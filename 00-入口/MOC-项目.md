---
type: 索引
scope: 全库
doc_type: 参考
status: 已整理
evidence: 不适用
tags: [索引]
updated: 2026-09-21
---

# 项目索引（MOC）

> 做到一半、有交付、有时间点的事放这里。
> 项目笔记保留**本项目的路径、命令、接线、日志、失败过程和验证结果**；
> 离开项目还能复用的原理提炼到 `20-领域/`，在这里留链接。

> 每个项目目录的 `README.md` 是该项目的入口，写清了"这个目录里是什么"。

## 项目一览

| 项目 | 状态 | 一句话 |
|---|---|---|
| [[10-项目/IMX95-EVK/README.md\|IMX95-EVK]] | **当前主线** | i.MX95 19x19 LPDDR5 EVK，目标是在 A55 上跑 FreeRTOS（Harpoon/Jailhouse 方案） |
| [[10-项目/FRDM-IMX95-PRO/README.md\|FRDM-IMX95-PRO]] | 旧板留档 | Pro 板阶段的完整现场记录；流程与结论换板后仍可复用 |
| [[10-项目/面试项目/README.md\|面试项目]] | 已完成 | 求职用的三个项目：PLSR、智能安防报警、系统健康监测平台 |
| `PLC-微波炉` | 已完成 | 信捷 PLC + TouchWin 触摸屏的微波炉控制（含设计文档与学习笔记） |
| `Stage-Modbus` | 已完成 | Modbus 协议与 STM32 上的 Modbus 工程、uC/OS-II 学习 |
| `Stage-PLSR` | 已完成 | PLSR 多段脉冲输出指令与工程实现 |

## IMX95-EVK（当前主线，7 篇）

> 为什么换板：NXP 确认 **Harpoon / Jailhouse 只支持 EVK，不支持 FRDM-IMX95-PRO**。

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md\|EVK-19x19到手操作计划]] | 拿到板子后按什么顺序做什么：开箱清点、装散热片、首次上电、Harpoon 复现、JTAG | 官方资料 |
| [[10-项目/IMX95-EVK/待向NXP确认的问题清单.md\|待向NXP确认的问题清单]] | 向原厂提问的清单，含换 EVK 的确认记录 | 官方资料 |
| [[10-项目/IMX95-EVK/资料清单表.md\|资料清单表]] | 资料总表；UM12022(EVK) 与 UM12527(Pro) 的区分；UG10170 确认了什么 | 实机验证 |
| [[10-项目/IMX95-EVK/JTAG与SWD接口调研.md\|JTAG与SWD接口调研]] | Pro 板只有测试点无座；EVK 有 10-pin J30 座，引脚定义见 UM12022 Table 52 | 官方资料 |
| [[10-项目/IMX95-EVK/MCUXpresso-SDK获取.md\|MCUXpresso-SDK获取]] | 获取 M7 对应的 SDK，用于编译 hello_world 和 FreeRTOS | 源码确认 |
| [[10-项目/IMX95-EVK/A55-FreeRTOS任务与时间安排.md\|A55-FreeRTOS任务与时间安排]] | 21 个可用工作日怎么分三个阶段 | 不适用 |

## FRDM-IMX95-PRO（旧板留档，11 篇）

> 已停止更新，但记录不作废：jailhouse 流程、cell 机制、A55 上跑 FreeRTOS 的验证，换板后全部可复用。

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/FRDM-IMX95-PRO/理解-i.MX95启动与资源隔离.md\|理解-i.MX95启动与资源隔离]] | 启动逻辑、资源隔离与权限；**这篇最完整，换板后仍适用** | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md\|FRDM-IMX95-PRO开发记录]] | 从上手到启动、下载和外设验证的完整现场记录 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md\|从上手到FreeRTOS外设验证完整流程]] | M7 阶段的完整复现流程 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md\|FreeRTOS任务创建与LED代码理解]] | 任务、串口、GPIO 和 LED 代码分析 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/开发日志.md\|开发日志]] | 按日期的连续日志，含问题记录范式 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md\|SD启动GPIO权限问题结论]] | SD 启动镜像里 GPIO 权限问题的最终结论 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md\|A55运行FreeRTOS的方向调整]] | 目标由 M7 改为 A55 的决策记录 | 实机验证 |
| [[10-项目/FRDM-IMX95-PRO/Harpoon复现.md\|Harpoon复现]] | 手把手复现手册 + 可用性判定 + 无输出根因 + 踩坑表（含附三、附四） | 实机验证 |

## 面试项目（3 篇）

| 笔记 | 一句话 | 依据 |
|---|---|---|
| [[10-项目/面试项目/PLSR.md\|PLSR]] | 从需求梳理、方案书、代码开发到波形验证与验收的完整过程 | 实机验证 |
| [[10-项目/面试项目/智能安防报警.md\|智能安防报警]] | 传感器触发报警的完整项目 | 实机验证 |
| [[10-项目/面试项目/系统健康监测平台.md\|系统健康监测平台]] | 实现 top/free/日志等工具的部分功能，含系统级与进程级视角 | 实机验证 |

## 其他项目

| 项目 | 笔记 | 依据 |
|---|---|---|
| PLC-微波炉 | [[10-项目/PLC-微波炉/设计/PLC_MicroWave_Design.md\|微波炉设计]] · [[10-项目/PLC-微波炉/学习/PLC_Basic/PLC_Basic.md\|PLC_Basic]] · [[10-项目/PLC-微波炉/学习/PLC_HMI/PLC_HMI.md\|PLC_HMI]] · [[10-项目/PLC-微波炉/学习/PLC_MicroWave/PLC_MicroWave_Learning.md\|PLC_MicroWave_Learning]] | 官方资料 |
| Stage-Modbus | [[10-项目/Stage-Modbus/Modbus/Modbus.md\|Modbus]] · [[10-项目/Stage-Modbus/Modbus_Project/Modbus_Project_Learning.md\|Modbus_Project_Learning]] · [[10-项目/Stage-Modbus/ucosii/ucosii.md\|ucosii]] | 实机验证 |
| Stage-PLSR | [[10-项目/Stage-PLSR/PLSR/PLSR.md\|PLSR]] · [[10-项目/Stage-PLSR/PLSR_Project/PLSR_Project_Learning.md\|PLSR_Project_Learning]] | 实机验证 |

## 相关领域笔记

- i.MX95 的芯片级原理 → [[20-领域/芯片与平台-i.MX95/README.md|芯片与平台-i.MX95]]
- Harpoon/Jailhouse 的机制 → [[20-领域/芯片与平台-i.MX95/Jailhouse分区式虚拟化原理.md|Jailhouse分区式虚拟化原理]]
- FreeRTOS 本体 → [[20-领域/RTOS/FreeRTOS.md|FreeRTOS]]
