---
type: 知识库
scope: RTOS
doc_type: 原理
status: 已整理
evidence: 源码确认
tags: [uC-OS-II, RTOS, 中断, 同步与IPC, 编译构建]
updated: 2026-09-17
---

# uC/OS-II

> 2026-09-17 精简：内核 API 参考与 STM32F103 学习笔记本是同一主题，合成一篇。

## 目录

- 一、ucos
- 二、μC/OS-II 多任务系统 — STM32F103C8T6 完整学习笔记

---

## 一、ucos

即实时操作系统，Real Time OS。
实时操作系统又分为硬实时和软实时。硬实时要求在规定的时间内必须完成操作，硬实时系统不允许超时，在软实时里面处理过程超时的后果就没有那么严格。

在实时操作系统中，我们可以把要**实现的功能划分为多个任务**，每个任务负责实现其中的一部分，每个任务都是一个很简单的程序，通常是个死循环。
RTOS操作系统:UCOS,FreeRTOS,RTX,RT-Thread,DJYOS等
RTOS操作系统的核心内容在于：实时内核。

RTOS的内核负责管理所有的任务，内核决定了运行哪个任务，何时停止当前任务切换到其他任务，这是内核的多任务管理能力。
多任务管理就好像芯片有多个CPL多任务管理实现了CPU资源的最大化利用，多任务管理有助于实现程序的模块化开发，能够实现复杂的实时应用。






## ucos

ucos是RTOS的一种，它的内核属于可剥夺内核，就是可以剥夺其他任务的CPU使用权，它总是运行就绪任务中的优先级最高的那个任务。
μC/OS-II 是**抢占式内核**——任何时候，CPU 上运行的永远是当前就绪的**最高优先级任务**。

从体系结构上来看,μC/OS-II的代码可以大致分成3大部分配置文件、与处
理器无关的源代码、与处理器相关的源代码
μC/OS-II只包含了进程调度、时钟管理、内存管理和进程间的通信与同步等基本功能，而没有I/O管理、文件系统、网络等额外的模块。

### 数据类型

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

### 任务
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

#### 任务状态
uC/OS-ll的任务有5种状态
睡眠态（DORMANT）：任务驻留在程序空间，还没有交给uCOS管理，即还没有配备任务控制块，还没有被创建。
就绪态（READY)：任务一旦建立，就进入就绪态准备运行，“万事具备，只欠CPU”。
运行态（RUNNING）：正在使用CPU的状态称运行态
等待态（WAITING)：等待某事件发生的状态.
中断服务态（ISR）：正在运行的任务被中断时进入的状态
![[90-附件/RTOS/ucosii任务状态.png]]

#### 任务管理函数
##### `OSTaskCreate()`

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

##### `OSTaskCreateExt()`

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



##### `OS_STK`

`OS_STK` 是UCOS中用于定义任务堆栈的数据类型。每个任务都有自己的堆栈，堆栈必须由连续的内存空间组成，并声明为 `OS_STK` 类型。堆栈空间可以静态分配，也可以动态分配。
```c
OS_STK TaskStack[STACK_SIZE];
```

- **STACK_SIZE**：堆栈的大小，由用户根据任务需求定义。

##### `OSTaskStkChk()`

用于检查任务堆栈的实际使用情况，以确定任务实际需要的堆栈空间大小。这有助于避免为任务分配过多的堆栈空间，从而减少应用程序所需的RAM空间。

```c
INT8U OSTaskStkChk(INT8U prio, OS_STK_DATA *pdata);
```

- **prio**：要检查堆栈的任务的优先级。
- **pdata**：指向 `OS_STK_DATA` 结构的指针，用于存储堆栈使用情况的信息（如堆栈已用大小和剩余大小）。
- 
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
##### `OSTaskDel()`

用于删除任务。删除任务是指将任务置于休眠态，任务代码本身不会被删除，只是不再被UCOS调度调用。调用该函数时，需确保被删除的任务不是空闲任务。

```c
INT8U OSTaskDel(INT8U prio);
```

- **prio**：要删除的任务的优先级。如果传入 `OS_PRIO_SELF`，表示删除调用该函数的任务自身。

返回函数错误信息，如果没有错误返回OS_NO_ERR值。
##### `OSTaskDelReq()`

用于请求删除某个任务。当一个任务占用了一些资源（如内存缓冲或信号量）时，若其他任务试图直接删除该任务，可能导致资源丢失。此时，被删除的任务应在使用完资源后主动释放资源，再删除自身。`OSTaskDelReq()` 用于向任务发出删除请求，由任务自身在适当时机响应并删除自己。

```c
INT8U OSTaskDelReq(INT8U prio);
```

- **prio**：要请求删除的任务的优先级。如果传入 `OS_PRIO_SELF`，表示请求删除调用该函数的任务自身。
##### `OSTaskChangePrio()`

用于在程序运行期间动态改变任务的优先级。任务在建立时会被分配一个优先级，但在运行过程中可以通过调用该函数进行调整。

```c
INT8U OSTaskChangePrio(INT8U oldprio, INT8U newprio);
```

- **oldprio**：任务当前的优先级。
- **newprio**：任务的新优先级。
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
##### `OSTaskSuspend()`

用于挂起任务。挂起操作是一个附加功能，如果任务在被挂起的同时也在等待延迟时间到，则需要先取消挂起操作，并且等待延迟时间到后，任务才能转入就绪状态。任务可以挂起自己，也可以挂起其他任务。


```c
INT8U OSTaskSuspend(INT8U prio);
```

- **prio**：要挂起的任务的优先级。如果传入 `OS_PRIO_SELF`，表示挂起调用该函数的任务自身。 
返回函数错误信息，如果没有错误返回OS_NO_ERR值。
##### `OSTaskResume()`

用于恢复被挂起的任务。挂起的任务只有通过调用该函数才能被恢复。


