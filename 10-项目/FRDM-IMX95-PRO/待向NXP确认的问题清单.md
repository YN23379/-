---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 已整理
evidence: 实机验证
tags: [协议, 启动, 多核与异构, 存储, Harpoon, Jailhouse, UART, i.MX95]
updated: 2026-09-21
---

# 待 NXP 确认（精简版，可直接发群）

> 整理：2026-09-17，2026-09-21 更新（问题 1 已按实机测量结果重写）。
> 板卡：**FRDM-IMX95-PRO**（i.MX95 B0，19x19 封装，LPDDR5 16GB，eMMC 32GB）。
> 目标：在该板的 **1–2 个 Cortex-A55 核**上跑 **FreeRTOS**，方案选 **Harpoon（Real-Time Edge）**。
> 证据标注沿用本库口径：**官方资料明确说明 / 源码确认 / 实机验证 / 教材课程 / 推测 / 不适用**。

---

## 问题 1：Harpoon 在 FRDM-IMX95-PRO 上应该怎么走？

**我们做到哪一步了（简述）**

1. 下载了 **Harpoon Software v3.5 / Real-Time Edge 3.3**，发现它只提供 **i.MX95 19x19 LPDDR5 EVK** 的板级包，FRDM-IMX95-PRO 不在 `meta-nxp-harpoon` 的支持矩阵里（DTB、启动容器、SM 配置、运行脚本的机器判断都是 EVK 的）。
2. 但 Pro 板原厂系统**自带完整 Jailhouse**（`/sbin/jailhouse`、`jailhouse.ko`、`/lib/firmware/jailhouse.bin`、`/usr/share/jailhouse/cells/imx95.cell`）。我们用"**底座用板子的 Jailhouse + inmate 用 Harpoon 包里的 `imx95-harpoon-freertos.cell` + `rt_latency.bin`**"的方式，已经让 **FreeRTOS 在 A55 的 CPU5 上跑起来**（`jailhouse cell list` → `freertos running 5`，`cell stats` 里 `vmexits_mmio` 持续增长）。

**三个卡点，请指导**

1. **inmate 控制台完全没有输出，已定位到 LPUART3 引脚归属**（详见下方"卡点 1 展开"）
2. **缺 `imx95-19x19-frdm-pro-root.dtb`**：U-Boot 的 `jh_root_dtb` 指向这个文件，但板的 boot 分区里只有 `imx95-19x19-frdm-pro.dtb`。
   现在的临时做法是在 U-Boot 里手工 `setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000` + `jh_clk …` 才能让 Linux 只占 4.4 GB、把 inmate/hypervisor 内存让出来，**断电即失效**。
   → 这个 root DTB 官方有吗？或有正确的生成方法（是否就是"板级 DTB + reserved-memory 节点"）？
3. **扩到 2 个 A55 核**：官方推荐"**一个 cell 里放 2 个 A55 核**"还是"**两个 cell 各 1 核**"？多核 FreeRTOS（SMP）在这个场景是否支持、有无已知限制？

### 卡点 1 展开：inmate 控制台无输出，已收敛到 LPUART3 的引脚归属

**环境与复现步骤（实机验证）**

板卡 FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB），底座用板子原厂系统自带的 Jailhouse，inmate 用 Harpoon Software v3.5 / Real-Time Edge 3.3 包里的 `imx95-harpoon-freertos.cell` 与 `rt_latency.bin`：

```
jailhouse enable imx95.cell
jailhouse cell create imx95-harpoon-freertos.cell
jailhouse cell load freertos rt_latency.bin -a 0xf0000000
jailhouse cell start freertos
```

**cell 本身是跑起来的**（实机验证）：`jailhouse cell list` 显示 `1 freertos running 5`；cell 内 `nproc` 返回 5；`jailhouse cell stats freertos` 的 `vmexits_mmio` 为 1515 且持续增长。也就是说 A55 侧的 inmate 确实在执行、确实在访问 MMIO。

**唯一的问题是：inmate 控制台一个字符都不输出。** 排查到三条互相印证的测量结果：

