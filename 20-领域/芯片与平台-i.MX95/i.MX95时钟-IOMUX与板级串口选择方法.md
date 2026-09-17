---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 未分类
status: 已整理
evidence: 实机验证
tags: []
updated: 2026-09-17
---

# i.MX95时钟、IOMUX与板级串口选择方法

## 这篇知识解决什么问题

拿到一个i.MX95 M7工程后，不能仅凭`board.h`中的实例号判断实际使用哪个串口，也不能仅凭`SystemCoreClock`宏判断CPU真实频率。需要同时检查芯片时钟模型、System Manager、IOMUX、资源权限、板级原理图和实机结果。

本文提炼自FRDM-IMX95-PRO的M7 FreeRTOS项目。时钟和资源管理机制适用于i.MX95系列；GPIO_IO36/37、CH9114F和COM18属于FRDM-IMX95-PRO板级实例，不适用于其他板卡。

## 一、i.MX95的M7时钟由谁配置

### 1. 先区分四种“频率”

1. **芯片规格上限**：数据手册或SDK说明芯片允许工作的最高频率。
2. **System Manager性能档位**：M33上的System Manager实际选择M7的父时钟、分频和电压档位。
3. **应用软件声明值**：`SystemCoreClock`告诉启动代码、RTOS和调试器当前核心频率是多少。
4. **实测值**：通过DWT周期计数器、定时器或输出时钟验证实际运行频率。

这四者应当一致，但不是同一个东西。修改应用中的`SystemCoreClock`变量不会自动把PLL改到对应频率；反过来，System Manager改变硬件频率后，也必须同步软件使用的时钟值。

### 2. 时钟路径

```text
24 MHz参考时钟
  -> SYSPLL1
  -> DFS/PFD输出
  -> M7时钟根CLOCK_ROOT_M7
  -> 根时钟分频
  -> Cortex-M7核心
```

System Manager源码为M7定义24 MHz、400 MHz、约666.667 MHz和800 MHz档位。800 MHz档使用SYSPLL1的800 MHz父时钟并采用1分频。M7 SDK则把`DEFAULT_SYSTEM_CLOCK`定义为800 MHz，供当前工程的`SystemCoreClock`和FreeRTOS时间换算使用。

### 3. 与STM32的区别

两者的物理结构都可概括为“振荡源 -> PLL -> MUX/分频 -> 核心和外设”。STM32单片机项目通常由应用启动代码直接配置RCC；i.MX95是异构SoC，电源、性能域和核心时钟由System Manager统一管理，因此M7应用的`clock_config.c`未必包含完整PLL配置。

判断i.MX95 M7频率时应按以下顺序检查：

```text
芯片电气规格
  -> System Manager性能表和当前档位
  -> M7 SDK中的SystemCoreClock
  -> DWT/定时器实测
```

## 二、外设时钟为什么不能等同于核心时钟

LPUART有独立的时钟根。以LPUART7为例，它可以从24 MHz振荡源、SYSPLL1分频输出或FRO中选择父时钟。当前M7运行在800 MHz时，LPUART7仍可以使用24 MHz根时钟，再由LPUART内部波特率分频器生成115200 bit/s。

```text
M7核心时钟 -> 决定指令执行和DWT计数速度
LPUART根时钟 -> 决定串口波特率分频的输入频率
FreeRTOS tick -> 由内核定时源和configCPU_CLOCK_HZ共同决定
```

排查串口乱码时，应先检查传给驱动的LPUART根时钟和波特率，不应直接拿M7的800 MHz计算串口分频。

## 三、如何选择一个LPUART实例

i.MX9596包含LPUART1至LPUART8。芯片“存在某个LPUART”不代表开发板“可以直接使用这个LPUART”。一个实例可用必须同时满足：

1. 芯片IOMUX允许目标焊盘复用为该实例的TX/RX；
2. 开发板原理图把这些焊盘接到可使用的接口或转换芯片；
3. System Manager给M7分配外设、时钟、daisy和引脚权限；
4. 软件中的外设基地址、实例号、中断号、时钟根和pin mux相互一致；
5. 实机收发验证通过。

因此不能通过“换一个实例号”完成串口迁移。迁移LPUART时要把IOMUX、时钟、IRQ、SM权限和板级连线作为一个整体检查。

## 四、IOMUX到底做了什么

SoC封装上的一个PAD可以连接GPIO、UART、SPI等多个内部外设，但同一时刻通常只选择一个主要功能。IOMUX寄存器中的MUX模式控制内部开关，输入信号还可能经过daisy选择器决定送到哪个外设输入端。

例如i.MX95芯片定义允许：

```text
GPIO_IO36 PAD -> GPIO5_IO16 或 LPUART7_TX 或 LPSPI4_SOUT
GPIO_IO37 PAD -> GPIO5_IO17 或 LPUART7_RX 或 LPSPI4_SCK
```

这里的`GPIO_IO36`首先是PAD名称，并不表示它永久属于GPIO。只有选择GPIO功能后，它才由对应GPIO控制器的数据和方向寄存器控制。

IOMUXC（管复用和电气）与RGPIO（管方向和数据）为什么分成两个外设、以及和STM32的对应关系，见[IOMUXC与RGPIO的分工](i.MX95引脚控制-IOMUXC与RGPIO分工.md)。

## 五、FRDM-IMX95-PRO上的LPUART7实例

这部分只适用于FRDM-IMX95-PRO：

```text
M7 LPUART7
  -> GPIO_IO36/37的LPUART7复用
  -> 原理图uart7.TX/RX网络
  -> DEB_UART7_TX/RX
  -> CH9114F四路USB-UART桥
  -> J22 USB-C
  -> Windows中的一个COM口（当前机器实测为COM18）
```

COM编号由Windows枚举决定，不是芯片或原理图固定属性。换电脑后应根据各串口输出内容重新识别，不能把“LPUART7永远等于COM18”写成通用结论。

## 六、资料和证据

### 官方/源码依据

- M7默认核心时钟：`devices/MIMX9596/system_MIMX9596_cm7.h`
- M7允许的最高频率和时钟根：`devices/MIMX9596/drivers/fsl_clock.h`
- System Manager性能档位：`imx-sm/devices/MIMX95/sm/dev_sm_perf.c`
- M7各档位频率：`imx-sm/devices/MIMX95/MIMX95_elec_spec.h`
- GPIO_IO36/37复用选项：`imx-sm/devices/MIMX95/drivers/fsl_iomuxc.h`
- Pro板物理连接：`SPF-95794_B1.pdf`第6页和第27页。

### 项目证据

- [任务、LPUART和GPIO代码理解](../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md)
- [完整开发记录](../../10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md)

## 七、可复用的排查清单

出现“串口无输出”时依次确认：

1. 程序是否真正运行到串口初始化；
2. 外设实例、基地址和IRQ是否一致；
3. LPUART根时钟是否启用，传给驱动的频率是否正确；
4. TX/RX的IOMUX和daisy是否正确；
5. M7是否拥有外设、时钟和引脚权限；
6. 原理图上的信号是否接到当前使用的接口；
7. 终端的COM口、波特率、电平和收发方向是否正确；
8. 用逻辑分析仪从SoC引脚到转换芯片逐段确认波形。
