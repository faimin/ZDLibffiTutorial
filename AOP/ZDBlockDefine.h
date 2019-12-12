//
//  ZDBlockDefine.h
//  ZDLibffiDemo
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#ifndef ZDBlockDefine_h
#define ZDBlockDefine_h

#pragma mark - Block Define
#pragma mark -

// http://clang.llvm.org/docs/Block-ABI-Apple.html#high-level
// https://opensource.apple.com/source/libclosure/libclosure-67/Block_private.h.auto.html
// Values for Block_layout->flags to describe block objects
typedef NS_OPTIONS(NSUInteger, ZDBlockDescriptionFlags) {
    BLOCK_DEALLOCATING =      (0x0001),  // runtime
    BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
    BLOCK_NEEDS_FREE =        (1 << 24), // runtime
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
    BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
    BLOCK_IS_GC =             (1 << 27), // runtime
    BLOCK_IS_GLOBAL =         (1 << 28), // compiler
    BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE  =    (1 << 30), // compiler
    BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};

// revised new layout

#define BLOCK_DESCRIPTOR_1 1
struct ZDBlock_descriptor_1 {
    uintptr_t reserved;
    uintptr_t size;
};

#define BLOCK_DESCRIPTOR_2 1
struct ZDBlock_descriptor_2 {
    // requires BLOCK_HAS_COPY_DISPOSE
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

#define BLOCK_DESCRIPTOR_3 1
struct ZDBlock_descriptor_3 {
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct ZDBlock_layout {
    void *isa;  // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    volatile int flags; // contains ref count
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 *descriptor;
    // imported variables
};

//*******************************************************

typedef struct ZDBlock_layout ZDBlock;
typedef void * ZDBlockIMP;

#endif /* ZDBlockDefine_h */
