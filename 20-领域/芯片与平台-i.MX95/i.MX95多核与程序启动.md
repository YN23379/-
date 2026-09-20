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

| 项目     | Cortex-A55         | Cortex-M7         | Cortex-M33     |
| ------ | ------------------ | ----------------- | -------------- |
| 主要用途   | 应用处理和 Linux        | 高性能实时控制           | 安全、低功耗和系统管理类任务 |
| 架构     | Armv8-A 系列         | Armv7E-M          | Armv8-M        |
| 位宽     | 支持 64 位 AArch64    | 32 位 Thumb 指令集    | 32 位 Thumb 指令集 |
| 当前板上数量 | 6 个                | 1 个               | 1 个            |
| 当前已知频率 | 启动日志显示 1.8 GHz     | 官方资料标明最高 800 MHz  | 以芯片资料和实际时钟配置为准 |
| 内存管理   | MMU                | MPU               | MPU            |
| 虚拟内存   | 支持                 | 不提供完整虚拟内存         | 不提供完整虚拟内存      |
| 操作系统   | 适合 Linux 等复杂系统     | 适合裸机或 FreeRTOS    | 适合裸机或 RTOS     |
| 实时性    | 吞吐量高，但时延较复杂        | 中断快，可使用 TCM，实时性较好 | 强调低功耗、安全和可控响应  |
| 安全特性   | 支持异常级和 TrustZone-A | 以高性能实时处理为主        | 支持 TrustZone-M |

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

前面几节讲的是"有哪些核、各自适合干什么"。这一节讲**上电之后这些核按什么顺序醒、每一步到底做了什么、上一步怎么把控制权交给下一步**。

> **本篇依据**：`imx-sm` 官方源码与文档（`sm/doc/intro.md`、`arch.md`、`imp.md`、`config.md`，
> `devices/MIMX95/sm/dev_sm_rom.c`，`sm/lmm/lmm.c`）。凡标 `源码确认` 的都能在源码里找到对应行。

### 0. 先把生词解释清楚

这一节会反复出现几个词，先说清楚**英文全称、在哪一层、干什么**：

| 词 | 英文全称 | 是什么 | 在哪一层 |
|---|---|---|---|
| **AON** | **Always-On**（常开域） | SoC 里**一直有电**的那部分。主电源断了它还在（靠备份电池/低功耗电源），所以能负责"叫醒整个系统"这类活 | 电源域（芯片内部的供电分区） |
| **AON MIX** | Always-On MIX | AON 电源域里的模块集合。SM 用到的外设**绝大多数都在这个域**（见下面第三节的表） | 电源域 |
| **SCP** | **System Control Processor**（系统控制处理器） | **承担系统管理职责的那个核**的统称。官方原文："`SCP - System Control Processor. For example, the AON Cortex-M33 in i.MX9.`" | 一个核 |
| **SM** | **System Manager**（系统管理器） | **跑在 SCP 上的那套软件**。i.MX9 上就是跑在 AON M33 里的固件 | 软件 |
| **M33P** | Cortex-M33 Processor | i.MX95 里那个 AON 域的 M33 核。**SM 独占它**，不允许客户往里加任务 | 一个核 |
| **Boot ROM** | 引导 ROM | **芯片出厂固化在片内 ROM 里的一段代码**，不可改。上电后第一个执行的东西 | 片内 ROM |
| **ELE** | **EdgeLock Enclave**（边缘安全飞地） | i.MX9 的**安全子系统**（一个独立的安全核 + 固件）。负责密钥、签名验证、TRDC 配置下发 | 独立安全核 |
| **LM** | **Logical Machine**（逻辑机） | 把一组核 + 内存 + 外设打成一个包，**看起来像一颗独立 SoC**，可以独立启动/复位/关机 | 逻辑划分 |
| **LMM** | **LM Manager**（逻辑机管理器） | SM 里**负责启动这些 LM 的组件** | 软件模块 |
| **TRDC / RDC** | Trusted Resource Domain Controller / Resource Domain Controller | **硬件级资源归属与访问控制**。TRDC 管外设/内存归属哪个域，RDC 管外设归属 | 硬件 IP |
| **mSel** | mode Select | **启动模式档位**。同一份 SM 配置可以有多套启动表，用 mSel 选第几套 | 配置参数 |
| **TCM** | Tightly Coupled Memory | 紧耦合内存，直接贴着核，延迟低。SM 的代码和数据都在 AON M33 的 TCM 里 | 片上内存 |

