---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 原理
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# i.MX95 多核与程序启动

## Arm、Cortex 和 i.MX95 的关系

Arm 既指一种处理器指令集架构，也指设计处理器核心的公司。Arm 公司通常提供 CPU 核心设计，芯片厂商获得授权后，将这些核心与内存控制器、UART、I2C、网口和电源管理等模块集成到一颗 SoC 中。

`Cortex` 是 Arm 的处理器核心系列名称。`Cortex-A55` 和 `Cortex-M7` 是 Arm 设计的 CPU 核心型号，`i.MX95` 则是 NXP 设计的完整 SoC。NXP 在 i.MX95 中集成了多个 Cortex 核心以及 NPU、存储控制器和各种外设。因此，Cortex-A55 不是一颗独立的开发板芯片，而是 i.MX95 内部的 CPU 核心。

## Cortex-A、Cortex-R 和 Cortex-M

Cortex 后面的字母表示核心面向的主要应用方向。

| 系列 | 英文方向 | 主要特点 | 常见软件 |
|---|---|---|---|
| Cortex-A | Application | 运算能力强，支持 MMU、虚拟内存和复杂操作系统 | Linux、Android、QNX |
| Cortex-R | Real-time | 强调高性能实时控制、低延迟和功能安全 | 汽车控制、存储控制、实时系统 |
| Cortex-M | Microcontroller | 面积和功耗较低，中断响应快，适合微控制器和实时任务 | 裸机、FreeRTOS、Zephyr |

这里的分类表示设计重点，不是绝对限制。Cortex-A 也能处理实时任务，但普通 Linux 调度和复杂缓存会增加时延的不确定性。Cortex-M 的总运算能力较低，但中断路径简单，配合 TCM 和 RTOS 更容易获得稳定的响应时间。

## 型号数字表示什么

`A55`、`M7` 和 `M33` 中的数字是 Arm 定义的核心型号，用于区分不同代际和设计等级。数字不是主频、核心数量或位宽，不能简单认为数字越大性能就按比例越高，也不能跨 A、R、M 系列直接比较数字。

判断性能和用途需要同时查看：

- 使用的 Arm 架构版本
- 32 位或 64 位指令集
- 流水线和每周期执行能力
- 缓存和 TCM 配置
- MMU 或 MPU
- 主频和核心数量
- 中断延迟和实时性要求
- 芯片厂商在 SoC 中的实际配置

## i.MX95 中 A55、M7 和 M33 的区别

| 项目 | Cortex-A55 | Cortex-M7 | Cortex-M33 |
|---|---|---|---|
| 主要用途 | 应用处理和 Linux | 高性能实时控制 | 安全、低功耗和系统管理类任务 |
| 架构 | Armv8-A 系列 | Armv7E-M | Armv8-M |
| 位宽 | 支持 64 位 AArch64 | 32 位 Thumb 指令集 | 32 位 Thumb 指令集 |
| 当前板上数量 | 6 个 | 1 个 | 1 个 |
| 当前已知频率 | 启动日志显示 1.8 GHz | 官方资料标明最高 800 MHz | 以芯片资料和实际时钟配置为准 |
| 内存管理 | MMU | MPU | MPU |
| 虚拟内存 | 支持 | 不提供完整虚拟内存 | 不提供完整虚拟内存 |
| 操作系统 | 适合 Linux 等复杂系统 | 适合裸机或 FreeRTOS | 适合裸机或 RTOS |
| 实时性 | 吞吐量高，但时延较复杂 | 中断快，可使用 TCM，实时性较好 | 强调低功耗、安全和可控响应 |
| 安全特性 | 支持异常级和 TrustZone-A | 以高性能实时处理为主 | 支持 TrustZone-M |

### MMU、MPU 和 TCM

MMU 是 Memory Management Unit，即内存管理单元。Linux 使用 MMU 建立虚拟地址空间、隔离进程并管理页表。没有 MMU，通常不能按常规方式运行完整 Linux。

MPU 是 Memory Protection Unit，即内存保护单元。它可以为若干内存区域设置访问权限，但不提供 Linux 所需的完整虚拟地址转换。FreeRTOS 不依赖 MMU，因此适合运行在 M7 和 M33 上。

