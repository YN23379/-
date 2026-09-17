---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待验证
evidence: 实机验证
tags: []
updated: 2026-09-17
---

# FRDM-IMX95-PRO 开发记录

## 板卡基本信息

FRDM-IMX95-PRO 使用 i.MX 95 处理器，包含 6 个 Cortex-A55、1 个 Cortex-M7 和 1 个 Cortex-M33。A55 一般用于运行 Linux，M7 和 M33 用于实时控制或低功耗任务。板载 16 GB LPDDR5、32 GB eMMC 和 512 Mbit SPI NOR Flash。

## 现有资料

- `UM12527.pdf`：FRDM-IMX95-PRO 用户手册，主要用于查看硬件接口、供电、启动模式和板卡功能。
- `FRDMIMX95PROQSG.pdf`：快速入门手册，主要用于第一次接线和启动。
- `SPF-95794_B1.pdf`：完整原理图。
- NXP Getting Started：<https://www.nxp.com/document/guide/getting-started-with-the-frdm-i-mx-95-pro-development-board:GS-FRDM-IMX95-PRO>
- `AN14748`：How to Run Application on M7 Core of i.MX 95，后续用于学习 M7 程序的构建和运行。
- `AN14120`：Debugging Cortex-M with VS Code on i.MX 8M, i.MX 8ULP, and i.MX 9，后续用于学习 M7 调试。

## 主要接口

| 标号  | 用途              | 当前使用方式                           |
| --- | --------------- | -------------------------------- |
| J11 | USB-C PD 供电     | 使用黑色带 E-marker 的 USB-C 线连接 PD 电源 |
| J22 | USB 调试串口        | 使用白色 USB-C 数据线连接电脑               |
| J7  | USB 3.0 数据接口    | 后续进入串行下载模式并使用 UUU 时使用            |
| J21 | HDMI 输出         | 可选，用于查看预装 Linux 的图形界面            |
| SW1 | USB-C PD 电源使能开关 | 接好 PD 电源后拨到 ON                   |
| SW4 | 启动模式开关          | 第一次启动保持出厂默认设置，从 eMMC 启动          |
| K1  | 冷复位按键           | 系统异常时用于重新启动整个平台                  |
|     |                 |                                  |

J11 只负责供电，不传输 USB 数据。官方快速入门资料要求 PD 电源支持 20 V/5 A，用户手册建议使用 65 W 或更高功率的 USB PD 电源。第一次启动前需要检查电源适配器铭牌，确认支持 USB PD 和 20 V 输出。

## SW1 和 SW4 的作用

`SW1` 是系统电源开关。它控制 USB-C PD 输入是否通过板上的 CC 控制电路进入电源管理部分。SW1 处于 OFF 时，即使 J11 已经接入 PD 电源，板子也不会按正常流程给处理器和外设供电。SW1 处于 ON 时，板子允许 PD 电源输入，PF09 等电源管理电路开始按顺序产生各路电压。SW1 解决的是板子是否上电的问题。

`SW4` 是四位启动模式开关。它不负责给板子供电，而是连接到 i.MX95 的启动模式引脚。处理器复位时，Boot ROM 读取 SW4 的状态，根据状态选择启动设备。当前默认设置为 eMMC 启动。常用设置如下：

| SW4[2] | SW4[3] | SW4[4] | 启动方式 |
|---|---|---|---|
| 0 | 1 | 0 | eMMC，默认 |
| 0 | 1 | 1 | MicroSD |
| 0 | 0 | 1 | USB Serial Downloader |
| 1 | 0 | 0 | SPI NOR Flash |

这里的 0 和 1 对应开关的 OFF 和 ON，SW4[1] 在这些模式中通常为任意状态。第一次启动时保持原来的 SW4 设置，不要为了尝试下载而修改它。

所以第一次上电的顺序是：先用 SW4 选择默认的 eMMC 启动，再用 SW1 打开 PD 电源，处理器随后从 eMMC 读取已经存在的启动镜像。只有在需要更换启动设备或进入 USB 下载模式时，才需要修改 SW4。

## 第一次启动步骤

1. 暂时不改 SW4，不连接 J7，也不进行镜像烧写。
2. 将USB-C 数据线连接 J22 和电脑。
3. 在 Windows 设备管理器中查看端口，正常情况下会出现 CH9114F 提供的四个串口。
4. 使用 MobaXterm 分别打开四个串口，参数设置为 115200、8 位数据、无校验、1 位停止位、无流控。
5. 将 PD 电源通过USB-C 线连接 J11。
6. 将 SW1 拨到 ON，观察 D4 电源指示灯和四个串口的输出。
7. 不操作 U-Boot，等待板载 eMMC 中的 Linux 自动启动。
8. 保存完整启动日志，记录哪个串口对应 A55、M7 和 M33。

## MobaXterm 串口配置

在 MobaXterm 中选择 `Session`，然后选择 `Serial`。需要建立四个串口会话，分别选择 `COM16`、`COM17`、`COM18` 和 `COM19`，不能使用 `Choose at session start` 代替具体串口。

基础设置如下：

- Serial port：选择当前实际存在的 COM 号
- Speed：`115200`
- Data bits：`8`
- Stop bits：`1`
- Parity：`None`
- Flow control：`None`

截图中的 `Xon/Xoff` 需要改为 `None`。Xon/Xoff 是软件流控，会使用特定字符控制发送暂停和继续。当前板卡用户手册要求无流控，选择 `None` 可以避免启动日志中的普通字符被误认为流控字符。

四个 COM 口不代表四条独立的外接线，而是 CH9114F 这一个 USB 转四路 UART 芯片提供的四个通道。由于 A55、M33 和 M7 的端口映射不固定，第一次打开四个窗口最稳妥。

官方手册说明 A55、M7 和 M33 对应的 COM 口编号不固定，因此第一次需要同时打开四个串口。当前 Windows 中保留过 CH9114F 的 COM16、COM17、COM18 和 COM19 设备记录，但检查时没有活动串口，需要在实际连接 J22 并上电后重新确认。

## 后续验证顺序

1. 验证电源、串口和 eMMC 中的 Linux 能够正常启动。
2. 进入 Linux，查看 `/lib/firmware/` 中已有的 Cortex-M7 示例固件。
3. 按照 `AN14748` 运行一个已有 M7 示例，观察 M7 对应串口输出。
4. 获取示例对应的源码、工具链和构建说明，完成一次不修改代码的重新编译。
5. 将重新编译的固件复制到板卡并加载运行。
6. 在基础示例能够运行后，再测试 FreeRTOS 示例和调试功能。

## 当前进度

> 本节为截至2026-09-14的最新状态。后文保留早期排查记录，其中“尚未完成”等文字只代表当时状态。

- 已收集用户手册、快速入门、原理图、布局图、AN14748和AN14120等官方资料。
- 已安装IAR并使用SDK 26.06.00编译M7 FreeRTOS工程，编译为0错误、0警告。
- 已通过J7、USB Serial Downloader和UUU完成RAM临时启动，未写入eMMC。
- COM18已完成M7 FreeRTOS串口输出和输入回显验证。
- 已修改System Manager资源配置，使M7可访问GPIO2，同时保留A55所需的GPIO2 API与访问权限。
- GPIO2_IO14输出、GPIO2_IO15输入已完成物理回环验证；COM18中输出值与输入值同步变化，逻辑分析仪测得约1 Hz方波。
- 早期GPIO权限方案曾导致COM19持续报告`Reset LM 2, reason=fccu, errId=19`；2026-09-15已通过单变量对照定位并解决。
- 最终发现SD启动进入BL31后，BL31会把GPIO2的`PCNS/PCNP`写成全1。M7程序改为只清除bit14/15，保留自己的两根引脚。
- 已完成SD卡持久化启动，断电后M7 FreeRTOS可从SD自动运行；GPIO输出波形和14→15输入回环均通过；eMMC未覆盖。

## 2026-09-10 第一次上电记录

接线和设置：

- 白色 USB-C 线连接电脑和 J22。
- 黑色 USB-C PD 线连接电源和 J11。
- SW1 置于 ON。
- SW4 保持原来的默认设置。
- MobaXterm 使用 115200、8 位数据、无校验、1 位停止位、无流控。

实际现象：

`COM19` 输出以下内容：

```text
DDR OEI: SOC MIMX95(B0), Board mx95lp5
DDR OEI: done, err = 0
Hello from SM
*** SM Debug Monitor ***
> $
```

其中 DDR OEI 表示 DDR 初始化相关固件，`SM` 表示 System Manager，系统管理固件已经运行到调试监控命令提示符。这个结果可以说明板子已经完成上电，至少系统管理部分和 J22 的其中一路串口工作正常。

`COM17` 出现大量乱码，可能原因包括该通道使用了不同波特率，或者该通道输出的是不适合直接显示的二进制数据。`COM16` 和 `COM18` 暂时没有输出，可能是对应核心当前没有启动或该通道只在特定阶段输出。下一步通过 K1 复位并同时观察四个窗口，必要时对 COM17 尝试 1500000、921600、57600 和 38400 波特率。暂时不在 COM19 的监控提示符中输入未知命令。

## 2026-09-10 COM17 启动结果

将 COM17 设置为 115200 后，获得了完整的 A55 启动日志。日志中的关键内容如下：

```text
U-Boot SPL 2025.04-g99518e6b6f20
Normal Boot
Trying to boot from MMC1
CPU: i.MX9596 rev2.0 at 1800MHz
Model: NXP FRDM-IMX95-PRO board
DRAM: 15.8 GiB
Starting kernel ...
Linux version 6.18.2-1.0.0
smp: Brought up 1 node, 6 CPUs
Welcome to NXP i.MX Release Distro 6.18-whinlatter
imx95-19x19-lpddr5-frdm-pro login:
```

