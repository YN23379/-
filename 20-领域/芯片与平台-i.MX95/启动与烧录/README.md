---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 原理
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# 启动与烧录

计划整理的主题：

- 程序从非易失性存储到CPU执行的完整过程；
- ELF、BIN、启动容器和`flash.bin`的区别；
- Boot ROM、ELE、DDR OEI、System Manager和M7固件的启动顺序；
- UUU的USB临时启动与SD/eMMC持久化烧录；
- JTAG/SWD、USB SDP/SDPS和Linux remoteproc的适用场景；
- 如何根据启动模式、串口日志和镜像组成排查启动失败。

项目中的实证材料：

- [FRDM-IMX95-PRO从上手到FreeRTOS外设验证](../../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md)
- [SDK、BSP与调试下载接口](SDK、BSP与调试下载接口.md)
- [STM32与i.MX95启动和开发流程对比](STM32与i.MX95启动和开发流程对比.md)
