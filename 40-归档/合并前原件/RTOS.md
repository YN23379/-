---
type: 知识库
scope: RTOS
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

即实时操作系统，Real Time OS。
实时操作系统又分为硬实时和软实时。硬实时要求在规定的时间内必须完成操作，硬实时系统不允许超时，在软实时里面处理过程超时的后果就没有那么严格。

在实时操作系统中，我们可以把要**实现的功能划分为多个任务**，每个任务负责实现其中的一部分，每个任务都是一个很简单的程序，通常是个死循环。
RTOS操作系统:UCOS,FreeRTOS,RTX,RT-Thread,DJYOS等
RTOS操作系统的核心内容在于：实时内核。

RTOS的内核负责管理所有的任务，内核决定了运行哪个任务，何时停止当前任务切换到其他任务，这是内核的多任务管理能力。
多任务管理就好像芯片有多个CPL多任务管理实现了CPU资源的最大化利用，多任务管理有助于实现程序的模块化开发，能够实现复杂的实时应用。






# ucos

ucos是RTOS的一种，它的内核属于可剥夺内核，就是可以剥夺其他任务的CPU使用权，它总是运行就绪任务中的优先级最高的那个任务。
μC/OS-II 是**抢占式内核**——任何时候，CPU 上运行的永远是当前就绪的**最高优先级任务**。

从体系结构上来看,μC/OS-II的代码可以大致分成3大部分配置文件、与处
理器无关的源代码、与处理器相关的源代码
μC/OS-II只包含了进程调度、时钟管理、内存管理和进程间的通信与同步等基本功能，而没有I/O管理、文件系统、网络等额外的模块。

## 数据类型

在嵌入式操作系统中，使用 `INT8U`、`INT16U`、`INT32U` 这类自定义类型，主要是为了：
1. **跨平台可移植性**：不同编译器/架构下，`int` 和 `char` 的长度可能不同，而 `INT8U` 明确告诉开发者它就是 8 位，不依赖编译器。
2. **语义清晰**：一眼就知道这是 8 位无符号整数，用于优先级、状态码、计数器等。
3. **与操作系统风格统一**：UCOS 的 API 大量使用这类类型，保持一致性。

|类型|等价C类型|范围|
|---|---|---|
|`INT8U`|`unsigned char`|0 ~ 255|
|`INT8S`|`signed char`|-128 ~ 127|
|`INT16U`|`unsigned short`|0 ~ 65535|
|`INT16S`|`signed short`|-32768 ~ 32767|
|`INT32U`|`unsigned int` / `unsigned long`|0 ~ 4294967295|
|`INT32S`|`signed int` / `signed long`|-2147483648 ~ 2147483647|
|`FP32`|`float`|单精度浮点数|
具体等价类型取决于编译器和平台（如 32位 ARM 下 `int` 是 32 位）。

## 任务
任务就是程序实体，是操作系统管理和调度的最小单位
由以下属性组成：
· 任务堆栈（上下文切换的寄存器值）
· 任务控制块（各个任务的属性值）
· 任务函数（用户编写的）


uC/OS-II 中最多可以支持64 个任务，分别对应优先级0～63，其中0 为最高优先级。63为最低级，系统保留了4个最高优先级的任务和4个最低优先级的任务，所有用户可以使用的任务数有56个。 在系统初始化时， 系统会默认创建一个最低优先级（63）的任务，这个任务只做一件事，就是不停的累加，在没有任务执行的时候，系统就执行这个任务。
uC/OS-II提供了任务管理的各种函数调用，包括创建任务，删除任务，改变任务的优先级，任务挂起和恢复等。

任务代码要有无限循环的结构
创建任务，就是从 `OSTCBFreeList`（空闲链表）取出一个空白TCB，填入任务信息后，将它同时插入 `OSTCBPrioTbl[]`（优先级索引表）和 `OSTCBList`（全局任务链表），最后判断是否立即调度。

µC/OS-II 任务控制块 (OS_TCB) 结构体定义

```c
typedef struct os_tcb {
    OS_STK    *OSTCBStkPtr;      // 指向任务堆栈栈顶的指针
    void      *OSTCBExtPtr;      // 指向任务控制块扩展的指针
    OS_STK    *OSTCBStkBottom;   // 指向任务堆栈栈底的指针
    INT32U    OSTCBStkSize;      // 任务堆栈的长度（单位：栈元素个数）
    INT16U    OSTCBOpt;          // 创建任务时的选择项（如是否允许堆栈检测）
    INT16U    OSTCBId;           // 目前该字段未被使用（保留）
    
    struct os_tcb *OSTCBNext;    // 指向下一个任务控制块的指针（双向链表）
    struct os_tcb *OSTCBPrev;    // 指向前一个任务控制块的指针（双向链表）
    
    INT16U    OSTCBDly;          // 任务等待的时限（Tick 数），0 表示不等待
    INT8U     OSTCBStat;         // 任务的当前状态（就绪/挂起/等待等）
    INT8U     OSTCBPrio;         // 任务的优先级（0~63，数值越小优先级越高）
    
    INT8U     OSTCBX;            // 就绪表行索引（用于快速访问就绪表）
    INT8U     OSTCBY;            // 就绪表列索引（用于快速访问就绪表）
    INT8U     OSTCBBitX;         // 就绪表行掩码（对应 OSTCBX 的位）
    INT8U     OSTCBBitY;         // 就绪表列掩码（对应 OSTCBY 的位）
} OS_TCB;

```

