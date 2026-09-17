---
type: 知识库
scope: RTOS
doc_type: 操作系统/RTOS
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# FreeRTOS 基本概念

## 1. FreeRTOS 是什么

FreeRTOS 是一个**微内核、抢占式、可裁剪**的实时操作系统内核。它只提供"**任务调度 + 任务间通信/同步 + 时间 + 内存管理**"这几件事，**不提供**文件系统、网络协议栈、设备模型、图形界面——需要时由芯片 SDK、BSP 或第三方组件（LwIP、FatFs 等）补充。

```text
FreeRTOS = 任务调度器 + 同步/通信 + 软件定时器 + 内存管理
          （可运行在 Cortex-M / RISC-V / x86 / ... 上）
```

它**不等于**一个完整的操作系统（区别于 Linux）：没有 MMU/进程/用户态，任务是共享地址空间的"线程式"执行单元。

## 2. 内核的本质：多任务与调度

裸机程序是"一个大循环 + 中断"（前后台架构）。RTOS 把功能**拆成多个独立任务**，由内核决定"此刻该运行谁"：

```text
裸机：      main loop 顺序做完所有事  +  中断抢占
RTOS：      多个任务各管一件事，内核按优先级/事件在任务间切换
```

内核要回答的问题：

- 当前有哪些任务？
- 每个任务处于什么状态（运行/就绪/阻塞/挂起）？
- 哪些任务就绪？
- 当前最高优先级的就绪任务是谁？
- 什么时候切换（tick / 中断 / 任务主动让出 / 事件到来）？
- 切换时要保存/恢复哪些寄存器？

## 3. 基本概念

### 任务（Task）

调度的最小单位，本质是一个**永不返回**的函数（通常死循环），拥有独立的**栈**和 **TCB（任务控制块）**。

```c
void vTask(void *pv) { for (;;) { /* ... */ vTaskDelay(1); } }
```

### 调度器（Scheduler）

决定运行哪个任务。FreeRTOS 默认**抢占式**：高优先级就绪任务可以打断低优先级任务；同优先级可配**时间片轮转**。

### 上下文切换（Context Switch）

保存当前任务的寄存器到它的栈、恢复下一个任务的寄存器。Cortex-M 上由 **PendSV 异常**完成（SVC 用于启动第一个任务，SysTick 用于产生节拍）。

### 优先级（Priority）

- FreeRTOS 中**数值越大优先级越高**（与 uC/OS 相反，注意别混）。
- 数量由 `configMAX_PRIORITIES` 决定；空闲任务优先级为 0。

### 任务状态

| 状态 | 含义 |
|---|---|
| Running | 正在占用 CPU |
| Ready | 就绪，等待被调度 |
| Blocked | 阻塞：等延时到期或等待事件（队列/信号量…） |
| Suspended | 挂起：被显式 `vTaskSuspend()`，不参与调度 |

### 时间节拍（Tick）

由周期性的定时器中断（Cortex-M 用 SysTick）产生，是内核的时间基准，频率 `configTICK_RATE_HZ`。延时、超时、时间片都以 tick 为单位。

### 临界区（Critical Section）

一段"不能被中断/切换打断"的代码（`taskENTER_CRITICAL`），用于保护任务与 ISR 共享的数据。临界区应尽可能短，否则增大中断延迟。

### 任务间通信与同步

| 机制 | 用途 |
|---|---|
| 队列 Queue | 多对多传数据（值拷贝） |
| 信号量 Semaphore | 同步/计数（二值、计数） |
| 互斥量 Mutex | 保护共享资源（有所有权 + 优先级继承） |
| 任务通知 Notification | 最快的"一对一"同步/传值 |
| 事件组 EventGroup | 多任务等"多事件组合"（AND/OR） |

### 内存

内核对 TCB、栈、队列等的内存来自 `heap_x.c`；可**动态**（`xTaskCreate`）或**静态**（`xTaskCreateStatic`）分配。实时系统关键路径倾向静态分配（确定、无碎片）。

## 4. FreeRTOS 的构成

```text
① 通用内核     tasks.c  list.c  queue.c  timers.c  event_groups.c  stream_buffer.c
② 移植层       portable/<编译器>/<架构>/  port.c  portmacro.h  portasm
③ 配置         FreeRTOSConfig.h（行为/裁剪/时钟/内存等开关）
④ 板级/芯片    启动文件、向量表、链接脚本、时钟、串口、GPIO、SDK 驱动
```

> ④ 不属于 FreeRTOS 内核，属于 SDK/BSP。只下载内核不能直接变成某块板子的可烧写工程。

## 5. 一个最小例子（概念对照）

```c
#include "FreeRTOS.h"
#include "task.h"

void vTaskA(void *pv) { for (;;) { /* 高优先级任务 */ vTaskDelay(pdMS_TO_TICKS(100)); } }
void vTaskB(void *pv) { for (;;) { /* 低优先级任务 */ vTaskDelay(pdMS_TO_TICKS(500)); } }

int main(void)
{
    BOARD_InitHardware();                 /* 板级：时钟/引脚/串口 */
    xTaskCreate(vTaskA, "A", 256, NULL, 3, NULL);   /* 创建任务：栈/优先级/句柄 */
    xTaskCreate(vTaskB, "B", 256, NULL, 1, NULL);
    vTaskStartScheduler();                /* 启动调度器：建 idle/timer，SVC 进入第一个任务 */
    for (;;);                             /* 正常不会到这里 */
}
```

对应概念：**任务**（A/B）、**栈**（256）、**优先级**（3/1）、**调度器**（`vTaskStartScheduler`）、**时间节拍**（`vTaskDelay`）。

## 6. 术语速查

| 术语 | 含义 |
|---|---|
| Task / TCB | 任务 / 任务控制块 |
| Ready / Blocked / Suspended | 就绪 / 阻塞 / 挂起 |
| Tick | 系统节拍 |
| Preemption | 抢占 |
| Time slicing | 时间片轮转 |
| Context switch | 上下文切换 |
| Critical section | 临界区 |
| Priority inversion | 优先级反转（用互斥量优先级继承缓解） |
| FromISR | 中断安全 API 后缀 |
| Idle task | 空闲任务（优先级 0，回收被删任务） |
| Hook | 钩子函数（idle/tick/malloc-failed 回调） |

## 7. 常见理解误区

| 误区 | 纠正 |
|---|---|
| "用了 FreeRTOS 就是硬实时" | 硬/软实时由**产品 deadline** 决定，RTOS 只提供机制 |
| "任务优先级和中断优先级方向一样" | **任务越大越高；Cortex-M 中断越小越高**，两套方向 |
| "任务越多越好" | 任务多→栈/调度开销大、复杂度高；够用即可 |
| "队列传的就是引用" | 默认是**值拷贝**（传指针 = 拷贝指针值，注意指向内存的生命周期） |
| "二值信号量可以当锁" | 当锁要用**互斥量**（有所有权 + 优先级继承） |
| "`vTaskDelay` 能保证周期" | 会随执行时间漂移，周期任务用 **`vTaskDelayUntil`** |
| "串口打印时间能当实时基准" | 串口阻塞且不确定，应用 DWT/硬件定时器 + 逻辑分析仪 |
