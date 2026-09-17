---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 怎么做
status: 已整理
evidence: 实机验证
tags: []
updated: 2026-09-17
---

# SDK、BSP与调试下载接口

## 一、SDK是什么

SDK 是 Software Development Kit 的缩写，中文通常叫软件开发工具包。它不是一个单独的库，也不等同于操作系统。SDK 是芯片或平台厂商为了让开发者能够针对某个芯片或开发板开发程序，整理出来的一组软件、工程、配置和文档。

以 NXP 的 MCUXpresso SDK 为例，SDK 主要解决的是程序如何建立、编译和调用芯片资源，而不是单独解决板子如何上电启动。一个完整的 SDK 通常包含以下部分：

| 组成部分          | 主要内容                                  | 作用                   |
| ------------- | ------------------------------------- | -------------------- |
| CMSIS 或芯片头文件  | 寄存器地址、位定义、CPU 相关定义                    | 让 C 代码能够访问芯片寄存器      |
| 启动文件          | 复位入口、向量表、栈初始化、C 运行库初始化                | 让处理器从复位状态进入 `main()` |
| 链接脚本          | Flash、TCM、OCRAM、DDR 等内存区域及地址          | 决定代码和数据放到哪里          |
| 外设驱动          | LPUART、LPI2C、GPIO、SPI、CAN、USB 等       | 提供初始化和收发数据的接口        |
| HAL 或 SDK API | 对寄存器操作的封装函数                           | 降低直接操作寄存器的复杂度        |
| 时钟和引脚配置       | 时钟树、引脚复用、电气属性                         | 让外设获得时钟并连接到实际引脚      |
| RTOS 组件       | FreeRTOS 内核、移植层、配置文件和示例               | 在目标核心上运行任务和调度器       |
| 示例工程          | `hello_world`、串口、I2C、FreeRTOS、RPMsg 等 | 用于验证编译、外设和功能         |
| 工程文件          | IAR、GCC、MCUXpresso IDE 或 VS Code 配置   | 告诉工具链如何编译和下载         |
| 文档            | API 手册、用户手册、应用笔记和例程说明                 | 说明使用条件和限制            |

因此，SDK 的作用可以分成三层理解：

1. 让编译器识别目标芯片。
2. 让程序能够初始化芯片和调用外设。
3. 提供一个可以直接编译的示例，帮助确认工具链和硬件环境是否正常。

当前使用的 `SDK_26_06_00_IMX95LPD5EVK-19` 已经实际参与了 M7 FreeRTOS `hello_world` 工程的编译。它生成了 M7 程序文件，但它本身不等于完整的 i.MX95 启动镜像，也不自动解决 FRDM-IMX95-PRO 的 System Manager、多核权限和 USB 启动问题。

## 二、SDK、FreeRTOS和BSP的区别

### FreeRTOS

FreeRTOS 是一个实时操作系统内核，主要提供任务、调度、队列、信号量、软件定时器和内存管理。单独下载 FreeRTOS Kernel 只能获得通用内核和处理器移植层，不能直接获得 i.MX95 的启动文件、引脚配置、System Manager 或开发板下载流程。

### SDK

SDK 是面向开发者的完整软件开发材料。它可能包含 FreeRTOS，也可能包含裸机驱动、USB 协议栈、网络协议栈和示例工程。SDK 会把 FreeRTOS 和芯片驱动、启动文件、链接脚本、编译配置组合起来。

### BSP

BSP 是 Board Support Package 的缩写，中文通常叫板级支持包。BSP 更关注某一块具体板子怎样启动和运行，包括：

- 启动镜像
- U-Boot
- Linux 内核和设备树
- System Manager
- 电源、时钟和内存初始化
- 板载外设的硬件映射
- eMMC、SD 卡和启动分区布局
- UUU 下载脚本

当前的 `LF_v6.18.2-1.0.0_images_IMX95.zip` 属于 i.MX95 Linux BSP 镜像资料。它不是当前 M7 FreeRTOS 的 SDK，但其中的原厂启动文件、U-Boot、设备树、M7 示例固件和 UUU 文件对当前工作有用。