根据日志，COM17 对应 A55 的系统调试串口。板子从 `MMC1` 的 eMMC 启动，U-Boot、Linux 内核和 6 个 A55 CPU 都已经启动，最后进入 Linux 登录提示符。此时可以在 COM17 输入 `root` 并回车，登录预装的 Linux 系统。

日志中的 `bad CRC, using default environment` 表示 U-Boot 保存的环境变量校验失败，当前使用默认环境变量。日志中的 `Fail to setup video link` 以及 Weston 启动失败与显示输出有关，目前不影响串口登录。COM19 对应系统管理固件，COM16 和 COM18 暂时没有持续输出，M7 和 M33 的对应关系需要在加载相应固件后继续确认。

## 2026-09-10 Linux 登录和 M7 固件记录

COM17 最终进入以下 Linux 登录提示符：

```text
NXP i.MX Release Distro 6.18-whinlatter
Type 'root' to login with superuser privileges (no password will be asked).
imx95-19x19-lpddr5-frdm-pro login:
```

第一次输入 `root` 后出现密码提示并在 60 秒后超时，随后串口重新显示了免密登录说明。第二次输入 `root` 后进入命令行，说明预装系统的 root 串口登录不需要密码，第一次密码提示属于登录服务切换或重新启动过程中的普通提示，不需要寻找默认密码。

登录后执行 `uname -a` 得到：

```text
Linux imx95-19x19-lpddr5-frdm-pro 6.18.2-1.0.0-gf49f45233f7b #1 SMP PREEMPT ... aarch64 GNU/Linux
```

执行 `ls -l /lib/firmware` 和 `find /lib/firmware -type f`，发现系统中已经预置多组 M7 固件。其中与当前 19x19 平台和 FreeRTOS 学习最相关的文件包括：

```text
imx95-19x19-evk_m7_TCM_hello_world.bin
imx95-19x19-evk_m7_TCM_hello_world.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.bin
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.bin
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.elf
imx95-19x19-evk_m7_TCM_flexcan_linux.bin
imx95-19x19-evk_m7_TCM_netc_share.bin
```

文件名中的 `m7` 表示目标核心是 Cortex-M7，`TCM` 表示程序使用 TCM 内存，`rtos` 表示示例使用实时操作系统，`rpmsg_lite` 表示 Linux 与 M7 之间可能使用 RPMsg Lite 通信，`linux_remote` 表示由 Linux 侧参与管理或加载。下一步先查看 remoteproc 状态，再选择 `hello_world` 或 RPMsg 示例运行。

## 2026-09-10 第一次设置 M7 固件

在 `remoteproc1` 的 `firmware` 属性中写入了 `imx95-19x19-evk_m7_TCM_hello_world.elf`。写入固件名称后，`state` 仍显示 `offline`，这是正常现象，因为写入 `firmware` 只选择待加载文件，不会自动启动 M7。还需要向 `state` 写入 `start`，remoteproc 才会读取 ELF、装载程序并启动 M7。

第一次输入命令时漏写了结尾双引号，Shell 显示 `>`，表示命令尚未结束并等待继续输入。使用 `Ctrl+C` 可以取消这条未完成的命令，重新输入完整命令。

向 `remoteproc1/state` 写入 `start` 时，Shell 返回以下错误：

```text
-sh: echo: write error: Permission denied
```

当前用户为 root，而且此前可以写入 `firmware`，因此该错误不是普通的 Linux 文件读写权限问题，而是 remoteproc 驱动在处理启动请求时返回了拒绝。可能原因需要结合紧随错误产生的内核日志判断，目前尚未确定，不能通过修改 sysfs 权限或重复启动来处理。

### 启动失败的根因

诊断信息如下：

```text
/sys/devices/platform/imx95-cm7
imx-rproc imx95-cm7: Using LMM Protocol OPS
remoteproc remoteproc1: Booting fw image imx95-19x19-evk_m7_TCM_hello_world.elf
imx-rproc imx95-cm7: lmm(1) not under Linux Control
remoteproc remoteproc1: Boot failed: -13
```

`remoteproc1` 已确认对应 i.MX95 Cortex-M7，Linux 也已经找到并读取 M7 ELF。启动失败发生在 System Manager 的 LMM 权限检查阶段。当前 M7 属于 LMM 1，但该 Logical Machine 不受 Linux 控制，因此驱动返回 `-13`，即权限拒绝。

这个问题不能通过修改 sysfs 权限解决。后续需要使用允许 A55/Linux 控制 M7 的 RPMsg 启动镜像，或者按照 `AN14748` 将 M7 程序打包到启动镜像中。为避免损坏当前可用的 eMMC，优先在 MicroSD 上准备测试镜像。

## 2026-09-10 M7下载接口结论

J22连接的是CH9114F USB转四路UART，只负责串口收发，不具备JTAG/SWD下载功能。Pro板没有安装标准JTAG插座，原理图第26页将调试信号引到了PCB测试点。测试点是焊盘，不是排针，也不是SoC封装引脚。

```text
TP1  JTAG_TMS / SWDIO
TP4  JTAG_TCK / SWCLK
TP2  JTAG_TDO
TP5  JTAG_TDI
TP3  JTAG_RESET
TP6  3.3 V目标电压参考
TP7  GND
```

使用J-Link时，需要通过测试夹具、转接板或焊线将J-Link线缆连接到这些测试点。J11继续独立给开发板供电，J-Link不能代替板卡主电源。

不用J-Link时，可以使用i.MX95 USB Serial Downloader。SW4设置为`x001`，电脑连接USB1对应的J7，再通过NXP UUU下载完整启动镜像。该方式需要适配Pro板并包含System Manager和M7固件的`flash.bin`，不能直接下载IAR生成的`.out`。当前Linux remoteproc方式因`lmm(1) not under Linux Control`暂时不可用。

### USB Serial Downloader验证结果

SW4设置为`ON、OFF、OFF、ON`后冷启动，J22的四路UART没有启动日志，J7在Windows中枚举为：

```text
VID_1FC9&PID_015D
Bus reported device: OO Blank 95
Status: OK
```

`VID_1FC9`为NXP厂商ID，说明i.MX95已经进入Boot ROM的USB Serial Downloader模式。该设备显示在Windows的HID/USB输入设备分类下，不会新增COM口。下一步使用NXP UUU的`uuu.exe -lsusb`继续验证，不执行烧写命令。

## 2026-09-10 温度检查

Linux thermal 接口读取到以下结果：

```text
ana-thermal: 49.0 C
a55-thermal: 49.9 C
pf09: 105.0 C
pf53_soc: 105.0 C
pf53_arm: 105.0 C
```

A55 和模拟模块约 50°C，属于当前空载启动下可以继续观察的温度。PF09 和两颗 PF53 同时显示 105°C，不能直接判定为正常。三个读数完全相同，可能是驱动占位值、无效传感器返回值或实际高温，需要继续检查 thermal zone 的设备路径、阈值和 hwmon 原始值。在确认前暂不启动 M7 固件，避免增加负载。

## 2026-09-10 M7 编译与下载接口

使用 MCUXpresso SDK 26.06.00 的 `IMX95LPD5EVK-19` 裸机 `hello_world_cm7` IAR 工程完成编译，结果为 0 个错误、0 个警告，生成了 `hello_world_cm7.out` 和 `hello_world.bin`。这说明 IAR、MIMX9596 器件支持和 SDK 编译链可以使用，但不代表程序已经适配 FRDM-IMX95-PRO。

板卡手册和原理图表明，J22 连接 CH9114F，只提供四路 USB 转 UART，不能作为 IAR 下载器。SoC 的 JTAG/SWD 信号只引出到原理图第 26 页的 TP1 至 TP7 测试点，板上没有常见的 JTAG 插座。若使用 IAR 的 J-Link 下载，需要外置 J-Link 和适配测试点的转接线或夹具。

当前 EVK 示例使用 LPUART3 输出，而 Pro 板 J22 接入 UART1、UART2 和 UART7，因此现有示例即使被装入 M7，也不能直接用 J22验证串口输出。下一步需要取得 FRDM-IMX95-PRO 对应的 M7 BSP、引脚配置和 System Manager/LMM 启动配置，或者根据原理图完成板级适配。

## 2026-09-10 M7启动路线核对

实机U-Boot版本为`2025.04-g99518e6b6f20`，同时提供`bootaux`和`rproc`命令。公开源码中的i.MX95 `bootaux`实现通过安全监控调用启动辅助核心，M7核心编号为`1`，启动前通常需要先执行`prepaux 1`。因此可以尝试U-Boot辅助核心启动路线，但不能省略准备核心、程序装载和地址转换。

板载U-Boot显示`FSL_SDHC: 0 (eMMC)`和`FSL_SDHC: 1`，其中`mmc 0`是eMMC，`mmc 1`是未插卡的SD卡槽。此前访问`mmc 1:2`失败只是设备号选错，与FreeRTOS无关。U-Boot的i.MX95 remoteproc驱动能够解析ELF，并通过System Manager的SCMI接口设置M7复位向量和启动核心。但当前执行`rproc init`只显示用法，`rproc list`为空，需要继续用`rproc init 0`核对设备是否可用。

NXP应用笔记AN14748给出的正式方法是将M7程序作为`m7_image.bin`，和System Manager固件、启动固件及A55启动组件一起通过`imx-mkimage`生成`flash.bin`。`uuu.auto`只是UUU命令脚本，不是固件本体。完整Linux镜像用于重装Linux系统，也不是单独验证M7程序的必要文件。当前优先顺序为先验证U-Boot `rproc`，若仍被LMM拒绝，再生成包含M7程序的Pro板启动容器，并先通过USB Serial Downloader临时启动验证，确认无误后才考虑写入eMMC。

### eMMC分区和M7固件实机检查

