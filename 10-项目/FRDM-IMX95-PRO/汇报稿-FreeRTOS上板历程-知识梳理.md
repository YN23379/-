---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# 汇报稿知识梳理：FreeRTOS 从选板到上板验证

> 用途：配合《汇报稿-FreeRTOS上板历程.md》，解释首次出现的名词、说明来龙去脉，用于应对汇报追问。
> 事实来源：本项目实测、NXP 官方资料与源码。区分"已验证"和"待验证"。

**核心索引**：汇报的两个重点是第六节的 GPIO 三层初始化，和第七节的权限隔离主链。这两节要讲透，其余章节作为背景知识备查。

## 一、整体主链

```text
① 官网资料 → 启动 A55 Linux，确认板子正常
② 看板载固件 → 误判 FreeRTOS 在 M7（因为文件名都是 m7_TCM）
③ 找烧录方式 → remoteproc 行不通，U-Boot 搬 TCM 行不通，无 JTAG，改用 USB+UUU
④ 下载 SDK → IAR 编译 M7 FreeRTOS 示例，得到 M7 bin
⑤ bin 不能直接烧 → 拆原厂启动镜像 + 组装启动容器 flash.bin
⑥ WSL 编译（SM 用 Arm GNU，打包用 imx-mkimage）+ uuu 烧录 → 看到 hello world
⑦ 测串口、测 GPIO → M7 无 GPIO 权限 → 改 M33 SM 配置
⑧ 掉电保持 → 写 SD 卡 → 又遇 BL31 改 PCNS/PCNP → M7 按位夺回
⑨ 实时性理解与初测 → 多任务 → LED 任务与抢占实验
```

主链一句话：**Boot ROM 收容器，ELE 校验，DDR 初始化，SM 起来配好逻辑机和 TRDC，再拉起 M7 和 A55；M7 用外设要过 TRDC 和 SCMI 两道关。**

## 二、名词逐条解释

- **Boot ROM**：芯片出厂固化的启动代码。它按 SW4 选择启动源，能识别的是一种特定格式的启动容器。
- **SDP / SDPS**：Boot ROM 的 USB 串行下载协议。SDPS 是支持大数据流的版本。板子进这个模式后会在电脑上枚举成一个 NXP 设备。
- **UUU**：NXP 主机端下载工具，把启动容器通过 SDPS 发给 Boot ROM。
- **启动容器 flash.bin**：i.MX 规定的多镜像打包格式。每个镜像带类型、核心、装载地址、大小、哈希。Boot ROM 靠它知道谁放到哪、交给哪个核。
- **ELE**：EdgeLock Enclave，芯片的安全子系统，固件在容器里。负责安全启动校验、密钥等。版本必须和 BSP 匹配。
- **AHAB**：i.MX9 的安全启动框架与容器，里面装 ELE 固件和校验信息。
- **V2X**：平台固件，也在 AHAB 容器里，和安全启动链路一起。
- **DDR OEI**：On-chip Execution Image，这里是 DDR 初始化镜像，负责把 LPDDR5 训练起来。没有它内存不可用。
- **SPL**：Secondary Program Loader，U-Boot 的第一阶段，A55 侧引导。
- **BL31 / ATF**：ARM Trusted Firmware 的 EL3 运行时，位于 A55 的安全监控层。它会在启动时改 GPIO2 的安全属性，是 SD 启动 GPIO 失效的根因。
- **TEE**：可信执行环境固件，是 A55 启动链的一部分。
- **Quick Boot 数据**：原厂启动镜像里的一段早期数据，不在普通镜像列表里。缺了它设备在早期启动就停。我们按偏移从原厂镜像取出补上。
- **64KB 保留区**：原厂布局里 DDR OEI 和 SM 之间的一段空隙。打包时不保留，SM 的装载位置就会前移，导致 SM 不启动。
- **TCM**：Tightly Coupled Memory，直接连在 M7 核上的紧耦合内存，延迟低且稳定，适合放实时程序。M7 视角地址从 0 开始，A55 视角是别名地址。
- **SM / System Manager**：运行在 M33 上的系统管理固件，管电源、时钟、复位、引脚和各核启动，启动后继续提供服务。它是整块芯片的管家。
- **LM / 逻辑机**：SM 把芯片划分成的资源集合。本项目 LM0 是 SM 自己，LM1 是 M7，LM2 是 A55。每个逻辑机有自己的内存、外设、引脚和 API 权限。LM 编号来自当前配置，不是硬件定律。
- **LMM**：SM 内部管理逻辑机生命周期和故障反应的模块。
- **TRDC**：Trusted Resource Domain Controller，总线上的硬件访问控制。访问会带发起方的域 ID，TRDC 按域 ID 和目标地址判断放不放行。它保护的不只是内存，外设寄存器窗口也在其中。
- **SCMI**：Arm 定义的系统控制与管理接口。各核通过它向 SM 申请时钟、电源、引脚等服务。
- **MU**：Messaging Unit，芯片上的消息单元，也就是邮箱硬件。SCMI 消息通过 MU 传给 SM。
- **IOMUXC**：引脚复用控制器，决定一个物理引脚接到哪个功能，以及驱动能力、上下拉等电气属性。M7 不直接写它，要经 SCMI 请 SM 代写。
- **RGPIO**：GPIO 控制器本体，管方向、输出、输入和中断，M7 可以直接访问。
- **PCNS / PCNP**：RGPIO 内部按引脚的安全属性和特权属性。一根引脚只归一个世界，另一侧访问会读 0 且写入被忽略。
- **remoteproc**：Linux 用来动态加载远端核固件的框架。能否启动取决于 SM 有没有把目标逻辑机的控制权交给 Linux。

