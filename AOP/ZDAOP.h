//
//  ZDAOP.h
//  ZDHookDemo
//
//  Created by Zero.D.Saber on 2019/12/9.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ZDBlockDefine.h"
#if __has_include(<ffi.h>)
#import <ffi.h>
#elif __has_include("ffi.h")
#import "ffi.h"
#endif

NS_ASSUME_NONNULL_BEGIN

// Libffi文档： http://www.chiark.greenend.org.uk/doc/libffi-dev/html/Index.html#Index

//*******************************************************

typedef NS_ENUM(NSInteger, ZDHookMethodType) {
    ZDHookMethodType_None           = 0,
    ZDHookMethodType_Instance       = 1,          // 类的实例方法
    ZDHookMethodType_Class          = 2,          // 类方法
    ZDHookMethodType_SingleInstance = 3,          // 单个实例
};

typedef NS_ENUM(NSInteger, ZDHookOption) {
    ZDHookOption_None               = 0,
    ZDHookOption_Befor              = 1,
    ZDHookOption_Instead            = 2,
    ZDHookOption_After              = 3,
};

//*******************************************************

@interface ZDFfiHookInfo : NSObject {
    @package
    ffi_cif *_cif;
    ffi_type **_argTypes;
    ffi_closure *_closure;

    void *_originalIMP;
    void *_newIMP;
}
@property (nonatomic) Method method;
@property (nonatomic, strong) NSMethodSignature *signature;
@property (nonatomic, copy) NSString *typeEncoding;
@property (nonatomic, weak) id obj;
@property (nonatomic, assign) BOOL isBlock;
@property (nonatomic, assign) ZDHookOption hookOption;
@property (nonatomic, strong) id callback;

@property (nonatomic, strong, nullable) ZDFfiHookInfo *callbackInfo;

+ (instancetype)infoWithObject:(id)obj method:(Method _Nullable)method option:(ZDHookOption)option callback:(id _Nullable)callback;

@end

//*************************************************

#pragma mark - Function
#pragma mark -

FOUNDATION_EXPORT void ZD_CoreHookFunc(id obj, Method method, ZDHookOption option, id callback);

/// 获取block方法签名
FOUNDATION_EXPORT const char *_Nullable ZD_BlockSignatureTypes(id block);
/// 获取block的函数指针
FOUNDATION_EXPORT ZDBlockIMP _Nullable ZD_BlockInvokeIMP(id block);
/// 消息转发专用的IMP
FOUNDATION_EXPORT IMP ZD_MsgForwardIMP(void);
/// 简化block的方法签名
FOUNDATION_EXPORT NSString *ZD_ReduceBlockSignatureCodingType(const char *signatureCodingType);
FOUNDATION_EXPORT ffi_type *_Nullable ZD_ffiTypeWithTypeEncoding(const char *type);
FOUNDATION_EXPORT id _Nullable ZD_ArgumentAtIndex(NSMethodSignature *methodSignature, void *_Nullable* _Nullable args, NSUInteger index);

NS_ASSUME_NONNULL_END
