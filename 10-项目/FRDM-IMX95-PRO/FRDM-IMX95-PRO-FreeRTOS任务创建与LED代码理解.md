---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# FRDM-IMX95-PRO FreeRTOS任务创建与LED代码理解

> 类型：项目学习记录。本文解释当前FRDM-IMX95-PRO工程的具体代码、引脚和验证过程；可迁移的方法已提炼到[个人知识库：i.MX95时钟、IOMUX与板级串口选择方法](../../20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md)。

## 一、当前程序运行顺序

```text
M7复位并进入main()
  -> BOARD_InitHardware()
  -> 初始化LPUART7收发
  -> 创建串口接收队列
  -> 创建echo_task
  -> 创建led_task
  -> 打开LPUART7接收中断
  -> vTaskStartScheduler()
  -> FreeRTOS开始按优先级调度任务
```

`vTaskStartScheduler()`之前仍是普通的顺序执行程序；调用之后，调度器接管CPU，`main()`后面的死循环正常情况下不会执行。

## 二、板级初始化

`BOARD_InitHardware()`位于`hardware_init.c`，依次完成：

1. `SM_Platform_Init()`：建立M7与System Manager交互所需的平台环境。
2. `BOARD_InitBootPins()`：配置GPIO14/15和LPUART7 TX/RX的引脚复用及电气属性。
3. `BOARD_BootClockRUN()`：同步/读取应用侧可见的时钟信息；M7性能档位和核心时钟根由System Manager配置。
4. `BOARD_InitDebugConsole()`：初始化`PRINTF()`使用的调试串口。
5. `BOARD_ConfigMPU()`：配置M7的内存保护和存储属性。
6. `GPIO2->PCNS = 0`：在M7初始化阶段设置GPIO2安全属性；完整A55启动后还需要按位恢复GPIO14/15。

## 三、为什么使用LPUART7

### 3.1 LPUART是什么

`LPUART`是 **Low-Power Universal Asynchronous Receiver/Transmitter**，即低功耗通用异步收发器。它和STM32中的USART/UART属于同一类外设，负责把CPU写入发送寄存器的字节转换成TX线上的串行波形，也把RX线上的串行波形还原成字节。`LP`强调该外设支持低功耗时钟/电源场景，不代表它只能低速工作。

i.MX9596的设备头文件列出了LPUART1到LPUART8：

```text
LPUART1_IRQn ... LPUART8_IRQn
LPUART1_BASE ... LPUART8_BASE
```

依据：

```text
SDK_26_06_00_IMX95LPD5EVK-19/devices/MIMX9596/MIMX9596_cm7_COMMON.h
```

所以LPUART7不是“唯一的串口”，而是芯片上的第7个LPUART控制器；其他LPUART也可以使用，但必须同时满足引脚复用、时钟、SM/TRDC权限和板上物理连接这几个条件。

### 3.2 为什么当前工程选LPUART7

当前选择不是凭经验指定，而是四个条件同时决定的：

1. 当前M7工程的`board.h`把`BOARD_DEBUG_UART_INSTANCE`定义为7，并把调试串口时钟根定义为`hal_clock_lpuart7`。
2. `mx95frdm-pro-m7gpio.cfg`的M7资源中包含`LPUART7 OWNER`，说明这个M7逻辑机被分配了LPUART7资源。
3. 当前工程的引脚配置把GPIO_IO36/37复用到LPUART7，且M7拥有`PIN_GPIO_IO36`和`PIN_GPIO_IO37`。
4. 这组信号已经通过板上串口桥和COM18实测输出、输入正常。

因此换成LPUART1、LPUART2或其他LPUART，不能只改`LPUART7`这个宏，还要重新确认对应引脚是否接到J22/CH9114、SM是否分配该控制器、时钟根是否正确以及中断号是否更换。当前工程使用LPUART7，是因为它是这块Pro板当前M7调试链路已经配置并验证好的串口。

### 3.3 GPIO_IO36/37为什么是LPUART7 TX/RX

