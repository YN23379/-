---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 怎么做
status: 待验证
evidence: 实机验证
tags: [编译构建, 启动, 存储]
updated: 2026-09-17
---

# FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程

## 一、目标、时间和最终结果

记录时间：2026-09-09至2026-09-15。

目标是熟悉FRDM-IMX95-PRO开发板、开发工具和下载方式，在Cortex-M7上编译并运行FreeRTOS程序，最后验证串口输入输出和GPIO输入输出。

截至2026-09-15，已经完成：

1. IAR能够编译SDK 26.06.00中的M7 FreeRTOS工程，编译结果为0错误、0警告。
2. 通过J7、USB Serial Downloader和UUU完成RAM临时启动，没有覆盖板载eMMC。
3. COM18完成LPUART7输出和中断接收回显测试。
4. M7获得GPIO2寄存器访问，A55保留GPIO2所需API和ACCESS；M7程序另外恢复IO14/15的PCNS/PCNP属性。
5. GPIO2_IO14输出、GPIO2_IO15输入完成杜邦线回环测试。
6. 逻辑分析仪测得约1 Hz方波，输入与输出状态一致。
7. 解决了错误转移GPIO2所有权引起的`Reset LM 2, reason=fccu, errId=19`问题。

必须区分以下状态：

```text
IAR编译成功
!= 启动容器生成成功
!= UUU传输成功
!= M7已经运行
!= UART/GPIO物理功能验证成功
```

本次五个层级均已分别取得证据。2026-09-15又完成了SD卡持久化启动，断电后不运行UUU也能自动启动M7，COM17同时证明A55启动链已进入U-Boot。eMMC持久化未操作；本次SD只写入启动容器，未写入Linux内核、DTB和根文件系统。

## 二、先认识板卡和接线

FRDM-IMX95-PRO使用i.MX95 SoC，主要包含6个Cortex-A55、1个Cortex-M7和1个Cortex-M33。当前分工是：

- Cortex-A55：正常模式下运行U-Boot和Linux。
- Cortex-M7：运行本次FreeRTOS应用。
- Cortex-M33：运行NXP System Manager，负责启动、资源分区、时钟、电源和多核管理。

实际使用的接口：

| 接口 | 实际作用 | 本次用途 |
| --- | --- | --- |
| J11 | USB-C PD供电 | 给整板供电，不承担下载数据传输 |
| J22 | CH9114F USB转四路UART | 同时观察A55、M7和M33串口 |
| J7 | i.MX95 USB数据口 | USB Serial Downloader和UUU传输 |
| SW4 | Boot Mode启动选择 | 复位时决定Boot ROM从eMMC、SD、USB等哪条路径启动 |
| J15 | 扩展排针 | 引出GPIO2_IO14、GPIO2_IO15和GND |

本机实测串口映射：

```text
COM17 -> A55启动串口
COM18 -> M7的LPUART7
COM19 -> M33 System Manager
```

COM号由Windows枚举决定，换USB口或电脑后可能变化，因此应根据输出内容识别，不能把COM号当成板卡固定定义。MobaXterm参数统一为`115200-8-N-1`、无流控。

本次USB下载模式使用的SW4物理位置为：

```text
SW4[1:4] = ON、OFF、OFF、ON
```

它对应用户手册中的`x001` USB Serial Downloader模式。Boot ROM只在上电/复位阶段采样启动模式，因此改变SW4后必须让SoC重新经历复位。若上一次UUU镜像已经让系统停在其他阶段，应断电再上电，直到Windows重新出现MX95 SDPS设备；“等待十多秒”不是协议规定，目的只是确保供电轨和USB枚举确实完成一次冷启动。

## 三、首先收集哪些官方资料

先按“板卡手册 -> 应用笔记 -> SDK示例 -> BSP -> 官方工具源码”的顺序查资料，不能先套用其他i.MX板卡命令。

本地资料：

| 资料 | 路径 | 作用 |
| --- | --- | --- |
| 快速入门 | `C:\Users\chen\Desktop\资料\IMX95\FRDMIMX95PROQSG.pdf` | 第一次接线、供电和启动 |
| 用户手册 | `C:\Users\chen\Desktop\资料\IMX95\UM12527.pdf` | 接口、SW4启动模式、板卡功能 |
| M7应用笔记 | `C:\Users\chen\Desktop\资料\IMX95\AN14748.pdf` | M7 BIN、`imx-mkimage`、`flash.bin`和UUU的官方流程 |
| Cortex-M调试 | `C:\Users\chen\Desktop\资料\IMX95\AN14120.pdf` | i.MX平台上Cortex-M调试方法 |
| 原理图 | `C:\Users\chen\Desktop\资料\IMX95\FRDM-IMX95-PRO_DESIGNFILES\Schematic\SCH-95794_B1\SPF-95794_B1.pdf` | JTAG/SWD测试点、UART和扩展口实际连线 |
| 布局图 | `C:\Users\chen\Desktop\资料\IMX95\FRDM-IMX95-PRO_DESIGNFILES\Layout\DNP-95794_B1.pdf` | 原理图位号与PCB位置对应 |

软件资料：

| 资源 | 本地路径或来源 | 作用 |
| --- | --- | --- |
| MCUXpresso SDK 26.06.00 | `F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19` | M7启动文件、链接文件、FreeRTOS内核移植、SDK驱动、板级示例和IAR工程 |
| SDK原始压缩包 | `C:\Users\chen\Downloads\SDK_26_06_00_IMX95LPD5EVK-19.zip` | 从NXP MCUXpresso SDK Builder获取 |
| Linux BSP镜像包 | `C:\Users\chen\Downloads\LF_v6.18.2-1.0.0_images_IMX95.zip` | 提供i.MX95/Pro匹配的启动组件、Linux镜像、设备树和固件 |
| BSP解压目录 | `F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95` | 构建时使用的NXP二进制组件来源 |
| UUU 1.5.243 | `F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe` | Windows端识别i.MX ROM并发送启动容器 |
| System Manager源码 | `F:\project\Learning\RTOS\tools\imx-sm` | 生成资源配置并编译M33的SM固件 |
| imx-mkimage源码 | `F:\project\Learning\RTOS\tools\imx-mkimage` | 把多核和启动组件封装为i.MX95启动容器 |

