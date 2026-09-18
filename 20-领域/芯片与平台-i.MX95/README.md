---
type: 索引
scope: i.MX95
doc_type: 教程
status: 已整理
evidence: 不适用
tags: [索引, 导航, i.MX95, 多核与异构, 启动]
updated: 2026-09-18
---

# i.MX95（芯片与平台）导览

> 一句话：这一片回答「i.MX95 这颗异构多核 SoC 长什么样、怎么启动、引脚和时钟怎么用」。

## 装什么 / 不装什么

- **装**：芯片级通用机制——多核、启动、IOMUXC/RGPIO、时钟、Jailhouse/Harpoon、SDK/BSP。
- **不装**：具体板子的接线、某根串口线怎么连 → 在 `10-项目/FRDM-IMX95-PRO/`（那里有对应的"理解-*"项目证据）。

## 建议阅读顺序

1. [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95多核与程序启动]] —— 先搞清楚"A55/M7/M33 都是什么、关系和区别"。
2. [[20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md|引脚控制]] 和 [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|时钟与串口选择]] —— 两个最常踩坑的日常问题。
3. [[20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md|在 A55 上跑 FreeRTOS]] 和 [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse/Harpoon 判定]] —— 进阶：虚拟化与实时。
4. 启动细节进 [[20-领域/芯片与平台-i.MX95/启动与烧录/README.md|启动与烧录]]。

## 笔记地图

- [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|多核与程序启动]] —— Arm/Cortex/i.MX95 关系、为什么不能当 STM32 烧。
- [[20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md|引脚控制]] —— IOMUXC 与 RGPIO 分工（和 STM32 最大的区别）。
- [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|时钟与串口选择]] —— M7 时钟谁配、怎么选 LPUART 实例。
- [[20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md|A55 跑 FreeRTOS 的路径]] —— "零改动"不可能、三种形态。
- [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse/Harpoon]] —— 厂商实时包能不能用的五步判定法。

## 相邻主题

- 项目的实证与命令 → [[10-项目/FRDM-IMX95-PRO/README.md|FRDM-IMX95-PRO 项目档案]]
- 启动镜像里到底装了什么 → [[20-领域/芯片与平台-i.MX95/启动与烧录/README.md|启动与烧录]]
