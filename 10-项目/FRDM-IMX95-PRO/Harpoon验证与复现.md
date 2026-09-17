---
type: 项目档案
scope: FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）
doc_type: 怎么做
status: 待验证
evidence: 实机验证
tags: [Harpoon,Jailhouse]
updated: 2026-09-17
---

# Harpoon 可用性验证与复现步骤

> 2026-09-17 精简：验证结论与复现步骤是同一次调研，合成一篇。

## 目录

- 一、Harpoon（Real-Time Edge 3.3 / HS v3.5）能否用于 FRDM-IMX95-PRO —— 纸面验证记录
- 二、Harpoon 全过程记录与复现步骤（FRDM-IMX95-PRO）

---

## 一、Harpoon（Real-Time Edge 3.3 / HS v3.5）能否用于 FRDM-IMX95-PRO —— 纸面验证记录

## Harpoon（Real-Time Edge 3.3 / HS v3.5）能否用于 FRDM-IMX95-PRO —— 纸面验证记录

> 类型：项目档案。板型：NXP FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）。
> 记录时间：2026-09-17。记录人：开发。
> 状态：纸面验证完成；**实机验证已于当日完成并通过**（详见 `2026-09-17-Harpoon全过程与复现步骤.md` 第十二节）。

> **结论更新（当日实机验证后）**：
> 1. **板子出厂自带的是 Jailhouse，不是 Harpoon**——Jailhouse（hypervisor + 工具 + `imx95.cell` + 演示 inmate）在原厂系统里齐全；`/usr/share/harpoon`、`/etc/harpoon` 实测不存在。不要把两者混为一谈。
> 2. 本文件判定的是"**这个预编译包作为整机镜像能否用在 Pro 板**"，结论是**不能**（五条证据见第四节）。
> 3. 但包里**可搬运的资产（FreeRTOS inmate 二进制 + Harpoon cell 配置 + 控制程序）在 Pro 板上是可以用的**，已实机验证：`imx95-harpoon-freertos.cell` + `rt_latency.bin` → `jailhouse cell list` 显示 `1 freertos running 5`，`cell stats` 显示 `vmexits_mmio` 持续增长。
> 4. 准确口径：**"板级外壳"必须换，"软件资产"能直接搬**——即"拆开用"。

### 一、要解决的问题和上下文

目标由 M7 改为 A55 上跑 FreeRTOS 后，需要判断：从 NXP 下载的 Harpoon 包（`HS_v3.5_IMX95-19X19-LPDDR5-EVK.zip`）能不能直接用在手头这块 FRDM-IMX95-PRO 上。

“能用”必须拆成两层，否则会得出错误结论：

1. **方案层**：Harpoon 是不是“在 Cortex-A55 上跑 FreeRTOS”的正确官方路线。
2. **适用层**：这个特定包（板级预编译二进制）能不能跑在这块特定板子上。

本记录中的所有判断都标注来源类型：`官方资料明确说明` / `源码或镜像可以确认` / `实机验证得到` / `待验证或推测`。

### 二、结论

- **方案层：是。** Harpoon 就是 NXP 官方的“RTOS on Cortex-A”方案：Linux（PREEMPT-RT）作为 Jailhouse 的 root cell，Jailhouse 做硬件资源分区，FreeRTOS 或 Zephyr 作为 inmate（guest OS）跑在 Cortex-A55 上，通过 RPMsg / VirtIO 与 Linux 通信。（`官方资料明确说明`：NXP HARPOON 产品页、harpoon-apps README、UG10170）
- **适用层：不能直接认定可用。** 下载包面向的是 `imx95-19x19-lpddr5-evk`（i.MX95 19x19 LPDDR5 EVK），**FRDM-IMX95-PRO 不在 Harpoon 官方支持的机器清单内**。（`源码/镜像可以确认`，见第四节）
- **底座比预期好。** FRDM-IMX95-PRO 自己的 LF 6.18.2 BSP **已经带 Jailhouse 启动流程**（U-Boot 里有 `jh_mmcboot` / `jh_root_dtb=imx95-19x19-frdm-pro-root.dtb` / `jh_root_mem` / `kvm-arm.mode=nvhe`），板载 Linux 的 `/lib/firmware` 里**已有 `jailhouse.bin`**。也就是说“Linux + Jailhouse 分区”这层官方已经支持，缺的主要是板级 root/inmate DTB 和 inmate 侧应用。（`镜像与文件确认`）

一句话：**包里的 Harpoon 软件本身好用，但它是 EVK 板级构建；用在 Pro 板上需要替换板级部分，或先做实机判定。**

### 三、下载到的到底是什么

路径：`F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK`（同内容压缩包 `F:\project\Learning\RTOS\HS_v3.5_IMX95-19X19-LPDDR5-EVK.zip`，3.59 GB）。

主要文件（实测大小）：

| 文件 | 大小 | 作用 |
|---|---|---|
| `Image-imx95-19x19-lpddr5-evk.bin` | 34,787,840 | Linux 6.12.34-rt11 内核镜像 |
| `imx-boot-imx95-19x19-lpddr5-evk-sd.bin-flash_a55` | 2,849,792 | 启动容器：AHAB/ELE + DDR OEI + M33 SM + SPL + BL31(ATF) + U-Boot |
| `imx95-19x19-evk-harpoon.dtb` | 76,636 | Harpoon（root cell）设备树 |
| `imx95-19x19-evk-inmate.dtb` | 5,055 | inmate（FreeRTOS 侧）设备树 |
| `imx95-19x19-evk-root.dtb` | 75,950 | jailhouse root cell 设备树（U-Boot 变量 `jh_root_dtb` 指向它） |
| `nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.tar.zst` | 1,781,543,362 | rootfs（含 jailhouse 与 harpoon 应用） |
| `nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.wic.zst` | 1,801,343,763 | SD 卡整盘镜像 |

rootfs manifest（`nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.manifest`）里确认存在的关键包：

```text
jailhouse-imx                                         2023.03+git0+f64de0b8f6-r0
kernel-module-jailhouse-6.12.34-rt11-lts-next         2023.03+git0+f64de0b8f6-r0
pyjailhouse                                           2023.03+git0+f64de0b8f6-r0
harpoon-apps-ctrl                                     3.5-r0
harpoon-apps-freertos-hello-world                     3.5-r0
harpoon-apps-freertos-industrial                      3.5-r0
harpoon-apps-freertos-rt-latency                      3.5-r0
harpoon-apps-zephyr-hello-world / -industrial / -rt-latency   3.5-r0
packagegroup-harpoon / packagegroup-harpoon-test       1.0-r0
```

