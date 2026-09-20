---
type: 项目档案
scope: i.MX95 19x19 LPDDR5 EVK（IMX95LPD5EVK-19）
doc_type: 参考
status: 进行中
evidence: 不适用
tags: [Harpoon, Jailhouse, 启动, 多核与异构, 调试]
updated: 2026-09-21
---

# IMX95-EVK 项目档案（当前主线）

> 目标板：**i.MX95 19x19 LPDDR5 EVK**（`IMX95LPD5EVK-19`），NXP 提供。
> **为什么换板**：NXP 确认 **Harpoon / Jailhouse 只支持 EVK，不支持 FRDM-IMX95-PRO**。
> 旧板记录 → [[10-项目/FRDM-IMX95-PRO/README.md|FRDM-IMX95-PRO 目录（留档）]]。

## 先看这篇

**[[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划]]**
—— 拿到板子后按什么顺序做什么：开箱清点 → 装散热片 → 首次上电 → Harpoon 复现 → JTAG。

## 目录内容

| 文件 | 内容 |
|---|---|
| `EVK-19x19到手操作计划.md` | 操作计划（开箱、上电、复现、JTAG、安全注意事项） |
| `Harpoon复现.md` | Harpoon 手把手流程 + **原理速览**（该懂什么、三块核心原理） |
| `Harpoon验证与复现.md` | 可用性判定、全流程记录、无输出问题的根因排查 |
| `待向NXP确认的问题清单.md` | 问题清单 + **已确认换 EVK 的记录** |
| `A55-FreeRTOS任务与时间安排.md` | 阶段级计划（含换板后的调整） |
| `JTAG与SWD接口调研.md` | Pro 板无 JTAG 座的结论 + **EVK J30 座与引脚定义** |
| `资料清单表.md` | 资料总表、手册区分、UG10170 确认了什么 |
| `MCUXpresso-SDK获取.md` | SDK 获取方法 |

## 换板后和 Pro 板的关键差异

| 项目 | FRDM-IMX95-PRO | **IMX95 19x19 EVK** |
|---|---|---|
| 板型 | 单板 | **SOM + 底板两块** |
| 启动开关 | SW4[1:4] | **SW7[1:4]**（默认 `x010` = eMMC） |
| 电源 | 板电源口 | **J5**（12V/13.33A/160W）+ **SW4** 开关 |
| 调试口 | J22 = CH9114F | **J31 = FT4232H**（A=M7/UART3、C=A55/UART1、D=M33/UART2） |
| **JTAG** | ❌ 只有测试点，**无座** | ✅ **有 10-pin 座 J30** |
| eMMC | 32GB | **64GB** |

> **注意**：两块板的开关名有重叠（都有 SW4），**含义完全不同**：
> Pro 板的 **SW4 是启动模式开关**，EVK 的 **SW4 是电源开关**（启动模式是 SW7）。
> 这是最容易搞混的一处。

## 资料位置

`C:\Users\chen\Desktop\资料\IMX95_19_19_EVK\`
（QSG、UM12022、底板/SOM 原理图与 BOM、布局文件）

<!-- related-generated -->
## 相关

- [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划]]
- [[10-项目/IMX95-EVK/Harpoon复现.md|Harpoon 复现]]
- [[10-项目/IMX95-EVK/待向NXP确认的问题清单.md|待向 NXP 确认的问题清单]]
- [[10-项目/IMX95-EVK/资料清单表.md|资料清单表]]
- [[10-项目/FRDM-IMX95-PRO/README.md|FRDM-IMX95-PRO（旧板留档）]]
