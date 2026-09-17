---
type: 索引
scope: 全库
doc_type: 参考
status: 已整理
evidence: 官方资料
tags: [索引]
updated: 2026-09-17
---

# 项目索引（MOC）

> 做到一半、有交付、有时间点的事都放这里。项目笔记里保留**本项目的路径、命令、接线、日志、失败过程和验证结果**；离开项目还能复用的原理请提炼到 `20-领域/` 并在这里留链接。

> 用法：`Ctrl+O` 快速打开；本页在 Obsidian 里点链接直接跳。每篇末尾的「相关」节给出同目录与相关主题的跳转。

## 10-项目（共 25 篇）

### FRDM-IMX95-PRO（13 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md\|A55-FreeRTOS任务与时间安排]] | 合计可用工作日：21 天（含今天）。所以只分 3 个阶段，阶段内不再细分到天。 | 不适用 |
| [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md\|A55运行FreeRTOS的方向调整]] | 初始资料和板卡默认分工里，M7 是“高性能实时核”，FreeRTOS 示例也在 cm7 目录，因此按 M7 推进 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md\|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]] | vTaskStartScheduler()之前仍是普通的顺序执行程序；调用之后，调度器接管CPU，main()后 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md\|FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程]] | 记录时间：2026-09-09至2026-09-15。 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md\|FRDM-IMX95-PRO开发记录]] | FRDM-IMX95-PRO 使用 i.MX 95 处理器，包含 6 个 Cortex-A55、1 个 Cort | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/Harpoon验证与复现.md\|Harpoon验证与复现]] | 目标由 M7 改为 A55 上跑 FreeRTOS 后，需要判断：从 NXP 下载的 Harpoon 包（HS_ | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/JTAG与SWD接口调研.md\|JTAG与SWD接口调研]] | 同页还有 DAP 引脚与球号（见第二节）以及 JTAG__TP26 的交叉引用。 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/MCUXpresso-SDK获取.md\|MCUXpresso-SDK获取]] | 获取 i.MX95 Cortex-M7 对应的 SDK，用于编译 hello_world 和 FreeRTOS  | 源码确认 |
| [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md\|SD启动GPIO权限问题结论]] | 2026-09-15已完成实机修复。已验证的SD启动镜像中，M7 FreeRTOS持久化启动后LPUART7/C | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/开发日志.md\|开发日志]] | 相对原始配置只改变GPIO2的归属： | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/待向NXP确认的问题清单.md\|待向NXP确认的问题清单]] | 1. 下载了 Harpoon Software v3.5 / Real-Time Edge 3.3，发现它只提供 | 不适用 |
| [[10-项目/FRDM-IMX95-PRO/理解-i.MX95启动与资源隔离.md\|理解-i.MX95启动与资源隔离]] | i.MX95 不是一个"CPU 加外设"的芯片，而是一个多核 + 多域 + 权限管理器的系统。理解它要分三层： | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/资料清单表.md\|资料清单表]] | — | 实机验证 |

### PLC-微波炉（4 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/PLC-微波炉/学习/PLC_Basic/PLC_Basic.md\|PLC_Basic]] | 官方提供的软件手册已经很完善了，讲解很细致而且图片很多很容易看懂。PLC信捷官方手册(1. 软件手册.pdf) | 官方资料 |
| [[10-项目/PLC-微波炉/学习/PLC_HMI/PLC_HMI.md\|PLC_HMI]] | 官方的TouchWin手册已经非常完善了，可以随时查阅TouchWin官方手册(TouchWin编辑软件用户手册 | 官方资料 |
| [[10-项目/PLC-微波炉/设计/PLC_MicroWave_Design.md\|PLC_MicroWave_Design]] | 1. 解冻（50)和烧烤(180)的时候温度上升到一定温度就不上升了 | 教材课程 |
| [[10-项目/PLC-微波炉/学习/PLC_MicroWave/PLC_MicroWave_Learning.md\|PLC_MicroWave_Learning]] | 写入操作命令和参数，PLC负责判断条件、保存步骤状态和驱动输出。除炉门外，按钮均使用瞬时ON。 | 教材课程 |

### Stage-Modbus（3 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/Stage-Modbus/Modbus/Modbus.md\|Modbus]] | Modbus是一种工业通信协议，最早用于控制器之间的数据交换。它的核心思想是：主站发起请求，从站按照请求访问自己 | 教材课程 |
| [[10-项目/Stage-Modbus/Modbus_Project/Modbus_Project_Learning.md\|Modbus_Project_Learning]] | ﻿# Modbus项目开发学习笔记 | 实机验证 |
| [[10-项目/Stage-Modbus/ucosii/ucosii.md\|ucosii]] | uC/OS-II是一个面向嵌入式系统的实时操作系统内核。它的主要作用是把复杂程序拆分成多个任务，并通过优先级、就 | 教材课程 |

### Stage-PLSR（2 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/Stage-PLSR/PLSR/PLSR.md\|PLSR]] | PLSR是多段脉冲输出指令。它不是单纯打开PWM，而是按照公共参数和段表，连续处理频率变化、脉冲计数、方向控制、 | 教材课程 |
| [[10-项目/Stage-PLSR/PLSR_Project/PLSR_Project_Learning.md\|PLSR_Project_Learning]] | 本项目在XDM-60T4-E控制器内部的STM32F407IG6上实现一路PLSR功能。设备使用定时器PWM输出 | 实机验证 |

### 面试项目（3 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/面试项目/PLSR.md\|PLSR]] | 本次PLSR题目从需求梳理、设计方案书编写、代码开发，到实际波形验证和验收调整，持续了近一个月。最终完成了参数配 | 实机验证 |
| [[10-项目/面试项目/智能安防报警.md\|智能安防报警]] | 智能安防报警系统主要实现遭遇窃贼时报警的功能。当家中发生非正常紧急情况（有人接近）时，通过一系列传感器的感应，及 | 实机验证 |
| [[10-项目/面试项目/系统健康监测平台.md\|系统健康监测平台]] | 项目实现：项目实际上实现的是几个常见工具的部分功能比如top，free，还实现了日志功能，top是系统级和进程级 | 实机验证 |
