## libffi浅析

#### 一、 `libffi`主要函数：

<details open>
<summary> Code </summary>

```c++
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


#### 二、简略说明：

首先`ffi_cif`是一个结构体：

```c++
typedef struct {
  ffi_abi abi;
  unsigned nargs;
  ffi_type **arg_types;
  ffi_type *rtype;
  unsigned bytes;
  unsigned flags;
#ifdef FFI_EXTRA_CIF_FIELDS
  FFI_EXTRA_CIF_FIELDS;
#endif
} ffi_cif;
```

接下来看看`ffi_prep_cif`函数，它内部其实是直接调用了`ffi_prep_cif_core`函数

<details open>
<summary> Code </summary>

```c++
ffi_status ffi_prep_cif(ffi_cif *cif, ffi_abi abi, unsigned int nargs,
			     ffi_type *rtype, ffi_type **atypes)
{
  return ffi_prep_cif_core(cif, abi, 0, nargs, nargs, rtype, atypes);
}

ffi_status FFI_HIDDEN ffi_prep_cif_core(ffi_cif *cif, ffi_abi abi,
			     unsigned int isvariadic,
                             unsigned int nfixedargs,
                             unsigned int ntotalargs,
			     ffi_type *rtype, ffi_type **atypes)
{
  unsigned bytes = 0;
  unsigned int i;
  ffi_type **ptr;

  FFI_ASSERT(cif != NULL);
  FFI_ASSERT((!isvariadic) || (nfixedargs >= 1));
  FFI_ASSERT(nfixedargs <= ntotalargs);

  if (! (abi > FFI_FIRST_ABI && abi < FFI_LAST_ABI))
    return FFI_BAD_ABI;

  cif->abi = abi;
  cif->arg_types = atypes;
  cif->nargs = ntotalargs;
  cif->rtype = rtype;

  cif->flags = 0;
 #ifdef _M_ARM64
  cif->isVariadic = isvariadic;
#endif
#if HAVE_LONG_DOUBLE_VARIANT
  ffi_prep_types (abi);
#endif

  /* Initialize the return type if necessary */
  if ((cif->rtype->size == 0)
      && (initialize_aggregate(cif->rtype, NULL) != FFI_OK))
    return FFI_BAD_TYPEDEF;

#ifndef FFI_TARGET_HAS_COMPLEX_TYPE
  if (rtype->type == FFI_TYPE_COMPLEX)
    abort();
#endif
  /* Perform a sanity check on the return type */
  FFI_ASSERT_VALID_TYPE(cif->rtype);

  /* x86, x86-64 and s390 stack space allocation is handled in prep_machdep. */
#if !defined FFI_TARGET_SPECIFIC_STACK_SPACE_ALLOCATION
  /* Make space for the return structure pointer */
  if (cif->rtype->type == FFI_TYPE_STRUCT
#ifdef TILE
      && (cif->rtype->size > 10 * FFI_SIZEOF_ARG)
#endif
#ifdef XTENSA
      && (cif->rtype->size > 16)
#endif
#ifdef NIOS2
      && (cif->rtype->size > 8)
#endif
     )
    bytes = STACK_ARG_SIZE(sizeof(void*));
#endif

  for (ptr = cif->arg_types, i = cif->nargs; i > 0; i--, ptr++)
    {

      /* Initialize any uninitialized aggregate type definitions */
      if (((*ptr)->size == 0)
	  && (initialize_aggregate((*ptr), NULL) != FFI_OK))
	return FFI_BAD_TYPEDEF;

#ifndef FFI_TARGET_HAS_COMPLEX_TYPE
      if ((*ptr)->type == FFI_TYPE_COMPLEX)
	abort();
#endif
      /* Perform a sanity check on the argument type, do this
	 check after the initialization.  */
      FFI_ASSERT_VALID_TYPE(*ptr);

#if !defined FFI_TARGET_SPECIFIC_STACK_SPACE_ALLOCATION
	{
	  /* Add any padding if necessary */
	  if (((*ptr)->alignment - 1) & bytes)
	    bytes = (unsigned)FFI_ALIGN(bytes, (*ptr)->alignment);

#ifdef TILE
	  if (bytes < 10 * FFI_SIZEOF_ARG &&
	      bytes + STACK_ARG_SIZE((*ptr)->size) > 10 * FFI_SIZEOF_ARG)
	    {
	      /* An argument is never split between the 10 parameter
		 registers and the stack.  */
	      bytes = 10 * FFI_SIZEOF_ARG;
	    }
#endif
#ifdef XTENSA
	  if (bytes <= 6*4 && bytes + STACK_ARG_SIZE((*ptr)->size) > 6*4)
	    bytes = 6*4;
#endif

	  bytes += (unsigned int)STACK_ARG_SIZE((*ptr)->size);
	}
#endif
    }

  cif->bytes = bytes;

  /* Perform machine dependent cif processing */
#ifdef FFI_TARGET_SPECIFIC_VARIADIC
  if (isvariadic)
	return ffi_prep_cif_machdep_var(cif, nfixedargs, ntotalargs);
#endif

  return ffi_prep_cif_machdep(cif);
}