TCM 是 Tightly Coupled Memory，即紧耦合内存。它直接连接处理器核心，访问延迟低且较稳定，不经过普通缓存和外部 DDR 的复杂路径。M7 固件名称中的 `TCM` 表示该固件按照 M7 的 TCM 地址布局构建，适合对实时性要求较高的代码和数据。

## 性能应该怎样比较

A55 的优势是整体计算能力、地址空间、内存容量和复杂软件支持。当前板上有 6 个 A55，主频达到 1.8 GHz，并能使用 16 GB LPDDR5，适合运行 Linux、网络服务和大型应用。

M7 的主频和总吞吐量低于 A55，但它的中断处理路径更直接，可以使用 TCM，运行的软件层次更少，因此响应时间更容易预测。实时控制关注的不只是单位时间完成多少计算，还关注事件到来后能否在规定时间内稳定响应。

M33 通常比 M7 更偏向低功耗、安全隔离和系统管理。它支持 Armv8-M TrustZone，可以把安全代码和普通代码隔离。具体由哪个核心承担系统管理或实时任务，需要结合 i.MX95 的启动固件和项目方案，不能仅根据核心名称判断。

因此，这块板采用异构多核结构：A55 负责 Linux 和复杂应用，M7 负责高性能实时任务，M33 负责安全或系统管理相关任务，各核心不是简单互相替代的关系。

## i.MX95 的处理器核心

FRDM-IMX95-PRO 上的 i.MX95 包含 6 个 Cortex-A55、1 个 Cortex-M7 和 1 个 Cortex-M33。这些核心位于同一颗 SoC 中，但用途和运行环境不同。

| 核心 | 常见用途 | 当前需要关注的内容 |
|---|---|---|
| Cortex-A55 | 运行 Linux 和复杂应用 | U-Boot、Linux、文件系统和 M7 固件管理 |
| Cortex-M7 | 高性能实时控制 | FreeRTOS 示例、实时任务和外设控制 |
| Cortex-M33 | 安全、低功耗和系统管理 | 启动管理及项目是否使用该核心 |

## 为什么不能把它当成普通 STM32 直接烧录

普通 MCU 工程通常由调试器直接把一个程序写入片上 Flash，复位后 CPU 从固定地址运行。i.MX95 是多核应用处理器，板上还有 eMMC、SPI NOR 和 LPDDR5，启动过程会涉及 Boot ROM、启动设备、系统固件、U-Boot、Linux 以及 M 核固件。M7 程序可能不是上电后独立直接运行，而是先由 A55 启动 Linux，再由 Linux 将 M7 固件加载到指定内存并启动 M7。

因此需要先回答以下问题，才能决定下载方式：

- 程序运行在哪个核心。
- 固件存放在 eMMC、SD 卡、SPI NOR 还是 Linux 文件系统。
- 哪个核心负责启动 M7 或 M33。
- M7 使用哪一段 SRAM 或 TCM。
- 固件由 Linux 加载还是由 JTAG 调试器下载。

## 启动与下载的区别

启动是处理器上电后从启动设备读取并执行程序的过程。下载或烧录是将镜像写入 eMMC、SD 卡或 SPI NOR 等存储设备。调试则是通过 JTAG 或其他调试接口控制程序运行、设置断点和查看寄存器。

J22 是 USB 转串口接口，只负责查看日志和进行串口交互，不能代替 JTAG 下载器。J7 是 USB 数据接口，在串行下载模式下可以配合 NXP UUU 工具传输和烧写 Linux 镜像。Linux 启动后也可能通过 remoteproc 框架加载 M7 固件，这种方式不需要每次将 M7 程序单独烧入 Flash。

## remoteproc 基本概念

remoteproc 是 Linux 用于管理远端处理器的框架。这里的远端处理器可以是同一颗 SoC 内的 Cortex-M7。Linux 负责读取固件文件，将固件放入约定的内存，配置相关资源并启动 M7。M7 启动后可以独立运行裸机程序或 FreeRTOS，必要时通过 RPMsg 等机制与 Linux 通信。