两个NXP源码仓库来自：

```text
https://github.com/nxp-imx/imx-sm.git
https://github.com/nxp-imx/imx-mkimage.git
```

本次`imx-sm`固定在提交：

```text
c450f53974ea1df826970ad399cb338625b5638d
```

`imx-mkimage`使用与BSP匹配的`lf-6.18.2_1.0.0`分支。固定版本是为了避免SM、容器格式和BSP组件跨版本混用。

MCUXpresso配置工具的“V26.06数据”属于芯片、板卡、外设和引脚配置的元数据，不是烧录器，也不是最终固件。真正参与本次M7开发的是完整SDK包；VS Code的MCUXpresso扩展可以管理工程和调用工具链，但也不能代替JTAG探针或UUU下载链路。

## 四、第一次启动：确认原厂板卡是正常的

先不改eMMC，也不下载M7程序：

```text
J11接PD电源
-> J22接电脑
-> SW4保持eMMC启动
-> MobaXterm打开四个115200串口
-> 整板上电
```

COM17出现：

```text
U-Boot SPL 2025.04-g99518e6b6f20
Trying to boot from MMC1
Model: NXP FRDM-IMX95-PRO board
Linux version 6.18.2-1.0.0
imx95-19x19-lpddr5-frdm-pro login:
```

这证明eMMC中的原厂A55启动链、Linux和A55串口正常。COM19出现DDR OEI和`Hello from SM`，证明DDR初始化固件及M33 System Manager已经运行。

进入Linux后，确认板型：

```sh
cat /proc/device-tree/model
cat /proc/device-tree/compatible
```

实际结果为`NXP FRDM-IMX95-PRO`和`fsl,frdm-imx95-pro`。随后在`/lib/firmware`发现NXP预置的M7固件：

```text
imx95-19x19-evk_m7_TCM_hello_world.bin
imx95-19x19-evk_m7_TCM_hello_world.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.elf
...
```

对`hello_world`执行`file`、`readelf`和`strings`确认：

- BIN是Cortex-M固件，初始SP为`0x2001e000`，复位入口为`0x0000087c`。
- ELF是32位ARM EABI5可执行文件，入口为`0x87d`。
- ELF中存在`hello world.`、LPUART驱动和MIMX9596 CM7启动代码。

这些文件证明BSP已经准备了M7示例，但“文件存在”不等于M7正在执行。还需要由启动容器、Linux remoteproc或调试器把代码放入M7可执行内存，并解除M7复位。

## 五、如何找到三种M7下载/启动方式

### 5.1 J-Link通过JTAG/SWD

SDK IAR示例的`example_board_readme.md`列出J-Link，AN14120也介绍Cortex-M调试。因此首先检查原理图上的JTAG/SWD物理连接。

原理图第26页显示相关信号只到TP1至TP7：

```text
TP1 -> JTAG_TMS / SWDIO
TP4 -> JTAG_TCK / SWCLK
TP2 -> JTAG_TDO
TP5 -> JTAG_TDI
TP3 -> JTAG_RESET
TP6 -> 3.3 V目标参考电压
TP7 -> GND
```

JTAG至少需要时钟TCK、状态/模式TMS、输入TDI、输出TDO、复位、目标参考电压和地；SWD通常使用SWCLK、双向SWDIO、复位、目标参考电压和地。J-Link不是唯一可能的调试器，但必须满足：

1. 调试器支持i.MX95/MIMX9596的Cortex-M7和目标调试协议。
2. IDE或命令行软件有对应驱动和器件支持。
3. 物理信号必须可靠连接到板上测试点。

本次没有J-Link，而且TP是狭小裸露焊盘，不是2.54 mm排针或标准20针JTAG插座。实际使用还需焊飞线、弹簧探针夹具或定制转接板，容易短路或接触不稳，因此暂不采用。J22只是四路UART，不能替代JTAG/SWD。

### 5.2 Linux remoteproc

Linux系统中存在：

```text
/sys/class/remoteproc/remoteproc1
```

它指向`/sys/devices/platform/imx95-cm7`。remoteproc理论流程是：

```text
Linux选择M7 ELF
-> 解析ELF Program Header
-> 把各LOAD段装入M7的TCM/预留内存
-> 通过i.MX95驱动向System Manager请求启动M7
-> System Manager配置并释放M7复位
```

实际选择官方ELF后启动，内核输出：

```text
remoteproc remoteproc1: Booting fw image ...hello_world.elf
imx-rproc imx95-cm7: lmm(1) not under Linux Control
remoteproc remoteproc1: Boot failed: -13
```

用户已经是root，而且驱动已经成功找到和读取ELF，因此这不是Linux文件权限。当前SM配置中M7属于LM1，A55/Linux所属逻辑机没有LM1控制权，所以平台驱动拒绝启动。

U-Boot中的`rproc`和`bootaux`也没有绕开该限制：`rproc init 0`提示只能检测M7是否运行；尝试由A55把BIN复制到M7 TCM地址`0x203c0000`时触发同步异常并复位。由此暂时排除“从现有Linux/U-Boot直接启动M7”路线。

### 5.3 USB Serial Downloader加UUU