|字段|类型|说明|
|---|---|---|
|`OSTCBStkPtr`|`OS_STK*`|**栈顶指针**，指向当前任务堆栈的栈顶。任务切换时，CPU 寄存器内容从这里保存/恢复|
|`OSTCBExtPtr`|`void*`|指向 TCB 扩展结构的指针（用户可自定义扩展），默认未使用|
|`OSTCBStkBottom`|`OS_STK*`|**栈底指针**，指向任务堆栈的栈底，用于堆栈溢出检测|
|`OSTCBStkSize`|`INT32U`|任务堆栈的总长度（以 `OS_STK` 为单位），用于栈溢出检查和内存统计|
|`OSTCBOpt`|`INT16U`|任务创建选项，如 `OS_TASK_OPT_STK_CHK`（允许栈检测）等|
|`OSTCBId`|`INT16U`|保留字段，目前未被使用|
|`OSTCBNext`|`struct os_tcb*`|指向 TCB 双向链表中的**下一个** TCB|
|`OSTCBPrev`|`struct os_tcb*`|指向 TCB 双向链表中的**上一个** TCB|
|`OSTCBDly`|`INT16U`|任务等待的 Tick 数。`OSTimeTick()` 每次递减该值，减到 0 时任务变为就绪态|
|`OSTCBStat`|`INT8U`|任务状态：`OS_STAT_RDY`（就绪）、`OS_STAT_SUSPEND`（挂起）、`OS_STAT_WAITING`（等待事件）等|
|`OSTCBPrio`|`INT8U`|任务优先级（0~63），**数值越小优先级越高**，每个优先级只能有一个任务|
|`OSTCBX`|`INT8U`|就绪表**行索引**（0~7），由 `(prio >> 3)` 计算得到|
|`OSTCBY`|`INT8U`|就绪表**列索引**（0~7），由 `(prio & 0x07)` 计算得到|
|`OSTCBBitX`|`INT8U`|就绪表行掩码，由 `(1 << OSTCBX)` 计算，用于 O(1) 调度查表|
|`OSTCBBitY`|`INT8U`|就绪表列掩码，由 `(1 << OSTCBY)` 计算，用于 O(1) 调度查表|

- **栈指针 `OSTCBStkPtr`** 是 TCB 中最重要的字段。任务切换时，当前任务的 CPU 寄存器（R4~R11 等）保存在栈中，`OSTCBStkPtr` 指向这个保存位置的栈顶。
- **就绪表快速访问字段**（`OSTCBX/Y/BitX/BitY`）是为了实现 **O(1) 优先级查找**。µC/OS-II 不使用循环遍历，而是通过查表 `OSUnMapTbl` 直接定位最高优先级就绪任务。
- **双向链表**（`OSTCBNext` / `OSTCBPrev`）用于将所有 TCB 链接起来，便于系统遍历所有任务（如 `OSTimeTick()` 需要遍历所有任务递减 `OSTCBDly`）。
- **内存占用**：每个 TCB 约 40~50 字节。系统最多支持 64 个任务，TCB 总内存约 3KB。


堆栈空间是在建立任务之初由用户自己定义的一段内存空间。每个任务都必须有自己的堆栈空间，任务堆栈用于保存任务在执行过程中产生的重要数据。

### 任务状态
uC/OS-ll的任务有5种状态
睡眠态（DORMANT）：任务驻留在程序空间，还没有交给uCOS管理，即还没有配备任务控制块，还没有被创建。
就绪态（READY)：任务一旦建立，就进入就绪态准备运行，“万事具备，只欠CPU”。
运行态（RUNNING）：正在使用CPU的状态称运行态
等待态（WAITING)：等待某事件发生的状态.
中断服务态（ISR）：正在运行的任务被中断时进入的状态
![[ucosii任务状态.png]]

### 任务管理函数
#### `OSTaskCreate()`

用于建立一个新任务，使其加入UCOS的任务调度管理中。调用该函数时，需要提供任务代码的入口地址、传递给任务的参数指针、任务堆栈的栈顶指针以及任务的优先级。

```c
INT8U OSTaskCreate(void (*task)(void *pd), void *pdata, OS_STK *ptos, INT8U prio);

INT 表示整数（Integer）
8表示占用8 位（即 1 个字节）
U表示无符号（Unsigned），即数值范围 ≥ 0,相当于unsigned char
```

- **task**：指向任务代码的指针，即任务函数的入口地址。
- **pdata**：任务开始执行时，传递给任务的参数的指针。
- **ptos**：分配给任务的堆栈的栈顶指针。
- **prio**：分配给任务的优先级。

