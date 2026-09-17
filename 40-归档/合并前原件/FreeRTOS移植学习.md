---
type: 知识库
scope: RTOS
doc_type: 教程
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# FreeRTOS 移植学习

## 当前目标

当前目标不是立即修改 FreeRTOS 内核，而是先在 FRDM-IMX95-PRO 的 Cortex-M7 上运行一个官方示例，打通工程编译、固件加载和串口输出流程。完成基本运行后，再根据现有工程区分通用内核代码、处理器移植代码和板级初始化代码。

## FreeRTOS 的基本组成

FreeRTOS 是一个实时操作系统内核，主要负责任务管理、任务调度、任务间通信、同步、软件定时器和内存管理。它不等于完整的 Linux，也不负责提供文件系统、网络协议栈和完整的设备模型。需要网络、文件系统或图形功能时，通常由芯片 SDK、BSP 或独立组件提供。

FreeRTOS 源码可以按三部分理解：

1. 通用内核代码，例如 `tasks.c`、`queue.c`、`list.c` 和 `timers.c`。
2. 移植层代码，通常位于 `portable` 目录，负责处理器寄存器、异常和上下文切换。
3. 工程配置和板级代码，例如 `FreeRTOSConfig.h`、启动文件、链接脚本、时钟、串口和 GPIO 初始化。

## 与 uC/OS-II 的对应关系

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

## 推荐的源码阅读顺序

先阅读一个最小示例，不要直接从整个内核开始。按照 `main()` 中的调用顺序跟踪：

1. `xTaskCreate()` 如何分配或准备任务控制块和任务栈。
2. `vTaskStartScheduler()` 如何创建空闲任务并启动第一个任务。
3. `vTaskDelay()` 如何把当前任务从就绪列表移到延时列表。
4. Tick 中断如何更新时间和唤醒到期任务。
5. `vTaskSwitchContext()` 如何选择下一个就绪任务。
6. PendSV 或对应异常处理函数如何保存和恢复寄存器。
7. `port.c` 和汇编文件如何实现第一次启动和上下文切换。

## 调度器要回答的几个问题

阅读调度器时，始终围绕以下问题：

- 当前有哪些任务。
- 每个任务当前是运行、就绪、阻塞还是挂起。
- 哪些任务位于就绪列表。
- 当前最高优先级的就绪任务是谁。
- 什么事件触发调度，是 Tick、中断、任务主动让出还是任务解除阻塞。
- 切换时当前任务的哪些寄存器被保存，下一任务的哪些寄存器被恢复。

理解这些问题后，再去看具体的链表、位图和临界区代码，源码会更容易对应到实际行为。

## 移植的实际含义

移植不是把所有 FreeRTOS 源码重新编写一遍，而是让通用内核适配目标处理器和工程环境。对于 M7，主要需要处理启动文件、异常向量、系统节拍、中断优先级、任务栈初始布局、上下文切换、链接脚本和内存分配。串口、I2C、GPIO 等驱动属于板级或 SDK 部分，不属于 FreeRTOS 调度器本身。

## FreeRTOS Kernel 与板级 SDK 的区别

FreeRTOS Kernel 仓库主要包含任务、队列、定时器等通用内核代码，以及不同 CPU 和编译器对应的移植层。它不包含一块复杂开发板正常运行所需的全部内容，例如 i.MX95 的启动流程、时钟配置、内存布局、引脚配置、串口驱动和多核固件加载方式。

NXP SDK 或项目 BSP 通常在 FreeRTOS Kernel 之外补充以下内容：

- 芯片启动文件和中断向量表
- M7 或 M33 的链接脚本
- 时钟、引脚和内存初始化
- UART、I2C、GPIO 等外设驱动
- 开发板配置和示例工程
- 编译、生成固件和调试所需的工程文件

因此，单独下载 FreeRTOS Kernel 可以用于阅读内核源码，但不能直接作为 FRDM-IMX95-PRO 的完整可烧写工程。当前应先使用 NXP 或部门提供的可运行工程。

## 计划

### 第一阶段：运行已有示例

