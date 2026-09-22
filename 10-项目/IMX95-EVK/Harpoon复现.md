---
type: 项目档案
scope: i.MX95 19x19 LPDDR5 EVK（IMX95LPD5EVK-19）
doc_type: 教程
status: 已整理
evidence: 实机验证
tags:
  - Harpoon
  - Jailhouse
  - 启动
  - 多核与异构
  - 存储
updated: 2026-09-22
---

# Harpoon 复现操作手册（IMX95-EVK 版）

> **本文只讲"手怎么动"**：每一步在哪台机器上做、敲什么、屏幕上会出现什么、做完接着做第几步。
> "为什么这样设计"放在最后第八部分，先不用看。
>
> 三个操作环境的标记，认准它就不会走错地方：
>
> | 标记 | 在哪 | 提示符 |
> |---|---|---|
> | **[电脑]** | 你的 Windows 笔记本 | `PS F:\...>` |
> | **[板子-U-Boot]** | 板子的引导程序（Linux 还没起来） | `u-boot=>` |
> | **[板子-Linux]** | 板子里已经跑起来的 Linux | `root@imx95-19x19-lpddr5-evk:~#` |
>
> **2026-09-22 实机跑通**：FreeRTOS 在 A55 CPU5 上运行，COM9 输出 `Hello world.` + `tic tac`。
>
> 与 Pro 板版本的差别见第十部分。**Pro 板那份流程在 EVK 上不能照抄**，原因在第八部分。

---

## 第一部分：开始前必须知道的 3 件事（5 分钟看完）

### 1. ★ 必须用 SD 卡上的 Real-Time Edge 系统，不能用原厂 eMMC 系统

**这是整件事最关键的一条，也是 EVK 和 Pro 板最大的不同。**

| | 原厂 eMMC 系统 | **SD 卡上的 RTE 系统** |
|---|---|---|
| 系统 | `NXP i.MX Release Distro 6.12-walnascar` | **`NXP Real-time Edge Distro 3.3`** |
| 内核 | `6.12.34-lts-next` | **`6.12.34-rt11-lts-next`** |
| jailhouse | `v0.12 (387-g7b9bbf71-dirty)` | **`v0.12 (388-gf64de0b8-dirty)`** |
| **LPUART3 能否从 A55 域访问** | ❌ **不能**（读寄存器触发 SIGBUS） | ✅ **能**（`VERID = 0x04040007`） |
| harpoon DTB | ❌ 缺 `imx95-19x19-evk-harpoon.dtb` | ✅ 有 |
| harpoon 应用 | ❌ 完全没有 | ✅ cell / inmate / harpoon_ctrl 齐全 |
| 结果 | FreeRTOS 跑起来但**看不到任何输出** | ✅ **正常输出** |

**原因**：Harpoon 需要一份**定制的 SM 配置**，它会把 LPUART3 的访问权划给 A55 域。原厂 eMMC 系统的 SM 配置把 LPUART3 给了 M7，A55 域上的 inmate 一写串口就撞总线错误。RTE 系统带的就是那份定制配置。

**所以：不要在原厂 eMMC 系统上折腾**。Pro 板时期在这上面花了大量时间，最后证明是 SM 配置的根本差异，不是操作问题。

### 2. 整个流程分两大轮

```text
第一轮：把 RTE 系统写进 SD 卡        ← 用 UUU，不动 eMMC
    ↓
第二轮：从 SD 启动，跑 FreeRTOS       ← U-Boot 设参数 + Linux 里跑 jailhouse
```

**eMMC 里的原厂系统一个字节都不动**，写坏了拔卡就恢复。

### 3. 什么会丢，什么不会丢

| 东西 | 断电后 | 为什么 |
|---|---|---|
| SD 卡上的 RTE 系统 | **还在** | 写进 SD 卡了 |
| eMMC 上的原厂系统 | **还在** | 没碰过 |
| U-Boot 里 `setenv` 的参数 | **丢** | 没 `saveenv`，只改内存 |
| 加载的 cell 和 inmate | **丢** | 只在内存里 |
| `/tmp` 里的文件 | **丢** | `/tmp` 是 tmpfs（内存盘） |