U-Boot执行`part list mmc 0`确认板载eMMC使用DOS分区表，共有两个分区。分区1为启动分区，分区2为Linux根文件系统。`mmc 1`是未插卡的SD卡槽。

```text
mmc 0:1  Boot分区
mmc 0:2  Linux根文件系统
```

通过`ext4ls mmc 0:2 /lib/firmware`确认根文件系统中存在当前19x19平台的M7程序：

```text
imx95-19x19-evk_m7_TCM_hello_world.bin  12028字节
imx95-19x19-evk_m7_TCM_hello_world.elf  50976字节
```

实机U-Boot同时提供`bootaux`、`prepaux`和`rproc`。执行`rproc init 0`后报告：

```text
Remoteproc not under U-boot control: only support detect running
```

`rproc list`仍能列出编号0的`imx95-cm7-root_driver`，但只检测运行状态，不能通过该路径加载和启动M7。随后尝试了U-Boot的`prepaux`和`bootaux`路线，结果见下一节。

### U-Boot直接装载TCM程序失败

U-Boot能够从eMMC根文件系统读取M7程序，文件大小和开头的向量表数据正常：

```text
ext4load mmc 0:2 0x90400000 /lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.bin
12028 bytes read

md.l 0x90400000 2
90400000: 2001e000 0000087d
```

`0x2001e000`是M7的初始栈指针，`0x0000087d`是带Thumb状态位的复位入口，说明BIN文件本身可以读取，并且确实是按M7本地TCM地址构建的。

执行`prepaux 1`后，System Manager接受了准备M7核心的请求。但是A55将程序复制到M7 ITCM映射地址时发生同步异常：

```text
cp.b 0x90400000 0x203c0000 ${filesize}
"Error" handler, esr 0xbe000011
Resetting CPU
```

SDK中19x19 EVK示例给出的TCM装载地址同样是`0x203c0000`，因此这次失败不是命令拼写或地址随意选择造成的。结合此前Linux和U-Boot remoteproc均提示M7不受A55控制，可以判断当前FRDM-IMX95-PRO出厂System Manager的LMM和访问控制配置不允许A55按这条路线直接写M7 TCM。异常只发生在内存访问阶段，没有执行eMMC写入，自动复位后原系统不受影响。

当前停止重复尝试Linux remoteproc、U-Boot rproc、`cp.b`写M7 TCM以及DDR临时启动。现阶段的正式主线是使用FRDM-IMX95-PRO对应的System Manager配置，将M7程序打包进i.MX启动容器`flash.bin`，再通过J7和UUU进行USB临时启动。先验证启动容器能够运行，再决定是否写入eMMC。

SDK裸机`hello_world_cm7`工程带有`ddr_debug`配置，并已使用IAR 9.70.4编译成功。该结果只保留为备选研究材料，不作为当前主线。

### 下载方式结论

原理图第26页表明，板上没有安装标准JTAG或SWD连接器。调试信号只引到测试焊盘：TP1为TMS/SWDIO，TP4为TCK/SWCLK，TP2为TDO，TP5为TDI，TP3为复位，TP6为VTREF，TP7为GND。使用J-Link还需要测试点夹具、探针或焊接转接线，不能直接插到板上。

当前没有J-Link、测试夹具和SD卡，因此可用的正式下载接口是J7。SW4选择USB Serial Downloader后，Boot ROM通过J7被UUU识别。UUU不能把单独的FreeRTOS BIN当作完整启动镜像运行，需要先取得或制作包含Pro版System Manager和M7程序的`flash.bin`。

Pro版System Manager配置文件为`configs/other/mx95frdm-pro.cfg`。该配置将M7划分为LM1，将A55划分为LM2，并且A55非安全域对`LMM_1`只有`NOTIFY`权限。这解释了当前Linux remoteproc的`lmm(1) not under Linux Control`以及U-Boot无法直接装载M7 TCM的问题。若项目要求Linux运行时启动和停止M7，需要修改System Manager权限配置并重新生成启动镜像；若只要求M7随板卡启动，则可以把M7固件直接加入启动容器。

### Linux BSP预编译镜像包

已检查`LF_v6.18.2-1.0.0_images_IMX95.zip`。该包与板载Linux版本一致，并包含FRDM-IMX95-PRO专用文件：

```text
imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
imx-boot-imx95-19x19-lpddr5-frdm-pro-fspi.bin-flash_a55_flexspi
imx95-19x19-frdm-pro.dtb
```

其中`flash_a55`包含Pro板启动Linux所需的AHAB、System Manager、DDR初始化、SPL和U-Boot等启动组件，可作为恢复镜像和制作新启动容器的版本来源。包内没有Pro版`flash_all`、独立`m33_image.bin`或Pro专用`uuu.auto`。`imx_mcore_demos`中的M7程序均为EVK或Verdin版本，不能直接认定为Pro板应用。

压缩包根目录的`uuu.auto`写死了19x19 EVK的`flash_all`和`imx-image-full-imx95evk.wic`，不能用于Pro板。执行完整脚本会覆盖eMMC，而不是仅临时运行M7。

已将少量关键文件提取到：

```text
F:\project\Learning\RTOS\bsp\LF_v6.18.2-1.0.0_IMX95
```

下一步在Linux构建环境中编译`imx-mkimage`，解析并提取Pro版`flash_a55`中的启动组件。随后使用Pro版System Manager配置和M7程序生成新的`flash_lpboot_sm_m7`，先通过UUU进行RAM启动测试，不执行eMMC烧写。

## 2026-09-10 Pro版RAM启动镜像

已搭建用于NXP固件构建的`UbuntuBuild` WSL 1环境，安装Arm GNU Toolchain 14.2.1、Make、GCC、Newlib、SRecord和Perl。WSL 1可以完成本次命令行构建，不依赖当前无法启动的WSL 2虚拟机环境。

System Manager源码使用与板载BSP一致的`lf-6.18.2-1.0.0`分支，并采用Pro板配置`configs/other/mx95frdm-pro.cfg`完成构建。该配置允许M7所在的LM1使用LPUART7及GPIO_IO36、GPIO_IO37。原SDK示例使用LPUART3，其引脚没有接入J22，因此已将FreeRTOS `freertos_hello`工程改为以下调试串口并由IAR重新编译：

```text
LPUART7
GPIO_IO36__LPUART7_TX
GPIO_IO37__LPUART7_RX
115200-8-N-1
```

使用匹配版本BSP的AHAB固件、新编译的Pro版System Manager和M7 FreeRTOS程序，通过`imx-mkimage`生成了最小RAM启动容器：

```text
F:\project\Learning\RTOS\build\pro-ram-boot\flash-sm-m7-freertos-hello.bin
大小：317440字节
SHA256：A1DD98244F589EFDF21474E26BA7027931A96C4832E247CC8C4C8374026F3CA0
```

容器解析结果中，System Manager的装载及入口地址为`0x1FFC0000`，M7程序装载地址为`0x303C0000`。本次只通过J7的USB Serial Downloader将容器临时装入RAM，不包含分区、格式化或写eMMC命令。断电后仍会恢复板载Linux启动。

RAM启动脚本为：

```text
F:\project\Learning\RTOS\tools\run-freertos-ram.ps1
```

脚本先等待UUU检测到`MX95 SDPS:`，检测不到时停止，检测成功后才执行命令列表中的`SDPS: boot`。运行前将SW4设为`ON、OFF、OFF、ON`，J7连接电脑，J11供电，J22保留四路串口，并在断电后重新上电。实机已经识别到SDPS设备并开始传输，但传输尚未完成，因此还不能记为板上运行成功。

## M7程序的三种下载与启动方式

这里所说的下载不一定等于写入Flash。J-Link可以把程序装入RAM并调试，Linux remoteproc是在Linux运行后动态装载固件，UUU的`SDPS: boot`是通过Boot ROM临时启动。只有明确执行eMMC、SD卡或FlexSPI写入命令时才属于持久烧录。

### J-Link通过JTAG或SWD调试

J-Link是硬件调试器。电脑上的IAR通过USB控制J-Link，J-Link再把调试命令转换成JTAG或SWD信号。它可以控制处理器复位和运行，将ELF中的代码和数据装入目标内存，读取寄存器和内存，并提供断点、单步和变量观察。因此它适合反复修改M7程序和研究FreeRTOS调度过程。

FRDM-IMX95-PRO没有安装常见的10针或20针调试插座。原理图第26页只把相关信号引到TP1至TP7：

```text
TP1  TMS或SWDIO
TP2  TDO
TP3  RESET
TP4  TCK或SWCLK
TP5  TDI
TP6  VTREF
TP7  GND
```

TP是Test Point，即测试点。它通常是裸露金属焊盘，不是可以直接插杜邦线的排针。即使取得J-Link，仍需根据焊盘尺寸制作探针夹具，或者焊接细线和转接板。当前既没有J-Link，也没有夹具或焊接转接线，因此暂不执行此路线。这是硬件条件不足，不是J-Link不支持Cortex-M7。

### Linux remoteproc动态装载M7固件

remoteproc是Linux内核管理异构处理器的框架。A55先运行Linux，Linux中的i.MX remoteproc驱动读取M7的ELF固件，按照ELF程序头把不同程序段复制到M7的TCM或预留DDR，设置启动地址，然后通过i.MX95 System Manager控制M7的复位和启动。它是Linux运行期间的动态装载，不会因为执行`start`就把程序持久写进eMMC。

典型操作如下：

```sh
R=/sys/class/remoteproc/remoteproc1
cat "$R/name"
cat "$R/state"
echo imx95-19x19-evk_m7_TCM_hello_world.elf > "$R/firmware"
echo start > "$R/state"
cat "$R/state"
dmesg | tail
```