> **一句话理解 SCP 和 SM 的区别**：**SCP 是"岗位"，SM 是"干这个岗位的人"。**
> i.MX95 上这个岗位由 AON M33 担任，SM 就是跑在它上面的固件。

### 1. 七个阶段的完整链条

```text
① POR 上电复位（纯硬件）
   ↓
② Boot ROM 执行（片内 ROM 固化代码）
   ↓
③ Boot ROM 把 SM 镜像装进 AON 的 TCM，释放 M33P
   ↓
④ SM 启动：读 handover → 初始化板级与器件 → 配置 TRDC/RDC 隔离
   ↓
⑤ LMM_Boot()：按 boot[] 表逐个拉起 LM（M7、A55 集群）
   ↓
⑥ A55 的 CPU0 起来 → ATF(BL31) → U-Boot → Linux
   ↓
⑦ Linux 用 PSCI 叫醒 CPU1~5，6 个核全在线
```

下面逐阶段展开。

---

### ① POR 上电复位：纯硬件，没有软件参与

**"POR" = Power-On Reset（上电复位）**。

**这一步完全是硬件行为**，没有任何代码执行。发生的事情：

```text
电源稳定
   ↓ 电源管理芯片（PMIC）拉高各路电压，等 PLL/时钟稳定
   ↓ 复位控制模块（SRC，System Reset Controller）释放复位信号
   ↓ 各核的 PC（程序计数器）被硬件强制设为"复位向量地址"
   ↓ 只有 Boot ROM 所在的核开始取指
```

**关键点**：

- **复位不是"从 0 地址开始执行"这么简单**。i.MX95 的复位向量地址是**芯片设计时固定的**，
  由硬件决定，软件改不了。
- **上电瞬间所有核都被复位**，但**不是所有核都立刻跑**。Boot ROM 只会让**主核**开始执行，
  其余核停在复位状态等指令。
- **为什么必须这样**：如果 6 个 A55 + M7 + M33 一起抢总线，系统直接乱掉。
  **必须有个"主"先跑，由它来决定别人的命运。**

**和 STM32 的对比**：

| | STM32 | i.MX95 |
|---|---|---|
| 复位后从哪执行 | Flash 里的复位向量（`0x08000000`） | **片内 Boot ROM**（用户改不了） |
| 有几个核 | 通常 1 个 | **多个**，需要"谁先跑"的机制 |
| 用户能不能改第一段代码 | 能（自己写 `Reset_Handler`） | **不能**（Boot ROM 固化） |

> **这是从单片机转到应用处理器最大的认知转变**：
> 单片机上电第一条指令是**你写的**；i.MX95 上电第一条指令是**芯片厂商写死在 ROM 里的**。

---

### ② Boot ROM：在哪、是什么、干了什么

**"Boot ROM" 是芯片内部一块只读存储器**，出厂时烧好了引导代码。特点：

| 特性 | 说明 |
|---|---|
| 位置 | **片内**（不是外部 Flash），地址由芯片设计固定 |
| 能否修改 | **不能**。烧死在硅片里 |
| 大小 | 通常几十 KB 级别 |
| 谁写的 | 芯片厂商（NXP） |
| 代码质量 | 经过严格验证，是"信任根"的起点 |

**Boot ROM 做的主要事情**（顺序）：