**结论**：写卡做一次就够；但**每次要跑 FreeRTOS，都得重走"重启 → U-Boot 设参数 → Linux 启用 jailhouse"**。

---

## 第二部分：准备工作

### 硬件

| 东西 | 接在哪 | 说明 |
|---|---|---|
| 电源 | **J5**（9-pin DC，12V/13.33A/160W） | 只用原装适配器 |
| 电源开关 | **SW4** | ⚠️ **EVK 的 SW4 是电源开关**，启动开关是 SW7 |
| 串口线 | **J31**（USB Type-C） | FT4232H 桥，电脑上出 4 个 COM 口 |
| USB 数据线 | **J8**（USB Type-C） | 写 SD 卡时用（走 USB1 控制器） |
| SD 卡 | 板子上的 MicroSD 槽 | **32 GB 够用** |
| 散热片 | SOM 上 | **必须装**，A55 满载发热不小 |

### 串口

**同时开这几个**，参数 115200-8-N-1：

| COM（本机实测） | 内容 | 对应 SoC 串口 | 用途 |
|---|---|---|---|
| **COM7** | Linux 控制台 | **UART1** | 看系统启动、登录 |
| **COM8** | `Hello from SM` / SM 调试监视器 | **UART2** | 看 M33 |
| **COM9** | M7 菜单 / **FreeRTOS 输出** | **UART3** | ★ **inmate 控制台在这里** |
| COM6 | **什么都没有** | — | **I2C 通道，不是串口，永远没输出** |

> **COM 号不固定**，换 USB 口或换电脑都会变。按输出内容认。
>
> **COM6 别盯着看**——FT4232H 的 Channel B 是板上 I2C 主控，不是串口。Pro 板时期就在这里浪费过时间。

---

## 第三部分：第一轮 —— 把 RTE 系统写进 SD 卡

### 原理

用 **UUU 的内置 `sd_all` 脚本**，通过板子的 USB 把镜像写进 SD 卡。

**不需要读卡器**——`uuu -b sd_all` 会先给板子送一个临时的 U-Boot 进内存，跑起来进 Fastboot，然后把镜像写到 SD 槽。

脚本内容（`uuu.exe -bshow sd_all` 打印）：

```text
SDPS: boot -f _flash.bin           ← 送临时 U-Boot 进内存
FB: ucmd setenv mmcdev ${sd_dev}   ← 把 mmcdev 设成 SD 槽
FB: ucmd mmc dev ${sd_dev}
FB: flash -raw2sparse all _image   ← 写 wic 镜像
FB: flash bootloader _flash.bin    ← 写引导程序
FB: done
```

`sd_dev` 在 U-Boot 源码里是 `1`（`imx95_evk.env:9`），而 `mmc 0` 是 eMMC、`mmc 1` 是 SD，**所以不会误写到 eMMC**。

### 要用的两个文件

```
F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK\real-time-edge\

  nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.wic.zst    1.80 GB   ← 系统本体
  imx-boot-imx95-19x19-lpddr5-evk-sd.bin-flash_a55                  2.85 MB   ← 引导程序
```

**不要用 `flash_all`**（2.89 MB），那是 A55+M7 双核版；跑 Harpoon 用 `flash_a55`。

### 第 1 步：断电，拨 SW7 到 USB 串行下载

```
SW7[1-4] = x001        ← 1 = ON，0 = OFF
```

### 第 2 步：接 USB 线到 J8，上电

**[电脑]** 确认 UUU 认到设备：

```powershell
cd F:\project\Learning\RTOS
.\tools\uuu-1.5.243\uuu.exe -lsusb
```

**屏幕上应该看到**：

```
Chip: MX95
Pro:  SDPS
Vid:  0x1FC9
Pid:  0x015D
```

**看不到**：检查 SW7、USB 线是不是数据线、是否真的冷复位过（要断电重上电，不能只按复位键）。