可以用下面的关系理解：

```text
FreeRTOS Kernel：提供实时内核
MCUXpresso SDK：提供芯片开发工程、驱动、启动文件和示例
Linux BSP：提供板卡启动系统、多核管理和平台镜像
UUU：把符合格式的启动镜像发送给芯片
J-Link：通过硬件调试接口下载和调试程序
```

## 三、如何寻找SDK和相关资源

针对一块新板子，资料不能只按芯片名称搜索，应该依次确认：

1. 芯片型号，例如 `MIMX9596`。
2. 封装和内存型号，例如 19x19、LPDDR5。
3. 开发板完整名称，例如 `FRDM-IMX95-PRO`。
4. SDK Builder 中是否有完全同名的开发板。
5. Linux BSP 的版本是否与板载系统一致。
6. 应用笔记中使用的是哪一个 EVK 工程。

下载 SDK 后需要检查：

- 是否包含目标核心的工程，例如 `cm7` 或 `cm33`。
- 是否包含 `freertos_examples`。
- 是否包含目标编译器工程，例如 `iar` 或 `gcc`。
- 是否有对应的启动文件和链接脚本。
- 示例使用了哪个 UART 和哪些引脚。
- 示例的内存地址是否适合当前板子。

当前 SDK Builder 中没有完全同名的 `FRDM-IMX95-PRO` 选项，因此选择了 `IMX95LPD5EVK-19`。这个选择可以用于学习和编译 M7 示例，但不能直接假设它和 Pro 板的所有硬件映射相同。尤其要重新核对 UART、GPIO、启动镜像、System Manager 和内存布局。

## 四、J-Link、JTAG和SWD的关系

### J-Link是什么

J-Link 是 SEGGER 的硬件调试器。电脑通过 USB 连接 J-Link，IAR、VS Code 或 SEGGER 软件通过 J-Link 控制目标处理器。J-Link 的 USB 线只是电脑到调试器的连接，J-Link 到目标板之间还要使用 JTAG 或 SWD 信号。

J-Link可以完成：

- 下载 ELF 或可执行镜像
- 控制处理器复位
- 暂停和继续运行
- 读取和修改寄存器
- 读取和修改内存
- 设置硬件断点和观察点
- 单步执行
- 检查异常现场

J-Link 不是 SDK 的组成部分，也不是 FreeRTOS 的强制要求。之所以在 IAR 工程中看到 J-Link，是因为 IAR 工程的 Debugger 配置常常默认选择 J-Link，或者项目团队规定使用 J-Link。更换为其他支持目标芯片、目标调试协议和 IAR 的调试器，理论上也可以完成下载和调试，但必须同时满足硬件连接、驱动、软件插件和芯片支持条件。

### JTAG的基本原理

JTAG 原本是 IEEE 1149.1 边界扫描测试接口，后来也被处理器用于调试。JTAG 使用串行数据寄存器和状态机传输调试命令。调试器通过时钟线驱动目标芯片，在 TMS 控制的状态机中选择指令寄存器或数据寄存器，再通过 TDI 写入数据，通过 TDO 读出数据。

主要信号如下：

| 信号 | 方向 | 作用 |
| --- | --- | --- |
| TCK | 调试器到芯片 | JTAG 时钟，决定采样和移位时刻 |
| TMS | 调试器到芯片 | 控制 JTAG 状态机切换 |
| TDI | 调试器到芯片 | 向芯片串行输入指令或数据 |
| TDO | 芯片到调试器 | 从芯片串行输出数据 |
| nRESET | 通常由调试器控制 | 复位处理器 |
| VTREF | 板到调试器 | 告诉调试器目标信号电平 |
| GND | 共地 | 建立共同电压参考 |

实际使用 JTAG 时的过程通常是：

1. 给目标板正常供电。
2. 将 J-Link 的 VTREF、GND、TCK、TMS、TDI、TDO 和复位信号正确连接。
3. J-Link 先检测 VTREF，确认目标电平。
4. 调试器对目标处理器复位并发送 JTAG 握手序列。
5. 读取调试端口的 ID，确认芯片可识别。
6. IAR 加载 ELF 中的代码和数据到目标内存。
7. 设置向量表、复位入口和断点。
8. 释放复位并运行程序，或者停在 `main()`。

