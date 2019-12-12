//
//  NSObject+ZDAOP.m
//  ZDHookDemo
//
//  Created by Zero.D.Saber on 2019/12/9.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import "NSObject+ZDAOP.h"
#import <objc/runtime.h>
#import "ZDAOP.h"

//*****************************************************************

@implementation NSObject (ZDAOP)

+ (void)zd_hookInstanceMethod:(SEL)selector option:(ZDHookOption)option callback:(id)callback {
    Method method = class_getInstanceMethod(self.class, selector);
    ZD_CoreHookFunc(self, method, option, callback);
}

+ (void)zd_hookClassMethod:(SEL)selector option:(ZDHookOption)option callback:(id)callback {
    Method method = class_getClassMethod(object_getClass(self), selector);
    ZD_CoreHookFunc(self, method, option, callback);
}

- (void)zd_hookInstanceMethod:(SEL)selector option:(ZDHookOption)option callback:(id)callback {
//    Method method = class_getInstanceMethod(self.class, selector);
//    ZD_CoreHookFunc(self, method, option, callback);
    //TODO: 客官莫急
}

@end
