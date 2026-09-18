---
type: 知识库
scope: RTOS
doc_type: 原理
status: 待验证
evidence: 实机验证
tags: [FreeRTOS, RTOS, 启动, 编译构建, 同步与IPC]
updated: 2026-09-17
---

# FreeRTOS

> 2026-09-17 精简：原本是一个文档被拆成 00–11 共 12 个文件（外加移植、实时性两篇），现合回一个文件，标题统一降为二级。

## 目录

- 一、FreeRTOS 基本概念
- 二、FreeRTOS 任务与调度
- 三、FreeRTOS 时间管理
- 四、FreeRTOS 队列与信号量
- 五、FreeRTOS 任务通知 / 事件组 / 流缓冲区
- 六、FreeRTOS 内存管理
- 七、FreeRTOS 中断 / 临界区 / 配置 / 移植
- 八、FreeRTOS 调试统计与面试题
- 九、RTOS 横向对比（FreeRTOS / uC/OS / RT-Thread / Zephyr / 其它）
- 十、工程实践：FRDM-IMX95-PRO / Cortex-M7 上跑 FreeRTOS
- 十、实时性测试（Cortex-M7 / FreeRTOS）
- 一、验证优先级抢占的方法（忙等+阻塞）
- 十、FreeRTOS 移植学习
- 二、FreeRTOS实时性

---

## 一、FreeRTOS 基本概念

## FreeRTOS 基本概念

### 1. FreeRTOS 是什么

FreeRTOS 是一个**微内核、抢占式、可裁剪**的实时操作系统内核。它只提供"**任务调度 + 任务间通信/同步 + 时间 + 内存管理**"这几件事，**不提供**文件系统、网络协议栈、设备模型、图形界面——需要时由芯片 SDK、BSP 或第三方组件（LwIP、FatFs 等）补充。

```text
FreeRTOS = 任务调度器 + 同步/通信 + 软件定时器 + 内存管理
          （可运行在 Cortex-M / RISC-V / x86 / ... 上）
```

它**不等于**一个完整的操作系统（区别于 Linux）：没有 MMU/进程/用户态，任务是共享地址空间的"线程式"执行单元。

### 2. 内核的本质：多任务与调度

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

### 3. 基本概念

#### 任务（Task）

调度的最小单位，本质是一个**永不返回**的函数（通常死循环），拥有独立的**栈**和 **TCB（任务控制块）**。

```c
void vTask(void *pv) { for (;;) { /* ... */ vTaskDelay(1); } }
```

#### 调度器（Scheduler）

决定运行哪个任务。FreeRTOS 默认**抢占式**：高优先级就绪任务可以打断低优先级任务；同优先级可配**时间片轮转**。

#### 上下文切换（Context Switch）

保存当前任务的寄存器到它的栈、恢复下一个任务的寄存器。Cortex-M 上由 **PendSV 异常**完成（SVC 用于启动第一个任务，SysTick 用于产生节拍）。

#### 优先级（Priority）

- FreeRTOS 中**数值越大优先级越高**（与 uC/OS 相反，注意别混）。
- 数量由 `configMAX_PRIORITIES` 决定；空闲任务优先级为 0。

#### 任务状态

| 状态 | 含义 |
|---|---|
| Running | 正在占用 CPU |
| Ready | 就绪，等待被调度 |
| Blocked | 阻塞：等延时到期或等待事件（队列/信号量…） |
| Suspended | 挂起：被显式 `vTaskSuspend()`，不参与调度 |

#### 时间节拍（Tick）

由周期性的定时器中断（Cortex-M 用 SysTick）产生，是内核的时间基准，频率 `configTICK_RATE_HZ`。延时、超时、时间片都以 tick 为单位。

#### 临界区（Critical Section）

一段"不能被中断/切换打断"的代码（`taskENTER_CRITICAL`），用于保护任务与 ISR 共享的数据。临界区应尽可能短，否则增大中断延迟。

#### 任务间通信与同步

| 机制 | 用途 |
|---|---|
| 队列 Queue | 多对多传数据（值拷贝） |
| 信号量 Semaphore | 同步/计数（二值、计数） |
| 互斥量 Mutex | 保护共享资源（有所有权 + 优先级继承） |
| 任务通知 Notification | 最快的"一对一"同步/传值 |
| 事件组 EventGroup | 多任务等"多事件组合"（AND/OR） |

#### 内存

内核对 TCB、栈、队列等的内存来自 `heap_x.c`；可**动态**（`xTaskCreate`）或**静态**（`xTaskCreateStatic`）分配。实时系统关键路径倾向静态分配（确定、无碎片）。

### 4. FreeRTOS 的构成

```text
① 通用内核     tasks.c  list.c  queue.c  timers.c  event_groups.c  stream_buffer.c
② 移植层       portable/<编译器>/<架构>/  port.c  portmacro.h  portasm
③ 配置         FreeRTOSConfig.h（行为/裁剪/时钟/内存等开关）
④ 板级/芯片    启动文件、向量表、链接脚本、时钟、串口、GPIO、SDK 驱动
```

> ④ 不属于 FreeRTOS 内核，属于 SDK/BSP。只下载内核不能直接变成某块板子的可烧写工程。

### 5. 一个最小例子（概念对照）

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

### 6. 术语速查

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

### 7. 常见理解误区

| 误区 | 纠正 |
|---|---|
| "用了 FreeRTOS 就是硬实时" | 硬/软实时由**产品 deadline** 决定，RTOS 只提供机制 |
| "任务优先级和中断优先级方向一样" | **任务越大越高；Cortex-M 中断越小越高**，两套方向 |
| "任务越多越好" | 任务多→栈/调度开销大、复杂度高；够用即可 |
| "队列传的就是引用" | 默认是**值拷贝**（传指针 = 拷贝指针值，注意指向内存的生命周期） |
| "二值信号量可以当锁" | 当锁要用**互斥量**（有所有权 + 优先级继承） |
| "`vTaskDelay` 能保证周期" | 会随执行时间漂移，周期任务用 **`vTaskDelayUntil`** |
| "串口打印时间能当实时基准" | 串口阻塞且不确定，应用 DWT/硬件定时器 + 逻辑分析仪 |

---

## 二、FreeRTOS 任务与调度

## FreeRTOS 任务与调度

### 1. 任务（Task）

任务是 FreeRTOS 调度的**最小单位**，本质是一个**永不返回**的 C 函数，通常是一个死循环：

```c
void vTaskFunction(void *pvParameters)
{
    /* 初始化：只执行一次 */
    for (;;)
    {
        /* 任务主体 */
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    /* 不允许 return；若真的返回，必须调用 vTaskDelete(NULL) */
}
```

每个任务拥有：

| 组成 | 说明 |
|---|---|
| 任务函数 | 用户编写（PC 入口） |
| 任务栈 | 保存局部变量 + 上下文（寄存器） |
| TCB | 任务控制块，内核管理任务的全部元数据 |

### 2. 任务控制块 TCB

FreeRTOS 用 `TCB_t`（在 `tasks.c`）描述一个任务。核心字段（简化）：

```c
typedef struct tskTaskControlBlock
{
    volatile StackType_t *pxTopOfStack;      // 栈顶：切换时寄存器压栈到这里

    ListItem_t xStateListItem;               // 挂在"就绪/阻塞/挂起"某个链表上
    ListItem_t xEventListItem;               // 挂在某个事件(队列/信号量等)的等待链表上
    UBaseType_t uxPriority;                  // 优先级（数值越大越高）
    StackType_t *pxStack;                    // 栈起始地址（用于栈溢出检查）

    char pcTaskName[configMAX_TASK_NAME_LEN];// 任务名（调试用）

    /* 条件编译字段：通知、运行时间统计等 */
    #if (configUSE_TASK_NOTIFICATIONS == 1)
    volatile uint32_t ulNotifiedValue;
    volatile uint8_t  ucNotifyState;
    #endif
    #if (configGENERATE_RUN_TIME_STATS == 1)
    uint32_t ulRunTimeCounter;
    #endif
} TCB_t;
```

要点：

- **`pxTopOfStack` 是最重要的字段**：任务切换时，当前任务的 CPU 寄存器被压到栈里，`pxTopOfStack` 指向保存点；恢复时从这个位置弹出。
- **两个 `ListItem_t`**：`xStateListItem` 说明任务"当前在哪"（就绪/延时/挂起），`xEventListItem` 说明任务"在等哪个事件"。
- 老版本用 `StaticTask_t`/`xTaskCreateStatic` 支持静态分配（TCB 和栈由用户提供，不依赖堆）。

### 3. 任务状态与迁移

FreeRTOS 任务的 4 个核心状态（实际还包括 Running / Deleted）：

| 状态 | 含义 |
|---|---|
| **Running** | 正在占用 CPU |
| **Ready** | 就绪，等待被调度（在 `pxReadyTasksLists[prio]` 里） |
| **Blocked** | 阻塞：等待事件或延时到期（在 `pxDelayedTaskList` 或事件等待链表） |
| **Suspended** | 挂起：被 `vTaskSuspend()` 显式挂起（在 `xSuspendedTaskList`），不参与调度 |

```text
              xTaskCreate
   (无) ─────────────────────▶ Ready ──────────────▶ Running
                               ▲  │                    │  │
        事件到达/延时到期       │  │ 被更高优先级抢占    │  │
                               │  ▼                    │  │ vTaskDelay/等事件
        vTaskSuspend ─────▶ Suspended                  │  ▼
                               │                       │ Blocked
        vTaskResume ───────────┘                       │
                                                       │ 事件到达/超时
                                                       └─▶ Ready
```

关键点：

- **`vTaskDelay(n)`**：把任务从就绪链表移到**延时链表**，n 个 tick 后由 tick 中断移回就绪。
- **等待事件**（队列满/空、信号量取不到）：任务进入阻塞，同时挂在**延时链表**（带超时）和**事件等待链表**上；事件到达或超时都会把它移回就绪。
- 任务的 `xStateListItem` 一定在且仅在某一个状态链表里。

### 4. 优先级

| 规则 | 说明 |
|---|---|
| 数值越大越高 | `0` 最低，`configMAX_PRIORITIES-1` 最高（与 uC/OS 相反！） |
| 数量 | 由 `configMAX_PRIORITIES` 决定（常见 5~32） |
| 同优先级 | 若 `configUSE_TIME_SLICING=1`，按时间片轮转 |
| 空闲任务 | 优先级 `0`（`tskIDLE_PRIORITY`） |
| 定时器任务 | 默认优先级 `configTIMER_TASK_PRIORITY` |

> 优先级设计要点：关键任务按 **deadline** 设优先级；不要把所有关键任务都设成最高优先级；注意低优先级任务可能被长期饿死。

### 5. 任务栈

- 每个任务独立栈，大小在创建时给定（单位是**字**，StackType_t 个数，不是字节）。
- Cortex-M 栈**向下生长**（满递减栈）。
- 创建时内核会**预填一个栈帧**，让第一次切换到该任务时能正确"返回"到任务函数入口。
- 栈溢出检查（`configCHECK_FOR_STACK_OVERFLOW`）：
  - 方法 1：切换时检查栈指针是否越界；
  - 方法 2：检查栈末尾的 magic 值（`0xA5A5A5A5`）是否被改写。
- 用 `uxTaskGetStackHighWaterMark()` 查**历史最小剩余**。

### 5b. FreeRTOS 到底支持多少个任务？（深度）

**结论先说：FreeRTOS 内核不设任务数上限，上限 = 你的 RAM。**（官方原话：*"FreeRTOS does not
impose a limit, so the only limit is the amount of RAM your system has."*）

这是很多人 misconceive 的地方——以为 `configMAX_PRIORITIES` 限制任务数。它不限制**数量**，
只限制**优先级档位**。两个是独立的两件事。

#### 上限由什么决定

一个任务占的内存 = **栈 + TCB**，都从 FreeRTOS 堆（`configTOTAL_HEAP_SIZE`）里出：

```text
每个任务开销 ≈ usStackDepth × sizeof(StackType_t)   ← 栈（你在 xTaskCreate 里给的）
             + sizeof(TCB_t)                         ← 任务控制块（几十到一百多字节）
             + 队列/信号量等内核对象（如果任务用了）
```

所以理论上限的推导是：

```text
最大任务数 ≈ configTOTAL_HEAP_SIZE / (每任务栈字数 × 4 + sizeof(TCB_t) 对齐)
```

**举例**：堆 32KB、每任务栈 128 字（512 字节）、TCB 约 92 字节 → 每任务约 604 字节 →
理论上限约 54 个任务。**真正的限制是你给堆留了多少 RAM，以及你愿意给每个任务多大栈。**

> 注意还有"隐性玩家"：调度器启动时会**自动创建空闲任务**（idle），
> `configUSE_TIMERS=1` 还会创建定时器服务任务——它们也吃堆。所以实际可用比理论少一点。

#### 为什么这么设计（对比 uC/OS）

| | FreeRTOS | uC/OS-II |
|---|---|---|
| 任务数上限 | **无硬限制**，只受 RAM | `OS_MAX_TASKS` **编译期定死** |
| 优先级 | 0 ~ `configMAX_PRIORITIES-1`（数值大=高） | 0 ~ 63 固定 |
| 任务控制块 | 动态从堆分配，或 `xTaskCreateStatic` 静态 | 预分配数组 `OSTCBTbl[]` |
| 就绪表 | `pxReadyTasksLists[prio]` 每优先级一个链表 | 8×8 位图 + 就绪组 |

为什么 FreeRTOS 不学 uC/OS 预分配数组？——**因为数组方案浪费且不灵活**：
`OS_MAX_TASKS=10` 就永远最多 10 个，哪怕你只用到 3 个，那 7 份 TCB+栈也一直占着 RAM；
而嵌入式 RAM 恰恰是最稀缺资源。FreeRTOS 选择"用多少占多少"，把上限交给开发者自己权衡。

#### 代价：这个设计把"确定性"换成了"灵活性"

动态分配意味着 `xTaskCreate` **可能失败**（堆满了），返回 `pdFAIL`。所以：

1. **必须检查返回值**，或实现 `vApplicationMallocFailedHook()`；
2. 若要**运行期完全无碎片、无失败**（安全关键场景），改用 `xTaskCreateStatic()`——
   TCB 和栈由你静态定义，内核零堆依赖；
3. **创建完就不再删**的话（大多数产品如此），堆碎片风险很低；频繁 `vTaskDelete`+`Create`
   才需要担心碎片（heap_4 的合并算法能缓解但不杜绝）。

#### 顺带：优先级数量和任务数量为什么无关

`configMAX_PRIORITIES` 决定**就绪表的桶数**：内核为每个优先级维护一条就绪链表
`pxReadyTasksLists[prio]`。同一优先级挂多少个任务都行（时间片轮转或先来先服务）。
所以"优先级 5 上挂 20 个任务"完全合法——这 20 个任务轮流用 CPU。
代价：`configMAX_PRIORITIES` 越大，就绪表数组越大、调度扫描越费时（`configUSE_PORT_OPTIMISED_TASK_SELECTION`
用硬件前导零指令可把扫描降到 O(1)，但上限通常 32 位）。

#### 一句话总结

**任务数没有魔法数字，它 = `堆大小 / (栈 + TCB)`，本质是"你有多少 RAM、愿意给每个任务多少栈"。**
`configMAX_PRIORITIES` 只管优先级档位。要"绝对不失败"就用 `xTaskCreateStatic`。

### 6. 常用任务 API

| API | 作用 |
|---|---|
| `xTaskCreate(fn, name, stackDepth, arg, prio, &handle)` | 动态创建（栈/TCB 从堆） |
| `xTaskCreateStatic(...)` | 静态创建（用户提供 TCB + 栈数组） |
| `vTaskDelete(handle)` | 删除任务；`NULL` = 删自己（必须让出 CPU 交给 idle 回收内存） |
| `vTaskDelay(ticks)` | 相对延时（阻塞） |
| `vTaskDelayUntil(&prev, period)` | 绝对周期延时（周期任务用） |
| `vTaskSuspend(handle)` / `vTaskResume(handle)` | 挂起 / 恢复 |
| `vTaskPrioritySet(handle, prio)` / `uxTaskPriorityGet(handle)` | 改/查优先级 |
| `vTaskGetInfo(...)` / `uxTaskGetSystemState(...)` | 查询任务信息（调试/统计） |
| `xTaskGetTickCount()` | 当前 tick |
| `vTaskStartScheduler()` | 启动调度器 |
| `xTaskGetCurrentTaskHandle()` | 当前任务句柄 |

`xTaskCreate` 原型：

