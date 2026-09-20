---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 原理
status: 已整理
evidence: 实机验证
tags: [启动, 多核与异构, 编译构建]
updated: 2026-09-17
---

# FRDM-IMX95-PRO SD启动GPIO权限问题最终结论

## 结论

2026-09-15已完成实机修复。已验证的SD启动镜像中，M7 FreeRTOS持久化启动后LPUART7/COM18收发正常，GPIO2_IO14输出约1 Hz方波，GPIO2_IO14与GPIO2_IO15直接连接后输入与输出同步。今天随后又重新生成了当前源码对应的镜像，重新写卡回归待进行。

最终镜像：

```text
F:\project\Learning\RTOS\build\pro-gpio\flash-m7-gpio.bin
size:   2856960 bytes
SHA256: 6DB4B15A01190AB95673DB2879CAB27A0B79C0ECCA655C4B9023FD525376B86A
```

## 现象与排查证据

```text
USB SDPS临时启动：GPIO正常
SD卡启动：M7和FreeRTOS任务仍运行，但GPIO读0、写入无效
M7诊断值：PCNS=PCNP=FFFFFFFF，PDOR/PDIR/PDDR读取异常
U-Boot写GPIO2 PSOR/PCOR：实际引脚电平可变
```

由此排除M7未启动、FreeRTOS未调度、SD镜像缺组件、IOMUX错误和GPIO硬件损坏。USB与SD的关键差异是：USB测试停在SPL阶段，SD启动会继续进入BL31和U-Boot。

## 官方源码根因

与板载日志版本匹配的NXP TF-A源码：

```text
F:\project\Learning\RTOS\tools\imx-atf-source
branch: lf_v2.12
commit: 4a2e9ef5f9f185bda68470b46365add008903b8c
```

`plat/imx/imx9/imx95/imx95_bl31_setup.c`的`bl31_plat_arch_setup()`明确执行：

```c
mmio_write_32(GPIO2_BASE + 0x10, 0xffffffff); /* PCNS */
mmio_write_32(GPIO2_BASE + 0x18, 0xffffffff); /* PCNP */
```

这会在M7已经完成GPIO初始化之后，把GPIO2所有引脚重新设为非安全/非特权属性。M7是安全特权态主设备，因此对GPIO2_IO14/15的访问变为读0、写入无效。这是RGPIO内部的按引脚属性问题，不是Linux抢占GPIO，也不是单纯的TRDC拒绝。

## 最终修复

M7源码：

```text
F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19\boards\imx95lpd5evk19\freertos_examples\freertos_hello\cm7\freertos_hello.c
```

修复只针对GPIO2_IO14和GPIO2_IO15：

```c
#define GPIO_PIN_MASK ((1UL << 14U) | (1UL << 15U))

static void gpio_reclaim_pins(void)
{
    GPIO2->PCNS &= ~GPIO_PIN_MASK;
    GPIO2->PCNP &= ~GPIO_PIN_MASK;
}
```

在GPIO初始化前调用一次；任务每500 ms运行时先检查bit14/15，只有发现BL31或其他启动组件重新设置了PCNS/PCNP，才再次调用。实测单次初始化或仅在进入循环前调用并不具备稳定性，当前保留循环内按需恢复。

不再使用`GPIO2->PCNS = 0`，因为那会改变GPIO2全部32根引脚。按位清除`0x0000C000`后：

```text
FFFFFFFF & ~0000C000 = FFFF3FFF
```

即只为M7保留bit14/15，其余GPIO2引脚仍保持BL31设置的属性。

## SM与TRDC的关系

最终镜像使用的`mx95frdm-pro-m7gpio.cfg`为：

```text
LM1/M7: GPIO2 OWNER
LM2/A55: GPIO2 ACCESS
LM2/A55: PERLPI_GPIO2 ALL
PIN_GPIO_IO14/15: LM1/M7 OWNER
```

SM配置解决LM、SCMI API和TRDC层的资源访问。`PCNS/PCNP`是GPIO2控制器自身的按引脚安全/特权属性。两层都必须允许，M7才能最终改变物理引脚电平。

早期把GPIO2和`PERLPI_GPIO2`全部从A55移走时，A55启动受阻，导致`WDOG3 -> FCCU errId=19 -> Reset LM2`。最终配置保留A55的API和ACCESS，不需要关闭看门狗或屏蔽FCCU。

## 实机验收

SD启动后，未连接回环线时GPIO14已有波形，寄存器为：

```text
PCNS=FFFF3FFF, PCNP=FFFF3FFF
PDOR=00000000 / 00004000
PDDR=00004000
```

J15-8输出与J15-10输入连接后：

```text
GPIO OUT=0, IN=0, PDIR=00000000
GPIO OUT=1, IN=1, PDIR=00008000
```

逻辑分析仪同时确认GPIO14存在稳定方波。这证明M7启动、FreeRTOS调度、RGPIO驱动、IOMUX、输出电平和输入回读链路均已通过。

## 后续产品化注意点

当前稳定实现不是无条件反复写寄存器，而是按需检测后恢复。产品化时更整洁的方案仍是修改匹配版本BL31，在启动时直接将GPIO2的PCNS和PCNP按位设置为`0xFFFF3FFF`，并对A55/Linux和M7的引脚占用做完整回归。在BL31重新编译和回归完成前，继续使用M7侧按需reclaim方案。

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/IMX95-EVK/待向NXP确认的问题清单.md|待向NXP确认的问题清单]]
- [[10-项目/FRDM-IMX95-PRO/理解-i.MX95启动与资源隔离.md|理解-i.MX95启动与资源隔离]]
- [[10-项目/FRDM-IMX95-PRO/MCUXpresso-SDK获取.md|MCUXpresso-SDK获取]]
