---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待验证
evidence: 实机验证
tags: []
updated: 2026-09-17
---

# JTAG / SWD 接口调研（FRDM-IMX95-PRO，要求 7 部分结论）

> 类型：项目档案 / 硬件调研。时间：2026-09-17。依据：原理图 **SPF-95794_B1**（`SCH-95794 PDF: SPF-95794 B1`，共 29 页）。

## 一、结论（先说结果）

**这块板上没有 JTAG 调试座，SoC 的 DAP 调试信号只引到测试点（test point）。**

- **第 7 页**（i.MX95 MISC 页）的 "JTAG/SWD" 块上写着：`Use test points to trigger JTAG.`
  同页还有 DAP 引脚与球号（见第二节）以及 `JTAG_*_TP[26]` 的交叉引用。
- **第 26 页**是**测试点实际摆放的那一页**（第 7 页用 `[26]` 指向它），页上是
  `JTAG_TMS_TP / JTAG_CLK_TP / JTAG_TDO_TP / JTAG_TDI_TP / JTAG_RST_TP` 这些网络名。

也就是说：**想用 J-Link，必须自己在测试点上飞线/焊接**，没有现成插座可插。

> **取证教训（记下来避免再犯）**：本 PDF 里那句注释**用 pdfplumber 抽不出来、用 pypdf 能抽出来**。
> 所以"某个引擎搜不到"不能当作"文档里没有"的证据；关键结论至少用两种引擎交叉验证，或直接看图。
> 这次就是我把第 7 页的 `[26]` 交叉引用误当成注释所在页，导致报错页码。

## 二、SoC 侧（信号从哪来）

原理图 "i.MX95 MISC" 页（第 7 页）给出 U25（`MIMX9596AVZXNAC_716BGA`）的 DAP 引脚：

| SoC 引脚名 | BGA 球号 | 作用 |
|---|---|---|
| `DAP_TCLK_SWCLK` | AG21 | JTAG TCK / SWD SWCLK |
| `DAP_TMS_SWDIO` | AH22 | JTAG TMS / SWD SWDIO |
| `DAP_TDI` | AK24 | JTAG TDI |
| `DAP_TDO_TRACESWO` | AJ23 | JTAG TDO / SWO（单线跟踪） |

## 三、板级侧（信号到哪去）

第 26 页（测试点实际摆放页）上的网络名；第 7 页以 `[26]` 指向本页，本页以 `[7]` 指回第 7 页：

| 板上网络名 | 对应 SoC 信号 | 说明 |
|---|---|---|
| `JTAG_CLK_TP` | `DAP_TCLK_SWCLK` | TCK/SWCLK 测试点 |
| `JTAG_TMS_TP` | `DAP_TMS_SWDIO` | TMS/SWDIO 测试点 |
| `JTAG_TDI_TP` | `DAP_TDI` | TDI 测试点 |
| `JTAG_TDO_TP` | `DAP_TDO_TRACESWO` | TDO/SWO 测试点 |
| `JTAG_RST_TP` | 与 `SYS_RST_B` 同网 | 复位测试点（**就是系统复位**） |

## 四、与 EVK 的对比（可作参考设计）

`UM12022`（IMX95LPD5EVK-19 板手册）的框图与功能表里，"Debug" 一栏写的是 **JTAG/SWD + `2 x 5 HDR`**，
即 **EVK 上是 10-pin（2×5）调试排针**，而 FRDM-IMX95-PRO 把它换成了测试点。
→ 如果 NXP 有"EVK 10-pin → 测试点"的转接做法，Pro 板可照搬；这是要问的问题之一。

## 五、要用 J-Link 的话，至少需要什么

**SWD 最小接线（4 线即可）**：

```text
J-Link                    板子（测试点）
VTREF  ────────────────► JTAG 参考电压（1.8V 还是 3.3V 待确认！）
GND    ────────────────► GND
SWCLK  ────────────────► JTAG_CLK_TP
SWDIO  ────────────────► JTAG_TMS_TP
（可选）RESET ───────────► JTAG_RST_TP  ← 注意此点与 SYS_RST_B 同网，会复位整机
```

**注意事项**

1. **VTREF 电压必须与 DAP 侧 I/O 电平一致**。J-Link 用 VTREF 做电平参考；接错可能打坏 SoC 或通信不稳。
   原理图第 26 页 JTAG 块附近出现 `VDD_3V3`，但同一行文本还混有其他功能块（按键/温度传感器/SPI NOR），
   **不能据此断定 DAP 就是 3.3V**——需要实测或问 NXP（已列入问题清单）。
2. `JTAG_RST_TP` 与 `SYS_RST_B` 同网，接上 RESET 等于"能复位整块板"，调试时注意别误触发。
3. 4 根信号线在板上是**测试点**，需要用细飞线/探针固定；建议同时确认测试点的**丝印编号（TP 号）**再动手。

## 六、待办 / 待确认

- [ ] 在板上找到 5 个测试点的**具体位置与 TP 编号**（对照原理图物件编号 + 实物丝印）
- [ ] **实测 VTREF 电压**（万用表量 JTAG 参考点），确定 1.8V/3.3V
- [ ] 确认 J-Link 型号与固件是否支持该 DAP（Cortex-A55 的 CoreSight DAP）
- [ ] 向 NXP 确认：官方是否有转接件/推荐接法；J-Link 能否调试 A55 上的 FlowRTOS/Jailhouse inmate
- [ ] 若最终不需要 A55 级调试，退一步：**用 `AN14120` 的方式调试 M33/M7**（该应用笔记就是讲这个，含 J-Link 连接与 VS Code 配置）

## 关联

- 资料清单：`2026-09-17-资料清单表.md`（AN14120 §4「为调试器准备电路板」、UM12022 §2.21.2 JTAG）
- 提问：`2026-09-17-待向NXP确认的问题清单.md` 问题 2

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
- [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md|A55运行FreeRTOS的方向调整]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]]
