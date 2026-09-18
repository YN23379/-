---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待验证
evidence: 实机验证
tags: [多核与异构, 启动, 编译构建]
updated: 2026-09-17
---

# 方向调整：FreeRTOS 从 M7 转到 A55

> 类型：项目决策与进度记录。记录时间：2026-09-16。

## 一、结论

- 与负责人同步后确认：目标改为在 **Cortex-A55** 上运行 FreeRTOS，M7/M33 留给其他任务使用。
- 之前的 M7 工作不废弃，作为 FreeRTOS 应用参考与平台基础设施保留。

## 二、之前为什么做 M7

初始资料和板卡默认分工里，M7 是“高性能实时核”，FreeRTOS 示例也在 cm7 目录，因此按 M7 推进了全部验证。方向调整来自“其他核要被别人使用”的产品分工，不是技术判断错误。

## 三、“不改代码”的准确结论

- 严格“零改动”不可能：A55(AArch64/MMU/EL) 与 M7(Armv7E-M/MPU) 指令集、异常级、内存管理都不同，**M7 的 BIN 不能在 A55 上执行**。
- 可做到“业务任务代码基本不改”：FreeRTOS 内核有 AArch64 端口，任务/队列/信号量 API 与业务逻辑不用动；改的是平台层（端口、启动、MMU、GIC、定时器、驱动、链接脚本、启动链与 SM 配置）。
- 详见知识库 [i.MX95 在 A55 上运行 FreeRTOS 的路径](../../20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md)。

## 四、A55 方案选项（待选）

1. A55 独占裸机 FreeRTOS（不跑 Linux）。
2. Jailhouse 与 Linux 共存（BSP 固件含 `jailhouse.bin`，划一个 A55 核给 FreeRTOS）。
3. 是否有 NXP 官方 A55 FreeRTOS BSP / FAE 支持（待确认）。

## 五、已有成果中可复用的部分

- 启动容器组装：`imx-mkimage` 用法、容器布局、SHA 记录（`build/pro-gpio/`）。
- 烧写与观测：UUU/SD 启动流程、串口映射、逻辑分析仪验证方法。
- SM/LM/TRDC 资源与权限配置方法及实机证据（`mx95frdm-pro-m7gpio.cfg` → `m33_image.bin`）。
- 平台概念与资料：ATF/BL31、异常级、TCM/MMU、逻辑机。
- M7 FreeRTOS 端到端参考：串口回显、GPIO、实时性周期/抖动、抢占实验。

## 六、需要负责人确认的问题

1. A55 是否仍需运行 Linux？FreeRTOS 独占几个 A55 核，还是与 Linux 共存（Jailhouse）？
2. 需要哪些外设、什么实时指标（周期、抖动、中断延迟）？
3. 是否允许使用 Jailhouse？有无 NXP 官方 A55 FreeRTOS BSP 或 FAE 支持？
4. 交付形态（SD/eMMC、量产）与时间点。

## 七、下一步（待确认后细化）

确认上述问题 → 选定形态 → 搭 A55 AArch64 FreeRTOS 最小工程（先把串口跑通）→ 再逐项加外设与实时性验证。

## 八、当前状态

```text
M7 FreeRTOS：已端到端跑通（串口/GPIO/实时性/抢占验证）
A55 FreeRTOS：未开始，等待方案确认
方向调整：已明确（M7 -> A55）
```

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md|FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程]]