当前只把 remoteproc 作为可能的运行路径，具体命令和固件名称需要根据 `AN14748`、板载 Linux 版本和部门工程进一步确认，不能直接套用其他 i.MX 开发板的命令。

## 第一次上电看到的 SM 输出

在第一次上电时，COM19 输出了 DDR OEI 初始化信息、`Hello from SM` 和 `SM Debug Monitor`。这说明启动早期的系统管理固件已经运行，并且调试串口已经能够传输可读信息。此时还不能认为 A55 上的 Linux 或 M7 上的 FreeRTOS 已经启动，只能说明平台的早期启动阶段已经有输出。

COM17 输出大量不可读字符时，不能马上认为板子损坏。需要先区分两种情况：一是串口波特率不正确，二是该通道本来就输出二进制协议或内存数据。判断方法是复位后观察输出是否具有固定格式，逐个尝试资料中规定的波特率和少数常见波特率，并结合其他串口是否出现 U-Boot 或 Linux 标识。COM16 和 COM18 无输出也需要结合启动阶段判断，不能只根据串口是否有文字下结论。

## 当前启动链路的实际结果

COM17 的启动日志表明当前启动链路为：

```text
上电
-> 系统管理固件和 DDR 初始化
-> Boot ROM 选择 MMC1
-> 从 eMMC 读取 U-Boot SPL
-> BL31 和 U-Boot 运行
-> U-Boot 加载 Linux 内核和设备树
-> Linux 启动 6 个 Cortex-A55
-> systemd 启动
-> A55 串口登录提示符
```

`Trying to boot from MMC1` 和 `root=/dev/mmcblk0p2` 说明系统使用的是板载 eMMC，而不是 MicroSD。`Model: NXP FRDM-IMX95-PRO board` 说明 U-Boot 识别到当前开发板型号。`smp: Brought up 1 node, 6 CPUs` 说明 Linux 已经启动了 6 个 A55 核心。

这次启动中，J22 的串口连续输出了系统管理固件、U-Boot、Linux 内核和 systemd 的信息。当前还不能据此判断 M7 或 M33 已经运行，因为 M 核通常需要单独启动，或者由 Linux 的 remoteproc 加载。

## Linux 登录后的实际信息

登录 A55 上的 Linux 后，`uname -a` 显示内核为 Linux 6.18.2，系统架构为 `aarch64`。`/lib/firmware` 中已经存在多组 `imx95-19x19-evk_m7_TCM_*` 文件。虽然文件名包含 `evk`，但目标尺寸为 19x19，与当前 FRDM-IMX95-PRO 使用的 i.MX95 19x19 处理器平台相关，是否可以直接运行仍应通过当前系统的 remoteproc 配置和官方应用笔记确认。

这些固件文件让启动关系变得具体：A55 先启动 Linux，Linux 文件系统中保存 M7 固件，之后 Linux 可以通过 remoteproc 将固件装载到 M7 使用的内存并启动 M7。带有 `rpmsg_lite` 的示例还会在 A55 和 M7 之间建立消息通信。这个过程与普通单片机通过下载器把一个程序写入 Flash 后直接复位运行不同。

## remoteproc 实际检查结果

Linux 中存在两个 remoteproc 设备：

```text
remoteproc0
name: neutron-rproc
state: offline
firmware: rproc-neutron-rproc-fw

remoteproc1
name: imx-rproc
state: offline
firmware: rproc-imx-rproc-fw
```

`remoteproc0` 名称中包含 Neutron，对应 i.MX95 的 Neutron NPU。`remoteproc1` 是 i.MX remote processor，结合系统中的 M7 固件判断，它大概率对应 Cortex-M7。启动固件前还需要读取它的设备树路径或 compatible 属性进行最终确认。两个设备目前都是 `offline`，表示对应远端处理器没有通过 Linux remoteproc 运行固件。

读取设备路径后，`remoteproc1` 指向 `/sys/devices/platform/imx95-cm7`，因此已经确认它对应 Cortex-M7。尝试启动 M7 时，内核报告 `lmm(1) not under Linux Control`。

LMM 是 Logical Machine Manager，即逻辑机管理。i.MX95 的 System Manager 固件运行在 Cortex-M33 上，它可以把 A55、M7 和外设划分给不同的 Logical Machine。M7 主要存在三种归属方式：