```text
1. 读启动模式引脚（SW7 拨码）→ 决定从哪个设备启动
2. 初始化最基本的硬件：时钟、引脚、启动介质控制器
3. 找到启动容器（boot container，就是一个打包好的镜像文件）
4. ★ 交给 ELE 验证签名（安全启动）—— 验证不过就停住
5. 把容器里的各个镜像分别装到它们该去的地方
6. 释放对应的核，让它们从各自的入口开始跑
```

**关键：Boot ROM 是"分发者"，不是"执行者"。**

它自己不跑操作系统，只负责**把镜像搬到正确的位置，然后把各个核放出去**。
官方源码里对应的是 `DEV_SM_RomBootImgNGet()` 这类函数——**从 ROM 的记录里读出
"第 N 个镜像该给哪个核、装到哪个地址、mSel 是多少"**。

**启动介质的选择**（`UM12527` §2.3，Pro 板用 SW4；**EVK 用 SW7**）：

| SW4[1:4]（Pro）/ SW7[1-4]（EVK） | 模式 |
|---|---|
| `x001` | USB Serial Downloader（配合 UUU 用） |
| `x010` | eMMC |
| `x011` | microSD |
| `x100` | FlexSPI NOR |

---

### ③ Boot ROM → M33：怎么交接的

**这一步是"从 Boot ROM 过渡到 SM"的关键，也是最容易讲不清楚的地方。**

#### 硬件上怎么做

Boot ROM 做两件事：

```text
1. 把 SM 的镜像（sm.bin）**搬进 AON M33 的 TCM**
   —— TCM 是紧耦合内存，直接贴着核，延迟低
2. 让 M33P 退出复位，它的 PC 指向镜像入口
   —— 从此 M33 开始执行 SM 的代码
```

#### 数据上怎么传递：handover 结构

**Boot ROM 不只搬代码，还留了一张"交接单"**——这就是源码里的 **handover** 机制。

官方源码 `devices/MIMX95/sm/dev_sm_rom.c` 里的定义（`源码确认`）：

```c
#define HANDOVER_BASE    0x2003DC00U    // 交接单放在这个地址
#define HANDOVER_BARKER  0xC0FFEE16U    // 魔数，用来确认"这确实是交接单"
#define HANDOVER_VER     0x2U
#define HANDOVER_SIZE    0x100U

#define PASSOVER_BASE    0x2003DE00U    // 另一张：passover
#define PASSOVER_TAG     0x504FU
#define PASSOVER_SIZE    0x80U
```

**这两个结构的分工**：

| 结构 | 方向 | 内容 | 地址 |
|---|---|---|---|
| **handover** | ROM → SM | "我把哪些镜像装到了哪里、给哪个核、mSel 是几" | `0x2003DC00` |
| **passover** | ROM ↔ SM | 需要**跨复位保留**的信息（如复位原因） | `0x2003DE00` |

**SM 启动后第一件事就是去读这个地址**（官方源码 `DEV_SM_RomHandoverGet()`）：

```c
const rom_handover_t *ptr = (const rom_handover_t *) HANDOVER_BASE;

/* 先验证魔数 —— 确认这块内存里放的确实是交接单 */
if (ptr->barker != HANDOVER_BARKER)   return SM_ERR_NOT_SUPPORTED;
/* 再验证版本和大小 */
if (ptr->ver  != HANDOVER_VER)        return SM_ERR_NOT_SUPPORTED;
if (ptr->size < sizeof(rom_handover_t)) return SM_ERR_NOT_SUPPORTED;
```

**为什么要验证魔数**：这块内存**物理上就是普通 RAM**，如果 ROM 没写过它，
里面可能是上次运行的残留数据。**用魔数确认"这确实是 ROM 留下的，不是垃圾"**，
这是一个很典型的"跨阶段数据传递"做法。

**镜像记录怎么编码**（同样来自源码）：

