//
//  ZDLibffiDemoTests.m
//  ZDLibffiDemoTests
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//
//  libffi基本用法

#import <XCTest/XCTest.h>
#import "NSObject+ZDAOP.h"

NSUInteger const MaxCount = 100000;

@interface ZDLibffiDemoTests : XCTestCase

@end

@implementation ZDLibffiDemoTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
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
    
    ffi_cif *cif = alloca(sizeof(ffi_cif));
    ffi_type *argTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint, &ffi_type_pointer, &ffi_type_pointer};
    ffi_prep_cif(cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);
    
    NSInteger arg1 = 100;
    NSString *arg2 = @"hello";
    id arg3 = NSObject.class;
    void *args[] = {&self, &selector, &arg1, &arg2, &arg3};
    __unsafe_unretained id ret = nil;
    IMP func = [self methodForSelector:selector];
    ffi_call(cif, func, &ret, args);
    NSLog(@"===== %@", ret);
}

- (id)a:(NSInteger)a b:(NSString *)b c:(id)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    NSLog(@"result = %@", ret);
    return ret;
}

#pragma mark - --------------------------
#pragma mark - BindC

struct ZDUserData {
    char *c;
    int a;
    void *imp;
};

static void bindCFunc(ffi_cif *cif, int *ret, void **args, void *userdata) {
    struct ZDUserData ud = *(struct ZDUserData *)userdata;
    *ret = 999;
    printf("==== %s, %d\n", ud.c, *(int *)ret);
    
    //ffi_call(cif, ud.imp, ret, args); //再调用此方法会进入死循环
}

- (void)testBindCFunc {
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_sint, &ffi_type_sint, &ffi_type_sint};
    unsigned int argTypesCount = sizeof(argTypes) / sizeof(ffi_type *);
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, argTypesCount, &ffi_type_sint, argTypes);
    
    // 新定义一个C函数指针
    int(*newCFunc)(int, int, int) = NULL;
    ffi_closure *cloure = ffi_closure_alloc(sizeof(ffi_closure), (void *)&newCFunc);
    struct ZDUserData userdata = {"元旦快乐", 8888, newCFunc};
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
    
    ffi_cif *cif = calloc(1, sizeof(ffi_cif));
    ffi_prep_cif(cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);
    
    IMP newIMP = NULL;
    ffi_closure *cloure = ffi_closure_alloc(sizeof(ffi_closure), (void *)&newIMP);
    ZDFfiHookInfo *info = ({
        ZDFfiHookInfo *model = ZDFfiHookInfo.new;
        model->_cif = cif;
        model->_argTypes = argTypes;
        model->_closure = cloure;
        model->_originalIMP = originIMP;
        model->_newIMP = newIMP;
        model.signature = signature;
        model;
    });
    ffi_status status = ffi_prep_closure_loc(cloure, cif, zdfunc, (__bridge void *)info, newIMP);
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
