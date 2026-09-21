---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 原理
status: 待验证
evidence: 实机验证
tags: [启动, 多核与异构, 安全与隔离]
updated: 2026-09-17
---

# i.MX95 多核与程序启动

## Arm、Cortex 和 i.MX95 的关系

Arm 既指一种处理器指令集架构，也指设计处理器核心的公司。Arm 公司通常提供 CPU 核心设计，芯片厂商获得授权后，将这些核心与内存控制器、UART、I2C、网口和电源管理等模块集成到一颗 SoC 中。

`Cortex` 是 Arm 的处理器核心系列名称。`Cortex-A55` 和 `Cortex-M7` 是 Arm 设计的 CPU 核心型号，`i.MX95` 则是 NXP 设计的完整 SoC。NXP 在 i.MX95 中集成了多个 Cortex 核心以及 NPU、存储控制器和各种外设。因此，Cortex-A55 不是一颗独立的开发板芯片，而是 i.MX95 内部的 CPU 核心。

## Cortex-A、Cortex-R 和 Cortex-M

Cortex 后面的字母表示核心面向的主要应用方向。

| 系列       | 英文方向            | 主要特点                      | 常见软件               |
| -------- | --------------- | ------------------------- | ------------------ |
| Cortex-A | Application     | 运算能力强，支持 MMU、虚拟内存和复杂操作系统  | Linux、Android、QNX  |
| Cortex-R | Real-time       | 强调高性能实时控制、低延迟和功能安全        | 汽车控制、存储控制、实时系统     |
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

| 核心         | 常见用途           | 当前需要关注的内容                  |
| ---------- | -------------- | -------------------------- |
| Cortex-A55 | 运行 Linux 和复杂应用 | U-Boot、Linux、文件系统和 M7 固件管理 |
| Cortex-M7  | 高性能实时控制        | FreeRTOS 示例、实时任务和外设控制      |
| Cortex-M33 | 安全、低功耗和系统管理    | 启动管理及项目是否使用该核心             |

## 上电流程与 SM 的角色

前面几节讲的是"有哪些核、各自适合干什么"。这一节讲**上电之后这些核是按什么顺序醒的，以及为什么是这个顺序**。

### 先记住一句

> **SM（System Manager，跑在 AON M33 上）是"管家"，它比 A55 先醒，而且它决定 A55 怎么醒。**

### 先解释本节会反复出现的名词

第一次出现的缩写全部展开，并标出它在哪一层（硬件 / 固件 / OS）。**不先过一遍这张表，后面每个阶段都会卡住。**

| 缩写             | 英文全称                                                            | 中文                | 在哪一层             | 作用与相邻模块的关系                                                                                                                                                                                                                                                                                                                                                    |
| -------------- | --------------------------------------------------------------- | ----------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **POR**        | Power-On Reset                                                  | 上电复位              | **硬件**           | 电源建立后由复位电路产生的全局复位信号。它把整个 SoC 拉回确定状态，是所有软件阶段的起点                                                                                                                                                                                                                                                                                                                |
| **PMIC**       | Power Management IC                                             | 电源管理芯片            | **硬件（板级）**       | 板上的独立芯片，负责产生并按顺序释放各路电压。本板是 **PF09（PPF0900AMBA1ES）+ PF5301/PF5302 两片调压器**（`UM12527` §2.2）。它不归 SoC 管，是 SoC 的"供电方"                                                                                                                                                                                                                                               |
| **AON**        | Always-ON                                                       | 常开域               | **硬件（电源域）**      | SoC 内一个**永不断电**的电源域。复位时其它域都掉电，只有它保持供电，所以"最先醒"的电路都放在这里。i.MX95 里它叫 **AONMIX**（见 SDK 头文件里的 `AON__BLK_CTRL_NS_AONMIX1` / `AON__BLK_CTRL_S_AONMIX2`）                                                                                                                                                                                                               |
| **BBNSM**      | Battery-Backed Non-Secure Module                                | 电池后备非安全模块         | **硬件（BBSM 电源域）** | 管 RTC 与部分电源状态的非安全模块，由 **NVCC_BBSM_1P8** 单独供电，**复位时不断电**（`UM12527` Table 4 原文：*"except for the NVCC_BBSM_1P8 supply. The NVCC_BBSM_1P8 supply remains powered throughout the reset sequence"*）。时钟来自板上 **Y3 晶振 32.768 kHz**。⚠️ **它不属于 AONMIX，而属于独立的 BBSM 电源域**（`imx-sm/sm/doc/arch.md` 把 `BBNSM` 和 `BLK_CTRL_BBSMMIX` 都标为 `BBSM`）。两者的共同点是"复位时都不断电"，但它们是两个不同的电源域 |
| **Boot ROM**   | —                                                               | 片上启动 ROM          | **固件（掩膜 ROM）**   | 芯片出厂固化的代码，**不可修改**。i.MX95 上它位于 **M33 的地址 0x0，大小 256 KB**（见下方"阶段 1"）。上电后第一段被执行的代码                                                                                                                                                                                                                                                                              |
| **ROMCP**      | ROM Controller (Prototype)                                      | ROM 控制器           | **硬件**           | 控制对 Boot ROM 访问权限的寄存器模块，基址 **`0x44430000`**（`MIMX9596_cm7_COMMON.h`）。SM 配置里 `ROMCP_M33 OWNER` 表示归 SM 管                                                                                                                                                                                                                                                        |
| **SCP**        | System Control Processor                                        | 系统控制处理器           | **架构角色**         | 指"负责管系统的那颗核"。i.MX9 上 **AON 域里的 Cortex-M33 就是 SCP**（`imx-sm/sm/doc/arch.md` 原文）。它是**角色名**，不是芯片型号                                                                                                                                                                                                                                                               |
| **SM**         | System Manager                                                  | 系统管理器             | **固件**           | 跑在 AON M33 上的 NXP 固件。它做三件事：配置隔离机制、按顺序启动其它核、之后转入服务模式长期提供 SCMI 服务（`imx-sm/README.md` 原文）                                                                                                                                                                                                                                                                        |
| **ELE**        | EdgeLock Enclave                                                | 边缘锁安全区            | **硬件 + 固件**      | SoC 内独立的安全子系统（有自己的核和 ROM），做签名校验、生命周期管理、密钥/TRNG 服务。在 SM 配置里被建模为 `DOM0 did=0`                                                                                                                                                                                                                                                                                   |
| **AHAB**       | Advanced High Assurance Boot                                    | 高级高保证启动           | **固件（安全启动流程）**   | NXP 的安全启动机制，由 Boot ROM 触发、ELE 执行，校验启动容器的签名                                                                                                                                                                                                                                                                                                                    |
| **TCM**        | Tightly Coupled Memory                                          | 紧耦合内存             | **硬件**           | 直接挂在 CPU 核心上的高速内存，不经缓存和 DDR。分 **ITCM**（指令）和 **DTCM**（数据）。**每个核看到的 TCM 地址不同**，这是后面地址对照的关键                                                                                                                                                                                                                                                                      |
| **LM**         | Logical Machine                                                 | 逻辑机               | **固件（SM 概念）**    | SM 把"一个核 + 它的一批资源"打包成一个逻辑机，可以独立启动/复位/下电。本板有 3 个：`LM0=SM`、`LM1=M7`、`LM2=AP(A55)`                                                                                                                                                                                                                                                                               |
| **DID**        | Domain ID                                                       | 域 ID              | **硬件（总线属性）**     | 每个总线主设备（LM/域）在总线上携带的身份号。TRDC 按 DID 判定权限。本板：SM=2、M7=4、AP=3                                                                                                                                                                                                                                                                                                     |
| **TRDC / RDC** | Trusted Resource Domain Controller / Resource Domain Controller | 可信资源域控制器 / 资源域控制器 | **硬件**           | 总线级的访问过滤器：**TRDC** 管外设和内存块，**RDC** 管部分外设。它按 DID 判定"这个主设备能不能碰这个地址"。**它是硬件闸门，Linux 的 root 权限越不过它**                                                                                                                                                                                                                                                              |
| **SCMI**       | System Control and Management Interface                         | 系统控制与管理接口         | **协议（ARM 标准）**   | 各核与 SM 通信的标准协议。承载在 **MU**（Message Unit，消息单元，一种核间邮箱硬件）之上                                                                                                                                                                                                                                                                                                       |
| **PSCI**       | Power State Coordination Interface                              | 电源状态协调接口          | **协议（ARM 标准）**   | 操作系统用来"叫醒/关掉一个 CPU 核"的标准接口。**A55 的 CPU1~5 就是 Linux 通过 PSCI 叫醒的**                                                                                                                                                                                                                                                                                              |
| **ATF / BL31** | ARM Trusted Firmware / Boot Loader stage 3-1                    | ARM 可信固件          | **固件**           | 跑在 A55 的 **EL3**（最高异常级），建立安全监控环境，并提供 PSCI 服务                                                                                                                                                                                                                                                                                                                  |
| **SPL**        | Secondary Program Loader                                        | 二级程序加载器           | **固件**           | A55 上跑的第一段**可见**代码（Boot ROM 之后），负责加载 BL31 和 U-Boot                                                                                                                                                                                                                                                                                                            |
| **OCRAM**      | On-Chip RAM                                                     | 片上 SRAM           | **硬件**           | SoC 内部的通用 SRAM，地址 `0x20480000`。常用作启动阶段的临时装载区                                                                                                                                                                                                                                                                                                                  |

### 三层心智模型

理解后面所有阶段的前提：i.MX95 不是一个"CPU + 外设"的芯片，而是**多核 + 多域 + 权限管理器**。

| 层        | 谁在管                 | 关键概念                   | 决定什么          |
| -------- | ------------------- | ---------------------- | ------------- |
| ① 启动与安全层 | Boot ROM + ELE      | 启动介质选择、AHAB 校验、生命周期    | **上电后谁先跑**    |
| ② 系统管理层  | AON M33 上的 SM       | LM、DID、TRDC/RDC、SCMI   | **哪个核能用哪个外设** |
| ③ 计算层    | A55×6 / M7 / M33 本体 | 地址空间、TCM/OCRAM/DDR、异常级 | **代码放哪、怎么跑**  |

### 七个阶段总览

```text
阶段 0  上电复位（POR）            ← 纯硬件
阶段 1  M33 执行 Boot ROM          ← 固件（掩膜 ROM）
阶段 2  M33 从 TCM 启动 SM         ← 固件（SM 的 Reset_Handler）
阶段 3  SM 初始化 + 写隔离配置      ← 固件（SM main）
阶段 4  SM 拉起 M7（LM1）          ← 固件（SM）
阶段 5  SM 拉起 A55 集群（LM2）     ← 固件（SM），只放 CPU0
阶段 6  A55 链：SPL → BL31 → U-Boot → Linux
阶段 7  Linux 用 PSCI 叫醒 CPU1~5
```