| 测量 | 结果 | 判断 |
|---|---|---|
| `jailhouse console -f` | 只输出 hypervisor 自己的消息：`Initializing Jailhouse hypervisor v0.12`、CPU 0–5 OK、`Activating hypervisor`、`Created cell "freertos"`、`Started cell "freertos"`；**没有一行来自 FreeRTOS** | inmate 根本没走 Jailhouse 虚拟控制台通道 |
| 板上 `/proc/tty/driver/*` | Linux 域只注册了 3 个 LPUART：**LPUART0**（mmio `0x44380010`，console）、**LPUART4**（`0x42590010`，tx:0 rx:0）、**LPUART5**（`0x425A0010`，tx:0 rx:0）；**没有 LPUART3** | Harpoon cell 里 inmate 控制台用的 LPUART3 不在 Linux 域 |
| `debugfs` 的 `/sys/kernel/debug/pinctrl/scmi_dev.8-scmi-pinctrl-imx/pinmux-pins`（共 129 个 pin） | 全部 uart 相关项只有 `uart1rxd/uart1txd/uart2rxd/uart2txd`，**没有任何 uart3 引脚** | LPUART3 的 TX 引脚从来没被 mux 成 UART 功能 |

补充两条现场事实：

- 与 inmate 控制台对应的引脚 `gpioio14`（pin 18 = J15-8）和 `gpioio15`（pin 19 = J15-10）在该表中的状态是 `(MUX UNCLAIMED) (GPIO UNCLAIMED)`；J15-8 上用逻辑分析仪长时间观察，**没有任何电平跳变**。
- **`UNCLAIMED` 不等于这个脚没被使用**（源码确认）：该表只覆盖"已委派给 Linux 域"的引脚，对 M7 域是盲区。反证是 M7 侧工程此前用 J15-8 / J15-10 做过可用的 GPIO 回环（实机验证），说明这两个脚物理上是通的、能被 M7 域驱动。
- 该 debugfs 路径名是 `scmi_dev.8-scmi-pinctrl-imx`，说明 Linux 侧的引脚配置是经 **SCMI 交由 System Manager（AON M33）** 下发的，Linux 并不直接写 IOMUX（源码确认）。

**我们的结论（推测，请确认）**：这份 cell 来自 **i.MX95 19x19 LPDDR5 EVK** 的板级包。在 EVK 上 LPUART3 归 Linux 域，在 FRDM-IMX95-PRO 上不归。于是 inmate 老老实实往 LPUART3 的寄存器里写数据，但对应引脚始终没有 mux 到 UART3，芯片外面自然什么都测不到。这属于**配置与来源问题，不是接线问题、也不是工具链问题**。

**读了 UG10170 之后，我们把这个结论又推进了一步（关键）**

对照 Harpoon 用户指南 **UG10170 Rev 3.3（`HRPNUG_3.3.pdf`）**：

- **§1.5**：`Harpoon provides a custom System Manager configuration that describes the hardware used for its applications, such as the TPM and LPUART usage for its guest cell.`
  → 也就是说 **guest cell 用哪一路 LPUART，是写在 Harpoon 定制的那份 SM 配置里的**，不是只写在 cell 配置里。
- **§1.4**：cell 配置的源码在 Harpoon meta-layer 的 Jailhouse recipe 补丁里，文件是 `configs/arm64/imx95-harpoon-freertos.c`。
- **§3.1**：官方支持的板卡只有 **i.MX 95 15x15 LPDDR4x EVK** 和 **i.MX 95 19x19 LPDDR5 EVK**，**没有 FRDM-IMX95-PRO**。

所以我们的理解是：**EVK 的 SM 配置把 LPUART3 分给了 guest cell，而 Pro 板的 SM 配置没有**。
这就是"改了 cell 也不一定能通"的原因——**要同时改 SM 配置和 cell 配置**。

**请确认并给出修正件：**