## 三、关键因果

- **为什么以为在 M7**：板载固件名都是 `imx95-19x19-evk_m7_TCM_*.bin`，SDK 示例也在 cm7 目录，所以判断为 M7。后来知道目标其实是 A55，这是产品分工变化。
- **为什么 remoteproc 不行**：报 `lmm(1) not under Linux Control`，是 SM 权限问题，不是文件权限，换 root 也没用。
- **为什么 U-Boot 搬 TCM 不行**：A55 默认没有 M7 TCM 的写权限，触发同步异常。
- **为什么 bin 要打成容器**：Boot ROM 只认带元数据的容器，裸 bin 没有装载地址和核心信息。
- **为什么 ELE 版本要对**：安全启动固件版本必须与 BSP 和芯片匹配，否则 SM 起不来。
- **为什么要保留 64KB 和 Quick Boot**：原厂容器布局要求，否则 SM 装载位置错误或早期启动中断。
- **为什么改 SM 才能用 GPIO**：GPIO2 默认归 A55 逻辑机，M7 访问被 TRDC 拒绝，引脚也不归 M7。改 cfg 把 GPIO2 OWNER 给 M7，同时保留 A55 的访问权限和 API 权限，否则 A55 早期启动受阻，触发看门狗复位。
- **为什么 SD 启动 GPIO 又失效**：完整启动会经过 BL31，BL31 把 GPIO2 的 PCNS 和 PCNP 全置 1，M7 是安全态，读写被静默丢弃。解法是 M7 只把自己那两根脚按位清回。

## 四、可能被追问的问题

- **为什么不用 JTAG**：板上只有裸露测试点，没有调试座，需要自己焊，而且手头没有 J-Link。
- **LMM 和 TRDC 有什么区别**：LMM 是 SM 软件里管逻辑机生命周期和故障反应的部分，TRDC 是硬件总线访问控制。前者管"谁拥有和谁管启停"，后者管"这次访问硬件放不放行"。
- **权限隔离分几层**：至少三层。逻辑机与 API 权限，TRDC 的寄存器访问权限，RGPIO 内部的引脚安全属性。三层都要对，才能让一个引脚真正工作。
- **为什么 A55 不能整块失去 GPIO2**：A55 早期启动链要用 GPIO2 的 API，整块拿走会导致启动受阻和看门狗超时，SM 就会反复复位 A55 所在逻辑机。
- **USB 烧录和 SD 烧录有什么区别**：USB 是 SDPS 下载到内存运行，不写 Flash，断电即恢复，适合试错；SD 是持久化，掉电后自动启动，但会完整走 A55 启动链，于是遇到 BL31 的问题。

