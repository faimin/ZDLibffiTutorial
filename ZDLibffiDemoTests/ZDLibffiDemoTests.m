//
//  ZDLibffiDemoTests.m
//  ZDLibffiDemoTests
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+ZDAOP.h"

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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        [self testCallObjC];
    }];
}

- (void)testInvocationPerformance {
    [self measureBlock:^{
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
        NSLog(@"### %@", retValue);
    }];
}

//#########################################################

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
    
    void **args = malloc(sizeof(ffi_type *) * 3);
    args[0] = &a;
    args[1] = &b;
    args[2] = &c;
    int retValue;
    ffi_call(&cif, (void *)cFunc, &retValue, args);
    free(*args);
    
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
    NSLog(@"===== %@", ret);
}

- (id)a:(NSInteger)a b:(NSString *)b c:(NSObject *)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    NSLog(@"result = %@", ret);
    return ret;
}

#pragma mark - HookC

- (void)testHookCFunc {
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_sint, &ffi_type_sint};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint, argTypes);

    int a = 123;
    int b = 456;
    void *args[] = {&a, &b};
    int retValue;
    ffi_call(&cif, (void *)cFunc, &retValue, args);
    //int m = cFunc(a, b);
    
}

@end