UM12527的SW4表明确给出`x001` USB Serial Downloader，AN14748明确给出“M7 BIN -> imx-mkimage -> flash.bin -> UUU”的流程，NXP UUU文档说明`SDPS: boot -f flash.bin`可以通过USB启动i.MX设备。因此这不是根据现象猜出的私有方法，而是芯片Boot ROM提供、NXP工具支持的官方启动链。

验证步骤：

```text
SW4设为ON、OFF、OFF、ON
-> J7连接电脑
-> 板卡重新上电
-> Windows枚举VID=0x1FC9、PID=0x015D
-> uuu.exe -lsusb显示MX95 SDPS
```

实测命令：

```powershell
cd F:\project\Learning\RTOS
.\tools\uuu-1.5.243\uuu.exe -lsusb
```

输出中出现：

```text
Chip: MX95
Pro:  SDPS
Vid:  0x1FC9
Pid:  0x015D
```

这证明Boot ROM、J7数据线、Windows USB驱动和UUU识别链路都正常。该方法不要求JTAG接线，也不依赖已经启动的Linux及其LMM权限，所以最终选择USB+UUU。

## 六、为什么不能直接把M7 BIN交给UUU

IAR生成的M7 BIN只是M7代码和数据的扁平二进制。i.MX95冷启动还需要先完成安全固件、DDR、系统管理和多核资源初始化。Boot ROM的`SDPS: boot`接收的是符合i.MX95容器格式的完整启动镜像，而不是任意裸BIN。

两类文件的用途不同：

```text
freertos_gpio.bin
-> 只描述M7执行的指令和初始数据
-> 由启动容器明确它属于M7、加载到哪里、入口在哪里

flash-m7-gpio.bin
-> Boot ROM可识别的多容器启动镜像
-> 包含ELE、V2X、DDR初始化、M33 SM、M7程序和A55启动组件
-> 每个镜像带核心ID、加载地址、入口地址、大小和哈希
```

早期把不完整或布局不匹配的容器交给UUU时，出现过：

```text
LIBUSB_ERROR_IO
LIBUSB_ERROR_PIPE
UUU进度从0到100反复循环
```

反复循环的原因是：Boot ROM接收镜像后启动失败，SoC再次复位回USB下载模式，UUU又把它识别成新的SDPS设备并重新发送。100%只说明本轮USB数据发完，不说明容器已成功执行。

最终判断成功必须观察串口：COM19应出现DDR OEI和SM，COM18应出现M7应用输出。

## 七、搭建Windows和WSL构建环境

### 7.1 Windows侧

Windows侧使用：

- IAR Embedded Workbench for Arm 9.70.4：编译、链接M7 FreeRTOS工程。
- MobaXterm：同时打开J22的四路UART，验证实际运行效果。
- UUU 1.5.243：通过J7和SDPS发送最终启动容器。
- PowerShell：执行UUU和WSL命令。

SDK里的IAR工程路径：

```text
F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19\boards\imx95lpd5evk19\freertos_examples\freertos_hello\cm7\iar
```

### 7.2 为什么还要搭建WSL

IAR能编译M7应用，但NXP的`imx-sm`和`imx-mkimage`官方构建流程使用Linux下的GNU Make、Perl、Shell、`dd`、`srecord`和交叉编译器。为了不在Windows上重写官方Makefile和脚本，建立了独立WSL发行版：

```text
名称：UbuntuBuild
版本：WSL 1
```

安装脚本：

```text
F:\project\Learning\RTOS\tools\install-wsl-admin.ps1
F:\project\Learning\RTOS\tools\setup-wsl-build.ps1
```

WSL依赖包括：

```text
build-essential
gcc-multilib
g++-multilib
make
perl
srecord
curl
xz-utils
git
file
gcc-arm-none-eabi
libnewlib-arm-none-eabi
```

Windows的`F:\project\Learning\RTOS`在WSL中对应：

```text
/mnt/f/project/Learning/RTOS
```

构建时把源码复制到WSL的`/root`临时目录，避免直接在NTFS挂载目录中进行大量Linux编译操作；最终产物再复制回Windows工作区。

### 7.3 官方Arm GNU Toolchain 14.2.Rel1从哪里得到

`imx-sm/README.md`要求使用`arm-none-eabi`交叉编译器，并要求以对应Release Notes测试过的版本为准。本次最终使用：

```text
Arm GNU Toolchain 14.2.Rel1
arm-none-eabi-gcc 14.2.1 20241119
```

官方入口：

```text
https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
```

使用的Linux x86_64、AArch32 bare-metal压缩包直链：

```text
https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz
```

本机实际文件和安装位置：

```text
压缩包：/root/armgcc/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz
大小：149739784 bytes
安装：/home/chen/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi
```

该工具链只用于编译M33上的System Manager，不用于当前M7应用；M7应用由IAR编译。系统通过环境变量告诉SM Makefile工具链根目录：

```sh
export TOOLS=/home/chen/toolchains
```

## 八、M7 FreeRTOS程序的编译链

SDK工程不是只有一个`hello_world.c`，而是已经把运行M7所需的多层代码组合在IAR工程中：

```text
业务代码freertos_hello.c
+ FreeRTOS内核tasks/queue/list/timers
+ FreeRTOS Cortex-M移植层
+ MIMX9596 CM7启动代码和中断向量表
+ IAR链接文件MIMX9596xxxxN_cm7_ram.icf
+ NXP LPUART、RGPIO、时钟、IOMUX和调试控制台驱动
+ 板级board、clock_config、pin_mux、hardware_init
        |
        | IAR C/C++编译器：每个.c -> 目标文件
        | IAR汇编器：启动汇编 -> 目标文件
        | IAR链接器：按.icf放置代码、数据、堆、栈和向量表
        v
freertos_hello_cm7.out
        |
        | IAR输出转换，去掉ELF/调试结构并保留可装载字节
        v
freertos_hello.bin
```