```c
BaseType_t xTaskCreate( TaskFunction_t pxTaskCode,
                        const char * const pcName,
                        const configSTACK_DEPTH_TYPE usStackDepth, // 单位：字
                        void * const pvParameters,
                        UBaseType_t uxPriority,
                        TaskHandle_t * const pxCreatedTask );
```

**空闲任务（Idle Task）**：调度器启动时自动创建，优先级 0，负责：

1. 释放被删除任务的内存（`vTaskDelete` 后由 idle 回收）；
2. 执行 `vApplicationIdleHook()`（若使能）；
3. 让系统总有任务可跑（防止调度器"无事可做"）。

**定时器任务（Timer Task）**：若 `configUSE_TIMERS=1`，创建，负责执行软件定时器回调。

### 7. 调度器：抢占与时间片

| 配置 | 作用 |
|---|---|
| `configUSE_PREEMPTION` | 1 = 抢占式（高优先级就绪即抢占）；0 = 协作式（只在任务让出/阻塞时切换） |
| `configUSE_TIME_SLICING` | 1 = 同优先级任务按 tick 轮转时间片 |
| `configUSE_TICKLESS_IDLE` | 1 = 空闲时关 tick，低功耗 |

调度策略：

```text
始终运行【就绪任务中优先级最高的那个】。
同优先级多个就绪任务：有 configUSE_TIME_SLICING 则轮流；
同优先级任务切换发生在 tick（时间片到期）或任务主动让出。
```

### 8. 就绪表与"选下一个任务"

FreeRTOS 用一个**就绪链表数组**表示每个优先级上的就绪任务：

```c
List_t pxReadyTasksLists[configMAX_PRIORITIES]; // 下标 = 优先级
```

选出最高优先级就绪任务有两种实现：

| 方式 | 配置 | 做法 | 复杂度 |
|---|---|---|---|
| 通用 | 默认 | 从最高优先级往下**遍历**找非空链表 | O(n)（n=优先级数） |
| 硬件优化 | `configUSE_PORT_OPTIMISED_TASK_SELECTION=1` | 用一个 32 位变量 `uxTopReadyPriority` 做**位图**，用 `CLZ`（前导零计数）指令直接定位最高位 | O(1) |

Cortex-M 上用 `CLZ`（`__clz`）。选任务的核心宏：

```c
taskSELECT_HIGHEST_PRIORITY_TASK():
    /* 找到最高优先级就绪链表，把 pxCurrentTCB 指向其第一个任务的 TCB */
```

### 9. 上下文切换（Cortex-M）

Cortex-M 的切换由 **PendSV 异常**完成（PendSV 优先级设为**最低**，保证不打断其它中断）：

```text
        SysTick / 任务让出 / 事件 / 抢占
                    │
                    ▼
        taskYIELD() / portYIELD()  →  触发 PendSV
                    │
                    ▼
   ┌──────────────── PendSV_Handler ────────────────┐
   │ 硬件已自动压栈：R0-R3,R12,LR,PC,xPSR            │
   │ 软件再压：R4-R11（portasm / port.c）            │
   │ 保存当前任务 pxTopOfStack                       │
   │ vTaskSwitchContext()：选下一个最高优先级就绪任务 │
   │ 恢复下一个任务的 R4-R11                         │
   │ 硬件自动出栈 R0-R3,R12,LR,PC,xPSR，返回         │
   └─────────────────────────────────────────────────┘
```

三个异常的分工：

| 异常 | 作用 |
|---|---|
| **SVC**（`vPortSVCHandler`） | 启动**第一个任务**（调度器首次运行，从栈里恢复第一个任务的上下文） |
| **PendSV**（`xPortPendSVHandler`） | 运行中的**任务切换**（保存/恢复寄存器） |
| **SysTick**（`xPortSysTickHandler`） | **系统节拍**：`xTaskIncrementTick()`，必要时触发 PendSV 切任务 |

> Cortex-M 硬件在进入异常时**自动**压栈 R0-R3/R12/LR/PC/xPSR；FreeRTOS 只需在汇编里额外保存 R4-R11（还有可能的 FPU 寄存器）。

### 10. 调度器启动流程

```text
main()
 └─ xTaskCreate(...)                 创建若干任务（放到就绪链表）
 └─ vTaskStartScheduler()
      ├─ 创建空闲任务 (idle)
      ├─ 创建定时器任务 (若 configUSE_TIMERS)
      ├─ xPortStartScheduler()
      │    ├─ 配置 SysTick、PendSV、SVC 优先级（PendSV 最低）
      │    ├─ 使能 SysTick（节拍开始）
      │    └─ 触发 SVC → vPortSVCHandler → 恢复第一个任务上下文 → 进入任务
      └─ （正常不会返回；若内存不足会返回并可能 assert）
```

### 11. 任务切换发生在什么时候

| 触发 | 例子 |
|---|---|
| 任务主动阻塞/让出 | `vTaskDelay`、等队列/信号量、`taskYIELD` |
| 时钟节拍 | SysTick 中断里唤醒到期任务 / 时间片到期 |
| 中断唤醒 | ISR 用 `FromISR` API 让更高优先级任务就绪（`portYIELD_FROM_ISR`） |
| 创建/恢复任务 | 新任务优先级更高立即抢占 |
| 改变优先级 | 被改高的任务立即抢占 |

### 12. 面试高频问法

- **FreeRTOS 任务和线程的区别？** MCU 上每个任务有**独立栈**（类似线程），但没有独立地址空间/MMU，共享全局内存。
- **为什么任务函数要死循环？** 任务的 PC 不应越过函数返回；返回必须 `vTaskDelete(NULL)`。
- **优先级数值方向？** 越大越高（注意与 uC/OS 相反）。
- **抢占是怎么实现的？** 高优先级任务就绪 → 置 PendSV pending → 退出中断时执行 PendSV 完成切换。
- **为什么 PendSV 优先级最低？** 避免在切换过程中被其它中断打断，保证切换原子性；也能让切换在所有 ISR 结束后统一进行。
- **就绪表用什么数据结构？** 每个优先级一个双向链表（`pxReadyTasksLists[]`），可选用位图 + CLZ 做 O(1) 选择。
- **`vTaskDelay` 和 `vTaskDelayUntil` 区别？** 前者相对（周期会叠加执行时间而漂移），后者绝对（严格周期），见 `02-时间管理.md`。

---

## 三、FreeRTOS 时间管理

## FreeRTOS 时间管理

### 1. 系统节拍（Tick）

FreeRTOS 用**周期性的定时器中断**产生"节拍"（tick），作为内核时间基准。Cortex-M 通常用 **SysTick**。

| 配置 | 含义 |
|---|---|
| `configTICK_RATE_HZ` | 每秒节拍数，如 1000（1 ms）、200（5 ms） |
| 一个 tick 的时间 | `1 / configTICK_RATE_HZ` 秒 |
| `configSYSTICK_CLOCK_HZ` | SysTick 时钟源（默认等于 CPU 时钟） |
| SysTick 重装值 | `configSYSTICK_CLOCK_HZ / configTICK_RATE_HZ - 1` |

> 本项目：`configTICK_RATE_HZ = 200`（5 ms/tick），M7 800 MHz → SysTick 重装值 = 800M/200 = 4,000,000。

**Tick 越大/频率越低**：中断开销小、时间分辨率粗。**频率越高**：分辨率高、开销大。选择要平衡实时性和开销。

#### 节拍中断做什么

`xPortSysTickHandler` → `xTaskIncrementTick()`：

```text
xTaskIncrementTick():
  1. xTickCount++
  2. 遍历"延时链表"，把到期任务的 xStateListItem 移回就绪链表
     （若任务还在等事件，则把它从事件等待链表摘除、返回相应失败码）
  3. 若 configUSE_TIME_SLICING：处理同优先级时间片轮转
  4. 若被唤醒任务的优先级 >= 当前任务：请求切换（触发 PendSV）
```

### 2. 延时链表

内核用 `pxDelayedTaskList`（当前延时链表）和 `pxOverflowDelayedTaskList`（溢出链表）**按到期 tick 升序**保存阻塞中的任务：

- 新任务插入时按唤醒时刻排序，所以 tick 中断只看链表头即可。
- 当 `xTickCount` 回绕（32 位溢出）时，两个链表**互换**，用 `xNumOfOverflows` 记录溢出次数。

### 3. 相对延时 vs 绝对延时

| API | 语义 | 适用 |
|---|---|---|
| `vTaskDelay(n)` | 从**调用点**起延时 n 个 tick | 简单延时不关心精确周期 |
| `vTaskDelayUntil(&xLastWakeTime, period)` | 到**上次唤醒 + period** 的绝对时刻唤醒 | **固定周期任务** |
| `xTaskDelayUntil(...)` | 同上，带返回值（是否真的延时了） | 需要知道是否被推迟 |

```c
/* 周期任务：正确写法 */
TickType_t xLastWakeTime = xTaskGetTickCount();
for (;;) {
    /* ... 工作 ... */
    vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(500));
}
```

**为什么周期任务用 `vTaskDelayUntil`？**

```text
vTaskDelay(500ms) 的实际周期 = 500ms + 任务执行时间  → 会累加、漂移
vTaskDelayUntil   的实际周期 = 固定 500ms（编译器补偿执行时间）→ 不漂移
```

> 注意：如果任务执行时间**超过** period，`vTaskDelayUntil` 会立即返回下一次（不补偿），需要检测。

### 4. 节拍与毫秒换算

```c
pdMS_TO_TICKS(ms)          // ms → tick（受 configTICK_RATE_HZ 精度影响）
pdTICKS_TO_MS(ticks)       // tick → ms
portTICK_PERIOD_MS         // 一个 tick 的毫秒数（可能为 0，若不整除）
```

> 若 `configTICK_RATE_HZ` 不能整除 1000（如 200 → 5 ms 可以；333 → 3.003 ms），换算会取整，注意精度。

### 5. 软件定时器（`timers.c`）

FreeRTOS 提供**软件定时器**：定时到点后，在**定时器服务任务**的上下文里执行回调。

| 配置 | 含义 |
|---|---|
| `configUSE_TIMERS` | 1 = 使能软件定时器 |
| `configTIMER_TASK_PRIORITY` | 定时器服务任务优先级 |
| `configTIMER_QUEUE_LENGTH` | 定时器命令队列长度 |
| `configTIMER_TASK_STACK_DEPTH` | 定时器任务栈 |

| API | 作用 |
|---|---|
| `xTimerCreate(name, period, autoReload, id, callback)` | 创建 |
| `xTimerStart/Stop/Reset/ChangePeriod` | 启动/停止/复位/改周期 |
| `xTimerStartFromISR` 等 | 中断版本 |
| `xTimerIsTimerActive` | 是否在运行 |

**关键机制**：

```text
定时器不直接跑在 tick 中断里！
tick 中断只把"到期的定时器"标记；
定时器命令(创建/启动/改周期)和到期事件 → 发到"定时器命令队列"；
定时器服务任务(一个普通任务)从队列取出并执行回调。
```

**回调里不能做的事**：

- **不能阻塞**（不能调 `vTaskDelay`、不能等信号量）；
- 不能调用非 `FromISR` 且会阻塞的 API；
- 回调应尽量短，慢活交给别的任务（通过通知/队列）。

### 6. 时间相关的其它 API

```c
xTaskGetTickCount();                 // 当前 tick 数
xTaskGetTickCountFromISR();          // 中断里取
vTaskSetTimeOutState(&xTimeOut);     // 与 xTaskCheckForTimeOut 配合做"总超时"
xTaskCheckForTimeOut(&xTimeOut, &xTicksToWait);
```

### 7. 常见坑

| 坑 | 说明 |
|---|---|
| 用 `vTaskDelay` 做周期任务 | 周期会随执行时间漂移，应用 `vTaskDelayUntil` |
| Tick 分辨率不够 | 需要 µs 级事件用**硬件定时器/中断**，不要靠 tick |
| `pdMS_TO_TICKS` 精度 | tick 频率不能整除 1000 时换算有误差 |
| 定时器回调里阻塞 | 会让定时器服务任务卡死，所有定时器失效 |
| 中断里不能用非 FromISR API | 必须用 `...FromISR` |
| tick 中断里做重活 | tick 里只做内核记账，重活放任务 |

### 8. 面试高频

- **`vTaskDelay(0)` / `vTaskDelay(1)` 区别？** `0` 通常等价于让出一次 CPU（`taskYIELD`，且不一定真的延时），`1` 至少阻塞 1 个 tick。
- **tick 中断和 PendSV 谁先？** tick 中断里判断需要切换后请求 PendSV；PendSV 在 tick 中断退出后（所有高优先级中断处理完）才执行。
- **软件定时器回调运行在哪个上下文？** 定时器服务任务（普通任务），不是中断。
- **如何实现微秒级延时？** 用硬件定时器 / DWT cycle counter（如本项目用 `MSDK_GetCpuCycleCount`），不要依赖 tick。

---

## 四、FreeRTOS 队列与信号量

## FreeRTOS 队列与信号量

### 1. 队列（Queue）

队列是 FreeRTOS 里**任务间通信的核心**，也是信号量、消息机制的基础。它是**先进先出（FIFO）**的、**定长元素**的缓冲区。

核心特点：

| 特点 | 说明 |
|---|---|
| **值拷贝** | 发送时把数据**拷贝**进队列；接收时拷贝出来（传指针也可以，但要保证指向的内存有效） |
| 定长元素 | 创建时指定"元素大小 × 长度" |
| 阻塞语义 | 队列满时发送可等待；队列空时接收可等待 |
| 超时 | 等待可带超时（`xTicksToWait`），也可以永久等待 |
| 多对多 | 多个任务/中断都可读写同一队列 |
| 线程安全 | 内部用临界区保护，任务用普通 API，中断用 `FromISR` |

#### 阻塞唤醒规则

- 发送入队成功 → 唤醒**等待接收**的**最高优先级**任务；
- 接收出队成功 → 唤醒**等待发送**（队列曾满）的**最高优先级**任务；
- 同优先级多个 → 按等待时间先后。

#### 常用 API

```c
QueueHandle_t xQueueCreate(UBaseType_t uxQueueLength, UBaseType_t uxItemSize);
BaseType_t   xQueueSend(xQueue, pvItemToQueue, xTicksToWait);       // 等同 xQueueSendToBack
BaseType_t   xQueueSendToFront(xQueue, pvItemToQueue, xTicksToWait);
BaseType_t   xQueueReceive(xQueue, pvBuffer, xTicksToWait);         // 出队
BaseType_t   xQueuePeek(xQueue, pvBuffer, xTicksToWait);            // 看不取
UBaseType_t  uxQueueMessagesWaiting(xQueue);                       // 当前元素数
BaseType_t   xQueueReset(xQueue);

/* 中断版本 */
BaseType_t xQueueSendFromISR(xQueue, pvItemToQueue, &xHigherPriorityTaskWoken);
BaseType_t xQueueReceiveFromISR(xQueue, pvBuffer, &xHigherPriorityTaskWoken);
```

典型生产者-消费者：

```c
/* 生产者任务 */            /* 消费者任务 */
xQueueSend(q, &data, 0);     xQueueReceive(q, &data, portMAX_DELAY);
```

中断里发队列：

```c
void IRQHandler(void) {
    BaseType_t xHPTW = pdFALSE;
    uint32_t d = ...;
    xQueueSendFromISR(q, &d, &xHPTW);
    portYIELD_FROM_ISR(xHPTW);   // 若唤醒了更高优先级任务，出了中断就切换
}
```

> **本项目实例**：LPUART7 接收中断里 `xQueueSendFromISR` 把收到的字节入队，`echo_task` 用 `xQueueReceive` 取出并回发——这就是"ISR 只搬数据、任务做处理"的标准写法。

#### 队列集（Queue Set）

多个队列/信号量可以放进一个**队列集**，让一个任务阻塞等待"任意一个"（如同时等按键队列和串口队列）：

```c
QueueSetHandle_t xQueueCreateSet(len);
xQueueAddToSet(xQueue, xQueueSet);
xQueueSelectFromSet(xQueueSet, timeout);   // 返回"哪个队列有数据"
```

### 2. 信号量（Semaphore）

FreeRTOS 的信号量**建立在队列之上**（元素长度为 0 的特殊队列）。三类：

| 类型 | 语义 | 典型用途 |
|---|---|---|
| **二值信号量** `BinarySemaphore` | 只有 0/1，无所有权 | 任务↔中断同步、任务↔任务同步（事件发生一次） |
| **计数信号量** `CountingSemaphore` | 计数 0~N | 资源计数、事件计数（可累积多次） |
| **互斥量** `Mutex` | 0/1，**有所有权**，支持**优先级继承** | 保护共享资源（临界区互斥） |