芯片一个物理焊盘可以有多种复用功能，GPIO_IO36这个名字只是该焊盘的默认GPIO功能名，不代表它只能当GPIO。引脚复用表会把同一个焊盘的某个MUX选项连接到LPUART7。

当前工程的`pin_mux.c`不是手写猜测，而是MCUXpresso Config Tools根据芯片封装和工程引脚配置生成的文件。文件中的工具配置注释明确写着：

```text
GPIO_IO36 -> LPUART7_TX
GPIO_IO37 -> LPUART7_RX
```

生成的实际代码进一步使用了有明确语义的芯片宏：

```c
HAL_PINCTRL_PLATFORM_IOMUXC_PAD_GPIO_IO36__LPUART7_TX
HAL_PINCTRL_PLATFORM_IOMUXC_PAD_GPIO_IO37__LPUART7_RX
```

这两个宏来自MIMX9596的设备/引脚定义，含义是把对应IOMUX选择值写入芯片的引脚复用寄存器。板级原理图再把这些SoC信号连接到板上的调试串口桥，最后电脑上表现为COM18。完整依据是：芯片引脚复用定义 -> 工程生成的`pin_mux.c` -> Pro原理图的串口连接 -> COM18实测。

### 3.4 LPUART7时钟怎么来的

STM32常见流程是外部HSE进入PLL，PLL输出SYSCLK，再给USART分频。i.MX95也有外部24 MHz振荡源、系统PLL、DFS/PFD输出、时钟根选择器和根时钟分频器，但它把这棵树拆成了两层：M33上的System Manager负责芯片级性能档位、电源域和核心时钟，M7应用通过HAL请求或读取自己需要的外设时钟。于是不能只在应用工程里寻找一段类似`HSE_VALUE -> PLLM -> PLLN -> SYSCLK`的代码。

#### 3.4.1 M7的800 MHz是怎么知道的

这个数有三层依据，不能混成一个结论：

1. **芯片/SDK允许的频率**：`devices/MIMX9596/drivers/fsl_clock.h`定义`SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY`为800 MHz，并注明这是使用Overdrive Voltage时CM7的最大频率；`system_MIMX9596_cm7.h`把`DEFAULT_SYSTEM_CLOCK`定义为`800000000u`。
2. **System Manager的实际性能档位**：M33源码`tools/wsl/UbuntuBuild/rootfs/root/nxp-build.hEoR5k/imx-sm/devices/MIMX95/sm/dev_sm_perf.c`定义M7性能域的时钟根为`CLOCK_ROOT_M7`。它给M7配置了四个档位：停车档24 MHz、低档400 MHz、正常档约666.667 MHz、Overdrive档800 MHz；800 MHz档使用`SYSPLL1_PFD1`作为父时钟，根分频为1。`MIMX95_elec_spec.h`把这些档位分别定义成`ES_400000KHZ`、`ES_666667KHZ`和`ES_800000KHZ`。
3. **当前工程的运行约定和实测**：FreeRTOS通过`configCPU_CLOCK_HZ (SystemCoreClock)`计算节拍，`SystemCoreClock`初值来自SDK的800 MHz默认值；此前用M7的DWT周期计数器测得的运行频率约800 MHz，与当前启动配置相符。因此当前可以说“这套启动配置下M7按800 MHz运行”，而不能说“只要包含这个头文件，任何启动配置下硬件都必然是800 MHz”。

对应的时钟层级是：

```text
外部24 MHz振荡源
  -> SYSPLL1
  -> PFD1输出约800 MHz
  -> M7时钟根 CLOCK_ROOT_M7
  -> M7核心和总线
  -> FreeRTOS用SystemCoreClock换算tick和延时
```

这和STM32的相同点是都存在“振荡源 -> PLL -> 根时钟/分频 -> CPU和外设”的关系；不同点是i.MX95的M7频率是System Manager性能域的一部分，配置在M33固件的性能表中，不是由M7应用单独接管全部PLL和电源配置。M7应用头文件中的800 MHz是供启动代码、FreeRTOS和调试工具使用的频率声明，真正改变频率应通过System Manager支持的性能档位完成。

当前工程的实际调用链是：