## 五、数据与证据

- 实测实时性：M7 800 MHz，500 毫秒周期任务，周期抖动约 0 到 7.5 纳秒，任务体执行约 112 个周期。
- 抢占实验：高优先级忙等 600 毫秒，低优先级打印间隔从 100 毫秒跳到 700 毫秒。
- 串口：LPUART7 到 COM18，LPUART3 是 SDK 默认，已改为板上实际接出的 LPUART7。
- 引脚：GPIO_IO14 是 J15 第 8 脚，GPIO_IO15 是 J15 第 10 脚，GND 是 J15 第 39 脚。
- 启动容器：`build/pro-gpio/flash-m7-preempt.bin`，约 2.85 MB。
- 存放了 PCNS 从 FFFFFFFF 变到 FFFF3FFF 的实机证据，即 M7 夺回两根脚后的值。

## 六、核心一：GPIO 三层初始化（详解）

### 6.1 为什么是三层

从"想用一根 GPIO"到"引脚真的输出电平"，i.MX95 上要经过三个互相独立的部分。三层任何一层不对，现象都是引脚不工作，所以排查时必须一层一层看。

- 第一层，IOMUXC，决定这根物理引脚接成什么功能。
- 第二层，SM 配置与 TRDC，决定 M7 能不能碰 GPIO2 的寄存器。
- 第三层，RGPIO，决定这根脚的方向、电平，以及它归哪个安全世界。

### 6.2 第一层 IOMUXC 引脚复用与电气

- 是什么：IOMUXC 是 I/O Multiplex Controller，引脚复用控制器。芯片的每个物理引脚都可以接多个内部功能，IOMUXC 里的 MUX 寄存器就是选择开关，PAD 控制寄存器负责驱动能力、上下拉、压摆率这些电气属性。
- 谁管：这块板把 IOMUXC 交给 M33 上的 SM 管，M7 不直接写。这和 STM32 不同，STM32 一个引脚的功能选择和电气都在 GPIO 外设里，i.MX95 把它们抽成了全局的 IOMUXC。
- 怎么配：`pin_mux.c` 里的 `BOARD_InitPins` 对每根引脚调 `HAL_PinctrlSetPinMux` 和 `HAL_PinctrlSetPinCfg`。因为工程 `hal_config.h` 选了 SM 路径，HAL 内部通过 SCMI 把请求发给 SM，由 SM 代写 IOMUXC。
- 参数含义：`muxRegister` 指认是哪根 pad，`muxMode` 选功能，0 是 GPIO，2 是 LPUART7，`inputRegister` 和 `inputDaisy` 只有输入功能才用，`configRegister` 指认电气寄存器。
- 关键实现：`SM_PINCTRL_SetPinMux` 把请求打包成 SCMI 配置项，并把寄存器地址换算成 SM 内部的引脚编号，公式是地址减 IOMUXC 基址 0x443C0000 再除以 4。GPIO_IO14 换算出来是 18。
- 本项目的映射：GPIO_IO14 复用成 GPIO2 的 bit14，GPIO_IO15 复用成 bit15，GPIO_IO36 和 37 复用成 LPUART7 的 TX 和 RX。
- 依据：`pin_mux.c`、`hal_pinctrl.c`、`sm_pinctrl.c`、`hal_pinctrl_platform.h`。

### 6.3 第二层 SM 配置与 TRDC 所有权和访问权

