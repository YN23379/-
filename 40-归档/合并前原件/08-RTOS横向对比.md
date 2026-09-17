---
type: 知识库
scope: RTOS
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# RTOS 横向对比（FreeRTOS / uC/OS / RT-Thread / Zephyr / 其它）

> 对比维度：定位、许可、内核大小、调度、同步、内存、配置方式、生态与典型场景。
> 数字类（优先级方向、内核大小）**以你手上的实际版本为准**，这里给的是通行约定。

## 1. 总览

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

## 2. 调度机制对比

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

## 3. 通信与同步对比

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

## 4. 内存管理对比

| | FreeRTOS | uC/OS-II | RT-Thread | Zephyr |
|---|---|---|---|---|
| 动态堆 | `heap_1~5`（可选实现） | `OSMemGet/Put`（**内存分区**，固定块） | 内存池 `rt_mp` + 堆 `rt_malloc` | `k_malloc`（堆）+ `k_mem_slab`（固定块） |
| 特点 | 通用分配；heap_4/5 合并空闲块 | 固定大小块、无碎片、确定性强 | 分区管理（小内存算法） | slab 固定块 + 堆 |
| 静态分配 | `xTaskCreateStatic` 等 | 任务栈用户提供 | 支持 | 编译期静态（Kconfig/DT） |

> uC/OS 的"内存分区"（固定块）是硬实时友好设计：无碎片、O(1)。FreeRTOS 的 heap_4 更灵活但有碎片风险。

## 5. 配置与构建对比

| | FreeRTOS | uC/OS | RT-Thread | Zephyr |
|---|---|---|---|---|
| 裁剪 | `FreeRTOSConfig.h` + `INCLUDE_xxx` | `os_cfg.h` | `rtconfig.h`（可由 Kconfig/menuconfig 生成） | **Kconfig（menuconfig）+ Devicetree** |
| 构建 | CMake/Make/各 IDE 工程接入 | 同 | SCons + Kconfig | **CMake + west**（模块化、跨平台） |
| 上手曲线 | 低 | 低 | 中 | **高**（概念多：DT、Kconfig、west、模块） |

> Zephyr 用 Devicetree 描述硬件（和 Linux 一致），配置在**编译期**完成，运行期几乎无动态配置；FreeRTOS 则把行为开关集中在 `FreeRTOSConfig.h`，最简单直接。

## 6. uC/OS-II 关键机制（作 FreeRTOS 的对照）

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

## 7. 其它值得知道的名字

| RTOS | 特点 |
|---|---|
| **VxWorks** | 商业硬实时旗舰，航天/国防/工业，工具链完善 |
| **ThreadX / Azure RTOS** | 微软，通过安全认证（医疗/汽车），组件生态 |
| **Zephyr** | Linux 基金会，SMP、多协议、Devicetree，现代构建 |
| **RT-Thread** | 国产，中间件全，图形化配置，社区活跃 |
| **SafeRTOS** | FreeRTOS 的**认证版**（IEC 61508 / ISO 26262 / DO-178） |
| **裸机 (super loop)** | 没 RTOS；简单任务 + 中断足够时反而更确定 |

## 8. 选型建议

| 场景 | 建议 |
|---|---|
| MCU 通用产品、要便宜/生态/CD 工具支持 | **FreeRTOS**（NXP/ST/ESP 等 SDK 默认） |
| 需要文件系统/网络/GUI 一站式、国产支持 | **RT-Thread** |
| 多协议 + 需要强构建系统 + SMP | **Zephyr** |
| 安全认证（航空/医疗/汽车） | uC/OS-III / SafeRTOS / ThreadX / VxWorks |
| 极简、只要调度 + 同步 | **FreeRTOS**（内核最小） |

## 9. 面试高频

- **FreeRTOS 和 uC/OS 优先级方向？** FreeRTOS 越大越高；uC/OS 越小越高。
- **两者就绪表实现差异？** uC/OS 位图 + `OSUnMapTbl` O(1)；FreeRTOS 就绪链表数组（可选位图 + CLZ）。
- **uC/OS 为什么每级只能一个任务？** 优先级即任务身份（TCB 表按优先级索引），不支持同优先级轮转。
- **FreeRTOS 任务通知在别的 RTOS 有吗？** 没有等价物（uC/OS/RT-Thread/Zephyr 没有这个机制）。
- **RT-Thread 相比 FreeRTOS 的特色？** 统一对象模型 + 设备驱动框架 + 丰富中间件（是"RTOS + IoT 平台"）。
- **Zephyr 相比 FreeRTOS 的特色？** Kconfig + Devicetree、编译期配置、SMP、强构建系统，学习曲线更陡。