```c
#define ROM_HANDOVER_IMG_CPU(x)    (((x) & 0x00FFU) >> 0)        // 低 8 位：哪个核
#define ROM_HANDOVER_IMG_TYPE(x)   (((x) & 0xFF00U) >> 8)        // 次 8 位：镜像类型
#define ROM_HANDOVER_IMG_MSEL(x)   (((x) & 0x00FF0000U) >> 16)   // 再 8 位：mSel
#define ROM_HANDOVER_IMG_FLAGS(x)  (((x) & 0xFF000000U) >> 24)   // 高 8 位：标志
```

**一个 32 位整数里塞了四个字段**——核 ID、镜像类型、mSel、标志。
SM 靠它知道"**ROM 给我留了哪些镜像、都在哪个核的手上**"。

> **这就回答了"阶段之间怎么衔接"**：
> **硬件上靠"搬代码 + 释放核"，数据上靠"在固定地址留一个带魔数的结构"。**
> 没有魔法，就是约定好地址和格式。

---

### ④ SM 启动：从 main() 到"隔离配置完成"

M33 跑起来后，执行 SM 的 `main()`。官方文档 `sm/doc/imp.md` 给了完整流程（`源码确认`）：

```c
main()
 ├─ BRD_SM_Init()                     // 板级初始化
 │   ├─ BOARD_InitHardware()          // 板子硬件初始化
 │   ├─ BRD_SM_SerialDevicesInit()    // 板级串口（调试输出用）
 │   ├─ DEV_SM_RomBootCpuGet()        // ★ 从 handover 读 mSel
 │   └─ DEV_SM_Init()                 // 器件（SoC）级初始化
 ├─ 打印 "Hello from SM"              // ★ 你在实机看到的那句
 ├─ LMM_Init()                        // 初始化逻辑机管理器
 │   ├─ LMM_ClockInit() 等各组件初始化
 │   └─ RPC_SCMI_Init()               // 为每个 LM 建 RPC 接口
 ├─ LMM_Boot()                        // ★ 开始启动各个 LM
 ├─ TEST_Config() / TEST()            // 单元测试（正常启动不走）
 ├─ MONITOR_Cmd()                     // 调试监视器（看到 SM Debug Monitor 就是它）
 └─ 死循环 WFI                        // 进入低功耗等待
```

**"Hello from SM" 出现在这里**——这就是本项目在 COM19 上看到的那句。
它证明 SM 已经跑到了 `BRD_SM_Init()` 之后。

#### SM 此时要做的核心事情：配隔离

官方文档 `arch.md` 说得很明确，SM 的第一职责是：

> **`Isolate execution of different cores to prevent interference` —— 隔离不同核的执行，防止互相干扰。
> 这包括在启动任何其他核之前，独占 RDC 并加载它们的配置。**

**顺序很重要**：

```text
先配好隔离（TRDC/RDC）
   ↓ 再启动别的核
```

**为什么不能反过来**：其他核一旦跑起来就会去访问外设。**如果隔离还没配好，
它们就能碰到不该碰的东西**——那就失去了隔离的意义。

#### SM 独占的硬件（谁也拿不到）

官方文档 `arch.md` 列了一张表，**这些 IP 是 SM 独占的，其他核访问不到**（节选）：

| IP 模块 | 所在 MIX | 用途 |
|---|---|---|
| **M33P** | AON | 执行 SM 应用本身 |
| LPUART1/2 | AON | 调试输出 |
| **LPI2C1/2** | AON | 跟 PMIC 通信 |
| **IOMUXC** | AON | **仲裁引脚的共享访问** |
| **GPIO1** | AON | 仲裁 GPIO 共享访问 |
| **WDOG1/2** | AON | 监视 SM 自己的健康 |
| **MU1-6** | AON | **给各客户端提供通信通道** |
| **TRDC_A / TRDC_M / TRDC_W 等** | 各 MIX | **配置硬件隔离**（经 ELE 下发） |
| **ELE (MU0)** | AON | 跟 ELE 通信 |
| CCM / GPC / SRC | CCMSRCGPC | 时钟 / 电源 / 复位管理 |

