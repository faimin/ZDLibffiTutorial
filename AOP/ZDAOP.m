//
//  ZDAOP.m
//  ZDHookDemo
//
//  Created by Zero.D.Saber on 2019/12/9.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import "ZDAOP.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const ZD_Prefix = @"ZDAOP_";

//************************************
#pragma mark - liffi Info
#pragma mark -

@implementation ZDFfiHookInfo

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (_cif) {
        free(_cif);
        _cif = NULL;
    }
    if (_closure) {
        ffi_closure_free(_closure);
        _closure = NULL;
    }
    if (_argTypes) {
        free(_argTypes);
        _argTypes = NULL;
    }
}

+ (instancetype)infoWithObject:(id)obj method:(Method)method option:(ZDHookOption)option callback:(id)callback {
    if (!obj) {
        return nil;
    }
    
    ZDFfiHookInfo *model = [[ZDFfiHookInfo alloc] init];
    model.isBlock = [obj isKindOfClass:objc_lookUpClass("NSBlock")];
    model.obj = obj;
    model.method = method;
    model.hookOption = option;
    model.callback = callback;
    {
        const char *typeEncoding = model.isBlock ? ZD_ReduceBlockSignatureCodingType(ZD_BlockSignatureTypes(obj)).UTF8String : method_getTypeEncoding(method);
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
        model.signature = signature;
        model.typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        
        model->_originalIMP = model.isBlock ? ZD_BlockInvokeIMP(obj) : (void *)method_getImplementation(method);
    }
    if (callback) {
        model.callbackInfo = [self infoWithObject:callback method:NULL option:ZDHookOption_None callback:nil];
    }
    
    return model;
}

@end

#pragma mark - Core Func
#pragma mark -

// 中转的IMP函数
static void ZD_ffi_closure_func(ffi_cif *cif, void *ret, void **args, void *userdata) {
    ZDFfiHookInfo *info = (__bridge ZDFfiHookInfo *)userdata;
    
    NSMethodSignature *methodSignature = info.signature;
    
#if DEBUG && 0
    int argCount = 0;
    while (args[argCount]) {
        argCount++;
    };
    printf("参数个数：-------- %d\n", argCount);
    
    // 打印参数
    NSInteger beginIndex = 2;
    if (info.isBlock) {
        beginIndex = 1;
    }
    for (NSUInteger i = beginIndex; i < methodSignature.numberOfArguments; ++i) {
        id argValue = ZD_ArgumentAtIndex(methodSignature, args, i);
        NSLog(@"arg ==> index: %zd, value: %@", i, argValue);
    }
#endif
    
    id callbackBlock = info.callback;
    __auto_type callbackArgsBlock = ^void **{
        // block没有SEL,所以比普通方法少一个参数
        void **callbackArgs = calloc(methodSignature.numberOfArguments - 1, sizeof(void *));
        callbackArgs[0] = (void *)&callbackBlock;
        // 从index=2位置开始把args中的数据拷贝到callbackArgs(从index=1开始，第0个位置留给block自己)中
        memcpy(callbackArgs + 1, args + 2, sizeof(*args)*(methodSignature.numberOfArguments - 2));
        /*
        for (NSInteger i = 2; i < methodSignature.numberOfArguments; ++i) {
            callbackArgs[i - 1] = args[i];
        }
         */
        return callbackArgs;
    };
    
    // 根据cif (函数原型，函数指针，返回值内存指针，函数参数) 调用这个函数
    switch (info.hookOption) {
        case ZDHookOption_Befor: {
            void **callbackArgs = callbackArgsBlock();
            IMP blockIMP = info.callbackInfo->_originalIMP;
            ffi_call(info.callbackInfo->_cif, blockIMP, NULL, callbackArgs);
            free(callbackArgs);
            
            ffi_call(cif, info->_originalIMP, ret, args);
        } break;
        case ZDHookOption_Instead: {
            void **callbackArgs = callbackArgsBlock();
            IMP blockIMP = info.callbackInfo->_originalIMP;
            ffi_call(info.callbackInfo->_cif, blockIMP, NULL, callbackArgs);
            free(callbackArgs);
        } break;
        case ZDHookOption_After: {
            ffi_call(cif, info->_originalIMP, ret, args);
            
            void **callbackArgs = callbackArgsBlock();
            IMP blockIMP = info.callbackInfo->_originalIMP;
            ffi_call(info.callbackInfo->_cif, blockIMP, NULL, callbackArgs);
            free(callbackArgs);
        } break;
        default: {
            NSCAssert(NO, @"不支持的hook类型");
        } break;
    }
}

static const SEL ZD_AssociatedKey(SEL selector) {
    NSCAssert(selector != NULL, @"selector不能为NULL");
    NSString *selectorString = [ZD_Prefix stringByAppendingString:NSStringFromSelector(selector)];
    const SEL key = NSSelectorFromString(selectorString);
    return key;
}

