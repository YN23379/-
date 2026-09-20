---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 未分类
status: 已整理
evidence: 实机验证
tags: [协议, 启动, 编译构建, 多核与异构]
updated: 2026-09-17
---

# i.MX95 上 Jailhouse 与 Harpoon 的分层与判定方法

> 适用范围：判断“厂商给的预编译实时/虚拟化软件包，能不能用在我手上这块板子上”，以及理解 Cortex-A 上跑 RTOS 的架构。示例来自 i.MX95 + FRDM-IMX95-PRO，但方法可迁移到 i.MX8M/i.MX93/i.MX943 等。
> 产生该结论的项目证据：[2026-09-17-Harpoon可用性验证](../../10-项目/IMX95-EVK/Harpoon验证与复现.md)。

## 一、先把“能用”拆成两层

评估一个厂商实时软件包时，必须分开回答，否则会把“方案不成立”和“这个包不适配”混为一谈：

1. **方案层**：这个软件是不是解决目标问题的正确架构（例如“在 Cortex-A 上跑 FreeRTOS”）。
2. **适用层**：这个**板级预编译包**能否跑在**这块具体板子**上。

预编译包 = 板级构建产物。它把“软件栈”和“某块板子的板级参数（DDR 训练、System Manager、引脚、设备树、内存划分）”焊在了一起，所以换板时软件栈可复用、板级必须换。

## 二、Cortex-A 上跑 RTOS 的三种形态

| 形态 | 做法 | 代价 | 适合场景 |
|---|---|---|---|
| A55 独占裸机 RTOS | 自己写 A55 平台层（端口、异常向量、MMU 页表、GIC、generic timer、链接脚本），启动链里用 RTOS 镜像替换 Linux | 工作量最大，所有权限与资源分配自己管 | 不需要 Linux |
| 分区 hypervisor + inmate（Jailhouse） | Linux 先启动作 root cell，Jailhouse 划分核/内存/中断，RTOS 作为 inmate 跑在某个 A55 上 | 需要 root cell DTB 预留内存、CPU 隔离、cell 配置；实时性受 hypervisor 影响但可控 | 需要 Linux 与实时域共存 |
| 官方 SDK/BSP | 厂商已把上面某一种做成产品（如 Harpoon = 第二种的成品） | 依赖厂商支持矩阵 | 首选，如果有支持 |

**与 STM32 的对比（哪些不能直接类比）**：

- STM32H7 的双核（Cortex-M7 + M4）是 AMP，但 M4 上没有 MMU、没有 EL 异常级、没有 hypervisor；两个核各自跑各自的，不存在“分区管理程序”这一层。所以 STM32 上“M4 跑 FreeRTOS”是**裸机**问题，不是虚拟化问题。
- Cortex-A55 有 EL0–EL3、MMU、GIC、generic timer，Linux 默认会用掉全部核和内存。要在其中一个核上跑 RTOS，必须解决“把核和内存从 Linux 手里合法拿走”这件事，这正是 Jailhouse 的角色。
- **相同点**：FreeRTOS 内核本身与业务任务代码是可复用的（`tasks.c`/`queue.c`/API 不变），换的是端口层与平台层。这点和 STM32 上换型号只改 `port.c`/启动文件/时钟树是同一个道理，只是 A55 的平台层厚得多（MMU、异常级、GIC、定时器、启动容器）。

## 三、Jailhouse 是什么、它向 root cell 要什么

- 类型：**静态分区（partitioning）hypervisor**，不是 KVM 那种通用全虚拟化。它假设整机配置在启动时就固定：哪个核属于哪个 cell、每段内存在哪个 cell、哪个中断发给谁，全部写在 `.cell` 配置里，运行时不做动态调度。
- 因此它向 Linux（root cell）要三样东西：
  1. **内存**：Linux 只能用一部分 DRAM。做法是在 root cell 设备树里预留，或由启动参数给出（NXP 的 U-Boot 用 `jh_root_mem=size@base,...` 和专门的 `*-root.dtb` 实现）。
  2. **CPU**：`cpu_set` 位图，root cell 初始占全部核，创建 inmate cell 时把某个核划走。
  3. **中断**：`irqchips` 里按 GIC SPI 号范围分配；hypervisor 自己占一个 maintenance IRQ。
- hypervisor 自身要放在一块 Linux 不用的内存里（i.MX95 是 `0xffc00000` + 4 MB），还需要一个 debug console（直接操作某个 UART）。
- 关键点：**这些地址绝大多数是 SoC 级常量**（GIC 基址、UART 基址、DDR 高地址布局），因此同一颗芯片的不同板子可以复用同一份 cell 配置骨架；**板级差异体现在**预留内存大小/位置、root DTB、以及 inmate 用哪个 UART 引到板子外面。

## 四、Harpoon 的组成：谁提供什么