### 一句话串起七个阶段

> **管家先上岗，把规矩定好，再叫醒干活的。**

AON M33 上的 SM 之所以必须先于 A55 运行，是因为**需要有个人先"分配资源"**。如果 A55 先跑，它会默认自己是主人，想用哪个外设就用哪个；等它把资源全占了再想收回来就晚了。所以设计成：**SM 先把隔离规则写进硬件（阶段 3），再按顺序放核（阶段 4、5）。**

**由此得到本节最重要的结论**：

> **资源隔离是 SM 在 Linux 起来之前就写进硬件的。**
> 隔离不是 Linux 做的，Linux 只是"被告知"结果。对应项目要求里的"资源隔离与权限分配"——**主体是 SM，不是操作系统**。

其余几点（为什么只放 CPU0、切核为什么可行、各环职责、启动模式引脚）已在下面各阶段中详述，此处不重复。

---

## 阶段 0：上电与复位（**纯硬件，无任何软件参与**）

这一阶段**没有一行代码在跑**，全部由电源芯片和 SoC 内部复位电路完成。把它单独列出来，是因为后面每个阶段都建立在"复位已经把 SoC 拉到一个确定状态"这个前提上。

### 谁在做

**PF09 PMIC** 和 SoC 内部的复位/时钟电路。**不是** Boot ROM，也**不是**任何 CPU 核。

### 具体做了什么

| 步骤  | 动作                                            | 性质  |
| --- | --------------------------------------------- | --- |
| 0.1 | 合上电源开关 **SW1**（USB Type-C PD 供电），PMIC 检测到有效输入 | 硬件  |
| 0.2 | **PF09 按 i.MX95 要求的顺序逐路释放电压**                 | 硬件  |
| 0.3 | 电压稳定后，PMIC 释放复位信号（POR_B），SoC 内部复位同步释放         | 硬件  |
| 0.4 | SoC 把各核置于复位态，**只有 AON 域保持供电并开始工作**            | 硬件  |

`UM12527` §2.2.1 原文（**官方资料明确说明**）：

> "Power-up and power-down sequencing of all processor rails is handled **internally by the PF09 PMIC** in accordance with i.MX 95 requirements. **No user configuration is required.** All rails are enabled automatically when the system power switch (SW1) is turned ON and a valid USB-C PD supply is present."

**注意最后一句**：电源时序不需要用户配置，PMIC 自己按 i.MX95 的要求做。这一点和很多需要外部电源管理代码的 SoC 不同。

### 手动复位怎么发生

`UM12527` Table 4（**官方资料明确说明**）：

> **K1 Reset 按钮**："generates a falling edge to **PF09 FCCU1 pin** and forces the PF09 PMIC to initiate a **system cold reset**. During a cold reset, the PMIC **power cycles all system power rails** and reinitializes the entire platform, **except for the NVCC_BBSM_1P8 supply. The NVCC_BBSM_1P8 supply remains powered throughout the reset sequence.**"

链路：

```text
按下 K1（或 SW3 长按）
  → PF09 PMIC 的 FCCU1 引脚收到下降沿
  → PMIC 执行 system cold reset
  → 所有电源轨重新上电（除了 NVCC_BBSM_1P8）
  → 回到步骤 0.2
```

**为什么 NVCC_BBSM_1P8 不断电**：它供的是 **BBNSM**（RTC + 部分电源状态），时钟来自板上 **Y3 晶振 32.768 kHz**（`UM12527` §2.4）。保持供电才能让 RTC 继续走时、让逻辑记住唤醒原因。**这也是"冷复位"和"断电"的区别**——冷复位不丢时间，断电才丢。

> ⚠️ 注意一个容易混的点：**BBNSM 和 AON 不是同一个电源域**。`imx-sm/sm/doc/arch.md` 把 `BBNSM`、`BLK_CTRL_BBSMMIX` 归为 **BBSM** 域，而把 M33P、WDOG1/2、ROMCP 等归为 **AONMIX** 域。它们的共同点是"复位期间都不断电"，但是**两个独立的域**，不要当成一个。详见下面的专题「AON 常开域」。

### 这一阶段的产出

```text
- 所有电源轨就绪
- 各核处于复位态（PC 被硬件置为各自的重置入口）
- AON 域已通电并工作
- BBNSM/RTC 继续运行（若之前有电）
```

### 怎么衔接到阶段 1

**纯硬件衔接，没有软件参与**：复位释放后，**Cortex-M33 从 Boot ROM 的复位入口取第一条指令**。

关于 M33 的复位入口地址：`M33_ROM` 区间是 `0x00000000–0x0003FFFF`（SM 配置原文，**源码可以确认**），NXP 提供的 ROM 模拟链接脚本也把 ROM 放在 `0x0`（`tools/imx-sm/devices/MIMX95/gcc/MIMX95_cm33_rom.ld`：`m_rom (RX) : ORIGIN = 0x00000000, LENGTH = 0x00020000`）。**但 ROM 内部第一条指令的确切地址属于 NXP 掩膜实现，公开资料不给出**（`待验证`）。

---

## 阶段 1：M33 执行 Boot ROM

### 谁在执行、在哪执行

- **执行主体**：**AON 域里的 Cortex-M33**（它此时的身份是 **SCP**）
- **执行位置**：片内 **Boot ROM**，地址 `0x00000000`，大小 **256 KB**（SM 配置 `M33_ROM EXEC, begin=0x000000000, end=0x00003FFFF`）
- **性质**：**固件**，出厂掩膜固化，**不可修改、不可擦写**

> **为什么是 M33 而不是 A55 来跑 Boot ROM？**
> 因为 Boot ROM 要做的第一件事就是"决定从哪启动、把谁叫起来"，如果这件事由被叫醒的核自己做，就没有"分配者"了。M33 在 AON 域、复位后最先可用，天然适合当这个角色。`UM12527` Table 7 的"Boot core"列**官方写明是 Cortex-M33**。

### 具体做了什么

| 步骤  | 动作                                   | 证据                                       |
| --- | ------------------------------------ | ---------------------------------------- |
| 1.1 | 建立最小运行环境（基础时钟等）                      | `待验证`（属掩膜 ROM 内部实现）                      |
| 1.2 | **采样 4 根 BOOT_MODE 引脚**，决定启动介质       | `UM12527` §2.3 Table 7（**官方**）           |
| 1.3 | 从选定的启动设备读取**启动容器**（`flash.bin`）      | `imx-mkimage` 文档（**源码可以确认**）             |
| 1.4 | 触发 **AHAB 校验**：把控制权交给 ELE 做签名/生命周期校验 | 实机 `ELE firmware version 2.0.5-fe6641ef` |
| 1.5 | 按容器描述，把各镜像装到各自地址，**跳转到 SM 入口**       | 容器解析报告（**实机验证**）                         |

### 启动模式引脚（1.2 的细节）

`UM12527` §2.3 Table 7（**官方资料明确说明**）：

```text
SW4[1]   SW4[2]   SW4[3]   SW4[4]
BOOT_MODE3 BOOT_MODE2 BOOT_MODE1 BOOT_MODE0

Boot core    Boot device
x  0  0  1   Serial downloader (USB)
x  0  1  0   uSDHC1 8-bit eMMC 5.1
x  0  1  1   uSDHC2 4-bit SD 3.0
x  1  0  0   Cortex-M33   FlexSPI Serial NOR flash
```

三点必须注意：

1. **"读引脚"是 ROM 代码在做**，引脚本身只是拨码开关的静态电平。SW4 **不是**"选择运行 Linux 还是 FreeRTOS"的开关，它只告诉 ROM 去哪找容器。
2. **`x` 是最低位无关**，只看后三位。所以 `1001` 满足 `x001`。
3. **Boot ROM 只在上电/复位瞬间采样一次**。改了 SW4 必须让 SoC 重新复位才生效——这就是"改完拨码要断电重上电"的原因。

### 启动容器里有什么（1.5 的输入）

容器不是"一个 bin"，而是 i.MX 规定的多容器格式。实机解析报告（`F:\project\Learning\RTOS\build\pro-gpio\flash-m7-gpio.parse.txt`，**实机验证**）：

```text
ROM CONTAINER 1:  ELE 固件                      56336 B
ROM CONTAINER 2:  Primary/Secondary V2X 固件     45440 + 10496 B
ROM CONTAINER 3:  DDR QB Dummy                  0 B
                  DDR Init / OEI                324608 B  @ load 0x1FFC0000, entry 0x1FFC0001
                  M33 System Manager            182272 B  @ load 0x1FFC0000, entry 0x1FFC0000
                  M7  FreeRTOS                   24576 B  @ load 0x303C0000, entry 0x0
                  A55 SPL                       167936 B  @ load 0x20480000, entry 0x20480000
                  V2X Dummy                         0 B
APP CONTAINER 1:  BL31                           43008 B  @ 0x8A200000
                  U-Boot                       1215488 B  @ 0x90200000
                  TEE                           606208 B  @ 0x8C000000
```

**每个镜像描述里带：类型、核心编号、装载地址、入口地址、大小、SHA384 哈希。** Boot ROM/ELE 就是按这些字段把镜像放到指定地址的——这就是"阶段之间怎么衔接"的答案：**不是靠约定，是靠容器里的显式地址字段**。

> ⚠️ 注意 `DDR Init/OEI` 和 `M33 System Manager` **装载地址都是 `0x1FFC0000`**，但它们的**入口地址不同**（`0x1FFC0001` vs `0x1FFC0000`），而且容器里靠**偏移**把它们排开（OEI 在 0x22C00，中间留 64 KB QB 保留区，SM 在 0x82000）。这是"同一个基址、分时复用"——**OEI 先跑完 DDR 训练，SM 再接管**。

### 这一阶段的产出

```text
- 选定了启动介质
- 容器通过 AHAB 校验
- DDR 训练完成（由容器里的 OEI 镜像完成）
- SM 镜像已被放到 M33 的 ITCM 0x1FFC0000
- 控制权即将交给 SM
```

### 怎么衔接到阶段 2

**衔接机制 = "搬代码到固定地址" + "在固定地址留带魔数的结构" + "跳转"**，三件事叠在一起。

#### (a) 搬代码 + 跳转：跳转那一步的原始代码

`tools/imx-sm/devices/MIMX95/gcc/rom_MIMX95_cm33.S` 第 332–336 行（**源码可以确认**）：

