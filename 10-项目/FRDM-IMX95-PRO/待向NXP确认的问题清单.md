---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 已整理
evidence: 不适用
tags: []
updated: 2026-09-17
---

# 待 NXP 确认（精简版，可直接发群）

> 整理：2026-09-17。板卡：**FRDM-IMX95-PRO**（i.MX95 B0，19x19 封装，LPDDR5 16GB，eMMC 32GB）。
> 目标：在该板的 **1–2 个 Cortex-A55 核**上跑 **FreeRTOS**，方案选 **Harpoon（Real-Time Edge）**。

---

## 问题 1：Harpoon 在 FRDM-IMX95-PRO 上应该怎么走？

**我们做到哪一步了（简述）**

1. 下载了 **Harpoon Software v3.5 / Real-Time Edge 3.3**，发现它只提供 **i.MX95 19x19 LPDDR5 EVK** 的板级包，FRDM-IMX95-PRO 不在 `meta-nxp-harpoon` 的支持矩阵里（DTB、启动容器、SM 配置、运行脚本的机器判断都是 EVK 的）。
2. 但 Pro 板原厂系统**自带完整 Jailhouse**（`/sbin/jailhouse`、`jailhouse.ko`、`/lib/firmware/jailhouse.bin`、`/usr/share/jailhouse/cells/imx95.cell`）。我们用"**底座用板子的 Jailhouse + inmate 用 Harpoon 包里的 `imx95-harpoon-freertos.cell` + `rt_latency.bin`**"的方式，已经让 **FreeRTOS 在 A55 的 CPU5 上跑起来**（`jailhouse cell list` → `freertos running 5`，`cell stats` 里 `vmexits_mmio` 持续增长）。

**三个卡点，请指导**

1. **看不到 inmate 的打印**：Harpoon 的 i.MX95 cell 里 inmate 控制台是 **LPUART3（0x42570000）**，而 FRDM-IMX95-PRO 的 J22 调试口只引出 **UART1 / UART2 / UART7**。
   → 官方推荐 inmate 用哪一路 UART？只改 cell 配置（console 地址）就够，还是必须重编 inmate 的 console 配置？
2. **缺 `imx95-19x19-frdm-pro-root.dtb`**：U-Boot 的 `jh_root_dtb` 指向这个文件，但板的 boot 分区里只有 `imx95-19x19-frdm-pro.dtb`。
   现在的临时做法是在 U-Boot 里手工 `setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000` + `jh_clk …` 才能让 Linux 只占 4.4 GB、把 inmate/hypervisor 内存让出来，**断电即失效**。
   → 这个 root DTB 官方有吗？或有正确的生成方法（是否就是"板级 DTB + reserved-memory 节点"）？
3. **扩到 2 个 A55 核**：官方推荐"**一个 cell 里放 2 个 A55 核**"还是"**两个 cell 各 1 核**"？多核 FreeRTOS（SMP）在这个场景是否支持、有无已知限制？

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
1. **i.MX95 参考手册（RM）**——重点是 **Boot ROM、Memory Map、TRDC/RDC** 章节；
2. **Harpoon 用户指南（UG10170）**；
3. 以及：**FRDM-IMX95-PRO 是否有官方 Harpoon / Real-Time Edge 支持计划**（含 `imx95-19x19-frdm-pro-root.dtb`）。

---

## 附：已自行确认、不必回答（避免占用时间）

| 事项 | 我们的结论 | 依据 |
|---|---|---|
| `boot[]` / `skip` / `mSel` 语义 | `boot[]`=按 mSel 的 LM 启动顺序；`skip` 是"容器无镜像时不报错"；`mSel` 是启动配置档位（Pro 板有 3 档，实机用 mSel=0） | `imx-sm/sm/doc/config.md` 330–388 行 + 生成的 `config_lmm.h` |
| 上电启动顺序 | AON **M33 先跑 Boot ROM → 加载 SM**；SM 写 TRDC/RDC 隔离后再按 `boot[]` 拉起 M7、A55；**A55 集群只由 SM 释放 CPU0**，C1–C5 由 OS/固件用 PSCI 启动 | SM 官方 README + `arch.md` + `config_lmm.h` 启动表 |
| 串口归属 | COM17=LPUART1→A55；COM18=LPUART7→M7；COM19=LPUART2→SM(M33) | `mx95frdm-pro.cfg` + 实机应答 |
| Pro 板能否用 Jailhouse | 能，已实机跑通 Harpoon 的 FreeRTOS inmate（A55 CPU5） | `jailhouse cell list` / `cell stats` |

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/资料清单表.md|资料清单表]]
- [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md|SD启动GPIO权限问题结论]]
- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
