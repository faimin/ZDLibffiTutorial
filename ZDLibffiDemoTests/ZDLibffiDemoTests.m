//
//  ZDLibffiDemoTests.m
//  ZDLibffiDemoTests
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+ZDAOP.h"

static const NSUInteger MaxCount = 10000;
#define HOOK 0

@interface ZDLibffiDemoTests : XCTestCase

@end

@implementation ZDLibffiDemoTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
#if HOOK
    [self.class zd_hookInstanceMethod:@selector(a:b:c:) option:ZDHookOption_After callback:^(NSInteger a, NSString *b, id c){
        //NSLog(@"###########收到Hook信息 ==> 小狗%zd岁了, %@, %@", a, b, c);
    }];
#endif
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

#pragma mark - 性能测试

// 用libffi执行oc方法的效率
- (void)testLibffiPerformance {
    // This is an example of a performance test case.
    [self measureBlock:^{
        for (NSInteger i = 0; i < MaxCount; ++i) {
            SEL selector = @selector(a:b:c:);
            NSMethodSignature *signature = [self methodSignatureForSelector:selector];
            
            ffi_cif cif;
            ffi_type *argTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint, &ffi_type_pointer, &ffi_type_pointer};
            ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);
            
            NSInteger arg1 = 100;
            NSString *arg2 = @"hello";
            id arg3 = NSObject.class;
            void *args[] = {(void *)&self, &selector, &arg1, &arg2, &arg3};
            __unsafe_unretained id ret = nil;
            IMP func = [self methodForSelector:selector];
            ffi_call(&cif, func, &ret, args);
        }
    }];
}

// Invitation执行OC方法的效率
- (void)testInvocationPerformance {
    [self measureBlock:^{
        for (NSInteger i = 0; i < MaxCount; ++i) {
            NSInteger arg1 = 100;
            NSString *arg2 = @"hello";
            id arg3 = NSObject.class;
            __unsafe_unretained id retValue = nil;

            SEL selector = @selector(a:b:c:);
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setArgument:&arg1 atIndex:2];
            [invocation setArgument:&arg2 atIndex:3];
            [invocation setArgument:&arg3 atIndex:4];
            [invocation invokeWithTarget:self];
            [invocation getReturnValue:&retValue];
            //NSLog(@"### %@", retValue);
        }
    }];
}

// 直接执行OC方法的效率
- (void)testOCPerformance {
    [self measureBlock:^{
        for (NSInteger i = 0; i < MaxCount; ++i) {
            NSInteger arg1 = 100;
            NSString *arg2 = @"hello";
            id arg3 = NSObject.class;
            [self a:arg1 b:arg2 c:arg3];
        }
    }];
}

// 执行hook之后的OC方法的效率
- (void)testOCPerformanceAfterHook {
    [self measureBlock:^{
        for (NSInteger i = 0; i < MaxCount; ++i) {
            NSInteger arg1 = 100;
            NSString *arg2 = @"hello";
            id arg3 = NSObject.class;
            [self a:arg1 b:arg2 c:arg3];
        }
    }];
}

//#########################################################
#pragma mark - #######################################################

#pragma mark - 调用C函数

static int cFunc(int a , int b, int c) {
    int x = a + b + c;
    return x;
}

- (void)testCallCFunc {
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_sint, &ffi_type_sint, &ffi_type_sint};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 3, &ffi_type_sint, argTypes);

    int a = 123;
    int b = 456;
    int c = 890;
    
    void **args = alloca(sizeof(void *) * 3);
    args[0] = &a;
    args[1] = &b;
    args[2] = &c;
    int retValue;
    ffi_call(&cif, (void *)cFunc, &retValue, args);
    
    int m = cFunc(a, b, c);
    
    XCTAssertEqual(retValue, m);
}

#pragma mark - 调用OC方法

// 直接调用OC方法
- (void)testCallObjC {
    SEL selector = @selector(a:b:c:);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint, &ffi_type_pointer, &ffi_type_pointer};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);
    
    NSInteger arg1 = 100;
    NSString *arg2 = @"hello";
    id arg3 = NSObject.class;
    void *args[] = {&self, &selector, &arg1, &arg2, &arg3};
    __unsafe_unretained id ret = nil;
    IMP func = [self methodForSelector:selector];
    ffi_call(&cif, func, &ret, args);
    //NSLog(@"===== %@", ret);
}

- (id)a:(NSInteger)a b:(NSString *)b c:(NSObject *)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    //NSLog(@"result = %@", ret);
    return ret;
}

#pragma mark - BindC

struct UserData {
    char *c;
    int a;
    void *imp;
};

static void bindCFunc(ffi_cif *cif, int *ret, void **args, void *userdata) {
    struct UserData ud = *(struct UserData *)userdata;
    *ret = 999;
    printf("==== %s, %d\n", ud.c, *(int *)ret);
    
    //ffi_call(cif, ud.imp, ret, args); //再调用此方法会进入死循环
}

- (void)testBindCFunc {
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_sint, &ffi_type_sint, &ffi_type_sint};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 3, &ffi_type_sint, argTypes);
    
    // 新定义一个C函数指针
    int(*newCFunc)(int, int, int);
    ffi_closure *cloure = ffi_closure_alloc(sizeof(ffi_closure), (void *)&newCFunc);
    struct UserData userdata = {"我是你爸爸", 8888, newCFunc};
    // 将newCFunc与bingCFunc关联
    ffi_status status = ffi_prep_closure_loc(cloure, &cif, (void *)bindCFunc, &userdata, newCFunc);
    if (status != FFI_OK) {
        NSLog(@"新函数指针生成失败");
        return;
    }
    
    int ret = newCFunc(11, 34, 24);
    printf("********** %d\n", ret);
    
    ffi_closure_free(cloure);
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

@end