```c
INT8U OSTaskResume(INT8U prio);
```
- **prio**：要恢复的任务的优先级。

##### `OSTaskQuery()`

用于获取自身或其他应用任务的信息。调用该函数可以查询任务的当前状态、堆栈使用情况等。


```c
INT8U OSTaskQuery(INT8U prio, OS_TCB *pdata);
```

- **prio**：要查询的任务的优先级。如果传入 `OS_PRIO_SELF`，表示查询调用该函数的任务自身。
- **pdata**：指向 `OS_TCB` 结构的指针，用于存储任务的信息。

返回函数错误信息，如果没有错误返回OS_NO_ERR值。

---

## 二、μC/OS-II 多任务系统 — STM32F103C8T6 完整学习笔记

## μC/OS-II 多任务系统 — STM32F103C8T6 完整学习笔记

> **阅读指南**：本文档从零开始，按"硬件→系统软件→应用架构→实战调试"递进。
> 每个知识点附有**免费的网络资料链接**，优先官网/权威来源。

---

### 目录

1. [前置知识](#1-前置知识从裸机到-rtos)
2. [STM32 硬件基础](#2-stm32-硬件基础)
3. [μC/OS-II 内核原理](#3-ucos-ii-内核原理)
4. [Cortex-M3 底层机制](#4-cortex-m3-底层机制)
5. [工程架构与任务设计](#5-工程架构与任务设计)
6. [代码逐层构建](#6-代码逐层构建)
7. [调试实录：4 个 Bug 的完整排查](#7-调试实录4-个-bug-的完整排查)
8. [附录：寄存器速查 / 内存占用 / 术语表](#8-附录)

---

### 1. 前置知识：从"裸机"到 RTOS

#### 1.1 裸机编程的局限

传统单片机程序是一个 `while(1)` 大循环，所有任务按顺序轮询：

```c
while (1) {
    task_led_blink();
    task_button_check();
    task_sensor_read();
    task_display_update();
}
```

问题：
- 某个任务里的 `delay_ms(500)` 会**阻塞整个 CPU**，其他任务全部停止
- 紧急事件（按键）必须等到当前任务让出 CPU 才能处理
- 随着功能增多，代码复杂度爆炸

> **学习资源**：[STM32 裸机开发入门（CSDN）](https://blog.csdn.net/chenqinhuan/article/details/155983346)

#### 1.2 RTOS 解决的核心问题

RTOS（Real-Time Operating System）让**多个任务看起来像是在同时运行**：

```c
// 任务 A — 只关心 LED 闪烁
void TaskA(void) { while(1) { LED_TOGGLE(); OSTimeDly(500); } }

// 任务 B — 只关心按键检测
void TaskB(void) { while(1) { if (BUTTON_PRESSED()) do_something(); OSTimeDly(10); } }
```

每个任务写自己的逻辑，**延时不会阻塞其他任务**。操作系统按优先级分配 CPU：

```
时间轴: [A][A][B][A][C][B][A][A][B][C][A]...
```

**抢占式调度**是 μC/OS-II 的核心特征：高优先级任务就绪时，低优先级任务立刻被"抢断"。

> **学习资源**：
> - [FreeRTOS vs 裸机对比教程 (DigiKey)](https://www.digikey.com/en/maker/projects/what-is-a-realtime-operating-system-rtos/4d6e8e6f7fb84b6a9b1c6a9c0c8e9b1a)
> - [什么是 RTOS (YouTube — Shawn Hymel)](https://www.youtube.com/watch?v=F321087yYy4)

#### 1.3 为什么选择 μC/OS-II？

| 特性 | μC/OS-II | FreeRTOS |
|------|----------|----------|
| 代码量 | ~5,500 行 | ~9,000 行 |
| 内核书 | 《μC/OS-II: The Real-Time Kernel》(Labrosse 著) — 经典教材 | 无官方教材 |
| 调度算法 | O(1) 位图查找 | 可配置 (链表/位图) |
| 学习价值 | 代码极度清晰，适合教学 | 功能更多但较复杂 |

μC/OS-II 的源码几乎是一本摊开的教科书——每个数据结构、每个算法都清晰可读。

> **学习资源**：
> - [μC/OS-II 官方书籍 (Micrium)](https://www.micrium.com/rtos/ucos-ii/) — 官网可下载源码
> - [邵贝贝译《嵌入式实时操作系统 μC/OS-II》](https://wenku.csdn.net/doc/1q6xm4duda) — 中文权威译本
> - [任哲《嵌入式实时操作系统 μCOS-II 原理与应用》](https://wenku.csdn.net/doc/2wi9acpb9f) — 更适合入门

---

### 2. STM32 硬件基础

#### 2.1 STM32F103C8T6 概览

```
┌─────────────────────────────────────┐
│          STM32F103C8T6              │
│  • Cortex-M3 内核 @ 72MHz           │
│  • 64KB Flash / 20KB RAM            │
│  • 37 个 GPIO (PA0~PA15, PB0~PB15…) │
│  • 外部中断 (EXTI), USART, SPI, I²C   │
│  • 2×12-bit ADC, 3×通用定时器        │
└─────────────────────────────────────┘
```

> **学习资源**：
> - [STM32F103C8T6 数据手册 (ST 官网)](https://www.st.com/resource/en/datasheet/stm32f103c8.pdf) — 引脚定义、电气特性
> - [STM32F103xx 参考手册 RM0008 (ST 官网)](https://www.st.com/resource/en/reference_manual/cd00171190.pdf) — 寄存器级详解（**必读**）

#### 2.2 时钟系统

STM32 的时钟树是一切外设的基础：

```
  HSI (8MHz 内部 RC) ─┐
                       ├── PLL (×9) ── 72MHz → SYSCLK (系统时钟)
  HSE (8MHz 外部晶振)─┘            │
                               ┌───┴────┐
                          AHB (72MHz)   APB2 (72MHz → GPIO, EXTI, AFIO)
                                        APB1 (36MHz → 定时器, USART)
```

**核心规则**：使用任何外设之前，必须先使能其时钟！

```c
RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);  // GPIOA 在 APB2 上
RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOB, ENABLE);  // GPIOB 在 APB2 上
```

`SystemInit()` 函数（标准库 V3.5.0）负责：
1. 使能 HSE（外部 8MHz 晶振），等待起振
2. 设置 Flash 等待周期 = 2（72MHz 必须 2 个等待周期，否则 CPU 取指错误）
3. PLL = HSE × 9 = 72MHz
4. 切换 SYSCLK 到 PLL
5. 设置 AHB/APB1/APB2 预分频器

> **学习资源**：
> - [STM32 时钟树详解 (ST 官方 Application Note AN2867)](https://www.st.com/resource/en/application_note/an2867-guidelines-for-oscillator-design-on-stm8afals-and-stm32-mcusmpus-stmicroelectronics.pdf)
> - [STM32 时钟配置图文教程 (CSDN)](https://blog.csdn.net/chenqinhuan/article/details/155983346)

#### 2.3 GPIO（通用输入输出）

每个 GPIO 引脚可独立配置为 8 种模式之一：

| 模式 | 缩写 | 本工程用途 |
|------|------|-----------|
| **推挽输出** | GPIO_Mode_Out_PP | LED 驱动 (PA0~PA7) |
| **上拉输入** | GPIO_Mode_IPU | 按键检测 (PB11/PB12/PB15) |

**推挽输出**：输出 HIGH = 3.3V，输出 LOW = 0V。两个 MOSFET 轮流导通。
**上拉输入**：引脚通过内部 ~40kΩ 电阻连接到 VDD。引脚悬空时读 HIGH，
接地时读 LOW。这样按键只需一根线接到 GND，无需外接上拉电阻。

```c
// LED 输出配置
GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_0 | GPIO_Pin_1;  // 哪些引脚
GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;         // 推挽输出
GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;         // 输出速率
GPIO_Init(GPIOA, &GPIO_InitStructure);

// 按键输入配置
GPIO_InitStructure.GPIO_Pin  = GPIO_Pin_11 | GPIO_Pin_12 | GPIO_Pin_15;
GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;              // 上拉输入
GPIO_Init(GPIOB, &GPIO_InitStructure);
```

控制 LED 亮灭使用 BSRR 寄存器（**原子操作**，单条 STR 指令，不会出现读-改-写竞态）：

```c
GPIO_SetBits(GPIOA, GPIO_Pin_0);    // PA0 = HIGH → LED 亮
GPIO_ResetBits(GPIOA, GPIO_Pin_0);  // PA0 = LOW  → LED 灭
```

> **学习资源**：
> - [STM32 GPIO 原理深入 (博客园)](https://www.cnblogs.com/muziwood/p/18884024)
> - [GPIO 8 种模式详解 (程序员宅基地)](https://www.programmersought.com/article/755811863786/)

#### 2.4 NVIC（嵌套向量中断控制器）

Cortex-M3 的 NVIC 支持最高 240 个外部中断，每个可配置 0~15 共 16 级优先级。
优先级数值越小，实际优先级越高。

**优先级分组** (`NVIC_PriorityGroup_2`)：
```
8-bit 优先级寄存器:  [抢占:2bit] [子优先级:2bit] [保留:4bit]
                         0~3          0~3
```

抢占优先级高的 ISR 可以**打断**抢占优先级低的 ISR。
子优先级只在抢占优先级相同时才参与裁决。

```
本工程配置:
  EXTI15_10 (按键):  抢占=0, 子=0  ← 最高，不能被打断
  SysTick:           抢占=3, 子=3  ← 最低，绝对不能打断任何 ISR
  PendSV:            抢占=3        ← 最低，在所有 ISR 之后执行
```

> **学习资源**：
> - [Cortex-M3 NVIC 详解 (ARM 官方文档)](https://developer.arm.com/documentation/ddi0337/e/nested-vectored-interrupt-controller)
> - [STM32 NVIC 中断优先级分组 (正点原子)](http://www.openedv.com/docs/book-video/stm32/ApolloSTM32F4.html)

#### 2.5 EXTI（外部中断 / 事件控制器）

EXTI 可以将 GPIO 引脚的边沿（上升/下降）信号转化为硬件中断。

配置步骤：
1. GPIO 配置为上拉/下拉输入模式
2. `GPIO_EXTILineConfig()` 将 GPIO 引脚映射到 EXTI 线
3. `EXTI_Init()` 设置触发边沿（上升沿/下降沿/双边沿）
4. `NVIC_Init()` 设置中断优先级并使能

```c
// PB11 → EXTI11, 下降沿触发 (按键按下: 高→低)
GPIO_EXTILineConfig(GPIO_PortSourceGPIOB, GPIO_PinSource11);
EXTI_InitStructure.EXTI_Line    = EXTI_Line11;
EXTI_InitStructure.EXTI_Mode    = EXTI_Mode_Interrupt;
EXTI_InitStructure.EXTI_Trigger = EXTI_Trigger_Falling;
EXTI_InitStructure.EXTI_LineCmd = ENABLE;
EXTI_Init(&EXTI_InitStructure);
```

**注意**：EXTI9_5 共享一个 IRQ 通道 (EXTI9_5_IRQn)，EXTI15_10 共享另一个 (EXTI15_10_IRQn)。
ISR 中需要用 `EXTI_GetITStatus()` 判断具体是哪条线触发。

> **学习资源**：
> - [STM32 EXTI 外部中断详解 (电子发烧友)](https://www.elecfans.com/emb/stm32/20180312646288.html)
> - [ST 官方 EXTI 应用笔记](https://www.st.com/resource/en/application_note/an2970-external-interrupt-management-on-stm32-mcus-stmicroelectronics.pdf)

---

### 3. μC/OS-II 内核原理

#### 3.1 任务（Task）与任务控制块（TCB）

**任务**：一个永不返回的 C 函数（无限循环），拥有独立的栈空间和优先级。

```c
void MyTask(void *p_arg)
{
    (void)p_arg;
    while (1) {
        // 做该做的事
        OSTimeDly(100);  // 让出 CPU 100 个 tick
    }
}
```

**任务控制块（TCB）**：内核为每个任务维护的数据结构，包含：

```
字段            含义
─────────────────────────────────────────
OSTCBStkPtr  →  任务栈指针 (保存 CPU 寄存器快照)
OSTCBPrio    →  优先级 (0=最高, 63=最低)
OSTCBStat    →  状态: RDY(就绪) / SUSPEND(挂起) / 等待事件 / 延时中
OSTCBDly     →  延时剩余 tick 数 (SysTick 每次减 1，减到 0 就绪)
OSTCBX/Y     →  就绪表中的行列坐标
OSTCBNext    →  双向链表, 链接所有 TCB
```

每个优先级**只能有一个任务**。共 64 个优先级 (0~63)，系统保留 0~3 和 60~63 给内部使用。

> **学习资源**：
> - [μC/OS-II 任务管理源码分析 (CSDN)](https://programmersought.com/article/40936023064/)

#### 3.2 任务状态机

```
                    ┌──────────┐
     OSTaskCreate() │   就绪   │◄──────── 延时到期 / 事件获得
           ────────►│   RDY    │
                    └────┬─────┘
                         │ OS_Sched() 选出最高优先级就绪任务
                         ▼
                    ┌──────────┐
                    │   运行   │
                    │   RUN    │
                    └────┬─────┘
            OSTimeDly() │        OSSemPend() / OSMboxPend()
                         │        (资源不可用)
            ┌────────────┴─────────────┐
            ▼                          ▼
      ┌──────────┐              ┌──────────┐
      │   延时   │              │   等待   │
      │  DLY     │              │  WAIT    │
      └──────────┘              └──────────┘
```

#### 3.3 抢占式优先级调度 — O(1) 位图算法

μC/OS-II 用**两级位图**记录 64 个优先级中哪些处于就绪状态：

```
OSRdyGrp  (8 位):  每一 bit 代表一个优先级组
OSRdyTbl[8] (8×8): 每个 byte 内按位标记该组内的就绪任务

查找最高就绪优先级 → OSUnMapTbl[256] 查表 (预先算好的 256 个值)，O(1):
  y = OSUnMapTbl[OSRdyGrp];          // 最高就绪任务在第几组
  x = OSUnMapTbl[OSRdyTbl[y]];       // 最高就绪任务在组内第几位
  prio = (y << 3) + x;               // 拼出优先级
```

**触发调度的时机**（任一个都会调用 `OS_Sched()`）：
- 任务调用 `OSTimeDly()` 主动让出 CPU
- 任务调用 `OSSemPend()` 等函数，但资源不可用
- ISR 结束时的 `OSIntExit()` — 如果 ISR 使某个高优先级任务就绪

> **学习资源**：
> - [μC/OS-II 调度算法详解 (程序员宅基地)](https://www.programmersought.com/article/77944473490/)

#### 3.4 系统时钟节拍（SysTick）

μC/OS-II 的"心跳"是一个周期性定时中断。每次中断：

```
SysTick_Handler()
  → OSTimeTick()
      → 遍历所有 TCB
          → OSTCBDly--  (如果 > 0)
          → 如果减到 0 且任务未被挂起 → 加入就绪表
  → OSIntExit()
      → 如果有更高优先级任务就绪 → 触发任务切换
```

```
OS_TICKS_PER_SEC = 100 → 节拍周期 = 10ms

OSTimeDly(50) → 延时 50 ticks = 500ms
                每 10ms: OSTCBDly-- (50→49→...→0)
                减到 0 → 任务重新就绪 → 等待被调度
```

> **注意**：`OSTimeDly(1)` 实际延时是 0~10ms，取决于距离下一个 tick 还有多久。

> **学习资源**：
> - [SysTick 定时器详解 (ARM 官方)](https://developer.arm.com/documentation/ddi0337/e/system-timer--systick)

#### 3.5 临界区保护

μC/OS-II 修改全局数据结构（就绪表、TCB 链表等）时必须**关中断**，防止 ISR 打断导致数据不一致。

本工程使用**方式 3**（Cortex-M3 推荐方式）：

```c
#define OS_ENTER_CRITICAL()  { cpu_sr = OS_CPU_SR_Save(); }  // 读 PRIMASK → 关中断
#define OS_EXIT_CRITICAL()   { OS_CPU_SR_Restore(cpu_sr); }  // 恢复 PRIMASK
```

OS_CPU_SR_Save 用汇编实现：
```asm
MRS  R0, PRIMASK    ; 读取当前中断屏蔽状态
CPSID I             ; 屏蔽所有可屏蔽中断 (PRIMASK=1)
BX   LR             ; 返回, R0=之前的状态
```

#### 3.6 IPC 机制：信号量、邮箱、队列、互斥量

μC/OS-II 提供四种任务间通信（IPC）机制，底层都用统一的**事件控制块（ECB）**管理：

```
ECB 结构体:
  OSEventType → 类型标记 (SEM / MBOX / Q / MUTEX)
  OSEventCnt  → 信号量计数
  OSEventPtr  → 邮箱指向消息 | 队列指向 OS_Q 结构
  OSEventGrp  + OSEventTbl[] → 等待该事件的任务位图
```

##### 3.6.1 信号量（Semaphore）

**用途**：任务间同步——"你做完我才能开始"。

```c
Sem = OSSemCreate(0);         // 初始计数 0 (事件尚未发生)

Task B: OSSemPost(Sem);       // 计数+1 → Task C 被唤醒
Task C: OSSemPend(Sem, 0);    // 阻塞，直到计数 > 0
```

##### 3.6.2 邮箱（Mailbox）

**用途**：传递一个 `void*` 指针。ISR 可以往邮箱发消息。

```c
Mbox = OSMboxCreate((void*)0);          // 空邮箱

ISR:   OSMboxPost(Mbox, (void*)&data);  // ISR 发送（不阻塞）
TaskC: p = OSMboxPend(Mbox, 1);         // 1 tick 超时 = 非阻塞轮询
```

##### 3.6.3 消息队列（Queue）

**用途**：存储多个消息，FIFO 顺序。邮箱只能存 1 个消息，队列可以存 N 个。

```c
void *buf[20];
Queue = OSQCreate(&buf[0], 20);   // 20 个槽的队列

Task C: OSQPost(Queue, &data);    // 入队 (FIFO)
Task F: OSQPend(Queue, 0);        // 出队 (阻塞等待)
```

##### 3.6.4 互斥量（Mutex）

**用途**：保护共享资源的互斥访问，**内置优先级反转保护**。

```
优先级反转问题:
  Task L (低优先级) 持有互斥量
  Task H (高优先级) 等待互斥量 → 被阻塞
  Task M (中优先级) 抢占 Task L → Task H 被无限期延迟!

解决方法 (优先级天花板):
  OSMutexCreate(9) → 天花板 = 9
  Task L 获取互斥量时，优先级临时提升到 9
  这样 Task M 无法抢占 Task L，Task L 能尽快释放互斥量
```

```c
Mutex = OSMutexCreate(9);       // 优先级天花板 = 9
OSMutexPend(Mutex, 0);          // 获取
OSMutexPost(Mutex);             // 释放
```

> **学习资源**：
> - [μC/OS-II 信号量/邮箱/队列详解 (程序员宅基地)](https://www.programmersought.com/article/15513986850/)
> - [优先级反转与解决方法 (维基百科)](https://en.wikipedia.org/wiki/Priority_inversion)

---

### 4. Cortex-M3 底层机制

#### 4.1 双栈机制：MSP vs PSP

Cortex-M3 有两个栈指针，用于隔离操作系统和任务：

| 栈指针 | 全称 | 使用场景 |
|--------|------|---------|
| **MSP** | Main Stack Pointer | 复位后默认使用；Handler 模式（中断服务程序）使用；内核自身使用 |
| **PSP** | Process Stack Pointer | 每个用户任务使用自己的 PSP |

```
          ┌──────────┐        ┌──────────┐
ISR 进入  │  MSP     │ 退出时 │  PSP     │ (可选, 由 EXC_RETURN 决定)
          └──────────┘        └──────────┘
              ↑                    ↑
         内核/中断栈           任务 A/B/C 各自的栈
```

**为什么需要两个栈**：如果所有代码共用 MSP，一个任务的栈溢出可能破坏 ISR 栈帧，导致系统崩溃。
分离后，任务栈的越界不会影响中断处理。

> **学习资源**：
> - [Cortex-M3 双栈机制 (ARM 官方文档 5.4 节)](https://developer.arm.com/documentation/ddi0337/e/programmers-model/stack-pointers)

#### 4.2 PendSV：专为 RTOS 设计的异常

PendSV（Pendable Service Call）是 Cortex-M3 的一个系统异常，
被**刻意配置为最低优先级**，用于实现延迟的上下文切换。

**设计原理**：当 ISR（如 SysTick）决定需要切换任务时，只是**挂起** PendSV，
然后正常退出 ISR。待所有更高优先级的 ISR 处理完毕后，
CPU 才进入 PendSV 执行上下文切换。这保证了上下文切换**永远在最安全的时刻**发生。

```
SysTick ISR 发现需要切换:
  → 设置 ICSR.PENDSVSET = 1  (挂起 PendSV)
  → ISR 返回

CPU 检查中断队列:
  → 有其他 ISR 在处理?  → 先处理它们
  → 只剩 PendSV?       → 执行上下文切换
```

> **学习资源**：
> - [ARM 官方 PendSV 说明](https://developer.arm.com/documentation/107706/0100/System-exceptions/Pended-SVC---PendSV)
> - [Cortex-M3 技术参考手册 (DDI0337E)](https://developer.arm.com/documentation/ddi0337/e)

#### 4.3 异常入口与返回：EXC_RETURN

Cortex-M3 进入异常时，硬件自动完成以下操作：
1. 将 **xPSR, PC, LR, R12, R3, R2, R1, R0** 这 8 个寄存器压入当前栈
2. 将 LR 设置为 **EXC_RETURN** 值（决定返回后的模式和栈）：

```
EXC_RETURN = 0xFFFFFFF1 → 返回 Handler 模式, 使用 MSP
EXC_RETURN = 0xFFFFFFF9 → 返回 Thread 模式, 使用 MSP
EXC_RETURN = 0xFFFFFFFD → 返回 Thread 模式, 使用 PSP     ← μC/OS-II 需要这个!
```

异常返回时执行 `BX LR`。如果 LR = 0xFFFFFFFD，硬件自动：
- 使用 PSP 弹出 8 个寄存器（xPSR, PC, LR, R12, R3~R0）
- 进入 Thread 模式

**PendSV 汇编处理器必须保留 R4~R11**（被调用者保存寄存器），这 8 个加上硬件自动处理的 8 个，
恰好覆盖了 CPU 的全部 16 个通用寄存器。

#### 4.4 PendSV 上下文切换完整流程

```
PendSV_Handler:                          (os_cpu_a.asm)
  1. PUSH {R14}          ← 保存 EXC_RETURN (0xFFFFFFF9)
  2. MRS  R0, PSP        ← 读出当前任务的 PSP
  3. STM  R0, {R4-R11}   ← 将 R4-R11 保存到当前任务栈
  4. STR  R0, [TCB]      ← 更新当前 TCB 的栈指针
  5.
  6. BLX  OSTaskSwHook   ← 内核钩子 (首次切换时在这里启动 SysTick)
  7.
  8. LDR  R2, =OSTCBHighRdy
  9. LDR  R0, [R2]       ← 读出新任务的栈指针
 10. LDM  R0, {R4-R11}   ← 从新任务栈恢复 R4-R11
 11. ADDS R0, #0x20      ← 跳过硬件栈帧
 12. MSR  PSP, R0        ← 设置 PSP = 新任务栈
 13.
 14. POP  {R14}          ← 恢复 EXC_RETURN
 15. ORR  LR, LR, #0x04  ← 0xFFFFFFF9 → 0xFFFFFFFD (Thread+PSP)
 16. CPSIE I             ← 开中断
 17. BX   LR             ← 异常返回 → 硬件弹出 8 寄存器 → 新任务开始执行
```

> **学习资源**：
> - [RTOS 上下文切换详解 (Zephyr RTOS 源码 `swap.S`)](https://github.com/zephyrproject-rtos/zephyr/blob/main/arch/arm/core/swap.S) — 工业级实现，注释详尽
> - [ARM Cortex-M3 异常模型](https://developer.arm.com/documentation/ddi0337/e/exception-model)

---

### 5. 工程架构与任务设计

#### 5.1 总体架构

```
┌──────────────────────────────────────────────────┐
│                    main()                         │
│  自检(LED0 闪 3 下) → BSP_Init → OSInit          │
│  → App_Init(创建 6 任务 + 5 IPC 对象) → OSStart   │
└───────────────────────┬──────────────────────────┘
                        │ 永不返回
                        ▼
┌──────────────────────────────────────────────────┐
│               μC/OS-II 调度器                      │
│                                                   │
│  通道 1 (串行管道):                               │
│    Task A(5) ──挂起/复苏──► Task B(6)             │
│       │ PA0 1Hz               │ PA1 10Hz          │
│       │ 10次后                │ 20次后             │
│       ▼                       ▼                   │
│    Task A 挂起            信号量 → Task C(7)       │
│                                    │ 变速闪 PA0    │
│                                    │ 数据入队      │
│                                    ▼               │
│                               Task F(8)            │
│                               出队 → N%8 个 LED 亮 │
│                                                   │
│  通道 2 (互斥量):                                  │
│    Task D(9) PB12→获/释放 Mutex→PA2 亮/灭         │
│    Task E(10) PB15→获/释放 Mutex→PA3 亮/灭        │
│                                                   │
│  外部中断:                                         │
│    PB11 按键 → EXTI11 → 计数+1 → 邮箱 → Task C    │
└──────────────────────────────────────────────────┘
```

#### 5.2 设计理念：管道式任务链

Task A → Task B → Task C 构成一条**串行触发管道**：

- **Task A 完成** 触发 **Task B 启动**（通过挂起/复苏）
- **Task B 完成** 触发 **Task C 启动**（通过信号量）
- **Task C** 进入无限循环，持续处理 ISR 发来的数据
- **Task C 产生数据** → **Task F 消费**（通过消息队列）

**为什么不用全局变量轮询？**
轮询浪费 CPU 且无法获得操作系统对优先级和阻塞的正确支持。
信号量/队列让任务在内核层面"真正阻塞"，不消耗 CPU。

#### 5.3 优先级分配原则

```
Task A: prio 5  (最高用户任务) → 最先运行，完成自证
Task B: prio 6  → A 复苏后才运行
Task C: prio 7  → B 发信号后才运行
Task F: prio 8  → 消费队列数据，优先级高于 D/E，保证数据处理及时
Task D: prio 9  → 互斥量演示，低优先级轮询
Task E: prio 10 → 最低用户任务
```

> **策略**：生产者（C）优先级高于消费者（F），确保数据先产生再消费。
> 轮询型任务（D/E）用最低优先级，不干扰数据管道。

#### 5.4 文件结构

```
F:\project\ucos2\
├── APP/                   应用层 (app.c + app_cfg.h)
├── BSP/                   硬件抽象层 (bsp.c + bsp.h)
├── UCOS-II/
│   ├── Source/            内核 (os_core/os_task/os_sem/os_mbox/os_q/os_mutex/os_time…)
│   └── Port/              移植层 (os_cpu.h / os_cpu_c.c / os_cpu_a.asm)
├── USER/                  入口 (main.c / stm32f10x_it.c / os_cfg.h / 启动文件)
├── Objects/               编译中间文件
└── Listings/              列表文件 (.map 可用于分析内存占用)
```

**外部依赖** (`F:\project\test\`)：
```
F:\project\test\
├── Start/                 CMSIS (core_cm3.c, system_stm32f10x.c, stm32f10x.h)
└── Library/               STM32 标准外设库 V3.5.0 (gpio/rcc/exti/flash/misc.c)
```

#### 5.5 Keil MDK 关键配置

| 选项 | 值 | 说明 |
|------|-----|------|
| Device | STM32F103C8 | 64KB Flash / 20KB RAM |
| Define | `STM32F10X_MD, USE_STDPERIPH_DRIVER` | 中容量型号 + 使用标准外设库 |
| 优化 | -O1 | 平衡代码大小和可调试性 |
| Include Paths | `.\APP; .\BSP; .\UCOS-II\Source; .\UCOS-II\Port; .\USER; ..\test\Start; ..\test\Library` | 6 个头文件搜索路径 |

---

### 6. 代码逐层构建

#### 6.1 BSP 层（硬件抽象）

BSP (**B**oard **S**upport **P**ackage) 将所有硬件操作封装为简单宏和函数，
上层应用不接触任何寄存器地址。

**LED 宏设计** (高电平=亮，因为 LED 阳极接 IO，阴极接 GND)：

```c
#define LED0_ON()     GPIO_SetBits(GPIOA, GPIO_Pin_0)    // 输出 3.3V → LED 亮
#define LED0_OFF()    GPIO_ResetBits(GPIOA, GPIO_Pin_0)  // 输出 0V   → LED 灭
#define LED0_TOGGLE() (GPIO_ReadOutputDataBit(..., Pin_0) \
                        ? LED0_OFF() : LED0_ON())          // 翻转
```

**按键读取宏**：
```c
// 上拉输入 — 松手=HIGH, 按下=LOW
#define INPUT1_IS_HIGH() (GPIO_ReadInputDataBit(GPIOB, GPIO_Pin_12) == Bit_SET)
```

#### 6.2 主函数启动流程

```c
int main(void)
{
    // ① 最小初始化 + 自检 (最早执行，不依赖任何 RTOS)
    SystemInit();  // 72MHz
    GPIOA 时钟 + PA0/PA1 推挽输出
    LED0 慢闪 3 下 (软件延时 for 循环)  ← 证明硬件/下载正常

    // ② 正式初始化
    BSP_Init();    // GPIO/EXTI/NVIC 全部初始化
    OSInit();      // μC/OS-II 内核 (创建空闲任务+统计任务)
    App_Init();    // 创建 6 个任务 + 5 个 IPC 对象

    // ③ 启动调度器
    OSStart();     // 永不返回!
}
```

**为什么需要自检**：如果 uCOS 启动失败，用户看到"什么都不亮"，
无法判断是"代码没烧进去"还是"调度器卡死"。自检在 RTOS 启动**之前**独立运行，
可以快速排除硬件和下载问题。

#### 6.3 App_Init — 内核对象与任务创建

```c
void App_Init(void)
{
    // 创建 IPC 对象
    Sem_BC      = OSSemCreate(0);                // 信号量 (B→C)
    Mbox_IntCnt = OSMboxCreate((void*)0);        // 邮箱 (ISR→C)
    Queue_CF    = OSQCreate(&buf[0], 20);        // 队列 (C→F)
    Mutex_D     = OSMutexCreate(9);              // 互斥量 D (天花板=9)
    Mutex_E     = OSMutexCreate(10);             // 互斥量 E (天花板=10)

    // 创建 6 个任务
    OSTaskCreate(TaskA, 0, &StkA[63], 5);       // 优先级 5, 栈 256B
    OSTaskCreate(TaskB, 0, &StkB[63], 6);
    // ... C(7), F(8), D(9), E(10)

    // Task B 初始挂起 (等待 A 完成后复苏)
    OSTaskSuspend(6);
}
```

#### 6.4 任务实现要点

**Task B 启动时机**：A 的 `while(1)` 在第 20 次 toggle 后调用
`OSTaskResume(6)` 复苏 B，然后 `OSTaskSuspend(OS_PRIO_SELF)` 挂起自己。

**Task C 两种闪烁频率**：
```c
if (intr_count < 5)
    dly = OS_TICKS_PER_SEC / 2;       // 500ms → 1Hz
else if (intr_count < 10)
    dly = OS_TICKS_PER_SEC / 20;      // 50ms  → 10Hz
else
    dly = OS_TICKS_PER_SEC / 2;       // 回退 1Hz
```

**Task F**：从队列取出数据后，`n = data % 8`，先全灭再亮前 n 个 LED。
因为 LED 是"高电平=亮"，所以 `GPIO_SetBits` 是亮，`GPIO_ResetBits` 是灭。

#### 6.5 ISR 模板

所有 μC/OS-II ISR 必须遵循同一模式：

```c
void EXTI15_10_IRQHandler(void)
{
    OS_ENTER_CRITICAL();
    OSIntNesting++;            // 记录中断嵌套
    OS_EXIT_CRITICAL();

    // --- 实际中断处理 (可调用 OS???Post) ---
    EXTI_ClearITPendingBit(EXTI_Line11);
    g_ext_int_count++;
    OSMboxPost(Mbox_IntCnt, (void*)&g_mbox_data);

    OSIntExit();               // 递减 OSIntNesting → 必要时触发调度
}
```

**`OSIntNesting` 的作用**：记录嵌套深度。只在最外层 ISR 退出时
（值为 0）才调用 `OS_Sched()`，避免在嵌套 ISR 中做上下文切换导致状态错乱。

---

### 7. 调试实录：4 个 Bug 的完整排查

#### Bug 1：SysTick 未启动

**现象**：上电后 LED0 不亮（自检也没有 → 代码不完整时的状态）。

**根因**：`OSTaskSwHook()` 为空函数，`main()` 和 `OSStart()` 也未调用 `SysTick_Config()`。

**修复**：在 `OSTaskSwHook()` 首次调用时执行 `SysTick_Config(SystemCoreClock / 100)`。
选择这个时机是因为 PendSV 已经完成第一次上下文切换，`OSRunning == TRUE`，
SysTick 中断能安全触发 `OSIntExit()`。

**同时**：`OSStart()` 中 `OSStartHighRdy()` 之前也添加 `SysTick_Config()` 作为双重保险。

#### Bug 2：EXC_RETURN 丢失（最致命）

**现象**：自检 3 闪通过。OSStart 快闪通过。PendSV 进入（LED1 亮）。Task A 从未运行。系统静默。

**根因分析**（最复杂的一个 Bug）：

```
Cortex-M3 硬件进入 PendSV → LR = 0xFFFFFFF9 (EXC_RETURN, Thread+MSP)
向量表 → PendSV_Handler (C 函数)
    ↓ C 编译器的 BL 指令
    LR = 返回地址 (0x0800xxxx)          ← EXC_RETURN 丢失!
    ↓
OS_CPU_PendSVHandler (汇编):
    PUSH {R14}       ← 保存的是 BL 返回地址，不是 EXC_RETURN
    BLX OSTaskSwHook ← LR 再次变化
    POP {R14}        ← 恢复 BL 返回地址
    ORR LR, #0x04    ← 0x0800xxxx | 0x04 → 垃圾值!
    BX LR            ← 异常返回失败 → HardFault → 死机
```

**修复**：完全绕过 C 包装函数。在汇编文件中直接 `EXPORT PendSV_Handler`，
让硬件中断向量**直接跳入汇编代码**，此时 LR 仍然是 EXC_RETURN：

```asm
PendSV_Handler                   ; ← 硬件直接跳入，LR = EXC_RETURN
        PUSH    {R14}            ; 第一时间保存 EXC_RETURN
        CPSID   I
        B       Pendsv_start    ; 跳入正文（跳过 OS_CPU_PendSVHandler 的二次 PUSH）
```

同时将 C 文件中的 `PendSV_Handler` 删除，避免链接器报重复定义。

**教训**：当汇编函数被 C 函数通过 `BL` 调用时，进入汇编时 LR 已经**不是**硬件给的原始值。
任何依赖 EXC_RETURN 的操作必须在 BL 之前（即汇编直接入口处）完成。

#### Bug 3：去抖逻辑的反作用

**现象**：PB11 按键失效，LED 数量不响应。

**一次失败的修复**：

```c
// 意图: 去抖 50ms
static volatile INT32U last_tick = 0;
if (OSTime - last_tick >= 5u) {   // ❌ OSTime 初始=0, last_tick=0, 0>=5 永远为假!
    last_tick = OSTime;
    // 处理按键...
}
```

`OSTime` 从 0 开始递增，`last_tick` 初始也为 0。条件 `0 >= 5` 永远不成立，
所有按键事件被丢弃。加上去抖后按键反而**完全失灵**。

**修复**：移除去抖。机械按键抖动虽然会导致一次按压产生 2~3 个 EXTI，
但在这个教学项目中影响不大，反而有助于快速验证 Task F 对 N%8 的响应。

#### Bug 4：互斥量状态跟踪与 LED 不一致

**现象**：PB12/PB15 按下时 LED2/LED3 不灭。

**根因**：

```c
// 原始代码
} else {                        // 按钮按下 (LOW)
    if (has_mutex) {            // ← 如果 has_mutex = 0 (获取失败/状态错乱)
        OSMutexPost(Mutex_D);   //    这个分支不会进入
        has_mutex = 0;
        LED2_OFF();             //    LED2_OFF() 永远不会被调用!
    }
}
```

**修复**：将 `LED2_OFF()` 移到 `if (has_mutex)` 判断之外：

```c
} else {
    if (has_mutex) {
        OSMutexPost(Mutex_D);
        has_mutex = 0;
    }
    LED2_OFF();                 // 无论如何，按钮按下时强制灭灯
}
```

这样即使互斥量状态跟踪出了错，按下按钮的视觉效果（灯灭）依然正确。

---

### 8. 附录

#### 8.1 内存占用估算

```
μC/OS-II 内核代码:       ~3.0 KB
6 个任务栈 (2×400 + 4×256): ~1.8 KB
Idle + Stat 任务栈:      ~0.5 KB
内核对象 (ECB+TCB+队列):  ~1.0 KB
标准外设库 (.data/.bss):  ~0.5 KB
MSP (主栈):              ~1.0 KB
─────────────────────────────────
总计:                    ~7.8 KB / 20 KB RAM (39%)
```

#### 8.2 关键寄存器速查

| 寄存器 | 地址 | 字段 |
|--------|------|------|
| ICSR | 0xE000ED04 | bit28=PENDSVSET (挂起 PendSV), bit27=PENDSVCLR |
| SHPR3 | 0xE000ED20 | [31:24]=SysTick, [23:16]=PendSV 优先级 |
| NVIC_ST_CTRL | 0xE000E010 | bit0=ENABLE, bit1=TICKINT, bit2=CLKSOURCE |
| NVIC_ST_RELOAD | 0xE000E014 | 24-bit 重装值 (本工程: 719999) |
| NVIC_ST_CURRENT | 0xE000E018 | 24-bit 当前值 |
| GPIOA_BSRR | 0x40010810 | [31:16]=BR (复位), [15:0]=BS (置位) |
| GPIOB_IDR | 0x40010C08 | 输入数据寄存器 |
| EXTI_PR | 0x40010414 | 挂起寄存器 (写 1 清除) |

#### 8.3 术语对照

| 缩写 | 全称 | 中文 |
|------|------|------|
| RTOS | Real-Time Operating System | 实时操作系统 |
| TCB | Task Control Block | 任务控制块 |
| IPC | Inter-Process Communication | 任务间通信 |
| ISR | Interrupt Service Routine | 中断服务例程 |
| NVIC | Nested Vectored Interrupt Controller | 嵌套向量中断控制器 |
| EXTI | External Interrupt | 外部中断 |
| PendSV | Pendable Service Call | 可挂起系统调用 |
| PSP | Process Stack Pointer | 进程栈指针 |
| MSP | Main Stack Pointer | 主栈指针 |
| BSP | Board Support Package | 板级支持包 |
| CMSIS | Cortex Microcontroller Software Interface Standard | ARM 软件接口标准 |
| HSE | High-Speed External | 外部高速晶振 |
| PLL | Phase-Locked Loop | 锁相环 |

---

> **工程地址**: `F:\project\ucos2\`
> **最后更新**: 2026-06-29

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/RTOS/FreeRTOS.md|FreeRTOS]]