#### API

```c
SemaphoreHandle_t xSemaphoreCreateBinary();          // 二值，初始"空"
SemaphoreHandle_t xSemaphoreCreateCounting(max, init);
SemaphoreHandle_t xSemaphoreCreateMutex();           // 互斥
SemaphoreHandle_t xSemaphoreCreateRecursiveMutex();  // 递归互斥

xSemaphoreTake(sem, timeout);   // P 操作；FromISR 版本为 xSemaphoreTakeFromISR
xSemaphoreGive(sem);            // V 操作
xSemaphoreGiveFromISR(sem, &xHPTW);

/* 互斥专用（带所有权检查） */
xSemaphoreTakeRecursive(m, timeout);
xSemaphoreGiveRecursive(m);
```

> **二值信号量创建后是"空"的**，通常先 `xSemaphoreGive` 一次或由中断 give，再让任务 take。

### 3. 优先级反转与优先级继承

#### 优先级反转（Priority Inversion）

```text
高优先级任务 H 想用互斥量（被低优先级任务 L 持有）→ H 阻塞
中优先级任务 M（不需要该资源，但优先级高于 L）抢占 L
→ L 迟迟不能释放 → H 被 M "间接"阻塞（被中优先级任务拖住）
```

经典案例：**1997 年火星探路者（Mars Pathfinder）**因优先级反转导致反复看门狗复位，最终通过启用**优先级继承**修复。

#### 优先级继承（Priority Inheritance）

- **仅互斥量支持**。当 H 等待被 L 持有的互斥量时，内核**临时把 L 的优先级提升到 H**；
- L 尽快运行、释放资源后，优先级**恢复原值**；
- 从而缩短 H 的阻塞时间。

```text
互斥量持有 + 高优等待  →  低优任务被临时提权  →  尽快释放  →  恢复
```

#### 互斥量 vs 二值信号量（**高频面试题**）

| 维度 | 二值信号量 | 互斥量 |
|---|---|---|
| 所有权 | 无：任何任务都能 give | 有：**只能由持锁者释放** |
| 优先级继承 | 不支持 | 支持 |
| 用途 | **同步**（通知事件） | **互斥**（保护资源） |
| 递归 | 不支持 | 有专门的递归互斥量 |
| `xSemaphoreGive` 从 ISR | 支持 | **不能**（互斥量不能在 ISR 操作） |

> 记法：**同步用信号量，互斥用互斥量**。不要用二值信号量当互斥锁（没有所有权 → 没有优先级继承 → 可能反转/误释放）。

### 4. 死锁（Deadlock）

```text
任务A 持有锁1 等锁2 ; 任务B 持有锁2 等锁1  → 互相等待，永久阻塞
```

避免：

1. **固定加锁顺序**（所有任务按同一顺序获取锁）；
2. 用**超时** take（拿不到就放弃并释放已持有的锁）；
3. 缩小临界区，尽量少持锁；
4. 不在持锁时阻塞等待另一个锁。

### 5. 实现原理（面试加分）

- 队列结构：环形缓冲区（`pcHead/pcTail/pcWriteTo/pcReadFrom`）+ 两个等待链表（`xTasksWaitingToSend` / `xTasksWaitingToReceive`）。
- 队列操作在**临界区**里完成；缓冲区满/空时把当前任务挂到对应等待链表并阻塞。
- 信号量 = 长度为 0（不拷贝数据）的队列，只用"计数/等待链表"语义。
- 互斥量在队列基础上增加**持有者记录**和**优先级继承**逻辑。

### 6. 常见坑

| 坑 | 说明 |
|---|---|
| 传指针但数据被覆盖 | 队列拷贝的是指针值，指向的内存要保证生命周期/一致性（跨核/DMA 还要考虑 cache） |
| 在 ISR 用非 FromISR API | 必须用 `...FromISR`，否则可能破坏内核 |
| 队列里塞大结构 | 拷贝成本高；大数据传指针 + 独立缓冲 |
| 用二值信号量当锁 | 无所有权/无继承，易误释放与反转 |
| `xSemaphoreGive` 给错的信号量 | 计数的语义要清楚（资源数 vs 事件数） |
| 持锁做长耗时/阻塞 | 拉长别人等待时间，易反转 |

### 7. 面试高频

- **队列是拷贝还是引用？** 拷贝（元素值）。传指针即拷贝指针。
- **信号量怎么实现的？** 基于队列（长度 0）。
- **互斥量和二值信号量的区别？** 见上表（所有权 + 优先级继承）。
- **什么是优先级反转？怎么解决？** H 等 L 持有的资源、被 M 抢占而间接阻塞；解决：优先级继承（互斥量）/优先级天花板。
- **ISR 里能 take 互斥量吗？** 不能。
- **队列为空时 `xQueueReceive` 会怎样？** 按 `xTicksToWait` 阻塞（0 立即返回，`portMAX_DELAY` 永久等）。

---

## 五、FreeRTOS 任务通知 / 事件组 / 流缓冲区

## FreeRTOS 任务通知 / 事件组 / 流缓冲区

### 1. 任务通知（Task Notification）

任务通知是 FreeRTOS 里**最快**的任务间同步/通信方式：直接操作**目标任务的 TCB 内部字段**，不经过队列，不需要额外内存。

| 优点 | 限制 |
|---|---|
| 速度快、无额外 RAM | **只能一对一**（通知发给"某个具体任务"） |
| 可直接传 32 位值或做计数 | **不能多个任务等同一个通知对象** |
| 有 FromISR 版本，适合中断→任务 | 发送者必须**知道目标任务句柄** |
| 可替代"轻量二值/计数信号量" | 只能有一个"发送者"语义（多发送者会覆盖/累加） |

#### 内核字段（TCB 里）

```c
volatile uint32_t ulNotifiedValue;   // 通知值：计数 或 位
volatile uint8_t  ucNotifyState;     // not-waiting / waiting / notification-received
```

#### API

| API | 作用 |
|---|---|
| `xTaskNotify(handle, value, eAction)` | 发送通知，按 `eAction` 更新值 |
| `xTaskNotifyGive(handle)` | 给"计数型"通知 +1（最常用，等价于轻量计数信号量） |
| `xTaskNotifyFromISR(...)` / `vTaskNotifyGiveFromISR(...)` | 中断版本 |
| `xTaskNotifyWait(bitsToClearOnEntry, bitsToClearOnExit, &val, timeout)` | 等待通知（阻塞） |
| `ulTaskNotifyTake(clearOnExit, timeout)` | 等计数通知：`1`=退化成二值，`0`=计数（递减） |

`eAction` 四种动作：

```text
eNoAction             只更新"收到通知"状态，不改值
eSetBits              按位或（用于位图语义）
eIncrement            值 +1（计数）
eSetValueWithOverwrite 直接覆盖值（即使上一次没被读）
eSetValueWithoutOverwrite 若上次未读则失败（保留旧值）
```

**典型用法：中断 → 任务**

```c
/* ISR */
vTaskNotifyGiveFromISR(xTaskHandle, &xHPTW);
portYIELD_FROM_ISR(xHPTW);

/* 任务 */
ulTaskNotifyTake(pdTRUE, portMAX_DELAY);   /* 等一次通知，出队后清零 */
/* 处理 */
```

> 一个任务只能有**一个**通知槽。若要"事件 + 数据"分开，用队列或事件组。

### 2. 事件组（Event Group）

事件组用来让任务等待**多个事件的组合**（AND / OR），比信号量更适合"满足多个条件才继续"。

- 一个事件组是 **24 个可用位**（高 8 位保留），每位代表一个事件；
- 多个任务可以**同时等待同一个事件组**（这是它优于任务通知的地方）；
- 支持"等任意一个位"或"等所有指定位"。

#### API

```c
EventGroupHandle_t xEventGroupCreate();

xEventGroupSetBits(grp, bits);                 // 置位（可 FromISR）
xEventGroupClearBits(grp, bits);
EventBits_t xEventGroupGetBits(grp);

EventBits_t xEventGroupWaitBits(grp,
                                uxBitsToWaitFor,  // 关心哪些位
                                xClearOnExit,     // 满足后是否清零
                                xWaitForAllBits,  // pdTRUE=全满足(AND) / pdFALSE=任一(OR)
                                xTicksToWait);
```

**典型**：任务等"网络已连接 + 数据已就绪"两位都为 1 才处理：

```c
xEventGroupWaitBits(grp, BIT_CONN | BIT_DATA, pdTRUE, pdTRUE, portMAX_DELAY);
```

> 事件组的位也可以当"多个二值信号量"用，但语义是"位"，不能计数。

### 3. 流缓冲区（Stream Buffer）

面向**单生产者 + 单消费者**的**字节流**缓冲，适合把 ISR 里收到的连续字节喂给任务（如串口 DMA 接收）。

- 不保留"消息边界"，就是一段字节流；
- 写满时，写者可选"覆盖最旧数据"；
- 只有一个读者、一个写者（不是多对多）。

```c
StreamBufferHandle_t xStreamBufferCreate(sizeBytes, triggerLevelBytes);
xStreamBufferSend(sb, data, len, timeout);
xStreamBufferReceive(sb, buf, len, timeout);
xStreamBufferBytesAvailable(sb);
xStreamBufferReset(sb);
```

### 4. 消息缓冲区（Message Buffer）

消息缓冲区是**流缓冲区的变长消息版**：每写一次消息，带一个长度前缀，读出来仍是完整的一条消息（保留边界）。

```c
MessageBufferHandle_t xMessageBufferCreate(sizeBytes);
xMessageBufferSend(mb, msg, len, timeout);
xMessageBufferReceive(mb, buf, bufLen, timeout);
```

### 5. 怎么选：队列 / 信号量 / 通知 / 事件组 / 缓冲区

| 需求 | 首选 |
|---|---|
| 多对多、传结构体数据 | **队列** |
| 同步一个事件（无数据、一对一） | **任务通知**（最快）或二值信号量 |
| 计数事件 / 资源计数 | 计数信号量 或 通知计数 |
| 保护共享资源 | **互斥量** |
| 一个任务等"多个事件组合"（AND/OR）/ 多任务等同一组事件 | **事件组** |
| ISR 连续字节流 → 任务 | **流缓冲区** |
| 变长消息 + 保留边界 | **消息缓冲区** |
| 大数据块 | 传**指针** + 环形缓冲/双缓冲（注意生命周期与 cache） |

### 6. 面试高频

- **任务通知为什么快？** 直接写目标任务的 TCB，不经过队列/临界区排队的额外开销；省内存省时间。
- **任务通知的局限？** 只能一对一；无法让多个任务等同一个对象；一个任务仅一个通知槽。
- **任务通知能替代二值/计数信号量吗？** 在许多"中断→单任务"场景可以（更快），但不能替代多对多/互斥/事件组。
- **事件组 vs 信号量？** 事件组可多个任务同时等、可等"多事件组合"（AND/OR），信号量偏"单个通行/计数"。
- **流缓冲区 vs 队列？** 流缓冲区是字节流（无边界、单读单写、可覆盖），队列是定长元素（多对多、有边界、值拷贝）。

---

## 六、FreeRTOS 内存管理

## FreeRTOS 内存管理

### 1. 内存来源

FreeRTOS 内核自己的内存（TCB、任务栈、队列、定时器等）来自 `portable/MemMang/heap_x.c` 提供的堆：

```c
void *pvPortMalloc(size_t xWantedSize);   // 内核/应用动态分配
void  vPortFree(void *pv);                // 释放
```

- 堆大小由 `configTOTAL_HEAP_SIZE` 配置；
- 若 `configAPPLICATION_ALLOCATED_HEAP=1`，则由用户提供 `ucHeap[]` 数组（可放到特定 RAM 区，如 TCM）；
- **在 ISR 里不能调用 `pvPortMalloc`**（非线程安全且可能阻塞）。

### 2. 静态 vs 动态分配

| 方式 | 说明 |
|---|---|
| 动态 | `xTaskCreate` 等从堆分配 TCB/栈；方便但有碎片和不确定性 |
| 静态 | `xTaskCreateStatic`、`xQueueCreateStatic`、`xEventGroupCreateStatic`、`xStreamBufferCreateStatic` 等：**TCB/栈/缓冲区由用户提供**，编译期确定内存 |

**产品实时系统**：关键路径优先静态分配或启动阶段一次性分配；避免在实时路径频繁 `pvPortMalloc`。

```c
StaticTask_t xTCB;
StackType_t  xStack[512];
xTaskCreateStatic(fn, "t", 512, NULL, prio, xStack, &xTCB);
```

### 3. heap_1 ~ heap_5

| 实现 | 能否释放 | 特点 | 适用 |
|---|---|---|---|
| **heap_1** | **不能释放** | 最简单、最确定（只一个指针递增）；没有碎片和释放逻辑 | 只在启动时创建任务/对象，之后不再动态分配 |
| **heap_2** | 能释放 | 不合并相邻空闲块（易碎片）**已不推荐** | 旧代码 |
| **heap_3** | 能释放 | 简单包装标准库 `malloc/free`（加挂起调度器保护） | 有成熟 C 库、堆管理交给 libc |
| **heap_4** | 能释放 | **首次适应 + 相邻空闲块合并**；单块连续内存 | **最常用**；通用动态分配 |
| **heap_5** | 能释放 | 同 heap_4，但支持**多块不连续内存区域**（`vPortDefineHeapRegions`） | 内存分散在多段（如 SRAM + DDR/TCM） |

> 选择：只需要"创建后不再释放" → heap_1；通用 → heap_4；多段内存 → heap_5。

#### heap_4 关键点

- 用**空闲链表**（按地址排序）管理空闲块；
- 分配：首次适应（first fit）；
- 释放：**与前后相邻的空闲块合并**（`prvInsertBlockIntoFreeList`），缓解碎片；
- 块头记录大小与"是否空闲"标志。

### 4. 碎片问题

```text
碎片 = 堆总量够，但没有足够大的连续块满足一次分配
```

缓解：

1. **固定大小对象池**（同一类对象用同一个内存池，避免变长）；
2. 启动阶段一次性分配，运行期不再分配/释放；
3. 用 heap_4/5（有合并）；
4. 关键对象用**静态分配**；
5. 监控 `xPortGetMinimumEverFreeHeapSize()` 观察历史最低水位。

### 5. 常用 API 与统计

```c
pvPortMalloc(size);
vPortFree(p);

size_t xPortGetFreeHeapSize(void);            // 当前空闲堆
size_t xPortGetMinimumEverFreeHeapSize(void); // 历史最小空闲（关键！看有没有接近耗尽）

/* heap_4/5 可用的详细统计（依赖 configHEAP_CLEAR_MEMORY_ON_FREE 等） */
HeapStats_t xHeapStats;
vPortGetHeapStats(&xHeapStats);   // 空闲块数、最大空闲块、分配次数等
```

> 用堆做数据结构时，重点关注"历史最小空闲"和"最大空闲块"，判断是否接近碎片/耗尽。

### 6. 任务栈的内存

- 动态任务：栈从 heap 分配；
- 静态任务：栈数组由用户提供；
- 栈大小单位是**字**（非字节）；
- 用 `uxTaskGetStackHighWaterMark(handle)` 查历史最小剩余（`configCHECK_FOR_STACK_OVERFLOW` + `vApplicationStackOverflowHook` 捕获溢出）。

### 7. 常见坑

| 坑 | 说明 |
|---|---|
| ISR 里 `pvPortMalloc` | 不允许 |
| heap 太小 | 创建任务/队列失败（`xTaskCreate` 返回 `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY`） |
| 频繁分配释放 | 碎片化；实时路径避免 |
| 只看当前空闲 | 要看"历史最小空闲"和"最大空闲块" |
| 忘记 `configTOTAL_HEAP_SIZE` 单位 | 单位是**字节**（不同实现可能不同，按头文件确认） |
| 释放非本堆指针 | 只能释放 `pvPortMalloc` 返回的指针 |

### 8. 面试高频

- **FreeRTOS 有哪几种内存管理？区别？** heap_1~5（见上表）。
- **heap_4 和 heap_2 区别？** heap_4 会**合并相邻空闲块**，heap_2 不会。
- **heap_3 的特点？** 包一层标准 malloc/free，靠 libc 管理，可能引入不确定性。
- **heap_5 用途？** 支持多段不连续 RAM（如片内 SRAM + 外部 DDR/TCM 分段）。
- **怎么检测内存/栈问题？** 栈高水位、`vApplicationStackOverflowHook`、`xPortGetMinimumEverFreeHeapSize`、`vPortGetHeapStats`、`configASSERT`。
- **实时系统为什么倾向静态分配？** 确定性（无碎片、无分配延迟、无失败）。

