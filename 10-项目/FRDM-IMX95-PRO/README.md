---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 参考
status: 已归档
evidence: 不适用
tags: [归档, 启动, 多核与异构, 安全与隔离]
updated: 2026-09-21
---

# FRDM-IMX95-PRO 项目档案（旧板，留档）

> ### ⚠️ 本目录已停止更新（2026-09-21）
>
> **原因**：NXP 确认 **Harpoon / Jailhouse 只支持 i.MX95 EVK，不支持 FRDM-IMX95-PRO**，
> 板级适配要改很多。目标板已换成 **i.MX95 19x19 LPDDR5 EVK**。
>
> **当前主线 →** [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|IMX95-EVK 目录]]
>
> **但这里的记录不作废**：jailhouse 流程、cell 机制、"FreeRTOS 在 A55 上跑起来"的验证，
> 换板后**全部可复用**，只是 cell 文件换成 EVK 版、不用再手工绕内存参数。

## 这个目录里是什么

Pro 板阶段的完整现场记录，**不改写成通用教材**。内容覆盖：

- 资料收集、环境搭建、**M7 FreeRTOS 启动**（USB+UUU 启动、SD 持久化）
- **GPIO 权限排查**（TRDC/RDC、SM 配置）
- 串口 / GPIO / LED 验证，以及失败过程
- **启动逻辑与资源隔离**的理解整理（对应验收要求 1/2/5）

## 主要记录

| 文件 | 内容 |
|---|---|
| `理解-i.MX95启动与资源隔离.md` | 启动逻辑、资源隔离与权限（**这篇最完整，换板后仍然适用**） |
| `FRDM-IMX95-PRO开发记录.md` | 从上手到启动、下载和外设验证的完整现场记录 |
| `FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md` | M7 阶段的完整复现流程 |
| `FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md` | 任务、串口、GPIO 和 LED 代码分析 |
| `开发日志.md` | 按日期的连续日志 |
| `SD启动GPIO权限问题结论.md` | SD 启动镜像里 GPIO 权限问题的最终结论 |
| `A55运行FreeRTOS的方向调整.md` | 目标由 M7 改为 A55 的决策记录 |

## 使用方法

查"Pro 板上当时怎么操作"看本目录；
查"以后换平台怎么理解"看 `20-领域`；
查**当前在做什么**看 [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|IMX95-EVK 目录]]。

> 本目录里的 COM 号、引脚号、**SW4** 组合、镜像路径和命令，
> **只对 FRDM-IMX95-PRO 和当时的构建环境负责**。
> 换到 EVK 后：启动开关是 **SW7**（不是 SW4）、调试口是 **J31**、
> 有 **JTAG 座 J30**、电源是 **J5 + SW4 开关**。

<!-- related-generated -->
## 相关

- [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划（当前主线）]]
- [[10-项目/FRDM-IMX95-PRO/理解-i.MX95启动与资源隔离.md|理解：启动逻辑、资源隔离与权限]]
- [[10-项目/FRDM-IMX95-PRO/开发日志.md|开发日志（按时间）]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md|从上手到外设验证完整流程]]
- [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md|SD 启动 GPIO 权限问题结论]]
- [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md|A55 运行 FreeRTOS 的方向调整]]