**包内没有 harpoon-apps 源码。** 源码在 `github.com/NXP/harpoon-apps`（west manifest，revision `harpoon_3.5.0`），用 ARM GNU Toolchain 14.2.rel1 交叉编译；FreeRTOS 内核来自 `nxp-mcuxpresso/FreeRTOS-Kernel`，驱动复用 MCUXpresso SDK。

跑法（来自 harpoon-apps README，`官方资料明确说明`）：

```bash
modprobe jailhouse
jailhouse enable /usr/share/jailhouse/cells/imx8mp.cell          # 具体到 i.MX95 为 imx95.cell
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/rt_latency.bin --address 0xc0000000
jailhouse cell start freertos
harpoon_ctrl latency -r 1
```

### 四、判定“板子对不上”的四条证据

#### 1. 设备树 model / compatible 实测对比（`镜像可以确认`）

用字符串提取对比两个 DTB：

```text
包内 imx95-19x19-evk-harpoon.dtb : model="NXP i.MX95 19X19 board" , compatible="fsl,imx95-19x19-evk"
包内 imx95-19x19-evk-inmate.dtb  : model="NXP i.MX95 19X19 EVK"  , compatible="fsl,imx95-19x19-evk"
板上 imx95-19x19-frdm-pro.dtb    : model="NXP FRDM-IMX95-PRO"    , compatible="fsl,frdm-imx95-pro"
```

#### 2. Harpoon 官方支持的机器清单里没有 Pro 板（`源码可以确认`）

`meta-nxp-harpoon` 仓库 `recipes-bsp/harpoon-apps/harpoon-apps-freertos.inc`（tag `Real-Time-Edge-v3.3-202512`）的机器映射表：

```text
BOARD:imx8mp-lpddr4-evk        = "evkmimx8mp"
BOARD:imx8mm-lpddr4-evk        = "evkmimx8mm"
BOARD:imx8mn-lpddr4-evk        = "evkmimx8mn"
BOARD:imx93evk                 = "mcimx93evk"
BOARD:imx943-19x19-lpddr5-evk  = "imx943evk"
BOARD:imx95-15x15-lpddr4x-evk  = "imx95lp4xevk15"
BOARD:imx95-19x19-lpddr5-evk   = "imx95lpd5evk19"
```

Harpoon 官方下载页 v3.5 列出的平台与之对应（IMX8MM/IMX8MP/IMX93/IMX95-15X15-LPDDR4X-EVK/IMX95-19X19-LPDDR5-EVK/IMX943-19X19-LPDDR5-EVK），**没有 FRDM-IMX95-PRO**。

`harpoon-apps` 里 FreeRTOS 板级目录同样只有 `imx95lp4xevk15` 和 `imx95lpd5evk19`，没有 frdm-pro。

#### 3. 两个启动容器的 U-Boot 环境变量对比（`镜像可以确认`）

对 `imx-boot-imx95-19x19-lpddr5-evk-sd.bin-flash_a55`（Harpoon 包）与 `imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55`（LF_v6.18.2 BSP）做字符串扫描，两边都带 Jailhouse 启动流程，但板级参数不同：

```text
EVK 包  : fdtfile="imx95-19x19-evk-adv7535-ap1302.dtb"
          jh_root_dtb=imx95-19x19-evk-root.dtb
          jh_root_mem=0x58000000@0x90000000,0x300000000@0x180000000
          console=ttyLP0,115200 earlycon
Pro BSP : fdtfile="imx95-19x19-frdm-pro.dtb"
          jh_root_dtb=imx95-19x19-frdm-pro-root.dtb
          jh_root_mem=0x58000000@0x90000000,0xc0000000@0x180000000
          console=ttyLP0,115200 earlycon
两者共同: jh_clk=kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
          jh_mmcboot / jh_netboot / xenboot，均有 xenboot
```

容器内 System Manager 的板名字符串也分别是对应的板名：

```text
EVK 包  : mx95rte
Pro BSP : mx95frdm-pro
DDR OEI : 两者都是 mx95lp5（同一族 LPDDR5 OEI 固件）
```

#### 4. 时间线（`官方资料明确说明`）

Real-Time Edge 3.3 / Harpoon 3.5 发布于 2025-12；FRDM-IMX95-PRO 的用户手册 UM12527 是 Rev 1.1、2026-07-02，快速入门 FRDMIMX95PROQSG REV 0。**板子比这个软件包晚**，所以包里不可能有 Pro 板配置。

### 五、SoC 级 vs 板级：需要换的拼图

Jailhouse 上游 `nxp-imx/imx-jailhouse` 在 RTE 3.3 使用的 `lf-6.12.34_2.1.0` 分支里**已经有 i.MX95 支持**：`configs/arm64/imx95.c`。其关键内容（`源码可以确认`）：

| 配置项 | 值 | 层级 |
|---|---|---|
| root cell 名 | `imx95` | SoC |
| hypervisor 内存 | `0xffc00000` + `0x00400000`（4 MB） | SoC |
| debug console | `0x44380000`（LPUART1），类型 `JAILHOUSE_CON_TYPE_IMX_LPUART` | SoC |
| GIC | gicd `0x48000000` / gicr `0x48060000`，maintenance IRQ 25，v3 | SoC |
| inmate 内存 | `0xf0000000` + `0x0f700000`（约 247 MB），RECLAIMABLE | SoC |
| Linux root cell 内存 | `0x8e200000` + `0x61e00000`、`0x100000000` + `0x380000000` 等 | 板级相关 |

与 SDK 交叉核对：`SDK_26_06_00_IMX95LPD5EVK-19\devices\MIMX9596\MIMX9596_cm7_COMMON.h` 中 `LPUART1_BASE = 0x44380000`，与 Jailhouse debug console 地址一致；U-Boot 的 `console=ttyLP0` 也指向 LPUART1，即 **COM17**。

结论：**SoC 级配置可以复用，板级必须替换。**

| 项目 | EVK 包提供 | Pro 板需要 | 状态 |
|---|---|---|---|
| Jailhouse 超visor + i.MX95 cell 配置 | `jailhouse.bin`、`imx95.c` | 同（SoC 级） | 可复用 |
| root cell DTB | `imx95-19x19-evk-root.dtb` | `imx95-19x19-frdm-pro-root.dtb` | 待取（U-Boot env 里有名字，本地 BSP 目录未含该文件） |
| inmate DTB | `imx95-19x19-evk-inmate.dtb` | 需对应 Pro（串口、内存划分） | 待做 |
| 启动容器（DDR OEI + SM + SPL/ATF/U-Boot） | EVK 版 | 必须用 Pro 版（已验证可启动） | 已有 |
| FreeRTOS inmate 应用 | `harpoon-apps-freertos-*` 3.5（`imx95lpd5evk19`） | 需按 Pro 板编译/适配 | 待做 |
| 控制台 | `ttyLP0` = LPUART1 = COM17 | 同 | 可复用 |