> **这张表解释了很多"为什么"**：
>
> - **为什么 `pinmux-pins` 里看不到某些引脚**？因为 **IOMUXC 归 SM 独占**，
>   Linux 只能通过 SCMI **请 SM 代配**——这就印证了本项目的实测现象。
> - **为什么 LPUART3 切不出来**？因为引脚的分配权在 SM 手里（`IOMUXC` 是 SM 独占的）。
> - **为什么 MPUART1/2 是 SM 的调试口**？它们也在 AON，归 SM。

#### 关于 DDR

官方文档另一句关键的话（`源码确认`）：

> **`All the IP in the DRCMIX is owned by the SM. The DDR controller, phy (inc. FW load),
> and PLL are initially configured by a DDR initialization firmware called by the M33 ROM.`**

**翻译**：DDR 控制器/PHY/PLL 最初是**由 M33 ROM 调用一段 DDR 初始化固件**配好的。
这解释了为什么第一次上电时 **COM19 会先打印一堆 DDR OEI 信息**——那是 DDR 初始化阶段，
**比 SM 的 "Hello from SM" 更早**。

---

### ⑤ LMM_Boot()：按表逐个拉起各个 LM

SM 初始化完成后调用 `LMM_Boot()`。**这段代码很短，但机制很关键**（`源码确认`，`sm/lmm/lmm.c:143`）：

```c
int32_t LMM_Boot(void)
{
    ...
    /* 取得起始时间戳 */
    uint64_t startTime = DEV_SM_Usec64Get();

    /* 外层循环：按"启动顺序号"从 1 到 LM 总数 */
    for (uint8_t bootOrder = 1U; bootOrder <= SM_NUM_LM; bootOrder++) {
        /* 内层循环：遍历所有 LM */
        for (uint32_t lmId = 0U; lmId < SM_NUM_LM; lmId++) {

            /* 这个 LM 的启动顺序 == 当前轮次？ */
            if (g_lmmConfig[lmId].boot[mSel] == bootOrder) {

                /* 算出这个 LM 该在什么时刻启动（支持延时） */
                uint64_t bootTime = startTime + g_lmmConfig[lmId].rtime;
                while (DEV_SM_Usec64Get() < bootTime) { ; }   /* 等到时间 */

                s_bootLm   = lmId;
                s_bootSkip = g_lmmConfig[lmId].bootSkip[mSel];
                SWI_Trigger();          /* ★ 触发软中断，实际启动在中断里做 */
                status = s_bootStatus;
            }
        }
    }
}
```

**三个要点**：

**① 启动表长什么样**（`sm/doc/config.md`，`源码确认`）：

| 字段 | 含义 |
|---|---|
| `boot[]` | **每个 mSel 一套**的启动顺序：`0` = 不启动，`1/2/3...` = 第几个启动 |
| `bootSkip[]` | 没有镜像时是否忽略错误：`0` = 报错停住（默认），`1` = 跳过继续 |
| `rtime` | **延时多少微秒再启动**（相对启动循环开始，最大 178 秒） |

**为什么要有 `rtime`**——官方给的理由很实际：

> 在汽车场景里，跑 CAN 协议的 M7 设 `rtime = 0`，AP（A55）设 `rtime = 50000`（50ms）。
> **这样 AP 启动就不会去跟实时核抢资源**，让实时核先起来把该配的都配好。

**② 实际配置长什么样**（本项目板级配置，`源码确认`）：

看 `mx95evkjailhouse.cfg` 和 `mx95frdm-pro.cfg`，三个 LM 的启动顺序是：

```text
LM0  name="SM",  boot=1, did=2, safe=feenv     ← SM 自己，第一个（boot=1）
LM1  name="M7",  boot=2, skip=1, did=4, safe=seenv    ← M7，第二个
LM2  name="AP",  boot=3, skip=1, did=3, default       ← A55 集群，第三个
```