`firmware`属性指定文件名，内核默认从`/lib/firmware`查找文件。写入`start`后才会解析ELF、复制程序并请求启动M7。使用ELF而不是BIN，是因为ELF同时保存了各程序段的目标地址和入口地址。

实机已经确认`remoteproc1`为`imx-rproc`，状态为`offline`，而且`/lib/firmware`中存在M7的hello world ELF。但是写入`start`返回`Permission denied`，相关日志指出`lmm(1) not under Linux Control`。进一步检查Pro版System Manager配置`configs/other/mx95frdm-pro.cfg`发现，M7属于LM1，A55 Linux属于LM2，A55对LM1只有通知权限，没有启动和停止的控制权。U-Boot的remoteproc也报告`Remoteproc not under U-boot control: only support detect running`，与Linux结果一致。

因此这里的`Permission denied`不是root权限、文件权限或sysfs权限问题，不能通过`chmod`或更换root用户解决。真正限制来自System Manager建立的逻辑机器和资源访问控制。要启用该路线，需要修改Pro版System Manager配置，将M7控制权授予A55所在的逻辑机器，重新构建System Manager并更新启动镜像。当前为了尽快先运行FreeRTOS，暂不修改这套运行架构。

### USB加UUU通过Boot ROM启动

UUU是NXP的主机端下载工具，J7是i.MX95的USB下载接口。将SW4设为`ON、OFF、OFF、ON`后重新上电，芯片不先从eMMC启动，而是进入芯片内部固化的Boot ROM。Boot ROM以USB HID设备连接电脑，实机枚举结果为：

```text
Chip      MX95
Protocol  SDPS
VID       0x1FC9
PID       0x015D
```

这条链路不是将单独的FreeRTOS BIN直接复制给M7。i.MX95启动受安全固件、System Manager、资源划分和地址映射约束，因此UUU先将符合i.MX启动格式的`flash.bin`容器发送给Boot ROM。当前容器包含以下关键内容：

```text
AHAB或ELE安全启动固件
FRDM-IMX95-PRO配置的M33 System Manager
Cortex-M7 FreeRTOS程序
各镜像的类型、装载地址、入口地址和哈希
```

当前M33 System Manager装载到`0x1FFC0000`。M7镜像在容器中使用系统侧可访问的别名地址`0x303C0000`，对应M7本地TCM地址`0x00000000`。Boot ROM和安全启动组件解析容器并装载各镜像，System Manager按照Pro配置建立逻辑机器和外设权限，随后M7从复位入口运行FreeRTOS。

当前UUU命令列表只有：

```text
uuu_version 1.5.243
SDPS: boot -f flash-sm-m7-freertos-hello.bin
```

`SDPS: boot`只下载并临时启动容器，不包含`FB: flash`、eMMC分区写入或完整系统镜像写入命令。断电后RAM内容消失，将SW4恢复为正常启动模式后，板子仍从原有eMMC启动Linux。只有后续明确制作并执行eMMC写入脚本时，才会改变板载系统。

选择这条路线的原因是它不需要J-Link、测试点夹具或SD卡，也不依赖Linux对M7的remoteproc控制权。代价是每次断电后都要重新通过UUU下载，并且只能通过串口或GPIO观察结果，不能像J-Link一样单步和查看变量。

### 当前UUU测试状态

最初脚本没有识别设备，是因为UUU实际显示`SDPS:`，脚本只匹配`SDPS`，现已修正。之后UUU能够找到MX95并开始传输自制FreeRTOS容器，但在29%处返回`LIBUSB_ERROR_PIPE`。使用`-force-ctrl`后仍失败。随后使用同版本NXP BSP中的Pro原厂`flash_a55`做对照，传输也返回`LIBUSB_ERROR_TIMEOUT`。

因此M7尚未启动，四个串口没有输出是预期结果。当前证据还不能判定自制容器错误，因为原厂Pro镜像也未完成传输。下一次必须先完全断电，使Boot ROM USB状态重新初始化，再分别测试原厂镜像和FreeRTOS镜像。如果原厂镜像也稳定失败，应优先检查J7数据线、电脑USB接口、扩展坞和供电；如果原厂镜像成功而FreeRTOS镜像失败，再检查自制容器的组成和地址。

完全断电后重新测试，原厂Pro `flash_a55`已经成功进入SPL，并在COM17显示从USB SDP继续启动的信息。这证明Boot ROM、J7、数据线、Windows驱动和UUU可以正常工作。该对照命令只有第一阶段`SDPS: boot`，没有继续发送SPL需要的后续镜像，因此停在SPL等待状态属于测试设计结果，不代表原厂镜像失败。

对比自制镜像和原厂镜像发现，自制镜像从偏移`0x400`开始缺少原厂容器数据。原因是`imx-mkimage -extract`输出的`extracted_imgs/ahab-container.img`只提取了ELE镜像部分，不能替代构建时需要的原始`mx95b0-ahab-container.img`。直接截取完整`flash_a55`前缀也不能作为该输入，因为`imx-mkimage`会重新排布容器。

已从NXP `firmware-ele-imx-2.0.2-89161a8`软件包提取官方`mx95b0-ahab-container.img`，并替换构建脚本中错误的反向提取方案。新镜像通过`imx-mkimage`解析，包含ELE、V2X、Pro版M33 System Manager和M7 FreeRTOS三个ROM容器。最终文件为：

```text
F:\project\Learning\RTOS\build\pro-ram-boot\flash-sm-m7-freertos-hello.bin
大小：403456字节
SHA256：7FDC497F29C4F4482D4D0CBC9EAC161BCF3A6207F5B7C7BBEB63C6FCA00947B9
```

UUU命令列表已通过`-dry`解析检查。该结果表示主机端文件格式和命令语法正确，最终是否能在M7上运行仍以实机UUU传输结果和串口或GPIO现象为准。

## 2026-09-11 下载接口和文件关系补充

### 四个串口为什么不能直接烧录

J22连接的是CH9114F USB转四路UART芯片。UART通常只有TX、RX和GND等信号，适合传输控制台字符和日志。CH9114F本身不具备控制M7复位、访问M7内存、擦除启动存储器或解析i.MX95启动容器的能力。

串口能否烧录取决于芯片是否提供UART Boot ROM协议，或者板上是否运行了一个能够接收串口升级协议的Bootloader。当前实机进入下载模式后显示的是USB SDP/SDPS，并且Windows识别到的是NXP USB设备，不是四个串口。因此当前板子的官方下载入口是J7的USB Serial Downloader，J22的四个串口主要用于观察A55、M33和M7的启动信息。

即使某个串口能看到U-Boot日志，也不能据此认为它就是下载接口。日志输出是单向的控制台功能，烧录还需要协议、存储器写入权限、复位控制和启动模式配合。

### JTAG、SWD和J-Link的实际分工

J-Link是调试器，JTAG和SWD是调试器与目标处理器之间使用的协议。IAR通过USB控制J-Link，J-Link再通过目标板的JTAG或SWD信号访问M7的调试端口。SDK中的IAR工程可能默认选择J-Link作为Debugger，但SDK本身并不要求只能使用J-Link。

JTAG的主要线路是TCK、TMS、TDI和TDO，通常还要连接nRESET、VTREF和GND。TCK由调试器提供时钟，TMS控制JTAG状态机，TDI把命令或数据送入芯片，TDO把结果送回调试器。JTAG可以通过调试端口访问处理器寄存器和内存，因此能够下载程序、控制复位、暂停运行、单步和设置断点。

SWD是ARM提供的两线调试协议，主要使用SWCLK和SWDIO，通常还要连接nRESET、VTREF和GND。SWCLK是调试时钟，SWDIO是一根双向数据线，调试器发送请求时由调试器驱动，芯片返回确认和数据时由芯片驱动。SWD的线路少于JTAG，但仍然需要连接到处理器专用的调试信号，不能用普通UART的TX和RX替代。

实际使用J-Link的步骤一般是：目标板供电，连接目标电平参考和GND，再连接JTAG或SWD信号，J-Link识别调试端口，IAR加载ELF中的代码和数据，设置复位入口和断点，最后释放复位运行。VTREF主要是给调试器识别目标电平，不能当作目标板的主电源使用。

FRDM-IMX95-PRO没有常见的10针或20针JTAG/SWD插座，原理图第26页只引出了TP1至TP7测试点。TP是PCB上的Test Point金属焊盘，不是排针，也不是SoC封装引脚。当前对应关系为：TP1是TMS或SWDIO，TP4是TCK或SWCLK，TP2是TDO，TP5是TDI，TP3是复位，TP6是VTREF，TP7是GND。

所以当前不采用J-Link有两个原因。第一，手中没有J-Link。第二，即使取得J-Link，也需要用细线、弹簧探针、测试夹具或转接板连接这些小而密的焊盘。手工焊接容易出现虚焊、短接和信号接错，特别是VTREF、复位和时钟线接错可能导致调试器无法识别甚至损坏板卡。否决的是当前物理连接条件，不是J-Link不支持Cortex-M7，也不是FreeRTOS只能用J-Link。

### SDP、SDPS和J7下载接口

SDP是Serial Download Protocol的缩写，是i.MX芯片Boot ROM提供的串行下载协议。这里的串行不专指UART，当前i.MX95使用USB承载SDP/SDPS数据。芯片上电复位后，如果启动模式选择USB下载，内部Boot ROM会初始化J7对应的USB设备控制器，等待电脑端工具发送启动镜像。

当前判断J7确实是下载入口，依据来自实际现象，而不是只根据接口外形判断：

1. SW4设置为`ON、OFF、OFF、ON`后，板子进入USB下载模式。
2. Windows识别到`VID_1FC9`、`PID_015D`的NXP USB设备。
3. `uuu.exe -lsusb`能够识别`MX95 SDPS`。
4. COM17曾经显示以下启动阶段信息：