1. 在 **FRDM-IMX95-PRO** 上，**LPUART3 的引脚归哪个域所有**？是否 LPUART3 被分配给 **M7** 而不是 Linux 域，这就是没有输出的原因？
2. **能否提供 Harpoon 定制的那份 SM 配置（源码或说明）**，以及对应的 `imx95-harpoon-freertos.c`？我们想看清楚 guest cell 的 LPUART 是怎么分配的，好判断在 Pro 板上应该换成哪一路。
3. 请提供一份 **inmate 控制台改用 LPUART4（`0x42590000`）或 LPUART5（`0x425A0000`）** 的 `imx95-harpoon-freertos.cell`（含配套 SM 配置）——这两路已经注册在 Linux 域且当前空闲（`tx:0 rx:0`）。
4. 如果本板 **LPUART4 / LPUART5 没有物理引出**，那么应该用哪一路 LPUART？请一并给出配套的 cell。
5. **FRDM-IMX95-PRO 是否被 Harpoon / Real-Time Edge 官方支持**？有没有针对该板的 cell 集合？
6. （核数确认）UG10170 §1.4 写明 i.MX 95 的 inmate cell 是 **CPU5 单核**（`.cpus = { 0b100000, }`），我们的实测与此一致。若要做到 **2 个 A55 核**，官方推荐"SMP cell 里放 2 核"（`.cpus = { 0b110000, }`）还是别的做法？i.MX 95 上有没有已知限制？

> **参考**：UG10170 §1.4 还给了 2 核的写法（原文举例是 i.MX 8M）：
> `For a multicore (SMP) cell, two cores can be used. For instance, on i.MX 8M: .cpus = { 0b1100, }`
> —— 即改位图后重编 cell。但如果**官方只在 i.MX 8M 上验证过 SMP**，我们希望确认 i.MX 95 是否同样可用。

---

## 问题 2：这块板子用 J-Link 调试/下载应该怎么接？

**我们查原理图（SPF-95794_B1，第 26 页）的结果**：SoC 的 DAP 脚
`DAP_TCLK_SWCLK`(AG21)、`DAP_TMS_SWDIO`(AH22)、`DAP_TDI`(AK24)、`DAP_TDO_TRACESWO`(AJ23)
**只引到测试点**：`JTAG_CLK_TP / JTAG_TMS_TP / JTAG_TDI_TP / JTAG_TDO_TP / JTAG_RST_TP`，
图上注明 **"Use test points to trigger JTAG."**，板上**没有 JTAG 座**。

请确认：

1. 这 5 个测试点在板上的**具体位置与丝印编号**（TP 号）？**VTREF 与 GND** 从哪里取？DAP 侧 I/O 是 **1.8 V 还是 3.3 V**（我们不敢直接按 3.3 V 接）？
2. 有没有**官方转接件/排线**（20-pin J-Link 标准口 → 这些测试点）？或推荐的接线方式（SWD 只用到 CLK/TMS/GND/VTREF 是否可行）？
3. 用 J-Link 能否**调试 A55 上运行的 FreeRTOS / Jailhouse inmate**（不只 M33/M7）？需要什么额外条件（halt 时机、是否需要 ATF/U-Boot 配合）？

---

## 问题 3：资料索取

请提供：

1. **i.MX95 参考手册（RM）**——重点是 **Boot ROM、Memory Map、TRDC/RDC** 三章。要看的是：LPUART 各实例在 RDC/TRDC 里的默认域归属表、外设 Memory Map，以及 Boot ROM 的启动镜像与前置安排。
2. ~~**Harpoon 用户指南 UG10170**~~ → **已拿到**（`HRPNUG_3.3.pdf`，Rev 3.3），不用再给。
3. **Harpoon 定制版 SM 配置**（UG10170 §1.5 提到它描述了 guest cell 的 TPM / LPUART 分配）——**这是解决"看不到输出"的关键**，也是我们目前最缺的一份。
4. **`imx95-19x19-frdm-pro-root.dtb`**（目前仍然缺失，见问题 1 卡点 2）。
5. **FRDM-IMX95-PRO 专用的 Jailhouse cell 集合**，或至少一份**书面支持声明**：本板在 Harpoon / Real-Time Edge 里是否被支持、支持到什么程度。

### 资料出处与适用范围说明（便于你们判断我们缺什么）

