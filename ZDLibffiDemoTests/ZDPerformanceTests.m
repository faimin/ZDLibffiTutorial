//
//  ZDPerformanceTests.m
//  ZDLibffiDemoTests
//
//  Created by Zero.D.Saber on 2019/12/17.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//
//  原生方法、Invocation、libffi调用方法的性能测试

#import <XCTest/XCTest.h>
#import "NSObject+ZDAOP.h"

FOUNDATION_EXPORT NSUInteger const MaxCount;

@interface ZDPerformanceTests : XCTestCase

@end

@implementation ZDPerformanceTests

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
            ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (uint)signature.numberOfArguments, &ffi_type_pointer, argTypes);
            
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

#pragma mark - OC Method

- (id)a:(NSInteger)a b:(NSString *)b c:(id)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    return ret;
}

@end