---

## 七、FreeRTOS 中断 / 临界区 / 配置 / 移植

## FreeRTOS 中断 / 临界区 / 配置 / 移植

### 1. 中断与 ISR 规则

在 FreeRTOS 里，ISR（中断服务程序）必须遵守规则，否则会破坏内核：

| 规则 | 说明 |
|---|---|
| ISR 里**只能用** `...FromISR` 后缀的 API | 如 `xQueueSendFromISR`、`xSemaphoreGiveFromISR`、`vTaskNotifyGiveFromISR` |
| 唤醒更高优先级任务后调用 `portYIELD_FROM_ISR(xHPTW)` | 让切换在中断退出时发生 |
| ISR **短、小、快** | 只做硬件确认、取数据、发通知；重活交给任务 |
| 不能用会阻塞的 API | 不能 `vTaskDelay`、不能等信号量 |
| 不能 `pvPortMalloc` / `printf` | 非线程安全、慢 |

**两段式**：ISR（上半部，快）→ 发通知/队列 → 任务（下半部，慢）。

```c
void LPUART7_IRQHandler(void) {
    BaseType_t xHPTW = pdFALSE;
    if (LPUART_GetStatusFlags(LPUART7) & kLPUART_RxDataRegFullFlag) {
        uint8_t d = LPUART_ReadByte(LPUART7);
        xQueueSendFromISR(q, &d, &xHPTW);
        portYIELD_FROM_ISR(xHPTW);
    }
    SDK_ISR_EXIT_BARRIER;
}
```

### 2. 中断优先级（**极易踩坑**）

**Cortex-M 硬件**：中断优先级**数值越小 = 优先级越高**（与 FreeRTOS 任务优先级方向**相反**！）。

FreeRTOS 把中断分成两档：

```text
        ┌───────────────────────────────────────────────┐
高优先 │  高于 configMAX_SYSCALL_INTERRUPT_PRIORITY     │  不能调用任何 FreeRTOS API
（数值 │  （比 BASEPRI 更紧急，不受内核临界区屏蔽）      │  （如看门狗、电机急停）
 小）  ├───────────────────────────────────────────────┤
       │  ≤ configMAX_SYSCALL_INTERRUPT_PRIORITY        │  可调用 ...FromISR API
       │  （受 BASEPRI 屏蔽，临界区会挡住它们）          │
低优先 ├───────────────────────────────────────────────┤
（数值 │  PendSV / SysTick（configKERNEL_INTERRUPT_     │  内核自己用
 大）  │  PRIORITY，永远最低）                           │
        └───────────────────────────────────────────────┘
```

要点：

- **凡是会调用 FreeRTOS API 的中断**，优先级必须 **≤ `configMAX_SYSCALL_INTERRUPT_PRIORITY`**（数值上 ≥，即"不比它更紧急"）；否则会破坏内核；
- 临界区通过设置 **`BASEPRI`** 屏蔽"≤ 该优先级"的中断（而不是全关中断）；
- **PendSV 与 SysTick 必须是最低优先级**（`configKERNEL_INTERRUPT_PRIORITY`）；
- Cortex-M 的中断优先级寄存器只实现高几位（`configPRIO_BITS`，如 4 位），写 `NVIC_SetPriority` 时必须**左对齐**（FreeRTOS 的宏会处理）。

> 本项目：`NVIC_SetPriority(LPUART7_IRQn, configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY)` —— 把串口中断设成"可调用 FromISR API"的最高优先级。

### 3. 临界区与调度器保护

| 手段 | API | 作用范围 | 特点 |
|---|---|---|---|
| 临界区 | `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()` | 屏蔽"≤ configMAX_SYSCALL 优先级"的中断 | 短小、快 |
| ISR 临界区 | `taskENTER_CRITICAL_FROM_ISR()` / `...EXIT...` | 同上（用于 ISR） | 嵌套计数支持 |
| 挂起调度器 | `vTaskSuspendAll()` / `xTaskResumeAll()` | **不关中断**，只是禁止任务切换 | 可较长，但不保护 ISR 与任务共享的数据 |
| 互斥量 | `xSemaphoreTake/Give` | 任务间共享资源 | 有优先级继承 |

选择：

```text
任务与任务抢共享数据      → 互斥量 或 临界区
任务与 ISR 抢共享数据     → 临界区（关中断）
较长操作 + 不能长时间关中断 → 挂起调度器（但要另想办法保护 ISR 数据）
```

> 临界区**越短越好**：关中断会增大中断延迟，破坏实时性。

### 4. `FreeRTOSConfig.h` 关键宏

| 分类 | 宏 | 说明 |
|---|---|---|
| 调度 | `configUSE_PREEMPTION` | 抢占/协作 |
| | `configUSE_TIME_SLICING` | 同优先级时间片 |
| | `configUSE_TICKLESS_IDLE` | 低功耗无节拍 |
| | `configMAX_PRIORITIES` | 优先级数 |
| 时间 | `configTICK_RATE_HZ` | 节拍频率 |
| | `configCPU_CLOCK_HZ` / `configSYSTICK_CLOCK_HZ` | CPU/SysTick 时钟 |
| | `configUSE_TIMERS` / `configTIMER_TASK_PRIORITY` / `configTIMER_QUEUE_LENGTH` | 软件定时器 |
| 同步 | `configUSE_MUTEXES` | 互斥量 |
| | `configUSE_RECURSIVE_MUTEXES` | 递归互斥 |
| | `configUSE_COUNTING_SEMAPHORES` | 计数信号量 |
| | `configUSE_TASK_NOTIFICATIONS` | 任务通知 |
| | `configUSE_QUEUE_SETS` | 队列集 |
| 内存 | `configSUPPORT_DYNAMIC_ALLOCATION` / `configSUPPORT_STATIC_ALLOCATION` | 动态/静态分配 |
| | `configTOTAL_HEAP_SIZE` | 堆大小 |
| | `configAPPLICATION_ALLOCATED_HEAP` | 用户提供 ucHeap |
| 中断 | `configPRIO_BITS` | 优先级位数 |
| | `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY` | 可调 API 的中断优先级阈值 |
| | `configKERNEL_INTERRUPT_PRIORITY` | PendSV/SysTick 优先级 |
| 钩子 | `configUSE_IDLE_HOOK` / `configUSE_TICK_HOOK` / `configUSE_MALLOC_FAILED_HOOK` | 空闲/节拍/分配失败钩子 |
| 断言/检查 | `configASSERT()` | 断言 |
| | `configCHECK_FOR_STACK_OVERFLOW` (1/2) | 栈溢出检查 |
| | `configUSE_TRACE_FACILITY` / `configGENERATE_RUN_TIME_STATS` | 跟踪/运行时间统计 |
| 裁剪 | `INCLUDE_vTaskDelay` / `INCLUDE_vTaskDelayUntil` / `INCLUDE_xTaskGetSchedulerState` 等 | 按需打开 API |

> `FreeRTOSConfig.h` 决定了内核的**行为和裁剪**，是移植的重中之重。本项目里 `configTICK_RATE_HZ=200`、`configCPU_CLOCK_HZ=SystemCoreClock`（800 MHz）。

### 5. 移植（Cortex-M）

移植 = 让通用内核适配目标 CPU 和工程环境，**不是重写内核**。核心在 `portable/<compiler>/<arch>/`：

| 文件 | 职责 |
|---|---|
| `portmacro.h` | 数据类型（`StackType_t`/`BaseType_t`/`TickType_t`）、`portSTACK_GROWTH`、临界区宏、`portYIELD`、优先级位数 |
| `port.c` | 启动第一个任务、SysTick 处理、临界区实现、任务栈初始化、MPU/FPU 处理 |
| `portasm.s`/汇编 | `vPortSVCHandler`、`xPortPendSVHandler` 的汇编（保存/恢复 R4-R11） |

Cortex-M 移植要处理的点：

1. 异常向量：SVC / PendSV / SysTick 挂到 `vPortSVCHandler` / `xPortPendSVHandler` / `xPortSysTickHandler`；
2. 中断优先级：`configPRIO_BITS`、`configKERNEL_INTERRUPT_PRIORITY`、`configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY`；
3. 任务栈初始布局（构造首次运行的栈帧，让 `SVC` 恢复后能进入任务函数）；
4. 上下文切换（PendSV 里额外保存 R4-R11，可能还有 FPU 寄存器 `S16-S31`）；
5. `SysTick` 配置节拍；
6. 链接脚本、启动文件、向量表；
7. 内存分配（heap_x、栈区、TCM/DDR 布局）。

> 板级内容（时钟、串口、GPIO、引脚、多核启动）**不属于 FreeRTOS 内核**，属于 SDK/BSP。见 `../FreeRTOS移植学习.md` 中 i.MX95 的具体做法。

### 6. 常见坑

| 坑 | 说明 |
|---|---|
| 中断优先级设太高又调 API | 破坏内核（必须 ≤ configMAX_SYSCALL） |
| 任务优先级和中断优先级方向搞混 | 任务：数值越大越高；中断：数值越小越高 |
| 临界区太长 | 中断延迟变大 |
| ISR 里用普通 API | 必须 FromISR |
| 忘了 `portYIELD_FROM_ISR` | 唤醒的高优先级任务要等下一个 tick 才运行 |
| 中断优先级没左对齐 | Cortex-M 只实现高几位，必须按 FreeRTOS 宏设置 |

### 7. 面试高频

- **Cortex-M 任务优先级和中断优先级方向？** 任务越大越高；中断越小越高。
- **为什么调 FreeRTOS API 的中断优先级有上限？** 内核临界区用 BASEPRI 屏蔽；比它更紧急的中断若调 API 会破坏内核。
- **临界区怎么实现的？** 通过 `BASEPRI` 屏蔽一定优先级以下的中断（不是全部关中断），并支持嵌套。
- **`vTaskSuspendAll` 和临界区区别？** 前者只禁任务切换、不关中断（ISR 照跑）；临界区关中断（保护任务与 ISR 共享数据）。
- **PendSV 为什么最低优先级？** 保证切换不被别的中断打断；让切换统一在中断退出时发生。
- **移植一个 Cortex-M 要做什么？** 见第 5 节。

---

## 八、FreeRTOS 调试统计与面试题

## FreeRTOS 调试统计与面试题

### 1. 调试与健康监测手段

| 手段 | 配置/API | 能发现什么 |
|---|---|---|
| 断言 | `configASSERT(x)` | 参数非法、内核状态异常（开发期开，发布期可关） |
| 栈溢出检查 | `configCHECK_FOR_STACK_OVERFLOW` (1/2) + `vApplicationStackOverflowHook` | 任务栈溢出 |
| 栈高水位 | `uxTaskGetStackHighWaterMark(handle)` | 每个任务历史最小剩余栈 |
| 分配失败钩子 | `configUSE_MALLOC_FAILED_HOOK` + `vApplicationMallocFailedHook` | 堆不足 |
| 堆水位 | `xPortGetFreeHeapSize` / `xPortGetMinimumEverFreeHeapSize` / `vPortGetHeapStats` | 堆余量与碎片 |
| 空闲钩子 | `configUSE_IDLE_HOOK` + `vApplicationIdleHook` | 系统是否常进空闲（负载、低功耗） |
| 节拍钩子 | `configUSE_TICK_HOOK` + `vApplicationTickHook` | 每 tick 统计 |
| 运行时间统计 | `configGENERATE_RUN_TIME_STATS` + `vTaskGetRunTimeStats` | 各任务 CPU 占用 |
| 任务状态查询 | `configUSE_TRACE_FACILITY` + `uxTaskGetSystemState` / `vTaskGetInfo` | 任务列表、状态、优先级、栈 |
| 图形化跟踪 | Tracealyzer（SEGGER/Percepio） | 时间轴、切换、队列事件 |

#### 运行时统计要注意

- 需要**一个比 tick 更快的时基**（配置 `portCONFIGURE_TIMER_FOR_RUN_TIME_STATS()` 和 `portGET_RUN_TIME_COUNTER_VALUE()`，Cortex-M 常用 DWT cycle counter 或高精度定时器）；
- 统计代码本身有开销，**低频调用**，别放进实时关键路径。

### 2. 常见错误与排查

| 现象 | 可能原因 |
|---|---|
| 创建任务返回失败 | `configTOTAL_HEAP_SIZE` 太小 / 栈太大 |
| 任务不运行 | 优先级太低被饿死 / 一直阻塞等不到事件 / 没启动调度器 |
| HardFault | 栈溢出 / 中断优先级不当调了 API / 空指针 / 越界 |
| 高优先级任务卡住低优先级 | 没阻塞（死循环不让出）/ 优先级设计问题 |
| 周期漂移 | 用 `vTaskDelay` 而非 `vTaskDelayUntil` |
| 队列数据错 | 传指针但内存被覆盖 / 多生产者没保护 |
| 中断后任务延迟很久才响应 | 忘了 `portYIELD_FROM_ISR` / 中断优先级太高破坏内核 |
| 长时间运行不稳定 | 栈/堆耗尽、碎片、泄漏（动态分配没释放） |

### 3. 综合面试题（按主题）

#### 概念与对比

1. FreeRTOS 是什么？能/不能提供什么？（能：调度/同步/时间/内存；不能：文件系统/网络/驱动/进程隔离）
2. 硬实时和软实时的区别？谁决定分类？（产品 deadline；不是用了 RTOS 就硬实时）
3. FreeRTOS 与 uC/OS、RT-Thread、Linux 的区别？
4. 任务和线程的异同？（独立栈、无独立地址空间）
5. 裸机前后台和 RTOS 的取舍？

#### 任务与调度

6. `xTaskCreate` 参数含义？栈单位？
7. 任务有哪几个状态？迁移条件？
8. 优先级方向？和有 uC/OS 什么不同？
9. 抢占式调度怎么实现？（就绪高优先级 → PendSV）
10. 时间片轮转用于什么情况？（同优先级）
11. `vTaskDelete(NULL)` 之后内存谁回收？（空闲任务）
12. 空闲任务为什么存在？优先级多少？
13. `vTaskSuspend` 和阻塞的区别？
14. 就绪表数据结构？O(1) 怎么做到（位图 + CLZ）？
15. 上下文切换保存哪些寄存器？谁做的（硬件/软件）？
16. SVC / PendSV / SysTick 各自作用？

#### 时间

17. `vTaskDelay` vs `vTaskDelayUntil`？
18. tick 频率怎么选？
19. 软件定时器回调在哪个上下文？能阻塞吗？
20. 怎么实现 µs 级延时/计时？（硬件定时器/DWT）

#### 通信与同步

21. 队列是拷贝还是引用？定长吗？
22. 队列阻塞/唤醒规则？
23. 二值/计数/互斥信号量的区别与用途？
24. 互斥量和二值信号量的根本区别？（所有权 + 优先级继承）
25. 优先级反转是什么？怎么解决？举实际案例（火星探路者）。
26. 死锁怎么产生、怎么避免？
27. 任务通知为什么快？有什么限制？
28. 事件组适合什么场景？
29. 流缓冲区 vs 队列？
30. ISR 怎么安全地和任务通信？（队列/信号量/通知的 FromISR 版 + `portYIELD_FROM_ISR`）

#### 中断/临界区/配置

31. 哪些中断优先级能调 API？为什么？
32. Cortex-M 中断优先级方向？任务优先级方向？容易混在哪？
33. 临界区怎么实现？为什么用 BASEPRI 而不是全关中断？
34. `vTaskSuspendAll` vs 临界区？

#### 内存

35. heap_1~5 区别？怎么选？
36. heap_4 合并空闲块的意义？
37. heap_3 的缺点？
38. 静态 vs 动态分配？实时系统为什么倾向静态？
39. 怎么检测栈溢出和堆不足？

#### 迁移/调试

40. 端口文件（port.c/portmacro.h）负责什么？
41. PendSV 为什么最低优先级？
42. 运行时统计需要什么？怎么开？

### 4. 本项目（i.MX95 M7）实践清单

对照上面，本项目已经落地验证的：

