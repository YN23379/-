---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# 芯片与平台

## i.MX95

计划整理的主题：

- 异构多核：A55、M7、M33/System Manager之间的关系；
- LM（Logical Machine）和资源分配；
- TRDC（Trusted Resource Domain Controller）访问控制；
- System Manager对电源、时钟、CPU启动和外设资源的管理；
- IOMUX、GPIO控制器和外设复用；
- M7核心时钟、外设根时钟和性能档位的区别。

项目中的实证材料：

- [i.MX95时钟、IOMUX与板级串口选择方法](i.MX95时钟-IOMUX与板级串口选择方法.md)
- [i.MX95引脚控制：IOMUXC与RGPIO的分工](i.MX95引脚控制-IOMUXC与RGPIO分工.md)
- [M7任务、LED、LPUART和GPIO代码理解](../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md)
- [i.MX95多核与程序启动](i.MX95多核与程序启动.md)
- [项目完整开发记录](../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md)

后续从项目记录提炼时，保留芯片通用机制，不把GPIO14、GPIO15、COM18等板级编号当成通用结论。