**这就把"先 M7 后 A55"落到了配置上**——不是设计者拍脑袋，是配置表里写死的顺序。

注意 `skip=1`：说明 **M7 或 A55 没有镜像时不报错，继续往下走**。
所以你可以只烧 Linux 不烧 M7，系统照样起来。

**③ 为什么用软中断（SWI）而不是直接调用**

`SWI_Trigger()` 触发一个**软件中断**，真正的启动动作在中断处理函数 `LMM_Handler()` 里做。

**这么做的好处**：启动一个核涉及**电源域上电、时钟使能、复位释放**一整套操作，
放在中断上下文里执行，**语义上更清晰、也便于处理错误和超时**。
（实际启动会走到 `LMM_SystemLmBoot()` → `LMM_DoBoot()`。）

#### A55 是怎么被"放出来"的

看配置里 AP 这个 LM 的 start/stop 表（`源码确认`）：

```text
VOLT_ARM     msel=1, start=1|1, stop=9    ← 先给 ARM 电压域上电
PD_A55P      msel=1, start=2,   stop=8    ← 再给 A55 平台电源域上电
PD_A55C0     msel=1, stop=7               ← 各核电源域（stop 时才动）
PD_A55C1     msel=1, stop=6
...
PERF_A55     msel=1, start=3|3            ← 设置性能档位（频率）
CPU_A55C0    msel=1, start=4              ← ★ 只启动 CPU0！
CPU_A55P     msel=1, stop=1
```

**注意 `start` 的编号是顺序执行的**：`VOLT_ARM`(1) → `PD_A55P`(2) → `PERF_A55`(3) → `CPU_A55C0`(4)。

**顺序不能乱**：**先给电压，再上电，再设频率，最后才放核**。
如果先放核再给电，核会在没电的状态下取指 → 直接跑飞。

**★ 关键：只有 `CPU_A55C0` 有 `start`，其他 C1~C5 只有 `stop`**——
**这就是"SM 只放 CPU0 出去"在配置里的体现**。

---

### ⑥ A55 CPU0 起来 → ATF → U-Boot → Linux

CPU0 被释放后，从它的入口地址开始执行。**这段是 ARM 标准启动链**：

```text
CPU0 复位
   ↓
ATF / BL31（跑在 EL3）
   - 建立安全监控环境
   - 初始化 PSCI 服务（★ 后面叫醒其他核要用）
   - 把控制权交到 EL2/EL1
   ↓
U-Boot（跑在 EL2 或 EL1）
   - 初始化 DDR、外设
   - 从存储加载内核镜像和设备树
   - 准备好启动参数（bootargs）
   - 跳转到内核
   ↓
Linux 内核
   - 解压、初始化内存管理、驱动
   - 挂载根文件系统
   - 启动 init / systemd
```

> **注意 U-Boot 也会做一些"板级初始化"**，这和 SM 的初始化不冲突：
> **SM 管的是"谁能用"，U-Boot 管的是"怎么用"。**

---

### ⑦ Linux 叫醒 CPU1~5

**Linux 自己不会去写 A55 的复位寄存器**（那些归 SM 管）。它通过标准接口请求：

```text
Linux 内核
   ↓ PSCI（Power State Coordination Interface）调用
ATF / BL31（EL3，PSCI 的实现者）
   ↓ 转发给 SM（通过 SCMI 协议，走 MU 邮箱）
SM 的 LMM
   ↓ 执行 PD_A55Cn 上电 + CPU_A55Cn 释放
CPU1~5 逐个上线
```

**PSCI 是 ARM 定义的标准接口**，作用是"**让操作系统用标准方式管理 CPU 上电/下电/复位**"，
不用关心具体芯片怎么实现。

**这一环为什么对 Harpoon 重要**：

