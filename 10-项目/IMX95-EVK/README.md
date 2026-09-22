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

## ★ 当前状态：FreeRTOS 跑通，rt_latency 延迟数据已拿到

**2026-09-22 实机验证通过**：
- **hello_world**：FreeRTOS 在 A55 CPU5 上运行，COM9 输出 `Hello world.` + `tic tac`
- **rt_latency**：六个测试用例（TC 1–6）全部跑完。无负载时 irq delay 平均 **791 ns**、irq to sched 平均 **2045 ns**；IRQ 负载下 irq to sched 涨到 **9214 ns**（4.5 倍）。**与 UG10170 Table 22 官方值最大偏差 25 ns**
- **TC5 补跑（Linux 侧 `stress-ng --cpu 4 --vm 2` 压满）**：irq to sched 均值 **2025 → 2027 ns**，**Linux 重载对 RTOS 延迟几乎无影响**——因为 CPU5 是静态分区独占的，Linux 抢不到
- **改代码流程打通**：改 `hello_world/freertos/main.c` 打印 `Goodbye world` + `0 1 0 1`，编译 → scp → 重载 cell → COM9 出新输出。**不用重新烧板子**

**关键结论：必须用 SD 卡上的 Real-Time Edge 系统，不能用原厂 eMMC 系统。**

| | 原厂 eMMC 系统 | **SD 卡上的 RTE 系统** |
|---|---|---|
| LPUART3 能否从 A55 域访问 | ❌ SIGBUS | ✅ 可以 |
| harpoon DTB / 应用 | ❌ 都没有 | ✅ 齐全 |
| 结果 | FreeRTOS 跑起来但**看不到输出** | ✅ **正常输出** |

原因：Harpoon 需要一份**定制 SM 配置**，它把 LPUART3 的访问权划给 A55 域；原厂 eMMC 的 SM 配置把 LPUART3 给了 M7。

## 先看这两篇

1. **[[10-项目/IMX95-EVK/Harpoon复现.md|Harpoon 复现操作手册]]** —— 从头到尾怎么做，含原理和排查表
2. **[[10-项目/IMX95-EVK/开发流程-改代码到上板.md|开发流程：改代码到上板]]** —— 跑通之后怎么改、改哪一层、要不要重烧
3. **[[10-项目/IMX95-EVK/开发日志.md|开发日志]]** —— 板子到货后按日期的实际操作、问题和结果

## 目录内容

| 文件 | 内容 |
|---|---|
| **`Harpoon复现.md`** | **复现操作手册 + 原理 + 排查表**（当前最完整的一篇） |
| **`开发流程-改代码到上板.md`** | **七层代码分工、六条改动路线、什么情况要重烧** |
| **`开发日志.md`** | **板子到货后的实际操作、问题与结果（按日期）** |
| `rt_latency原始日志.md` | rt_latency TC 1–6 的完整原始输出（附录） |
| `A55交叉编译环境-WSL2.md` | WSL2 环境搭建、工具链、网络坑 |
| **`rt_latency原始日志.md`** | **rt_latency TC 1–6 的完整原始输出**（开发日志的附录，只放日志不做分析） |
| `EVK-19x19到手操作计划.md` | 操作计划（开箱、上电、复现、JTAG、安全注意事项） |
| `待向NXP确认的问题清单.md` | 问题清单 + 已确认换 EVK 的记录 |
| `A55-FreeRTOS任务与时间安排.md` | 阶段级计划（含换板后的调整） |
| `JTAG与SWD接口调研.md` | Pro 板无 JTAG 座的结论 + **EVK J30 座与引脚定义** |
| `资料清单表.md` | 资料总表、手册区分、UG10170 确认了什么 |
| `MCUXpresso-SDK获取.md` | SDK 获取方法 |

**不在本目录但会用到的**：

- 上电流程原理 → [[10-项目/FRDM-IMX95-PRO/上电流程.md|FRDM-IMX95-PRO/上电流程]]（SoC 级，两块板通用）
- Pro 板那份 Harpoon 流程（**供对照，不能照抄**）→ [[10-项目/FRDM-IMX95-PRO/Harpoon复现.md|FRDM-IMX95-PRO/Harpoon复现]]

## 换板后和 Pro 板的关键差异

| 项目 | FRDM-IMX95-PRO | **IMX95 19x19 EVK** |
|---|---|---|
| 板型 | 单板 | **SOM + 底板两块** |
| 启动开关 | SW4[1:4] | **SW7[1:4]**（默认 `x010` = eMMC，`x011` = SD） |
| 电源 | 板电源口 | **J5**（12V/13.33A/160W）+ **SW4** 开关 |
| 调试口 | J22 = CH9114F | **J31 = FT4232H**（A=M7/UART3、B=I2C、C=A55/UART1、D=M33/UART2） |
| **JTAG** | ❌ 只有测试点，**无座** | ✅ **有 10-pin 座 J30** |
| eMMC | 32GB | **64GB** |
| **系统从哪来** | 原厂 eMMC | **SD 卡上的 RTE 系统** |
| **inmate 控制台** | LPUART3 **没引出** | **LPUART3 = COM9，引出了** |

> **注意**：两块板的开关名有重叠（都有 SW4），**含义完全不同**：
> Pro 板的 **SW4 是启动模式开关**，EVK 的 **SW4 是电源开关**（启动模式是 SW7）。
> 这是最容易搞混的一处。

> **串口注意**：COM6 是 FT4232H 的 I2C 通道，**不是串口，永远不会有输出**。inmate 控制台在 **COM9**。

## 资料位置

`C:\Users\chen\Desktop\资料\IMX95_19_19_EVK\`
（QSG、UM12022、底板/SOM 原理图与 BOM、布局文件）