- 是什么：SM 配置决定哪个逻辑机拥有哪个外设和引脚。TRDC 是硬件访问控制，决定一次总线访问放不放行。
- 这里要分清三类权限，容易混。
  1. 外设 API 权限，例如 `PERLPI_GPIO2`，决定这个逻辑机能不能通过 SM 管理这个外设。
  2. 外设所有权与访问权，`OWNER` 和 `ACCESS`，参与生成 TRDC 配置，决定这个逻辑机的域 ID 能不能读写 GPIO2 的寄存器窗口。
  3. 引脚所有权，例如 `PIN_GPIO_IO14 OWNER`，决定谁有权配置这根 pad 的 IOMUX。
- 默认情况：GPIO2 归 A55，M7 访问会被拒绝，引脚也不归 M7，所以 GPIO 任务一跑就出问题。
- 怎么改：SM 源码不在 SDK 里，来自 NXP 的 `imx-sm` 仓库。在 `configs` 目录下基于 Pro 板的 cfg 复制一份，把 GPIO2 的 `OWNER` 给 LM1 也就是 M7，同时给 LM2 也就是 A55 保留 `ACCESS` 和 `PERLPI_GPIO2 ALL`。
- 怎么变成固件：用 `configtool.pl` 把 cfg 转成配置头文件，`config_trdc.h` 是 TRDC 权限，`config_scmi.h` 是 API 权限，`config_lmm.h` 是逻辑机配置，再用 Arm GNU 工具链编成 `m33_image.bin`，替换进启动容器。
- 为什么不能整块拿走：A55 早期启动链要用 GPIO2 的 API，失去后启动受阻，触发看门狗超时，FCCU 上报，SM 就反复复位 A55 所在逻辑机。实测错误是 `Reset LM 2, reason=fccu, errId=19`。

### 6.4 第三层 RGPIO 方向读写与引脚安全属性

- 是什么：RGPIO 是 GPIO 控制器本体，M7 可以直接访问，和 IOMUXC 不同。
- 寄存器：`PDDR` 是方向寄存器，1 是输出，0 是输入，复位默认全 0 也就是默认输入。`PDOR` 是输出值，`PSOR` 和 `PCOR` 是置位和清零，`PDIR` 是输入读取。
- 怎么用：`RGPIO_PinInit` 设方向，输出脚还会先写初值。`RGPIO_PinWrite` 输出，`RGPIO_PinRead` 读取。
- 引脚安全属性：RGPIO 内部还有按引脚的安全属性 `PCNS` 和特权属性 `PCNP`。一根引脚只归一个世界，另一侧访问会读 0 且写入被忽略，而且不报错。
- 本项目的用法：GPIO2 的 bit14 接 J15 第 8 脚做输出，bit15 接 J15 第 10 脚做输入。

### 6.5 持久化时的坑，BL31 改写 PCNS 和 PCNP

- 现象：USB 烧录时 GPIO 正常，写到 SD 卡完整启动后就不正常，M7 打印的 `PCNS` 和 `PCNP` 全是 FFFFFFFF，读写自己那两根脚变成读 0 写无效。
- 原因：USB 启动停在 SPL，不进 BL31。SD 完整启动会经过 BL31，而 BL31 在 `bl31_plat_arch_setup` 里把 GPIO2 的 `PCNS` 和 `PCNP` 无条件写成 FFFFFFFF，把整块 GPIO2 划给非安全世界。M7 是安全态，于是访问被静默丢弃。
- 定位过程：先在 U-Boot 读寄存器看到 `PCNS` 是 FFFFFFFF，且写不进去，说明只有安全态能改。再在 U-Boot 里直接操作 GPIO2 数据寄存器能真实改变引脚电平，排除了引脚和硬件问题。最后让 M7 自己打印寄存器，确认是 RGPIO 的安全域过滤，不是 TRDC 拒绝。
- 解法：M7 只把自己那两根脚按位清回安全域。

```c
#define GPIO_PIN_MASK ((1UL << 14U) | (1UL << 15U))   /* 0x0000C000 */
GPIO2->PCNS &= ~GPIO_PIN_MASK;
GPIO2->PCNP &= ~GPIO_PIN_MASK;
```

