//
//  ZDLibffiVSAspectTests.m
//  ZDLibffiDemoTests
//
//  Created by Zero.D.Saber on 2019/12/17.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//
//  aspect与libffi性能对比

#import <XCTest/XCTest.h>
#import "NSObject+ZDAOP.h"
#import <Aspects/Aspects.h>

FOUNDATION_EXPORT NSUInteger const MaxCount;
#define HOOK_Libffi (1)

@interface ZDLibffiVSAspectTests : XCTestCase

@end

@implementation ZDLibffiVSAspectTests

// 执行被hook后的OC方法的效率
- (void)testOCPerformanceAfterHook {
    printf("********************* %s\n", __PRETTY_FUNCTION__);
    SEL selector = @selector(a:b:c:);
#if HOOK_Libffi
    [self.class zd_hookInstanceMethod:selector option:ZDHookOption_After callback:^(NSInteger a, NSString *b, id c){
        //NSLog(@"###########收到Hook信息 ==> 小狗%zd岁了, %@, %@", a, b, c);
    }];
#else
    [self.class aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info, NSInteger a, NSString *b, id c){
        
    } error:nil];
#endif
    
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