`.out`保存符号、段表和调试信息，适合IAR/J-Link调试；扁平`.bin`没有符号和段地址元数据，体积小，适合由`imx-mkimage`在容器参数中指定M7的加载地址和入口。两者不是谁更高级，而是加载方需要的信息不同。Linux remoteproc要解析多个LOAD段，所以通常使用ELF；本次容器打包明确给出地址，所以使用BIN。

IAR构建后的实际M7输入文件：

```text
F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19\boards\imx95lpd5evk19\freertos_examples\freertos_hello\cm7\iar\debug\freertos_hello.bin
```

最终构建脚本将它复制为：

```text
F:\project\Learning\RTOS\build\pro-gpio\freertos_gpio.bin
```

### 8.1 串口输入输出修改

原始示例只创建任务并打印一次`Hello world.`。为了验证输入和输出，程序改为：

```text
LPUART7接收中断
-> 读取接收字节
-> xQueueSendFromISR送入FreeRTOS队列
-> echo_task阻塞等待队列
-> 收到字节后由LPUART7原样发回
```

主要文件：

```text
...\cm7\freertos_hello.c
...\cm7\pin_mux.c
...\cm7\board.c
...\cm7\clock_config.c
```

引脚使用GPIO_IO36/37复用为LPUART7 TX/RX，输出到J22的COM18。运行提示从原始一次性`Hello world.`改为更能说明测试状态的：

```text
M7 FreeRTOS UART echo ready
```

因此最终程序没有再次打印`Hello world.`是代码行为变化，不是FreeRTOS没有启动。

### 8.2 GPIO输入输出修改

在相同工程中加入NXP `fsl_rgpio`驱动和GPIO任务：

```text
GPIO_IO14 -> GPIO2_IO_BIT14 -> 输出 -> J15-8
GPIO_IO15 -> GPIO2_IO_BIT15 -> 输入  -> J15-10
```

初始化和任务链：

```text
BOARD_InitHardware
-> 初始化SM接口、IOMUX、时钟、调试串口和MPU
-> GPIO2->PCNS = 0
-> main创建echo_task和gpio_task
-> vTaskStartScheduler启动FreeRTOS调度
-> gpio_task每500 ms翻转GPIO2_IO14
-> 立即读取GPIO2_IO15
-> COM18打印OUT和IN
```

GPIO代码依据SDK官方`driver_examples/rgpio/led_output`示例，使用`RGPIO_PinInit()`、`RGPIO_PinWrite()`、`RGPIO_PinRead()`。官方示例明确提示默认配置不能直接和Linux BSP同时运行，因此本次先在UUU RAM测试环境验证外设，不宣称已经完成完整Linux与M7共存。

## 九、为什么还要重编System Manager

只修改M7代码和IOMUX仍不能保证M7能访问GPIO寄存器。i.MX95由M33上的System Manager按照Logical Machine配置资源，并由TRDC实施硬件访问控制。

官方Pro配置：

```text
F:\project\Learning\RTOS\tools\imx-sm\configs\other\mx95frdm-pro.cfg
```

本次GPIO配置：

```text
F:\project\Learning\RTOS\tools\imx-sm\configs\other\mx95frdm-pro-m7gpio.cfg
```

原始配置已经给LM1/M7分配`PIN_GPIO_IO14`和`PIN_GPIO_IO15`，但“引脚归属”只允许M7配置这些IOMUX引脚，不等于M7可以访问整个GPIO2寄存器控制器。

第一次错误方案把以下内容从LM2/A55整体转给LM1/M7：

```text
PERLPI_GPIO2 ALL
GPIO2 OWNER
```

M7 GPIO因此能工作，但COM19持续出现：

```text
Reset LM 2, reason=fccu, errId=19
```

官方源码确认`errId=19`是WDOG3超时。保持M7程序、容器其他组件和构建工具不变，只换回官方原始SM配置后，A55 SPL恢复、WDOG3错误消失，而M7不能访问GPIO2。这个单变量对照证明问题随“移走A55的GPIO2所有权”出现，不是工具链或容器随机故障。

官方配置文档：

```text
F:\project\Learning\RTOS\tools\imx-sm\sm\doc\config.md
```

其中说明API访问和TRDC访问是两套控制，每个LM的DID有独立TRDC权限。最终实测配置为：

```diff
 LM1/M7: GPIO2 OWNER
 LM2/A55: GPIO2 ACCESS
 LM2/A55: PERLPI_GPIO2 ALL
```

最终关系：

```text
LM1/M7：GPIO2 OWNER，并拥有GPIO_IO14/15 pad
LM2/A55：保留PERLPI_GPIO2 ALL + GPIO2 ACCESS
```

含义是M7可以直接访问GPIO2寄存器，A55仍保留启动和管理所需的SCMI API及寄存器访问。但这只解决SM/TRDC层，不能阻止BL31后续改写RGPIO自身的`PCNS/PCNP`。

### 9.1 SM配置如何变成M33 BIN

完整数据流：

```text
mx95frdm-pro-m7gpio.cfg
        |
        | Perl配置工具configtool.pl
        | make config=mx95frdm-pro-m7gpio cfg
        v
config_lmm.h + config_trdc.h + config_scmi.h + 其他生成头文件
        |
        | Arm GNU Toolchain 14.2.Rel1
        | make config=mx95frdm-pro-m7gpio all
        v
m33_image.elf + m33_image.bin
```

实际输出复制到：

```text
F:\project\Learning\RTOS\build\pro-gpio\m33_image.bin
```