1. M7 属于独立 Logical Machine，Linux 无权控制。
2. M7 属于独立 Logical Machine，但 Linux 可以通过 LMM 协议控制。
3. M7 与 A55 位于同一个 Logical Machine，Linux通过 CPU 协议控制 M7。

当前启动镜像属于第一种情况。Linux 可以发现 M7 的 remoteproc 设备，也可以找到 ELF 文件，但 System Manager 不允许 Linux启动 M7。要改变这种关系，需要更换启动镜像中的 System Manager 配置，而不是修改 Linux 文件权限。

## i.MX95的两种M7启动接口

当前板载Linux和U-Boot中的remoteproc都受System Manager的LMM权限限制。Linux启动M7返回`-13`，U-Boot执行`rproc init 0`后也提示只能检测M7运行状态。这说明切换到U-Boot并不会自动获得remoteproc控制权。

板载U-Boot还提供`prepaux`和`bootaux`。`prepaux 1`用于请求底层固件准备编号1的M7，`bootaux 0 1`用于让M7从其核心地址空间的`0x0`启动。M7的ITCM在M7视角从`0x0`开始，在A55视角映射到`0x203c0000`。因此裸二进制需要先由A55加载到DDR，再复制到`0x203c0000`，最后让M7从`0x0`取向量表并执行。

`bootaux`使用裸BIN时不解析ELF。BIN开头是Cortex-M向量表，前两个32位数据分别为初始栈指针和复位入口。ELF包含程序段地址等结构化信息，适合Linux或U-Boot remoteproc加载。两种格式不能在不同加载命令中随意替换。

## TCM程序装载失败说明

M7看到的ITCM地址从`0x00000000`开始，A55访问同一块物理存储时需要使用SoC提供的映射地址。SDK的i.MX95内存转换定义和19x19 EVK示例使用`0x203c0000`作为M7 ITCM在系统地址空间中的映射地址。因此，TCM版BIN先被读入DDR后，还需要复制到这个映射地址，最后在M7本地`0x00000000`放置向量表和代码。

当前FRDM-IMX95-PRO执行这次复制时触发了U-Boot同步异常并自动复位，说明A55对M7 TCM的访问受到当前System Manager和硬件访问控制配置限制。`prepaux 1`只表示准备核心的请求被接受，不能推出A55已经取得M7所属逻辑机器及全部内存的控制权。

DDR版M7程序与TCM版程序的区别不只是存放位置。链接脚本会决定向量表、代码、数据和入口地址。TCM版程序虽然可以暂存到DDR，但不能直接从该DDR地址启动，因为向量表中的复位入口仍是TCM地址。若绕过TCM复制，需要重新构建链接到DDR地址的程序，再把同一个DDR地址交给`bootaux`。

## 2026-09-14 SW4、USB下载模式与Linux是否运行

SW4不是“选择Linux或FreeRTOS”的开关，它只在芯片复位时向Boot ROM提供启动模式电平。Boot ROM根据这些电平决定先到哪个启动设备寻找可认证、可装载的启动容器。后续究竟运行A55、M7、M33、U-Boot还是Linux，由该启动源中的镜像内容和System Manager配置决定。

依据`UM12527`第2.3节，常用模式为：

| 官方模式 | SW4[1:4]实际设置 | Boot ROM首先使用的启动源 |
|---|---|---|
| `x001` | `ON、OFF、OFF、ON`，当前使用 | J7 USB Serial Downloader |
| `x010` | `ON、OFF、ON、OFF` | 板载eMMC |
| `x011` | `ON、OFF、ON、ON` | microSD |
| `x100` | 第一位任意，其余为`100` | FlexSPI NOR |

这里的`x`表示该位对该启动模式无关。当前`1001`满足`x001`；以前使用的`1010`满足`x010`。