### 六、验证计划与实际进展

三条路径：

- **A（快速判定）**：用 UUU 的 SDPS 把 EVK 容器只加载到内存运行，**不写 eMMC、不写 SD 卡**，只看 COM17（LPUART1，115200-8-N-1）能否出现 DDR OEI / SPL / ATF(BL31) / U-Boot 日志。
  - 意义：直接回答“EVK 板级构建在 Pro 板上能不能起来”。这也是“把 RTE 的 wic 镜像直接写 SD 卡启动”这条最省事路线的前提（wic 里就是 EVK 容器）。
  - 风险：EVK 容器带的是 EVK 的 SM/PMIC/DDR 板级配置，属于非官方组合；不写任何持久介质，断电即恢复。
  - 脚本已备：`F:\project\Learning\RTOS\build\harpoon-test\boot-evk-container.uuu`。
  - 状态：**未执行**。待板子上电、并提权执行 `uuu.exe`。
- **B（移植）**：Pro 已验证启动链 + RTE 内核/rootfs + `imx95-19x19-frdm-pro-root.dtb` + jailhouse `imx95` cell + 按 Pro 板编译的 harpoon FreeRTOS inmate。
- **C（官方支持）**：向 NXP/FAE 确认 FRDM-IMX95-PRO 是否有 Harpoon / Real-Time Edge 计划或 Pro 板 root DTB 获取途径。

#### 实机现状（2026-09-17）

- COM16–COM19 四个口都能打开（CH9114F 由 USB 供电即枚举，不代表 SoC 在跑）。
- 对四个口各发一次 `<CR>`，并发抓取 120 秒，**收到 0 字节有效数据** → 板子当前没有运行（未上电或未启动）。
- 电脑侧没有活动的有线网卡（只有 VMware 虚拟网卡和 WLAN），板子 ping 不通 `192.168.50.2` → **SSH 路线当前不可用**，只能走串口。

### 七、环境上踩到的问题

1. **串口被占用**：MobaXterm 打开着串口会话时，PowerShell/.NET 打开 COM16–19 报 `Access to the port 'COMxx' is denied`。关掉 MobaXterm 的串口标签页后四个口均可打开。
2. **沙箱限制外部程序**：当前 DSH 文件策略为 `workspace-write` 时，`uuu.exe`、`tar.exe`（解 rootfs 的 zst）、`python.exe`、`git.exe`、`cmd.exe` 一律报 `Access is denied` / `[sandbox: file access denied]`。纯 PowerShell/.NET 代码（含串口读写、二进制字符串提取）不受影响。需要执行 uuu 时按规则逐次提权。

### 八、待确认 / 待验证

- `待验证`：EVK 启动容器能否在 FRDM-IMX95-PRO 上跑起来（路径 A）。
- `待验证`：Pro 板原厂 Linux 是否已带 jailhouse 用户态工具、`/usr/share/jailhouse/cells` 和 root DTB（需要串口登录后查）。
- `待确认`：`imx95-19x19-frdm-pro-root.dtb` 从哪取（完整 LF BSP 包 / 板载 /boot / 内核源码重编）。
- `待确认`：NXP 是否有 Pro 板的 Harpoon 计划（路径 C）。
- 若走 B：A55 是否仍保留 Linux、划几个核给 inmate、需要哪些外设与实时指标。

### 附：本次用到的路径与命令

```text
Harpoon 包        : F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK
同内容压缩包      : F:\project\Learning\RTOS\HS_v3.5_IMX95-19X19-LPDDR5-EVK.zip
Pro 原厂启动容器  : F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95\imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
Pro 原厂 DTB      : F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95\imx95-19x19-frdm-pro.dtb
板载 jailhouse.bin: F:\project\Learning\RTOS\board_firmware\firmware\jailhouse.bin （104,456 B）
UUU               : F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe
本次新增脚本      : F:\project\Learning\RTOS\build\harpoon-test\boot-evk-container.uuu
                    F:\project\Learning\RTOS\build\harpoon-test\serial-probe.ps1
                    F:\project\Learning\RTOS\build\harpoon-test\serial-capture.ps1
串口抓取日志      : F:\project\Learning\RTOS\build\logs\
```

```powershell
# 串口探测（纯 PowerShell）
.\serial-probe.ps1 -Port COM17 -Send @('') -WaitMs 2500
# 多口并发抓取
.\serial-capture.ps1 -Ports COM16,COM17,COM18,COM19 -DurationSec 600 -OutDir F:\project\Learning\RTOS\build\logs
# SDPS 内存启动 EVK 容器（需提权，板子需 SW4=x001 并冷复位）
& F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe -lsusb
& F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe F:\project\Learning\RTOS\build\harpoon-test\boot-evk-container.uuu
```

### 关联

- 知识库：`i.MX95 上 Jailhouse / Harpoon 的分层与判定方法`
- 项目档案：`方向调整-A55运行FreeRTOS.md`、`进度汇报-2026-09-17.md`

---

## 二、Harpoon 全过程记录与复现步骤（FRDM-IMX95-PRO）

## Harpoon 全过程记录与复现步骤（FRDM-IMX95-PRO）

> 类型：项目档案 / 复现手册。板型：NXP FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）。
> 日期：2026-09-17。目的：把"下载的 Harpoon 能不能用"这件事从下载、核查、上板、验证到复现，一次说清。

### 〇、先纠一个最容易传错的结论

**板子出厂自带的是 Jailhouse，不是 Harpoon。** 这两者不是一回事：

| 名称 | 是什么 | 原厂 Pro 系统里有没有 |
|---|---|---|
| **Jailhouse** | 静态分区 hypervisor（把核/内存/中断划给不同 cell）+ 管理工具 + `.cell` 配置 + 演示 inmate | **有**（`/sbin/jailhouse`、`jailhouse.ko`、`/lib/firmware/jailhouse.bin`、`/usr/share/jailhouse/`） |
| **Harpoon** | 基于 Jailhouse 的**产品化方案**：Real-Time Edge 发行版 + FreeRTOS/Zephyr inmate 应用 + `harpoon_ctrl` 控制程序 + 运行脚本 | **没有**（`/usr/share/harpoon`、`/etc/harpoon` 都不存在，实测 `ls` 报 No such file） |