| 主题 | 本项目状态 |
|---|---|
| 任务创建/调度 | ✅ `freertos_hello.c` 两个任务（`echo_task` + `gpio_task`） |
| ISR → 队列 → 任务 | ✅ LPUART7 接收中断 `xQueueSendFromISR` → `echo_task` 回显 |
| 中断优先级 | ✅ `NVIC_SetPriority(LPUART7_IRQn, configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY)` |
| `vTaskDelay` | ✅ 早期 GPIO 翻转每 500 ms |
| `vTaskDelayUntil` | ✅ 实时测试改用绝对周期 |
| 优先级设计 | `echo_task` 高、`gpio_task` 次之（`configMAX_PRIORITIES-1 / -2`） |
| 时基/DWT | ✅ `MSDK_EnableCpuCycleCounter` + `MSDK_GetCpuCycleCount` 测周期/执行时间 |
| 实测 | 周期 500 ms 抖动 ≈ 0~7.5 ns、任务体 ≈ 140 ns、主频 800 MHz（见 `../实时性.md`） |
| 尚未做 | 信号量/互斥/事件组实战、栈高水位、运行时统计、动态分配压力、多优先级压力测试 |

### 5. 下一步建议（把笔记变成实践）

1. 加一个**信号量/队列**+ 多优先级任务的小实验，验证阻塞/唤醒/优先级抢占；
2. 打开 `configCHECK_FOR_STACK_OVERFLOW` + `uxTaskGetStackHighWaterMark`，记录每个任务栈余量；
3. 打开 `configGENERATE_RUN_TIME_STATS`（用 DWT），输出各任务 CPU 占比；
4. 做**长时间运行** + 栈/堆水位记录；
5. 再测**中断响应延迟**和**端到端延迟**（GPIO 边沿 → ISR → 任务 → GPIO，逻辑分析仪测）。

---

## 九、RTOS 横向对比（FreeRTOS / uC/OS / RT-Thread / Zephyr / 其它）

## RTOS 横向对比（FreeRTOS / uC/OS / RT-Thread / Zephyr / 其它）

> 对比维度：定位、许可、内核大小、调度、同步、内存、配置方式、生态与典型场景。
> 数字类（优先级方向、内核大小）**以你手上的实际版本为准**，这里给的是通行约定。

### 1. 总览

| 维度 | FreeRTOS | uC/OS-II / III | RT-Thread | Zephyr |
|---|---|---|---|---|
| 定位 | 微内核、纯调度/同步 | 经典抢占内核、强认证 | "RTOS + 中间件全家桶" | 大而全的 RTOS 平台 |
| 许可 | MIT（FreeRTOS Kernel） | 商业（源码可获取，Apache 版有） | Apache-2.0 | Apache-2.0 |
| 归属 | AWS / 社区 | Micrium → Silicon Labs | RT-Thread 社区/公司 | Linux 基金会 |
| 内核大小 | 极小（可 < 10 KB ROM） | 小 | 中 | 大 |
| 调度 | 抢占 + 时间片（可裁剪） | 抢占（每级一个任务） | 抢占 + 时间片 + 调度器插件 | 抢占 + 时间片 + 多种调度器 |
| 配置方式 | `FreeRTOSConfig.h` 宏 | `os_cfg.h` 宏 | `rtconfig.h` + Kconfig（图形化） | **Kconfig + Devicetree**（编译期裁剪） |
| 中间件 | 基本无（靠自己/第三方） | 基本无 | **很全**（文件系统/网络/GUI/设备框架） | **很全**（net/BLE/FS/驱动模型…) |
| 典型用户 | NXP/ST/ESP32… 海量 MCU | 航空/医疗/工业 | 国内 IoT 产品 | Nordic/Intel/智能硬件 |

### 2. 调度机制对比

| 项 | FreeRTOS | uC/OS-II | RT-Thread | Zephyr |
|---|---|---|---|---|
| 抢占 | 支持（`configUSE_PREEMPTION`） | 支持 | 支持 | 支持 |
| 时间片轮转 | 支持（同优先级，`configUSE_TIME_SLICING`） | 不支持同优先级（每级只能一个任务） | 支持（同优先级轮转） | 支持 |
| **优先级方向** | **数值越大越高** | **数值越小越高（0 最高）** | 数值越小越高（0 最高） | 数值越小越高（更负=更高） |
| 优先级数量 | `configMAX_PRIORITIES`（任意） | 固定 64（0~63，留 8 个别用户 56） | `RT_THREAD_PRIORITY_MAX`（默认 32） | 可配置，含协作式优先级 |
| 就绪结构 | `pxReadyTasksLists[]` 链表数组（可选位图 + CLZ） | 就绪表 + `OSUnMapTbl` 查表 O(1) | 就绪优先级位图 + 每组链表 | 优先级数组 + 就绪位图 |
| 空闲任务 | 优先级 0 | 优先级 63（最低，系统自建） | 最低优先级 | 最低优先级 |
| 特有能力 | 协程（几乎不用） | — | 对象容器/设备模型 | 多调度器（含 SMP、协作、deadline） |

> **最容易混的点**：FreeRTOS 是"越大越高"，uC/OS、RT-Thread、Zephyr 都是"越小越高"。Cortex-M 的**中断**优先级也是"越小越高"——所以 Cortex-M + FreeRTOS 上"任务越大越高、中断越小越高"，两套方向并存。

### 3. 通信与同步对比

| 功能 | FreeRTOS | uC/OS-II/III | RT-Thread | Zephyr |
|---|---|---|---|---|
| 队列/消息 | `Queue` | 消息队列 `OSQ` | `rt_mq`（消息队列） | `k_msgq`（定长）/`k_fifo`/`k_lifo` |
| 邮箱 | 用队列（传指针） | `OSMbox` 邮箱 | `rt_mb` 邮箱 | `k_msgq`/`k_fifo` |
| 二值信号量 | `BinarySemaphore` | 信号量(0/1) | `rt_sem` | `k_sem` |
| 计数信号量 | `CountingSemaphore` | 信号量计数 | `rt_sem`（计数） | `k_sem`（带 limit） |
| 互斥量 | `Mutex`（**优先级继承**） | 互斥信号量（**优先级继承**） | `rt_mutex`（**优先级继承**） | `k_mutex`（**优先级继承**） |
| 递归互斥 | 支持 | uC/OS-III 支持 | 支持 | 支持 |
| 事件标志 | `EventGroup`（24 位） | 事件标志组（8/16/32 位） | `rt_event` | `k_event` |
| 任务通知 | **有**（FreeRTOS 特色，最快） | 无（用信号量/邮箱） | 无（无此机制） | 无 |
| 流/消息缓冲 | `StreamBuffer`/`MessageBuffer` | 无 | `rt_pipe` 等 | `k_pipe` |
| 队列集 | 有 | 无 | 无 | `k_poll`（多对象轮询） |

**同步思想差异**：

- **FreeRTOS**：以**队列**为核心，信号量/互斥都建立在队列之上；任务通知是额外的高速通道。
- **uC/OS**：事件控制块（ECB）统一管理信号量/互斥/邮箱/消息队列；事件标志组是独立对象。
- **RT-Thread**：统一的**对象模型**（所有内核对象都有 `rt_object`），可挂到对象容器里按名查找。
- **Zephyr**：内核对象 + **`k_poll`** 统一多对象等待（类似 Linux 的 epoll 思路）。

### 4. 内存管理对比

| | FreeRTOS | uC/OS-II | RT-Thread | Zephyr |
|---|---|---|---|---|
| 动态堆 | `heap_1~5`（可选实现） | `OSMemGet/Put`（**内存分区**，固定块） | 内存池 `rt_mp` + 堆 `rt_malloc` | `k_malloc`（堆）+ `k_mem_slab`（固定块） |
| 特点 | 通用分配；heap_4/5 合并空闲块 | 固定大小块、无碎片、确定性强 | 分区管理（小内存算法） | slab 固定块 + 堆 |
| 静态分配 | `xTaskCreateStatic` 等 | 任务栈用户提供 | 支持 | 编译期静态（Kconfig/DT） |

> uC/OS 的"内存分区"（固定块）是硬实时友好设计：无碎片、O(1)。FreeRTOS 的 heap_4 更灵活但有碎片风险。

### 5. 配置与构建对比

| | FreeRTOS | uC/OS | RT-Thread | Zephyr |
|---|---|---|---|---|
| 裁剪 | `FreeRTOSConfig.h` + `INCLUDE_xxx` | `os_cfg.h` | `rtconfig.h`（可由 Kconfig/menuconfig 生成） | **Kconfig（menuconfig）+ Devicetree** |
| 构建 | CMake/Make/各 IDE 工程接入 | 同 | SCons + Kconfig | **CMake + west**（模块化、跨平台） |
| 上手曲线 | 低 | 低 | 中 | **高**（概念多：DT、Kconfig、west、模块） |

> Zephyr 用 Devicetree 描述硬件（和 Linux 一致），配置在**编译期**完成，运行期几乎无动态配置；FreeRTOS 则把行为开关集中在 `FreeRTOSConfig.h`，最简单直接。

### 6. uC/OS-II 关键机制（作 FreeRTOS 的对照）

来自 `../RTOS.md`：

- **优先级固定 64 级**（0 最高 ~ 63 最低），**每个优先级只能有一个任务**（不支持同优先级多任务）。系统保留 8 个（4 高 + 4 低），用户可用 56 个。
- **就绪表 O(1)**：`OSRdyGrp`（8 位）+ `OSRdyTbl[8]`（每字节 8 位），配合 `OSUnMapTbl[256]` 查表，一次就能定位最高优先级就绪任务（**查表法**）。
- FreeRTOS 的对照：就绪用**链表数组**（每级一个链表，可多任务），选任务用**遍历**或**位图+CLZ**（`configUSE_PORT_OPTIMISED_TASK_SELECTION`）。
- **TCB（OS_TCB）** 里有 `OSTCBX/Y/BitX/BitY` 就是为 O(1) 就绪表服务；FreeRTOS 的 `TCB_t` 则用两个 `ListItem_t`（状态 + 事件）。
- uC/OS 阻塞/延时用 `OSTCBDly`，每次 `OSTimeTick()` 遍历所有 TCB 递减并判断超时（这与 FreeRTOS 的"按到期时间排序的延时链表"不同，FreeRTOS 只看链表头）。

| 对比点 | uC/OS-II | FreeRTOS |
|---|---|---|
| 优先级方向 | 越小越高 | **越大越高** |
| 同优先级多任务 | 不允许 | 允许（时间片） |
| 就绪表 | 位图 + 查表 O(1) | 链表数组（可选位图+CLZ） |
| 超时检查 | 遍历所有 TCB | 延时链表按到期排序，看头 |
| 消息机制 | 邮箱 + 消息队列 | 队列（统一） |
| 内存 | 固定块分区 | heap_1~5 |

### 7. 其它值得知道的名字

| RTOS | 特点 |
|---|---|
| **VxWorks** | 商业硬实时旗舰，航天/国防/工业，工具链完善 |
| **ThreadX / Azure RTOS** | 微软，通过安全认证（医疗/汽车），组件生态 |
| **Zephyr** | Linux 基金会，SMP、多协议、Devicetree，现代构建 |
| **RT-Thread** | 国产，中间件全，图形化配置，社区活跃 |
| **SafeRTOS** | FreeRTOS 的**认证版**（IEC 61508 / ISO 26262 / DO-178） |
| **裸机 (super loop)** | 没 RTOS；简单任务 + 中断足够时反而更确定 |

### 8. 选型建议

| 场景 | 建议 |
|---|---|
| MCU 通用产品、要便宜/生态/CD 工具支持 | **FreeRTOS**（NXP/ST/ESP 等 SDK 默认） |
| 需要文件系统/网络/GUI 一站式、国产支持 | **RT-Thread** |
| 多协议 + 需要强构建系统 + SMP | **Zephyr** |
| 安全认证（航空/医疗/汽车） | uC/OS-III / SafeRTOS / ThreadX / VxWorks |
| 极简、只要调度 + 同步 | **FreeRTOS**（内核最小） |

### 9. 面试高频

- **FreeRTOS 和 uC/OS 优先级方向？** FreeRTOS 越大越高；uC/OS 越小越高。
- **两者就绪表实现差异？** uC/OS 位图 + `OSUnMapTbl` O(1)；FreeRTOS 就绪链表数组（可选位图 + CLZ）。
- **uC/OS 为什么每级只能一个任务？** 优先级即任务身份（TCB 表按优先级索引），不支持同优先级轮转。
- **FreeRTOS 任务通知在别的 RTOS 有吗？** 没有等价物（uC/OS/RT-Thread/Zephyr 没有这个机制）。
- **RT-Thread 相比 FreeRTOS 的特色？** 统一对象模型 + 设备驱动框架 + 丰富中间件（是"RTOS + IoT 平台"）。
- **Zephyr 相比 FreeRTOS 的特色？** Kconfig + Devicetree、编译期配置、SMP、强构建系统，学习曲线更陡。

---

## 十、工程实践：FRDM-IMX95-PRO / Cortex-M7 上跑 FreeRTOS

## 工程实践：FRDM-IMX95-PRO / Cortex-M7 上跑 FreeRTOS

> 把 `../FreeRTOS移植学习.md`（早期进程）与本次全部实测收敛成一份"可复现"的工程笔记。
> 详细原理与排查见 `../../../../docs/FRDM-IMX95-PRO-FreeRTOS-M7.md`（项目文档）。
> 实时性指标与测试见 `10-实时性测试.md`。

### 1. 平台总览：这是一块多核安全启动的板子

| 核 | 角色 | 运行 |
|---|---|---|
| 6× Cortex-A55 | 应用核 | Linux |
| 1× Cortex-M33 | **System Manager（SM）** | NXP SM 固件（管时钟/电源/复位/**资源与权限(TRDC)**） |
| 1× Cortex-M7 | **实时核（本次目标）** | **FreeRTOS 应用** |

启动不是"把 bin 烧进某个地址就完事"，而是 **Boot ROM 解析启动容器 → 加载 ELE/V2X/OEI/SM → SM 建立逻辑机与权限 → 放行 A55/M7**。M7 不能脱离 SM 独立运行。

这也决定了 FreeRTOS 只占整条链的**最上一层**：

```text
应用（FreeRTOS 任务 / 队列 / 中断）
      │
FreeRTOS 内核（tasks/queue/list/timers...）
      │
移植层（port.c / portasm / portmacro.h，Cortex-M7）
      │
SDK 驱动 + 板级（LPUART/RGPIO/时钟/引脚/链接脚本/启动文件）
      │
启动容器 flash.bin（ELE + V2X + OEI + SM + M7 + SPL + ATF + U-Boot + TEE）
      │
Boot ROM / SM（LM / DID / TRDC / PIN 资源分配）
```

### 2. 工程与编译

| 项 | 值 |
|---|---|
| SDK | `SDK_26_06_00_IMX95LPD5EVK-19` |
| IDE/编译器 | IAR 9.70.4（工程配置名是小写 `debug`） |
| 工程 | `boards/imx95lpd5evk19/freertos_examples/freertos_hello/cm7/iar/freertos_hello_cm7.ewp` |
| 产物 | `iar/debug/freertos_hello.bin`（M7 镜像） |
| 时钟 | `SystemCoreClock = 800 MHz`；`configTICK_RATE_HZ = 200`（5 ms/tick） |

编译：

```powershell
& "F:\Tools\IAR9.70.4\common\bin\iarbuild.exe" "<...>/iar/freertos_hello_cm7.ewp" -build debug
```

工程里的代码分三类（对应内核/移植/板级）：

- **通用内核**：`freertos-kernel`（tasks.c/queue.c/list.c/timers.c…）
- **移植层**：`portable/IAR/ARM_CM4F`（`port.c` + `portasm.s`，Cortex-M 移植；M7 复用 CM4F 端口）
- **板级**：`board.c`/`clock_config.c`/`pin_mux.c`/`hardware_init.c` + SDK 驱动

### 3. 启动方式与烧写

三种让 M7 跑起来的方式，本次用的是 **UUU（USB Serial Download）**：

| 方式 | 说明 | 适用 |
|---|---|---|
| J-Link | 直接下到 TCM 调试 | 有调试器时（本板无） |
| Linux remoteproc | Linux 运行后动态加载 | 被 LMM 权限挡住（`lmm(1) not under Linux Control`） |
| **UUU + SDPS** | 把整个启动容器经 USB 交给 Boot ROM | **本次采用**（无需 J-Link/SD） |

**启动容器（flash.bin）里有什么**（`mkimage_imx8 -parse`）：

| 容器 | 镜像 | 装载地址 | 作用 |
|---|---|---|---|
| ROM Container 1 | ELE FW | 0xE7FF8000 | EdgeLock 安全固件 |
| ROM Container 2 | V2X | 0x6000000 | 安全/功能安全固件 |
| ROM Container 3 | DDR OEI | 0x1FFC0000（M33） | DDR 训练 |
| | **SM** | 0x1FFC0000（M33） | System Manager |
| | **M7 固件** | 0x303C0000（M7 TCM 别名） | 本次的 FreeRTOS |
| | U-Boot SPL | 0x20480000（A55） | A55 一级引导 |
| App Container | BL31(ATF)/U-Boot/TEE | 0x8A200000 / 0x90200000 / 0x8C000000 | A55 后续 |

**两种运行**：

| 方式 | 命令 | 现象 |
|---|---|---|
| RAM 临时启动（USB/SDPS） | `uuu.exe <xxx>-ram.uuu`（`SDPS: boot -f flash.bin`） | A55 停在 SPL，**不跑 BL31**；M7 正常 |
| SD 完整启动 | 先 `uuu.exe -b sd <loader> flash.bin`，再 SW4 切 SD 启动 | A55 跑 SPL→**BL31**→U-Boot；触发 GPIO 的 PCNS 问题（见第 6 节） |

**关键操作点**：`uuu -lsusb` 必须是 **`SDPS`（0x015D）**；若是 `SPL1 SDPV`（0x0151）说明没冷复位（拔 J11 电源 15 s 再插）。SW4：USB 下载 = `ON,OFF,OFF,ON`；SD 启动 = `ON,OFF,ON,ON`。

> eMMC 与 SD 结论相同：只要 A55 跑到 BL31 就有 PCNS 问题；换介质不换结论。

### 4. 串口（LPUART7 + ISR→队列→任务）

- Pro 板 J22 引出的调试串口是 **LPUART7**（引脚 `GPIO_IO36=TX / GPIO_IO37=RX`），对应 **COM18**（COM17=A55 SPL，COM19=SM）。
- 工程里把 SDK 示例默认的 LPUART3 改成 **LPUART7**（`pin_mux.c` 里复用 `GPIO_IO36__LPUART7_TX` / `GPIO_IO37__LPUART7_RX`）。

**FreeRTOS 标准写法**（ISR 只搬数据，任务处理）：

```c
static QueueHandle_t echo_rx_queue;

void LPUART7_IRQHandler(void)   /* 中断：收到一字节 -> 入队 */
{
    BaseType_t xHPTW = pdFALSE;
    if (LPUART_GetStatusFlags(LPUART7) & kLPUART_RxDataRegFullFlag) {
        uint8_t d = LPUART_ReadByte(LPUART7);
        xQueueSendFromISR(echo_rx_queue, &d, &xHPTW);
        portYIELD_FROM_ISR(xHPTW);
    }
}