在`x001`模式下，Boot ROM不会自动读取eMMC中的原厂Linux。它在J7枚举为MX95 SDPS设备，等待电脑上的UUU发送启动容器。本次UUU只进行`SDPS: boot`，容器被装入易失性内存并启动，没有写eMMC。容器中如果包含A55 SPL，A55应至少执行SPL并在COM17输出；只有继续具备U-Boot、Linux内核、设备树和根文件系统等完整链路时，Linux才会运行。当前COM17静默且LM2被反复复位，因此原eMMC Linux没有运行，USB容器中的A55启动链也没有正常推进。

在`x010`模式下，Boot ROM选择eMMC。当前eMMC恰好保存原厂A55启动镜像和Linux系统，所以外在表现是SPL、U-Boot、Linux依次启动。准确说法是“SW4选择eMMC，eMMC中的镜像随后启动Linux”，不是“SW4直接选择Linux”。

## FCCU、WDOG3与LM2反复复位

### 名词与归属

- `LM2`：Pro官方SM配置中的Logical Machine 2，名称为`AP`，对应A55应用处理器域。
- `WDOG3`：分配给LM2/AP的硬件看门狗。软件必须按规定周期维护它；超时会产生看门狗复位请求。
- `FCCU`：Fault Collection and Control Unit，故障收集与控制单元。它接收SoC安全故障源，并将故障交给配置的处理逻辑。
- `System Manager`：运行在M33上的平台管理固件，负责LM生命周期、资源和故障反应。COM19是它的日志通道。

官方i.MX95 SM源码明确将故障号19定义为：

```c
#define DEV_SM_FAULT_WDOG3 19U  /* WDOG3 timeout (Watchdog reset request) */
```

Pro配置明确包含：

```text
LM2 name="AP", ...
PERLPI_WDOG3 ALL
WDOG3 OWNER
FAULT_WDOG3 OWNER, reaction=lm_reset
```

因此`Reset LM 2, reason=fccu, errId=19`不是模糊告警，其含义是：FCCU报告WDOG3超时，故障属于LM2，配置要求执行LM级复位。

### 状态机和调用链

这套复位逻辑已经存在于M33 System Manager中，不需要移植到M7。源码调用关系为：

```text
WDOG3超时
-> FCCU产生19号故障
-> SM故障处理器构造reason=FCCU、errId=19的reset record
-> DEV_SM_FaultComplete()
-> LMM_FaultComplete()
-> LMM_FaultReactionGet()读取FAULT_WDOG3配置
-> 得到LM2和reaction=lm_reset
-> LMM_SystemLmReset(LM2)
-> LMM_DoShutdown(LM2)
-> LMM_DoBoot(LM2)
```

LM2重新启动后，如果A55仍没有正常运行到维护WDOG3的位置，看门狗会再次超时，状态机再次关闭并启动LM2。这就是COM19一直输出同一行的原因：它是多个连续的“启动、超时、复位”周期，不是串口重复发送一条旧日志。

### COM17是否应有输出

需要看USB容器内容。M7-only容器没有A55镜像时，COM17静默是正常的；当前`flash-m7-gpio.bin`的镜像解析结果包含A55 SPL及后续A55 APP container，所以正常情况下COM17至少应看到SPL输出。现在COM17没有输出，同时COM19反复报告LM2的WDOG3超时，可以判断A55启动链没有正常推进，但仅凭这两项还不能确定停在哪一条指令。

### 当前根因边界和解决原则

已经证实的是WDOG3超时及SM的LM2复位反应。尚未证实的上游根因是：把整个GPIO2从LM2/A55转给LM1/M7后，A55 SPL是否访问了GPIO2并因此阻塞。该推断合理，但目前没有A55异常点或TRDC故障日志，不能当成最终结论。新编译SM与旧可运行SM之间也可能存在工具链或版本差异。

不应通过关闭WDOG3、屏蔽FCCU或删除`lm_reset`处理来“解决”，因为这只会隐藏A55失去响应。正确排查是每次只改变一个变量：

1. 同版本SM加原始Pro配置，加已验证M7程序，验证A55是否正常。
2. GPIO权限版SM加不访问GPIO的旧M7程序，判断故障是否仍出现。
3. 如果故障只随GPIO2转移出现，再确认A55 SPL对GPIO2的依赖。
4. 共存工程中只允许一个LM直接拥有GPIO2；另一侧通过RPMsg请求GPIO服务，或改用A55启动阶段不依赖的GPIO资源。
5. 只做M7 GPIO验证时，可研究不启动LM2的官方M7-only构建目标；它不能替代Linux与M7共存方案。