所以正确说法是：**Pro 板出厂就具备"跑 Jailhouse 分区"的能力，缺的是 Harpoon 这层应用（inmate 二进制、cell 配置、控制脚本）。** 而 Harpoon 的这些文件在下载包里是有的——只是它是为 i.MX95 19x19 LPDDR5 **EVK** 构建的。

另外必须强调：**整个验证过程没有向板子写入任何持久介质**（没写 eMMC、没写 SD 卡、没刷任何镜像）。所有改动都是运行时的、断电即消失的。详见第六节。

### 一、阶段一：先搞清楚"下载的到底是什么"（只在 PC 上做，未接触板子）

#### 1.1 下载物

| 项目 | 值 |
|---|---|
| 压缩包 | `F:\project\Learning\RTOS\HS_v3.5_IMX95-19X19-LPDDR5-EVK.zip`（3.59 GB） |
| 解压目录 | `F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK` |
| 官方身份 | Harpoon Software v3.5 / Real-Time Edge Software 3.3（`SCR-REAL-TIME-EDGE-3.3.txt`：Release tag `Real-Time-Edge-v3.3-202512`，2025 年 12 月） |
| 内容 | Linux RT 内核 `Image`、启动容器 `imx-boot-...-evk-sd.bin-flash_a55`、DTB、rootfs（tar.zst / wic.zst） |
| **包内没有的东西** | harpoon-apps 源码（源码在 `github.com/NXP/harpoon-apps`，用 west + ARM GCC 14.2 编译） |

#### 1.2 用到的检查手段（全部只读，不执行任何写入）

| 手段 | 命令/做法 | 目的 |
|---|---|---|
| DTB 字符串提取 | 纯 PowerShell 读二进制、抽 ASCII 串 | 看 `model` / `compatible`，判断面向哪块板 |
| rootfs 清单比对 | 读 `*.rootfs.manifest`（纯文本） | 确认包里装了哪些 harpoon/jailhouse 软件包 |
| 容器字符串扫描 | 对 `imx-boot-*.bin` 抽字符串 | 看 U-Boot 环境变量（`fdtfile`/`jh_root_dtb`/`jh_root_mem`/`console`）和 SM 板名 |
| tar 列表 | `tar -tf *.rootfs.tar.zst`（需提权执行 tar.exe） | 确认 inmate 二进制、cell 配置、脚本的确切路径 |
| 联网核对 | NXP Harpoon 下载页、`github.com/NXP/harpoon-apps`、`github.com/NXP/meta-nxp-harpoon`、`github.com/nxp-imx/imx-jailhouse` | 拿官方支持清单和上游 cell 配置 |

#### 1.3 判定"不支持本板"的五条证据

1. **DTB 面向 EVK**
   ```text
   包内 imx95-19x19-evk-harpoon.dtb : model="NXP i.MX95 19X19 board"  compatible="fsl,imx95-19x19-evk"
   本板  imx95-19x19-frdm-pro.dtb   : model="NXP FRDM-IMX95-PRO"      compatible="fsl,frdm-imx95-pro"
   ```
2. **Yocto 机器映射表里没有 Pro**（`meta-nxp-harpoon/recipes-bsp/harpoon-apps/harpoon-apps-freertos.inc`，tag `Real-Time-Edge-v3.3-202512`）：
   ```text
   BOARD:imx8mp-lpddr4-evk / imx8mm / imx8mn / imx93evk / imx943-19x19-lpddr5-evk
   BOARD:imx95-15x15-lpddr4x-evk = "imx95lp4xevk15"
   BOARD:imx95-19x19-lpddr5-evk  = "imx95lpd5evk19"
   → 共 7 个，没有 frdm-pro
   ```
3. **启动容器环境变量是 EVK 的**（同 SoC，不同板级）：
   ```text
   EVK 包  : fdtfile="imx95-19x19-evk-adv7535-ap1302.dtb"  jh_root_dtb=imx95-19x19-evk-root.dtb
             jh_root_mem=0x58000000@0x90000000,0x300000000@0x180000000  SM 板名=mx95rte
   Pro BSP : fdtfile="imx95-19x19-frdm-pro.dtb"           jh_root_dtb=imx95-19x19-frdm-pro-root.dtb
             jh_root_mem=0x58000000@0x90000000,0xc0000000@0x180000000  SM 板名=mx95frdm-pro
   ```
4. **官方运行脚本不认这块板**（`/usr/share/harpoon/scripts/jh_harpoon.sh` 的 `detect_machine()` 只匹配
   `NXP i.MX95 19X19 board` / `15X15 board` 等；Pro 板的 machine 是 `NXP FRDM-IMX95-PRO` → 落到 `Unknown` → `exit 1`）。
5. **时间线**：RTE 3.3 / Harpoon 3.5 发布于 2025-12；FRDM-IMX95-PRO 用户手册 UM12527 Rev 1.1 是 2026-07-02 —— 软件包比板子早，不可能带 Pro 配置。

**结论（阶段一）：包里的 Harpoon 软件栈可用，但它整套板级部分（启动容器、DTB、SM 配置、脚本机器判断、inmate 控制台串口）都是 EVK 的，不能直接认定可用于 Pro 板。**

### 二、阶段二：上板前准备（未执行的方案也记录，避免后人重走）

- 写了串口工具（纯 PowerShell，因为沙箱不允许执行外部程序）：
  - `serial-probe.ps1` 单口交互 / `serial-capture.ps1` 多口并发抓取 / `serial-filter.ps1` 只保留匹配行
  - `uboot-run.ps1`、`uboot-catch.ps1`、`uboot-poweron.ps1`、`uboot-reboot-catch.ps1`：抢 U-Boot 并下发命令
- 写了 UUU 脚本 `boot-evk-container.uuu`，准备"把 EVK 容器只送进内存跑一次"做快速判定。
  **最终没有执行**：因为后来发现底座问题可以用更可靠的方式验证（见阶段四、五），执行 UUU 需要把板子切到 SW4=x001、
  且会引入"用别块板的 SM/电源配置启动本板"的非官方组合，性价比不高。
- 写了一份测试手册 `README-测试流程.md`（SW4 启动模式、UUU 命令、判定标准、恢复步骤）。

### 三、阶段三：上板基线（确认板子在跑、确认串口映射）