`.cfg`本身不会被Boot ROM读取，也不能复制到板子后立即生效。它先生成C头文件，再和SM源码一起编译成M33机器码；最终`m33_image.bin`被放进启动容器。M33执行该固件时，才按配置设置LM、DID、TRDC和SCMI权限。

## 十、最终启动容器的生成链

统一构建脚本：

```text
F:\project\Learning\RTOS\tools\build-m7-gpio.sh
```

在PowerShell中可执行：

```powershell
wsl.exe -d UbuntuBuild -u root -- bash /mnt/f/project/Learning/RTOS/tools/build-m7-gpio.sh
```

脚本分三阶段。

### 10.1 阶段一：编译SM

```text
mx95frdm-pro-m7gpio.cfg
-> configtool.pl生成配置头
-> arm-none-eabi-gcc 14.2.1编译和链接
-> /root/imx95-m7-gpio-build/imx-sm/build/mx95frdm-pro-m7gpio/m33_image.bin
```

### 10.2 阶段二：准备NXP原厂组件

最终容器不是从零开发所有固件，而是复用与Pro板已经验证匹配的NXP组件：

```text
ahab-container.img             -> ELE安全固件容器
Primary/Secondary V2X         -> V2X固件
container3_img2.bin            -> DDR OEI/DDR固件
container3_img4.bin            -> A55 U-Boot SPL
app_container1_img1.bin        -> BL31/TF-A
app_container1_img2.bin        -> U-Boot主体
app_container1_img3.bin        -> OP-TEE
QB数据                         -> Pro板DDR Quick Boot相关数据
```

这些文件保存在：

```text
F:\project\Learning\RTOS\build\pro-ram-boot\extracted_imgs
```

它们来自与FRDM-IMX95-PRO实机匹配并已成功启动的NXP/BSP启动镜像。最终脚本保留Pro特有的V2X容器头、载荷和早期DDR/QB字节，避免把普通19x19 EVK的容器布局直接当成Pro布局。

我们自己修改或重新生成的只有：

```text
M7 FreeRTOS源码和freertos_gpio.bin
SM权限配置mx95frdm-pro-m7gpio.cfg
重新编译的m33_image.bin
集成脚本build-m7-gpio.sh
最终组合镜像flash-m7-gpio.bin
```

ELE、V2X、DDR OEI、SPL、BL31、U-Boot和OP-TEE均复用NXP匹配组件，没有自行编写。

### 10.3 阶段三：imx-mkimage组装

`imx-mkimage`不是编译FreeRTOS的编译器，而是NXP启动镜像打包工具。它把不同CPU的二进制、加载地址、入口地址、核心类型和哈希写入AHAB容器。

核心参数：

```text
-m33 m33_image.bin 0 0x1FFC0000
-m7  m7_image.bin  0 0x0 0x303C0000
-ap  u-boot-spl.bin a55 0x20480000
```

整体汇合链：

```text
IAR链：FreeRTOS+SDK+板级代码 -> freertos_gpio.bin -----------+
                                                               |
SM链：权限.cfg -> configtool.pl -> GCC 14.2 -> m33_image.bin --+
                                                               |
NXP BSP：ELE+V2X+DDR OEI+SPL+BL31+U-Boot+TEE ------------------+
                                                               |
                                                               v
                                                    imx-mkimage/mkimage_imx8
                                                               |
                                                               v
                                                    flash-m7-gpio.bin
```

最终文件：

```text
F:\project\Learning\RTOS\build\pro-gpio\flash-m7-gpio.bin
大小：2854912 bytes
SHA256：7A7F13F6EFE371775E27DE111666D3F21FED85BC2EAD1573B8094979ED097506
```

解析报告：

```text
F:\project\Learning\RTOS\build\pro-gpio\flash-m7-gpio.parse.txt
```

报告确认容器包括：

```text
ROM Container 1：ELE
ROM Container 2：Primary V2X、Secondary V2X
ROM Container 3：DDR QB、DDR OEI、M33 SM、M7 FreeRTOS、A55 SPL、V2X dummy
APP Container 1：BL31、U-Boot、OP-TEE
```

M7镜像在解析报告中的关键属性：

```text
Image type：M7_0 Executable
Size：0x6400，即25600 bytes
Load address：0x303C0000（Boot ROM/A55系统视角）
Entry address：0
```

## 十一、UUU把镜像送到哪里，为什么M7会运行

UUU脚本：

```text
F:\project\Learning\RTOS\build\pro-gpio\gpio-ram.uuu
```

内容只有：

```text
uuu_version 1.5.243
SDPS: boot -f flash-m7-gpio.bin
```

完整启动过程：

```text
1. SW4选择x001，整板复位
-> 2. i.MX95片内Boot ROM启动
-> 3. Boot ROM不读eMMC，J7枚举为MX95 SDPS HID设备
-> 4. Windows上的UUU读取gpio-ram.uuu
-> 5. UUU通过USB把flash-m7-gpio.bin送给Boot ROM
-> 6. Boot ROM解析和校验AHAB容器
-> 7. ELE安全固件参与认证/安全启动服务
-> 8. DDR OEI初始化LPDDR5
-> 9. Boot ROM按容器描述装载并启动M33 System Manager
-> 10. SM设置LM、TRDC、时钟、电源和多核资源
-> 11. 容器中的M7 BIN被放到M7启动地址，SM释放M7复位
-> 12. M7读取向量表、设置栈和PC，执行Reset_Handler
-> 13. C运行库初始化.data/.bss，进入main
-> 14. main初始化LPUART7和GPIO，创建任务并启动FreeRTOS调度器
```