```text
main()
 -> BOARD_InitHardware()
 -> BOARD_BootClockRUN()
 -> BOARD_InitDebugConsole()
 -> HAL_ClockSetRate(hal_clock_lpuart7, 24 MHz)
 -> HAL_ClockEnable(hal_clock_lpuart7)
 -> DbgConsole_Init(7, 115200, ..., HAL_ClockGetRate(...))
```

`clock_config.c`中的`BOARD_BootClockRUN()`调用`BOARD_InitClock()`，后者遍历HAL时钟源并读取其频率；它不是STM32风格的应用层PLL寄存器配置。M7核心时钟的默认软件值来自：

```text
devices/MIMX9596/system_MIMX9596_cm7.h
#define DEFAULT_SYSTEM_CLOCK 800000000u
```

并由`system_MIMX9596_cm7.c`初始化`SystemCoreClock`。FreeRTOS再通过：

```c
#define configCPU_CLOCK_HZ (SystemCoreClock)
```

使用这个值配置节拍和时间换算。这个`800 MHz`是SDK对该M7工程的默认核心时钟声明；实际芯片时钟还要与启动时的System Manager时钟配置一致，不能仅凭宏就断言所有启动场景都一定是800 MHz。之前实时性测试中用DWT周期数反推约800 MHz，与该默认值相互吻合。

LPUART7外设时钟是另一条时钟路径，不等于M7核心时钟。芯片时钟驱动`fsl_clock.c`列出了LPUART7根时钟的四个候选父时钟：24 MHz振荡源、`SYSPLL1_PFD0_DIV2`、`SYSPLL1_PFD1_DIV2`和FRO。当前`board.c`把LPUART7根时钟设为24 MHz并使能；`LPUART_Init()`接收这个外设时钟，根据115200波特率计算LPUART分频值。也就是说，M7核心800 MHz负责执行代码，LPUART7的24 MHz负责产生串口位时序，两者必须分开理解。

```text
GPIO_IO36 -> LPUART7_TX
GPIO_IO37 -> LPUART7_RX
```

这组信号连接到板载CH9114串口桥，对应实机COM18，前期测试已经确认COM18能够看到M7输出并向M7输入字符。因此使用LPUART7不是任意选择，而是由芯片复用能力、Pro板布线、System Manager权限和实机验证共同确定。这里要区分两件事：芯片资料说明“GPIO_IO36/37可以复用为LPUART7”，原理图说明“这两个信号被板子接到CH9114”，实机COM18回显说明“整条链路确实工作”。

### 3.5 为什么不是LPUART1到LPUART6或LPUART8

`MIMX9596_cm7_COMMON.h`列出LPUART1至LPUART8的基地址和中断号，所以芯片层面不是只有LPUART7。选择外设时要同时检查四件事：

1. **SoC引脚复用**：目标焊盘必须有该LPUART的TX/RX MUX选项；
2. **Pro板原理图**：该TX/RX网络必须真的接到排针、调试桥或目标外设；
3. **System Manager权限**：M7必须拿到外设、时钟根、daisy输入输出和对应引脚权限；
4. **工程初始化**：`board.h`、时钟根、IRQ、`pin_mux.c`和驱动实例必须一致。

当前工程四项都指向LPUART7：板级调试链路使用`uart7.TX/RX`，SM配置给M7分配LPUART7及GPIO_IO36/37，工程把调试实例定义为7，并已在COM18实测输入输出。换成其他LPUART不能只修改`BOARD_DEBUG_UART_INSTANCE`，否则可能出现“代码能编译但没有物理串口”“TX/RX没有复用到目标引脚”“时钟或权限不足”等问题。

### 3.6 GPIO_IO36/37为什么是LPUART7的TX/RX

依据不是文件名，也不是因为GPIO编号接近7，而是芯片IOMUX表给出的MUX选择。`tools/wsl/UbuntuBuild/rootfs/root/nxp-build.hEoR5k/imx-sm/devices/MIMX95/drivers/fsl_iomuxc.h`明确列出：

```text
IOMUXC_PAD_GPIO_IO36__LPUART7_TX
IOMUXC_PAD_GPIO_IO37__LPUART7_RX
```