1. 启动开发板预装的 Linux。
2. 查看 `/lib/firmware/` 中的 Cortex-M7 示例固件。
3. 根据 `AN14748` 选择并运行一个官方 M7 示例。
4. 通过 M7 串口确认程序已经运行。

### 第二阶段：完成编译和加载

1. 确认示例源码来自 MCUXpresso SDK、Application Code Hub 或 Linux BSP 配套源码。
2. 确认编译器、SDK 版本和目标板配置。
3. 不修改代码，先完整编译一次示例。
4. 对比生成的 ELF 和 BIN 文件，了解各文件用途。
5. 将固件传入 Linux，再由 Linux 加载到 M7，或者按项目规定使用调试器下载。

### 第三阶段：阅读 FreeRTOS 源码

先从应用调用关系开始阅读：

1. `main()` 中的硬件初始化和任务创建。
2. `xTaskCreate()` 如何建立任务控制块和任务栈。
3. `vTaskStartScheduler()` 如何启动第一个任务。
4. `tasks.c` 中任务状态、就绪列表和调度选择。
5. `portable` 目录中 Cortex-M7 对应的 `port.c` 和汇编代码。
6. SysTick、PendSV 和 SVC 在调度过程中的作用。
7. 链接脚本、向量表和启动文件如何与 FreeRTOS 移植层配合。

## 移植完成的基本判断

FreeRTOS 能够在目标核心上启动，至少两个不同优先级的任务可以按照预期运行，系统节拍正常，延时和任务切换正常，串口能够持续输出，并且中断、信号量等基本功能可以正常使用。进一步还需要检查任务栈、内存占用、长时间运行稳定性和异常处理。

## 当前待确认事项

- FreeRTOS 最终运行在 M7 还是 M33。
- 部门是否已有 FRDM-IMX95-PRO 配套工程。
- 项目规定的 SDK、BSP 和编译器版本。
- 固件由 Linux remoteproc 加载，还是通过 JTAG 调试器下载。
- 最终验收使用哪些外设和测试场景。

## 板载 Linux 中已经存在的 M7 示例

登录板载 Linux 后，在 `/lib/firmware` 中发现了当前 19x19 平台的 M7 固件，例如：

- `imx95-19x19-evk_m7_TCM_hello_world.bin`
- `imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.bin`
- `imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.bin`
- `imx95-19x19-evk_m7_TCM_flexcan_linux.bin`

这些文件说明当前系统已经带有可以直接用于验证的 M7 示例，其中带有 `rtos` 的文件名与 FreeRTOS 示例有关。它们比立即从空目录创建 FreeRTOS 工程更适合作为第一个学习对象。下一步先通过 Linux 的 remoteproc 接口查看 M7 状态，再运行最简单的 `hello_world`，之后再运行带有 RPMsg 的 RTOS 示例。

## 第一次运行示例的原则

先查看，不修改：

```bash
ls -l /sys/class/remoteproc
for r in /sys/class/remoteproc/remote*; do echo $r; cat $r/name 2>/dev/null; cat $r/state 2>/dev/null; cat $r/firmware 2>/dev/null; done
```

确认 remoteproc 编号、名称和当前状态后，再根据官方应用笔记选择固件。不能直接把 `echo start` 写入未知的 remoteproc，也不能把不同平台的固件名称直接替换使用。

## 当前 M7 启动阻塞

`remoteproc1` 已确认是 Cortex-M7，Linux 可以读取 `hello_world.elf`，但启动时报告：

```text
lmm(1) not under Linux Control
Boot failed: -13
```

这不是 FreeRTOS 内核错误，也不是 ELF 编译错误，而是启动镜像中的多核资源划分不允许 Linux 控制 M7。FreeRTOS 是否能够运行，需要先解决 M7 的启动和资源所有权。

## 接下来的工程路线