```asm
/* Load PC and SP */
ldr r0, =0x1FFC0000
ldr r13, [r0, #0]      ; SP  ← 0x1FFC0000 处的第 1 个字
ldr r1,  [r0, #4]      ; PC  ← 0x1FFC0004 处的第 2 个字
bx  r1                 ; 跳过去
```

**这就是 Boot ROM 交接给 SM 的确切动作**：把 `0x1FFC0000` 当作 Cortex-M 的向量表来读——第 1 个字当栈顶（MSP），第 2 个字当复位入口，然后 `bx` 跳过去。**和 STM32 复位后硬件从向量表取 SP/PC 是同一个约定**，区别只是这里由 ROM 代码显式做。

#### (b) 留带魔数的结构：Handover / Passover

Boot ROM 不是"跳完就不管了"，它还在固定地址留下两张**信息表**给 SM 读：

| 结构 | 地址 | 魔数（tag） | 内容 |
|---|---|---|---|
| **Handover** | `0x2003DC00` | `0xC0FFEE16` | 启动镜像信息（两个镜像、SM CPU 编号等） |
| **Passover** | `0x2003DE00` | （同族 tag/ver/size） | 传给 SM 的启动参数 |

ROM 侧写入：`rom_MIMX95_cm33.S` 第 56–115 行（`HANDOVER_BASE` / `PASSOVER_BASE`）。
SM 侧读取：`devices/MIMX95/sm/dev_sm_rom.c` 的 `DEV_SM_RomHandoverGet()`（84–119 行）、`DEV_SM_RomPassoverGet()`（124–159 行）、`DEV_SM_RomBootImgNGet()`（175 行起）。

**为什么用"固定地址 + 魔数"而不是函数参数**：因为 ROM 和 SM 是**分别编译的两段固件**，ROM 是掩膜的、改不了，两者之间没有共同的调用约定，也不能靠链接器解析符号。**在约定地址放一个带魔数的结构，是这种"两个独立固件交接"最常用的做法**——魔数用来确认"这块内存确实是上一级留给我的，不是我读到的垃圾"。

> **这正是理解 i.MX95 启动的关键模式**：越靠前的阶段，越依赖"约定地址 + 魔数"这种硬编码约定；越靠后，越依赖标准协议。

#### (c) 完整衔接链

```text
Boot ROM：
  按容器描述把 m33_image.bin 写到 ITCM 0x1FFC0000
  在 0x2003DC00 写 handover 结构（tag 0xC0FFEE16）
  在 0x2003DE00 写 passover 结构
  ldr r13, [0x1FFC0000]   → 设栈顶
  ldr r1,  [0x1FFC0004]   → 取 Reset_Handler 地址
  bx  r1                  → 跳转
SM（阶段 2）：
  Reset_Handler 开始执行
  之后 main() 里用 DEV_SM_RomPassoverGet() 把 ROM 留的参数读回来
```

**为什么地址是 `0x1FFC0000`**：这是 M33 **本地视角**的 ITCM 起始地址（`tools/imx-sm/devices/MIMX95/gcc/MIMX95_cm33_ram.ld`：`m_interrupts (RX) : ORIGIN = 0x1FFC0000, LENGTH = 0x00000800`）。系统侧（A55/ELE）看同一块物理内存是另一个地址：

| 视角 | ITCM 起始 | 证据 |
|---|---|---|
| **M33 本地** | `0x1FFC0000` | SM 链接脚本 `MIMX95_cm33_ram.ld` |
| **系统侧** | `0x201C0000` | SM 配置 `M33_TCM_CODE EXEC, begin=0x0201C0000, size=256K` |

**这和 M7 是同一个道理**：M7 的 ITCM 在 M7 本地是 `0x0`，在系统侧是 `0x203C0000`。**同一个物理存储，不同核看到的地址不同**——这是理解后面所有地址对照的关键。

---

## 阶段 2：M33 从 TCM 启动 System Manager

### 谁在执行、在哪执行

- **执行主体**：AON Cortex-M33
- **执行位置**：**ITCM `0x1FFC0000`**（不是 ROM 了）
- **入口**：`Reset_Handler`（链接脚本 `ENTRY(Reset_Handler)`，实现在 `tools/imx-sm/devices/MIMX95/gcc/startup_MIMX95_cm33.S`）

### 具体做了什么（**寄存器级**）

`startup_MIMX95_cm33.S` 第 439 行起，`Reset_Handler` 按顺序做：

**第 1 步：武装看门狗（整个 SM 的第一件事）**

```asm
_AON_BLK_CTRL_BASE = 0x444F0000     ; AON__BLK_CTRL_S_AONMIX2
_WDOGBASE          = 0x442E0000     ; WDOG2
_WDOG_UNLOCK_KEY   = 0xD928C520
_WDOGANY  = 0x1B8   _WDOGCS = 0x0   _WDOGCNT = 0x4   _WDOGTOVAL = 0x8

str 0x1D,       [0x444F0000 + 0x1B8]   ; 配置 WDOG 驱动 WDOG_ANY 输出
str 0xD928C520, [0x442E0000 + 0x4]     ; 解锁 WDOG2（写解锁键到 CNT）
str 32768,      [0x442E0000 + 0x8]     ; TOVAL = 1000ms × 32768Hz
str 0x21E2,     [0x442E0000 + 0x0]     ; 写 WDOGCS 使能
```

`WDOGCS = 0x21E2` 的逐位含义（**源码注释原文**）：

```text
WDGW   = 0  (1<<15)  窗口模式关闭
CMD32  = 1  (1<<13)  启用 32 位命令
PRES   = 0  (1<<12)  不分频
CLK    = 1  (1<<8)   时钟源 = LPOCLK（低功耗振荡器，即 AON 的 32.768 kHz）
EN     = 1  (1<<7)   使能看门狗
INT    = 1  (1<<6)   使能提前中断
UPDATE = 1  (1<<5)   允许更新 WDGCS
WAIT   = 1  (1<<1)   wait 模式下继续计数
→ 0x21E2
```

**交叉印证**：SM 配置里 `LM0(SM)` 的资源列表包含 `WDOG1 OWNER` / `WDOG2 OWNER`（`mx95frdm-pro.cfg` 第 281–282 行），而 startup 代码武装的正是 **WDOG2（0x442E0000）**。**两个独立来源对上了**，说明这段代码确实是 SM 在跑。

> **为什么第一件事是武装看门狗？**
> 因为看门狗用的是 **AON 域的 32.768 kHz 低功耗时钟**，不依赖任何后续初始化，复位后立刻可用。SM 要在"自己还没初始化完"的这段危险期里有个兜底：如果初始化卡死，1 秒后硬件自己复位重来。**这解释了为什么"SM 起不来"时表现为反复复位而不是死机。**

**第 2 步：建立 C 运行环境**

```asm
cpsid i                          ; 关中断
VTOR (0xE000ED08) = __isr_vector ; ★ 把向量表基址指向 SM 自己的向量表 0x1FFC0000
msp = __isr_vector[0]            ; 从向量表第 0 项取栈顶，设置主栈指针
清 __StackLimit..__StackTop      ; 栈区清零
清 __HeapBase..__HeapLimit       ; 堆区清零
bl SystemInit                    ; 时钟/基础外设初始化
拷贝 .data（__etext → __data_start__..__data_end__）  ; 把已初始化数据从 ROM 搬到 RAM
（随后清零 .bss）
```

> **`VTOR` 这一步很关键**：复位时 M33 的向量表在 ROM（`0x0`），现在 SM 把它改指向自己的 ITCM（`0x1FFC0000`）。**这就是"从 ROM 世界切换到 SM 世界"的标志性动作**——之后所有中断都走 SM 的向量表。

### 这一阶段的产出

```text
- 看门狗已武装（1 秒超时，AON 时钟）
- M33 的向量表、栈、堆、.data/.bss 就绪
- 基础时钟与外设初始化完成
- 即将进入 SM 的 main()
```

### 怎么衔接到阶段 3

**衔接机制 = 普通函数调用**（`bl main`）。到这里才第一次出现"软件调用软件"，前面全是硬件跳转。

---

## 阶段 3：SM 初始化并写入隔离配置

### 谁在执行、在哪执行

AON M33，ITCM 里的 SM 固件，`main()` 及其调用链。

### 具体做了什么

`imx-sm/sm/doc/arch.md` 的 "SM Framework" 描述（**官方资料明确说明**）：

```text
- Boot:  main() 入口
         * 配置底层 device（SoC 级）与 board（板级）抽象
         * 初始化实现数据，含 LMM、SCMI、RPC、Mailbox
         * 启动各个 logical machine
         * 之后变成 idle loop，空闲时把系统带入低功耗
- Monitor: UART 命令行（实机 COM19 上的 "*** SM Debug Monitor ***"）
```

| 步骤 | 动作 | 说明 |
|---|---|---|
| 3.1 | `DEV_SM` 设备抽象初始化 | 基于 MCUXpresso SDK 驱动：BBNSM/CACHE/CLOCK/CPU/ELE/IOMUXC/LPI2C/LPUART/MU1/PMIC/POWER/RESET… |
| 3.2 | `BRD_SM` 板级抽象初始化 | PMIC、I2C 扩展器、板级 RTC、板级传感器 |
| 3.3 | **★ 写 TRDC/RDC 隔离配置** | **在任何其它核启动之前** |
| 3.4 | 初始化 LMM / SCMI / RPC / Mailbox | 建立与各核的通信通道 |
| 3.5 | 进入 LM 启动循环 | 按 `boot[]` 顺序拉起各逻辑机 |

### 3.3 为什么必须排在这里（**顺序不能乱**）

`arch.md` 原文（**官方资料明确说明**）：

> "Isolate execution of different cores to prevent interference — this includes having **exclusive access the RDCs and loading their configuration before starting any other cores**"

**必须"先写隔离、再放核"**，因为：

```text
如果反过来（先放核，再写隔离）：
  A55 一起来就认为自己可以使用全部外设
  它会去配置时钟、申请内存、初始化设备
  等 SM 再去写 TRDC 说"这个外设不归你"，
  A55 可能已经在用了 → 取指/访问失败、状态不一致，甚至直接跑飞
```

**所以隔离是"在别的核睁眼之前就摆好的既定事实"**，而不是运行期的协商。SM 配置里 `TRDC_A…TRDC_W` 全部 `OWNER` 给 `LM0(SM)` 就是这个意思——**只有 SM 有权改这些闸门**。

**这解释了一件项目里反复遇到的事**：Linux 里的 root 是 **LM2 内部**的超级用户，它的权限上限由 LM2 的 EENV 决定。SM 没给 LM2 的东西，root 也拿不到——历史上 `remoteproc` 报 `lmm(1) not under Linux Control`、U-Boot `prepaux` 写 M7 TCM 触发同步异常，根因都在这里。