```text
Trying to boot from USB SDP
SDP: initialize...
SDP: handle requests...
```

这些内容来自板子启动过程中的SPL或Boot ROM相关日志，不是MobaXterm生成的提示。它说明芯片已经选择USB SDP路径，并等待电脑继续发送启动数据。设备识别和后续传输结果又通过UUU进行了验证。

SDP、SDPS、SDPU和SDPV表示i.MX下载流程中不同芯片或不同启动阶段使用的协议命令。当前重点是`SDPS: boot`，它要求Boot ROM接收一个符合i.MX启动格式的文件并尝试启动，不等于普通的USB文件复制。

### UUU的使用方式

UUU是NXP的Universal Update Utility，是命令行下载工具，不是双击后出现图形界面的程序。双击`uuu.exe`没有明显窗口是正常现象，应在PowerShell中使用：

```powershell
cd F:\project\Learning\RTOS\tools\uuu-1.5.243
.\uuu.exe -version
.\uuu.exe -lsusb
```

下载时可以把命令写在`.uuu`文件中，再传给UUU：

```powershell
.\uuu.exe F:\project\Learning\RTOS\build\pro-ram-boot\freertos-ram.uuu
```

当前命令文件内容为：

```text
uuu_version 1.5.243
SDPS: boot -f flash-sm-m7-freertos-hello.bin
```

PowerShell脚本先循环执行`uuu -lsusb`等待`MX95 SDPS`出现，确认板子已经进入下载模式后，再执行上述命令。UUU负责按照SDPS协议发送文件，但不负责编译FreeRTOS，也不负责判断M7程序是否适合当前硬件。

### flash.bin的作用和生成过程

`flash.bin`是i.MX启动链路使用的启动容器，不是单独的M7 ELF，也不是简单把几个BIN文件直接拼接。i.MX95是A55、M7和M33组成的异构多核平台，Boot ROM启动时还需要识别容器、镜像类型、核心编号、装载地址、入口地址和哈希等信息。

当前启动容器需要考虑以下内容：

- Boot ROM可以识别的容器格式
- ELE或AHAB相关启动内容
- 与原厂BSP匹配的平台固件
- Pro板的M33 System Manager
- M7 FreeRTOS程序
- 各镜像的核心类型
- M33和M7的装载地址及入口地址
- 镜像长度、哈希和容器描述

本次的`flash-sm-m7-freertos-hello.bin`确实是从多份资料中按启动格式重新组合生成的，过程不是把M7 BIN复制到某个固定地址这么简单。使用到的内容包括：

1. 从`LF_v6.18.2-1.0.0_images_IMX95`中取得与当前Pro板启动流程匹配的原厂组件。
2. 使用`imx-sm`的`mx95frdm-pro.cfg`编译Pro板System Manager。
3. 使用SDK和IAR生成M7 FreeRTOS `hello_world` BIN。
4. 使用匹配版本的`imx-mkimage`重新组织启动容器。
5. 写入M33和M7镜像信息、核心编号、装载地址和入口地址。
6. 使用`imx-mkimage -parse`检查生成结果。
7. 用UUU的`SDPS: boot`进行RAM临时启动测试。

当前解析出的关键地址为：

```text
M33 System Manager：0x1FFC0000
M7 system-side load address：0x303C0000
M7 entry address：0x00000000
```

M7镜像在容器中使用系统侧地址装载，M7启动后再从自己的TCM地址视图运行。因此，M7的链接地址、容器装载地址和System Manager配置必须互相匹配，不能把普通单片机工程生成的BIN直接交给UUU。

`SDPS: boot`当前只做RAM临时启动，不包含`FB: flash`或其他eMMC写入命令。UUU传输到100%只代表电脑把文件交给了Boot ROM，后续还必须看到芯片不复位、M7串口有输出或GPIO有变化，才能证明M7真正运行。

### IMX95 BSP和FRDM-IMX95-PRO的关系

`LF_v6.18.2-1.0.0_images_IMX95.zip`文件名没有写`PRO`，不能只看压缩包名字判断是否适配。实际要检查内部文件名、设备树、启动镜像和板卡标识。当前资料中出现了：

```text
imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
imx95-19x19-frdm-pro.dtb
mx95frdm-pro.cfg
```

并且板载启动日志显示`NXP FRDM-IMX95-PRO board`，所以这个BSP内部包含当前Pro板对应的启动资料。它的作用不是提供完整的FreeRTOS SDK，而是提供原厂Linux启动系统、多核启动组件、设备树、U-Boot、M7示例和UUU脚本。

EVK和Pro即使使用相同的i.MX95芯片，也可能在LPDDR初始化、电源管理、UART连接、GPIO复用、存储器、启动开关和System Manager权限上存在差异。因此，`IMX95LPD5EVK-19` SDK可以用来学习和编译M7工程，但制作完整启动镜像时必须使用Pro板对应的BSP和System Manager配置。

### 32GB SD卡的使用计划

现在已经有32GB SD卡和读卡器，可以把SD卡作为持久启动测试介质。SD卡启动与USB RAM临时启动的主要区别是：USB RAM启动断电后内容消失，SD卡中的启动镜像断电后仍然保留，下一次上电时Boot ROM可以继续从SD卡读取。

SD卡并不意味着可以把任意`flash.bin`或`.bin`文件直接复制到卡中。启动镜像通常需要写入指定扇区偏移，完整Linux SD镜像还包含分区表、启动分区、根文件系统和设备树。写卡前必须确认镜像类型、写入偏移、启动开关和板卡型号。

检查`LF_v6.18.2-1.0.0_images_IMX95.zip`的内容发现，压缩包中存在Pro专用启动文件：

```text
imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
imx95-19x19-frdm-pro.dtb
```

但压缩包中的完整`.wic`系统镜像主要是`imx-image-full-imx95evk.wic`，文件名没有表明它是FRDM-IMX95-PRO版本，不能直接当作Pro板的完整SD卡系统使用。当前更稳妥的顺序是先用USB RAM启动验证包含M7的启动容器，再根据Pro板启动格式制作SD卡启动镜像。SD卡可以降低eMMC误写风险，但仍然需要使用正确的Pro板启动组件。
### 2026-09-11 USB重复测试结论

再次执行`uuu -lsusb`确认开发板稳定枚举为：

```text
MX95  SDPS  VID 0x1FC9  PID 0x015D
```

随后使用相同的`run-freertos-ram.ps1`和相同的`flash-sm-m7-freertos-hello.bin`测试，现象仍然是传输进度从0%到100%后重复开始。由于输入的命令、启动模式和镜像没有变化，本次测试没有产生新的启动条件，也不能期待结果发生变化。

重复进度的实际含义是：主机将镜像传输完成后，芯片尝试执行启动镜像并发生复位，再次进入SDPS，UUU重新发现设备并自动开始下一次传输。MobaXterm提示COM19状态更新，只能说明串口设备发生了重新连接、复位或状态变化，不等于COM19收到了M33或M7的有效日志。

因此当前已经不需要继续重复同一条UUU命令。下一步必须改变测试对象或镜像内容，例如使用官方Pro启动镜像做单独对照，或者重新检查自制容器中的System Manager启动配置、M7镜像描述和入口地址。只有改变其中一个变量后，测试结果才具有新的诊断价值。

### 2026-09-11 M7 FreeRTOS首次运行成功

本次没有使用自动串口采集脚本，而是直接保持MobaXterm打开四个串口，在另一个PowerShell窗口中执行：

```powershell
cd F:\project\Learning\RTOS\build\pro-ram-boot
..\..\tools\uuu-1.5.243\uuu.exe .\freertos-ram.uuu
```

板卡设置为USB下载模式，SW4为`ON、OFF、OFF、ON`，J7连接电脑，J11供电，J22连接串口。实际串口结果为：

COM18输出：

```text
Hello world.
```

这说明当前M7已经真正取得执行权，并且M7上的FreeRTOS `hello_world`程序已经运行到串口输出位置。COM19输出：

```text
DDR OEI: ...
DDR OEI: SOC MIMX95(B0), Board mx95lp5
DDR OEI: TRAINING complete ...
DDR OEI: done, err = 0
Hello from SM
```

这说明DDR初始化和M33上的System Manager也已启动。UUU的`SDPS: boot`已经将包含匹配ELE、原厂Pro启动组件、System Manager和M7 FreeRTOS程序的容器送入芯片并成功执行。

COM17中的：

```text
Trying to boot from USB SDP
SDP: initialize...
SDP: handle requests...
CTRL+C - Operation aborted.
SPL: failed to boot from all boot devices
```

表示A55 SPL仍尝试通过USB SDP等待后续A55启动阶段数据，而当前命令文件只发送并启动了用于本次验证的容器，之后没有继续提供完整A55 Linux启动所需的后续阶段。它不否定M7已运行，因为COM18已经输出`Hello world.`，COM19也显示System Manager正常工作。

本次验证的成功标准已经满足：

```text
M33 System Manager启动
M7启动
FreeRTOS hello_world运行
COM18输出Hello world.
```

当前使用的是USB RAM临时启动，尚未写入eMMC。断电后需要重新进入USB下载模式并执行UUU才能再次运行。下一步可以将同一套已验证的启动容器制作成SD卡启动镜像，验证掉电后的持久启动，再决定是否写入eMMC。

## 2026-09-11 USB+UUU启动链路完整说明

### 一、这次到底运行了哪个文件

最终通过UUU发送的文件是：

```text
F:\project\Learning\RTOS\build\pro-ram-boot\flash-sm-m7-freertos-hello.bin
```

它不是SDK压缩包，不是FreeRTOS源码，不是IAR工程文件，也不是`.uuu`命令文件。它是使用`imx-mkimage`生成的i.MX95启动容器，内部包含多个核心和启动阶段需要的镜像。