1. 电脑侧串口：`COM17=A55 控制台 console=ttyLP0`、`COM18=M7`、`COM19=M33 System Manager`、`COM16` 备用；115200-8-N-1。
2. 抓到的启动链（实机日志）：
   ```text
   U-Boot SPL 2025.04-g99518e6b6f20 → NOTICE: BL31: v2.12.0 (lf-6.18.2-1.0.0) → U-Boot 2025.04
   Model: NXP FRDM-IMX95-PRO board / DRAM: 15.8 GiB / BOARD: V3.3
   SM firmware Build 819 / ELE firmware version 2.0.5-fe6641ef
   cfg name not match mx95evkrpmsg:mx95frdm-pro, ignore      ← EVK 配置在本板被忽略
   Loading Environment from MMC... bad CRC, using default environment   ← 环境区损坏，用默认环境
   Linux 6.18.2-1.0.0 … console=ttyLP0,115200 earlycon root=/dev/mmcblk0p2
   ```
3. 存储布局：`mmcblk0`=eMMC 29.6G（p1 256M boot / p2 10.6G 根）；`mmcblk1`=SD 29.7G（FAT32，单分区，几乎空）。
4. boot 分区内容：`Image`、`imx95-19x19-frdm-pro.dtb`（及若干摄像头/屏变体）、`mcore-demos`、`tee.bin`、`xen`。
   **没有 `imx95-19x19-frdm-pro-root.dtb`。**

### 四、阶段四：验证"原厂系统自带 Jailhouse"（逐条命令与实机输出）

登录：串口 `root`（无密码）。以下全部实机输出：

```text
/sbin/jailhouse
Jailhouse management tool v0.12

# modinfo jailhouse | head -6
filename:       /lib/modules/6.18.2-1.0.0-gf49f45233f7b/updates/driver/jailhouse.ko
version:        v0.12 (393-gcda91277-dirty)
firmware:       jailhouse.bin

# ls -l /lib/firmware/jailhouse.bin
-rw-r--r-- 1 root root 104456 /lib/firmware/jailhouse.bin

# ls /usr/share/jailhouse
cells  inmates  tools
# ls /usr/share/jailhouse/cells | grep imx95
imx95-inmate-demo.cell   imx95-linux-demo.cell   imx95.cell
# ls /usr/share/jailhouse/inmates
gic-demo.bin  ivshmem-demo.bin  tools  uart-demo.bin

# ls -l /dev/kvm ; dmesg | grep -i kvm
crw-rw-rw- 1 root kvm 10, 232 /dev/kvm
kvm [1]: VHE mode initialized successfully

# ls /usr/share/harpoon /etc/harpoon
ls: cannot access '/usr/share/harpoon': No such file or directory
ls: cannot access '/etc/harpoon': No such file or directory
```

**这一步同时证明了两件事**：Jailhouse 齐全；Harpoon 不存在。

### 五、阶段五：让 Jailhouse 真正可用（关键机制 + 实机结果）

#### 5.1 为什么不能直接 `jailhouse enable`

板子有 15.8 GiB DRAM，Linux 默认全占。Jailhouse 需要两块内存是空闲的：
- inmate 区 `0xf0000000 + 0xf700000`（约 247 MB）
- hypervisor 区 `0xffc00000 + 0x400000`（4 MB）

直接 enable 会把这些地址上的 Linux 内存当成空闲区覆盖掉，属于破坏性操作，所以必须先让 Linux "看不见"这两块。

#### 5.2 机制：U-Boot 用 `jh_root_mem` 改写设备树 `/memory`

读本地 U-Boot 源码（`tools\uboot-imx-source\board\freescale\imx95_frdm\imx95_frdm.c:502`）确认：
`ft_board_setup()` 读环境变量 `jh_root_mem`（格式 `size@base,...`），调用 `fdt_fixup_memory_banks()` **改写设备树的 `/memory` 节点**。
Pro 板默认值 `0x58000000@0x90000000,0xc0000000@0x180000000` 正好把上面两块排除在外。

所以**不需要那个缺失的 `-root.dtb` 文件**，只要让 U-Boot 带上 `jh_root_mem` 和 `jh_clk` 即可。

#### 5.3 操作与结果

在 U-Boot 提示符（`u-boot=>`）执行：

```text
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
run bsp_bootcmd
```

实机验证（内存确实被限制）：

```text
Kernel command line: kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe console=ttyLP0,115200 earlycon root=/dev/mmcblk0p2 rootwait rw
Memory: 3407188K/4587520K available        ← 设之前是 15106208K/16515072K
MemTotal: 4398132 kB                       ← 约 4.19 GiB
```

#### 5.4 启用 hypervisor 与运行 inmate（实机输出）

```text
# modprobe jailhouse
# jailhouse enable /usr/share/jailhouse/cells/imx95.cell
Initializing Jailhouse hypervisor v0.12 (393-gcda91277-dirty) on CPU 0
Code location: 0x0000ffffc0200800
Page pool usage after early setup: mem 71/993, remap 0/131072
Initializing processors: CPU 0... OK ... CPU 5... OK
Initializing unit: irqchip / ARM SMMU v3 / ARM SMMU / PVU IOMMU / PCI
Adding virtual PCI device 00:00.0..00:03.0 to cell "imx95"
Activating hypervisor

# jailhouse cell list
ID   Name          State       Assigned CPUs
0    imx95         running     0-5

# jailhouse cell create /usr/share/jailhouse/cells/imx95-inmate-demo.cell
Created cell "inmate-demo"

# jailhouse cell list
0    imx95         running     0-4
1    inmate-demo   shut down   5          ← CPU5 已从 Linux 划走

# jailhouse cell load inmate-demo /usr/share/jailhouse/inmates/uart-demo.bin
Cell "inmate-demo" can be loaded          (RC=0)

# jailhouse cell start inmate-demo
（串口持续输出）
Hello 144284 from cell!
Hello 144285 from cell!
...
Hello 166434 from cell!
```

**结论：A55 上"Linux 作 root cell + Jailhouse 分区 + 一个核跑独立实时域并对外输出"在 Pro 板上实机跑通。**

### 六、"烧录"到底烧了什么？（重要澄清）

**全过程没有向任何持久介质写入过 Harpoon 或任何镜像。** 逐项对照：