## 2026-09-15 WDOG3根因确认与修复

严格对照已经完成，因此前一节的待确认推断现在可以更新为已验证结论。

### 对照结果

保持M7 GPIO程序、ELE、DDR OEI、A55 SPL和容器布局不变，只把System Manager配置恢复为官方`mx95frdm-pro.cfg`。运行后COM17正常输出A55 SPL，COM19不再报告WDOG3，但M7无法访问GPIO2。由此排除SM工具链和容器布局是WDOG3循环的直接原因，确认故障随GPIO2所有权从A55移走而出现。

### 根因

错误配置把`PERLPI_GPIO2 ALL`和`GPIO2 OWNER`从LM2/A55全部移到LM1/M7。A55早期启动链仍依赖GPIO2资源，失去该资源后不能正常推进和维护WDOG3。WDOG3超时被FCCU记录为故障19，System Manager按照`reaction=lm_reset`反复复位LM2。

### 正确修复

官方SM文档明确区分两种权限：

- SCMI/API权限：决定逻辑机是否能通过System Manager管理外设资源。
- TRDC/DID权限：决定总线主设备能否直接读写外设寄存器。

FreeRTOS GPIO驱动直接操作GPIO2寄存器，因此SM/TRDC层必须允许M7访问，同时不能删除A55启动所需的SCMI API和访问权限。最终实测配置是：M7使用`GPIO2 OWNER`，A55保留`PERLPI_GPIO2 ALL`和`GPIO2 ACCESS`。

但SM/TRDC修正不是SD模式GPIO问题的最终修复。SD启动进入BL31后，BL31还会把GPIO2的`PCNS/PCNP`写成`FFFFFFFF`。最终由M7程序只清除bit14/15，将自己的两根引脚恢复为安全特权属性。

## SM权限配置如何进入最终启动镜像

### 官方文档位置

本地NXP `imx-sm`源码中的配置文档为：

```text
F:\project\Learning\RTOS\tools\imx-sm\sm\doc\config.md
```

关键依据位于第841至852行。官方说明访问控制分为两类：通过Agent MU进行的API访问，以及按DID配置的TRDC访问；每个LM使用唯一DID，TRDC为每个DID设置独立权限。第877行以后说明TRDC权限值由安全/非安全、特权/用户四组读写执行位组成。

### 修改的源配置

NXP原始Pro配置：

```text
F:\project\Learning\RTOS\tools\imx-sm\configs\other\mx95frdm-pro.cfg
```

GPIO测试配置：

```text
F:\project\Learning\RTOS\tools\imx-sm\configs\other\mx95frdm-pro-m7gpio.cfg
```

最终实测配置相对原始Pro配置的资源关系为：

```text
LM1/M7资源：GPIO2 OWNER
LM2/A55资源：GPIO2 ACCESS
LM2/A55 API：PERLPI_GPIO2 ALL
```

A55侧保留`PERLPI_GPIO2 ALL`，是避免早期启动再次因外设API不可用而进入WDOG3/FCCU复位循环。`GPIO2 OWNER/ACCESS`和`PERLPI_GPIO2`分别属于资源/TRDC与API控制，仍要与RGPIO内部的`PCNS/PCNP`区分。

NXP匹配版本TF-A源码`tools/imx-atf-source/plat/imx/imx9/imx95/imx95_bl31_setup.c`已经证明，`bl31_plat_arch_setup()`会将GPIO2的`PCNS/PCNP`写成全1。最终SD实测中，M7恢复bit14/15后读到`PCNS=PCNP=FFFF3FFF`，GPIO输出波形与输入回环通过。

### 从cfg到M33固件

构建脚本执行：

```text
make config=mx95frdm-pro-m7gpio cfg
make config=mx95frdm-pro-m7gpio all
```

第一条命令调用官方`configs/configtool.pl`解析cfg，并生成`configs/mx95frdm-pro-m7gpio/`中的配置头文件，主要包括：