void ZD_CoreHookFunc(id obj, Method method, ZDHookOption option, id callback) {
    if (!obj || !method) {
        NSCAssert(NO, @"参数错误");
        return;
    }
    
    const SEL key = ZD_AssociatedKey(method_getName(method));
    if (objc_getAssociatedObject(obj, key)) {
        return;
    }
    
    ZDFfiHookInfo *info = [ZDFfiHookInfo infoWithObject:obj method:method option:option callback:callback];
    // info需要被强引用，否则会出现内存crash
    objc_setAssociatedObject(obj, key, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    const unsigned int argsCount = method_getNumberOfArguments(method);
    // 构造参数类型列表
    ffi_type **argTypes = calloc(argsCount, sizeof(ffi_type *));
    for (int i = 0; i < argsCount; ++i) {
        const char *argType = [info.signature getArgumentTypeAtIndex:i];
        if (info.isBlock) {
            argType = ZD_ReduceBlockSignatureCodingType(argType).UTF8String;
        }
        ffi_type *arg_ffi_type = ZD_ffiTypeWithTypeEncoding(argType);
        NSCAssert(arg_ffi_type, @"can't find a ffi_type ==> %s", argType);
        argTypes[i] = arg_ffi_type;
    }
    // 返回值类型
    ffi_type *retType = ZD_ffiTypeWithTypeEncoding(info.signature.methodReturnType);
    
    //需要在堆上开辟内存，否则会出现内存问题(ZDFfiHookInfo释放时会free掉)
    ffi_cif *cif = calloc(1, sizeof(ffi_cif));
    //生成ffi_cfi模版对象，保存函数参数个数、类型等信息，相当于一个函数原型
    ffi_status prepCifStatus = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argsCount, retType, argTypes);
    if (prepCifStatus != FFI_OK) {
        NSCAssert1(NO, @"ffi_prep_cif failed = %d", prepCifStatus);
        return;
    }
    
    // 生成新的IMP
    void *newIMP = NULL;
    ffi_closure *cloure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&newIMP);
    {
        info->_cif = cif;
        info->_argTypes = argTypes;
        info->_closure = cloure;
        info->_newIMP = newIMP;
    };
    ffi_status prepClosureStatus = ffi_prep_closure_loc(cloure, cif, ZD_ffi_closure_func, (__bridge void *)info, newIMP);
    if (prepClosureStatus != FFI_OK) {
        NSCAssert1(NO, @"ffi_prep_closure_loc failed = %d", prepClosureStatus);
        return;
    }

    //替换IMP实现
    Class hookClass = [obj class];
    SEL aSelector = method_getName(method);
    const char *typeEncoding = method_getTypeEncoding(method);
    if (!class_addMethod(hookClass, aSelector, newIMP, typeEncoding)) {
        //IMP originIMP = class_replaceMethod(hookClass, aSelector, newIMP, typeEncoding);
        IMP originIMP = method_setImplementation(method, newIMP);
        if (info->_originalIMP != originIMP) {
            info->_originalIMP = originIMP;
        }
    }
    
    // 组装callback block
    if (info.callbackInfo) {
        uint blockArgsCount = argsCount - 1;
        ffi_type **blockArgTypes = calloc(blockArgsCount, sizeof(ffi_type *));
        blockArgTypes[0] = &ffi_type_pointer; //第一个参数是block自己，肯定为指针类型
        for (NSInteger i = 2; i < argsCount; ++i) {
            blockArgTypes[i-1] = ZD_ffiTypeWithTypeEncoding([info.signature getArgumentTypeAtIndex:i]);
        }
        info.callbackInfo->_argTypes = blockArgTypes;
        
        ffi_cif *callbackCif = calloc(1, sizeof(ffi_cif));
        if (ffi_prep_cif(callbackCif, FFI_DEFAULT_ABI, blockArgsCount, &ffi_type_void, blockArgTypes) == FFI_OK) {
            info.callbackInfo->_cif = callbackCif;
        }
        else {
            NSCAssert(NO, @"💔");
        }
    }
}

//*******************************************************

#pragma mark - Function
#pragma mark -