static void echo_task(void *pv)  /* 任务：出队 -> 回发 */
{
    uint8_t d;
    for (;;)
        if (xQueueReceive(echo_rx_queue, &d, portMAX_DELAY) == pdPASS)
            LPUART_WriteBlocking(LPUART7, &d, 1U);
}

/* 初始化（片段） */
NVIC_SetPriority(LPUART7_IRQn, configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY);
LPUART_EnableInterrupts(LPUART7, kLPUART_RxDataRegFullInterruptEnable);
EnableIRQ(LPUART7_IRQn);
```

### 5. GPIO（GPIO2_IO14 输出 / IO15 输入）

- 引脚：`GPIO_IO14 = GPIO2_IO14`（J15-8，输出）、`GPIO_IO15 = GPIO2_IO15`（J15-10，输入）；**J15-39 才是 GND**（J15-9 是 GPIO_IO04，不能当地）。
- 回环：J15-8 ↔ J15-10 → `OUT` 翻转时 `IN` 跟随。
- 应用层用 **RGPIO API**：`RGPIO_PinInit / RGPIO_PinWrite / RGPIO_PinRead`（不要手写寄存器）。

```c
RGPIO_PinInit(GPIO2, 14, &outputConfig);
RGPIO_PinWrite(GPIO2, 14, output);
input = RGPIO_PinRead(GPIO2, 15);
```

#### ⭐ 本项目的核心坑：GPIO2 的"安全域"

**现象**：USB/RAM 启动下 GPIO 正常；**SD 完整启动后** M7 打印 `OUT` 在变，但 `PCNS=FFFFFFFF`、`PDOR` 不动、引脚无波形。

**根因**（已定位到源码行）：A55 启动链里的 **BL31/ATF** 在 `imx95_bl31_setup.c` 的 `bl31_plat_arch_setup()` 里**无条件**执行：

```c
mmio_write_32(GPIO2_BASE + 0x10, 0xffffffff);   /* PCNS: 把整个 GPIO2 划给非安全世界 */
mmio_write_32(GPIO2_BASE + 0x18, 0xffffffff);   /* PCNP */
```

而 RGPIO 的 PCNS/PCNP 是**逐引脚的"安全域独占"**语义：`NSE=0` 归安全世界、`NSE=1` 归非安全世界；**另一侧访问会"读回 0、写被忽略"（且不 fault）**。M7 是**安全态**主子，所以 SD 启动后 M7 对 GPIO2 的访问被静默丢弃。

> 注意两层要分清：SM 配置里的 `PIN_GPIO_IO14 OWNER` 是 **IOMUX/Pinctrl** 层（M7 有权复用它）；`PCNS` 是 **RGPIO 安全域**层（由 BL31 设）。**SM 源码里没有任何写 PCNS 的代码**——所以这不是"配置没对齐"，而是两层各做各的冲突。

**修复（M7 侧按需 reclaim）**：把自己两根引脚重新拉回安全域，且**只在被划走时写一次**：

```c
static void gpio_reclaim_pins(void)
{
    GPIO2->PCNS &= ~GPIO_PIN_MASK;   /* 只清 bit14/15，保留其余给 A55 */
    GPIO2->PCNP &= ~GPIO_PIN_MASK;
}
/* 循环里 */
if ((GPIO2->PCNS & GPIO_PIN_MASK) != 0U) { gpio_reclaim_pins(); }
```

**PCNS 三态判读口诀**（COM18）：

| PCNS | 含义 |
|---|---|
| `00000000` | BL31 没跑（USB/RAM 启动，或 SD 未到 BL31） |
| `FFFFFFFF` | BL31 跑了、M7 没在它之后 reclaim（失败） |
| `FFFF3FFF` | BL31 跑了、M7 已夺回 14/15 位（✔ 正确） |

**更彻底的方向**（产品级）：给 M7 独立 GPIO 控制器 / 把 BL31 改成逐引脚 / 走 RPMsg 让 Linux 代管。

### 6. 中断与优先级

- 串口接收中断：`NVIC_SetPriority(LPUART7_IRQn, configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY)`（必须 ≤ 该阈值才能调用 `FromISR` API）。
- 原则：ISR 短、快；用 `...FromISR` + `portYIELD_FROM_ISR`。

### 7. 多核资源模型（SM / LM / DID / TRDC / PIN）

- SM 把 SoC 分成**逻辑机（LM）**：LM0=SM、LM1=M7（DID=4）、LM2=A55（DID=3）。
- 每个 LM 有独立的**资源所有权**（`OWNER`）与**访问权限（TRDC）**；`PIN_GPIO_IO14/15` 归 M7。
- M7 `boot=2` 先启动、A55 `boot=3` 后启动 → BL31 的 PCNS 写入**必然晚于** M7 初始化。

### 8. 踩坑清单

| 坑 | 现象 | 结论/对策 |
|---|---|---|
| SM 自编不复位 | 自编 SM 启动即复位循环 | 需用**官方 ARM GNU 工具链 14.2.rel1** 编 SM |
| 未冷复位 | UUU 看到 `SPL1 SDPV` | 拔 J11 15 s 再插，必须看到 `SDPS` |
| GPIO2 安全域 | SD 启动 `PCNS=FFFFFFFF`、无波形 | M7 侧按需 reclaim（或改 BL31/独立控制器） |
| `vTaskDelay` 做周期 | 周期漂移 | 周期任务用 `vTaskDelayUntil` |
| DWT 不使能 | `period=0` | 必须调 `MSDK_EnableCpuCycleCounter()`（`MSDK_GetCpuCycleCount` 只读） |
| 统计溢出 | `avg/fcpu~` 错 | 累加用 `uint64_t` |
| BL31 二进制补丁 | 改了会启动失败 | 编译器复用寄存器，必须源码级改 |
| 串口当实时基准 | 不可靠 | 用 DWT/GPIO + 逻辑分析仪 |

### 9. 关键文件与命令速查

```text
镜像/脚本（build/pro-gpio/）
  flash-m7-rt.bin          实时性测试容器（UART + GPIO + DWT 测量）
  flash-m7-gpio-reclaim.bin 仅 GPIO/UART 的可复现容器
  rt-ram.uuu               RAM 启动脚本

打包
  tools/build-container-variant.sh <SM> <M7> <out>   # 组装启动容器

文档
  docs/FRDM-IMX95-PRO-FreeRTOS-M7.md   # 原理/排查/24 节完整记录
```

### 10. 下一步（把笔记变成更多实践）

1. 加**信号量/队列 + 多优先级**任务实验，验证阻塞/唤醒/抢占与优先级反转；
2. 打开 `configCHECK_FOR_STACK_OVERFLOW` + `uxTaskGetStackHighWaterMark`，记录栈余量；
3. 打开 `configGENERATE_RUN_TIME_STATS`（用 DWT），输出各任务 CPU 占比；
4. 测**中断响应延迟**与**端到端延迟**（GPIO 边沿→ISR→任务→GPIO）；
5. 长时间运行 + 栈/堆水位、看门狗、异常恢复。

---

## 十、实时性测试（Cortex-M7 / FreeRTOS）

## 实时性测试（Cortex-M7 / FreeRTOS）

> 本文把 `../实时性.md`（方法论）与本次 FRDM-IMX95-PRO / Cortex-M7 的**实测数据**合并。
> 工程细节见 `09-工程实践（i.MX95 M7）.md`。

### 1. 什么是实时性

实时系统的核心不是"跑得快"，而是"**结果在规定时间窗口内产生**"。计算正确但超过时限，在实时系统里可能等同错误。

周期任务的时间定义：

| 术语 | 含义 |
|---|---|
| Release time | 任务被释放（可运行）的时刻 |
| Start time | 实际开始执行的时刻 |
| Finish time | 执行结束的时刻 |
| **Response time** | 事件/释放 → 完成（重点看**最大值**） |
| Execution time | 实际占用 CPU 的时间 |
| Period | 两次释放的目标间隔 |
| **Deadline** | 本次结果必须完成的最晚时刻 |
| **Jitter** | 实际相对目标的变化（看最大/峰峰/分布） |

基本条件：

```text
每次执行时间 ≤ 允许执行窗口
完成时间   ≤ deadline
最坏情况下仍不丢 deadline
```

### 2. 三种"实时"

| 类型 | 超时后果 | 例子 |
|---|---|---|
| 硬实时 hard | 安全/功能失效 | 保护动作、运动控制、采样闭环 |
| 软实时 soft | 质量下降 | 音频缓存、显示刷新 |
| Firm real-time | 结果失去价值但系统继续 | 过期的采样数据 |

> **类别由产品 deadline 决定**，不由"用了 FreeRTOS"决定。FreeRTOS 只提供机制，不自动保证硬实时。

### 3. 关键指标（别只看平均值）

- **周期/频率**：测相邻**释放点**之间的时间，不是两行串口文本之间的时间。
- **响应/延迟**：如"GPIO 输入边沿 → GPIO 输出响应"，看平均 + 最大 + 分布。
- **抖动 jitter**：平均再准，偶发一次大延迟也可能不满足实时要求。
- **WCET（最坏执行时间）**：是"在规定输入/编译/缓存/总线竞争/中断负载下的**最坏情况上界**"，不是某次测试看到的最大值。
- **CPU 利用率与可调度性**：`U = Σ(执行时间/周期)`，但还要看优先级、阻塞、中断、禁中断区间；高优任务达标不等于低优任务不被饿死。

### 4. FreeRTOS 中实时性的基础

| 机制 | 要点 |
|---|---|
| 抢占式调度 | 高优先级就绪即抢占；但**不能**打断关中断的临界区 |
| Tick/延时 | 周期任务用 `vTaskDelayUntil`（绝对）；tick 分辨率 ≠ 响应延迟 |
| 中断协作 | ISR 只做必要工作 + `FromISR` 唤醒任务；检查中断优先级上限 |
| 同步/优先级反转 | 互斥量有优先级继承；记录最大阻塞时间 |
| 内存确定性 | 关键路径避免动态分配；用静态/启动期分配 |
| 监测 | `configASSERT`、栈溢出钩子、`uxTaskGetStackHighWaterMark`、`xPortGetMinimumEverFreeHeapSize` |

### 5. 测试方法与工具

- **高精度计时**：Cortex-M7 的 **DWT cycle counter**（本项目 800 MHz，1 cycle = 1.25 ns）。
- **严格周期**：`vTaskDelayUntil()`（与任务体耗时解耦）。
- **物理验证**：GPIO 边沿用**逻辑分析仪**测（J15-8 输出、J15-39 GND）。
- **不要用**：Windows 串口接收时间、MobaXterm 显示时间、`printf` 间隔——串口发送本身会阻塞并引入不确定延迟。

### 6. 本次实现（代码要点）

```c
MSDK_EnableCpuCycleCounter();   /* 必须先使能！GetCpuCycleCount 只读不使能 */