### 第 3 步：写卡

**[电脑]** **SD 卡保持在槽里**，执行：

```powershell
cd F:\project\Learning\RTOS
.\tools\uuu-1.5.243\uuu.exe -b sd_all `
  ".\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK\real-time-edge\imx-boot-imx95-19x19-lpddr5-evk-sd.bin-flash_a55" `
  ".\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK\real-time-edge\nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.wic.zst"
```

**屏幕上会滚很多行**：

```
Starting download of 16776244 bytes
downloading of 16776244 bytes finished
writing to partition 'all'
sparse flash target is mmc:1
Flashing sparse image at offset 0
........ wrote 16776192 bytes to 'all'
```

这是按 16 MB 分块写镜像的过程。**1.8 GB 压缩、解压后约 11 GB，要写 700 块左右，耗时几分钟到十几分钟。**

> ⚠️ **中途不要动板子、不要拔线。** 写卡被中断会导致 rootfs 分区不完整，启动时内核 panic。

**怎么判断写完**：最后出现 `Done`，或者命令正常返回（退出码 0）。

> ⚠️ **如果看到 `status: -108 ep 'ep1in' trans: 0` 然后掉回 `u-boot=>`**，说明 USB 传输被中断了。**必须重跑一次**。这个现象本项目遇到过：启动区在最前面先写完、rootfs 在后面写一半断了，结果从 SD 启动时内核报 `Unable to mount root fs on "/dev/mmcblk1p2"` 并 panic。

### 第 4 步：断电，拨 SW7 到 SD 启动

```
SW7[1-4] = x011
```

拔掉 J8 的 USB 线（不是必须，但避免混淆）。

**做完你人在**：板子断电，SD 卡插着，SW7 是 `x011`。接着做第二轮。

---

## 第四部分：第二轮 —— 从 SD 启动并验证

### 第 5 步：上电，看 COM7

**[板子]** 打开 SW4 电源开关。

**[电脑]** COM7 上应该看到：

```text
U-Boot SPL 2025.04-g4399e3827163 (Nov 27 2025 - 03:55:23 +0000)
Trying to boot from MMC2              ← MMC2 = SD
Boot stage: Primary
NOTICE:  BL31: v2.12.0(release):lf-6.12.34-2.1.0-dirty
U-Boot 2025.04-g4399e3827163
Model: NXP i.MX95 19X19 board
DRAM:  15.8 GiB
...
Starting kernel ...
Linux version 6.12.34-rt11-lts-next   ← RTE 内核
...
NXP Real-time Edge Distro 3.3 imx95-19x19-lpddr5-evk ttyLP0
imx95-19x19-lpddr5-evk login:
```

**看到 `Real-time Edge Distro 3.3` 就对了。**

> `Weston` 启动失败（`[FAILED] Failed to start Weston`）是**正常的**——需要显示器。不影响串口登录。
>
> 串口上时不时冒出的 `audit: type=1006 ... sshd-session` 是**每次 SSH 登录写的审计记录**，正常现象。

### 第 6 步：登录

**[板子-Linux]** 在 `login:` 输入 `root`（无密码）。

### 第 7 步：确认 harpoon 资产齐全

```bash
ls /usr/share/jailhouse/cells/ | grep imx95-harpoon
ls /usr/share/harpoon/inmates/freertos/
ls /run/media/boot-mmcblk1p1/ | grep harpoon
```

**应该看到**：

```text
imx95-harpoon-freertos.cell
imx95-harpoon-freertos-industrial.cell
imx95-harpoon-zephyr.cell

hello_world.bin   rt_latency.bin   industrial.bin

imx95-19x19-evk-harpoon.dtb
imx95-19x19-evk-harpoon-industrial.dtb
```

### 第 8 步：重启，在 U-Boot 里让出内存

**这一步必须做。** 不做的话 Linux 会占满 15.8 GB，`jailhouse enable` 会把 Linux 正在用的内存覆盖掉。

**[板子]** 断电重启，在 U-Boot 提示符（**只有 2 秒**）执行：