这些宏包含PAD寄存器地址、MUX模式值、输入选择寄存器和输入选择值；`pin_mux.c`调用对应宏，本质上是把GPIO_IO36这个焊盘内部的信号开关接到LPUART7发送端，把GPIO_IO37接到LPUART7接收端。GPIO_IO36/37仍然是焊盘名称，`GPIO5_IO_BIT16/17`是它们的另一种GPIO复用功能；同一个焊盘一次只能选择其中一种主要功能。

板级证据在原理图`SPF-95794_B1.pdf`：第6页列出SoC侧`uart7.TX`和`uart7.RX`网络，第27页列出`DEB_UART7_TX`和`DEB_UART7_RX`并连接到板载CH9114F调试串口芯片。于是完整信号链是：

```text
M7执行LPUART_WriteBlocking()
  -> LPUART7发送寄存器
  -> SoC内部LPUART7 TX
  -> IOMUX把GPIO_IO36接到LPUART7_TX
  -> 原理图uart7.TX/DEB_UART7_TX
  -> CH9114F
  -> USB-C J22
  -> 电脑COM18
```

接收方向相反：

```text
电脑COM18 -> USB-C J22 -> CH9114F -> DEB_UART7_RX/uart7.RX
  -> IOMUX GPIO_IO37 -> LPUART7_RX寄存器
  -> LPUART7_IRQHandler() -> FreeRTOS队列 -> echo_task
```

初始化分为三层：

1. `BOARD_InitBootPins()`把GPIO_IO36/37复用为LPUART7 TX/RX。
2. `BOARD_InitDebugConsole()`设置LPUART7时钟并初始化`PRINTF()`后端。
3. `main()`调用`LPUART_GetDefaultConfig()`、设置115200波特率并开启收发，再调用`LPUART_Init()`。

接收使用中断：LPUART7收到字符后进入`LPUART7_IRQHandler()`，中断读取一个字节并通过`xQueueSendFromISR()`写入队列。`echo_task`平时阻塞在`xQueueReceive()`；收到数据后被唤醒，再调用`LPUART_WriteBlocking()`把字符发回COM18。这就是当前最简单的“中断生产数据，任务消费数据”的任务通信。

## 四、任务创建

任务通过`xTaskCreate()`创建：

```c
xTaskCreate(led_task,
            "led_task",
            configMINIMAL_STACK_SIZE + 100,
            NULL,
            led_task_PRIORITY,
            NULL);
```

六个参数依次是任务函数、任务名、栈深度、传入参数、优先级和任务句柄保存位置。当前没有向LED任务传参数，也暂时不保存句柄，所以两个位置都是`NULL`。

每个任务都有独立栈，用来保存局部变量、函数调用现场和任务切换时的CPU寄存器。当前`configMINIMAL_STACK_SIZE=90`，LED任务栈深度为190个`StackType_t`；当前IAR Cortex-M端口的`StackType_t`为32位，因此约为760字节。这个参数是栈元素数量，不是直接填写字节数。

任务栈从FreeRTOS堆中动态分配，当前使用heap_4，`configTOTAL_HEAP_SIZE=10240`字节。除了任务栈，任务控制块和队列也会占用这块堆。

## 五、任务优先级和阻塞

`configMAX_PRIORITIES=5`表示可用优先级是0到4，数字越大优先级越高：

```text
echo_task = 4
led_task  = 3
Idle任务  = 0
```

`configUSE_PREEMPTION=1`表示开启抢占。当串口收到字符时，中断把数据放进队列，优先级4的`echo_task`从阻塞态变成就绪态，会抢占优先级更低的LED任务。

LED任务调用`vTaskDelay(500 ms)`后进入阻塞态，不占用CPU。500 ms到期后变为就绪态，得到运行机会后翻转LED，再次阻塞。LED闪烁不是靠空循环延时，因此等待期间CPU可以运行其他任务。

## 六、空闲任务和栈溢出检测

FreeRTOS启动调度器时会自动创建Idle任务，优先级为0。当应用任务都处于阻塞态时，Idle任务运行。`configUSE_IDLE_HOOK=1`后，Idle任务会调用`vApplicationIdleHook()`；当前函数只增加计数，不做串口打印或阻塞操作。