返回函数错误信息，如果没有错误返回OS_NO_ERR值。

在OS操作系统中，任务是系统最小最基本的元素。
在多任务环境启动之前，或在正在运行的任务中建立任务，在中断处理程序中不能建立任务。

#### `OSTaskCreateExt()`

`OSTaskCreateExt()` 是 `OSTaskCreate()` 的扩展版本，提供了更多功能，例如任务标识符、堆栈检验、浮点操作支持等。该函数需要9个参数，前4个与 `OSTaskCreate()` 相同。

```c
INT8U OSTaskCreateExt(void (*task)(void *pd), void *pdata, OS_STK *ptos, INT8U prio, INT16U id, OS_STK *pbos, INT32U stk_size, void *pext, INT16U opt);
```
- **task**：指向任务代码的指针。
- **pdata**：传递给任务的参数的指针。
- **ptos**：任务堆栈的栈顶指针。
- **prio**：任务的优先级。
- **id**：为任务创建的特殊标识符。
- **pbos**：指向任务堆栈栈底的指针，用于堆栈检验。
- **stk_size**：指定堆栈的容量（成员数目）。
- **pext**：指向用户附加数据域的指针，用于扩展任务的OS_TCB。
- **opt**：选项，用于指定是否允许堆栈检验、是否将堆栈清零、任务是否进行浮点操作等。



#### `OS_STK`

`OS_STK` 是UCOS中用于定义任务堆栈的数据类型。每个任务都有自己的堆栈，堆栈必须由连续的内存空间组成，并声明为 `OS_STK` 类型。堆栈空间可以静态分配，也可以动态分配。
```c
OS_STK TaskStack[STACK_SIZE];
```

- **STACK_SIZE**：堆栈的大小，由用户根据任务需求定义。

#### `OSTaskStkChk()`

用于检查任务堆栈的实际使用情况，以确定任务实际需要的堆栈空间大小。这有助于避免为任务分配过多的堆栈空间，从而减少应用程序所需的RAM空间。

```c
INT8U OSTaskStkChk(INT8U prio, OS_STK_DATA *pdata);
```

- **prio**：要检查堆栈的任务的优先级。
- **pdata**：指向 `OS_STK_DATA` 结构的指针，用于存储堆栈使用情况的信息（如堆栈已用大小和剩余大小）。
- 
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
#### `OSTaskDel()`

用于删除任务。删除任务是指将任务置于休眠态，任务代码本身不会被删除，只是不再被UCOS调度调用。调用该函数时，需确保被删除的任务不是空闲任务。

```c
INT8U OSTaskDel(INT8U prio);
```

- **prio**：要删除的任务的优先级。如果传入 `OS_PRIO_SELF`，表示删除调用该函数的任务自身。

返回函数错误信息，如果没有错误返回OS_NO_ERR值。
#### `OSTaskDelReq()`

用于请求删除某个任务。当一个任务占用了一些资源（如内存缓冲或信号量）时，若其他任务试图直接删除该任务，可能导致资源丢失。此时，被删除的任务应在使用完资源后主动释放资源，再删除自身。`OSTaskDelReq()` 用于向任务发出删除请求，由任务自身在适当时机响应并删除自己。

```c
INT8U OSTaskDelReq(INT8U prio);
```

- **prio**：要请求删除的任务的优先级。如果传入 `OS_PRIO_SELF`，表示请求删除调用该函数的任务自身。
#### `OSTaskChangePrio()`

用于在程序运行期间动态改变任务的优先级。任务在建立时会被分配一个优先级，但在运行过程中可以通过调用该函数进行调整。

```c
INT8U OSTaskChangePrio(INT8U oldprio, INT8U newprio);
```

- **oldprio**：任务当前的优先级。
- **newprio**：任务的新优先级。
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
#### `OSTaskSuspend()`

用于挂起任务。挂起操作是一个附加功能，如果任务在被挂起的同时也在等待延迟时间到，则需要先取消挂起操作，并且等待延迟时间到后，任务才能转入就绪状态。任务可以挂起自己，也可以挂起其他任务。


```c
INT8U OSTaskSuspend(INT8U prio);
```

- **prio**：要挂起的任务的优先级。如果传入 `OS_PRIO_SELF`，表示挂起调用该函数的任务自身。 
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
#### `OSTaskResume()`

用于恢复被挂起的任务。挂起的任务只有通过调用该函数才能被恢复。


```c
INT8U OSTaskResume(INT8U prio);
```
- **prio**：要恢复的任务的优先级。

#### `OSTaskQuery()`

用于获取自身或其他应用任务的信息。调用该函数可以查询任务的当前状态、堆栈使用情况等。


```c
INT8U OSTaskQuery(INT8U prio, OS_TCB *pdata);
```

- **prio**：要查询的任务的优先级。如果传入 `OS_PRIO_SELF`，表示查询调用该函数的任务自身。
- **pdata**：指向 `OS_TCB` 结构的指针，用于存储任务的信息。

返回函数错误信息，如果没有错误返回OS_NO_ERR值。