这个文件中的M7部分来自IAR编译产生的：

```text
F:\project\Learning\RTOS\SDK_26_06_00_IMX95LPD5EVK-19\boards\imx95lpd5evk19\freertos_examples\freertos_hello\cm7\iar\debug\freertos_hello.bin
```

生成关系是：

```text
FreeRTOS源码 + NXP SDK + 板级配置
        |
        | IAR编译
        v
freertos_hello_cm7.out       调试用ELF/OUT
freertos_hello.bin            M7裸二进制
        |
        | imx-mkimage打包
        v
flash-sm-m7-freertos-hello.bin
        |
        | UUU通过J7发送
        v
i.MX95 Boot ROM接收并临时启动
```

### 二、SDK在这个过程中的位置

SDK没有直接被UUU烧录。SDK提供了：

- M7启动文件
- M7向量表
- Cortex-M7寄存器和CMSIS头文件
- LPUART驱动
- 时钟、引脚和内存初始化代码
- FreeRTOS内核
- FreeRTOS移植层
- 链接脚本
- IAR工程配置
- `freertos_hello`示例源码

IAR使用SDK中的这些内容，把源码编译和链接成M7可执行程序。程序开头的向量表中包含初始栈地址和复位入口，M7复位后会从这个入口开始执行。

本次M7程序使用Pro板实际接出的调试串口配置，修改为LPUART7以及对应的GPIO复用，因此运行后能够从J22对应的COM18看到：

```text
Hello world.
```

### 三、为什么需要完整的flash.bin

普通STM32通常是：

```text
应用程序.bin
    |
    v
ST-Link写入内部Flash
    |
    v
复位后CPU从Flash执行
```

i.MX95不是只有一个运行核心。它包含A55、M7和M33，M7的电源、时钟、复位、内存和部分外设由System Manager管理，芯片上电后还要经过Boot ROM、ELE/AHAB、安全容器、DDR初始化和System Manager启动。

因此M7的裸BIN不能单独交给Boot ROM。芯片需要知道：

- 这是哪个核心的程序
- 应该加载到哪个地址
- 入口地址是什么
- 程序有多大
- 镜像是否通过哈希或安全容器校验
- M33 System Manager放在哪里
- DDR和其他启动组件放在哪里
- 启动后是否还要继续进入A55 SPL或U-Boot

这些信息由i.MX95启动容器保存。`flash.bin`不是简单的文件拼接，而是由容器头、镜像描述、核心类型、装载地址、入口地址、镜像数据、哈希和其他启动信息组成。

### 四、最终容器中包含什么

本次成功构建使用了以下内容：

```text
tools\ele205\mx95b0-ahab-container.img
build\pro-ram-boot\extracted_imgs\container3_img2.bin
build\pro-ram-boot\extracted_imgs\container3_img3.bin
build\pro-ram-boot\extracted_imgs\container3_img4.bin
build\pro-ram-boot\extracted_imgs\app_container1_img1.bin
build\pro-ram-boot\extracted_imgs\app_container1_img2.bin
build\pro-ram-boot\extracted_imgs\app_container1_img3.bin
m7_image.bin
```

各部分作用如下：

| 文件 | 内容和作用 |
| --- | --- |
| `mx95b0-ahab-container.img` | 匹配当前BSP的ELE/AHAB启动容器 |
| `container3_img2.bin` | DDR/OEI初始化相关固件 |
| `container3_img3.bin` | 原厂Pro板M33 System Manager |
| `container3_img4.bin` | A55 SPL |
| `app_container1_img1.bin` | A55启动链中的BL31 |
| `app_container1_img2.bin` | A55启动链中的U-Boot |
| `app_container1_img3.bin` | TEE固件 |
| `m7_image.bin` | 要运行的M7 FreeRTOS程序 |
| `qb_data.bin` | 64KB占位区域，用于保持原厂启动布局 |

其中，`container3_img3.bin`是当前使用的原厂Pro System Manager，不是简单的M7应用。System Manager运行在M33上，负责处理器、时钟、电源、复位、逻辑机器和资源权限。

### 五、这些文件从哪里得到

#### 1. M7 FreeRTOS程序

来自NXP MCUXpresso SDK：

```text
SDK_26_06_00_IMX95LPD5EVK-19
```

使用IAR打开`freertos_hello_cm7.eww`，编译后生成：

```text
freertos_hello_cm7.out
freertos_hello.bin
```

#### 2. 原厂启动组件

来自：

```text
LF_v6.18.2-1.0.0_images_IMX95.zip
```

其中包含：

```text
imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
```

这个文件是当前FRDM-IMX95-PRO对应的A55启动镜像。通过`imx-mkimage`的extract功能，将其中的DDR/OEI、System Manager、SPL、BL31、U-Boot和TEE等组件拆出来。

#### 3. ELE/AHAB容器

之前使用的ELE 2.0.2和当前BSP不匹配。通过匹配BSP版本的NXP资料得到：

```text
firmware-ele-imx-2.0.5-29313e0.bin
```

解包后得到：

```text
mx95b0-ahab-container.img
```

它放在：

```text
F:\project\Learning\RTOS\tools\ele205\mx95b0-ahab-container.img
```

#### 4. 容器打包工具

使用与当前BSP版本匹配的`imx-mkimage`，它读取各个镜像和参数，生成最终的i.MX95启动容器。

### 六、build-final3.sh做了什么

这个脚本不编译FreeRTOS，它只负责打包。它首先把原厂拆出的组件复制到WSL中的`imx-mkimage/iMX95`目录：

```bash
cp container3_img2.bin m33-oei-ddrfw.bin
cp container3_img3.bin m33_image.bin
cp container3_img4.bin u-boot-spl.bin
cp app_container1_img1.bin bl31.bin
cp app_container1_img2.bin u-boot-hash.bin
cp app_container1_img3.bin tee.bin
```

然后生成64KB的QB占位区域：

```bash
dd if=/dev/zero of=qb_data.bin bs=1024 count=64
```

再先制作A55的ATF子容器：

```bash
../mkimage_imx8 -soc IMX9 -cntr_version 2 -c \
  -ap bl31.bin a55 0x8A200000 \
  -ap u-boot-hash.bin a55 0x90200000 \
  -ap tee.bin a55 0x8C000000 \
  -out u-boot-atf-container.img
```

最后制作主容器：

```bash
../mkimage_imx8 -soc IMX9 -cntr_version 2 \
  -append mx95b0-ahab-container.img -c \
  -ddr_dummy 0x1000 \
  -oei m33-oei-ddrfw.bin m33 0x1FFC0001 0x1FFC0000 \
  -hold 65536 qb_data.bin \
  -m33 m33_image.bin 0 0x1FFC0000 \
  -m7 m7_image.bin 0 0x0 0x303C0000 \
  -ap u-boot-spl.bin a55 0x20480000 \
  -dummy 0x8b000000 \
  -out flash-final.bin
```

其中最关键的是：

```text
-append       追加匹配版本的ELE/AHAB容器
-m33          加入M33 System Manager
-m7           加入M7程序
0x303C0000    M7的系统侧装载地址
0x00000000    M7本地入口地址
-hold 65536   保留原厂QB布局
```

M7的`0x303C0000`是系统侧看到的装载地址，M7启动后使用自己的TCM地址视图，从`0x00000000`执行。这个地址由SDK链接脚本、芯片内存映射、System Manager和容器参数共同决定，不能随意更改。

脚本最后把A55 ATF子容器按对齐位置写入主容器，生成：

```text
flash-final-frdm-pro.bin
```

再复制为UUU命令文件中使用的：

```text
flash-sm-m7-freertos-hello.bin
```

### 七、freertos-ram.uuu做了什么

文件内容只有：

```text
uuu_version 1.5.243
SDPS: boot -f flash-sm-m7-freertos-hello.bin
```

它不是固件，也不包含M7程序。它只是告诉UUU：

1. 使用1.5.243版本语法。
2. 等待并使用i.MX95的SDPS设备。
3. 发送指定的启动容器。
4. 让Boot ROM尝试启动这个容器。

运行命令是：

```powershell
cd F:\project\Learning\RTOS\build\pro-ram-boot
..\..\tools\uuu-1.5.243\uuu.exe .\freertos-ram.uuu
```

UUU通过J7连接芯片内部Boot ROM。它不是通过J22串口写入M7，也不是通过MobaXterm下载程序。

### 八、芯片内部实际发生了什么

执行`SDPS: boot`后，过程可以按下面理解：

#### 1. 启动模式采样

SW4设置为`ON、OFF、OFF、ON`，芯片复位时读取启动模式引脚，选择USB Serial Downloader，而不是直接从eMMC启动。

#### 2. Boot ROM运行

芯片内部固化的Boot ROM启动J7对应的USB设备功能，电脑通过USB枚举看到：

```text
MX95 SDPS
VID 0x1FC9
PID 0x015D
```

`VID_1FC9`是NXP厂商标识，`PID_015D`对应MX95的USB下载设备。

#### 3. UUU发送容器

UUU读取`.uuu`文件，执行：

```text
SDPS: boot -f flash-sm-m7-freertos-hello.bin
```

Boot ROM通过USB接收整个启动容器。传输进度达到100%，只代表主机已经把文件发送完成。

#### 4. Boot ROM解析启动容器

Boot ROM根据容器头找到ELE、DDR/OEI、M33、M7和A55等镜像，按照镜像描述进行校验和装载。

#### 5. DDR/OEI初始化

COM19输出：

```text
DDR OEI: SOC MIMX95(B0), Board mx95lp5
DDR OEI: TRAINING complete ...
DDR OEI: done, err = 0
```

说明DDR初始化和训练成功。OEI是DDR初始化阶段使用的固件，不是FreeRTOS。

#### 6. M33启动System Manager