> **CPU1~5 是"运行期"才被叫醒的，不是启动时就放出来的。**
> 这意味着 hypervisor **完全可以在运行期对某个核做手脚**——
> 比如把 CPU5 从 Linux 手里拿走给 FreeRTOS。
>
> 如果 6 个核在启动时就被 SM 一次性全放出来，Linux 一上来就全占了，
> **再想切就难得多**。

---

### 一张图：完整的交接链

```text
POR（硬件复位）
  │  硬件行为：设 PC 到复位向量、释放复位
  ▼
Boot ROM（片内固化）
  │  ① 读 SW7 决定启动介质
  │  ② 找启动容器、交 ELE 验签
  │  ③ 把 SM 镜像搬进 AON TCM
  │  ④ 在 0x2003DC00 写 handover 结构（魔数 0xC0FFEE16）
  │  ⑤ 释放 M33P
  ▼
SM（跑在 AON M33）/ main()
  │  ① 读 handover（验魔数）→ 拿到 mSel 和各镜像信息
  │  ② 板级初始化，打印 "Hello from SM"
  │  ③ ★ 配置 TRDC/RDC —— 把隔离规则写进硬件
  │  ④ LMM_Init()：建 RPC 接口（SCMI）
  │  ⑤ LMM_Boot()：按 boot[] 表依次启动
  │       LM1 M7    (boot=2)  ← 放核
  │       LM2 AP    (boot=3)  ← 只放 CPU_A55C0
  │  ⑥ 进 WFI 死循环，转为"服务者"角色：等各核发 SCMI 请求
  ▼
A55 CPU0
  │  ATF/BL31 (EL3) → U-Boot → Linux
  ▼
Linux
  │  PSCI → ATF → SCMI → SM
  │  逐个叫醒 CPU1~5
  ▼
6 核全在线
  │
  ▼
（Harpoon）在 SM 定的规矩内，再从 Linux 手里切一个核给 FreeRTOS
```

### 三个必须理解的点

#### 1. 为什么是 AON M33 先跑，而不是 A55

**因为需要有个人先"分配资源"，而且这个人必须"一直在"。**

如果 A55 先跑，它会默认自己是主人，想用哪个外设就用哪个。等它把资源全占了，再想收回来就晚了。

**选 AON 域的 M33 还有第二个原因**：AON 是**常开域**，主电源断了它还有电。
这样系统休眠时 SM 还在跑，**能负责"被事件唤醒"**——如果 SM 在 A55 上，A55 一睡 SM 就没了。

**这解释了一件重要的事**：**资源隔离是在 Linux 起来之前就写进硬件的。**

> 隔离不是 Linux 做的，是 **SM 做的**。Linux 只是"被告知"结果。
> 对应项目要求里的"资源隔离与权限分配"——**主体是 SM，不是操作系统**。

#### 2. 为什么 A55 只启动 CPU0

```text
A55 集群（6 个核）
   CPU0   ← SM 只释放这一个（配置里只有 CPU_A55C0 有 start）
   CPU1~5 ← 暂时停着，等着被 PSCI 叫醒
```

**因为多核启动比单核复杂得多**：谁当主核、栈放哪、核间怎么同步、缓存怎么维护，这些 **Linux 自己比 SM 更清楚**。

所以约定：**SM 只放 CPU0 出去，剩下的由 Linux 用 PSCI 接口（经 ATF 转发、走 SCMI 到 SM）按需叫醒。**

**这也解释了为什么"切核"是可行的**：CPU1~5 本来就是 Linux 后来叫醒的，属于"运行期资源"。

#### 3. 阶段之间靠什么衔接

这是最容易被略过、但最该讲清的一点。**看完整条链，衔接只有三种方式**：

| 衔接方式 | 用在哪 | 具体做法 |
|---|---|---|
| **硬件释放 + 入口地址** | 每个"换核执行"的地方 | 上一个阶段把下一个阶段的代码放到约定地址，然后释放那个核 |
| **固定地址 + 魔数结构** | ROM → SM | `0x2003DC00` 的 handover（魔数 `0xC0FFEE16`）、`0x2003DE00` 的 passover |
| **标准化接口** | Linux → SM | PSCI（ARM 定义）→ SCMI（ARM 定义）→ MU 邮箱（硬件） |