JTAG 的注意事项：

- TCK、TMS、TDI、TDO 不能接错。
- GND 必须共地。
- VTREF 是电平参考，不能把它误当作大功率供电。
- 目标板仍然需要独立供电。
- nRESET 接错可能导致板子一直复位。
- 调试信号线过长或接触不良会导致识别失败。
- 测试焊盘之间短接可能损坏调试口或电源。

### SWD的基本原理

SWD 是 ARM 提供的 Serial Wire Debug 协议，是 JTAG 的一种两线调试替代方案。SWD 不使用 TDI、TDO 和 TMS，而是使用一根双向数据线 SWDIO 和一根时钟线 SWCLK。

主要信号如下：

| 信号 | 方向 | 作用 |
| --- | --- | --- |
| SWCLK | 调试器到芯片 | 调试时钟 |
| SWDIO | 双向 | 命令、地址和数据传输 |
| nRESET | 调试器到芯片 | 复位目标处理器 |
| VTREF | 板到调试器 | 目标电平参考 |
| GND | 共地 | 公共参考地 |

SWDIO 是半双工双向信号。调试器发送请求时驱动 SWDIO，芯片返回 ACK 和数据时由芯片驱动 SWDIO，双方需要在协议规定的时刻切换方向。SWCLK 始终由调试器产生。

实际使用 SWD 时的过程通常是：

1. 目标板上电并连接 GND、VTREF、SWCLK、SWDIO 和可选的 nRESET。
2. 调试器检测目标电平。
3. 调试器发送 SWD 线复位和激活序列。
4. 读取 Debug Port ID，确认调试端口响应。
5. 选择访问端口，通常是连接到内核调试模块的 AP。
6. 通过内存访问端口读写目标内存和调试寄存器。
7. 下载程序、设置断点并控制处理器运行。

SWD 比 JTAG 少了几根线，但并不等于可以通过串口使用。SWDIO 和 SWCLK 必须连接到处理器的专用调试复用功能，普通 UART 的 TX 和 RX 不具备同样的协议和电气时序。

### 当前板子的实际限制

FRDM-IMX95-PRO 没有安装常见的 10 针或 20 针 JTAG/SWD 插座。原理图第 26 页把调试信号引到了 TP1 至 TP7：

```text
TP1  JTAG_TMS / SWDIO
TP2  JTAG_TDO
TP3  JTAG_RESET
TP4  JTAG_TCK / SWCLK
TP5  JTAG_TDI
TP6  VTREF
TP7  GND
```

TP 是 PCB 上的 Test Point，通常是裸露的金属焊盘。它不是排针，也不是可以直接插入普通杜邦线的连接器。要使用 J-Link，需要先找到焊盘位置和尺寸，然后使用细线、弹簧探针、测试夹具或专用转接板连接。

当前否决 J-Link 方式的原因不是 J-Link 不支持 M7，也不是 SDK 规定只能用 J-Link，而是：

1. 当前没有 J-Link。
2. 板上没有标准调试插座。
3. TP1 至 TP7 位置小且间距紧。
4. 需要额外的探针、夹具或焊接转接线。
5. 手工焊接容易短路、虚焊和接错信号。

## 五、SDP、SDPS和USB下载

### SDP是什么

SDP 是 Serial Download Protocol 的缩写，中文可以理解为串行下载协议。这里的串行不一定指 UART，也可以指通过 USB 进行串行的数据传输。i.MX 芯片内部的 Boot ROM 支持这种下载协议，在没有从正常启动设备启动时，可以等待电脑发送启动镜像。

不同 i.MX 芯片和不同启动阶段可能显示 `SDP`、`SDPS`、`SDPU` 或 `SDPV`。当前 i.MX95 进入的是 `SDPS`，可以把它理解为 i.MX95 Boot ROM 使用的 USB 串行下载阶段协议。不要把 `SDPS` 和 UART 串口混为一谈。