- 为什么按位与而不是直接写 0：写 0 会把 GPIO2 全部 32 根脚设成安全域，A55 就全用不了。只清 bit14 和 bit15，等于只抢回 M7 自己那两根脚。
- 为什么要在循环里反复执行：M7 先启动，A55 后启动，BL31 写在 M7 初始化之后。所以 M7 要在运行中检查，发现被改回去就再夺回一次。
- 为什么合法：这两根脚在 SM 配置里归 M7，且 PCNS 的锁定位是 0，安全特权态可以改。
- 实机结果：`PCNS` 从 FFFFFFFF 变成 FFFF3FFF，也就是 FFFFFFFF 与上取反 0x0000C000，输出出现方波，回接输入后同步翻转。

### 6.6 三层怎么配合，缺一层会怎样

- 只配 IOMUXC，不动 SM 配置：引脚复用对了，但 M7 访问 GPIO2 寄存器被 TRDC 拒绝，程序可能报错或跑不动。
- 只改 SM 配置，不配 IOMUXC：寄存器能访问，但引脚没接到 GPIO2，电平出不来。
- 三层都对，但完整启动经 BL31：寄存器能访问、复用也对，可是引脚被划给非安全世界，M7 读写无效，这就需要第三层里的 PCNS 和 PCNP 夺回。
- 一句话，IOMUXC 决定这根针接成什么，SM 配置和 TRDC 决定 M7 能不能碰这个控制器，RGPIO 决定这根脚的方向电平以及它归哪个世界。

## 七、核心二：权限隔离主链（详解）

### 7.1 为什么需要隔离

i.MX95 有 6 个 A55、1 个 M7、1 个 M33，还有 GPU、NPU、DMA 这些也能主动读写内存的总线主设备。内存和外设是共享的，如果不隔离，两个核同时改一个寄存器就会冲突，一个设备乱写还可能破坏另一个核的代码和数据。所以隔离要先回答三个问题。

1. 哪个逻辑系统拥有某个核，谁能启动、停止、复位它。
2. 哪个逻辑系统拥有某个外设、引脚和内存区域。
3. 一次真实的总线访问，硬件到底放不放行。

注意，这一整套不是 Linux 的文件权限，root 也绕不过，因为它是硬件和 SM 层的控制。

### 7.2 SM，System Manager

- 是什么：运行在 M33 上的系统管理固件。管电源、时钟、复位、引脚，以及各个核的启动，启动之后继续提供服务。
- 做什么：先把硬件的隔离机制配好，再启动其他核。它把芯片划分成若干个逻辑机，每个逻辑机的权限是静态配置的。
- 怎么通信：对外通过 SCMI 协议，走 MU 邮箱提供服务。Linux、U-Boot、M7 要向它申请时钟、电源、复位、引脚都是走这条路。
- 一句话，SM 是整块芯片的管家。

### 7.3 LM 逻辑机与 LMM

- LM，Logical Machine，逻辑机：SM 把芯片划分成的资源集合，每个逻辑机有自己的 CPU、内存、外设、引脚和 API 权限。它不是虚拟机，也不一定等于一个物理核。
- 本项目：LM0 是 SM 自己，LM1 是 M7，LM2 是 A55。LM 编号来自当前配置，不是 i.MX95 的硬件定律。
- LMM，Logical Machine Manager：SM 内部负责逻辑机配置、状态和生命周期管理的模块。故障反应也走它，比如某逻辑机的看门狗超时，FCCU 上报，LMM 按配置复位该逻辑机。本项目 A55 的 `WDOG3` 超时就是 `reason=fccu, errId=19`，然后 `LMM_SystemLmReset` 复位 LM2。

### 7.4 TRDC 硬件访问控制