| 层 | 内容 | 换板时 |
|---|---|---|
| root cell OS | Linux（Real-Time Edge 版本带 PREEMPT-RT 内核） | 软件栈，可换板但需匹配内核模块 |
| hypervisor | `jailhouse.bin` + `jailhouse`/`pyjailhouse` 工具 + `.cell` 配置 | SoC 级可复用，板级内存划分要改 |
| inmate OS | FreeRTOS 或 Zephyr 内核（来自 MCUXpresso SDK / FreeRTOS-Kernel） | 内核可复用 |
| inmate 应用 | `hello_world` / `industrial` / `rt_latency` / `audio` / `virtio_net` | 源码可复用，板级 `board.h` / `memory.h` / MMU / 串口要改 |
| 板级包 | 启动容器、DTB、rootfs（预编译） | **必须换** |
| IPC | RPMsg-Lite、VirtIO（`harpoon_ctrl` 做控制） | 可复用 |

FreeRTOS 侧不是“重写一个 RTOS”，而是“把 MCUXpresso SDK 的驱动 + FreeRTOS 内核编译成 AArch64 inmate 镜像”，所以它的驱动仍然是 `fsl_lpuart.c`、`fsl_gpio.c` 这一套，只是通过 inmate DTB/MMU 拿到设备。

## 五、判定“厂商预编译包能否用于手头板子”的五步法

按顺序查，任一步不符就不能直接认定可用。这几步都是**只看二进制/配置就能做**的，不必先上板：

1. **设备树 model / compatible 对比**（最硬）：把包里的 DTB 和板子原厂 DTB 各提取一次字符串，比 `model` 与 `compatible`。不同 → 板级配置不同。
2. **Yocto 配方里的机器映射表**：厂商 meta 层里通常有 `COMPATIBLE_MACHINE` 或 `BOARD:<machine> = "<board>"` 映射，这就是**官方支持清单**，比下载页更准确。
3. **启动容器内的 U-Boot 环境变量**：`fdtfile`、`jh_root_dtb`、`jh_root_mem`、`console=`。这些直接暴露板级参数；`jh_root_dtb` 的命名（`imx95-19x19-<board>-root.dtb`）还能反推厂商为哪块板做过 jailhouse 适配。
4. **容器内 System Manager 的板名字符串**：i.MX95 的 M33 SM 固件里带板名（如 `mx95rte` / `mx95frdm-pro`）。板名不同意味着 SM 的引脚/外设/权限配置不同，**不能混用容器**。
5. **时间线**：包的发布日期 vs 板子用户手册版本。软件包不可能支持比它更晚发布的板子。

补充一条经验：**i.MX9 的 U-Boot 里如果有 `jh_*` 命令和 `xenboot`，说明该 BSP 已经为这块板做过 Jailhouse/Xen 启动适配**（预留内存、root DTB 命名都齐了），这时“Linux + 分区 hypervisor”的底座是官方给的，缺口只剩 inmate 侧。

## 六、对不上时，按“SoC 级 / 板级”分层算差距

以 i.MX95 为例（`imx-jailhouse` 的 `configs/arm64/imx95.c`）：

| 项目 | 层级 | 换板要不要改 |
|---|---|---|
| root cell 名 `imx95`、hypervisor 内存 `0xffc00000`+4 MB | SoC | 不改 |
| GIC（gicd `0x48000000` / gicr `0x48060000`、maintenance IRQ 25） | SoC | 不改 |
| debug console UART 地址（`0x44380000` = LPUART1） | SoC（由芯片决定） | 地址不改，但要确认该 UART 在板子上是否引出 |
| inmate 内存段（`0xf0000000` + `0xf700000`） | SoC 布局 + 板级 DRAM 容量 | 视板子内存调整 |
| Linux root cell 内存段、`jh_root_mem` | 板级 | 必须改 |
| root cell DTB（预留内存节点） | 板级 | 必须换 |
| inmate DTB（给 inmate 哪些设备、串口） | 板级 | 必须换 |
| 启动容器（DDR 训练/OEI、SM、SPL/ATF/U-Boot） | 板级 | 必须用本板已验证的 |
| inmate 应用板级头文件（`board.h`/`memory.h`/MMU/串口） | 板级 | 必须适配 |

判断口诀：**地址看芯片，容量看板子，设备看原理图，启动链看 BSP。**

## 七、实际排查中用到的可复用经验

- **串口被占用**：Windows 上 `.NET SerialPort.Open()` 报 `Access to the port 'COMxx' is denied`，优先怀疑有终端程序（MobaXterm/PuTTY 等）占着，而不是线坏了。
- **端口存在 ≠ 板子在跑**：USB 转串口芯片（如 CH9114F）只要 USB 侧有电就会枚举出 COM 口，SoC 没上电时发 `<CR>` 得不到任何回显。定位“板子是否在跑”要靠**收数据**，不能靠“设备管理器里有口”。
- **用启动参数交叉定位控制台 UART**：U-Boot 里 `console=ttyLP0`、jailhouse 里 debug console 地址 `0x44380000`、SDK 头文件里 `LPUART1_BASE=0x44380000`，三处一致才能确认“日志应该出现在哪个物理口上”。只看其中一处容易认错串口。
- **板级容器不能混用**：i.MX95 的启动容器里含 System Manager，SM 决定引脚、外设归属与访问权限（TRDC/LMM）。把别块板的容器拿到本板跑，等于用别人的权限与电源配置启动本板，属于非官方组合；用 SDPS 载入内存运行（不写 Flash）可以把风险限制在“断电即恢复”。