### 如何知道当前板子进入了USB下载模式

判断依据不是 J7 的外观，而是下面几项实际证据：

1. SW4 设置为 `ON、OFF、OFF、ON` 后重新上电。
2. J7 连接电脑，J11 保持供电。
3. Windows 中出现 NXP 的 USB 设备，设备标识中有 `VID_1FC9` 和 `PID_015D`。
4. `uuu.exe -lsusb` 能够列出 `MX95 SDPS`。
5. COM17 的启动日志出现：

```text
Trying to boot from USB SDP
SDP: initialize...
SDP: handle requests...
```

这些日志来自 i.MX95 的启动阶段，而不是 MobaXterm 自己生成的内容。它们说明 Boot ROM 或紧接着的 SPL 已经选择 USB SDP 路径并开始等待主机发送数据。日志是在之前通过 COM17 观察 U-Boot/SPL 启动过程时获得的，之后又用 UUU 的 `-lsusb` 进行了主机侧确认。

### UUU是什么

UUU 是 NXP 的 Universal Update Utility，中文可理解为通用下载工具。它运行在电脑上，通过 USB 与 i.MX 的 Boot ROM、SPL 或 Fastboot 阶段通信。

打开 `uuu.exe` 看不到窗口是正常的。它是命令行工具，不是带图形界面的程序。直接双击通常只会快速打开一个命令行窗口，执行结束后窗口立即关闭，或者因为没有提供命令而没有明显动作。应在 PowerShell 中运行：

```powershell
cd F:\project\Learning\RTOS\tools\uuu-1.5.243
.\uuu.exe -version
.\uuu.exe -lsusb
```

`-version` 查看版本，`-lsusb` 查看当前 USB 下载设备。运行下载时需要提供命令文件或 UUU 脚本，例如：

```powershell
.\uuu.exe F:\project\Learning\RTOS\build\pro-ram-boot\freertos-ram.uuu
```

常见的 UUU 命令含义：

```text
SDPS: boot -f image.bin       通过 Boot ROM 临时发送启动镜像
SDPU: write ...               向后续下载阶段写入镜像的一部分
SDPU: jump                    跳转执行
SDPV: write ...               另一种 SPL 后续传输阶段
FB: flash ...                 通过 Fastboot 执行持久化写入
```

当前使用的命令文件只有 `SDPS: boot`，所以目标是临时装入 RAM 并启动，不包含 eMMC 写入。

### USB加UUU的实际数据流

```text
PowerShell脚本
    |
    v
UUU命令文件
    |
    v
USB J7
    |
    v
i.MX95 Boot ROM的SDPS接口
    |
    v
读取并解析flash.bin
    |
    v
装载ELE、System Manager和M7镜像
    |
    v
尝试启动M7
```

UUU 不是编译器，也不是 J-Link 的替代驱动。它只负责按照 i.MX 启动协议发送文件和执行下载阶段命令。镜像是否正确、System Manager 是否匹配、M7 的地址是否正确，由镜像内容和芯片启动组件决定。

## 六、flash.bin是什么

`flash.bin` 是面向 i.MX 启动链路组织出来的启动镜像，不是单独的 FreeRTOS ELF，也不是简单把几个 BIN 文件首尾拼接起来的压缩包。它通常包含多个容器和镜像描述信息。

当前 i.MX95 多核启动至少要考虑：

- Boot ROM 能识别的容器格式
- ELE 或 AHAB 相关安全启动内容
- V2X 等平台固件，具体取决于原厂镜像
- M33 System Manager
- M7 程序
- 每个镜像的核心类型
- 装载地址
- 入口地址
- 镜像大小和哈希
- 签名块或容器描述

本次 `flash-sm-m7-freertos-hello.bin` 的生成思路是：