### 3.4 通信通道怎么建立的

`arch.md` 的组件关系（**官方资料明确说明**）：

```text
Mailbox → Transport(SMT) → RPC(SCMI 协议/agents) → LMM → Device/Board
```

板级配置里的实例（`mx95frdm-pro.cfg`，**源码可以确认**）：

```text
SCMI_AGENT0 name="M7"    MAILBOX type=mu, mu=9    ← M7 用 MU9
SCMI_AGENT1 name="AP-S"  MAILBOX type=mu, mu=1    ← A55 安全侧用 MU1
SCMI_AGENT2 name="AP-NS" MAILBOX type=mu, mu=3    ← A55 非安全侧用 MU3
```

### 这一阶段的产出

```text
- SoC/板级外设初始化完成
- TRDC/RDC 隔离规则已写入硬件（此时其它核还在复位态）
- SCMI 通信通道就绪
- 即将按 boot[] 顺序启动各逻辑机
```

### 怎么衔接到阶段 4

**衔接机制 = SM 内部的 LM 启动循环**，按配置里的 `boot[]` 顺序执行。本板 `boot[]`（`mx95frdm-pro.cfg`，**源码可以确认**）：

```text
LM0  name="SM",  rpc=none,  boot=1,                did=2, safe=feenv
LM1  name="M7",  rpc=scmi,  boot=2, skip=1,        did=4, safe=seenv
LM2  name="AP",  rpc=scmi,  boot=3, skip=1,        did=3, default
```

即 **自己(1) → M7(2) → A55/AP(3)**。`skip=1` 的含义是 **bootSkip**："容器里没有该 LM 的镜像时不要报错"，**不是**"跳过启动"。

---

## 阶段 4：SM 拉起 M7（LM1）

### 谁在执行、在哪执行

AON M33 上的 SM，执行启动命令表中的 M7 段。

### 具体做了什么

启动命令是**有序的寄存器/电源操作序列**，不是一条"启动"指令。从 `config_lmm.h` 生成的 `SM_LM_START_DATA` 表（**源码可以确认**）：

| 序 | LM | 命令 | 目标资源 | 含义 |
|---|---|---|---|---|
| 1 | M7 | `LMM_SS_PD` | `DEV_SM_PD_M7` | **M7 电源域上电** |
| 2 | M7 | `LMM_SS_CPU` | `DEV_SM_CPU_M7P` | **释放 M7 出复位** |

对应 `mx95frdm-pro.cfg` 里的写法（**源码可以确认**）：

```text
PD_M7   start=1, stop=2      ← 先开 M7 所在电源域
CPU_M7P start=2, stop=1      ← 再放 CPU 出复位
```

### 顺序不能乱：为什么必须先 `PD_M7` 再 `CPU_M7P`

```text
正确顺序：先给电源域上电 → 再释放 CPU 复位
  电源域没上电时，M7 的 TCM 和寄存器都不可访问

反过来会怎样：
  在电源域还没上电时释放 CPU 复位
  → CPU 立即开始取指
  → 但它的 TCM 没有供电，取指失败
  → 行为不确定（可能挂死、可能触发总线错误、可能读到垃圾）
```

### 这一阶段的产出

```text
- M7 电源域上电
- M7 已出复位，开始从它的复位入口取指
```

### 怎么衔接到阶段 5

**衔接机制 = SM 继续执行启动命令表的下一条**（M7 段结束后紧接 A55 段）。M7 一旦被释放就**独立运行**，SM 不等它、也不管它跑成什么样——**这是"启动"不是"监督"**。

> 补充：M7 的代码从哪来，取决于容器里有没有 M7 镜像。容器里有 `-m7 m7_image.bin 0 0x0 0x303C0000`（装载地址是**系统侧别名** `0x303C0000`，入口 `0x0` 是 **M7 本地视角**的 ITCM）。若容器里没有 M7 镜像且 `skip=1`，SM 跳过且不报错。

---

## 阶段 5：SM 拉起 A55 集群（LM2）——只释放 CPU0

### 谁在执行、在哪执行

AON M33 上的 SM，执行启动命令表的 A55 段。

### 具体做了什么

A55 的启动序列比 M7 长得多，因为它涉及**电压、电源域、性能档位（频率）**三层：

```text
VOLT_ARM  start=1|1, stop=9     ← ① 建立 ARM 电压
PD_A55P   start=2,   stop=8     ← ② A55 平台域上电
PERF_A55  start=3|3             ← ③ 设定性能档位（对应工作频率）
CPU_A55C0 start=4               ← ④ 释放 CPU0 复位 ★ 只放这一个
CPU_A55C1..C5  stop=7..2        ← C1~C5 只有"停"的条目
CPU_A55P  stop=1
```

生成头文件里的实际命令表（mSel=0 档，**源码可以确认**）：

| 序 | LM | 命令 | 目标资源 | 参数 | 含义 |
|---|---|---|---|---|---|
| 3 | AP | `LMM_SS_VOLT` | `DEV_SM_VOLT_ARM` | 1 | 建立 ARM 电压 |
| 4 | AP | `LMM_SS_PD` | `DEV_SM_PD_A55P` | — | A55 平台域上电 |
| 5 | AP | `LMM_SS_PERF` | `DEV_SM_PERF_A55` | 3 | A55 性能档位 = 3 |
| 6 | AP | `LMM_SS_CPU` | `DEV_SM_CPU_A55C0` | — | **只释放 A55 的 CPU0** |

### 顺序不能乱：为什么是"电压 → 电源域 → 频率 → 放核"

```text
① 电压：ARM 集群需要特定的核心电压才能工作在目标频率
② 电源域：给 A55 平台供电
③ 性能档位：此时才能安全地把时钟切到目标频率
④ 释放 CPU0：电压和频率都稳了，核才可以开始跑

任何一步提前都会出问题：
- 先放核再给电压 → 核在欠压状态下取指，行为不确定
- 先切高频再升压 → 同样欠压，可能直接损坏或锁死
```

**和 STM32 的对比**：STM32 上电后电压是固定的，不需要软件参与"升压"。i.MX95 因为要支持多种性能档位和低功耗状态，**电压/频率是一组必须按序执行的软件动作**——这是应用处理器和单片机的典型差别。

### ★ 为什么只释放 CPU0（这是本节最重要的一点）

**SM 的启动表里只有 `DEV_SM_CPU_A55C0` 一条。C1~C5 不在 SM 的启动列表里。**

```text
A55 集群（6 个核）
   CPU0   ← SM 只释放这一个，它是 boot core
   CPU1~5 ← 保持在复位态，等着被"叫醒"
```

**为什么这样设计**：多核启动比单核复杂得多——谁当主核、栈放哪、核间怎么同步、缓存怎么维护，这些 **Linux 自己比 SM 更清楚**。所以约定：**SM 只放 CPU0 出去，剩下的由操作系统通过 PSCI 按需叫醒。**

**这条设计带来一个重要的推论**：CPU1~5 本来就是"运行期才被叫醒的资源"，所以**在运行期把它们中的某一个"截走"是可行的**——这正是 Jailhouse/Harpoon 能在 A55 上切出一个核给 FreeRTOS 的底层前提。

### 这一阶段的产出

```text
- ARM 电压、A55 平台域、性能档位就绪
- CPU0 出复位，从它的复位入口取指
- CPU1~5 仍在复位态
```

### 怎么衔接到阶段 6

**衔接机制 = 同样的"搬代码 + 释放核"**。容器里 A55 SPL 的描述是 `@ load 0x20480000, entry 0x20480000`（**实机验证**，来自容器解析报告），所以：

```text
Boot ROM/ELE 早已把 SPL 放到 OCRAM 0x20480000
SM 释放 CPU0
→ CPU0 从 0x20480000 取第一条指令
```

**注意这里的层次**：SPL 是 **Boot ROM 阶段**就装好的，SM 只负责"放核"。**装载和放核是两件事，由两个不同的主体在不同时间完成。**

---

## 阶段 6：A55 链 —— SPL → BL31 → U-Boot → Linux

### 谁在执行、在哪执行

A55 的 CPU0，依次在不同异常级、不同内存位置运行四段固件。

### 具体做了什么

| 子阶段 | 谁在跑 | 在哪跑 | 异常级 | 干什么 |
|---|---|---|---|---|
| 6.1 | **SPL** | OCRAM `0x20480000` | EL3（或 EL2） | 初始化串口、校验并从启动介质读入后续镜像 |
| 6.2 | **BL31（ATF）** | `0x8A200000` | **EL3** | 建立安全监控环境、异常级切换、提供 PSCI 服务 |
| 6.3 | **U-Boot** | `0x90200000` | **EL2** | 读设备树、组装启动参数、加载内核 |
| 6.4 | **Linux** | DDR | **EL1** | 接管 A55，启动内核与 systemd |

实机日志逐行对应（`build/logs/`，**实机验证**）：

```text
U-Boot SPL 2025.04-g99518e6b6f20          ← 6.1 A55 第一段可见代码
SYS Boot reason: por / LM Boot reason: por  ← SM 记录的复位原因
Trying to boot from MMC1
NOTICE: BL31: v2.12.0(release):lf-6.18.2-1.0.0   ← 6.2 ATF
U-Boot 2025.04-g99518e6b6f20              ← 6.3
Model: NXP FRDM-IMX95-PRO board / DRAM: 15.8 GiB  ← DDR 已就绪（SM 阶段就训练完了）
Loading Environment from MMC... bad CRC, using default environment
Starting kernel ...                       ← 6.4
Linux version 6.18.2-1.0.0
smp: Brought up 1 node, 6 CPUs            ← 阶段 7 完成
```

**注意 `DRAM: 15.8 GiB` 这一行**：U-Boot 能报出容量，说明 **DDR 早在 SM 阶段就已经训练完成了**（容器里的 OEI 镜像干的，见阶段 1）。U-Boot 只是"读"这个结果，不负责训练 DDR。

### 异常级怎么分配

```text
EL3  ← BL31 (ATF)      最高，管安全和 PSCI
EL2  ← U-Boot / hypervisor（Harpoon 时 Jailhouse 占这里）
EL1  ← Linux 内核
EL0  ← Linux 用户态程序
```

**U-Boot 为什么是 EL2 而不是 EL1**（`imx95_bl31_setup.c:51-65`，**源码可以确认**）：BL31 会**读 A55 的能力寄存器**再决定：

```c
el_status = read_id_aa64pfr0_el1() >> ID_AA64PFR0_EL2_SHIFT;
el_status &= ID_AA64PFR0_ELX_MASK;
mode = (el_status) ? MODE_EL2 : MODE_EL1;   // A55 实现了 EL2 → 用 EL2
```

