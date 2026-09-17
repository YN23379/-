---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 未分类
status: 待验证
evidence: 源码确认
tags: []
updated: 2026-09-17
---

# i.MX95 在 Cortex-A55 上运行 FreeRTOS 的可行路径

## 这篇知识解决什么问题

项目原本在 M7 上跑 FreeRTOS。若改为在 A55 上跑（例如 M7/M33 已被其它任务占用），先要判断：能不能“零改动”搬过去、有哪几种实现形态、各需要改什么。本文给出判断框架和证据，具体选型仍需按产品需求确认。

## 一、两类核不同，“零改动”不可能

- A55：Armv8-A、AArch64、有 MMU、异常级 EL0~EL3，正常由 ATF(BL31)+U-Boot+Linux 引导。
- M7：Armv7E-M、32 位 Thumb、MPU、无 EL 异常级模型，常用 TCM + 裸机/RTOS。
- 两者指令集、二进制格式、异常与启动模型、内存管理都不同。**M7 的 `freertos_hello.bin` 不能在 A55 上执行。**

但 FreeRTOS 内核有 AArch64 端口可复用，任务/队列/信号量等 API 与业务任务代码基本不用改。

## 二、真正的 A55 移植要改的是“平台层”

- 端口层：`port.c / portmacro.h` 换成 AArch64 端口（GIC + generic timer）。
- 启动与异常级：A55 从 EL3/EL2/EL1 进入，需要异常向量、栈、MMU 页表、cache 初始化。
- 平台驱动：GIC 中断控制器、系统定时器、串口、GPIO（与 M7 的 RGPIO/LPUART 不同）。
- 链接脚本与内存布局：MMU 页表、DDR 布局。
- 启动链与容器：谁把 A55 镜像放到内存并放行（Boot ROM/ELE→SM→TF-A/U-Boot），以及 SM 中 A55 逻辑机与权限。

## 三、三种实现形态

1. **A55 独占裸机 FreeRTOS（不跑 Linux）**
   用 FreeRTOS AArch64 端口 + 自写 A55 板级；启动容器里把 A55 链（SPL/U-Boot/Linux）换成 FreeRTOS 镜像，由 TF-A/U-Boot 引导。自主性最高、工作量最大；需要 SM 把 A55 核与外设交给 FreeRTOS。
2. **Jailhouse inmate（A55 与 Linux 共存）**
   Linux 先启动，Jailhouse 划分核/内存/中断，在某个 A55 上运行裸机 inmate。NXP i.MX95 BSP 固件中含 `jailhouse.bin`。最贴合“一个 A55 核给实时任务、其余留给 Linux”。需要把 FreeRTOS 适配为 Jailhouse inmate（入口、内存、中断路由）。
3. **NXP 官方 A55 FreeRTOS BSP / FAE 支持**
   MCUXpresso SDK 的 i.MX95 只覆盖 M33/M7（`boards/imx95lpd5evk19` 下只有 cm7/cm33），未见 A55 例程。是否有官方 A55 FreeRTOS 支持需向 NXP/FAE 确认。

## 四、结论与待确认

- “零改动”不成立；“业务代码基本不改、只改平台层”可行。
- 选型取决于：A55 是否仍需跑 Linux、需要几个 A55 核、实时性与外设需求、是否允许用 Jailhouse、是否有官方支持。

标记：

- AArch64 端口、jailhouse.bin 存在 = `源码/资料确认`
- i.MX95 上用 Jailhouse 跑 FreeRTOS inmate = `待验证`
- NXP 官方 A55 FreeRTOS 支持 = `待确认`

## 五、证据

- 端口：`FreeRTOS/FreeRTOS-Kernel-1/portable/GCC/ARM_AARCH64`、`ARM_CA53_64_BIT`
- Jailhouse：`board_firmware/firmware/jailhouse.bin`
- SDK 只有 M 核例程：`SDK_26_06_00_IMX95LPD5EVK-19/boards/imx95lpd5evk19`（cm7/cm33）
- 项目档案：[方向调整：FreeRTOS 从 M7 转到 A55](../../10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md)

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95多核与程序启动]]
- [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|i.MX95上Jailhouse与Harpoon的分层与判定方法]]
- [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|i.MX95时钟-IOMUX与板级串口选择方法]]