`configCHECK_FOR_STACK_OVERFLOW=2`开启任务栈边界检查。检测到任务栈溢出时，内核调用`vApplicationStackOverflowHook()`。当前处理方式是关闭中断并停在死循环中，防止栈已经损坏后继续运行。后续可在进入死循环前记录任务名，但调试输出本身也会使用栈，应保持处理函数简单。

## 七、GPIO为什么叫GPIO2_IO14

i.MX95有多组GPIO控制器，控制器按GPIO1、GPIO2、GPIO3等分组，每组控制器内部再用bit编号区分引脚。`GPIO2_IO14`表示GPIO2控制器中的第14位，不表示SoC上的第14个GPIO控制器。

当前`pin_mux.c`明确写有：

```c
HAL_PINCTRL_PLATFORM_IOMUXC_PAD_GPIO_IO14__GPIO2_IO_BIT14
HAL_PINCTRL_PLATFORM_IOMUXC_PAD_GPIO_IO15__GPIO2_IO_BIT15
```

因此可以确认：

```text
GPIO_IO14物理焊盘 -> 复用为GPIO2的bit14
GPIO_IO15物理焊盘 -> 复用为GPIO2的bit15
```

这也是代码使用`GPIO2`和引脚号14/15的依据。Pro板扩展排针上，GPIO14对应J15-8，GPIO15对应J15-10。

## 八、GPIO初始化的主链条

先给主脉络（可类比Backup SRAM的“开电源→开时钟→解保护→读写”，i.MX95把它分成“通信、复用、权限、方向”四步）：

```text
main()
 -> BOARD_InitHardware()
      -> SM_Platform_Init()     // ① 建立M7与SM的通信（MU邮箱/SMT通道）
      -> BOARD_InitBootPins()   // ② 请SM把pad复用成GPIO并设电气（走SCMI）
      -> ...
      -> GPIO2->PCNS = 0        // ③ M7直接写RGPIO：设置GPIO2安全属性
 -> led_task()
      -> RGPIO_PinInit()        // ④ M7直接写RGPIO：方向、初值
      -> RGPIO_PinWrite/Read()  // ⑤ M7直接写RGPIO：输出/读取
```

要点：**②的引脚复用属于IOMUXC，M7不直接写，要经SCMI请SM代写；③④⑤属于RGPIO，M7直接写。** 两者分工见[知识库：IOMUXC与RGPIO的分工](../../20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md)。

### 8.1 引脚复用（IOMUXC，经SM）

`BOARD_InitPins()`（`pin_mux.c`）对IO14/IO15/IO36/IO37各调用一次`HAL_PinctrlSetPinMux`+`HAL_PinctrlSetPinCfg`。本板`hal_config.h`选`SM_PINCTRL 1`，所以HAL内部走SCMI→SM→由SM写IOMUXC；这就是用`HAL_PinctrlSetPinMux`而不是直接写寄存器的`IOMUXC_SetPinMux`的原因（后者只在M7自己拥有IOMUXC时用）。

`HAL_PinctrlSetPinMux`的6个参数（宏给前5个，第6个传`0U`）：

| 参数 | 用来干什么 |
|---|---|
| `muxRegister` | 指认是哪根pad（用它的MUX寄存器地址） |
| `muxMode` | 把这根pad设成哪种功能：0=GPIO，2=LPUART7 |
| `inputRegister`/`inputDaisy` | 输入功能才用（选输入来源）；GPIO/TX传0 |
| `configRegister` | 指认是哪根pad的PAD控制寄存器 |
| `inputOnfield`（第6个） | 是否强制打开输入，本项目全0 |

`SM_PINCTRL_SetPinMux()`把“改哪根pad、改成什么功能”打包成SCMI配置项，并把地址换算成SM的引脚编号（`(muxRegister-0x443C0000)/4`，IO14=18），发给SM；`SM_PINCTRL_SetPinCfg()`同理，只是发电气设置。SM只代写这一次，不持续控制GPIO。