即 **"SoC 支持 EL2 就把 U-Boot 放 EL2，否则退回 EL1"**。i.MX95 的 A55 实现了 EL2，所以 U-Boot 跑在 EL2。

**Harpoon 能工作的前提就在这张表里**：Jailhouse 要占的正是 **EL2**，而 Linux 只在 EL1。EL2 比 EL1 高一级，所以 hypervisor 能在 Linux 不知情的情况下接管核和内存的映射。**U-Boot 把 EL2 让出来之后，这一级就空着等 hypervisor 入驻。**

BL31 在这个阶段的三个关键动作（`imx95_bl31_setup.c`，**源码可以确认**）：

| 函数 | 行号 | 动作 |
|---|---|---|
| `bl31_early_platform_setup2()` | 67–107 | 注册 LPUART 控制台；填充 `bl33_image_ep_info`（U-Boot 入口 = `PLAT_NS_IMAGE_OFFSET` = `0x90200000`） |
| `bl31_plat_arch_setup()` | 109–146 | **把 GPIO2~5 全部划给非安全世界**；建 MMU 表；`enable_mmu_el3(0)` |
| `bl31_platform_setup()` | 148–171 | `generic_delay_timer_init()` → GICv3 初始化 → `ele_get_soc_info()` → `plat_imx9_scmi_setup()` |

> ⚠️ **第二行是项目里一个老问题的根因**：`bl31_plat_arch_setup()` 会把 GPIO2 的按引脚安全属性写成全 1，导致此前 M7 侧读 GPIO14/15 得 0、写入无效。**这不是 bug，是 BL31 的正常行为**——它认为 GPIO2~5 都归非安全世界。

`platform.mk` 里的编译开关（**源码可以确认**）：

```make
RESET_TO_BL31             := 1    # BL31 直接在 EL3 运行，不需要更早的一级
PROGRAMMABLE_RESET_ADDRESS:= 1
COLD_BOOT_SINGLE_CPU      := 1    # ★ 冷启动只启动一个核（对应阶段 5"只放 CPU0"）
BL32_BASE                 ?= 0x8C000000   # OP-TEE
```

`COLD_BOOT_SINGLE_CPU := 1` 和 SM 启动表里"只释放 CPU0"是**同一件事在两个层次上的表达**。

### 怎么衔接到阶段 7

**衔接机制 = 标准接口请求（PSCI）**，不再是"搬代码 + 放核"了。

Linux 启动过程中发现设备树里声明了 6 个 CPU，于是对 CPU1~5 逐个调用 **PSCI `CPU_ON`**。完整路径（**源码可以确认**）：

```text
Linux (EL1)
  │ 写 PSCI CPU_ON，触发 SMC 指令
  ▼
ATF 通用 PSCI 状态机  psci_cpu_on()        ← lib/psci/psci_on.c（本工程源码树未包含）
  ▼
平台回调  plat_psci_ops.pwr_domain_on
  ▼
imx_pwr_domain_on()                        ← imx95_psci.c:535-562
  ├─ imx_set_cpu_boot_entry(core_id, secure_entrypoint, SCMI_CPU_VEC_FLAGS_BOOT)
  │     └─ scmi_core_set_reset_addr(...)   ← 告诉 SM "这个核起来后从哪取指"
  ├─ scmi_core_start(imx9_scmi_handle, scmi_cpu_id[core_id])   ← 请 SM 启动该核
  └─ scmi_core_nonIrq_wake_set(...)
  ▼
SCMI over MU：写 IMX9_MU1_BASE(0x44220000) 的门铃，消息放 IMX9_SCMI_PAYLOAD_BASE(0x44221000)
  ▼
SM（AON M33）执行与阶段 5 相同的"电压 → 电源域 → 频率 → 释放复位"序列
  ▼
核被叫醒，跳入 ATF 指定的入口
```

几个值得记住的细节（**源码可以确认**）：

- `boot_stage[6] = {false, true, true, true, true, true}`（`imx95_psci.c:121`）——**只有第一个 boot core 需要设向量表入口**，其余核靠 SCMI 传入口地址。这与"SM 只放 CPU0"完全对应。
- 入口地址有合法性检查：`imx_validate_ns_entrypoint()`（`:493-501`）拒绝 `ns_entrypoint < PLAT_NS_IMAGE_OFFSET`，防止内核被引导到不该去的地址。
- SCMI 标志位：`SCMI_CPU_VEC_FLAGS_BOOT = BIT(30)`、`SCMI_CPU_VEC_FLAGS_RESUME = BIT(31)`（`scmi_imx9.h:125-126`）——区分"冷启动这个核"和"从低功耗恢复这个核"。

> **`smp: Brought up 1 node, 6 CPUs` 就是这条链跑通的证据。**

**注意这一阶段和前几阶段的本质区别**：阶段 0~5 都是"固定地址 + 硬件信号"，到阶段 6→7 变成了"**标准协议 + 消息传递**"。原因是此时已经有操作系统在跑，可以用标准接口协商，不需要再靠约定地址了。

---

## 阶段 7：Linux 起来，6 个核全在线

```text
- Linux 在 CPU0 上完成初始化
- 通过 PSCI 依次叫醒 CPU1~5
- 6 个 A55 全部在线
- M33 上的 SM 进入 service mode，长期提供 SCMI 服务
- 之后才是 Harpoon 这类方案能做的事
```

SM **不会退出**。启动完各 LM 后它进入 idle loop + SCMI 服务模式，持续响应时钟/电源/复位/传感器/引脚/性能/CPU 等协议请求（`arch.md`，**官方资料明确说明**）。实机证据（Linux dmesg，**实机验证**）：

```text
arm-scmi arm-scmi.0.auto: SCMI Protocol v2.1 'NXP:IMX' Firmware version 0x333
arm-scmi arm-scmi.0.auto: SM Version = Build 819, Commit c450f539 Mar 10 2026
arm-scmi arm-scmi.0.auto: SM Config = mx95frdm-pro, mSel = 0
arm-scmi arm-scmi.0.auto: i.MX LMM: 3 Logical Machines
arm-scmi arm-scmi.0.auto: i.MX CPU: name: m33p / m7p / a55c0 … a55c5 / a55p
```

`i.MX LMM: 3 Logical Machines` 与配置里的 LM0/LM1/LM2 **完全对上**，`mSel = 0` 说明用的是第 0 套启动配置档位。

---

## 阶段衔接机制汇总

**这一张表就是"阶段之间到底靠什么衔接"的答案。**

| 从 → 到 | 衔接机制 | 具体形式 |
|---|---|---|
| 阶段 0 → 1 | **纯硬件** | 复位释放后 M33 从 Boot ROM 取指（无软件参与） |
| 阶段 1 → 2 | **搬代码 + 跳转** | 容器描述里写明 `load 0x1FFC0000, entry 0x1FFC0000`，Boot ROM 照做 |
| 阶段 2 → 3 | **函数调用** | `Reset_Handler` 末尾 `bl main` |
| 阶段 3 → 4 | **SM 内部循环** | 按 `boot[]` 顺序执行启动命令表 |
| 阶段 4 → 5 | **SM 继续执行下一条** | M7 段结束紧接 A55 段，M7 独立运行不再受管 |
| 阶段 5 → 6 | **搬代码 + 释放核** | SPL 早已由 Boot ROM 装到 `0x20480000`，SM 只放 CPU0 |
| 阶段 6 → 7 | **标准接口请求（PSCI）** | Linux 发 `CPU_ON` → BL31 → SCMI → SM 打开核 |
| 阶段 7 之后 | **标准接口请求（SCMI）** | 运行期所有资源管理都走 SCMI |

**规律**：越靠前的阶段越"硬"（硬件信号、固定地址），越靠后越"软"（标准接口）。**这解释了为什么启动早期的问题很难调**——那时候没有操作系统、没有日志、没有调试器，只有固定地址和复位行为。

---

## 顺序不能乱的地方（汇总）

> ⚠️ **先说明证据强度**：下面"顺序"本身是**源码/配置可以确认**的（`mx95frdm-pro.cfg` 的 `start=` 索引 + `LM_ProcessStart()` 的执行顺序）。但"为什么不能反"这一列，**源码里没有任何文字解释**——它是根据硬件常识和代码中的实际处理（`fsl_cpu.c` 里 `CPU_RUN_MODE_START` 分支明确先 `SRC_MixSoftPowerUp()` 再 `CPU_WaitSet(false)`）推出的**推理**，不是官方结论。**按 `推测` 对待。**

| 顺序 | 为什么不能反（**推理**） | 顺序本身的证据 |
|---|---|---|
| **先写 TRDC/RDC 隔离，再放任何其它核** | 反过来核会先用上即将被收走的资源，导致取指失败或状态不一致 | `arch.md` 有明确文字："loading their configuration **before starting any other cores**"（**官方**） |
| **先给电源域上电，再释放 CPU 复位** | 电源域没电时核取指会失败，行为不确定 | 配置 `PD_M7 start=1` / `CPU_M7P start=2`；代码 `fsl_cpu.c` 先 `SRC_MixSoftPowerUp()` 后 `CPU_WaitSet(false)` |
| **先建立电压，再切频率，最后放核** | 欠压状态下跑高频会不稳定甚至损坏 | 配置 `VOLT_ARM start=1` / `PD_A55P start=2` / `PERF_A55 start=3` / `CPU_A55C0 start=4` |
| **先武装看门狗，再做其它初始化** | 初始化卡死时需要硬件兜底复位；AON 时钟复位后立刻可用 | `startup_MIMX95_cm33.S` 里 WDOG 配置确实是 `Reset_Handler` 的最前面几条 |
| **SM 只放 CPU0，其余由 OS 用 PSCI 叫** | 多核的栈/同步/缓存由 OS 决定比 SM 更合适；这也是运行期能切核的前提 | `platform.mk` 的 `COLD_BOOT_SINGLE_CPU := 1` + 启动表只有 `CPU_A55C0`（**源码**） |

**"先给电压再放核"这条在源码里的确切表达**：`devices/MIMX95/drivers/fsl_cpu.c` 的 `CPU_RUN_MODE_START` 分支（**源码可以确认**）：

```c
case CPU_RUN_MODE_START:
    /* if CPU stopped, power up respective mix and release */
    if (curRunMode == CPU_RUN_MODE_STOP) {
        /* Make sure MIX of CPU is powered */
        (void) SRC_MixSoftPowerUp(s_cpuMgmtInfo[cpuIdx].srcMixIdx);
        ...
        /* Release CPUWAIT */
        rc = CPU_WaitSet(cpuIdx, false);
```

**注释原文就是 "Make sure MIX of CPU is powered" → "Release CPUWAIT"**——顺序在代码里是明确的，只是没有解释"违反会怎样"。