## 七、包不适配时的正确姿势：**"拆开用"**

判定"厂商预编译包不适用于本板"之后，不要直接放弃——要按层拆开看：

1. **板级外壳**（启动容器、DTB、System Manager 配置、脚本里的机器名判断）：**必须用本板 BSP 的**。
2. **芯片级/软件栈资产**（hypervisor 二进制与 cell 配置骨架、RTOS inmate 二进制、控制程序、运行脚本逻辑）：**通常可以直接复用**。
3. 于是可行路线是：**底座用本板原厂的虚拟化栈，应用取厂商包里的资产**。

具体到本项目（FRDM-IMX95-PRO + Harpoon/Real-Time Edge）：

- 底座：Pro 板原厂 Linux 自带的 Jailhouse（`/sbin/jailhouse`、`jailhouse.ko`、`/lib/firmware/jailhouse.bin`、`/usr/share/jailhouse/cells/imx95.cell`）。
- 应用：从 RTE/Harpoon 包里抽出的 `imx95-harpoon-freertos.cell` + `inmates/freertos/rt_latency.bin`（FreeRTOS）。
- 结果：`jailhouse cell load freertos rt_latency.bin -a 0xf0000000` + `cell start` → **FreeRTOS 在 A55 的一个核上 running**，Linux 同时保留其余核。
- 代价：需要自己把包里的板级假设（root DTB、脚本机器名、inmate 控制台 UART）逐个替换。

这条经验可推广到任何"厂商只给了 A 板预编译包，而我在 B 板"的场景：**先分层，再决定哪些必须换、哪些能直接搬。**

## 八、怎么证明"inmate 真的在跑"

只看 `cell start` 返回 0 不够（它只说明 hypervisor 接受了请求）。按强度递增：

1. **`jailhouse cell list`**：状态从 `shut down` 变 `running`，且目标 CPU 从 root cell 的 CPU 列表里消失（例：`imx95 running 0-4` + `freertos running 5`）。
2. **`nproc` / `lscpu`**：Linux 侧可用核数减少，是最直观的"核被划走了"。
3. **`jailhouse cell stats <cell>`**：看 `vmexits_total` 与 `vmexits_mmio`。inmate 在**持续访问被 hypervisor 模拟的 MMIO**（典型是写自己的控制台 UART）时，这两个计数会不断增长——这是"CPU 上真的有代码在跑"的硬证据。
   - 坑：该工具是 curses 程序，需要终端；非交互 SSH 下要加 `ssh -tt` + `TERM=xterm`；且它 exec 的 `jailhouse-cell-stats` 在 `/usr/share/jailhouse/tools`，必须把该目录加进 PATH，否则报 `execvp: No such file or directory`。

## 九、控制通道的选择：SSH 优先，串口兜底

Cortex-A 上跑 inmate 时，**inmate 很可能占用调试串口（甚至抢走其 IRQ），导致 Linux 控制台失去输入**（本项目实测：跑 `uart-demo.bin` 后串口回车、Ctrl-C 全部无效）。所以控制通道要提前规划：

- **首选独立网口 + SSH**：直连网线时两端自动获得 IPv4 链路本地（`169.254.x.x/16`）与 IPv6 链路本地（`fe80::...`），**无需 DHCP、无需手工配 IP**；IPv4 那个地址每次启动可能变，IPv6 链路本地稳定。Linux 发行版 sshd 常允许 root 免密（`ssh -o BatchMode=yes`）。
- **网口默认可能是 DOWN**：必须在串口上先 `ip link set eth0 up`，否则表现为 SSH 连接超时（容易被误判为板子挂了）。
- **串口只用于：抢 U-Boot、改启动参数、网络没起来时的救援**。做这些时注意：抢 autoboot 只用回车（Ctrl-C 会打死 getty）、抢到提示符后立刻下发命令（否则看门狗会把板子复位）、读取要有绝对超时（持续刷屏时"等安静"会永远等不到）。

## 十、证据来源

- NXP HARPOON 产品页与下载矩阵、`UG10170`/`HRPNUG` Harpoon 用户指南（`官方资料明确说明`）
- `github.com/NXP/harpoon-apps`（README、`west.yml`、板级目录）（`源码可以确认`）
- `github.com/NXP/meta-nxp-harpoon` `recipes-bsp/harpoon-apps/harpoon-apps-freertos.inc`（机器映射表）（`源码可以确认`）
- `github.com/nxp-imx/imx-jailhouse` `configs/arm64/imx95.c`（`源码可以确认`）
- 项目实测：容器内 U-Boot 环境变量、DTB `model`/`compatible`、rootfs manifest、板载 `/lib/firmware/jailhouse.bin`（`实机/镜像确认`，见项目档案）

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|i.MX95时钟-IOMUX与板级串口选择方法]]
- [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95多核与程序启动]]
- [[20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md|i.MX95在A55上运行FreeRTOS的路径]]
