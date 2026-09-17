---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# i.MX95引脚控制：IOMUXC与RGPIO的分工

## 这篇知识解决什么问题

在STM32上初始化一个GPIO，只要操作`GPIOx`这一组寄存器。在i.MX95上同样一件事却要分两个外设来做，容易搞不清“为什么分成两类”。本文说明IOMUXC和RGPIO各管什么、为什么分开，以及M7使用一根GPIO要过哪几关。

## 一、和STM32最大的区别

STM32：一个引脚的功能选择（`MODER`选输入/输出/AF、`AFR`选哪个复用）、电气属性（`OSPEEDR/PUPDR/OTYPER`）和数据（`ODR/IDR`）都在**同一个GPIO外设**里，所以“初始化一个引脚”就是操作一组GPIO寄存器。

i.MX95把这两件事拆成两个外设：

- **IOMUXC**（I/O Multiplex Controller，引脚复用控制器）：管“这个物理引脚对外接哪个功能、电气属性如何”。**全芯片共用一个**。
- **RGPIO**（GPIO控制器，GPIO1~GPIO5）：管“当引脚接到GPIO功能后”的方向、输出、输入和中断。

| STM32 | i.MX95 |
|---|---|
| `GPIOx->MODER` 选 输入/输出/AF | IOMUXC的**MUX寄存器**选功能 |
| `GPIOx->AFR` 选哪个AF编号 | **MUX寄存器的值**（0=GPIO2_IO14，1=LPUART3_TX…） |
| `GPIOx->OSPEEDR/PUPDR/OTYPER` | IOMUXC的**PAD控制寄存器**（驱动能力/上下拉/压摆率） |
| `GPIOx->ODR/IDR` 方向与数据 | **RGPIO**的`PDDR/PDOR/PDIR` |

结论：i.MX95的“引脚复用/电气”和“GPIO数据”不在一个外设里，所以代码分两步——先配IOMUXC（这根针是否接到GPIO2的bit14），再配RGPIO（这个bit怎么动）。

## 二、IOMUXC是什么

- 全称：I/O Multiplex Controller。
- 层级：SoC片内外设，寄存器内存映射在`0x443C0000`（i.MX9596）。
- 作用：一个物理pad内部可以接到GPIO、LPUART、LPSPI、SAI等多个功能，但同一时刻通常只选一个主要功能。MUX寄存器就是“功能选择开关”；PAD控制寄存器设置驱动能力、上下拉、压摆率等电气参数；输入类信号还可能经过daisy（输入选择）决定送到哪个外设输入端。
- 实例（i.MX9596源码可确认）：pad `GPIO_IO14`可选0=GPIO2_IO14、1=LPUART3_TX、6=LPUART4_TX…；pad `GPIO_IO36`可选0=GPIO5_IO16、2=LPUART7_TX、4=LPSPI4_SOUT。

### IOMUXC_BASE是什么

```c
#define IOMUXC_BASE (0x443C0000u)
```

它只是**IOMUXC外设寄存器块在CPU地址空间里的起始地址**。外设寄存器是内存映射的，CPU访问这段地址就等于读写IOMUXC的寄存器。

- 它不是“把硬件地址绑定到GPIO寄存器”。
- 真正决定“这根pad接什么功能”的是**写进MUX寄存器的值**；地址只负责“找到这个寄存器”。
- IOMUXC和RGPIO是**串联**关系，不是绑定关系：IOMUXC决定“pad→GPIO2 bit14”，RGPIO决定“bit14怎么动”。

```text
物理pad（如GPIO_IO14=J15-8）
   │
[IOMUXC MUX]  ← 0→接到GPIO2.bit14；1→LPUART3_TX；6→LPUART4_TX…
[IOMUXC PAD]  ← 驱动能力/上下拉/压摆率
   │  （MUX选0时）
   ▼
[RGPIO/GPIO2] ← PDDR方向、PDOR输出、PDIR输入、PCNS/PCNP安全属性、中断
```