/// 不能直接通过blockRef->descriptor->signature获取签名，因为不同场景下的block结构有差别:
/// 比如当block内部引用了外面的局部变量，并且这个局部变量是OC对象，
/// 或者是`__block`关键词包装的变量，block的结构里面有copy和dispose函数，因为这两种变量都是属于内存管理的范畴的；
/// 其他场景下的block就未必有copy和dispose函数。
/// 所以这里是通过flag判断是否有签名，以及是否有copy和dispose函数，然后通过地址偏移找到signature的。
const char *ZD_BlockSignatureTypes(id block) {
    if (!block) return NULL;
    
    ZDBlock *blockRef = (__bridge ZDBlock *)block;
    
    // unsigned long int size = blockRef->descriptor->size;
    ZDBlockDescriptionFlags flags = blockRef->flags;
    
    if ( !(flags & BLOCK_HAS_SIGNATURE) ) return NULL;
    
    void *signatureLocation = blockRef->descriptor;
    signatureLocation += sizeof(unsigned long int);
    signatureLocation += sizeof(unsigned long int);
    
    if (flags & BLOCK_HAS_COPY_DISPOSE) {
        signatureLocation += sizeof(void(*)(void *dst, void *src));
        signatureLocation += sizeof(void(*)(void *src));
    }
    
    const char *signature = (*(const char **)signatureLocation);
    return signature;
}


ZDBlockIMP ZD_BlockInvokeIMP(id block) {
    if (!block) return NULL;
    
    ZDBlock *blockRef = (__bridge ZDBlock *)block;
    return blockRef->invoke;
}


IMP ZD_MsgForwardIMP(void) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    msgForwardIMP = (IMP)_objc_msgForward_stret;
#endif
    return msgForwardIMP;
}


NSString *ZD_ReduceBlockSignatureCodingType(const char *signatureCodingType) {
    NSString *charType = [NSString stringWithUTF8String:signatureCodingType];
    if (charType.length == 0) return nil;
    
    NSString *codingType = charType.copy;
    
    NSError *error = nil;
    NSString *regexString = @"\\\"[A-Za-z]+\\\"|\\\"<[A-Za-z]+>\\\"|[0-9]+";// <==> \\"[A-Za-z]+\\"|\d+  <==>  \\"\w+\\"|\\\"<w+>\\\"|\d+
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:0 error:&error];
    
    NSTextCheckingResult *mathResult = nil;
    do {
        mathResult = [regex firstMatchInString:codingType options:NSMatchingReportProgress range:NSMakeRange(0, codingType.length)];
        if (mathResult.range.location != NSNotFound && mathResult.range.length != 0) {
            codingType = [codingType stringByReplacingCharactersInRange:mathResult.range withString:@""];
        }
    } while (mathResult.range.length != 0);
    
    return codingType;
}


id ZD_ArgumentAtIndex(NSMethodSignature *methodSignature, void **args, NSUInteger index) {
#define WRAP_AND_RETURN(type) \
do { \
type val = *((type *)args[index]);\
return @(val); \
} while (0)
    
    const char *originArgType = [methodSignature getArgumentTypeAtIndex:index];
//    NSString *argTypeString = ZD_ReduceBlockSignatureCodingType(originArgType);
//    const char *argType = argTypeString.UTF8String;
    const char *argType = originArgType;
    
    // Skip const type qualifier.
    if (argType[0] == 'r') {
        argType++;
    }
    
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        id argValue = (__bridge id)(*((void **)args[index]));
        return argValue;
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        __unsafe_unretained id block = nil;
        block = (__bridge id)(*((void **)args[index]));
        return [block copy];
    }
    else {
        NSCAssert(NO, @"不支持的类型");
    }
    
    return nil;
#undef WRAP_AND_RETURN
}


ffi_type *ZD_ffiTypeWithTypeEncoding(const char *type) {
    if (strcmp(type, "@?") == 0) { // block
        return &ffi_type_pointer;
    }
    const char *c = type;
    switch (c[0]) {
        case 'v':
            return &ffi_type_void;
        case 'c':
            return &ffi_type_schar;
        case 'C':
            return &ffi_type_uchar;
        case 's':
            return &ffi_type_sshort;
        case 'S':
            return &ffi_type_ushort;
        case 'i':
            return &ffi_type_sint;
        case 'I':
            return &ffi_type_uint;
        case 'l':
            return &ffi_type_slong;
        case 'L':
            return &ffi_type_ulong;
        case 'q':
            return &ffi_type_sint64;
        case 'Q':
            return &ffi_type_uint64;
        case 'f':
            return &ffi_type_float;
        case 'd':
            return &ffi_type_double;
        case 'F':
#if CGFLOAT_IS_DOUBLE
            return &ffi_type_double;
#else
            return &ffi_type_float;
#endif
        case 'B':
            return &ffi_type_uint8;
        case '^':
            return &ffi_type_pointer;
        case '@':
            return &ffi_type_pointer;
        case '#':
            return &ffi_type_pointer;
        case ':':
            return &ffi_type_pointer;
        case '*':
            return &ffi_type_pointer;
        case '{':
        default: {
            printf("not support the type: %s", c);
        } break;
    }
    
    NSCAssert(NO, @"can't match a ffi_type of %s", type);
    return NULL;
}