1. 从当前板卡对应的原厂 BSP 中取得 Pro 版启动镜像。
2. 使用匹配版本的 `imx-sm` 源码和 `mx95frdm-pro.cfg` 编译 System Manager。
3. 从 SDK 编译得到 M7 FreeRTOS `hello_world` BIN。
4. 使用与 BSP 版本匹配的 `imx-mkimage`。
5. 保留原厂启动容器中与芯片启动相关的内容。
6. 将 Pro 版 System Manager 和 M7 BIN 放到指定容器中。
7. 为 M33 和 M7 填入正确的核心编号、装载地址和入口地址。
8. 生成新的 `flash.bin`。
9. 使用 `imx-mkimage -parse` 检查容器内容。
10. 通过 UUU 的 `SDPS: boot` 进行临时 RAM 启动验证。

当前解析结果中的关键地址为：

```text
M33 System Manager load/entry：0x1FFC0000
M7 system-side load address：0x303C0000
M7 entry address：0x00000000
```

M7 使用 `0x303C0000` 是因为启动容器从 A55/系统侧地址视图装载，M7 启动后使用自己的本地 TCM 地址视图。这个地址不能根据普通 STM32 工程随意填写，必须和 SDK 链接脚本、System Manager 配置以及 `imx-mkimage` 的格式一致。

## 七、IMX95 BSP和Pro板的适配问题

`LF_v6.18.2-1.0.0_images_IMX95.zip` 文件名中没有写 `PRO`，不能仅凭文件名判断它完全适用于 Pro 板。需要检查压缩包内部的文件名、设备树、启动镜像和板卡标识。

当前实际观察到：

- 原厂启动日志显示 `Model: NXP FRDM-IMX95-PRO board`。
- 原厂启动文件名称包含 `imx95-19x19-lpddr5-frdm-pro`。
- Linux 设备树名称包含 `imx95-19x19-frdm-pro.dtb`。
- BSP 中存在 `imx95-19x19-evk_m7_TCM_hello_world` 文件。
- Pro 版 System Manager 配置使用 `mx95frdm-pro.cfg`。

这说明该 BSP 压缩包虽然总名称为 IMX95，但内部包含当前 Pro 板所需的版本或变体。判断资料是否可用时，应该以内部的板卡型号、设备树、启动镜像和版本号为准，而不是只看压缩包名称。

EVK 和 Pro 板即使使用相同的 i.MX95 芯片，也可能存在以下差异：

- LPDDR 型号和初始化参数不同。
- 电源管理芯片不同。
- UART 连接到不同的板载转换器通道。
- GPIO 复用和外部器件不同。
- 启动开关和存储器连接不同。
- System Manager 的逻辑机器和资源权限不同。
- JTAG/SWD 是否引出不同。

因此，EVK SDK 可以作为芯片级和 M7 工程的基础，但生成启动镜像时必须使用 Pro 板对应的 BSP、System Manager 配置和启动组件。不能直接把 EVK 的完整 `flash.bin` 当作 Pro 板镜像使用。

## 八、当前资料在本项目中的分工

| 资料 | 当前用途 |
| --- | --- |
| `SDK_26_06_00_IMX95LPD5EVK-19` | 编译 M7 FreeRTOS 示例，提供驱动、启动文件、链接脚本和工程 |
| `LF_v6.18.2-1.0.0_images_IMX95.zip` | 提供原厂 Linux/BSP 启动文件、设备树、U-Boot、M7 示例和 UUU 配置 |
| `imx-sm` | 编译 System Manager，配置多核资源和逻辑机器 |
| `imx-mkimage` | 组织和解析 i.MX 启动容器 |
| `uuu.exe` | 通过 J7 和 SDPS 协议发送启动镜像 |
| IAR | 编译 M7 工程和生成 ELF/BIN |
| MobaXterm | 观察 COM17 等串口日志，不能代替下载工具 |

当前最重要的认识是：SDK 已经负责生成 M7 程序，BSP 提供板卡启动环境，`imx-mkimage` 负责组合启动容器，UUU 负责通过 USB 发送容器，串口只负责观察结果。

## 九、RAM临时启动、SD卡启动和eMMC启动

### RAM临时启动

当前使用的命令：

```text
SDPS: boot -f flash-sm-m7-freertos-hello.bin
```

主要过程是：