- 全称：Trusted Resource Domain Controller。
- 是什么：位于总线和目标资源之间的硬件门禁。总线事务会带发起方的域 ID，TRDC 按域 ID 和目标地址判断能不能访问。
- 关键缩写：DID 是域编号，MDA 把 CPU、DMA 这些主设备分配到域，MBC 内存块检查器按固定块划分权限，MRC 内存区域检查器按起止地址划分权限。
- 注意：它保护的不只是 RAM，外设的寄存器窗口同样在地址空间里，也能被保护。
- 拒绝的后果：不是返回一句权限错误，而是一次总线错误。对 Cortex-M7 来说可能表现为 BusFault 或 HardFault。这也是排查时容易误判的地方。

### 7.5 SCMI 与 MU

- SCMI，System Control and Management Interface：Arm 定义的系统控制与管理接口。各核通过它向 SM 申请服务，比如时钟、电源、复位、引脚。
- 引脚复用就是走 SCMI 的 pinctrl 协议，让 SM 代写 IOMUXC。
- MU，Messaging Unit：芯片上的消息单元，也就是邮箱硬件。SCMI 命令通过 MU 传给 SM，SM 执行后回复。

### 7.6 主链怎么串起来

```text
上电或复位
  -> Boot ROM 按 SW4 选启动源，读启动容器
  -> ELE 做安全校验
  -> DDR 初始化把内存训练起来
  -> 启动 M33 上的 SM
  -> SM 建立逻辑机并配置 TRDC
  -> 按配置释放 M7 复位，并启动 A55 链
  -> M7 用外设要过两道，一道是 TRDC 检查访问放不放行，一道是通过 SCMI 请 SM 配引脚或时钟
```

### 7.7 三层权限与引脚三层的对应

| 权限层 | 配置项或寄存器 | 管什么 |
|---|---|---|
| 引脚所有权 | SM 配置的 `PIN_GPIO_IO14 OWNER` | 谁有权配置这根 pad 的 IOMUX |
| 外设访问权 | SM 配置的 `OWNER` 和 `ACCESS`，生成 TRDC 配置 | 哪个域能读写这个外设寄存器窗口 |
| 外设 API 权 | SM 配置的 `PERLPI_GPIO2 ALL` | 哪个逻辑机能通过 SM 管理这个外设 |
| 引脚安全属性 | RGPIO 的 `PCNS` 和 `PCNP` | 这根引脚的数据寄存器归安全世界还是非安全世界 |

### 7.8 容易混淆的点

- 引脚所有权不等于 GPIO 控制器归谁。`PIN_* OWNER` 只管 IOMUX 配置权，不等于 RGPIO 里这根脚归 M7。
- TRDC 拒绝和 `PCNS` 过滤不是一回事。TRDC 拒绝会产生总线错误，`PCNS` 过滤是读 0 写忽略且不报错。
- Linux 的 root 不等于芯片的最高权限。`lmm(1) not under Linux Control` 是 SM 层拒绝，换 root 或改文件权限都没用。
- 逻辑机不一定等于一个核，它是一组资源，本项目只是恰好一个核一个逻辑机。

## 八、高频问答（版本、串口、GPIO 实测）

### 8.1 烧的是哪个 FreeRTOS，怎么编译，怎么烧，支持什么

- 版本：**FreeRTOS Kernel V11.2.0**。依据是 SDK 内 `rtos/freertos/freertos-kernel-upstream/include/FreeRTOS.h` 文件头。SDK 是 MCUXpresso SDK for i.MX95，版本 26.06.00。
- 编译：IAR EWARM 9.70.4，工程 `freertos_hello/cm7/iar/freertos_hello_cm7.ewp`，命令 `iarbuild ... -build debug`，产物 `iar/debug/freertos_hello.bin`。移植层是 `portable/IAR/ARM_CM4F`，Cortex-M7 复用 CM4F 端口，`configENABLE_FPU` 为 1。
- 烧录：不直接烧 bin。WSL 里用 imx-mkimage 把 M7 bin 与 ELE、DDR OEI、M33 SM、A55 链打成 `flash.bin`，再用 uuu 的 SDPS 发到内存，或写 SD 卡启动。
- 本工程打开的功能，均可从 `FreeRTOSConfig_Gen.h` 查证。
  - 抢占式调度 `configUSE_PREEMPTION` 为 1。
  - tick 200 Hz，`configMAX_PRIORITIES` 为 5，`configNUMBER_OF_CORES` 为 1。
  - 队列，二值信号量，计数信号量，互斥量，递归互斥量，任务通知，事件组，流缓冲和消息缓冲，软件定时器。
  - 内存 `heap_4`，堆 10240 字节，动态分配。
  - 空闲钩子，栈溢出检测为 2，trace 设施打开。
