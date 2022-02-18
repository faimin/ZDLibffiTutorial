//
//  NSObject+ZDAOP.h
//  ZDHookDemo
//
//  Created by Zero.D.Saber on 2019/12/9.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//
//  这只是一个demo，完整的hook repo请移驾:
//  https://github.com/faimin/ZDFfiHook

#import <Foundation/Foundation.h>
#import "ZDAOP.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (ZDAOP)

+ (void)zd_hookInstanceMethod:(SEL)selector option:(ZDHookOption)option callback:(id)callback;

+ (void)zd_hookClassMethod:(SEL)selector option:(ZDHookOption)option callback:(id)callback;

@end

NS_ASSUME_NONNULL_END
