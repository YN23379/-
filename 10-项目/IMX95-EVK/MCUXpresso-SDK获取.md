---
type: 知识库
scope: 工具与环境
doc_type: 未分类
status: 已整理
evidence: 源码确认
tags: [协议, 编译构建, 多核与异构, 启动]
updated: 2026-09-17
---

# MCUXpresso SDK 获取

## 当前目标

获取 i.MX95 Cortex-M7 对应的 SDK，用于编译 `hello_world` 和 FreeRTOS RPMsg 示例。下载 SDK 和编译工程不需要 SD 卡。

## SDK Builder 选择

1. 进入 MCUXpresso SDK Builder。
2. 选择 Development Board。
3. 搜索 `IMX95`。
4. 当前列表没有 `FRDM-IMX95-PRO` 时，选择 `IMX95LPD5EVK-19 (MIMX9596xxxxN)`，不要选择普通 `FRDM-IMX95`。
5. SDK 版本按照 `AN14748` 优先选择 `25.12.00` 或兼容的更新版本。
6. Toolchain 选择 `ARMGCC`。
7. 构建并下载完整 SDK Archive。

选择 `IMX95LPD5EVK-19` 的原因是当前 Pro 板使用 i.MX9596 19x19 封装和 LPDDR5，官方 M7 应用笔记也以该板为示例。该 SDK 可先用于理解和编译 M7 核心示例，但不能默认所有板级外设配置都与 FRDM-IMX95-PRO 相同。

## 错误下载记录

`SDK_25_09_00_MCXW23.zip` 是 MCXW23 无线 MCU SDK，不是 i.MX95 SDK。判断 SDK 是否匹配不能只看版本号，应同时检查压缩包名称、板卡名、处理器型号和文档目录。

正确压缩包名称应包含类似：

```text
SDK_25_12_00_IMX95LPD5EVK-19.zip
```

具体版本号以 SDK Builder 当前提供的版本为准。

## SDK 26.06.00 实际结果

已下载并解压 `SDK_26_06_00_IMX95LPD5EVK-19.zip`。SDK 包含 M7 裸机示例、FreeRTOS 示例、RPMsg Lite 示例和 IAR 工程，清单指定 IAR Embedded Workbench for Arm 9.70.4。裸机 `hello_world_cm7` 已编译成功。

该 SDK 的目标板仍是 `IMX95LPD5EVK-19`，不是 `FRDM-IMX95-PRO`。芯片层代码可用，板级的串口、GPIO、引脚复用和启动配置不能直接套用。尤其是 EVK 示例使用 LPUART3，而 Pro 板的 J22 连接 UART1、UART2 和 UART7。

## UUU和Linux BSP的用途

UUU 1.5.243已经通过`uuu.exe -lsusb`识别USB Serial Downloader模式下的i.MX95，协议为`SDPS`，VID为`0x1FC9`，PID为`0x015D`。这只说明USB下载通道正常，不表示已经烧写程序。

与板载系统匹配的Linux BSP版本为`6.18.2_1.0.0`。下载完整BSP不是为了获得FreeRTOS源码，而是为了取得Pro板匹配的System Manager、AHAB、OEI、DDR初始化、U-Boot和恢复镜像。这些文件用于制作`flash.bin`或在eMMC损坏时恢复系统。当前先使用eMMC内已有的M7 BIN验证`bootaux`，暂不需要下载体积较大的完整BSP。

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md|SD启动GPIO权限问题结论]]
- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
- [[10-项目/FRDM-IMX95-PRO/A55运行FreeRTOS的方向调整.md|A55运行FreeRTOS的方向调整]]