- `config_trdc.h`：DID到外设/内存块的TRDC硬件权限寄存器配置。
- `config_scmi.h`：各Agent通过SCMI调用资源管理API的权限。
- `config_lmm.h`：LM启动顺序、资源生命周期和故障反应。
- 其他board、device、mailbox和RPC配置头文件。

第二条命令把这些生成头文件与NXP System Manager源码一起编译、链接，产生：

```text
m33_image.elf
m33_image.bin
```

cfg文本本身不会被Boot ROM读取，也不会原样出现在最终镜像中。权限最终表现为`m33_image.bin`内的初始化表和SM逻辑，M33上的System Manager启动后用它配置TRDC和LM。本次最终M33文件导出为：

```text
F:\project\Learning\RTOS\build\pro-gpio\m33_image.bin
```

### M7程序来源

M7 FreeRTOS程序由IAR编译以下SDK工程：

```text
F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19\boards\imx95lpd5evk19\freertos_examples\freertos_hello\cm7\iar
```

工程包含FreeRTOS内核、Cortex-M7移植层、启动文件、链接配置、NXP驱动以及修改后的LPUART7和GPIO任务。IAR生成的M7裸二进制为`freertos_hello.bin`，构建脚本将其导出为：

```text
F:\project\Learning\RTOS\build\pro-gpio\freertos_gpio.bin
```

### imx-mkimage打包过程

实际脚本为：

```text
F:\project\Learning\RTOS\tools\build-m7-gpio.sh
```

流程为：

1. 用自定义cfg生成配置头文件并编译新的`m33_image.bin`。
2. 从已验证Pro启动镜像提取ELE、V2X、DDR OEI、Quick Boot数据、A55 SPL、BL31、U-Boot和TEE组件。
3. 使用`mkimage_imx8`先把BL31、U-Boot和TEE组成A55 APP container。
4. 使用`mkimage_imx8`生成ROM启动容器，加入DDR OEI、M33 System Manager、M7 FreeRTOS程序和A55 SPL。
5. 将A55 APP container按1 KiB边界追加到ROM容器后面。
6. 解析镜像并导出`flash-m7-gpio.bin`和`flash-m7-gpio.parse.txt`。

关键打包参数为：

```text
-m33 m33_image.bin 0 0x1FFC0000
-m7  m7_image.bin  0 0x0 0x303C0000
-ap  u-boot-spl.bin a55 0x20480000
```

### 最终flash-m7-gpio.bin的组成

解析报告：

```text
F:\project\Learning\RTOS\build\pro-gpio\flash-m7-gpio.parse.txt
```

最终文件包含三个ROM container和一个APP container：

| 部分 | 用途 | 来源 |
|---|---|---|
| ELE固件 | 安全启动、容器认证和芯片生命周期服务 | NXP Pro/BSP原始组件 |
| Primary/Secondary V2X固件 | V2X安全子系统启动组件 | NXP Pro原始组件 |
| DDR Quick Boot数据和DDR OEI | 初始化、训练LPDDR5 | NXP Pro原始组件 |
| M33 `m33_image.bin` | System Manager、LM、SCMI和TRDC配置 | NXP源码加本次自定义cfg重新编译 |
| M7 `freertos_gpio.bin` | FreeRTOS、UART和GPIO应用 | 本次修改的SDK工程由IAR编译 |
| A55 SPL | A55早期启动，之后进入SDPV或加载后续系统 | NXP Pro原始组件 |
| BL31 | ARM Trusted Firmware EL3运行时 | NXP Pro原始组件 |
| U-Boot镜像 | A55主Bootloader | NXP Pro原始组件 |
| TEE | OP-TEE安全执行环境 | NXP Pro原始组件 |
| Container header、偏移和SHA384摘要 | 描述每个映像的类型、核心、加载地址和完整性 | `imx-mkimage`根据以上输入生成 |

其中本次项目直接修改或生成的是M7应用源码及其BIN、SM权限cfg及其M33 BIN、集成构建脚本和最终组合镜像。ELE、V2X、DDR、SPL、BL31、U-Boot和TEE没有重新开发，均复用匹配FRDM-IMX95-PRO的NXP组件。