本次`SDPS: boot`是RAM临时启动，不包含`FB: flash`、`emmc`或`sd`写入命令，所以不会覆盖eMMC。这里的“RAM启动”不是只把M7 BIN随意复制到DDR，而是把完整启动容器通过ROM下载链装载并执行；各组件仍按容器指定地址进入各核心可访问的内存。

上电后CPU不是直接执行磁盘/eMMC中的普通文件。程序必须先被Boot ROM或后级加载器搬到可执行地址，设置安全与访问权限，再由对应核心从入口取指。M7开始运行后，处理器按“PC给出地址 -> 指令Cache/总线取指 -> 译码 -> 寄存器和数据Cache/TCM读写 -> 执行 -> 更新PC”的循环执行FreeRTOS和任务代码。

## 十二、实际UUU启动步骤

### 12.1 接线和终端

```text
J11 -> PD电源
J22 -> 电脑，打开四路115200串口
J7  -> 电脑USB数据口
SW4 -> ON、OFF、OFF、ON
```

先打开MobaXterm再运行UUU，避免错过一次性启动日志。

### 12.2 确认ROM设备

重新上电后执行：

```powershell
cd F:\project\Learning\RTOS
.\tools\uuu-1.5.243\uuu.exe -lsusb
```

必须看到`MX95 SDPS`。看不到时优先检查SW4、J7是否为数据线、J11供电和是否真正完成冷复位，不应先重编程序。

### 12.3 启动最终镜像

```powershell
cd F:\project\Learning\RTOS
.\tools\uuu-1.5.243\uuu.exe .\build\pro-gpio\gpio-ram.uuu
```

命令中的相对路径基于当前目录。若当前位于`build\pro-ram-boot`，直接写`.\tools\...`会寻找不存在的子目录；应先`cd F:\project\Learning\RTOS`，或者使用完整绝对路径。

UUU显示100%只代表传输完成。真正成功证据是：

```text
COM19 -> DDR OEI完成、Hello from SM、进入SM Debug Monitor
COM18 -> M7 FreeRTOS UART/GPIO持续输出
COM17 -> A55 SPL有启动输出
```

COM17最后出现：

```text
SPL: failed to boot from all boot devices
```

是因为当前UUU脚本只有第一阶段`SDPS: boot`，没有在SPL切换到后续USB协议阶段时继续发送Linux内核、设备树和根文件系统。这不表示M7失败，也不是WDOG3问题；当前完整Linux没有运行。

## 十三、串口输入输出验证

启动成功后，COM18首先显示：

```text
M7 FreeRTOS UART echo ready
M7 FreeRTOS GPIO test ready
```

在COM18输入：

```text
1222222abc123
```

终端收到相同字符，验证链为：

```text
电脑键盘
-> MobaXterm
-> J22/CH9114F USB转UART
-> LPUART7 RX
-> M7中断服务程序
-> FreeRTOS Queue
-> echo_task
-> LPUART7 TX
-> CH9114F
-> MobaXterm显示
```

因此不能只根据启动提示判断“串口完成”；输出提示验证TX，主动输入并收到回显才同时验证RX、RX中断、ISR到任务通信和TX。

## 十四、GPIO输入输出验证

接线：

```text
J15-8  GPIO2_IO14输出 -> J15-10 GPIO2_IO15输入
逻辑分析仪CH0          -> J15-8
逻辑分析仪CH1          -> J15-10
逻辑分析仪GND          -> J15-39
```

J15-9是GPIO_IO04，不是GND；这是核对原理图后修正的接线错误。测试时不连接外部3.3 V或5 V，GPIO14直接给GPIO15提供0/1电平，避免输入悬空并减少误加电压风险。

未连接J15-8与J15-10时，输出翻转但输入一直为0：

```text
GPIO OUT=0, IN=0
GPIO OUT=1, IN=0
```

这说明输出软件状态变化，但不能验证输入。连接回环线后，COM18稳定显示：

```text
GPIO OUT=0, IN=0
GPIO OUT=1, IN=1
```

逻辑分析仪原始数据：

```text
F:\project\Learning\RTOS\docs\digital.csv
```

实测相邻边沿约`0.50004 s`，完整周期约`1.00008 s`，频率约`1 Hz`，CH0与CH1同相。由此同时验证：

1. FreeRTOS任务和`vTaskDelay(500 ms)`持续调度。
2. M7对GPIO2寄存器的TRDC权限有效。
3. GPIO2_IO14输出有效。
4. GPIO2_IO15输入有效。
5. IOMUX、扩展口位置、物理接线和串口打印相互一致。

## 十五、关键故障及排查方法

### 15.1 UUU找不到SDPS

现象：

```text
No MX95 SDPS device was detected
```

排查层级：

```text
SW4是否为ON、OFF、OFF、ON
-> J7是否为可传数据的USB线
-> J11是否稳定供电
-> 是否重新上电使Boot ROM重新采样SW4
-> uuu.exe -lsusb是否出现VID 1FC9/PID 015D
```

### 15.2 UUU提示文件打不开

最初PowerShell把`SDPS: boot -f ...`作为错误参数传给UUU，出现`fail open file`。解决方法是把命令写入`.uuu`脚本，让UUU以命令列表模式解析，并保证镜像路径相对`.uuu`文件可解析。

### 15.3 100%反复循环或LIBUSB_ERROR_PIPE

不能继续重复同一命令期待结果变化。应先用官方/已验证容器做基线，再只替换一个组件。最终通过保留Pro镜像的V2X和DDR/QB布局解决了容器启动问题。

### 15.4 Linux remoteproc返回Permission denied

查看紧邻的内核日志后确认是`lmm(1) not under Linux Control`，所以没有修改sysfs权限、chmod或重复以root执行。解决方向是换允许Linux控制LM1的SM配置，或像本次一样在冷启动容器中直接装载并启动M7。