- 要主动说明的坑：本工程原本**没有开时间片轮转**。`configUSE_TIME_SLICING` 在配置头里未定义，被内核默认头设成 0。做对照实验时改成了 1，汇报前应还原，回答时说原本是 0，同级任务不轮转。

### 8.2 串口怎么测的，输入输出分别怎么验证

- 输出：`PRINTF` 最终走 LPUART7，对应 COM18，看到 hello world 说明发送链正常。
- 输入：靠 LPUART7 接收中断。中断服务函数 `LPUART7_IRQHandler` 判断接收寄存器满，读一个字节，`xQueueSendFromISR` 送进队列，`portYIELD_FROM_ISR` 触发调度。
- 消费：`echo_task` 平时阻塞在 `xQueueReceive`，收到字节后调用 `LPUART_WriteBlocking` 把同一个字节发回串口。
- 验证：在 COM18 终端里输入字符，看到原样返回，说明接收中断、队列、任务调度、发送整条链都通。
- 细节：中断优先级设为 `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY`，才能调用 `FromISR` 版本的 API。
- 一句话回答"是不是直接发到串口显示"：是的，回显任务把收到的字节再写回 LPUART7，终端上看到的就是自己输入的字符。

### 8.3 GPIO 权限怎么改，WDOG3 怎么回事，输出输入怎么测

- 现象：用 USB 加 UUU 烧到 TCM，GPIO 任务在跑但引脚不动，COM19 反复打印 `Reset LM 2, reason=fccu, errId=19`。
- 定位：查官方 SM 源码 `eMcem_VfccuFaultList_MIMX95XX.h`，`errId=19` 定义为 WDOG3 timeout。
- 根因：一开始把整个 GPIO2 从 A55 挪给 M7。A55 早期启动链也要用 GPIO2，失去后启动受阻、没喂看门狗，WDOG3 超时，FCCU 上报，SM 反复复位 A55 所在逻辑机。
- 改哪个文件：`tools/imx-sm/configs/other/mx95frdm-pro-m7gpio.cfg`，基于官方 `mx95frdm-pro.cfg` 修改。M7 拿 `GPIO2 OWNER`，A55 保留 `GPIO2 ACCESS` 和 `PERLPI_GPIO2 ALL`，M7 再拿 `PIN_GPIO_IO14` 和 `PIN_GPIO_IO15` 的 OWNER。
- 怎么生效：configtool.pl 生成配置头文件，Arm GNU 工具链编成 `m33_image.bin`，替换进启动容器。没有关闭看门狗，也没有屏蔽 FCCU，只是把权限配对。
- 输出测试：`RGPIO_PinInit(GPIO2, 14, 输出)`，循环里 `RGPIO_PinWrite` 每 500 毫秒翻转。逻辑分析仪接 J15 第 8 脚看到约 1 Hz 方波，或接 LED 看闪。
- 输入测试：`RGPIO_PinInit(GPIO2, 15, 输入)`，`RGPIO_PinRead` 读取。用杜邦线把 J15 第 8 脚和第 10 脚连起来，COM18 打印 `GPIO OUT=0, IN=0` 与 `GPIO OUT=1, IN=1` 同步。
- 一个坑：逻辑分析仪的地要接 J15 第 39 脚，第 9 脚是 IO 不是地。
- 和后续问题的区分：这一节是 SM 与 TRDC 层的权限。SD 卡完整启动后遇到的 `PCNS` 和 `PCNP` 是 RGPIO 内部的安全属性层，见第六节第 5 小节。
