#ifdef __arm64__

#if __has_include(<ffitarget_arm64.h>)
#include <ffitarget_arm64.h>
#else
#include "ffitarget_arm64.h"
#endif


#endif
#ifdef __i386__

#if __has_include(<ffitarget_i386.h>)
#include <ffitarget_i386.h>
#else
#include "ffitarget_i386.h"
#endif


#endif
#ifdef __arm__

#if __has_include(<ffitarget_armv7.h>)
#include <ffitarget_armv7.h>
#else
#include "ffitarget_armv7.h"
#endif


#endif
#ifdef __x86_64__

#if __has_include(<ffitarget_x86_64.h>)
#include <ffitarget_x86_64.h>
#else
#include "ffitarget_x86_64.h"
#endif


#endif
#ifdef __arm__

#if __has_include(<ffitarget_armv7k.h>)
#include <ffitarget_armv7k.h>
#else
#include "ffitarget_armv7k.h"
#endif


#endif