```text
u-boot=> setenv jh_root_dtb imx95-19x19-evk-harpoon.dtb
u-boot=> run jh_mmcboot
```

**`jh_mmcboot` 这个宏干的事**（`imx95_evk.env:33-38`）：

```make
jh_mmcboot=setenv fdtfile ${jh_root_dtb};
	setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe;
	setenv jh_root_mem 0x58000000@0x90000000,0x300000000@0x180000000;
	if run loadimage; then
		run mmcboot;
	else run jh_netboot; fi;
```

**它会自动设好 `jh_clk` 和 `jh_root_mem`，不用手敲。**

> **抢不到提示符**：autoboot 只有 2 秒，必须**先开始按回车再上电**。
> **只用回车（CR），不要用 Ctrl-C**——Ctrl-C 会杀死串口登录服务，之后提示符永久消失，看起来像板子挂了。

### 第 9 步：验证内存真的让出来了

```bash
grep MemTotal /proc/meminfo
cat /proc/cmdline
```

**屏幕上应该看到**：

```text
MemTotal:       13651328 kB          ← 13.02 GB

kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe console=ttyLP0,115200 earlycon root=/dev/mmcblk1p2 rootwait rw
```

**两条都要对**：

| 检查 | 正常值 | 不对的话 |
|---|---|---|
| `MemTotal` | **明显小于 15 GB**（约 13 GB） | `jh_root_mem` 没生效，**停手**，不要往下走 |
| `cmdline` | 含 `kvm-arm.mode=nvhe` 等 | `jh_clk` 没生效 |

**为什么必须小于 15 GB**：Jailhouse 要两块空闲内存（inmate 区 247 MB + hypervisor 区 4 MB），`jh_root_mem` 通过改设备树 `/memory` 节点让 Linux "看不见"这两块。Linux 还占着的话，hypervisor 会覆盖它的数据。

> **内存账**：普通启动 15.35 GB → 设了参数后 13.02 GB，让出约 2.3 GB。让出量比实际需要的大很多，因为内存是按内存条整块让的，不能细粒度切。

**做完你人在**：板子的 Linux 里，内存已经让好。接着跑 FreeRTOS。

---

## 第五部分：把 FreeRTOS 跑起来

### 第 10 步：启用 hypervisor

```bash
modprobe jailhouse
jailhouse enable /usr/share/jailhouse/cells/imx95.cell
```

**屏幕上应该看到**：

```text
Initializing Jailhouse hypervisor v0.12 (388-gf64de0b8-dirty) on CPU 5
Code location: 0x0000ffffc0200800
Page pool usage after early setup: mem 71/993, remap 0/131072
Initializing processors:
 CPU 5... OK
 CPU 2... OK
 CPU 0... OK
 CPU 1... OK
 CPU 4... OK
 CPU 3... OK
Initializing unit: irqchip
Initializing unit: ARM SMMU v3
Initializing unit: ARM SMMU
Initializing unit: PVU IOMMU
Initializing unit: PCI
Adding virtual PCI device 00:00.0 to cell "imx95"
Adding virtual PCI device 00:01.0 to cell "imx95"
Adding virtual PCI device 00:02.0 to cell "imx95"
Adding virtual PCI device 00:03.0 to cell "imx95"
Page pool usage after late setup: mem 125/993, remap 208/131072
Activating hypervisor
```

> ⚠️ **不要被"看起来卡住"骗了。** 之后内核会打印十几行新虚拟 PCI 总线的消息，把提示符淹没在中间：
>
> ```text
> Activating hypervisor
> [   56.231532] pci-host-generic ff700000.pci: host bridge /pci@0 ranges:
> root@imx95-19x19[   56.231825] pci_bus 0004:00: root bus resource ...
> -lpddr5-evk:~# [   56.231858] pci 0004:00:00.0: ...
> ...
> [   56.246035] The Jailhouse is opening.
> ```
>
> **时间戳说明 `jailhouse enable` 早就返回了**（提示符在 56.231825，而最后那条日志是 56.246035，晚 14 毫秒）。
>
> **正确判断方法**：直接跑 `jailhouse cell list`，能列出 root cell 就说明成功了。**不要盯着串口等提示符。**