1. 板子进入Boot ROM的USB下载模式。
2. 电脑通过J7把启动容器发送给Boot ROM。
3. Boot ROM和后续启动组件把镜像加载到芯片的RAM、OCRAM、TCM或DDR等运行内存。
4. 芯片尝试执行镜像中的System Manager和M7程序。
5. 断电后，RAM中的内容消失。

这种方式的优点是不会修改eMMC，适合验证：

- 启动容器格式是否正确
- System Manager是否能够启动
- M7是否能够运行
- M7的串口和GPIO是否正确
- 新镜像是否会导致板子无法正常启动

这种方式不是最终产品的持久化烧录，但并不等于没有工程价值。启动镜像在没有验证前直接写入eMMC，可能造成板子无法从eMMC启动，后续还要依靠USB、SD卡或调试器恢复。通常先进行RAM启动测试，再进行SD卡启动测试，最后才考虑eMMC。

### SD卡启动

SD卡属于持久存储。将正确的启动镜像写入SD卡后，断电再上电，Boot ROM可以从SD卡读取启动内容。它比RAM临时启动更接近实际产品启动流程，但不会破坏板载eMMC中的原有Linux系统。

当前有32GB SD卡和读卡器后，可以把SD卡作为隔离测试介质。基本过程是：

1. 准备与FRDM-IMX95-PRO匹配的启动镜像或完整SD卡镜像。
2. 使用镜像写入工具将镜像写入SD卡，而不是直接复制文件到可见分区。
3. 写入前确认目标盘符，避免误写电脑硬盘。
4. 拔出并重新插入SD卡，检查分区是否正常。
5. 按用户手册设置SW4为MicroSD启动模式。
6. 插入SD卡，保持J22连接四个串口。
7. 上电后观察A55、M33和M7的启动输出。

SD卡测试可以回答一个重要问题：镜像在持久存储介质启动时是否正常，而不仅仅是Boot ROM临时接收后是否能够继续执行。当前还不能直接把现有`flash-sm-m7-freertos-hello.bin`写入SD卡就认为一定可启动，因为它是为USB RAM启动过程生成和验证的镜像，仍需要确认其偏移、启动介质格式和Pro板SD启动要求。

### eMMC持久烧录

eMMC是板载的持久存储器，原来的Linux、U-Boot、设备树和M7固件都可能依赖它。写入eMMC通常会涉及：

- 启动分区
- 分区表
- Bootloader
- Linux镜像
- 设备树
- 根文件系统
- 可能的M7启动容器

因此，直接把一个未经验证的`flash.bin`写入eMMC风险较高。`uuu.auto`中出现`FB: flash`、`flash bootloader`、`flash all`等命令时，才需要警惕它可能执行持久化写入。当前的`SDPS: boot`命令没有eMMC写入操作。

工程上常见的验证顺序是：

```text
RAM临时启动
    -> 验证镜像能否运行
SD卡启动
    -> 验证持久介质启动和板级配置
eMMC烧录
    -> 写入正式或测试系统
```

所以USB RAM启动不是最终交付方式，主要是低风险验证阶段。验证成功后，通常可以继续使用同一套经过确认的启动容器制作SD卡镜像或eMMC烧录流程，但不能跳过具体的存储布局和写入脚本检查。

## 十、LMM、LM1和LM2

### 为什么i.MX95需要逻辑机器

i.MX95不是只有一个处理器。它包含多个A55、M7、M33，以及大量共享外设、内存和中断资源。如果所有核心都可以随意访问同一批资源，可能出现：

- 两个核心同时配置同一个UART
- 两个核心同时复位同一个外设
- 一个核心修改另一个核心正在使用的内存
- 不同安全域之间越权访问
- Linux误操作实时核心的时钟或电源

因此i.MX95的System Manager会把处理器、内存、外设和控制权限划分给不同的逻辑机器。

### LMM的含义

LMM 是 Logical Machine Manager 的缩写，可以理解为逻辑机器管理机制。它不是一个具体的CPU核心，而是一套由System Manager维护的资源隔离和控制关系。

LMM负责描述和管理：