1. 从 MCUXpresso SDK Builder 获取 i.MX95 19x19 平台的 SDK，官方应用笔记示例使用 `IMX95LPD5EVK-19`、SDK 25.12.00 和 ARM GCC。
2. 在 SDK 中先编译 M7 `hello_world`，再编译带 `rtos` 的 RPMsg 示例。
3. 获取与当前 FRDM-IMX95-PRO Linux BSP 版本匹配的 `imx-mkimage` 和启动固件。
4. 生成允许 A55 控制 M7 的 RPMsg 启动镜像，或者将 M7 固件直接打包进 `flash.bin`。
5. 优先将测试镜像写入 MicroSD，保留当前能够正常启动的 eMMC。
6. 从 MicroSD 启动后再次验证 M7，再进入 FreeRTOS 示例和源码学习。

这里 SDK 负责提供 M7 工程、启动代码、链接脚本、驱动和 FreeRTOS 组件，Linux BSP 与 `imx-mkimage` 负责平台启动镜像和 System Manager 配置，两者作用不同，缺少任何一部分都不能完成当前多核平台上的完整启动。

## 如何判断板子有没有 FreeRTOS

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

## SDK Builder 板卡选择记录

在 SDK Builder 中搜索 `IMX95`，结果包含：

- `FRDM-IMX95 (MIMX9596xxxxN)`
- `IMX95LP4XEVK-15 (MIMX9596xxxxN)`
- `IMX95LPD5EVK-19 (MIMX9596xxxxN)`
- `IMX95VERDINEVK (MIMX9596xxxxN)`

当前板卡是 `FRDM-IMX95-PRO`，不是列表中的普通 `FRDM-IMX95`。当前 Pro 板使用 19x19 封装和 LPDDR5，板载 Linux 中的 M7 固件也以 `imx95-19x19-evk` 命名。`AN14748` 的 SDK 获取步骤使用 `IMX95LPD5EVK-19`，因此在 Pro 专用 SDK 尚未出现在 Builder 时，先选择 `IMX95LPD5EVK-19` 用于学习和编译 M7 示例。板级引脚和外设差异仍需结合 FRDM-IMX95-PRO 工程或 BSP 处理。

已下载的 `SDK_25_09_00_MCXW23.zip` 属于 MCXW23 无线 MCU。压缩包中出现 `mcuxsdk-frdmmcxw23.pdf`、`mcxw23evk` 和 `wireless/mcxw23` 等目录，可以确认它不是 i.MX95 SDK，不能用于当前板卡。

## 当前FreeRTOS上板目标

已经使用IAR 9.70.4编译SDK 26.06.00中的Cortex-M7示例，编译结果为0错误、0警告。板载Linux根文件系统还自带`imx95-19x19-evk_m7_TCM_hello_world.bin`和多组名称包含`rtos`的RPMsg Lite示例。因此当前工作不是从空工程移植FreeRTOS内核，而是先解决M7启动和Pro板串口输出。

第一阶段的最小完成标准为：M7能够执行程序，FreeRTOS调度器能够启动任务，串口能够观察到任务输出。之后再增加两个任务、延时切换、队列或信号量和GPIO翻转，用于验证系统节拍、任务调度和基本外设。最后才进入`tasks.c`、就绪列表、SysTick、PendSV和移植层源码分析。

## 2026-09-14实机进度

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

## 第二阶段方向：从功能验证进入实时性验证

第一阶段基本完成，但“任务能周期打印”和“GPIO能翻转”只能证明功能链路可用，不能证明产品级实时性。下一阶段必须定义每个关键任务的周期、响应时间、deadline、允许抖动和超时后果，再使用M7硬件计时器、GPIO和逻辑分析仪测最大值，而不是使用串口文本时间判断。

重点指标包括：中断响应延迟、输入到输出的端到端延迟、任务实际执行时间、最坏执行时间（WCET）估计、周期抖动、deadline miss、CPU利用率、任务最大阻塞时间、栈最小余量和堆最小余量。还要在高负载、多中断、队列竞争、互斥量竞争、DMA/共享内存和长时间运行条件下重复测量。

对当前i.MX95 M7工程，先做本地实时链路，再测A55/Linux或RPMsg跨核链路。TCM/DDR位置、Cache、总线竞争、System Manager/TRDC权限和USB RAM启动方式都要写入测试条件。串口只用于低频状态日志，不能作为高精度实时测量手段。