### 8.2 资源访问权限

System Manager配置`mx95frdm-pro-m7gpio.cfg`中：

```text
LM1/M7: GPIO2 OWNER
LM1/M7: PIN_GPIO_IO14/15 OWNER
LM1/M7: LPUART7 OWNER
LM1/M7: PIN_GPIO_IO36/37 OWNER
LM2/A55: GPIO2 ACCESS
LM2/A55: PERLPI_GPIO2 ALL
```

配置文件经`configtool.pl`生成配置源码，再由Arm GNU Toolchain编译成`m33_image.bin`，与其他启动组件一起打进`flash-m7-gpio.bin`。板子启动后，M33上的System Manager据此配置逻辑机和TRDC权限。

### 8.3 GPIO方向、初值和安全属性（RGPIO，M7直写）

LED任务中：

```c
rgpio_pin_config_t outputConfig = {kRGPIO_DigitalOutput, 0U};
RGPIO_PinInit(GPIO2, 14U, &outputConfig);
```

这一步把GPIO2 bit14设为输出并给出初始低电平。完成复用、权限和方向配置后，循环里才能直接：

```c
RGPIO_PinWrite(GPIO2, 14U, output);
```

`RGPIO_PinWrite()`只改变已初始化好的输出位，不配置IOMUX、权限或方向。

`RGPIO_PinInit()`在RGPIO控制器里做的事：输入脚把`PDDR`（方向寄存器，1=输出、0=输入）对应位清0；输出脚先用`PSOR/PCOR`写初始电平，再把`PDDR`对应位置1。`PDDR`复位默认全0，即所有脚默认是输入，所以输入脚不初始化也能读。

当前程序只初始化并使用了输出脚GPIO14：`led_task()`只翻转输出并打印`LED=%u`，没有读取GPIO15（GPIO15只作为`GPIO_PIN_MASK`的bit15出现在PCNS恢复里）。9-14那版曾用GPIO15做输入回环，当前LED版本已不再读它。若以后要用输入，建议仍显式`RGPIO_PinInit(GPIO2, 15, &inputConfig)`，把方向位清0表明意图。

命名上，`GPIO2_IO14`和STM32的`PA14`是同一思路：控制器+引脚号。STM32用端口字母+0~15，i.MX95用控制器编号GPIO1~GPIO5+bit0~31。差别是i.MX的pad名（`GPIO_IO14`）是全局的，一个pad可经IOMUXC接到不同控制器/外设。

### 8.4 为什么SDK里有很多重复的pin_mux.c/board.c

- SDK示例是自包含的：每个example目录自带一份`board.c/pin_mux.c/clock_config.c/hardware_init.c`，便于独立编译（SDK里有80多个`pin_mux.c`）。
- 真正参与本项目编译的只有`freertos_hello/cm7/`下那一份，见`freertos_hello_cm7.ewp`（`$PROJ_DIR$/../pin_mux.c`）。
- `project_template`（board级和device级各一份）是新建工程的骨架，不参与本示例编译，内容甚至可能对应其他芯片/核。
- SourceInsight索引了整个SDK所以看起来“重复”；判断哪份在用，看工程文件引用的路径。

## 九、A55启动后为什么还要恢复GPIO属性

完整SD启动会经过BL31，当前BL31会把GPIO2的`PCNS/PCNP`设置为全1，使安全态M7访问GPIO14/15时读0、写入无效。`gpio_reclaim_pins()`只清除bit14/15：

```c
GPIO2->PCNS &= ~GPIO_PIN_MASK;
GPIO2->PCNP &= ~GPIO_PIN_MASK;
```

LED任务在写GPIO前检查对应位，只有属性被重新设置时才恢复。它处理的是RGPIO控制器内部的安全/特权属性，与SM中的控制器资源权限和IOMUX引脚所有权不是同一层。

## 十、当前验证结果

IAR编译并重新打包后，GPIO2_IO14连接带限流电阻的8位LED模块，LED每500 ms改变一次状态，完整周期约1 s。说明当前LED任务创建、阻塞调度、GPIO初始化、权限配置和物理输出链路均能工作。
