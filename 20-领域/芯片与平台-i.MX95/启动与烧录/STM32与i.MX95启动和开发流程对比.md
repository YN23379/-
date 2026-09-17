---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 怎么做
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# STM32与i.MX95启动和开发流程对比

## 一、开发流程的根本区别

STM32通常是单片机，芯片上有一个Cortex-M内核、片上Flash和SRAM。工程中编译出一个程序，通过ST-Link、J-Link等调试器写入片上Flash，复位后内核从固定启动地址取向量表并执行。常见流程是：

```text
创建工程
配置时钟和外设
编译生成ELF或BIN
调试器写入Flash
复位运行
```

i.MX95是异构多核应用处理器。A55通常运行Linux，M7运行裸机或FreeRTOS，M33运行System Manager。它有LPDDR5、eMMC、SPI NOR等外部存储，程序不一定写入处理器内部Flash。不同核心的启动方式、内存、外设和资源权限也不同。

```text
配置板卡和各核心软件
编译A55、M7、M33各自的程序
准备DDR、ELE/AHAB和启动组件
生成启动容器
写入或临时加载到启动设备
Boot ROM和System Manager依次初始化
启动A55、M7和其他核心
```

因此，STM32中一个BIN通常就能作为烧写对象，而i.MX95中M7的BIN通常只是一个核心应用，不能单独代表整板启动镜像。

## 二、什么是启动镜像

启动镜像是按照芯片Boot ROM和启动组件要求组织起来的一组二进制数据。它不是某一个正在运行的程序，而是芯片上电后用来完成初始化和启动的文件集合。

对FRDM-IMX95-PRO来说，启动镜像通常需要包含或引用：

- Boot ROM能够识别的容器头和镜像描述信息
- ELE/AHAB相关安全启动组件
- DDR OEI和DDR初始化相关固件
- M33上的System Manager固件
- A55启动组件，例如SPL、TF-A、U-Boot或其组合
- A55使用的设备树、Linux内核和根文件系统，视启动方式而定
- 需要上电自动启动的M7 BIN
- 各部分的加载地址、入口地址、大小和属性

`flash.bin`通常是由`imx-mkimage`生成的启动容器文件。它把多个已经编译好的组件按i.MX95规定的格式和地址组合起来，使Boot ROM能够依次加载和启动。它不是Linux镜像的同义词，也不是单独的FreeRTOS程序。

## 三、BIN文件的含义

BIN是Binary的缩写，表示没有文件头的原始二进制数据。编译器先生成带有结构信息的ELF，再根据工程配置提取代码和数据形成BIN。

ELF中包含：

- 目标架构
- 程序入口地址
- 程序段和加载地址
- 代码、只读数据、已初始化数据
- 未初始化数据的大小
- 符号表和调试信息

BIN通常只保留需要装载到内存中的原始内容，不包含ELF头、段表和调试符号。因此：

- 调试器通常使用ELF或OUT，便于加载、断点和查看符号。
- Linux remoteproc通常使用ELF，因为需要根据程序段读取加载地址和大小。
- 启动容器通常使用BIN，因为容器已经另外保存了各镜像的装载地址和入口信息。
- UUU的`SDPS: boot -f`接收的是符合Boot ROM要求的完整启动容器，不是普通M7 BIN。

M7的TCM BIN开头通常是Cortex-M向量表。前4字节是初始栈地址，后4字节是复位入口地址。当前板载文件开头为：

```text
2001e000 0000087d
```

这表示程序启动时使用`0x2001e000`作为栈顶，并从M7的TCM地址空间入口执行。这个BIN能否运行，还取决于M7是否已经被准备、目标内存是否可访问、引脚和串口是否配置正确，以及System Manager是否允许该核心启动。

## 四、启动镜像中的主要组件

### Boot ROM

Boot ROM是芯片出厂固化在只读存储器中的第一段启动代码。上电或复位后，它读取启动模式引脚和安全配置，选择eMMC、SD卡、SPI等启动设备，或者进入USB Serial Downloader模式。Boot ROM负责识别启动容器、把早期组件加载到指定位置，并把控制权交给后续启动组件。

### ELE和AHAB

ELE是i.MX95中的安全执行环境相关组件。AHAB是NXP的高级硬件启动和认证机制。`mx95a0runtime-ahab-container.img`、`mx95b0-ahab-container.img`等文件属于安全启动容器或运行时安全组件，不是M7 FreeRTOS应用。

不同文件名中的A0、B0和runtime通常对应芯片版本或运行阶段。具体选择必须和芯片版本、BSP版本以及启动容器构建说明一致，不能只因为文件名相似就替换。

### DDR和DDR OEI

DDR是外部动态随机存取内存，不是启动程序。i.MX95上电时DDR还不能直接使用，需要DDR PHY训练、控制器配置和相关初始化。DDR OEI负责早期DDR初始化，启动组件完成这一步后，A55的Linux和其他需要放入DDR的程序才有足够的运行空间。