### 第 11 步：创建 cell

```bash
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
```

**屏幕上应该看到**：

```text
Adding virtual PCI device 00:00.0 to cell "freertos"
Shared memory connection established, peer cells:
 "imx95"
Created cell "freertos"
Page pool usage after cell creation: mem 148/993, remap 208/131072
```

**这一步做的事**：按 cell 文件划出资源容器（CPU5、16 MB 内存、LPUART3 等），里面是空的。

### 第 12 步：装载 inmate

```bash
jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/hello_world.bin -a 0xf0000000
```

**屏幕上应该看到**：`Cell "freertos" can be loaded`

**`-a 0xf0000000` 不能省**：这个 inmate 是**裸 AArch64 机器码，不是 ELF**，没有地址信息，必须手工指定装载地址。

**先用 `hello_world.bin`**，因为官方文档写明了它该打印什么，最容易判断成功。

### 第 13 步：启动

```bash
jailhouse cell start freertos
```

**屏幕上应该看到**：`Started cell "freertos"`

### 第 14 步：★ 切到 COM9 看输出

```bash
jailhouse cell list
```

```text
ID      Name       State      Assigned CPUs
0       imx95      running    0-4
1       freertos   running    5
```

**然后切到 COM9**，应该看到：

```text
INFO hello_func            : Hello world.
tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac
tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac
```

**与官方文档 UG10170 §4.3 的预期输出完全一致。**

> **COM9 上还会有 M7 的菜单**（`Power Mode Switch Task`），因为 **M7 的调试口也是 UART3**。两者输出交织，不影响功能。

### 第 15 步：收工

```bash
jailhouse cell shutdown freertos
jailhouse cell destroy freertos
jailhouse disable
modprobe -r jailhouse
```

或者**直接断电**——`setenv` 没存盘，重启就回到原样（SD 卡上的系统还在）。

---

## 第六部分：实测结果（2026-09-22）

### 最终输出

```
INFO hello_func            : Hello world.
tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac
tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac tic tac
```

### 逐项验证

| 检查项 | 结果 |
|---|---|
| RTE 系统从 SD 启动 | ✅ `NXP Real-time Edge Distro 3.3` |
| `jh_root_mem` 生效 | ✅ `MemTotal: 13651328 kB`（13.02 GB） |
| `jh_clk` 生效 | ✅ `cmdline` 含 `kvm-arm.mode=nvhe` 等 |
| hypervisor | ✅ `v0.12 (388-gf64de0b8-dirty)`，6 个 CPU 全 OK |
| cell 生命周期 | ✅ `Created` → `can be loaded` → `Started` → `running 5` |
| Linux 剩几个核 | ✅ `nproc` = 5 |
| **inmate 输出** | ✅ **COM9 上 `Hello world.` + `tic tac`** |

### 这一轮解决的问题

**FreeRTOS 从"跑起来但看不到输出"变成"跑起来且能看到输出"。**

| | Pro 板 / EVK 原厂 eMMC | **EVK + RTE 系统** |
|---|---|---|
| FreeRTOS 在 CPU5 上跑 | ✅ | ✅ |
| **能看到输出** | ❌ | ✅ |
| 卡在哪 | LPUART3 不归 A55 域 | — |

---

## 第七部分：卡住时的排查表

**先看最后出现的是哪一段**，再对下表。