---

## 专题一：AON 常开域（Always-On）

前面反复说"AON M33 最先跑"，但**为什么需要这样一个域**、**它和普通电源域有什么区别**，值得单独讲清。

### 1. 先理解"电源域"这个概念

现代 SoC 的功耗管理不是"整块芯片开或关"，而是把芯片切成若干个**可以独立上下电的区域**，每个区域叫一个**电源域**（power domain）。

i.MX95 把这类区域叫 **MIX**（"混合域"，一个 MIX 里通常包含若干 IP 模块 + 它自己的总线/时钟门控）。Pro 板 SM 配置里出现的电源域（**源码可以确认**，`mx95frdm-pro.cfg`）：

```text
AONMIX          ← 常开域（本专题主角）
BBSMMIX         ← 电池后备域
WAKEUPMIX       DDRMIX         NOCMIX
NPUMIX          GPUMIX         VPUMIX
CAMERAMIX       DISPLAYMIX     NETCMIX      HSIOMIX
```

**为什么要切这么多域**：手机/汽车场景下，不用摄像头就把 CAMERAMIX 整个断电，不用 NPU 就把 NPUMIX 断电，省下的静态功耗很可观。**代价是"上电顺序"变成一个必须由软件精心安排的问题**——这正是 SM 存在的原因之一。

### 2. AON 的特殊之处：它在代码里就是"不可切换"

SM 源码里，每个电源域有一个 slice 索引和一个 flags 字段（`devices/MIMX95/drivers/fsl_power.c`，**源码可以确认**）：

```c
/* AON slice 的配置 */
.flags = 0U                       /* 不带"可切换"标志 */

/* 其它 mix 的配置 */
.flags = PWR_MIX_FLAG_SWITCHABLE  /* 可上下电 */
```

而它的定义处直接写了注释（`devices/MIMX95/sm/dev_sm_power.h:72`，**源码可以确认**）：

```c
#define DEV_SM_PD_AON  PWR_MIX_SLICE_IDX_AON  /*!< 1: Always-on domain */
```

> **"常开"不是一句口号，而是 `flags` 里少了 `PWR_MIX_FLAG_SWITCHABLE` 这一位。**
> 少了这一位，SM 的电源管理代码就不会（也不能）给它下电。这是"永远在线"在软件里的确切表达。

### 3. 为什么必须有一个常开域（自举问题）

这是一个**先有鸡还是先有蛋**的问题：

```text
谁来管理电源域？          → SM（跑在 M33 上）
M33 跑在哪个电源域？      → AON
AON 能不能被关掉？        → 不能
为什么不能？              → 关掉就没人能再打开它了
```

所以 AON 必须**复位后自己就通电、并且永远不断电**。它承担的是"**开机时第一个醒、关机时最后一个睡**"的角色。

这也解释了 `Reset_Handler` 为什么第一件事是武装看门狗（见阶段 2）：**看门狗用的是 AON 自己的时钟，复位后立刻可用，不依赖任何后续初始化**——它是在"系统还没起来"这段危险期里唯一的兜底机制。

### 4. AON 里到底有什么

`imx-sm/sm/doc/arch.md` 第 372–396 行给出了逐项列表（**官方资料明确说明**）：

| 模块 | 在 AON 的原因 |
|---|---|
| **M33P** | 执行 SM 本身——SM 必须最先跑，所以它所在的域必须最先有电 |
| **WDOG1 / WDOG2** | 监控 SM 的健康状况；必须比 SM 更早可用，否则兜不住底 |
| **ROMCP_M33** | ROM 控制器——Boot ROM 阶段的访问控制 |
| **ELE (MU0)** | 与 ELE 安全子系统的通信通道 |
| **FCCU** | Fault Collection and Control Unit，故障收集与控制单元 |
| **INTM / CMU / CRC** | 安全相关 IP（供 SAF 使用） |
| **ATU_A / AXBS_AON** | 内存翻译隔离、QoS 配置 |
| **BLK_CTRL_NS_AON / BLK_CTRL_S_AON** | AON 的非安全/安全杂项控制寄存器块 |
| **IOMUXC / IOMUX_GPR** | 引脚复用控制器——**引脚配置必须常开，否则断电后引脚状态丢失** |
| **GPIO1** | 仲裁共享访问 |
| **LPI2C1/2、LPUART1/2** | 早期调试与板级管理总线（实机上 SM 的日志就在 LPUART2/COM19） |
| **MU1–MU6、MSGINTR1** | 核间邮箱，SCMI 通信的物理载体 |
| **SYSCTR_CTL、TSTMR1** | 系统计数器与时间戳定时器 |
| **TRDC_A** | AON 自己的 TRDC 访问控制器 |

**能看出规律**：AON 里装的都是"**别的模块要正常工作，必须先由它工作**"的东西——管电源的、管复位的、管引脚的、管通信的、管故障的。

### 5. AON 的时钟从哪来

AON 域用的是**低功耗振荡器时钟（LPOCLK）**，频率 **32.768 kHz**，来自板上 **Y3 晶振**，供 `NVCC_BBSM` 块（`UM12527` §2.4，**官方资料明确说明**）。

**为什么是 32.768 kHz 而不是 24 MHz**：

- 32.768 kHz = 2¹⁵，**用 15 级二分频就能得到 1 Hz**，是做 RTC 的经典频率；
- 频率低意味着功耗低——AON 要在系统"关机"时长期维持，功耗是首要指标。

代价是**时间分辨率粗**（一个周期约 30.5 µs）。所以 SM 的看门狗超时设成 `1000 ms × 32768 = 32768` 个计数（见阶段 2 的 `TOVAL`）——**用慢时钟换低功耗，用大计数值换长时间**。

### 6. AON ≠ BBSM（一个常见的混淆）

| | AONMIX | BBSM |
|---|---|---|
| 供电 | 主电源轨 | **NVCC_BBSM_1P8**（单独，复位期间不断） |
| 复位时 | 保持 | 保持 |
| 断电（拔电源）时 | 丢 | **若接了后备电池则保留**（RTC 继续走） |
| 典型内容 | M33、看门狗、ROMCP、IOMUXC、MU、GPIO1 | BBNSM（RTC）、`BLK_CTRL_BBSMMIX` |

**两者都"复位不断电"，但"断电后能不能活"不一样**：AON 只在"复位"时保持，真正拔掉电源也会丢；BBSM 因为有独立供电引脚（可接后备电池），才是真正意义上的"断电也不丢时间"。**所以 RTC 放在 BBSM 而不是 AON。**

### 7. 和 STM32 的对比

| | STM32 | i.MX95 |
|---|---|---|
| 有没有常开域 | **有**，叫**后备域（backup domain）**，由 VBAT 引脚供电 | 有，叫 AONMIX（+ BBSM 负责电池后备部分） |
| 里面放什么 | RTC、备份寄存器（BKP）、LSE 32.768 kHz 晶振 | M33、看门狗、ROMCP、IOMUXC、MU、GPIO1… |
| 谁最先跑 | 用户代码（复位向量在 Flash） | **SM（在 AON M33 上）**——这才是本质差别 |
| 目的 | 掉电保时间、保少量数据 | **承担整个多核系统的启动与资源分配** |

**能类比的部分**：`VBAT`/后备域 ≈ AON 的"不断电"思路，32.768 kHz 晶振 ≈ Y3，RTC 放后备域 ≈ RTC 放 BBSM。
**不能类比的部分**：STM32 的后备域只是个"小仓库"，不承担启动职责；i.MX95 的 AON 里跑着**整个系统的管理者**。

### 8. 对本项目的意义

1. **"SM 起不来就全盘起不来"**——因为 SM 在 AON，而 AON 是最先通电的域。AON 之后的所有域都靠 SM 打开。
2. **看门狗复位会反复发生而不是死机**——AON 的 WDOG2 用独立时钟，SM 卡住 1 秒后硬件自己复位重来。项目里 COM19 反复刷同一行日志就是这个机制在起作用。
3. **引脚配置常开**——IOMUXC 在 AON，所以引脚复用状态不会因为某个业务域断电而丢失。这也是为什么 SM 能"替 Linux 配引脚"（Linux 经 SCMI 请求，SM 用 AON 里的 IOMUXC 写）。

---

## 专题二：ATF（ARM Trusted Firmware）与 BL 阶段

阶段 6 里 BL31 只占了表格一行，但它其实是一套完整的固件框架，值得单独讲。

### 1. ATF 是什么、为什么会有它

**ATF = ARM Trusted Firmware**，是 **ARM 官方提供的一套参考实现**（开源），作用是**在 ARMv8-A 平台上建立"可信启动链"和"安全运行环境"**。

**为什么需要它**：ARMv8-A 引入了 **异常级（Exception Level）** 机制：

```text
EL0  用户态        ← 应用程序
EL1  内核态        ← 操作系统内核
EL2  虚拟化态      ← hypervisor
EL3  安全监控态    ← 最高，管安全世界/非安全世界切换
```

**EL3 必须有东西占着**，因为：

- 安全世界（TrustZone）和非安全世界之间的切换只能从 EL3 发起；
- 有些操作（如启动一个 CPU 核、访问安全外设）**只有 EL3 有权做**；
- 如果 EL3 空着，操作系统就能自己提权，安全隔离就没了。

**ATF 就是"住在 EL3 的那段固件"**。它启动时占住 EL3，之后长期驻留，为下面的软件提供受控的服务。

### 2. BL 阶段编号是什么意思

ATF 把启动过程分成若干 **BL（Boot Loader）阶段**：

| 阶段 | 名称 | 跑在哪 | 在本项目里 |
|---|---|---|---|
| **BL1** | Boot ROM 阶段 | EL3 | ❌ **i.MX95 不用**（见下） |
| **BL2** | 可信固件加载阶段 | EL3 | ❌ **i.MX95 不用** |
| **BL31** | 运行时固件（Runtime Software） | **EL3** | ✅ **这就是我们说的"ATF"** |
| **BL32** | 安全 OS（Secure Payload） | EL1（安全世界） | ✅ OP-TEE（`tee.bin`，`0x8C000000`） |
| **BL33** | 非安全固件 | EL2/EL1 | ✅ U-Boot（`0x90200000`） |

**BL31 和 BL1/BL2 的关键区别**：BL1/BL2 是"用完就退场"的加载器；**BL31 是常驻的**——启动完成后它留在 EL3 继续服务，直到关机。

### 3. i.MX95 为什么不需要 BL1/BL2

ATF 的 `plat/imx/imx9/imx95/platform.mk` 里有（**源码可以确认**）：

