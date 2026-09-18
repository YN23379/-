---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 怎么做
status: 已整理
evidence: 实机验证
tags: [多核与异构, 编译构建, 存储]
updated: 2026-09-17
---

# i.MX95官方启动配置与ELE文件

## 一、官方为什么能启动M7

厂家提供的M7 FreeRTOS ELF和BIN是M7应用固件，已经和对应的源码、链接地址、TCM布局及外设配置配套。它能否启动，还取决于System Manager采用哪种启动方案。

常见方案有两种：

1. 启动容器在上电阶段直接包含M7 BIN，由Boot ROM和System Manager完成初始化后释放M7。
2. Linux启动后使用remoteproc加载M7 ELF，再通过System Manager请求复位、设置入口和启动M7。

当前Pro板的出厂配置中，M7和A55属于不同的Logical Machine。Pro配置中M7侧有`LMM_2 ALL`，A55侧只有`LMM_1 NOTIFY`。`NOTIFY`是通知权限，不等于控制权限，所以Linux remoteproc报`lmm(1) not under Linux Control`是当前配置的结果。

源码中还存在`mx95evkrpmsg.cfg`，A55部分包含`CPU_M7P ALL`和`LMM_1 ALL`。这说明NXP提供了允许Linux参与M7控制的配置思路，但这是EVK RPMsg配置，不能直接替换FRDM-IMX95-PRO配置，必须保留Pro板的引脚、外设和内存分配，再按需要调整控制权限。

因此，厂家给了FreeRTOS示例并不矛盾。示例可以由启动容器自动启动，也可以在使用合适的LMM权限配置后由remoteproc动态启动。当前出厂System Manager选择的是隔离方案，不代表M7固件不能运行。

## 二、ELE和AHAB文件

板载`/usr/lib/firmware/imx/ele/`中的：

```text
mx95a0runtime-ahab-container.img
mx95b0-ahab-container.img
mx95b0runtime-ahab-container.img
```

属于ELE/AHAB安全启动相关文件，作用是配合芯片Boot ROM完成启动认证、安全服务和运行时安全功能。它们不是M7 FreeRTOS应用，也不能单独作为M7烧写文件。

文件中的`a0`和`b0`通常对应芯片修订版本，`runtime`表示运行时使用的容器或固件。具体选哪个必须以芯片版本、BSP版本和`imx-mkimage`构建规则为准，不能只按文件名替换。

`sof-zephyr-gcc`等目录中的文件属于其他组件或工具链资源。判断是否使用时，先看文件被哪个构建脚本引用、加载到哪个核心和地址，再决定是否加入启动镜像。目录中有BIN或ELF，不代表它就是M7启动所需文件。

## 三、当前烧写主线

当前已经从板载系统取出官方FreeRTOS候选文件：

```text
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_pingpong_rtos_linux_remote.bin
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.elf
imx95-19x19-evk_m7_TCM_rpmsg_lite_str_echo_rtos.bin
```

正确顺序是：

1. 保存官方ELF和BIN并记录哈希。
2. 先用官方ELF尝试remoteproc，确认失败是否仍为LMM控制权限。
3. 使用Pro板的原厂启动组件和ELE/AHAB文件作为基础。
4. 将官方FreeRTOS BIN加入启动容器，不能把BIN直接当成完整`flash.bin`。
5. 用J7进入USB Serial Downloader，通过UUU执行`SDPS: boot`临时启动。
6. COM18看到M7 FreeRTOS输出后，再研究UUU写入eMMC或SD卡。

`SDPS: boot`是把启动容器传给Boot ROM并运行，主要用于验证；`FB: flash`等命令才是向eMMC或其他存储介质写入。当前先验证启动容器，避免直接覆盖出厂eMMC。

## 四、2026-09-14官方资料核对结果

前面把修改LMM控制权限列为优先方向并不准确。核对NXP官方应用笔记AN14748、System Manager开发文档和SDK示例说明后，官方运行M7示例的主流程是将M7 BIN加入启动容器，由System Manager在启动阶段启动M7，不要求先由Linux remoteproc动态启动。

AN14748给出的流程为：

1. 编译M7示例，得到M7 BIN。
2. 将M7 BIN复制到`imx-boot/iMX95`并命名为`m7_image.bin`。
3. 执行`make SOC=iMX95 REV=B0 flash_all LPDDR_TYPE=lpddr5 OEI=YES`。
4. 得到`iMX95/flash.bin`。
5. 使用UUU的`uuu -b sd flash.bin`或`uuu -b emmc flash.bin`写入启动介质。
6. 从对应启动介质重新启动板子，M7在启动阶段运行。

SDK中`rpmsg_lite_str_echo_rtos`和`rpmsg_lite_pingpong_rtos_linux`的板级说明同样要求先制作并烧入`flash.bin`，然后启动Linux。M7终端先显示FreeRTOS示例信息，Linux再加载`imx_rpmsg_tty`或`imx_rpmsg_pingpong`模块进行核间通信。

因此，当前`remoteproc`的LMM错误只说明出厂System Manager不支持Linux在运行后动态启动M7，不能据此判断官方FreeRTOS示例无法使用。对于当前任务，先使用官方M7 BIN制作启动容器更加符合官方说明。

## 五、配置文件依据

`mx95frdm-pro.cfg`位于电脑上的NXP `imx-sm`源码仓库：

```text
F:\project\Learning\RTOS\tools\imx-sm\configs\other\mx95frdm-pro.cfg
```

它不是板载Linux的即时配置文件，而是生成System Manager配置头文件和编译M33固件时使用的输入文件。NXP System Manager发布说明明确记录了该文件用于FRDM-IMX95-PRO，并给出：

```text
make config=mx95frdm-pro cfg
make config=mx95frdm-pro all
```

修改该CFG后必须重新生成配置、编译`m33_image.bin`、重新制作启动容器并重启板子才能生效。不能直接修改一行后影响当前运行中的System Manager。

`mx95evkrpmsg.cfg`位于同一目录。文件中的A55 API配置确实包含：

```text
CPU_M7P             ALL
LMM_1               ALL
```

这是本地NXP源码文件中的实际内容，不是推测。但它针对EVK RPMsg场景，不是FRDM-IMX95-PRO官方配置，因此目前只用来解释不同LMM方案，不直接替换Pro配置。

## 六、当前执行顺序

1. 保留出厂eMMC，不先修改LMM配置。
2. 使用板载官方19x19 FreeRTOS BIN作为`m7_image.bin`。
3. 使用Pro板对应的System Manager和启动组件生成包含A55与M7的`flash.bin`。
4. 先通过J7和UUU执行RAM临时启动，观察M7和A55输出。
5. 验证成功后优先写入SD卡，从SD卡启动验证持久化。
6. 最后根据项目需要决定是否写入eMMC。

只有项目明确要求Linux运行后反复停止、切换和启动不同M7 ELF时，才需要继续研究remoteproc和LMM控制权限。

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/芯片与平台-i.MX95/启动与烧录/STM32与i.MX95启动和开发流程对比.md|STM32与i.MX95启动和开发流程对比]]
- [[20-领域/芯片与平台-i.MX95/启动与烧录/SDK、BSP与调试下载接口.md|SDK、BSP与调试下载接口]]

**相关主题**

- [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95多核与程序启动]]
- [[20-领域/芯片与平台-i.MX95/i.MX95时钟-IOMUX与板级串口选择方法.md|i.MX95时钟-IOMUX与板级串口选择方法]]