| 卡在哪 | 现象 | 查什么 |
|---|---|---|
| 写 SD 卡 | `status: -108` 后掉回 `u-boot=>` | **USB 传输中断**，重跑 UUU |
| 写 SD 卡 | `uuu -lsusb` 看不到 `MX95 SDPS` | SW7 是不是 `x001`、USB 线是不是数据线、是否冷复位过 |
| SD 启动 | `Kernel panic - not syncing: VFS: Unable to mount root fs` | **rootfs 没写完**，重跑 UUU |
| SD 启动 | `Trying to boot from MMC2` 之后没有 BL31 | SD 卡启动区没写好 |
| U-Boot | 抢不到提示符 | autoboot 只有 2 秒，**先按回车再上电** |
| U-Boot | 停在 `u-boot=>` 不动，一分多钟后自己重启 | 被看门狗复位，**抢到提示符要立刻操作** |
| 第 9 步 | `MemTotal` 还是 15.35 GB | `jh_root_mem` 没生效，**停手**，检查 `setenv` 和 `jh_mmcboot` |
| 第 10 步 | 看着像卡在 `The Jailhouse is opening.` | **没卡**，提示符被 PCI 消息淹没。跑 `jailhouse cell list` 确认 |
| 第 11 步 | `JAILHOUSE_CELL_CREATE: Device or resource busy` | 已有 cell 占着 CPU5，先 `cell destroy` |
| 第 13 步 | cell `running` 但 COM9 没输出 | **先切到 COM9**（不是 COM6！），再查下面两条 |
| 第 13 步 | COM9 没输出，且 `vmexits` 不涨 | 用 `/dev/mem` 测 LPUART3 能不能访问（见第八部分） |
| 串口 | COM6 永远没输出 | **COM6 是 I2C 通道，不是串口** |
| 串口 | 提示符永久消失 | 之前按过 Ctrl-C 杀死了登录服务，**断电重启** |

---

## 第八部分：原理

### 一句话说清这个方案

Harpoon 方案就是在 Linux 运行的时候，由 Jailhouse 接管硬件资源（CPU 核、内存、外设），把这些资源重新分配和隔离给不同的操作系统，让它们各自独占分到的那部分、并行运行、互不干扰。分配方案写在 cell 文件里，是静态的。

注意主语：接管硬件的是 **Jailhouse 本体**（`jailhouse.ko` 内核模块），`jailhouse` 命令行只是操作界面。

### ★ 为什么必须用 RTE 系统：LPUART3 的归属

**这是整个 EVK 复现的核心问题。**

**现象**：在原厂 eMMC 系统上，FreeRTOS 明明跑起来了（`cell list` 显示 `running 5`），但串口一个字节都没有。

**排查过程**：

**① 受控实验定位——统计在哪一步产生**

销毁 cell 后重做，每步读一次统计：

| 步骤 | `vmexits_total` | `vmexits_mmio` |
|---|---|---|
| `create` 后 | 0 | 0 |
| `load` 后 | 1 | 0 |
| **`start` 后立即** | **1517** | **1515** |
| start + 6 秒 | 1517 | 1515 |

**inmate 确实执行了**（`start` 瞬间 1515 次 MMIO），**然后就静止**。统计冻结说明它**卡在一个不碰 MMIO 的地方**——如果是轮询卡住，统计会一直涨。

**② 对照实验——跑板子自带的 demo**

板子上有一对原厂配好的 cell + inmate：

```bash
jailhouse cell create /usr/share/jailhouse/cells/imx95-inmate-demo.cell
jailhouse cell load inmate-demo /usr/share/jailhouse/inmates/uart-demo.bin
jailhouse cell start inmate-demo
```

**结果：COM7 持续刷 `Hello N from cell!`**

**证明 jailhouse 本身完全正常，问题在 harpoon 那套 cell/inmate。**

**③ 决定性实验——从 Linux 直接读 LPUART3 的寄存器**

```bash
python3 -c "
import mmap, os, struct
f = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
m = mmap.mmap(f, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, offset=0x42570000)
print('LPUART3 VERID = 0x%08x' % struct.unpack_from('<I', m, 0)[0])
"
```

| 系统 | LPUART3 | LPUART1（对照） | LPUART4（对照） |
|---|---|---|---|
| 原厂 eMMC | ❌ **SIGBUS**（退出码 135） | ✅ 可读 | ✅ 可读 |
| **RTE 系统** | ✅ **`0x04040007`** | ✅ 可读 | ✅ 可读 |