```make
RESET_TO_BL31              := 1
PROGRAMMABLE_RESET_ADDRESS := 1
COLD_BOOT_SINGLE_CPU       := 1
```

`RESET_TO_BL31 := 1` 的含义是：**"复位后直接进 BL31"**，不需要 BL1/BL2 这两级。

**为什么可以省掉**：BL1/BL2 的职责是"从存储介质读入后续镜像并校验"。而在 i.MX95 上，**这件事已经由 Boot ROM + ELE 做完了**（见阶段 1）：

```text
Boot ROM 读容器 → ELE 做 AHAB 签名校验 → 按容器描述把 BL31 装到 0x8A200000
→ SPL 把控制权交给 BL31
```

**所以 i.MX95 的启动链是"Boot ROM 兼任了 BL1/BL2 的活"**。这也说明：**ATF 的 BL 编号是一套通用框架，具体到某个 SoC 用哪几级，要看平台实现**——不能看到"BL31"就以为前面一定有 BL1/BL2。

### 4. BL31 在 i.MX95 上具体做什么

`plat/imx/imx9/imx95/imx95_bl31_setup.c`（**源码可以确认**）：

| 函数 | 行号 | 动作 |
|---|---|---|
| `bl31_early_platform_setup2()` | 67–107 | 注册 LPUART 控制台；填充 `bl33_image_ep_info`（U-Boot 入口 = `0x90200000`）；若有 BL32（OP-TEE）则把基址/大小通过 arg1/arg2 传给 BL33 |
| `bl31_plat_arch_setup()` | 109–146 | **把 GPIO2~5 划给非安全世界**；建 MMU 表；`enable_mmu_el3(0)` |
| `bl31_platform_setup()` | 148–171 | `generic_delay_timer_init()` → GICv3 初始化 → `ele_get_soc_info()` → `plat_imx9_scmi_setup()`（建立 SCMI 通道） |
| `bl31_plat_get_next_image_ep_info()` | 173–182 | 返回下一级入口：`NON_SECURE` → BL33（U-Boot），`SECURE` → BL32（OP-TEE） |

**注意第 2 行**：`bl31_plat_arch_setup()` 会把 GPIO2 的按引脚安全属性写成全 1——**这就是项目里 M7 GPIO 读 0、写入无效的根因**。它不是 bug，是 BL31 按"GPIO2~5 归非安全世界"的设定正常执行。

### 5. BL31 交出去的是什么：EL3 保留、EL2 空出来

这是理解 Harpoon 的关键：

```text
BL31 自己占住 EL3（不交出）
把 BL33（U-Boot）放到 EL2
→ U-Boot 之后把 EL2 让出来（它启动 Linux 时降到 EL1）
→ EL2 空着
→ Jailhouse 加载时占住 EL2
→ Linux 在 EL1 运行，不知道 EL2 上有人
```

BL31 决定 BL33 异常级的代码（`imx95_bl31_setup.c:51-65`，**源码可以确认**）：

```c
el_status = read_id_aa64pfr0_el1() >> ID_AA64PFR0_EL2_SHIFT;
el_status &= ID_AA64PFR0_ELX_MASK;
mode = (el_status) ? MODE_EL2 : MODE_EL1;
```

即**先读 A55 的能力寄存器**，实现了 EL2 就用 EL2，否则退回 EL1。i.MX95 的 A55 实现了 EL2，所以 U-Boot 跑在 EL2。

> **Harpoon 能用，本质上是"ATF 把 EL2 空出来了"这个设计决定的。** 如果 BL31 把 U-Boot 直接放到 EL1，EL2 就没有"合法的入驻者"，hypervisor 也就无从谈起。

### 6. PSCI：BL31 提供的另一项核心服务

**PSCI = Power State Coordination Interface**，ARM 定义的标准接口，用来"叫醒/关闭/挂起一个 CPU 核"。

**为什么必须由 EL3 提供**：启动一个核要写电源域、时钟、复位寄存器，这些操作**不能交给操作系统随便做**（否则一个 OS 就能干扰另一个）。所以设计成：

```text
Linux 想启动 CPU1~5
  → 发 PSCI CPU_ON（SMC 指令，陷入 EL3）
  → BL31 处理
  → BL31 通过 SCMI 请求 SM 真正操作硬件
  → 核被叫醒
```

**注意这个"两段式"**：BL31 并不自己写核的复位寄存器，而是**转发给 SM**。因为资源归属由 SM 决定，BL31 只负责"从 EL3 这个特权位置接受请求并转交"。

具体实现在 `plat/imx/imx9/imx95/imx95_psci.c`，平台回调是 `imx_pwr_domain_on()`（535–562 行），细节见阶段 6 的衔接一节。

### 7. 和 STM32 的对比

| | STM32（Cortex-M） | i.MX95（Cortex-A） |
|---|---|---|
| 有没有异常级 | **没有**（M 系列只有特权/非特权之分） | 有 EL0–EL3 四级 |
| 有没有 TrustZone | M33 有 TrustZone-M（两个安全状态，但不是异常级） | 有 TrustZone-A，配合 EL3 做世界切换 |
| 有没有 ATF | **没有**——不需要 | **有**，BL31 常驻 EL3 |
| 谁启动其它核 | 通常不需要（单核）或多核由应用自己管 | **PSCI → BL31 → SCMI → SM**，四层转发 |
| 能不能跑 hypervisor | 不能（无 EL2、无 MMU） | 能（EL2 + MMU + stage-2 翻译） |

**一句话**：ATF 是"ARMv8-A 才有的东西"，它在 Cortex-M 上**没有对应物**。理解 ATF 的前提是先理解异常级——这也是为什么本笔记前面要单独讲 MMU/MPU 和异常级。

### 8. 对本项目的意义

1. **BL31 是"看不见但一直在跑"的一层**——U-Boot、Linux、hypervisor 都依赖它的服务（PSCI、SCMI 转发、安全世界切换）。
2. **GPIO2 权限问题的根因在 BL31**，不在 SM、不在 Linux。定位问题时要知道"这一层也会改硬件状态"。
3. **Harpoon 的 EL2 是 BL31 让出来的**——这条链决定了"在 A55 上跑 RTOS"这条路在 i.MX95 上成立。
4. **改 BL31 是高风险动作**：它常驻 EL3，出错的表现往往是"板子完全起不来"，且没有操作系统日志可看。

---

## 与 STM32 的对比（哪些能类比、哪些不能）

| 维度 | STM32（如 H7 双核） | i.MX95 | 能否直接类比 |
|---|---|---|---|
| 上电第一段代码 | 片内 Boot ROM（Cortex-M）→ 用户 Flash 复位向量 | 片内 Boot ROM，但**执行在 AON M33 上**，且管理的是整套多核系统 | ❌ 执行主体和职责范围都不同 |
| 电源时序 | 通常固定，软件不参与 | **由 PMIC 按序释放多路电压**，且有软件参与的电压/频率档位切换 | ❌ 不能类比 |
| 有没有"系统管理器" | 没有 | **有**（M33 上的 SM），管时钟/电源/复位/引脚/PMIC/权限 | ❌ i.MX95 独有 |
| 核之间关系 | 各自独立，靠共享内存/IPCC 通信 | 由 SM 建模成**逻辑机**，可被独立启动/复位/下电 | ❌ 权限模型完全不同 |
| 外设能不能随便用 | 能（除少数安全外设） | **不能**，要 SM 在配置里给 OWNER/ACCESS | ❌ |
| 权限载体 | MPU / 选项字节 | **TRDC/RDC + SM 配置**，由 SM 在其它核启动前写好 | ❌ |
| 复位后第一件事 | 用户代码的 Reset_Handler | **SM 的 Reset_Handler 先武装看门狗** | ⚠️ 形式相似，但 SM 的复位入口在 TCM 而非 Flash |
| "烧录"的含义 | 把程序写进片上 Flash | 写**启动容器**到 eMMC/SD/NOR，或经 USB 送入 RAM | ❌ 概念不同 |
| TCM 地址 | 单一地址空间 | **每个核看到的地址不同**（M33 ITCM：本地 `0x1FFC0000` / 系统 `0x201C0000`） | ❌ 别名概念是 MCU 没有的 |

### 一句话串起七个阶段

> **管家先上岗，把规矩定好，再叫醒干活的。**

AON M33 上的 SM 之所以必须先于 A55 运行，是因为**需要有个人先"分配资源"**。如果 A55 先跑，它会默认自己是主人，想用哪个外设就用哪个；等它把资源全占了再想收回来就晚了。所以设计成：**SM 先把隔离规则写进硬件（阶段 3），再按顺序放核（阶段 4、5）。**

**由此得到本节最重要的结论**：

> **资源隔离是 SM 在 Linux 起来之前就写进硬件的。**
> 隔离不是 Linux 做的，Linux 只是"被告知"结果。对应项目要求里的"资源隔离与权限分配"——**主体是 SM，不是操作系统**。

其余几点（为什么只放 CPU0、切核为什么可行、各环职责、启动模式引脚）已在上面各阶段中详述，此处不重复。

### 和 Harpoon 的关系（重要）

把上电流程和 Harpoon 连起来看，是一条线：

```text
上电 → SM 定规矩（写 TRDC/RDC 隔离）
     → Linux 起来（只拿到 SM 给的那部分）
     → Harpoon 在 SM 定的规矩之内，再切一次
```

> **Harpoon 不能违反 SM 定的规矩。**
> 它是"二房东"，但**房子是大房东（SM）先分好的**——二房东没法把大房东没给的房间租出去。
>
> 这就是 FRDM-IMX95-PRO 上 Harpoon 的 inmate 串口没输出的根源：
> **（EVK 的）SM 配置没把 LPUART3 分给 Linux 域，Harpoon 再怎么切也切不出一个不归它的串口。**

### 本节证据索引

按证据类型分组。**"官方资料明确说明"和"源码可以确认"是两回事**，前者是文档写的，后者是代码里读出来的。

**官方资料明确说明**

| 内容 | 出处 |
|---|---|
| 电源时序由 PF09 PMIC 内部处理，无需用户配置 | `UM12527` §2.2.1 |
| K1 复位经 PF09 FCCU1 触发冷复位；NVCC_BBSM_1P8 复位期间不断电 | `UM12527` Table 4 |
| Boot core 是 Cortex-M33；BOOT_MODE[3:0] 与启动设备对照表 | `UM12527` §2.3 Table 7 |
| RTC 晶振 Y3 = 32.768 kHz，供 NVCC_BBSM 块 | `UM12527` §2.4 |
| SM 是 boot core 上跑的第一段固件；它先配置隔离、再启动其它核 | `imx-sm/README.md` |
| i.MX9 的 AON M33 是 SCP；SM 独占 M33，不支持客户加负载 | `imx-sm/sm/doc/arch.md` |
| "loading their configuration **before starting any other cores**" | `imx-sm/sm/doc/arch.md` |
| `boot[]` / `bootSkip` / `rtime` / `start[]` 语义 | `imx-sm/sm/doc/config.md` 330–388 行 |