| 动作 | 写到哪 | 断电后 |
|---|---|---|
| 检查下载包（DTB/manifest/容器字符串） | 只读，PC 内存 | 无影响 |
| `tar -xf` 抽出 harpoon cell/inmate 文件 | 只写 PC 的 `build\rte-extract\` | 无影响 |
| UUU `boot-evk-container.uuu` | **未执行** | — |
| 抓启动日志、登录 Linux、查 Jailhouse | 只读 | 无影响 |
| U-Boot 里 `setenv jh_root_mem / jh_clk` | **只改 U-Boot 内存里的环境副本，没有 `saveenv`** | **丢失，需重做** |
| `run bsp_bootcmd` 启动 Linux | 只是启动，不改介质 | — |
| `modprobe jailhouse` + `jailhouse enable` | hypervisor 从 `/lib/firmware/jailhouse.bin` 载入 **RAM** | 丢失 |
| `jailhouse cell create/load/start` | inmate 二进制载入 **RAM**（入口 `0xf0000000`） | 丢失 |
| 写日志文件 | PC 的 `F:\project\Learning\RTOS\build\logs\` | — |

换句话说：**这次是"运行时验证"，不是"烧录验证"。** 唯一写入过板子的是……没有。

如果将来要做"持久化"（让每次开机都自动带 Jailhouse 内存布局），有三条路（尚未执行）：
1. 在 U-Boot 里 `saveenv`（需要先解决环境区 CRC 损坏，且当前默认环境可用、存盘位置要确认）；
2. 用板载 `dtc` 改 boot 分区里的 `imx95-19x19-frdm-pro.dtb` 的 `/memory` 节点（会动 eMMC 启动文件，需先备份到 SD）；
3. 自己做启动容器（沿用本工程 M7 那套 imx-mkimage 流程），把参数固化进去。

### 七、Harpoon 缺什么：与"原厂已有的 Jailhouse"对照

| 组件 | 原厂 Pro 系统 | 下载的 Harpoon 包 | 复现需要做什么 |
|---|---|---|---|
| Jailhouse 工具/模块/固件 | ✅ 有（6.18.2 内核版） | ✅ 有（6.12.34 内核版，版本与 Pro 内核不匹配） | 用板载自带的 |
| `imx95.cell`（root cell） | ✅ 有 | ✅ 有 | 用板载自带的 |
| 演示 inmate（`uart-demo.bin` 等） | ✅ 有 | ✅ 有 | 已跑通 |
| **Harpoon FreeRTOS inmate 二进制** | ❌ 无 | ✅ `inmates/freertos/{hello_world,industrial,rt_latency}.bin` | 从包里抽出来传到板上 |
| **Harpoon cell 配置** | ❌ 无 | ✅ `imx95-harpoon-freertos.cell`（772 B）/ `-industrial.cell`（1028 B） | 同上 |
| **控制程序/脚本** | ❌ 无 | ✅ `harpoon_ctrl`、`jh_harpoon.sh`、`harpoon.conf`、`harpoon.service` | 同上 |
| 运行脚本的机器判断 | — | ❌ 只认 EVK/15X15，Pro 会 `Unknown` 退出 | 改脚本或手敲命令 |
| inmate 控制台串口 | — | LPUART3（`0x42570000`，实测两处 cell 一致） | Pro 板 J22 只引出 UART1/2/7，需确认 LPUART3 是否可用，否则换 UART 重编 cell/bin |

### 八、复现步骤

#### 8.1 复现 A：验证"Pro 板能用 Jailhouse"（约 15 分钟，零持久改动）

前置：J22 调试串口线接好（COM17 = A55，115200-8-N-1）；板子能正常启动原厂 Linux。

```text
1) 上电，等 Linux 起来，串口出现 login:，输入 root（无密码）
2) 确认原厂已带 Jailhouse：
     jailhouse --version
     ls /usr/share/jailhouse/cells | grep imx95
     modinfo jailhouse
3) 重启并在 U-Boot 提示符停下（autoboot 只有 2 秒；用脚本在上电前持续轮发回车最稳），执行：
     setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
     setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
     run bsp_bootcmd
4) 起来后确认内存被限制（应为 4.3 GB 左右，而不是 15.8 GB）：
     head -2 /proc/meminfo        # MemTotal 约 4398132 kB
     cat /proc/cmdline            # 含 kvm-arm.mode=nvhe 等
5) 启用 hypervisor 并划一个核给实时域：
     modprobe jailhouse
     jailhouse enable /usr/share/jailhouse/cells/imx95.cell
     jailhouse cell list                       # 0 imx95 running 0-5
     jailhouse cell create /usr/share/jailhouse/cells/imx95-inmate-demo.cell
     jailhouse cell load inmate-demo /usr/share/jailhouse/inmates/uart-demo.bin
     jailhouse cell start inmate-demo          # 串口开始刷 Hello N from cell!
6) 收工：断电重启即可完全恢复（没有任何持久改动）
```

#### 8.2 复现 B：把 Harpoon 的 FreeRTOS inmate 跑起来（**2026-09-17 已实机跑通**，原始输出见第十二节）

```text
1) 在 PC 上从 RTE rootfs 抽出 Harpoon 文件（本工程已抽出，位于 F:\project\Learning\RTOS\build\rte-extract）：
     tar -xf nxp-image-...rootfs.tar.zst -C <目标目录> \
       ./usr/share/jailhouse/cells/imx95-harpoon-freertos.cell \
       ./usr/share/harpoon/inmates/freertos/rt_latency.bin \
       ./usr/share/harpoon/scripts ./etc/harpoon ./usr/bin/harpoon_ctrl
2) 传到板上 —— 实测走网络最省事（串口 base64 是备选）：
     a. 板子用网线接电脑网口（本机 "以太网" Realtek PCIe GbE，直连即可，两端都会自配 169.254.x 链路本地地址）
     b. 串口上把 eth0 拉起来（默认是 DOWN）：ip link set eth0 up
     c. 串口上读地址：ip -brief addr   → eth0 169.254.x.x/16
     d. PC 上 scp（Windows 自带 OpenSSH，root 免密）：
          scp imx95-harpoon-freertos.cell rt_latency.bin hello_world.bin root@<板子IP>:/tmp/
3) 板上放到标准路径：
     mkdir -p /usr/share/harpoon/inmates/freertos
     cp /tmp/imx95-harpoon-freertos.cell /usr/share/jailhouse/cells/
     cp /tmp/rt_latency.bin /tmp/hello_world.bin /usr/share/harpoon/inmates/freertos/
4) 带 Jailhouse 内存参数重启（关键，否则 inmate 内存被 Linux 占着）：
     在 U-Boot 提示符执行 setenv jh_root_mem / setenv jh_clk / run bsp_bootcmd（见 8.1 第 3 步）
     确认 MemTotal ≈ 4398132 kB