### 15.5 GPIO可以工作但LM2反复复位

错误方案把整个GPIO2和API所有权从A55转给M7，结果：

```text
A55早期启动链受阻
-> WDOG3未被维护
-> FCCU报告故障19
-> SM按reaction=lm_reset复位LM2
-> 再次启动、再次超时，形成循环
```

修复过程不是关闭看门狗或屏蔽FCCU，而是做单变量对照，保留A55的`PERLPI_GPIO2 ALL`和`GPIO2 ACCESS`，避免再次阻断A55启动。修复后：

```text
COM17：A55 SPL恢复输出
COM18：M7 UART和GPIO任务持续运行
COM19：SM正常，无errId=19循环
```

## 十六、从源码到实机现象的总流程

```text
1. 阅读QSG、UM12527、原理图和AN14748
-> 2. 确认J11供电、J22串口、J7下载、SW4启动模式
-> 3. 先从eMMC启动原厂Linux，验证板卡、A55和串口正常
-> 4. 在/lib/firmware确认官方M7 BIN/ELF存在并检查格式
-> 5. 验证J-Link、remoteproc、USB+UUU三条路线
-> 6. 因无调试器和测试点不便，暂缓J-Link
-> 7. 因SM拒绝Linux控制LM1，暂缓remoteproc
-> 8. 用SW4和uuu -lsusb确认Boot ROM SDPS，选择USB+UUU
-> 9. 从NXP SDK的FreeRTOS hello工程开始，在IAR编译M7 BIN
-> 10. 适配LPUART7，实现中断接收、FreeRTOS队列和任务回显
-> 11. 加入RGPIO驱动、GPIO14输出和GPIO15输入任务
-> 12. 在WSL用Arm GNU 14.2.Rel1重编含正确TRDC权限的SM
-> 13. 用imx-mkimage合并NXP Pro组件、SM BIN和M7 BIN
-> 14. 解析容器并检查核心、地址、大小和哈希
-> 15. UUU执行SDPS: boot，把完整容器临时送入RAM并启动
-> 16. COM19确认DDR和SM，COM18确认M7 FreeRTOS
-> 17. COM18输入字符，确认UART RX/中断/队列/任务/TX闭环
-> 18. J15-8连接J15-10，确认GPIO输出输入闭环
-> 19. 用逻辑分析仪确认约1 Hz同相波形
-> 20. 用单变量对照修复GPIO2所有权导致的WDOG3故障
-> 21. UUU以官方Pro flash_a55临时启动到Fastboot
-> 22. Fastboot选择sd_dev=1，把flash-m7-gpio-reclaim.bin写入SD启动区
-> 23. SW4改为SD启动，断电重启，不运行UUU
-> 24. COM18自动输出M7任务，COM17运行Linux，完成掉电保持验证
```

## 十七、当前可复现的最短操作

前提是IAR已生成最新`freertos_hello.bin`，SM源码、官方工具链和NXP组件未移动。

重新构建容器：

```powershell
cd F:\project\Learning\RTOS
wsl.exe -d UbuntuBuild -u root -- bash /mnt/f/project/Learning/RTOS/tools/build-m7-gpio.sh
```

检查USB下载设备：

```powershell
.\tools\uuu-1.5.243\uuu.exe -lsusb
```

RAM启动：

```powershell
.\tools\uuu-1.5.243\uuu.exe .\build\pro-gpio\gpio-reclaim-ram.uuu
```

写入SD卡启动区：

```powershell
.\tools\uuu-1.5.243\uuu.exe -V -b sd `
  .\bsp\LF_v6.18.2-1.0.0_IMX95\imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55 `
  .\build\pro-gpio\flash-m7-gpio-reclaim.bin
```

该命令的第一个镜像只用于通过SDPS/SDPV临时启动到Fastboot，第二个镜像才是写入SD卡的内容。已从官方Pro镜像中的U-Boot环境字符串确认`sd_dev=1`、`mmcdev=1`，并且此前实机`mmc list`确认`mmc 0`为eMMC、`mmc 1`为SD。UUU日志实际执行并成功返回：

```text
FB: ucmd setenv fastboot_dev mmc
FB: ucmd setenv mmcdev ${sd_dev}
FB: ucmd mmc dev ${sd_dev}
FB: flash bootloader flash-m7-gpio-reclaim.bin
FB: Done
```

写入后断电，把SW4改为`ON、OFF、ON、ON`，拔掉J7并重新上电。拔掉J7不是启动SD的必要条件，但可以避免把USB下载链与SD启动现象混淆。

实机验收：

```text
COM18能输出启动提示
-> 输入字符能原样回显
-> J15-8接J15-10
-> OUT=0时IN=0，OUT=1时IN=1
-> 逻辑分析仪两通道约1 Hz且同相
-> COM19无Reset LM 2/fccu/errId=19循环
```

## 十八、已经完成、尚未验证和后续工作

### 已经完成并实机验证

- SDK FreeRTOS工程由IAR编译成功。
- 自定义M7 BIN和SM BIN被正确加入Pro启动容器。
- UUU通过J7完成SDPS RAM启动。
- M7 FreeRTOS任务实际运行。
- LPUART7输入、输出、中断和任务回显正常。
- GPIO2_IO14输出、GPIO2_IO15输入和物理回环正常。
- GPIO2的SM/TRDC资源配置与RGPIO的PCNS/PCNP属性已分层验证。
- WDOG3/FCCU错误19已经消除。
- UUU已选择`mmc 1`并把自定义容器写入32 GB SD卡启动区。
- SW4改为SD启动并断电重启后，不运行UUU也能自动启动M7 FreeRTOS。
- SD启动时COM18的M7 FreeRTOS和COM19的M33 SM有正常输出；Linux完整启动需要另外提供内核、DTB和根文件系统。

