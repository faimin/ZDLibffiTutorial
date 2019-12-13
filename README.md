# libffi

### 一、libffi简介

        [libffi](https://github.com/libffi/libffi) 可根据 **参数类型**(`ffi_type`)，**参数个数** 生成一个 **模板**(`ffi_cif`)；可以输入 **模板**、**函数指针** 和 **参数地址** 来直接完成 **函数调用**(`ffi_call`)； **模板** 也可以生成一个所谓的 **闭包**(`ffi_closure`)，并得到指针，当执行到这个地址时，会执行到自定义的`void function(ffi_cif *cif, void *ret, void **args, void *userdata)`函数，在这里，我们可以获得所有参数的地址(包括返回值)，以及自定义数据`userdata`。

        `libffi` 能调用任意 `C` 函数的原理与`objc_msgSend`的原理类似，其底层是用汇编实现的，`ffi_call`根据模板`cif`和`参数值`，把参数都按规则塞到栈/寄存器，调用的函数可以按规则得到参数，调用完再获取返回值，清理数据。通过其他方式调用上文中的`imp`，`ffi_closure`可根据栈/寄存器、模板`cif`拿到所有的参数，接着执行自定义函数`xxx_func`。
         看完以上介绍，是否想到了`hook`操作？！我们可以将`ffi_closure`关联的指针替换原方法的`IMP`，当对象收到该方法的消息时`objc_msgSend(id self, SEL sel, ...)`，将最终执行自定义函数`void xxx_func(ffi_cif *cif, void *ret, void **args, void *userdata)`，在`xxx_func`里的参数`userdata`会派上很大用处，我们可以通过它传递我们需要的信息，比如原始函数指针，这样我们就可以愉快的玩耍了😄。

### 二、 用法

主要流程：

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

##### 1. 调用C函数

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

##### 2.调用OC方法

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

##### 3. 生成切面函数

>  大家熟知的几种方式：
> 
> 1. 方法交换
> 
>         什么addMethod啊、replaceMethod啊，exchangMethod啊
> 
> 2. 消息转发
> 
> 3. 分类覆盖原方法

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

### 三、如何 hook 单个实例对象？

##### 基本原理：

仿照`KVO`的实现机制，以当前实例对象所属类为父类，动态创建一个新的子类，把当前实例的`isa`设置为新建的子类，并重写`class`方法。接下来只要  `hook` 这个子类就可以了；

### 四、总结：

1. libffi的优势：
   
   > + 跨平台
   > 
   > + 支持调用`C`、`Objective-C`
   > 
   > + 不用进入消息转发的流程即可实现`hook`
   > 
   > + `hook`比较方便

2. 缺点：
   
   > + 使用时需要创建模版函数
   > + 非原生，有时需要手动管理内存的生命周期

3. 使用场景：
   
   > + `hook` 原生方法
   > 
   > + 替代`performSelector:`、`NSInvocation`调用`OC`方法

## 其他：

+ [ZDBlockHook](https://github.com/faimin/ZDBlockHook)

## 参考：

1. [libffi](https://github.com/libffi/libffi)

2. [libffi-iOS](https://github.com/sunnyxx/libffi-iOS)

3. [使用libffi实现AOP](https://juejin.im/post/5a600d20518825732c539622)

4. [libffi文档](http://www.chiark.greenend.org.uk/doc/libffi-dev/html/Index.html#Index)


