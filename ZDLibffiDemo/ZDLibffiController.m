//
//  ZDLibffiController.m
//  ZDLibffiDemo
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import "ZDLibffiController.h"
#import "NSObject+ZDAOP.h"

@interface ZDLibffiController ()

@end

@implementation ZDLibffiController

+ (void)load {
    [self zd_hookInstanceMethod:@selector(x:y:z:) option:ZDHookOption_After callback:^(NSInteger a, NSString *b, id c){
        NSLog(@"###########收到Hook信息 ==> 小狗%zd岁了, %@, %@", a, b, c);
    }];
}

- (void)dealloc {
    printf("%s, %d\n", __PRETTY_FUNCTION__, __LINE__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    [self testHookOC];
    
    id r = [self x:110 y:@"阿尔托莉雅·潘德拉贡" z:NSObject.new];
    NSLog(@"$$$$$$$$$$$$ %s => %@", __PRETTY_FUNCTION__, r);
    
}

#pragma mark - HookOC

static void zdfunc(ffi_cif *cif, void *ret, void **args, void *userdata) {
    ZDFfiHookInfo *info = (__bridge ZDFfiHookInfo *)userdata;
    
    // 打印参数
    NSMethodSignature *methodSignature = info.signature;
    NSInteger beginIndex = 2;
    if (info.isBlock) {
        beginIndex = 1;
    }
    for (NSInteger i = beginIndex; i < methodSignature.numberOfArguments; ++i) {
        id argValue = ZD_ArgumentAtIndex(methodSignature, args, i);
        NSLog(@"arg ==> index: %ld, value: %@", i, argValue);
    }
    
    // https://github.com/sunnyxx/libffi-iOS/blob/master/Demo/ViewController.m
    // 根据cif (函数原型，函数指针，返回值内存指针，函数参数) 调用这个函数
    ffi_call(cif, info->_originalIMP, ret, args);
}

- (void)testHookOC {
    SEL selector = @selector(x:y:z:);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    IMP originIMP = [self methodForSelector:selector];
    
    
    //ffi_type *argTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint, &ffi_type_pointer, &ffi_type_pointer};
    ffi_type **argTypes = calloc(signature.numberOfArguments, sizeof(ffi_type *));
    argTypes[0] = &ffi_type_pointer;
    argTypes[1] = &ffi_type_schar;
    argTypes[2] = &ffi_type_sint;
    argTypes[3] = &ffi_type_pointer;
    argTypes[4] = &ffi_type_pointer;
    
    ffi_cif cif;
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);
    
    IMP newIMP = NULL;
    ffi_closure *cloure = ffi_closure_alloc(sizeof(ffi_closure), (void *)&newIMP);
    ZDFfiHookInfo *info = ({
        ZDFfiHookInfo *model = ZDFfiHookInfo.new;
        model->_cif = &cif;
        model->_argTypes = argTypes;
        model->_closure = cloure;
        model->_originalIMP = originIMP;
        model->_newIMP = newIMP;
        model.signature = signature;
        model;
    });
    ffi_status status = ffi_prep_closure_loc(cloure, &cif, zdfunc, (__bridge void *)info, newIMP);
    if (status != FFI_OK) {
        NSLog(@"新函数指针生成失败");
        return;
    }
    
    //替换实现
    Method method = class_getInstanceMethod(self.class, selector);
    method_setImplementation(method, newIMP);
    
    NSInteger arg1 = 100;
    NSString *arg2 = @"Zero.D.Saber";
    id arg3 = @(909090);
    [self x:arg1 y:arg2 z:arg3];
}

- (id)x:(NSInteger)a y:(NSString *)b z:(id)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    NSLog(@"result = %@", ret);
    return ret;
}

@end