ffi_status ffi_prep_cif_machdep (ffi_cif * cif)
{
  switch (cif->rtype->type)
    {
    case FFI_TYPE_VOID:
    case FFI_TYPE_STRUCT:
    case FFI_TYPE_FLOAT:
    case FFI_TYPE_DOUBLE:
    case FFI_TYPE_SINT64:
    case FFI_TYPE_UINT64:
      cif->flags = (unsigned) cif->rtype->type;
      break;

    default:
      cif->flags = FFI_TYPE_INT;
      break;
    }

  return FFI_OK;
}

```

</details>

里面主要就是把我们传递进去的参数赋值给`ffi_cif`，并对参数类型和返回值类型做了些对齐操作；概括起来讲就是如函数名一样，就是构建`ffi_cif`的过程；


接下来让我们看看 `ffi_closure_alloc` 函数

<details open>
<summary> Code </summary>

```c++
void *ffi_closure_alloc(size_t size, void **code)
{
  /* Create the closure */
  ffi_closure *closure = malloc(size);
  if (closure == NULL)
    return NULL;

  pthread_mutex_lock(&ffi_trampoline_lock);

  /* Check for an active trampoline table with available entries. */
  ffi_trampoline_table *table = ffi_trampoline_tables;
  if (table == NULL || table->free_list == NULL)
    {
      table = ffi_trampoline_table_alloc();
      if (table == NULL)
	    {
	      pthread_mutex_unlock (&ffi_trampoline_lock);
	      free (closure);
	      return NULL;
	    }

      /* Insert the new table at the top of the list */
      table->next = ffi_trampoline_tables;
      if (table->next != NULL)
	        table->next->prev = table;

      ffi_trampoline_tables = table;
    }

  /* Claim the free entry */
  ffi_trampoline_table_entry *entry = ffi_trampoline_tables->free_list;
  ffi_trampoline_tables->free_list = entry->next;
  ffi_trampoline_tables->free_count--;
  entry->next = NULL;

  pthread_mutex_unlock (&ffi_trampoline_lock);

  /* Initialize the return values */
  *code = entry->trampoline;
  closure->trampoline_table = table;
  closure->trampoline_table_entry = entry;

  return closure;
}
```

</details>


没看懂创建闭包`closure`的操作，里面用到了链表操作。


<details open>
<summary> ffi_prep_closure_loc </summary>

```c++
ffi_status ffi_prep_closure_loc(ffi_closure * closure,
		      ffi_cif * cif,
		      void (*fun) (ffi_cif *, void *, void **, void *),
		      void *user_data, void *codeloc)
{
  void (*closure_func) (void) = ffi_closure_SYSV;

  if (cif->abi == FFI_VFP)
    {
      /* We only need take the vfp path if there are vfp arguments.  */
      if (cif->vfp_used)
	closure_func = ffi_closure_VFP;
    }
  else if (cif->abi != FFI_SYSV)
    return FFI_BAD_ABI;

#if FFI_EXEC_TRAMPOLINE_TABLE
  void **config = (void **)((uint8_t *)codeloc - PAGE_MAX_SIZE);
  config[0] = closure;
  config[1] = closure_func;
#else

#ifndef _M_ARM
  memcpy(closure->tramp, ffi_arm_trampoline, 8);
#else
  // cast away function type so MSVC doesn't set the lower bit of the function pointer
  memcpy(closure->tramp, (void*)((uintptr_t)ffi_arm_trampoline & 0xFFFFFFFE), FFI_TRAMPOLINE_CLOSURE_OFFSET);
#endif

#if defined (__QNX__)
  msync(closure->tramp, 8, 0x1000000);	/* clear data map */
  msync(codeloc, 8, 0x1000000);	/* clear insn map */
#elif defined(_MSC_VER)
  FlushInstructionCache(GetCurrentProcess(), closure->tramp, FFI_TRAMPOLINE_SIZE);
#else
  __clear_cache(closure->tramp, closure->tramp + 8);	/* clear data map */
  __clear_cache(codeloc, codeloc + 8);			/* clear insn map */
#endif
#ifdef _M_ARM
  *(void(**)(void))(closure->tramp + FFI_TRAMPOLINE_CLOSURE_FUNCTION) = closure_func;
#else
  *(void (**)(void))(closure->tramp + 8) = closure_func;
#endif
#endif

  closure->cif = cif;
  closure->fun = fun;
  closure->user_data = user_data;

  return FFI_OK;
}
```

</details>

这个就是为`closure`结构体赋值，保存我们需要的变量数据；


<details open>
<summary> Code </summary>

```c++
static void
ffi_call_int (ffi_cif * cif, void (*fn) (void), void *rvalue,
	      void **avalue, void *closure)
{
  int flags = cif->flags;
  ffi_type *rtype = cif->rtype;
  size_t bytes, rsize, vfp_size;
  char *stack, *vfp_space, *new_rvalue;
  struct call_frame *frame;

  rsize = 0;
  if (rvalue == NULL)
    {
      /* If the return value is a struct and we don't have a return
	 value address then we need to make one.  Otherwise the return
	 value is in registers and we can ignore them.  */
      if (flags == ARM_TYPE_STRUCT)
	rsize = rtype->size;
      else
	flags = ARM_TYPE_VOID;
    }
  else if (flags == ARM_TYPE_VFP_N)
    {
      /* Largest case is double x 4. */
      rsize = 32;
    }
  else if (flags == ARM_TYPE_INT && rtype->type == FFI_TYPE_STRUCT)
    rsize = 4;

  /* Largest case.  */
  vfp_size = (cif->abi == FFI_VFP && cif->vfp_used ? 8*8: 0);

  bytes = cif->bytes;
  stack = alloca (vfp_size + bytes + sizeof(struct call_frame) + rsize);

  vfp_space = NULL;
  if (vfp_size)
    {
      vfp_space = stack;
      stack += vfp_size;
    }

  frame = (struct call_frame *)(stack + bytes);

  new_rvalue = rvalue;
  if (rsize)
    new_rvalue = (void *)(frame + 1);

  frame->rvalue = new_rvalue;
  frame->flags = flags;
  frame->closure = closure;

  if (vfp_space)
    {
      ffi_prep_args_VFP (cif, flags, new_rvalue, avalue, stack, vfp_space);
      ffi_call_VFP (vfp_space, frame, fn, cif->vfp_used);
    }
  else
    {
      ffi_prep_args_SYSV (cif, flags, new_rvalue, avalue, stack);
      ffi_call_SYSV (stack, frame, fn);
    }

  if (rvalue && rvalue != new_rvalue)
    memcpy (rvalue, new_rvalue, rtype->size);
}
```

</details>


利用现有的数据创建`call`所需的 `struct call_frame`参数，最终调用的汇编来执行的。