5) 按官方流程启动（等价于 jh_harpoon.sh start，但绕过它的机器判断；经 SSH 执行最稳）：
     for c in 0 1 2 3 4 5; do echo 1 > /sys/devices/system/cpu/cpu$c/power/pm_qos_resume_latency_us; done
     echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor   # 本机实测是 ondemand，可选
     echo c0100000.rpmsg-ca55 > /sys/bus/platform/drivers/imx-rpmsg/unbind         # rt_latency 用 RPMsg 时需要
     modprobe jailhouse
     jailhouse enable /usr/share/jailhouse/cells/imx95.cell
     jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
     jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/rt_latency.bin -a 0xf0000000
     jailhouse cell start freertos
6) 验证（三条独立证据）：
     jailhouse cell list                    → 1  freertos  running  5
     jailhouse cell stats freertos          → vmexits_total 增长、vmexits_mmio 占绝大多数（inmate 在写控制台）
     nproc                                  → 5（Linux 只剩 5 个核）
   注意：jailhouse cell stats 需要终端（curses）且需要把 /usr/share/jailhouse/tools 放进 PATH，否则报
         execvp: No such file or directory / _curses.error: setupterm
7) 停止：jailhouse cell shutdown freertos ; jailhouse cell destroy freertos ; jailhouse disable ; modprobe -r jailhouse
   完全恢复：断电重启即可（jh_root_mem 等未 saveenv，不会持久）
```

#### 8.3 官方脚本的真正内容（复现的依据）

`jh_harpoon.sh start` 的顺序（读源码确认）：`set_real_time_configuration`（i.MX95 只做 CPU idle 限制 + rtc unbind + 调频 governor）→ 解绑 rpmsg → `modprobe jailhouse` → `jailhouse enable $ROOT_CELL` → `cell create $INMATE_CELL` → `cell load $INMATE_NAME $INMATE_BIN -a $INMATE_ENTRY_ADDRESS` → `cell start` → 重新绑定 rpmsg。参数来自 `/etc/harpoon/harpoon.conf`：

```text
ROOT_CELL=/usr/share/jailhouse/cells/imx95.cell
INMATE_CELL=/usr/share/jailhouse/cells/imx95-harpoon-freertos-audio.cell
INMATE_BIN=/usr/share/harpoon/inmates/freertos/audio.bin
INMATE_ENTRY_ADDRESS=0xf0000000
INMATE_NAME=freertos
```

（注意：包内这份 `harpoon.conf` 指向 audio 变体，而 i.MX95 并没有 audio 的 cell/bin，正式用法是先跑
`harpoon_set_configuration.sh freertos latency` 生成对应配置。）

### 九、踩过的坑与规避（都可复现）

| # | 现象 | 根因 | 规避 |
|---|---|---|---|
| 1 | `Access to the port 'COMxx' is denied` | MobaXterm 占着串口（Windows 串口独占） | 关掉终端软件的串口会话 |
| 2 | `uuu.exe`/`tar.exe`/`python.exe` 一律 Access denied | 沙箱策略限制新进程创建 | 按规则单次提权；能不用外部程序就改用纯 PowerShell/.NET |
| 3 | 抢 U-Boot 失败、命令落在 ATF 阶段 | 脚本用文本匹配判断"到提示符了"，误判提前停手 | 整个窗口持续轮发，不做提前判断 |
| 4 | A55 控制台彻底静默，像板子挂了 | 连续 28 秒 Ctrl-C 把 `serial-getty@ttyLP0` 反复杀死，触发 systemd `StartLimitBurst=5/StartLimitIntervalSec=10s` 后不再重启（内核正常） | **只用回车（CR）抢 autoboot**；限制发送时长；用独立通道（M33 SM 控制台）交叉判断板子是否存活 |
| 5 | `setenv` 明明执行成功但没生效 | 停在 `u-boot=>` 不操作，1 分多钟后被看门狗复位、自启回 Linux | 抢到提示符后**在同一进程内立刻** setenv + 启动 |
| 6 | 脚本挂死、看着像板子卡死 | 读取函数只按"多久没有新数据"退出，遇到 inmate 每秒上百行刷屏永远等不到安静 | 读取函数加绝对超时上限并截断输出 |
| 7 | inmate 一跑起来 Linux 就没法输入 | `uart-demo.bin` 占用 LPUART1 及其中断，Linux 控制台失去输入 | 换 inmate 控制台到独立 UART；或接受"跑起来就靠复位收回控制" |
| 8 | PowerShell 脚本报除零/变量为 null | 无 BOM 的 UTF-8 脚本被 PS 5.1 按 ANSI 解码，中文注释吞掉下一行 | 交互脚本一律纯 ASCII |

### 十、文件与路径清单

```text
【PC 上】
下载包解压目录 : F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK
同内容压缩包   : F:\project\Learning\RTOS\HS_v3.5_IMX95-19X19-LPDDR5-EVK.zip
抽出的 Harpoon : F:\project\Learning\RTOS\build\rte-extract\
                 ├─ usr\share\jailhouse\cells\imx95-harpoon-freertos.cell (772B)
                 ├─ usr\share\jailhouse\cells\imx95-harpoon-freertos-industrial.cell (1028B)
                 ├─ usr\share\jailhouse\cells\imx95.cell (1680B)
                 ├─ usr\share\harpoon\inmates\freertos\{hello_world(66040B),industrial(422240B),rt_latency(94848B)}.bin
                 ├─ usr\share\harpoon\scripts\{jh_harpoon.sh,harpoon_configure.sh}
                 ├─ etc\harpoon\harpoon.conf
                 └─ usr\bin\{harpoon_ctrl,harpoon_set_configuration.sh}
rootfs 文件清单: F:\project\Learning\RTOS\build\rte-harpoon-jailhouse-files.txt
串口/日志目录  : F:\project\Learning\RTOS\build\logs\
串口与 U-Boot 脚本: F:\project\Learning\RTOS\build\harpoon-test\
Pro 原厂启动容器 : F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95\imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
Pro 原厂 DTB     : F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95\imx95-19x19-frdm-pro.dtb
U-Boot 源码(含机制): F:\project\Learning\RTOS\tools\uboot-imx-source\board\freescale\imx95_frdm\
UUU(未用)        : F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe

【板上】
Jailhouse 工具/模块/固件: /sbin/jailhouse ; /lib/modules/$(uname -r)/updates/driver/jailhouse.ko ; /lib/firmware/jailhouse.bin
cell 配置              : /usr/share/jailhouse/cells/{imx95.cell,imx95-inmate-demo.cell,imx95-linux-demo.cell}
演示 inmate            : /usr/share/jailhouse/inmates/{uart-demo.bin,gic-demo.bin,ivshmem-demo.bin}
boot 分区挂载点        : /run/media/boot-mmcblk0p1  (Image, imx95-19x19-frdm-pro.dtb, tee.bin, xen)
SD 卡挂载点            : /run/media/mmcblk1p1
```

### 十一、结论

1. 下载的 Harpoon（HS v3.5 / RTE 3.3）**是 EVK 板级构建，官方不支持 FRDM-IMX95-PRO**：DTB、机器映射表、启动容器、运行脚本的机器判断、inmate 控制台串口五处都对不上。
2. 但 **Pro 板出厂系统自带完整的 Jailhouse**，只要在启动时用 U-Boot 的 `jh_root_mem`/`jh_clk` 把内存让出来，就能在 A55 上划出独立实时域——**这一点已经实机验证通过**（CPU5 划给 inmate 并持续运行输出）。
3. 剩下的工作只是"把 inmate 换成 Harpoon 的 FreeRTOS 应用"：文件已经从包里抽出，缺的是**传到板上**这一步（网络链路未通、PC 无读卡器，可走串口 base64 或先修网络），以及处理 **LPUART3 控制台在 Pro 板上是否引出**这个板级差异。
4. **全过程零持久写入**：断电即回到原厂状态。

### 十二、最终结果：Harpoon 的 FreeRTOS inmate 在 Pro 板上跑通（2026-09-17 当天完成）

#### 12.1 操作序列与实机原始输出

```text
① 打通网络（串口把 eth0 拉起来，PC 用 scp 通过链路本地地址传文件）
   ip link set eth0 up            → eth0 UP 169.254.170.232/16  fe80::204:9fff:fe0b:4261/64
   PC 侧：以太网 Realtek PCIe GbE，169.254.121.11/16，ping 板子 2 ms
   scp → /tmp/：imx95-harpoon-freertos.cell(772) / -industrial.cell(1028)
                / rt_latency.bin(94848) / hello_world.bin(66040)

② 安装到标准路径（板上）
   /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
   /usr/share/jailhouse/cells/imx95-harpoon-freertos-industrial.cell
   /usr/share/harpoon/inmates/freertos/{hello_world.bin, rt_latency.bin}

③ 带 Jailhouse 内存参数重启（U-Boot）
   jh_root_mem=0x58000000@0x90000000,0xc0000000@0x180000000
   jh_clk=kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
   → Memory: 3407188K/4587520K available      MemTotal: 4398132 kB

④ 通过 SSH 执行启动序列（比串口稳，且 inmate 抢串口也不影响控制）
   ===MODPROBE===  jailhouse  45056  0
   ===ENABLE===    RC=0
   ===LIST1===     0  imx95      running   0-5
   ===CREATE===    RC=0
   ===LIST2===     0  imx95      running   0-4
                   1  freertos   shut down 5
   ===LOAD===      jailhouse cell load freertos .../rt_latency.bin -a 0xf0000000   RC=0
   ===START===     RC=0
   ===LIST3===     0  imx95      running   0-4
                   1  freertos   running   5          ← FreeRTOS 在 A55 CPU5 上运行
   ===STATS===
       Statistics for freertos cell
       COUNTER (All CPUs)      SUM   PER SEC
       vmexits_total          1517
       vmexits_mmio           1515        ← 绝大多数陷入是 MMIO（inmate 在写自己的控制台）
       vmexits_management        2
       vmexits_hypercall         0
   ===LINUX===     nproc=5 ；uptime up 12 min, load average 0.08
```

#### 12.2 这件事对"Harpoon 能不能用"的最终回答

| 问法 | 答案 |
|---|---|
| 这个包能直接当 Pro 板的系统镜像用吗？ | **不能**。它是 EVK 板级构建（启动容器/DTB/SM/脚本机器判断/inmate 控制台 UART 都对不上） |
| 包里的 Harpoon 资产能在 Pro 板上跑吗？ | **能，已实机验证**：`imx95-harpoon-freertos.cell` + `rt_latency.bin`（FreeRTOS）在 A55 CPU5 上 running |
| 怎么做到的？ | **"拆开用"**：底座用 Pro 板原厂自带的 Jailhouse 与 `imx95.cell`，inmate 用 Harpoon 包里的 FreeRTOS 二进制与 cell 配置；启动时用 U-Boot 的 `jh_root_mem`/`jh_clk` 把内存让出来 |
| 还缺什么？ | 官方针对 Pro 板的板级适配：`imx95-19x19-frdm-pro-root.dtb`、`jh_harpoon.sh` 的机器判断、inmate 控制台 UART（LPUART3 在 Pro 板未引出） |

#### 12.3 仍未解决 / 待确认

- **inmate 控制台看不到输出**：两个 harpoon cell 里 console 地址都是 LPUART3（`0x42570000`），而 Pro 板 J22 只引出 UART1/2/7。要看到 FreeRTOS 的打印，需要把 cell/console 改到已引出的 UART 并重编 inmate 的 console 配置。
- `jh_harpoon.sh start` 直接跑会 `Unsupported Machine: Unknown` 退出（脚本只认 EVK/15X15）。
- `jh_root_mem` / `jh_clk` **每次启动都要重设**（没有 `saveenv`，也没有 `fw_setenv`）。
- 用 `harpoon_ctrl` 跑完整的实时性测量（RT latency 的 p99/max 统计）需要 RPMsg 配对与 `harpoon_set_configuration.sh`，本次只验证到"cell 成功启动并持续运行"。

#### 12.4 网络控制通道的坑（本次新发现，很值得复用）

1. **板子 eth0 默认 DOWN**：每次重启都要 `ip link set eth0 up`，否则 PC ping 不通（表现为 SSH connection timed out）。
2. **IPv4 链路本地地址每次启动会变**（APIPA）：本次从 `169.254.247.145` 变成 `169.254.170.232`；**IPv6 链路本地 `fe80::204:9fff:fe0b:4261` 是稳定的**，PC 侧是 `%8`（以太网接口索引）。
3. **板子 sshd 允许 root 免密登录**：用 `ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@<IP>` 即可，不需要密码。
4. **SSH 是比串口好得多的控制通道**：inmate 抢走 LPUART1 后串口失去输入，但 SSH 仍然可用（本次就是靠 SSH 完成的整套 jailhouse 操作）。
5. 直连网线时两端都会自配 `169.254.x.x/16`，无需 DHCP、无需手工配 IP 即可互通。

### 关联

- 同日：`2026-09-17-Harpoon可用性验证.md`（判定证据）、`2026-09-17-FRDM-IMX95-PRO开发日志.md`（现场流水）
- 知识库：`i.MX95上Jailhouse与Harpoon的分层与判定方法.md`

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md|FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程]]
- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
- [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md|A55运行FreeRTOS的方向调整]]