内核日志佐证：`audit: ... comm="python3" ... sig=7 res=1`（SIGBUS = 总线错误）

**`mmap` 成功、读的时候才触发总线错误**——这是**总线级的访问拦截**，不是"设备不存在"，也不是 Linux 权限问题。

**④ 根因**

**LPUART3 的寄存器，A55 域根本访问不了。**

对照 SM 配置的资源归属：

| UART | 归谁 | A55 能访问吗 |
|---|---|---|
| LPUART1 | A55（LM2） | ✅ 能 |
| LPUART2 | SM（LM0） | ❌ 不能 |
| **LPUART3** | **M7（LM1）** | ❌ **不能** |
| LPUART4 | A55（LM2） | ✅ 能 |

**Harpoon cell 虽然在 jailhouse 层面把 LPUART3 的 MMIO 划给了 inmate，但硬件层面 A55 域碰不到它。** inmate 一写串口就撞总线错误，异常处理卡住，之后不再产生 MMIO 陷入。

**这也解释了 demo 为什么能跑**——demo 用的是 LPUART1，那是 A55 域自己的。

**⑤ 为什么 RTE 系统能解决**

UG10170 §1.5 原文：

> "Harpoon provides a **custom System Manager configuration** that describes the hardware used for its applications, such as **the TPM and LPUART usage for its guest cell**."

**Harpoon 配套的 SM 配置会把 LPUART3 的访问权划给 A55 域。** 原厂 eMMC 里的是普通 BSP 配置，没做这件事。

**这就是官方流程要求用 RTE 系统的原因。**

### 这个判断方法可以复用

**怎么快速判断某个外设归不归当前域**：从 Linux 用 `/dev/mem` 读它的寄存器。

```bash
python3 -c "
import mmap, os, struct
f = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
m = mmap.mmap(f, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, offset=<物理地址>)
print(hex(struct.unpack_from('<I', m, 0)[0]))
"
```

- **读到正常值，退出码 0** → 当前域能访问
- **SIGBUS，退出码 135** → 当前域不能访问（TRDC/RDC 拦截）

比翻 SM 配置快得多，也不用知道 SM 配置在哪。

### 为什么内存要在启动前让，CPU 和外设不用

Linux 启动时会把内存、CPU、外设全部认领，三者没有本质区别。区别在于**运行期再改的代价不一样**：

- **内存**：已经进了 Linux 的页表，可能已被进程、页缓存、DMA 用着。运行期抽走要先把里面的东西搬走、改页表、通知所有使用方，代价极高。而在 Linux 启动前改设备树，Linux 从建立起就不知道这块内存存在，**不需要任何人配合**。
- **CPU**：核可以停下来。`cell start` 时把某个核从 Linux 调度器里拿走交给 inmate，Linux 只是少一个核，不用搬迁任何数据。
- **外设**：卸载驱动就能交出去。

所以不是内存特殊，而是**内存里装着 Linux 的数据，抽走等于要它搬家**。

### 为什么 A55 只由 SM 放开 CPU0

SM 的启动表里只有 `DEV_SM_CPU_A55C0` 一条，C1~C5 不在启动列表里。

**原因**：多核启动比单核复杂——谁当主核、栈放哪、核间怎么同步、缓存怎么维护，这些 **Linux 自己比 SM 更清楚**。所以约定 SM 只放 CPU0 出去，剩下的由操作系统通过 PSCI 按需叫醒。

**推论**：CPU1~5 本来就是"运行期才被叫醒的资源"，所以在运行期把其中一个"截走"是可行的——这正是 Jailhouse 能在 A55 上切出一个核给 FreeRTOS 的底层前提。

---

## 第九部分：名词表