| 我们手里的资料 | 来源 | 缺什么 |
|---|---|---|
| FRDM-IMX95-PRO 板级 DTB / U-Boot | 板子出厂 boot 分区 | 只有 `imx95-19x19-frdm-pro.dtb`，没有 `…-root.dtb` |
| Jailhouse 二进制、`imx95.cell` | 板子原厂 rootfs | 无源码配置说明（哪个域拿哪些外设） |
| `imx95-harpoon-freertos.cell`、`rt_latency.bin` | Harpoon v3.5 / RTE 3.3 包（在 `rootfs.tar.zst` 内，`usr/share/jailhouse/cells/` 与 `usr/share/harpoon/inmates/freertos/`） | 是 EVK 的，不是 Pro 的；且包内**无 `.c` 源码**，源码在 `github.com/NXP/harpoon-apps` |
| 板级原理图 SPF-95794_B1、UM12527 | NXP 公开文档 | 引脚到域的归属表（J15/J22 那一段） |
| **Harpoon 用户指南 UG10170 Rev 3.3** | NXP 公开文档（`HRPNUG_3.3.pdf`，86 页） | **已有**；但 §1.5 提到的**定制版 SM 配置**我们拿不到，见问题 3 第 3 条 |

我们的复现过程、每一步命令和板上原始 log 记在 [[10-项目/FRDM-IMX95-PRO/Harpoon复现-手把手操作.md|Harpoon 复现：手把手操作]] 里，需要的话可以直接对照。

---

## 附：已自行确认、不必回答（避免占用时间）

| 事项 | 我们的结论 | 依据 |
|---|---|---|
| `boot[]` / `skip` / `mSel` 语义 | `boot[]`=按 mSel 的 LM 启动顺序；`skip` 是"容器无镜像时不报错"；`mSel` 是启动配置档位（Pro 板有 3 档，实机用 mSel=0） | `imx-sm/sm/doc/config.md` 330–388 行 + 生成的 `config_lmm.h` |
| 上电启动顺序 | AON **M33 先跑 Boot ROM → 加载 SM**；SM 写 TRDC/RDC 隔离后再按 `boot[]` 拉起 M7、A55；**A55 集群只由 SM 释放 CPU0**，C1–C5 由 OS/固件用 PSCI 启动 | SM 官方 README + `arch.md` + `config_lmm.h` 启动表 |
| J22 调试口的硬件形态 | J22 是 **USB Type-C**，经 **CH9114F 四路 UART 桥**接到 SoC，4 个 COM 口就是这颗桥的 4 个通道 | UM12527 §2.19（**官方资料明确说明**） |
| 串口物理通道与域的对应 | CH9114F 各通道到 A55 / M33(SM) / M7 的映射**官方明确写了"不固定"**，不能当成 COM 号到核的固定映射 | UM12527 §2.19 + `mx95frdm-pro.cfg`；**实机验证**当前这台机器上是 COM17=LPUART1、COM18=LPUART7、COM19=LPUART2 |
| Pro 板能否用 Jailhouse | 能，已实机跑通 Harpoon 的 FreeRTOS inmate（A55 CPU5）；只是 inmate 控制台这一路 UART 的引脚没配起来（见问题 1） | `jailhouse cell list` / `cell stats`、`jailhouse console -f`、`/proc/tty/driver/*`、pinctrl debugfs（**实机验证**） |
| inmate 分几个核 | **CPU5 单核**，与官方定义一致；UG10170 §1.4 原文 `.cpus = { 0b100000, }` | UG10170 §1.4（**官方资料明确说明**）+ 实机 `cell list`（**实机验证**） |
| 官方支持哪些板子 | 只有 **i.MX 95 15x15 LPDDR4x EVK** 和 **i.MX 95 19x19 LPDDR5 EVK**，**不含 FRDM-IMX95-PRO** | UG10170 §3.1（**官方资料明确说明**） |
| 官方预期应该有输出 | 跑 `hello_world` 时 inmate cell console 应打印 `INFO: hello_func : Hello world.` / `tic tac tic tac ...` | UG10170 §4.3（**官方资料明确说明**）——所以"看不到输出"确实是异常 |


<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/资料清单表.md|资料清单表]]
- [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md|SD启动GPIO权限问题结论]]
- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