Boot ROM或启动组件将System Manager装载到M33的执行内存并启动M33。COM19输出：

```text
Hello from SM
```

说明M33上的System Manager已经运行。它负责后续多核资源、时钟、复位和外设权限管理。

#### 7. M7装载和启动

容器中的M7镜像被标记为`CORE_M7_0`，系统侧装载到`0x303C0000`。System Manager根据容器和自身配置准备M7的电源、时钟、复位和资源，然后解除M7复位，让M7从本地入口`0x00000000`开始执行。

M7启动文件首先建立栈和向量表，然后进入芯片初始化代码，初始化时钟、引脚和LPUART7，最后进入FreeRTOS示例的`main()`，创建任务并启动调度器。任务输出：

```text
Hello world.
```

COM18看到这句话，证明不是只有M7镜像被装载，而是M7已经执行到了应用代码。

### 九、为什么这次没有写入eMMC

当前命令只有：

```text
SDPS: boot
```

没有：

```text
FB: flash
flash bootloader
flash all
```

所以这次是RAM临时启动：

```text
电脑通过USB发送
    -> Boot ROM接收
    -> 启动组件装载到运行内存
    -> System Manager和M7执行
    -> 断电后RAM内容消失
```

eMMC中的原有Linux没有被覆盖。下一次上电如果仍然保持USB下载模式，还需要再次执行UUU；如果把SW4拨回eMMC启动模式，板子仍会从原有eMMC启动Linux。

### 十、实际运行后的每个输出如何理解

```text
COM18: Hello world.
```

表示M7 FreeRTOS应用已经运行。

```text
COM19: DDR OEI ... done, err = 0
```

表示DDR初始化成功。

```text
COM19: Hello from SM
```

表示M33上的System Manager已运行。

```text
COM17: Trying to boot from USB SDP
```

表示A55 SPL还在尝试等待USB后续启动数据。当前测试没有继续执行完整A55 Linux启动流程，所以COM17出现等待或被中断并不影响M7成功运行。

### 十一、这次成功的判断标准

单独看到UUU的100%不够，因为它只能说明文件传输完成。完整判断需要满足：

1. UUU命令返回`Okay`，没有反复循环或USB传输错误。
2. COM19有DDR OEI和`Hello from SM`，说明启动管理链路正常。
3. COM18出现`Hello world.`，说明M7真正执行了FreeRTOS应用。
4. eMMC没有被写入，原有Linux仍可恢复启动。

本次四项中前三项已经在实机日志中得到验证，第四项由命令文件只有`SDPS: boot`、没有任何eMMC写入命令得到保证。

## 三种M7下载和启动方式统一梳理

### 先区分下载、运行和持久烧录

在i.MX95上，下载M7程序不一定表示把程序写进非易失存储器。J-Link调试通常把ELF中的代码和数据加载到M7的TCM或RAM，Linux remoteproc也把ELF程序段加载到TCM或预留内存，UUU的`SDPS: boot`则把启动容器临时送入RAM执行。这三种操作都可以让M7运行，但默认都不保证断电后自动再次运行。

要实现掉电后自动运行，需要把包含System Manager和M7固件的启动镜像正确写入SD卡、eMMC或其他启动存储器，并让Boot ROM在上电时从该介质启动。

| 方式 | PC端工具 | 物理或软件通道 | 直接输入文件 | 是否默认持久保存 | 当前状态 |
| --- | --- | --- | --- | --- | --- |
| J-Link调试 | IAR、J-Link软件 | JTAG或SWD测试点 | ELF或IAR的OUT | 否，通常加载到TCM/RAM | 未具备J-Link和测试点连接条件 |
| USB加UUU | `uuu.exe` | J7 USB和Boot ROM SDPS | i.MX启动容器`flash.bin` | `SDPS: boot`不持久，带`FB: flash`才写存储器 | USB正常，自制容器启动失败 |
| Linux remoteproc | Linux sysfs和内核驱动 | A55到System Manager再到M7 | ELF固件 | 否，固件文件保存在文件系统，启动时动态加载 | ELF存在，但LMM权限拒绝启动 |

### 第一种：J-Link通过JTAG或SWD

SDK不是J-Link要下载的文件。SDK是一套源码、驱动、启动文件、链接脚本和工程配置。IAR先使用SDK编译工程，得到`freertos_hello_cm7.out`。该OUT本质上是带调试符号和程序段信息的ELF格式可执行文件，J-Link调试器根据其中的地址把程序段加载到M7的TCM或RAM，然后设置入口地址并启动M7。

当前IAR工程的调试配置明确使用：

```text
Debugger：JLINK_ID
Driver：armjlink.dll
```

这说明NXP生成的IAR示例默认配置为J-Link。并不是i.MX95硬件只能使用J-Link。其他调试器若同时满足以下条件，理论上也可以使用：

1. 支持ARM CoreSight以及目标JTAG或SWD协议。
2. 能识别i.MX95中的Cortex-M7调试访问路径。
3. 能在M33 System Manager和多核资源约束下复位、连接并启动M7。
4. IAR存在对应的调试驱动或插件。
5. 厂商提供适用于i.MX95的初始化脚本和支持说明。

ST-Link主要面向STM32生态。即使某型号能产生SWD/JTAG电气信号，也不代表其软件能够识别i.MX95的多核CoreSight结构、执行i.MX95初始化和与IAR当前工程配合。因此当前优先考虑NXP示例已经配置和验证的J-Link，而不是直接用ST-Link替换。

当前已经找到的程序文件为：

```text
SDK工程：SDK_26_06_00_IMX95LPD5EVK-19
IAR输出：freertos_hello_cm7.out
原始BIN：freertos_hello.bin
```

其中OUT适合调试，BIN主要适合打包进启动容器。当前没有完全同名的Pro SDK，所用工程来自19x19 LPDDR5 EVK。芯片和核心基础代码可以使用，但UART引脚、板级初始化和System Manager资源配置需要按Pro板调整。

当前失败原因是没有J-Link，且板上只有TP1至TP7测试焊盘，没有标准调试连接器。解决办法是取得J-Link或其他经确认支持i.MX95的调试器，并制作弹簧探针夹具或焊接转接板。该方式适合开发和源码调试，但若要求掉电自动运行，最后仍要制作并写入正式启动镜像。

### 第二种：USB加UUU

i.MX95内部固化了Boot ROM。SW4选择USB Serial Downloader后，Boot ROM不先从eMMC启动，而是通过J7枚举为NXP USB设备，并使用SDPS协议等待电脑端UUU发送启动镜像。

流程如下：

```text
SW4选择USB启动
    -> Boot ROM通过J7枚举为MX95 SDPS
    -> UUU读取.uuu命令文件
    -> SDPS: boot发送flash.bin
    -> Boot ROM验证和解析启动容器
    -> 装载ELE、System Manager、M7或SPL等镜像
    -> 执行容器指定的入口
```

UUU直接使用的文件不是SDK，也不是普通M7 ELF，而是符合i.MX启动格式的`flash.bin`。`flash.bin`中需要哪些部分取决于启动目标：

- 只进行M7低功耗启动测试时，需要芯片启动所需的安全容器、匹配的M33 System Manager和M7镜像。
- 启动完整A55 Linux时，还需要DDR初始化、SPL、U-Boot及后续系统镜像。
- 写入eMMC时，UUU脚本还要进入后续下载或Fastboot阶段，并包含明确的`FB: flash`等写入命令。

官方Pro镜像来自NXP下载的：

```text
LF_v6.18.2-1.0.0_images_IMX95.zip
```

内部文件为：

```text
imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55
```

该文件是FRDM-IMX95-PRO的A55启动镜像，包含原厂启动容器、DDR初始化、System Manager、SPL和U-Boot等组件。使用它执行第一阶段`SDPS: boot`后，COM17出现了：

```text
U-Boot SPL 2025.04...
Trying to boot from USB SDP
SDP: initialize...
SDP: handle requests...
```

这证明官方Pro镜像被Boot ROM接受并且SPL已经运行。由于测试脚本只有第一条`SDPS: boot`，没有继续执行SDPV写入、跳转或Fastboot阶段，所以SPL停在等待后续数据。该结果不是M7已经运行，也不是完整Linux已经通过USB启动。

当前自制文件：

```text
flash-sm-m7-freertos-hello.bin
```

是使用`imx-mkimage`按容器格式重新生成的，不是简单拼接。其来源包括：

1. 从官方Pro `flash_a55`保留或提取与芯片启动匹配的ELE、AHAB和平台容器内容。
2. 用与BSP版本匹配的`imx-sm`和`mx95frdm-pro.cfg`编译M33 System Manager。
3. 将SDK编译的M7 BIN或BSP自带的M7 `hello_world.bin`作为M7镜像。
4. 通过`imx-mkimage`写入核心类型、装载地址、入口地址、长度和哈希。

修改ROM容器的原因是官方`flash_a55`面向A55 Linux启动，并没有按当前目标直接包含要测试的M7程序。要让Boot ROM和System Manager在启动阶段装载M7，需要重新生成包含M33和M7描述的容器。不能在原文件尾部随意追加M7 BIN，因为Boot ROM依据容器头和镜像描述查找、校验和装载每个镜像。

当前USB方式未成功的现象有两类：

- 自制镜像传输到100%后芯片复位并重新枚举，说明镜像已传输但启动阶段失败。
- 后续官方M7对照镜像出现`LIBUSB_ERROR_PIPE`，说明该次在USB传输阶段已经失败，尚不能判断M7内容。

截至该次排查时，尚未找到经过实机验证、可直接让FRDM-IMX95-PRO启动M7的完整`flash.bin`。已有正确候选组件，但当时的自制容器还没有通过实机启动验证。该结论已被后续2026-09-11的M7 UART成功和2026-09-14的GPIO成功验证更新。