- 哪些处理器核心属于哪个逻辑机器
- 哪些内存区域属于哪个逻辑机器
- 哪些外设由哪个逻辑机器使用
- 哪个逻辑机器可以启动或停止另一个核心
- 哪些操作只允许通知，哪些操作允许控制
- 不同安全域之间的访问权限

在Linux中看到的`lmm(1) not under Linux Control`，意思不是Linux用户权限不够，而是System Manager判断：编号为1的逻辑机器不属于Linux所在逻辑机器控制。

### LM1和LM2是什么

LM 是 Logical Machine 的缩写。`LM1`和`LM2`是两个不同的逻辑机器编号，不是M1、M2处理器，也不是两个线程。

当前Pro板配置中大致是：

```text
LM1：包含或负责M7相关资源
LM2：包含A55和Linux运行环境
```

可以将它类比为两个相互隔离的运行域：

```text
LM1                         LM2
M7及其资源                   A55及Linux资源
实时任务                     Linux应用和驱动
独立的部分内存和外设         Linux可控制的外设和内存
```

这种划分的目的是让M7可以作为实时控制核心运行，不被Linux调度延迟或普通驱动误操作影响。代价是A55上的Linux不能默认启动、停止或修改LM1中的M7。

### Control和Notify的区别

System Manager中的权限不是只有允许和禁止，还可能区分不同操作类型：

- `CONTROL`：可以管理、启动、停止、复位或配置目标逻辑机器。
- `NOTIFY`：只能接收或发送状态通知，不能真正控制目标逻辑机器。
- 其他资源权限：可能包括读取、写入、共享或独占使用。

当前Pro配置中，A55所在LM2对M7所在LM1主要只有通知权限，没有完整控制权限。因此Linux执行：

```sh
echo start > /sys/class/remoteproc/remoteproc1/state
```

时，Linux内核虽然能够找到M7 ELF，也能够调用remoteproc框架，但在请求System Manager启动LM1时被拒绝，最终得到：

```text
lmm(1) not under Linux Control
Boot failed: -13
```

`-13`对应权限拒绝。这个错误不是`/lib/firmware`的文件权限，也不是root登录失败。

### LMM对三种启动方式的影响

| 启动方式 | 是否需要Linux控制LM1 | 当前情况 |
| --- | --- | --- |
| J-Link | 通常不依赖Linuxremoteproc，但需要调试接口 | 没有J-Link且测试点难连接 |
| Linux remoteproc | 需要A55获得LM1控制权限 | 当前被LMM权限拒绝 |
| USB启动容器 | 由Boot ROM和System Manager在启动阶段建立资源 | 当前正在验证启动容器 |
| SD卡启动容器 | 与启动镜像内容有关，不一定依赖Linux运行时控制 | 可作为下一步隔离验证 |

### 如何研究remoteproc

研究remoteproc不能只看Linux命令，还要同时看三层：

1. Linux用户接口层：`/sys/class/remoteproc/remoteproc*`。
2. Linux内核驱动层：i.MX95的`imx-rproc`驱动、ELF装载和启动请求。
3. System Manager层：LMM、LM归属、资源和控制权限。

典型流程是：

```text
Linux选择firmware文件
    -> remoteproc解析ELF
    -> 把程序段加载到TCM或共享内存
    -> 从ELF获取入口地址
    -> 请求System Manager复位和启动M7
    -> M7开始执行
```

当前流程停在最后两步之间，不是FreeRTOS调度器没有运行，而是System Manager没有允许Linux控制M7。要继续研究remoteproc，需要取得一个允许Linux控制M7的System Manager启动配置，或者修改现有LMM配置后重新生成启动镜像。修改后应先使用SD卡或USB RAM启动验证，确认Linux中的`remoteproc`状态能够从`offline`变为`running`，再考虑写入eMMC。

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/芯片与平台-i.MX95/启动与烧录/STM32与i.MX95启动和开发流程对比.md|STM32与i.MX95启动和开发流程对比]]
- [[20-领域/芯片与平台-i.MX95/启动与烧录/i.MX95官方启动配置与ELE文件.md|i.MX95官方启动配置与ELE文件]]