**源码可以确认**

| 内容 | 文件与位置 |
|---|---|
| M33 链接脚本：向量表 `0x1FFC0000`，入口 `Reset_Handler` | `tools/imx-sm/devices/MIMX95/gcc/MIMX95_cm33_ram.ld` |
| ROM 模拟脚本把 ROM 放在 `0x0` | `tools/imx-sm/devices/MIMX95/gcc/MIMX95_cm33_rom.ld` |
| `Reset_Handler` 逐条：武装 WDOG2 → 设 VTOR → 设 MSP → 清栈堆 → SystemInit → 搬 .data | `tools/imx-sm/devices/MIMX95/gcc/startup_MIMX95_cm33.S` 439 行起 |
| WDOG2 基址 `0x442E0000`、解锁键 `0xD928C520`、`WDOGCS=0x21E2` 的逐位含义 | 同上，426–470 行 |
| AON 外设基址：`AON__ROMCP1=0x44430000`、`AON__BLK_CTRL_S_AONMIX2=0x444F0000`、`AON__FCCU=0x44570000` | `SDK_26_06_00_IMX95LPD5EVK-19/devices/MIMX9596/MIMX9596_cm7_COMMON.h` |
| `WDOG2_BASE = 0x442E0000` | 同上 |
| M33 内存段：`M33_ROM 0x0–0x3FFFF`、`M33_TCM_CODE 0x201C0000+256K`、`M33_TCM_SYS 0x20200000+256K` | `imx-sm/configs/other/mx95frdm-pro.cfg` 325–327 行 |
| `WDOG1/WDOG2 OWNER` 归 LM0(SM)、`ROMCP_M33 OWNER` | 同上，281–282、263 行 |
| `boot[]` 实际取值：SM=1、M7=2、AP=3 | 生成的 `config_lmm.h`（`SM_LM0/1/2_CONFIG`） |
| 启动命令表 mSel=0 共 6 条：PD_M7 → CPU_M7P → VOLT_ARM → PD_A55P → PERF_A55 → CPU_A55C0 | 生成的 `config_lmm.h`（`SM_LM_START_DATA`） |
| **ROM → SM 的跳转代码**：`ldr r13,[0x1FFC0000]; ldr r1,[0x1FFC0004]; bx r1` | `tools/imx-sm/devices/MIMX95/gcc/rom_MIMX95_cm33.S` 332–336 行 |
| **Handover 结构**：地址 `0x2003DC00`、魔数 tag `0xC0FFEE16`；**Passover** 在 `0x2003DE00` | 同上，56–115 行 |
| SM 侧读回这两个结构：`DEV_SM_RomHandoverGet()` / `DEV_SM_RomPassoverGet()` / `DEV_SM_RomBootImgNGet()` | `tools/imx-sm-src/imx-sm-master/devices/MIMX95/sm/dev_sm_rom.c` 46–54、84–159、175 行起 |
| **AON 定义**：`DEV_SM_PD_AON = PWR_MIX_SLICE_IDX_AON /* Always-on domain */` | `devices/MIMX95/sm/dev_sm_power.h:72` |
| **AON "不可切换"的实现**：AON slice `.flags = 0U`，其它 mix 用 `PWR_MIX_FLAG_SWITCHABLE` | `devices/MIMX95/drivers/fsl_power.c:79-90`、`:107` |
| **AON 内含模块清单**（M33P/WDOG1-2/ROMCP/ELE/FCCU/IOMUXC/MU1-6/GPIO1…）；**BBNSM 归 BBSM 不归 AON** | `sm/doc/arch.md` 368–404 行 |
| SM `main()` 调用顺序：`SM_FUSEINIT` → `BRD_SM_Init` → `LMM_Init` → `LMM_Boot` → `LMM_PostBoot` → idle | `sm/boot/sm.c:87-231` |
| `DEV_SM_Init()` 顺序（含 `DEV_SM_RdcInit()` 在第 133 行） | `devices/MIMX95/sm/dev_sm.c:55-181` |
| LMM 启动命令枚举 `LMM_SS_PD/PERF/CLK/CPU/VOLT/RST/CTRL` | `sm/lmm/lmm_config.h:70-81` |
| `LM_ProcessStart()` **两趟执行**：第一趟先设 reset vector，第二趟才按命令分派 | `sm/lmm/lmm_sys.c:1108-1214` |
| **"释放 CPU 复位"的确切落点**：清 `BLK_CTRL_S_AONMIX->CA55_CPUWAIT` 的 `CPUn_WAIT` 位；M7 是 `M7_CFG` 的 `WAIT` 位 | `devices/MIMX95/drivers/fsl_cpu.c` 94–239、475–503、979–1045 行 |
| CPU 复位向量寄存器：A55 用 `CA55_RVBARADDRn_L/_H`；M7 用 `INITVTOR`；M33 用 `INITSVTOR` | 同上，94–239 行 |
| **TRDC 配置的落点**：`DEV_SM_RdcInit()` 经 `ELE_RdcRelease()` 向 ELE 申请所有权；`DEV_SM_RdcLoad()` 用 `CONFIG_Load()` **直接写 TRDC 寄存器** | `devices/MIMX95/sm/dev_sm_rdc.c:97-125`、`176-190` |
| TRDC 实例基址表（aon `0x44270000`、wakeup `0x42460000`、netc `0x4C840000`…） | 同上，80–92 行 |
| 电压切换经板级 PMIC：`BRD_SM_VoltageModeSet()` → PF09 GPIO4 使能 PF53 + 等待 1000 µs 斜坡 | `boards/mcimx95evk/sm/brd_sm_voltage.c:171-201` |
| **容器结构体**：`flash_header_v3_t` / `boot_img_t`（含 `dst`/`entry`/`hash`）/ `sig_blk_hdr_t`；i.MX9 v3 tag = `0x87` | `tools/imx-mkimage/src/imx8qxb0.c:112-153`、`:22-24` |
| 镜像数组参数：`IMG_ARRAY_ENTRY_SIZE 128`、`HEADER_IMG_ARRAY_OFFSET 0x10`、`MAX_NUM_IMGS 16` | 同上，19、37–38 行 |
| 逻辑核编号：`CORE_IMX95_M33P=0`、`CORE_IMX95_M7P=1`、`CORE_IMX95_A55C0=2`… | `tools/imx-mkimage/src/mkimage_common.h:139-147` |
| **各镜像装载地址的权威定义**：`MCU_TCM_ADDR=0x1FFC0000`（256KB TCM）、`MCU_TCM_ADDR_ACORE_VIEW=0x201C0000`、`M7_TCM_ADDR=0x0`、`M7_TCM_ADDR_ALIAS=0x303C0000`、`SPL_LOAD_ADDR_M33_VIEW=0x20480000`、`ATF_LOAD_ADDR=0x8A200000`、`UBOOT_LOAD_ADDR=0x90200000`、`TEE_LOAD_ADDR=0x8C000000` | `tools/imx-mkimage/iMX95/soc.mak:41-74` |
| ATF 编译开关：`RESET_TO_BL31 := 1`（不需 BL1/BL2）、`COLD_BOOT_SINGLE_CPU := 1` | `tools/imx-atf-source/plat/imx/imx9/imx95/platform.mk` |
| BL33 异常级由 `read_id_aa64pfr0_el1()` 决定 → A55 有 EL2，故 U-Boot 跑 EL2 | `plat/imx/imx9/imx95/imx95_bl31_setup.c:51-65` |
| BL31 三个 setup 函数的行为（含 `bl31_plat_arch_setup()` 把 GPIO2~5 划给非安全世界） | 同上，67–171 行 |
| PSCI 平台回调 `imx_pwr_domain_on()`、`boot_stage[6]={false,true×5}`、入口校验 | `plat/imx/imx9/imx95/imx95_psci.c:121`、`493-501`、`535-562` |
| SCMI over MU：`IMX9_MU1_BASE=0x44220000`、`IMX9_SCMI_PAYLOAD_BASE=0x44221000` | `plat/imx/imx9/imx95/include/platform_def.h:83-87` |
| `SCMI_CPU_VEC_FLAGS_BOOT=BIT(30)` / `RESUME=BIT(31)` | `drivers/arm/css/scmi/vendor/scmi_imx9.h:125-126` |
| U-Boot 侧 `ft_board_setup()` 解析 `jh_root_mem` 并改写设备树 `/memory` | `tools/uboot-imx-source/board/freescale/imx95_frdm/imx95_frdm.c:502-540`；EVK 版在 `imx95_evk.c:398-437` |

**实机验证得到**

| 内容 | 证据 |
|---|---|
| 容器解析报告：各镜像的 load/entry 地址与大小 | `build/pro-gpio/flash-m7-gpio.parse.txt` |
| A55 链日志：SPL → BL31 → U-Boot → Linux 逐行对应 | `build/logs/`（COM17） |
| DDR 在 SM 阶段就绪（U-Boot 报 `DRAM: 15.8 GiB`） | 同上 |
| SM 在最早阶段输出 DDR OEI 与 `Hello from SM` | `build/logs/`（COM19） |
| SM 版本 `Build 819`、`i.MX LMM: 3 Logical Machines`、`mSel = 0` | Linux dmesg |

**待验证 / 推测**

- `待验证`：Boot ROM 内部第一阶段的确切步骤与第一条指令地址（属 NXP 掩膜 ROM 实现，公开资料不给出）
- `待验证`：OEI 入口 `0x1FFC0001` 与 SM 入口 `0x1FFC0000` 最低位差异的确切含义（前者带 Thumb 位特征，后者不带；容器解析报告如此，但未见官方说明）
- `待验证`：`A55C1..C5` 在启动表中的 `stop=7..2` 与 PSCI `CPU_ON` 的对应关系（需读 ATF `imx95_psci.c` 与 SM CPU 协议源码）

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

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|i.MX95时钟-IOMUX与板级串口选择方法]]
- [[20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md|i.MX95引脚控制-IOMUXC与RGPIO分工]]
- [[20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md|i.MX95在A55上运行FreeRTOS的路径]]

**相关主题**

- [[20-领域/芯片与平台-i.MX95/启动与烧录/i.MX95官方启动配置与ELE文件.md|i.MX95官方启动配置与ELE文件]]
- [[20-领域/芯片与平台-i.MX95/启动与烧录/STM32与i.MX95启动和开发流程对比.md|STM32与i.MX95启动和开发流程对比]]