解决办法是先取得NXP或项目组已经验证的Pro版M7启动镜像和配套UUU脚本作为基准。若没有现成镜像，则以官方Pro `flash_a55`为工作基准，使用对应版本的`imx-sm`、`imx-mkimage`和官方构建目标生成完整镜像，而不是手工裁剪容器。先用`SDPS: boot`进行RAM验证，成功后再制作SD卡或eMMC写入流程。

### 第三种：Linux remoteproc

Linux启动后，remoteproc框架读取`/lib/firmware`中的M7 ELF，根据ELF程序头取得各程序段的目标地址，把代码和数据加载到M7的TCM或预留内存，再通过i.MX remoteproc驱动向System Manager请求设置入口、解除复位并启动M7。

System Manager是运行在Cortex-M33上的系统管理固件。M33是运行System Manager的核心，但不能把M33核心和System Manager软件完全等同。System Manager负责电源、时钟、复位、引脚、逻辑机器和资源权限等平台管理工作。

remoteproc使用的是ELF而不是裸BIN，因为ELF包含：

- 不同程序段的数据
- 每个程序段的目标地址
- 入口地址
- 段属性
- 可选的资源表

当前板载Linux中已经找到可用候选文件：

```text
/lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.elf
```

因此不是缺少ELF。实际失败发生在控制M7时：

```text
lmm(1) not under Linux Control
Boot failed: -13
```

当前System Manager配置把M7分配给LM1，把A55/Linux分配给LM2，LM2没有控制LM1的权限。因此Linux能选择和读取ELF，但不能请求System Manager启动M7。

解决办法有两种：

1. 修改`mx95frdm-pro.cfg`中的逻辑机器关系，使A55所在LM拥有M7所在LM的控制权限，重新编译System Manager并重新制作启动镜像。先从USB或SD卡启动该新镜像，再验证remoteproc状态能否变为`running`。
2. 不使用Linux动态启动M7，而是在启动容器中直接包含并启动M7。这样M7随系统启动，Linux只与其通信，不负责运行时启动。

当前remoteproc所需的M7 ELF已经找到，但缺少经过验证且允许Linux控制M7的System Manager启动配置。因此文件层面基本具备，平台权限层面尚未解决。

### 三条路线当前结论和优先级

| 方式 | 正确文件是否已有 | 失败点 | 解决方案 | 优先级 |
| --- | --- | --- | --- | --- |
| J-Link | 有IAR输出的OUT/ELF候选 | 缺少调试器和物理连接 | 获取J-Link和TP测试夹具，核对Pro板初始化 | 暂停 |
| USB加UUU | 有官方Pro A55基准镜像；M7自制容器未验证 | 自制容器启动复位，部分测试有USB PIPE错误 | 获取官方Pro M7镜像，或按官方目标重建完整容器 | 当前主线 |
| Linux remoteproc | 板载M7 ELF已存在 | System Manager的LMM权限拒绝 | 修改LM控制关系并更新System Manager启动镜像 | 第二主线 |

近期最有效的外部资料需求不是再要一个单独FreeRTOS BIN，而是向NXP或项目组索要以下任一项：

```text
FRDM-IMX95-PRO已验证的M7启动flash.bin和UUU脚本
FRDM-IMX95-PRO可由Linux remoteproc控制M7的System Manager配置
FRDM-IMX95-PRO对应的完整MCUXpresso SDK或板级补丁
官方M7启动构建命令、版本组合和串口映射说明
```

## 2026-09-14 板载M7固件分析

通过网线直连开发板，开发板的`eth0`获取了IPv6链路本地地址，Windows可以Ping通，MobaXterm和PowerShell都可以通过SSH登录。说明网线、Linux网络和SSH服务正常。

板载`/lib/firmware`中存在多组19x19平台的M7固件。普通的`hello_world`是裸机示例，`rpmsg_lite_pingpong_rtos_linux_remote`和`rpmsg_lite_str_echo_rtos`是FreeRTOS示例。对这两组ELF执行`strings`，可以看到`tasks.c`、`xTaskCreate`、`vTaskStartScheduler`、队列和`rpmsg`等内容，因此已经确认厂家系统中预置了M7 FreeRTOS程序。

系统还把19x19平台的M7 BIN保存到了启动分区：

```text
/run/media/boot-mmcblk0p1/mcore-demos
```

`/usr/lib/firmware/imx/ele/`中的AHAB/ELE镜像属于芯片安全启动和系统启动组件，不是FreeRTOS应用，但生成完整启动容器时需要使用对应版本的启动组件。

## 2026-09-14 SSH取文件与烧写主线

SSH用于登录A55上的Linux，SCP和SFTP用于在电脑与Linux文件系统之间传输文件。传输板载M7固件只能说明文件被复制出来，不能说明M7已经启动，也不能说明文件已经写入eMMC。当前先保存官方FreeRTOS候选ELF和BIN，记录哈希，再进行启动验证。

板载官方FreeRTOS固件的验证顺序：

1. 查看`rpmsg_lite_pingpong_rtos_linux_remote.elf`和`rpmsg_lite_str_echo_rtos.elf`的文件大小、哈希和ELF信息。
2. 通过Linux `remoteproc1`加载官方ELF。
3. 观察`dmesg`、COM18和remoteproc状态。
4. 如果仍然出现`lmm(1) not under Linux Control`，说明官方固件已经被找到，但当前System Manager不允许Linux控制M7。
5. 再将官方FreeRTOS BIN放入匹配的i.MX95启动容器，通过J7和UUU验证启动。

电脑中的`freertos_hello.bin`是使用SDK重新编译生成的FreeRTOS程序，板载的`rpmsg_lite_*_rtos*`是厂家随Linux BSP预置的FreeRTOS程序。两者都可以用于学习，但应先验证厂家预置程序，再研究自己编译程序与板载程序的差异。

## 2026-09-14 官方资料核对与验收目标

本阶段使用的官方资料：

- `UM12527`：FRDM-IMX95-PRO板卡接口、启动开关和硬件说明。
- `FRDMIMX95PROQSG`：Pro板第一次上电和基本连接。
- `AN14748`：i.MX95 M7程序编译、生成`flash.bin`以及使用UUU写入SD或eMMC。
- `AN14120`：使用VS Code和调试器调试i.MX系列Cortex-M程序。
- SDK示例`readme.md`和`example_board_readme.md`：示例功能、准备步骤、运行现象和测试方法。
- `imx-sm`文档：System Manager配置、逻辑机、资源分配和启动容器。

AN14120属于调试流程。i.MX95的串行下载调试方式需要MCU-Link、LinkServer和Secure Provisioning Tool；当前Pro板没有标准JTAG插座，也没有MCU-Link，因此暂时不作为本阶段烧写验证方式。AN14748的`flash.bin + UUU + SD/eMMC`作为当前主线。

当前四项目标和状态：

| 目标            | 当前状态                 | 完成标准                              |
| ------------- | -------------------- | --------------------------------- |
| 熟悉开发板和下载资料    | 基本完成                 | 能说明供电、串口、USB下载、启动开关和三种下载方式        |
| 熟悉芯片资源和开发工具   | 基本完成                 | 能说明A55、M7、M33分工及IAR、SDK、BSP、UUU作用 |
| 编译FreeRTOS并烧写 | 编译、USB RAM启动和SD卡持久化启动完成 | 编译无错误，M7实际运行，断电后从SD自动启动；未覆盖eMMC |
| 测试串口和GPIO     | 已完成 | COM18串口收发通过；GPIO2_IO14输出、GPIO2_IO15输入和物理回环通过 |

串口和GPIO目标已完成。2026-09-15先解决了错误SM资源划分导致的LM2/A55 WDOG3超时，随后通过NXP匹配版本BL31源码定位SD模式GPIO失效的最终原因。M7 GPIO验证使用了寄存器状态、物理回环和逻辑分析仪波形，不是Linux侧GPIO测试。

## 2026-09-15 SD卡持久化启动结果

使用UUU内置`sd`流程写入前，先确认官方Pro启动镜像中的`sd_dev=1`、`mmcdev=1`，并与实机U-Boot的`mmc 0=eMMC`、`mmc 1=SD`对应。UUU先通过SDPV加载官方`imx-boot-imx95-19x19-lpddr5-frdm-pro-sd.bin-flash_a55`进入Fastboot，然后执行：

```text
FB: ucmd setenv fastboot_dev mmc
FB: ucmd setenv mmcdev ${sd_dev}
FB: ucmd mmc dev ${sd_dev}
    FB: flash bootloader flash-m7-gpio-reclaim.bin
FB: Done
```

所有命令返回`Okay`，UUU退出码为0。该操作只选择`mmc 1`，没有写eMMC。

断电后将SW4设置为`ON、OFF、ON、ON`并从SD重新启动，不再运行UUU。COM18自动输出`M7 FreeRTOS UART echo ready`和GPIO任务；COM19正常完成DDR OEI并启动SM；COM17的A55 SPL和U-Boot正常运行。由此确认自定义启动容器已经写入SD，并能在掉电后自动启动M7 FreeRTOS、M33 SM和A55 U-Boot链。

最终写入SD启动区的文件为`flash-m7-gpio-reclaim.bin`，SHA256为`1BCBA278F852169332DD7BFF24571C143A933FDF7FE8C3D435B9B3119ACC4D08`。SD重启后`PCNS=PCNP=FFFF3FFF`，`PDOR`在`0/00004000`之间翻转；J15-8与J15-10连接后，`IN`在`0/1`之间与`OUT`同步，逻辑分析仪确认GPIO14有波形。

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md|FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程]]
- [[10-项目/FRDM-IMX95-PRO/理解-i.MX95启动与资源隔离.md|理解-i.MX95启动与资源隔离]]