### System Manager

System Manager通常运行在M33上，负责电源、时钟、复位、启动核心、引脚和资源权限。它还通过LMM对不同Logical Machine的核心和外设进行隔离管理。M7的FreeRTOS程序即使本身没有问题，如果System Manager没有允许对应核心启动或访问外设，也可能无法运行。

### A55启动组件

SPL、TF-A、U-Boot、Linux内核、设备树和根文件系统组成A55的Linux启动链路。它们不属于FreeRTOS，但在Linux启动模式下会负责启动Linux，之后Linux可能使用remoteproc管理M7。

### M7固件

M7固件可以是裸机程序，也可以是FreeRTOS程序。它通常使用TCM或预留DDR，并需要对应的链接脚本、启动文件、时钟、引脚和外设配置。若要求上电后M7自动运行，M7 BIN需要被加入启动容器；若要求Linux运行后动态启动，Linux需要通过remoteproc加载M7 ELF，并且System Manager必须开放相应控制权限。

## 五、FRDM-IMX95-PRO上电启动流程

```text
接入J11电源
        ↓
SW1允许板卡供电
        ↓
芯片复位释放
        ↓
Boot ROM读取SW4
        ↓
选择eMMC、SD卡或USB下载模式
        ↓
加载早期启动容器
        ↓
ELE/AHAB进行安全相关处理
        ↓
DDR OEI完成LPDDR5初始化
        ↓
System Manager在M33上运行
        ↓
根据启动容器和LMM配置管理各核心
        ↓
启动A55的SPL、U-Boot和Linux
        ↓
启动容器直接释放M7，或Linux之后通过remoteproc启动M7
```

当SW4选择USB Serial Downloader时，Boot ROM不会从eMMC正常启动，而是通过J7等待电脑上的UUU发送启动容器。`SDPS: boot`通常是把容器临时传入RAM并执行，不等于已经写入eMMC。只有UUU脚本中包含`FB: flash`等写入命令时，才会执行存储器烧写。

## 六、官方FreeRTOS示例为什么可以启动

板载系统中的以下文件已经是厂家随BSP提供的M7 FreeRTOS候选程序：

```text
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.bin
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.bin
```

其中ELF中已经能看到`tasks.c`、`xTaskCreate`和`vTaskStartScheduler`，说明FreeRTOS内核和应用已经编译进M7固件。它们之所以能够作为官方示例使用，是因为源码、M7内存布局、启动文件、板级配置和System Manager方案是配套的。

但FreeRTOS ELF或BIN仍然只是M7应用文件。能否运行还要看启动方式：

- 如果放入正确的启动容器，由System Manager在启动阶段释放M7，可以上电运行。
- 如果由Linux remoteproc加载，除了ELF正确，还要有对应的LMM控制权限。
- 如果用J-Link下载，需要调试接口和M7目标内存可访问。

因此，厂家提供FreeRTOS示例，不代表可以把这个BIN直接当成整板`flash.bin`，而是说明M7应用本身已经准备好，剩下要使用匹配的启动路径。

## 七、M7的正常控制方式

### 启动容器直接启动

这是最适合验证上电运行的方式。将官方M7 BIN加入包含正确System Manager、DDR和安全启动组件的Pro板启动容器，Boot ROM加载容器后，System Manager根据配置启动M7。M7可以与A55同时运行，不依赖Linux登录后的操作。

### Linux remoteproc动态启动

Linux启动后，remoteproc读取M7 ELF，按照ELF程序段将代码和数据放到TCM或预留内存，再通过System Manager请求复位、设置入口和释放M7。这个方式的优点是无需重新启动整板，缺点是System Manager必须把M7所在的Logical Machine控制权限开放给Linux所在的Logical Machine。

当前执行时出现：

```text
lmm(1) not under Linux Control
Boot failed: -13
```

这表示Linux已经找到M7 ELF，但System Manager拒绝了控制请求。正常解决方式不是修改Linux文件权限，而是使用允许Linux控制M7的System Manager配置，或者改用启动容器在上电阶段直接启动M7。

### JTAG或SWD调试启动

J-Link通过JTAG或SWD直接访问M7调试接口，适合断点和单步。当前Pro板只把信号引到TP测试点，没有标准插座，因此需要外部调试器和测试点夹具或焊线。

## 八、当前工作结论

当前电脑上使用SDK编译的`freertos_hello.bin`和板载系统中的官方`rpmsg_lite_*_rtos*`固件都属于M7 FreeRTOS应用。前者用于学习和修改，后者用于验证厂家已经提供的官方示例。当前最合理的顺序是先用官方FreeRTOS ELF验证remoteproc，记录LMM权限失败结果；再使用官方FreeRTOS BIN和Pro板启动组件生成完整启动容器，通过UUU临时启动；临时启动成功后，再研究使用UUU写入eMMC或SD卡。
