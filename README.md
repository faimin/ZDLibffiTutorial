# libffi

### 一、libffi简介

>  维基百科： 
>
> [libffi](https://github.com/libffi/libffi) 是一个外部函数接口库。它提供了一个C编程语言接口，用于在运行时（而不是编译时）给定有关目标函数的信息来调用本地编译函数。它还实现了相反的功能：`libffi`可以生成一个指向可以接受和解码在运行时定义的参数组合的函数的指针。

`FFI（Foreign Function Interface）`允许以一种语言编写的代码调用另一种语言的代码，而[libffi](https://github.com/libffi/libffi)库提供了最底层的、与架构相关的、完整的`FFI`。`libffi`的作用就相当于编译器，它为多种调用规则提供了一系列高级语言编程接口，然后通过相应接口完成函数调用，底层会根据对应的规则，完成数据准备，生成相应的汇编指令代码。

    [libffi](https://github.com/libffi/libffi) 被称为`C语言的runtime`，它可根据 `参数类型`(`ffi_type`)、`参数个数`生成一个模板(`ffi_cif`)，然后通过`模板`、`函数指针` 、`参数地址` 来直接完成函数的调用(`ffi_call`)。

    它也可以生成一个`闭包`(`ffi_closure`)，并同时得到一个函数指针`newIMP`，把这个新的函数指针`newIMP`与自定义的函数`void xx_func(ffi_cif *cif, void *ret, void **args, void *userdata)` 关联到一起，然后当我们执行`newIMP`时，会执行到我们自定义的`xx_func_`函数里（这个函数的参数格式是固定的），这里我们可以获得所有参数的地址和返回值以及自定义数据`userdata`。最后我们通过`ffi_call`函数来调用其他函数，简要流程是通过模板`cif`和`参数值`，把参数都按规则塞到栈/寄存器，然后调用的函数可以按规则获取到参数，调用完再获取返回值，最后记得释放内存。

### 二、用法

我们都知道`Objective-C`底层最终都会转成`objc_msgsend`这个`C`层的函数，而 `libffi` 能调用任意 `C` 函数，所以这也是`libffi`支持`Objective-C`的原因。`libffi`底层也是用汇编实现的。

<details close>
<summary> 先介绍一下`libffi`使用流程： </summary>

```c
//1. 生成参数类型列表
根据方法签名获取参数类型，然后转换成`ffi_type`类型

//2. 创建函数模版
ffi_status ffi_prep_cif(ffi_cif *cif,
            ffi_abi abi,
            unsigned int nargs,
            ffi_type *rtype,
            ffi_type **atypes);

//3. 如果需要用到切面，用下面函数生成一个`ffi_closure`闭包，否则直接执行第5步
void *ffi_closure_alloc(size_t size, void **code);
//4. 生成一个函数指针，并把闭包和函数指针绑定到函数模版上
ffi_status ffi_prep_closure_loc(ffi_closure*,
              ffi_cif *,
              void (*fun)(ffi_cif*,void*,void**,void*), //cif指针、返回值、参数列表、user_data
              void *user_data,    
              void*codeloc);    // 函数指针，执行函数实体

//5. 调用函数
void ffi_call(ffi_cif *cif,
          void (*fn)(void),
          void *rvalue,
          void **avalue);

//6. 在合适的时机释放`ffi_closure`
ffi_closure_free(void *)
```

</details>


##### 1. 调用C函数

<details>
<summary> Code </summary>

```c
int cFunc(int a , int b) {
    int x = a + b;
    return x;
}

- (void)testCallCFunc {
    ffi_cif cif;
    ffi_type *argTypes[] = {&ffi_type_sint, &ffi_type_sint};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint, argTypes);

    int a = 123;
    int b = 456;
    void *args[] = {&a, &b};
    int retValue;
    ffi_call(&cif, (void *)cFunc, &retValue, args);
}
```

</details>


##### 2.调用OC方法

<details close>
<summary> Code </summary>

```objectivec
// 直接调用OC方法
- (void)testCallObjc {
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
```

</details>


#### 3. 关联C函数

<details close>
<summary> Code </summary>

```c
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
    struct UserData userdata = {"圣诞快乐", 8888, newCFunc};
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
```

</details>


##### 4. 生成`OC`切面函数

>  大家熟知的几种hook方式：
> 
> 1. 方法交换
> 
>         什么addMethod啊、replaceMethod啊，exchangMethod啊
> 
> 2. 消息转发（[Aspects](https://github.com/steipete/Aspects)）
> 
> 3. 分类覆盖原方法

<details close>
<summary> Code </summary>

```objectivec
static void zdfunc(ffi_cif *cif, void *ret, void **args, void *userdata) {
    ZDFfiHookInfo *info = (__bridge ZDFfiHookInfo *)userdata;

    // 打印参数
    NSMethodSignature *methodSignature = info.signature;
    NSInteger beginIndex = 2;
    if (info.isBlock) {
        beginIndex = 1;
    }
    for (NSInteger i = beginIndex; i < methodSignature.numberOfArguments; ++i) {
        id argValue = ZD_ArgumentAtIndex(methodSignature, ret, args, userdata, i);
        NSLog(@"arg ==> index: %ld, value: %@", i, argValue);
    }

    // 根据cif (函数原型，函数指针，返回值内存指针，函数参数) 调用这个函数
    ffi_call(&(info->_cif), info->_originalIMP, ret, args);
}

- (void)testHookOC {
    SEL selector = @selector(x:y:z:);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    IMP originIMP = [self methodForSelector:selector];


    ffi_type *argTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint, &ffi_type_pointer, &ffi_type_pointer};

    ffi_cif cif;
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (uint32_t)signature.numberOfArguments, &ffi_type_pointer, argTypes);

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
    ffi_status status = ffi_prep_closure_loc(cloure, &cif, zdfunc, (__bridge void *)info, newIMP);
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
```

</details>


### 三、如何 hook 单个实例对象？

> 只提供思路

仿照`KVO`的实现机制，以当前实例对象所属类为父类，动态创建一个新的子类，把当前实例的`isa`设置为新建的子类，并重写`class`方法。接下来只要  `hook` 这个子类就可以了；

### 四、总结：

1. libffi的优势：
   
   > + 支持多平台
   > 
   > + 支持调用`C`、`Objective-C`
   > 
   > + 快
   > 
   > + 可以做到像[Aspects](https://github.com/steipete/Aspects)一样多次`hook`同一方法
   > 
   > + 可以像`NSInvocation`动态调用`Objective-C`

2. 缺点：
   
   > + 构建模版函数时像构建`NSInvocation`一样撕心裂肺

3. 使用场景：
   
   > + `hook` 原生方法
   > 
   > + 替代`performSelector:`、`NSInvocation`调用`Objective-C`方法

### 其他：

> 通过`消息转发`和`libffi`两种方式实现对block的`hook`

+ [ZDBlockHook](https://github.com/faimin/ZDBlockHook)

### 参考：

- [libffi](https://github.com/libffi/libffi)

- [libffi-iOS](https://github.com/sunnyxx/libffi-iOS)

- [libffi文档](http://www.chiark.greenend.org.uk/doc/libffi-dev/html/Index.html#Index)

- [使用libffi实现AOP](https://juejin.im/post/5a600d20518825732c539622)

- [动态调用&定义C函数](https://www.jianshu.com/p/92d4c06223e7)