## 三、RGPIO是什么

RGPIO是GPIO控制器（GPIO1~GPIO5），只管“当pad复用到GPIO功能后”的行为。常用寄存器：

| 寄存器 | 作用 |
|---|---|
| `PDDR` | 方向：1=输出，0=输入（复位默认全0，即引脚默认输入） |
| `PDOR` | 输出值 |
| `PSOR`/`PCOR` | 置位/清零输出（写1生效，类似STM32的`BSRR`） |
| `PDIR` | 读取引脚当前电平 |
| `PCNS`/`PCNP` | 逐引脚的安全/特权属性（i.MX特有） |

`RGPIO_PinInit(base, pin, config)`做的事：

```c
if (输入) base->PDDR &= ~(1UL << pin);          // 方向位清0=输入
else { 写PSOR/PCOR设置初始电平; base->PDDR |= (1UL << pin); }  // 再置1=输出
```

`RGPIO_PinWrite()`用`PSOR/PCOR`改变输出，`RGPIO_PinRead()`读`PDIR`。这对应STM32设置`MODER`和`ODR`的动作，区别是STM32一个引脚用2 bit表示方向，i.MX用1 bit。因为`PDDR`默认全0，输入脚不初始化也是输入，不调用`RGPIO_PinInit()`也能读，但显式初始化更清楚。

## 四、为什么要分成两类

i.MX95引脚多、可复用功能多，而且多数功能不是GPIO（LPUART/SPI/SAI…）。把“引脚对外接什么”集中到全局IOMUXC，职责更清晰，各功能外设各管自己；STM32端口引脚少、复用简单，就并入GPIO/外设寄存器。功能上两者等价，只是组织方式不同。

## 五、M7用一根GPIO要过哪几关

1. **引脚所有权**（SM配置）：该pad是否归M7，如`PIN_GPIO_IO14 OWNER`。它只说明“M7有权配这根pad的IOMUX”。
2. **IOMUXC配置**：M7**不直接写**IOMUXC，通过SCMI请SM代写（选功能+电气）。SM配完即结束，不持续控制。
3. **RGPIO访问**：M7直接操作GPIO2寄存器（受TRDC和PCNS/PCNP约束）。

三层要分开：引脚所有权（谁能配IOMUX）、TRDC（谁能访问寄存器窗口）、PCNS/PCNP（引脚数据寄存器归安全世界还是非安全世界）。

## 六、常见误区

- 把`IOMUXC_BASE`理解成“绑定GPIO地址”：它只是IOMUXC寄存器的访问地址。
- 以为M7能直接写IOMUXC：本板SDK走`SM_PINCTRL`路径（源码可确认），M7经SCMI请SM代写。
- 把“引脚复用”和“GPIO安全域（PCNS/PCNP）”混为一谈：前者决定引脚接什么功能，后者决定这根GPIO的数据寄存器归哪个世界访问。
- 把“引脚所有权（`PIN_* OWNER`）”当成“RGPIO归谁”：它只管IOMUX配置权。

## 七、适用范围与依据

- 适用范围：i.MX95系列的IOMUXC/RGPIO组织方式；具体pad名、功能编号和地址是i.MX9596的值。
- 源码依据（`SDK_26_06_00_IMX95LPD5EVK-19`）：
  - `devices/MIMX9596/MIMX9596_cm7_COMMON.h`：`IOMUXC_BASE (0x443C0000)`
  - `devices/MIMX9596/drivers/fsl_iomuxc.h`：`IOMUXC_SetPinMux/SetPinConfig`（直接写寄存器版本）
  - `components/pinctrl/hal_pinctrl.c`：按`hal_config.h`选择SM版或直写版
  - `components/sm/pinctrl/sm_pinctrl.c`：SM版，经SCMI发请求
  - `components/pinctrl/porting/platform/imx95/hal_pinctrl_platform.h`：pad功能宏
- 项目证据：[FRDM-IMX95-PRO FreeRTOS任务创建与LED代码理解](../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md)