### 资料支持但本次尚未验证

- UUU可以写入eMMC；本次为保护原厂系统未操作。
- Linux可以在合适的SM LMM控制配置下通过remoteproc动态加载M7 ELF。
- J-Link接入TP测试点后可以进行M7断点和单步调试。
- 当前Linux内核、设备树和根文件系统来自SD还是eMMC，尚未通过COM17完整启动日志确认。当前只确认第一阶段启动容器来自SD。

### 后续工作

- 保存SD卡写入日志和镜像哈希，避免后续误写eMMC。
- 设计完整Linux和M7并行运行时的GPIO唯一所有者与RPMsg协作方案。
- 进行FreeRTOS实时性测试，包括中断响应、任务切换、周期抖动、最坏执行时间和系统压力下的确定性。
- 将当前验证代码从SDK示例改造成可维护的独立工程，并保存所有版本、哈希和构建日志。

## 十九、结论

本次不是“把一个FreeRTOS BIN直接烧进Flash”。实际链路是：IAR先把FreeRTOS、SDK驱动和板级代码编译成M7 BIN；WSL中的官方Arm GNU工具链把SM资源配置编译成M33 BIN；`imx-mkimage`再把这两个自定义组件与NXP提供的ELE、DDR、V2X和A55启动组件组装成i.MX95 Boot ROM可以识别的启动容器；最后UUU利用Boot ROM的USB SDPS协议将容器送入易失性内存并启动各核心。

串口回显和GPIO回环是两项独立的端到端验证。串口回显证明LPUART7的收发、中断、FreeRTOS队列和任务调度有效；GPIO回环与逻辑分析仪波形证明M7的GPIO代码、IOMUX、TRDC、PCNS/PCNP和物理引脚都有效。SD卡启动又证明自定义容器可以掉电保存并自动启动M7和A55 U-Boot链。Linux完整共存还需补齐并验证内核、DTB和根文件系统。

## 二十、2026-09-15 SD卡持久化验证

### 20.1 写入前的安全确认

本次没有直接根据UUU帮助文字猜目标设备，而是先完成三项确认：

1. `uuu -bshow sd`确认内置脚本会设置`mmcdev=${sd_dev}`，然后执行`FB: flash bootloader`。
2. 从官方FRDM-IMX95-PRO SD启动镜像中确认`sd_dev=1`和`mmcdev=1`。
3. 实机U-Boot此前执行`mmc list`确认`mmc 0`是eMMC、`mmc 1`是SD。

因此写入目标为SD卡，不是eMMC。UUU退出码为0，所有SDPV和Fastboot命令均返回`Okay`。

### 20.2 掉电启动结果

写入后关闭电源，将SW4设置为`ON、OFF、ON、ON`，保持SD卡插入，不再运行UUU，重新给板卡上电。实测：

```text
COM18：
M7 FreeRTOS UART echo ready
M7 FreeRTOS GPIO test ready
GPIO OUT=0, IN=0
GPIO OUT=1, IN=0

COM19：
DDR OEI: SOC MIMX95(B0), Board mx95lp5
DDR OEI: TRAINING complete
DDR OEI: done, err = 0
Hello from SM (Build 1, Commit c450f539, Sep 15 2026 09:01:10)
*** SM Debug Monitor ***

COM17：
A55 SPL和U-Boot正常运行，因SD上没有Image/DTB而停在U-Boot
```

该结果证明Boot ROM已经从SD启动区读取启动容器，DDR OEI、M33 SM、M7 FreeRTOS和A55 U-Boot链均能在掉电后自动运行。本次只向SD写入约2.85 MB启动容器，没有写入完整Linux WIC镜像，所以U-Boot无法在SD上找到`Image`和DTB。

### 20.3 GPIO输入为0的两种情况

未连接J15-8与J15-10时，输入没有外部高电平，`IN=0`是正常现象。但早期SD模式中，即使已连接回环线，`PDOR/PDIR/PDDR`仍读0、写入无效，这不是接线问题，而是BL31将GPIO2的`PCNS/PCNP`设为`FFFFFFFF`后对安全态M7的访问过滤。

重新可靠连接：

```text
J15-8 GPIO2_IO14 -> J15-10 GPIO2_IO15
```

最终修复后的验收结果为：

```text
GPIO OUT=0, IN=0
GPIO OUT=1, IN=1
```

对应寄存器为`PCNS=PCNP=FFFF3FFF`、`PDDR=00004000`，逻辑分析仪已确认GPIO14有稳定方波。完整证据和最终镜像哈希见`2026-09-15-SD启动GPIO权限问题最终结论.md`。

### 20.4 AN14120在本项目中的用途

`AN14120 Rev.5.0（2026-06-29）`明确覆盖i.MX95，主题是使用VS Code、MCUXpresso for VS Code和J-Link调试Cortex-M。它可用于以后配置J-Link Server、导入SDK工程、附加M7、设置断点、单步、查看变量、寄存器、调用栈和内存，也讨论了仅运行Cortex-M或跳过Cortex-A镜像的调试场景。

它不是本次SD卡写入教程。当前SD持久化的直接依据是UM12527的SW4启动模式、AN14748的M7启动容器流程和UUU内置`sd`脚本。由于Pro板JTAG/SWD只引到TP测试点且当前没有J-Link，AN14120先作为后续硬件调试资料保存，不影响现在使用UUU和SD卡启动。

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md|FRDM-IMX95-PRO开发记录]]
- [[10-项目/FRDM-IMX95-PRO/A55-FreeRTOS任务与时间安排.md|A55-FreeRTOS任务与时间安排]]
