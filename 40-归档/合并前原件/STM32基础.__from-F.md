---
type: 归档
scope: 全库
doc_type: 教程
status: 已归档
evidence: 待标注
tags: []
updated: 2026-09-17
---

新建工程：
· 建立工程文件夹，Keil中新建工程，选择型号
· 工程文件夹里建立Start、Library、User等文件夹，复制固件库里面的文件到工程文件来
· 工程里对应建立Start、Library、User等同名称的分组，然后将文件夹内的文件添加到工程分组里
· 工程选项，C/C++，Include Paths内声明所有包含头文件的文件夹
· 工程选项，C/C++，Define内定义USE_STDPERIPH_DRIVER
· 工程选项，Debug，下拉列表选择对应调试器，Settings，Flash，Download里勾选Reset and Run


## GPIO
GPIO（General Purpose Input Output）通用输入输出口，是MCU与外部世界交互的最基本接口。

- 每个GPIO端口有16个引脚（如PA0~PA15）
- 电平范围：0V~3.3V，部分引脚可容忍5V输入（不能输出5V）
- STM32的GPIO挂载在**APB2总线上**（AHB→APB2→GPIO）

### 八种工作模式

| 模式   | 方向  | 用途                       |                               |
| ---- | --- | ------------------------ | ----------------------------- |
| 推挽输出 | 输出  | 驱动LED、蜂鸣器、控制信号           | 可输出引脚电平，高电平接VDD，低电平接VSS       |
| 开漏输出 | 输出  | I2C等多设备总线，需外部上拉          | 可输出引脚电平，高电平为高阻态，无驱动能力，低电平接VSS |
| 复用推挽 | 输出  | 作为UART/SPI/I2C的TX/SCK等引脚 | 由片上外设控制，高电平接VDD，有驱动能力，低电平接VSS |
| 复用开漏 | 输出  | I2C的SDA/SCL              | 由片上外设控制，高电平为高阻态，低电平接VSS       |
| 浮空输入 | 输入  | 读取外部电平（无内部上拉）            | 可读取引脚电平，若引脚悬空，则电平不确定          |
| 上拉输入 | 输入  | 按键检测（默认高电平）              | 可读取引脚电平，内部连接上拉电阻，悬空时默认高电平     |
| 下拉输入 | 输入  | 按键检测（默认低电平）              | 可读取引脚电平，内部连接下拉电阻，悬空时默认低电平     |
| 模拟输入 | 输入  | ADC采样                    | GPIO无效，引脚直接接入内部ADC            |
4种输入模式
- **浮空**：引脚内部什么都不接，电平完全取决于外部信号。外部没接好时电平是浮动的，容易受干扰，所以实际项目中很少单独用。
- **上拉**：内部通过一个电阻把引脚拉到VDD（高电平）。外部没驱动时读到的是高电平，适合按键检测（按键按下接地，读到低电平）。
- **下拉**：内部通过一个电阻把引脚拉到VSS（低电平）。外部没驱动时读到的是低电平，适合按键检测（按键按下接VDD，读到高电平）。
- **模拟**：引脚断开数字电路，直接连接ADC，用于采集模拟信号（如电压值）。

上拉和下落的本质区别在于“默认电平”不同：**上拉默认高、下拉默认低**，分别对应不同的外部电路设计，选哪个取决于外部电路怎么接更方便。

**输出模式（4种）**：推挽、开漏、复用推挽、复用开漏。核心区别在于“驱动能力”和“总线兼容性”。

- **推挽**：能主动输出高电平也能主动输出低电平，驱动能力强，点LED、控制蜂鸣器都用这个。
- **开漏**：只能主动拉低，不能主动输出高电平（高电平要靠外部上拉电阻）。用于I2C等多设备共享总线的场景，多个设备都可以拉低总线，不会短路。
- **复用推挽/复用开漏**：引脚不再由你的程序直接控制，而是交给UART、SPI、I2C等片上外设来使用。比如UART的TX引脚配置为复用推挽，I2C的SCL/SDA配置为复用开漏。

常用的操作，标准库写法：
```c
// 初始化（需要四个结构体成员）
GPIO_InitTypeDef GPIO_InitStruct;
GPIO_InitStruct.GPIO_Pin = GPIO_Pin_13;
GPIO_InitStruct.GPIO_Mode = GPIO_Mode_Out_PP;   // 推挽输出
GPIO_InitStruct.GPIO_Speed = GPIO_Speed_50MHz;
GPIO_Init(GPIOC, &GPIO_InitStruct);

// 操作电平
GPIO_SetBits(GPIOC, GPIO_Pin_13);   // 输出高电平
GPIO_ResetBits(GPIOC, GPIO_Pin_13); // 输出低电平
GPIO_ReadInputDataBit(GPIOA, GPIO_Pin_0); // 读取输入电平
```


## RCC
RCC ：reset clock control  复位和时钟控制器。


**使用任何外设之前必须先使能它的时钟**
**系统时钟初始化由启动文件和SystemInit()完成**，不需要自己配置PLL。绝大多数项目直接用默认的72MHz（HSE 8MHz → PLL ×9 → 72MHz）。如果要改主频，在`system_stm32f10x.c`里改`PLL_MUL`宏就行，不需要动别的地方。
**不同外设挂在不同总线上**，使能时钟的API前缀不一样。

系统时钟SYSCLK通常由外部晶振（HSE，8MHz）经PLL 9倍频得到72MHz，再通过AHB/APB1/APB2分频器分配到各个总线。GPIO挂在APB2上（72MHz），定时器挂在APB1上（36MHz），USART1挂在APB2上，USART2/3挂在APB1上。频率决定速度，总线决定挂载位置。
APB2外设使用`RCC_APB2PeriphClockCmd()`，APB1外设使用`RCC_APB1PeriphClockCmd()`，AHB外设使用`RCC_AHBPeriphClockCmd()`。配置GPIO前必须调用`RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE)`，否则寄存器写不进去。

调试时若遇到外设不工作或频率异常，优先检查时钟是否使能，其次检查时钟源配置是否正确。大部分外设问题都出在时钟未使能。
UCOS的任务调度依赖SysTick定时器，SysTick的时钟来自AHB（72MHz），因此系统时钟配置决定了UCOS的时间基准。时钟配错了，整个UCOS的时序都会偏。