next = xTaskGetTickCount();
prev = MSDK_GetCpuCycleCount();
for (;;)
{
    vTaskDelayUntil(&next, pdMS_TO_TICKS(500U));   /* 严格 500 ms 周期 */

    now = MSDK_GetCpuCycleCount();
    d   = now - prev; prev = now;                  /* period（周期，cycles） */

    if ((GPIO2->PCNS & GPIO_PIN_MASK) != 0U)       /* BL31 抢走就夺回 */
        gpio_reclaim_pins();

    w0 = MSDK_GetCpuCycleCount();
    output ^= 1U;
    RGPIO_PinWrite(GPIO2, GPIO_OUTPUT_PIN, output);
    input = RGPIO_PinRead(GPIO2, GPIO_INPUT_PIN);
    work = MSDK_GetCpuCycleCount() - w0;           /* work（执行时间，cycles） */

    /* 统计（跳过首拍残段；sum_d 用 uint64 防溢出），每 20 拍打印 min/max/avg/jitter */
}
```

镜像：`build/pro-gpio/flash-m7-rt.bin`（RAM 用 `rt-ram.uuu`，SD 用 `uuu -b sd ... flash-m7-rt.bin`）。

### 7. 实测数据

**条件**：M7 @ 800 MHz，tick 200 Hz，`vTaskDelayUntil(500 ms)`，无其它负载。

| 启动方式 | period min/max/avg (cyc) | jitter | work min/max/avg (cyc) | fcpu~ |
|---|---|---|---|---|
| RAM | 400000000 / 400000006 / 400000000 | **6 cyc ≈ 7.5 ns** | 109 / 115 / 112 | 800 MHz |
| SD 完整启动 | 400000000 / 400000006 / 400000000 | **0~6 cyc（≈0~7.5 ns）** | 109 / 115 / 112 | 800 MHz |

原始日志（SD，连续两批）：

```text
RT n=20 period[min=400000000 max=400000006 avg=400000000 jitter=6] work[min=109 max=128 avg=112] fcpu~800000000 Hz
RT n=20 period[min=400000000 max=400000000 avg=400000000 jitter=0] work[min=109 max=115 avg=112] fcpu~800000000 Hz
```

**结论**：

- 实际主频 **800 MHz**（`period × 2` 反推，与 `SystemCoreClock` 一致）；
- 周期 = **400,000,000 cyc = 500 ms，零偏差**；
- **抖动 ≈ 0~7.5 ns**，相对 500 ms 约 **1.5×10⁻⁵**，调度非常稳；
- 任务体（GPIO 翻转 + 读取，含 PCNS 判断）≈ **112 cyc ≈ 140 ns**；
- **SD 与 RAM 一致**：BL31 只在 A55 启动时改一次 PCNS，对 M7 稳定运行无持续影响。

### 8. 踩坑记录

| 坑 | 现象 | 原因/对策 |
|---|---|---|
| DWT 未使能 | `period=0 work=0` | 只调了 `MSDK_GetCpuCycleCount()`（只读）；必须调 `MSDK_EnableCpuCycleCounter()` |
| 32 位求和溢出 | `avg/fcpu~` 明显偏小 | `sum_d` 用 `uint32_t` 累加 19×4e8 溢出；改 `uint64_t` |
| 首拍残段 | 第一拍 396,114,222 拉大 jitter | 第一段是"从任务启动到首次释放"的不完整周期，应排除 |
| 串口干扰 | — | 打印放在测量窗口之外；高频测试建议关打印、用内存缓冲 |

### 9. 待测清单（下一步）

1. **中断响应延迟**：外部信号/片上定时器 → ISR 入口翻转 GPIO，逻辑分析仪测。
2. **端到端响应**：输入 GPIO 边沿 → ISR → 任务 → 输出 GPIO（平均/最大/抖动）。
3. **WCET**：空载 / 正常 / 峰值 / 并发中断 / 总线竞争 下分别测。
4. **deadline miss 计数**：每次完成比较绝对 deadline。
5. **调度压力**：加不同优先级周期 + 通信 + 后台任务。
6. **同步压力**：队列满/空、信号量/互斥竞争、优先级反转场景，测最大阻塞。
7. **资源稳定性**：长时间运行看栈/堆余量、CPU 利用率、错误计数。
8. **跨核**：A55/RPMsg、共享内存 + cache 一致性对延迟的影响。

### 10. 产品级报告应包含

- 需求编号、任务名、周期、deadline、允许抖动、故障后果；
- 芯片时钟、编译器/优化、FreeRTOS/SDK 版本、镜像哈希；
- M7 内存布局（TCM/DDR）、Cache 设置、DMA/共享资源；
- 任务优先级、栈大小、队列长度、互斥/中断配置；
- 空载/正常/峰值/并发中断/异常输入条件；
- 平均、最小、最大、峰峰、分位数、deadline miss、测试时长；
- 栈/堆最小余量、CPU 利用率、看门狗/复位记录；
- 测量工具、采样率、接线、原始 CSV 与分析脚本。

---

## 一、验证优先级抢占的方法（忙等+阻塞）

## 验证优先级抢占的方法（忙等+阻塞）

### 这篇知识解决什么问题

两个任务只用 `vTaskDelay` 时，各自大部分时间都在阻塞，看不出优先级抢占。要在一套最小代码里“看见”并量化抢占，需要一个专门制造“高优先级就绪且占着 CPU”的方法。

适用范围：支持抢占式调度的 RTOS 与 Cortex-M 类平台。示例来自 FRDM-IMX95-PRO 的 M7 FreeRTOS 工程。

### 一、抢占为什么“看不见”

抢占发生在“高优先级任务就绪、低优先级任务正在运行（或将要用 CPU）”的时刻。若两个任务都用 `vTaskDelay` 周期性阻塞，任一时刻通常只有一个任务就绪，CPU 大部分空闲或跑 Idle，没有可观察的抢占对象。

### 二、方法：让高优先级任务“忙等”占住 CPU

- 高优先级任务周期 = 忙等 B（不让出 CPU）+ 阻塞 D。
- 低优先级任务用较短周期 P 翻转一个 LED/计数器，并打印本次与上次的时间间隔。
- 忙等期间低优先级任务虽已就绪却得不到调度，打印间隔被拉长到约 B，LED 肉眼停顿。

一份代码同时体现两件事：抢占（低优被推迟）和节奏随阻塞变化（改 B/D 即改停顿长度与有效频率）。

### 三、实现要点

1. 忙等不能用 `vTaskDelay`（那是阻塞、会让出 CPU）。
2. 忙等内部不调用任何 RTOS API、不 `taskYIELD`，否则不再独占 CPU。
3. 计时用 CPU 周期计数器（Cortex-M3+ 的 DWT CYCCNT），结果与主频解耦；此类计数器需先使能（TRCENA/CYCCNTENA），只读函数不会自动使能。
4. 打印间隔用系统 tick，便于跨平台；务必注意 tick 与 ms 的换算。

### 四、常见陷阱

- 把 tick 当成 ms：显示值先是 tick 数，需乘 `1000/configTICK_RATE_HZ`。例如 200 Hz 时 20 tick=100 ms。
- 首拍/残段：任务启动到首次释放的间隔不完整，统计时应剔除。
- 忙等被编译器优化：用周期计数器或 `volatile` 保证循环不被消除。
- 参数选择：B 太短看不出停顿，太长会挤掉其它功能；一般让 B 明显大于低优任务周期。

### 五、对照实验（证明是“优先级”而不是别的原因）

把低优先级任务临时设为与高优先级相同优先级。若 `configUSE_TIME_SLICING` 开启，同优先级按 tick 轮转，长停顿消失；改回低优先级后停顿重现。用于排除“死机 / 其它阻塞”等误判。

### 六、项目证据

- [FRDM-IMX95-PRO 2026-09-16 开发日志（双LED抢占实验）](../../10-项目/FRDM-IMX95-PRO/开发日志.md)
- 实测：高优忙等 600 ms / 阻塞 400 ms，低优周期 100 ms（20 tick）；COM18 出现 `20,20,20,140` 循环，`140 tick = 700 ms = 600+100`，循环 200 tick = 1000 ms 与高优周期一致 → 低优被推迟 600 ms，抢占成立。

---

## 十、FreeRTOS 移植学习

## FreeRTOS 移植学习

### 当前目标

当前目标不是立即修改 FreeRTOS 内核，而是先在 FRDM-IMX95-PRO 的 Cortex-M7 上运行一个官方示例，打通工程编译、固件加载和串口输出流程。完成基本运行后，再根据现有工程区分通用内核代码、处理器移植代码和板级初始化代码。

### FreeRTOS 的基本组成

FreeRTOS 是一个实时操作系统内核，主要负责任务管理、任务调度、任务间通信、同步、软件定时器和内存管理。它不等于完整的 Linux，也不负责提供文件系统、网络协议栈和完整的设备模型。需要网络、文件系统或图形功能时，通常由芯片 SDK、BSP 或独立组件提供。

FreeRTOS 源码可以按三部分理解：

1. 通用内核代码，例如 `tasks.c`、`queue.c`、`list.c` 和 `timers.c`。
2. 移植层代码，通常位于 `portable` 目录，负责处理器寄存器、异常和上下文切换。
3. 工程配置和板级代码，例如 `FreeRTOSConfig.h`、启动文件、链接脚本、时钟、串口和 GPIO 初始化。

### 与 uC/OS-II 的对应关系

uC/OS-II 和 FreeRTOS 都是抢占式实时内核，都需要任务控制块、任务栈、就绪状态、阻塞状态和时钟节拍。两者的函数名称和数据结构不同，但学习思路可以对应起来：

| uC/OS-II | FreeRTOS | 作用 |
|---|---|---|
| `OSTaskCreate()` | `xTaskCreate()` | 创建任务 |
| `OSStart()` | `vTaskStartScheduler()` | 启动调度器 |
| `OSTimeDly()` | `vTaskDelay()` | 延时并进入阻塞 |
| 信号量 API | `xSemaphoreCreateBinary()` 等 | 任务同步 |
| `OS_TCB` | `TCB_t` | 任务控制块 |
| `OS_STK` | 任务栈数组或动态栈空间 | 保存任务运行上下文 |

FreeRTOS 的优先级通常是数值越大优先级越高，这一点与 uC/OS-II 中数值越小优先级越高不同，阅读代码时需要特别注意。

### 推荐的源码阅读顺序

先阅读一个最小示例，不要直接从整个内核开始。按照 `main()` 中的调用顺序跟踪：

1. `xTaskCreate()` 如何分配或准备任务控制块和任务栈。
2. `vTaskStartScheduler()` 如何创建空闲任务并启动第一个任务。
3. `vTaskDelay()` 如何把当前任务从就绪列表移到延时列表。
4. Tick 中断如何更新时间和唤醒到期任务。
5. `vTaskSwitchContext()` 如何选择下一个就绪任务。
6. PendSV 或对应异常处理函数如何保存和恢复寄存器。
7. `port.c` 和汇编文件如何实现第一次启动和上下文切换。

### 调度器要回答的几个问题

阅读调度器时，始终围绕以下问题：

- 当前有哪些任务。
- 每个任务当前是运行、就绪、阻塞还是挂起。
- 哪些任务位于就绪列表。
- 当前最高优先级的就绪任务是谁。
- 什么事件触发调度，是 Tick、中断、任务主动让出还是任务解除阻塞。
- 切换时当前任务的哪些寄存器被保存，下一任务的哪些寄存器被恢复。

理解这些问题后，再去看具体的链表、位图和临界区代码，源码会更容易对应到实际行为。

### 移植的实际含义

移植不是把所有 FreeRTOS 源码重新编写一遍，而是让通用内核适配目标处理器和工程环境。对于 M7，主要需要处理启动文件、异常向量、系统节拍、中断优先级、任务栈初始布局、上下文切换、链接脚本和内存分配。串口、I2C、GPIO 等驱动属于板级或 SDK 部分，不属于 FreeRTOS 调度器本身。

### FreeRTOS Kernel 与板级 SDK 的区别

FreeRTOS Kernel 仓库主要包含任务、队列、定时器等通用内核代码，以及不同 CPU 和编译器对应的移植层。它不包含一块复杂开发板正常运行所需的全部内容，例如 i.MX95 的启动流程、时钟配置、内存布局、引脚配置、串口驱动和多核固件加载方式。

NXP SDK 或项目 BSP 通常在 FreeRTOS Kernel 之外补充以下内容：

- 芯片启动文件和中断向量表
- M7 或 M33 的链接脚本
- 时钟、引脚和内存初始化
- UART、I2C、GPIO 等外设驱动
- 开发板配置和示例工程
- 编译、生成固件和调试所需的工程文件

因此，单独下载 FreeRTOS Kernel 可以用于阅读内核源码，但不能直接作为 FRDM-IMX95-PRO 的完整可烧写工程。当前应先使用 NXP 或部门提供的可运行工程。

### 计划

#### 第一阶段：运行已有示例

1. 启动开发板预装的 Linux。
2. 查看 `/lib/firmware/` 中的 Cortex-M7 示例固件。
3. 根据 `AN14748` 选择并运行一个官方 M7 示例。
4. 通过 M7 串口确认程序已经运行。

#### 第二阶段：完成编译和加载

1. 确认示例源码来自 MCUXpresso SDK、Application Code Hub 或 Linux BSP 配套源码。
2. 确认编译器、SDK 版本和目标板配置。
3. 不修改代码，先完整编译一次示例。
4. 对比生成的 ELF 和 BIN 文件，了解各文件用途。
5. 将固件传入 Linux，再由 Linux 加载到 M7，或者按项目规定使用调试器下载。

#### 第三阶段：阅读 FreeRTOS 源码

先从应用调用关系开始阅读：

1. `main()` 中的硬件初始化和任务创建。
2. `xTaskCreate()` 如何建立任务控制块和任务栈。
3. `vTaskStartScheduler()` 如何启动第一个任务。
4. `tasks.c` 中任务状态、就绪列表和调度选择。
5. `portable` 目录中 Cortex-M7 对应的 `port.c` 和汇编代码。
6. SysTick、PendSV 和 SVC 在调度过程中的作用。
7. 链接脚本、向量表和启动文件如何与 FreeRTOS 移植层配合。

### 移植完成的基本判断

FreeRTOS 能够在目标核心上启动，至少两个不同优先级的任务可以按照预期运行，系统节拍正常，延时和任务切换正常，串口能够持续输出，并且中断、信号量等基本功能可以正常使用。进一步还需要检查任务栈、内存占用、长时间运行稳定性和异常处理。

### 当前待确认事项

- FreeRTOS 最终运行在 M7 还是 M33。
- 部门是否已有 FRDM-IMX95-PRO 配套工程。
- 项目规定的 SDK、BSP 和编译器版本。
- 固件由 Linux remoteproc 加载，还是通过 JTAG 调试器下载。
- 最终验收使用哪些外设和测试场景。

### 板载 Linux 中已经存在的 M7 示例

登录板载 Linux 后，在 `/lib/firmware` 中发现了当前 19x19 平台的 M7 固件，例如：

- `imx95-19x19-evk_m7_TCM_hello_world.bin`
- `imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.bin`
- `imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.bin`
- `imx95-19x19-evk_m7_TCM_flexcan_linux.bin`

这些文件说明当前系统已经带有可以直接用于验证的 M7 示例，其中带有 `rtos` 的文件名与 FreeRTOS 示例有关。它们比立即从空目录创建 FreeRTOS 工程更适合作为第一个学习对象。下一步先通过 Linux 的 remoteproc 接口查看 M7 状态，再运行最简单的 `hello_world`，之后再运行带有 RPMsg 的 RTOS 示例。

### 第一次运行示例的原则

先查看，不修改：

```bash
ls -l /sys/class/remoteproc
for r in /sys/class/remoteproc/remote*; do echo $r; cat $r/name 2>/dev/null; cat $r/state 2>/dev/null; cat $r/firmware 2>/dev/null; done
```

确认 remoteproc 编号、名称和当前状态后，再根据官方应用笔记选择固件。不能直接把 `echo start` 写入未知的 remoteproc，也不能把不同平台的固件名称直接替换使用。

### 当前 M7 启动阻塞

`remoteproc1` 已确认是 Cortex-M7，Linux 可以读取 `hello_world.elf`，但启动时报告：

```text
lmm(1) not under Linux Control
Boot failed: -13
```

这不是 FreeRTOS 内核错误，也不是 ELF 编译错误，而是启动镜像中的多核资源划分不允许 Linux 控制 M7。FreeRTOS 是否能够运行，需要先解决 M7 的启动和资源所有权。

### 接下来的工程路线

1. 从 MCUXpresso SDK Builder 获取 i.MX95 19x19 平台的 SDK，官方应用笔记示例使用 `IMX95LPD5EVK-19`、SDK 25.12.00 和 ARM GCC。
2. 在 SDK 中先编译 M7 `hello_world`，再编译带 `rtos` 的 RPMsg 示例。
3. 获取与当前 FRDM-IMX95-PRO Linux BSP 版本匹配的 `imx-mkimage` 和启动固件。
4. 生成允许 A55 控制 M7 的 RPMsg 启动镜像，或者将 M7 固件直接打包进 `flash.bin`。
5. 优先将测试镜像写入 MicroSD，保留当前能够正常启动的 eMMC。
6. 从 MicroSD 启动后再次验证 M7，再进入 FreeRTOS 示例和源码学习。

这里 SDK 负责提供 M7 工程、启动代码、链接脚本、驱动和 FreeRTOS 组件，Linux BSP 与 `imx-mkimage` 负责平台启动镜像和 System Manager 配置，两者作用不同，缺少任何一部分都不能完成当前多核平台上的完整启动。

### 如何判断板子有没有 FreeRTOS

板子有没有 FreeRTOS 可能表示四种不同情况，需要分别判断：

1. 硬件是否支持运行 FreeRTOS。i.MX95 内部有 Cortex-M7，硬件支持运行裸机程序和 FreeRTOS。
2. 存储中是否有 FreeRTOS 固件。当前 Linux 的 `/lib/firmware` 中有文件名包含 `m7`、`rtos` 和 `rpmsg_lite` 的 ELF 与 BIN，说明系统镜像已经附带 M7 RTOS 示例固件。
3. FreeRTOS 当前是否正在运行。`remoteproc1/state` 为 `offline`，M7 串口没有输出，因此当前没有 M7 FreeRTOS 程序在运行。
4. 是否已经有可修改和编译的 FreeRTOS 源码工程。当前电脑尚未获得正确的 i.MX95 SDK，因此还没有对应板卡的可编译工程。

可以在板载 Linux 中进一步检查 ELF 是否保留 FreeRTOS 字符串：

```bash
strings /lib/firmware/imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.elf | grep -i freertos | head
```

即使没有搜索结果，也不能说明它没有使用 FreeRTOS，因为编译时可能去除了相关字符串。最终应以 SDK 示例的构建配置和源码组件为准。

### SDK Builder 板卡选择记录

在 SDK Builder 中搜索 `IMX95`，结果包含：

- `FRDM-IMX95 (MIMX9596xxxxN)`
- `IMX95LP4XEVK-15 (MIMX9596xxxxN)`
- `IMX95LPD5EVK-19 (MIMX9596xxxxN)`
- `IMX95VERDINEVK (MIMX9596xxxxN)`

当前板卡是 `FRDM-IMX95-PRO`，不是列表中的普通 `FRDM-IMX95`。当前 Pro 板使用 19x19 封装和 LPDDR5，板载 Linux 中的 M7 固件也以 `imx95-19x19-evk` 命名。`AN14748` 的 SDK 获取步骤使用 `IMX95LPD5EVK-19`，因此在 Pro 专用 SDK 尚未出现在 Builder 时，先选择 `IMX95LPD5EVK-19` 用于学习和编译 M7 示例。板级引脚和外设差异仍需结合 FRDM-IMX95-PRO 工程或 BSP 处理。

已下载的 `SDK_25_09_00_MCXW23.zip` 属于 MCXW23 无线 MCU。压缩包中出现 `mcuxsdk-frdmmcxw23.pdf`、`mcxw23evk` 和 `wireless/mcxw23` 等目录，可以确认它不是 i.MX95 SDK，不能用于当前板卡。

### 当前FreeRTOS上板目标

已经使用IAR 9.70.4编译SDK 26.06.00中的Cortex-M7示例，编译结果为0错误、0警告。板载Linux根文件系统还自带`imx95-19x19-evk_m7_TCM_hello_world.bin`和多组名称包含`rtos`的RPMsg Lite示例。因此当前工作不是从空工程移植FreeRTOS内核，而是先解决M7启动和Pro板串口输出。

第一阶段的最小完成标准为：M7能够执行程序，FreeRTOS调度器能够启动任务，串口能够观察到任务输出。之后再增加两个任务、延时切换、队列或信号量和GPIO翻转，用于验证系统节拍、任务调度和基本外设。最后才进入`tasks.c`、就绪列表、SysTick、PendSV和移植层源码分析。

### 2026-09-14实机进度

此前“FreeRTOS当前未运行”“尚未获得正确SDK”等内容是早期排查状态，现已更新：

- 已取得`SDK_26_06_00_IMX95LPD5EVK-19`，并以其M7 FreeRTOS示例为工程基础。
- 已使用IAR完成编译，结果为0错误、0警告。
- 已适配FRDM-IMX95-PRO实际使用的LPUART7，COM18完成字符串输出和输入回显。
- 已在FreeRTOS任务中加入GPIO2_IO14翻转和GPIO2_IO15读取，每500 ms执行一次。
- 已通过自定义System Manager配置把GPIO2的TRDC资源所有权从LM2/A55转给LM1/M7。
- J15-8与J15-10物理连接后，COM18持续得到`OUT=0, IN=0`与`OUT=1, IN=1`。
- 逻辑分析仪测得完整周期约1.00008 s，频率约1 Hz。

因此当前可以确认“FreeRTOS程序已经在M7上运行，串口收发和GPIO输入输出均已验证”。这属于USB RAM临时启动成功，不等于已经把程序持久化写入eMMC或SD卡。

本次GPIO任务也证明了FreeRTOS的基本调度链路在工作：任务能够周期运行，`vTaskDelay()`对应的系统节拍有效，任务在延时后能够再次被调度。若后续验收要求更完整的RTOS功能，还需增加多任务优先级、队列或信号量、中断唤醒、栈余量和长时间稳定性测试。

GPIO测试同时出现的`Reset LM 2, reason=fccu, errId=19`属于LM2/A55的WDOG3超时和System Manager故障恢复，不是M7 FreeRTOS任务崩溃。M7的GPIO任务在LM2反复复位期间仍持续输出，说明LM1与LM2的故障隔离生效。A55问题需要在启动镜像和SM资源配置层单独排查。

### 第二阶段方向：从功能验证进入实时性验证

第一阶段基本完成，但“任务能周期打印”和“GPIO能翻转”只能证明功能链路可用，不能证明产品级实时性。下一阶段必须定义每个关键任务的周期、响应时间、deadline、允许抖动和超时后果，再使用M7硬件计时器、GPIO和逻辑分析仪测最大值，而不是使用串口文本时间判断。

重点指标包括：中断响应延迟、输入到输出的端到端延迟、任务实际执行时间、最坏执行时间（WCET）估计、周期抖动、deadline miss、CPU利用率、任务最大阻塞时间、栈最小余量和堆最小余量。还要在高负载、多中断、队列竞争、互斥量竞争、DMA/共享内存和长时间运行条件下重复测量。

对当前i.MX95 M7工程，先做本地实时链路，再测A55/Linux或RPMsg跨核链路。TCM/DDR位置、Cache、总线竞争、System Manager/TRDC权限和USB RAM启动方式都要写入测试条件。串口只用于低频状态日志，不能作为高精度实时测量手段。

---

## 二、FreeRTOS实时性

## FreeRTOS实时性

### 记录范围

本文用于第二阶段学习和测试，目标是从“程序能运行”推进到“能够证明系统满足时限、稳定性和资源约束”。当前对象为FRDM-IMX95-PRO上的Cortex-M7 FreeRTOS程序。实时性结论必须以实测数据和明确需求为依据，不能只根据串口输出正常或任务周期大致稳定来判断。

官方参考入口：

- FreeRTOS官方文档：任务调度、软件定时器、队列、信号量、互斥量和运行时间统计。
- NXP MCUXpresso SDK官方示例及其板级说明：M7启动文件、时钟、LPUART、RGPIO、链接脚本和FreeRTOS工程配置。
- NXP AN14748：i.MX95上M7应用的构建、启动镜像和运行方式。
- FRDM-IMX95-PRO用户手册、原理图和BSP：实际引脚、启动模式、串口映射、系统管理和资源分配。

### 第一阶段和第二阶段的区别

第一阶段已经完成：IAR和SDK环境、M7 FreeRTOS工程编译、USB+UUU临时启动、COM18串口输入输出、GPIO2_IO14输出、GPIO2_IO15输入以及物理回环。它证明工程能够构建，M7能够执行，调度器和基本驱动能够工作。

这还不能证明产品级实时性。产品级验证还要回答：输入事件最迟多久得到响应，周期任务是否每次按时完成，中断和任务的最大延迟是多少，系统负载接近上限时是否仍满足deadline，异常时是否可检测和恢复，运行很长时间后是否发生丢任务、栈溢出、堆耗尽或看门狗复位。

### 什么是实时性

实时系统的核心不是“运行速度快”，而是“结果在规定时间窗口内产生”。同一个结果即使计算正确，如果超过允许时间，在实时系统中仍然可能等同于错误。

对一个周期任务，可以定义：

- **Release time**：任务被释放、变为可运行的时间。
- **Start time**：任务实际开始执行的时间。
- **Finish time**：任务本次执行结束的时间。
- **Response time**：从事件发生或任务释放到任务完成的时间。
- **Execution time**：任务实际占用CPU执行的时间。
- **Period**：任务两次释放之间的目标间隔。
- **Deadline**：本次结果必须完成的最晚时间。
- **Jitter**：实际时间相对目标时间的变化量，通常关注最大值、峰峰值和统计分布。

基本条件是：

```text
每次执行时间 <= 允许执行窗口
完成时间 <= deadline
最坏情况下仍不能丢失deadline
```

实时性不是只有一种：

1. **硬实时 hard real-time**：错过一次deadline就可能造成安全或功能失效，例如保护动作、运动控制和采样闭环。
2. **软实时 soft real-time**：偶尔超时会降低质量但不一定造成系统失效，例如音频缓存、显示刷新和普通通信。
3. **Firm real-time**：超时结果失去价值，但系统可以继续运行，例如过期采样数据。

最终类别由产品需求决定，不由“使用了FreeRTOS”自动决定。FreeRTOS只是提供调度和同步机制，不能替产品定义deadline，也不能自动保证硬实时。

### 必须区分的几个指标

#### 周期和频率

任务目标每1 ms、10 ms或500 ms执行一次，是周期要求。实际周期应该测相邻释放点之间的时间，而不是测两行串口文本之间的时间。串口发送本身会阻塞并引入不确定延迟，不能作为高精度周期基准。

#### 响应时间和延迟

例如GPIO输入边沿到GPIO输出响应之间的时间，包括中断响应、调度、任务等待、处理和输出寄存器写入。要记录平均值、最大值和分布，产品验收通常重点看最大值。

#### 抖动 jitter

如果目标周期是10 ms，实际释放时刻可能是9.99 ms、10.02 ms、9.98 ms。相对目标的变化就是抖动。平均周期正常而偶发一次100 ms延迟，仍可能不满足实时要求，因此不能只看平均值。

#### WCET

**Worst-Case Execution Time**，最坏执行时间。它不是一次测试中看到的最大值，而是在规定输入、编译配置、缓存状态、总线竞争、中断负载和温度电压范围内，对最坏情况的工程估计或测量上界。产品级报告必须说明测量条件和覆盖范围。

#### CPU利用率和可调度性

对周期任务，粗略利用率为：

```text
U = sum(每个任务的执行时间 / 任务周期)
```

但只看总利用率不够，还要考虑任务优先级、阻塞时间、中断时间、禁中断区间、共享资源和调度器开销。高优先级任务可能满足deadline，而低优先级任务已经长期得不到运行。应同时检查每个关键任务的响应时间和deadline miss。

### FreeRTOS中实时性的实现基础

#### 抢占式调度

启用抢占式调度后，较高优先级的就绪任务可以抢占较低优先级任务。它不能抢占关闭中断的临界区，也不能消除高优先级任务长期占用CPU造成的影响。优先级设计必须服务于deadline，而不是简单地把所有关键任务都设成最高优先级。

#### Tick和延时

`vTaskDelay()`适合相对延时，但任务执行时间会叠加到下一次释放时间，周期可能漂移。周期任务通常应研究`vTaskDelayUntil()`，它按照绝对节拍计算下一次唤醒点，更适合固定周期任务。Tick分辨率不是实际响应延迟的全部；中断、临界区、同优先级任务和硬件总线访问都会影响实际结果。

#### 中断和任务协作

快速中断服务程序只做必要的硬件确认、时间戳和数据搬运，然后使用FromISR版本API唤醒任务。耗时计算、格式化字符串和阻塞式串口发送不应放在高频ISR中。需要检查中断优先级是否满足FreeRTOS可调用ISR API的限制。

#### 同步和优先级反转

互斥量用于保护共享资源，并支持优先级继承；二值信号量、计数信号量和队列用于同步或传递数据。不能用一个普通二值信号量代替所有互斥量，也不能让高优先级任务长时间等待低优先级任务持有的资源。要记录最大阻塞时间，检查是否存在优先级反转。

#### 内存确定性

产品系统应明确任务栈、队列、消息缓冲区和堆的来源。关键路径优先使用静态分配或启动阶段一次性分配，避免在实时路径频繁调用动态分配。启用并检查：

- `configASSERT()`。
- `configCHECK_FOR_STACK_OVERFLOW`和`vApplicationStackOverflowHook()`。
- `vTaskGetInfo()`或`uxTaskGetSystemState()`。
- `xPortGetMinimumEverFreeHeapSize()`和`vPortGetHeapStats()`，具体取决于heap实现。
- 每个任务的`uxTaskGetStackHighWaterMark()`。

### 对FRDM-IMX95-PRO/M7要测什么

当前M7是独立实时执行单元，A55运行Linux，M33运行System Manager。第一版测试应把M7本地实时链路和A55/Linux辅助链路分开。Linux调度、USB、网络和文件系统不能直接当作M7的确定性实时测试结果。

#### 必测项目

1. **任务周期**：用M7硬件计时器或GPIO翻转测关键周期任务的实际周期、最大偏差和长期漂移。
2. **中断响应延迟**：用外部信号或片上定时器产生事件，在ISR入口立即翻转一个GPIO，用逻辑分析仪测事件到翻转的时间。
3. **端到端响应**：输入GPIO边沿 -> ISR -> FreeRTOS任务 -> 输出GPIO，测平均、最大、最小延迟和抖动。
4. **执行时间/WCET估计**：在任务入口和出口采集硬件计数器，分别测试空载、正常负载、最大输入、其他中断并发和总线访问竞争。
5. **deadline miss**：每次任务完成时比较绝对deadline，计数并打印或保存超时次数，不能只观察任务是否还在运行。
6. **调度压力**：增加不同优先级的周期任务、通信任务和低优先级后台任务，确认关键任务的最大响应时间仍达标。
7. **同步压力**：队列满/空、信号量竞争、互斥量竞争和优先级反转场景，测最大阻塞时间。
8. **中断压力**：多源中断同时到达，确认ISR耗时、嵌套和任务唤醒行为。
9. **资源稳定性**：长时间运行检查栈余量、堆余量、任务数量、队列积压、CPU利用率和错误计数。
10. **故障恢复**：故意制造输入异常、通信超时和任务不响应，验证错误检测、复位策略和日志是否符合产品要求。

#### i.MX95特有的注意事项

- M7使用TCM还是共享DDR会影响访问延迟、容量和确定性；测试报告必须记录链接脚本和内存区域。
- Cache、总线仲裁、共享内存和DMA会造成延迟变化。涉及DMA或A55/M7共享缓冲区时必须处理cache一致性和内存屏障，不能只凭普通变量读写判断通信正确。
- System Manager、LM和TRDC资源权限必须固定并记录。权限错误、LM复位和A55启动异常属于平台配置问题，不应混进FreeRTOS调度器性能结论。
- 调试日志会改变时序。COM18串口打印只能作为状态记录；实时测试应减少打印，用GPIO、片上计时器或内存缓冲区采样，测试结束后再导出数据。
- 当前USB+UUU是RAM临时启动，适合快速验证，不等于量产启动方案。持久化启动方式和镜像版本应在测试报告中单独记录。

### 推荐的实际测试台

#### 测试连接

继续使用已经验证的回环：

```text
J15-8  GPIO2_IO14输出 -> J15-10 GPIO2_IO15输入
逻辑分析仪CH0       -> 输入或外部触发信号
逻辑分析仪CH1       -> M7响应GPIO
逻辑分析仪GND       -> J15-39
```

第一版可以让GPIO14输出周期信号，GPIO15作为输入；更严格的响应延迟测试应加入可控外部边沿源，或者使用片上定时器触发中断并用另一路GPIO标记ISR入口和任务完成点。输入输出回环适合验证路径，但不能代替不同频率、边沿密度和异常电平测试。

#### 时间测量

优先使用M7可访问的硬件计时器或DWT cycle counter，并记录CPU主频。GPIO边沿由逻辑分析仪验证，软件时间戳用于关联任务和事件。不要用Windows串口接收时间、MobaXterm显示时间或`printf`间隔作为实时延迟。

#### FreeRTOS统计

在测试配置中按官方内核文档启用所需统计接口，例如运行时间统计和任务状态查询。统计项至少包括任务运行计数、运行时间占比、最小剩余栈、堆剩余量、队列高水位和deadline miss计数。统计本身应低频执行，避免让统计代码进入关键实时路径。

### 建议的验证顺序

1. 先保持当前GPIO权限和已验证串口工程不变，确认基准镜像每次都能运行。
2. 增加一个固定周期任务，使用`vTaskDelayUntil()`，不打印，只翻转测试GPIO，测周期和抖动。
3. 增加输入中断，测ISR响应和端到端响应。
4. 增加第二个不同优先级任务，测负载变化下的deadline和抖动。
5. 加入队列、信号量和互斥量测试，记录阻塞上界和优先级反转情况。
6. 开启栈、堆、断言和运行时统计检查，执行长时间压力测试。
7. 再加入A55通信、共享内存或RPMsg，单独测跨核通信延迟和cache一致性影响。
8. 最后验证掉电持久启动、看门狗、错误恢复和版本可追溯性。

### 产品级报告应包含的内容

- 需求编号、任务名称、周期、deadline、允许抖动和故障后果。
- 芯片时钟、编译器、优化选项、FreeRTOS版本、SDK版本和镜像哈希。
- M7内存布局、TCM/DDR使用情况、Cache设置、DMA和共享资源。
- 任务优先级、栈大小、队列长度、互斥量和中断配置。
- 空载、正常负载、峰值负载、并发中断和异常输入条件。
- 平均值、最小值、最大值、峰峰值、分位数、deadline miss次数和测试时长。
- 栈/堆最小余量、CPU利用率、看门狗状态、复位记录和错误计数。
- 测量工具、采样率、接线、原始CSV和分析脚本。
- 已验证结论、适用范围、未覆盖条件和后续风险。

### 当前结论和待办

当前已完成的是功能级第一阶段：M7 FreeRTOS能运行，串口收发和GPIO输入输出通过。实时性尚未验收，尤其还没有得到中断响应最大值、端到端响应最大值、WCET、deadline miss、栈/堆余量和压力条件下的抖动数据。

下一步先做一个不打印串口的固定周期GPIO测试任务，用硬件计时器和逻辑分析仪测实际周期；然后加入GPIO输入中断和响应标记。测试过程中继续保留COM18作为低频状态日志，但不能把串口输出间隔作为实时性证据。

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/RTOS/uC-OS-II.md|uC-OS-II]]