**没有魔法**。所谓"阶段过渡"，本质就是这三件事：
**把代码放对位置、把该传的数据放对地址、用标准接口请求下一件事**。

### 启动模式拨码

Boot ROM 靠**读引脚电平**决定从哪启动。**两块板的拨码位置不同**：

| 板子 | 启动模式开关 |
|---|---|
| FRDM-IMX95-PRO | **SW4**[1:4]（`UM12527` §2.3） |
| **i.MX95 EVK** | **SW7**[1-4]（`UM12022` Table 55 / QSG） |

| 拨码 | 模式 |
|---|---|
| `x001` | USB Serial Downloader（配合 UUU 用） |
| `x010` | **eMMC（默认）** |
| `x011` | microSD / uSDHC2 |
| `x100` | FlexSPI NOR |

**注意 `x` 是最低位无关**，看后三位。**另外 EVK 的 `SW4` 是电源开关，不是启动开关**，别搞混。

### 和 Harpoon 的关系（重要）

把上电流程和 Harpoon 连起来看，是一条线：

```text
上电 → Boot ROM 放 SM → SM 配 TRDC/RDC 定规矩
     → SM 只放 CPU0 → Linux 起来（只拿到 SM 给的那部分）
     → Linux 用 PSCI 叫醒 CPU1~5
     → Harpoon 在 SM 定的规矩之内，再从 Linux 手里切一个核
```

> **Harpoon 不能违反 SM 定的规矩。**
> 它是"二房东"，但**房子是大房东（SM）先分好的**——二房东没法把大房东没给的房间租出去。
>
> 这就是 FRDM-IMX95-PRO 上 Harpoon 的 inmate 串口没输出的根源：
> **（EVK 的）SM 配置没把 LPUART3 分给 Linux 域，Harpoon 再怎么切也切不出一个不归它的串口。**
>
> 而且从第三节的表能看到，**`IOMUXC` 本身就是 SM 独占的**——
> Linux 连"自己配引脚"这件事都做不到，必须经 SCMI 请 SM 代配。

### 依据

| 结论 | 等级 | 出处 |
|---|---|---|
| SCP 定义（AON M33 就是 SCP） | **官方资料明确说明** | `sm/doc/intro.md` 术语表 |
| SM 首要职责是隔离、启动其他核前先配 RDC | **官方资料明确说明** | `sm/doc/arch.md` |
| SM 启动流程（main → BRD_SM_Init → LMM_Init → LMM_Boot） | **源码确认** | `sm/doc/imp.md` Bootflow 节 |
| SM 独占 IP 清单（含 IOMUXC / GPIO1 / MU1-6 / TRDC） | **官方资料明确说明** | `sm/doc/arch.md` 物理视图表 |
| DDR 由 M33 ROM 调用的固件初始化 | **官方资料明确说明** | `sm/doc/arch.md` |
| handover/passover 地址、魔数、字段编码 | **源码确认** | `devices/MIMX95/sm/dev_sm_rom.c` |
| `LMM_Boot()` 双重循环 + `SWI_Trigger()` | **源码确认** | `sm/lmm/lmm.c:143` |
| `boot[]` / `bootSkip[]` / `rtime` 语义 | **源码确认** | `sm/doc/config.md` |
| LM0/LM1/LM2 的 boot=1/2/3 | **源码确认** | `mx95evkjailhouse.cfg`、`mx95frdm-pro.cfg` |
| A55 只有 CPU_A55C0 有 start | **源码确认** | 同上，AP LM 的 start/stop 表 |
| SW4/SW7 启动模式表 | **官方资料明确说明** | `UM12527` §2.3、`UM12022` Table 55 |
| 实机看到 "Hello from SM"、DDR OEI | **实机验证** | COM19 上电日志 |

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