| 缩写 | 全称 | 在哪一层 | 一句话 |
|---|---|---|---|
| **AON** | Always-ON | 硬件（电源域） | 常开域，复位时不断电。M33 和 Boot ROM 在这里 |
| **SM** | System Manager | 固件 | 跑在 M33 上，分配资源、写隔离规则、放开其它核 |
| **LM** | Logical Machine | 固件（SM 概念） | SM 把"一个核 + 一批资源"打包成一个逻辑机 |
| **TRDC / RDC** | Trusted / Resource Domain Controller | 硬件 | 总线级访问过滤器，按身份判定权限 |
| **LPUART** | Low Power UART | 硬件 | 串口控制器。本板 LPUART1/2/3/4 的归属见第八部分 |
| **SCMI** | System Control and Management Interface | 协议 | 各核与 SM 通信的标准协议 |
| **PSCI** | Power State Coordination Interface | 协议 | 操作系统用它叫醒或关闭 CPU 核 |
| **Jailhouse** | — | 软件（hypervisor） | 静态分区 hypervisor，把硬件资源分给不同 guest |
| **cell** | — | Jailhouse 概念 | 资源容器。**不是操作系统**，里面是空的，装什么由 `load` 决定 |
| **inmate** | — | Jailhouse 概念 | cell 里跑的程序。本项目的 inmate 是 FreeRTOS |
| **root cell** | — | Jailhouse 概念 | 第一个 cell，Linux 就在里面 |
| **RTE** | Real-Time Edge | 软件（发行版） | NXP 的实时发行版，带 Harpoon 定制 SM 配置 |
| **FT4232H** | — | 硬件 | EVK 的 USB 转四路串口桥。通道 A=UART3、B=I2C、C=UART1、D=UART2 |
| **wic** | — | 镜像格式 | 整盘镜像，含分区表 + 各分区内容 |

---

## 第十部分：和 Pro 板那份的差别

| | FRDM-IMX95-PRO | **IMX95-EVK** |
|---|---|---|
| 系统从哪来 | 原厂 eMMC（不支持 Harpoon） | **SD 卡上的 RTE 系统** |
| root DTB | ❌ `imx95-19x19-frdm-pro-root.dtb` 不存在 | ✅ `imx95-19x19-evk-harpoon.dtb` 有 |
| 内存参数 | **必须手工敲** `jh_root_mem` + `jh_clk` | **`jh_mmcboot` 宏自带**，不用敲 |
| `jh_root_mem` 的值 | `0x58000000@0x90000000,0xc0000000@0x180000000` | **`0x58000000@0x90000000,0x300000000@0x180000000`** |
| 启动开关 | SW4[1:4] | **SW7[1:4]**（EVK 的 SW4 是电源开关） |
| 调试口 | J22（CH9114F） | **J31（FT4232H）** |
| inmate 控制台 | LPUART3，**没引出** | **LPUART3 = COM9，引出了** |
| **能不能看到输出** | ❌ | ✅ |

> ⚠️ **两块板的 `jh_root_mem` 值不同**。要手敲时必须用本板的，不能照抄。

---

## 附录：文件与路径

```text
【PC 上】
Harpoon 包        : F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK
UUU               : F:\project\Learning\RTOS\tools\uuu-1.5.243\uuu.exe

【SD 卡上（写卡之后）】
系统              : NXP Real-time Edge Distro 3.3
boot 分区         : /run/media/boot-mmcblk1p1
harpoon cell      : /usr/share/jailhouse/cells/imx95-harpoon-*.cell
harpoon inmate    : /usr/share/harpoon/inmates/freertos/{hello_world,rt_latency,industrial}.bin
控制程序          : /usr/bin/harpoon_ctrl
配置              : /etc/harpoon/harpoon.conf
```

## 相关

- 开发日志（按日期的现场记录）→ [[10-项目/IMX95-EVK/开发日志.md|IMX95-EVK 开发日志]]
- 到手操作计划 → [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划]]
- 上电流程原理（SoC 级，两块板通用）→ [[10-项目/FRDM-IMX95-PRO/上电流程.md|FRDM-IMX95-PRO 上电流程]]
- 启动链原理 → [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95 多核与程序启动]]
- Pro 板那份流程（供对照）→ [[10-项目/FRDM-IMX95-PRO/Harpoon复现.md|FRDM-IMX95-PRO/Harpoon复现]]
