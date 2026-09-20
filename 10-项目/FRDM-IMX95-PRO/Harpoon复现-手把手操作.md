---
type: 项目档案
scope: FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）
doc_type: 教程
status: 已整理
evidence: 实机验证
tags: [Harpoon, Jailhouse, 启动, 多核与异构, i.MX95]
updated: 2026-09-20
---

# Harpoon 复现：手把手操作（照这个敲就行）

> 本文是"照着做"的手册，不是原理总结。每一步都标了**在哪台机器上操作**：
>
> | 标记 | 在哪 | 提示符长什么样 |
> |---|---|---|
> | **[电脑]** | 我的 Windows 笔记本 | `PS F:\...>` |
> | **[板子-U-Boot]** | 板子的引导程序阶段（还没进 Linux） | `u-boot=>` |
> | **[板子-Linux]** | 板子里已经跑起来的 Linux | `root@frdm-imx95:~#` |
>
> 第一部分和第二部分先讲明白"这是在干嘛"，不懂也先读一遍；第三部分才是操作。

---

## 第一部分：Harpoon 到底是什么（说人话）

### 一句话

**Linux 正在用 6 个 A55 核。Harpoon 方案让其中 1 个核"让出来"，单独跑 FreeRTOS，两边同时运行、互不打扰。**

### 三个词，看懂就懂一半

| 词 | 是什么 | 类比 |
|---|---|---|
| **hypervisor** | 一个"硬件二房东"程序。它让 Linux 以为自己独占硬件，实际上硬件归它管，可以再分给别人 | 二房东 |
| **cell** | 一份**资源分配单**，写明"哪个核、哪段内存、哪些外设归谁"。是个二进制配置文件（`.cell`） | 租房合同 |
| **inmate** | 住进 cell 里的程序。这里就是 FreeRTOS 的二进制（`xxx.bin`） | 租客 |

NXP 用的这个"二房东"叫 **Jailhouse**（读音"监狱屋"——它的意思就是把硬件分成一个个"牢房"，各自独立）。

### 两种 cell

| | 给谁用 | 文件 |
|---|---|---|
| **root cell**（根分区） | Linux 自己 | `imx95.cell` |
| **inmate cell**（住客分区） | FreeRTOS | `imx95-harpoon-freertos.cell` |

### 为什么你的 M7 方案不能照搬过来

| | 你的 M7 方案 | Harpoon 方案 |
|---|---|---|
| FreeRTOS 在哪 | M7 核 | A55 的 1 个核 |
| 谁把它启动起来 | **SM**（启动早期，Linux 之前） | **Linux 起来之后**，用 `jailhouse` 命令 |
| FreeRTOS 固件怎么进去的 | 打包进 `flash.bin`，跟着启动容器一起烧 | 用 `scp` 传文件到 Linux 里，运行时加载 |
| 要不要重新烧板子 | 要 | **不用**（板子原厂镜像自带 Jailhouse） |

**一句话记住区别**：M7 的 FreeRTOS 是"**开机就装在楼里的固定住户**"，Harpoon 的 FreeRTOS 是"**楼盖好后临时搬进来的租客**"。

---

## 第二部分：为什么非要在 U-Boot 里敲命令（你最困惑的地方）

### 先搞懂 U-Boot 是什么

板子按下电源后，程序是按这个顺序跑的：

```text
上电 → Boot ROM（固化在芯片里，改不了）
     → U-Boot（板子上的引导程序）      ← 我们要在这里敲命令
     → Linux 内核
     → Linux 用户程序（jailhouse 命令在这里跑）
```

**U-Boot 就是"Linux 的上一棒"**。它干的事：初始化内存 → 把 Linux 内核加载到内存 → **把启动参数传给 Linux** → 跳过去执行。

进 U-Boot 的方法：上电时在串口里不停按回车，就会停在 `u-boot=>` 提示符。**注意 autoboot 只有 2 秒**，慢了就直接进 Linux 了。

### 为什么内存的事非得在 U-Boot 里做

因为 **Linux 一旦启动，就会把板子上的内存全部认下来当自己的**。

等 Linux 起来了再想"哎这块内存你别用了"——晚了，Linux 可能已经把数据放那儿了。

所以必须在 Linux 启动**之前**，通过 U-Boot 告诉它："**你只能用这些内存**"。

### `jh_root_mem` 是干嘛的

```text
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
```

格式是 **`大小@起始地址`**，逗号分隔两块：

| 第几块 | 大小 | 起始地址 | 算出来 |
|---|---|---|---|
| 第一块 | `0x58000000` | `0x90000000` | 1.375 GB，从 2.25GB 开始，到 3.625GB |
| 第二块 | `0xc0000000` | `0x180000000` | 3.0 GB |
| | | | **合计 4.375 GB** |

**含义：Linux（root cell）只准用这两块内存，一共 4.375 GB。**

验证：设完之后 Linux 里的 `MemTotal` 从 15800000 kB 左右掉到 **4398132 kB（4.19 GB）**——和 4.375 GB 基本对上（差的那点是内核自己留的）。

**剩下的内存 Linux 看不到，就是留给 FreeRTOS 用的。** 后面 FreeRTOS 被加载到 `0xf0000000`（3.75GB），这个地址正好在 Linux 第一块内存（到 3.625GB）**之后**——所以 Linux 碰不到它，不会打架。

> 这条推断的依据：`jh_root_mem` 两个数值相加 = 4.375GB，与实测 MemTotal 4.19GB 吻合；
> 且 inmate 入口 0xf0000000 落在 Linux 可用区间之外。现象自洽，但**还没去 U-Boot 源码里逐行确认**，
> 属于"由实测推断"。

### `jh_clk` 是干嘛的

```text
setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
```

这串是**给 Linux 内核的启动参数**（等于平时说的 kernel cmdline），四个参数各有各的用处：

| 参数 | 干嘛的 | 不设会怎样 |
|---|---|---|
| `kvm-arm.mode=nvhe` | 让 Linux 的 KVM 用 NVHE 模式 | 虚拟化硬件被 KVM 占着，Jailhouse 起不来 |
| `kvm.enable_virt_at_load=false` | 加载 KVM 模块时别立刻接管虚拟化硬件 | 同上，两边抢 |
| `cpuidle.off=1` | 关掉 CPU 深度休眠 | 分给 FreeRTOS 的核睡过去了，叫不醒 |
| `clk_ignore_unused` | 别把"没人用"的时钟自动关掉 | 有些外设时钟被关掉，驱动不起来 |

### 这两个变量为什么不 `saveenv` 也能用

`setenv` 只是**改内存里的一份临时配置**，没写进存储（没执行 `saveenv`）。
所以：**断电就恢复原样**，不会把板子搞坏。代价是**每次重启都要重新设一遍**。

这就是为什么复现是"零风险"的——全程不改板子的存储。

---

## 第三部分：手把手操作

### 阶段 0：在电脑上准备要传的文件（5 分钟）

**[电脑]** 这些文件之前已经从 Harpoon 包里抽出来了，确认在：

```text
F:\project\Learning\RTOS\build\rte-extract\
    usr\share\jailhouse\cells\imx95-harpoon-freertos.cell
    usr\share\harpoon\inmates\freertos\hello_world.bin
    usr\share\harpoon\inmates\freertos\rt_latency.bin
```

**为什么**：Harpoon 包里 FreeRTOS 的"住客"和"合同"文件，板子上原厂镜像里没有，得自己传进去。

**看到什么算成功**：三个文件都在，`hello_world.bin` 大约 66KB。

---

### 阶段 1：上电，进 Linux

**[电脑] → 串口** 打开串口终端（MobaXterm 之类），连接参数：

```text
COM17（A55 控制台）  115200  8-N-1
```

**注意**：如果串口打不开报 `Access to the port 'COMxx' is denied`，说明别的软件（MobaXterm 的另一个串口标签页）占着它，先关掉。

板子插好电、串口线接 J22，上电。

**看到什么算成功**：串口滚出一堆启动日志，最后出现 `login:`。

登录：

```text
root
```

（这个板子的 root 没有密码，直接回车）

**为什么**：后面所有 `jailhouse` 命令都要 root 权限。

---

### 阶段 2：让板子联网（好把文件传进去）

**[板子-Linux]** 板子的网口默认是关着的，先拉起来：

```bash
ip link set eth0 up
```

然后看分到的地址：

```bash
ip -brief addr
```

**看到什么算成功**：`eth0` 那行出现类似 `169.254.9.133/16` 的地址。

**为什么**：板子用网线直连电脑网口，两边会自动分配 169.254 开头的"链路本地地址"（不需要路由器）。有了这个地址就能用 `scp` 传文件。

**把这个地址记下来**，下一步要用。

---

### 阶段 3：把文件传到板子

**[电脑]** 新开一个 PowerShell 窗口：

```powershell
cd F:\project\Learning\RTOS\build\rte-extract\usr\share
scp jailhouse\cells\imx95-harpoon-freertos.cell root@169.254.9.133:/tmp/
scp harpoon\inmates\freertos\hello_world.bin harpoon\inmates\freertos\rt_latency.bin root@169.254.9.133:/tmp/
```

（把 `169.254.9.133` 换成你上一步看到的地址）

**为什么**：`scp` 就是"通过 SSH 传文件"。板子的 root 免密，不用输密码。

**[板子-Linux]** 传完之后，放回标准位置：

```bash
mkdir -p /usr/share/harpoon/inmates/freertos
cp /tmp/imx95-harpoon-freertos.cell /usr/share/jailhouse/cells/
cp /tmp/hello_world.bin /tmp/rt_latency.bin /usr/share/harpoon/inmates/freertos/
```

**为什么**：`.cell` 放 `/usr/share/jailhouse/cells/`（Jailhouse 默认找 cell 的地方），`.bin` 放 `/usr/share/harpoon/inmates/freertos/`（Harpoon 默认找 inmate 的地方）。不按这个放，命令就得写一长串路径。

**看到什么算成功**：

```bash
ls /usr/share/jailhouse/cells/ | grep harpoon
ls /usr/share/harpoon/inmates/freertos/
```

能列出文件名就行。

---

### 阶段 4：重启，在 U-Boot 里设那两个参数（关键一步）

**[板子-Linux]** 先重启：

```bash
reboot
```

**[板子-U-Boot]** 现在要抢 U-Boot 提示符。**这一步最容易失败**，原因是 autoboot 只有 2 秒：

- 串口窗口里**在上电/重启的同时不停按回车**，直到出现 `u-boot=>`
- 千万别用 Ctrl-C 猛刷（之前踩过坑：连续 Ctrl-C 会把串口的登录服务搞死，后面串口就静默了）

看到提示符后，**在同一个窗口里立刻连续敲这三条**（不要停太久，否则看门狗会复位板子）：

```text
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
run bsp_bootcmd
```

**为什么**：
- 前两条：告诉 U-Boot "Linux 只能用 4.375GB 内存"+"内核启动参数"（见第二部分）
- `run bsp_bootcmd`：用板子原厂的启动流程启动 Linux。**必须立刻执行**，因为停在 U-Boot 超时会被看门狗复位、自己跑回 Linux，那样前面两条 `setenv` 就白设了

**看到什么算成功**：Linux 又起来了，登录后检查内存是不是变小了：

```bash
head -2 /proc/meminfo     # MemTotal 应该约 4398132 kB，不是 15800000 多
cat /proc/cmdline         # 应该能看到 kvm-arm.mode=nvhe 等参数
```

**如果 MemTotal 还是 15GB 多**：说明 setenv 没生效（多半是超时被看门狗复位了），回到阶段 4 重新抢提示符。

---

### 阶段 5：在 Linux 里启动 hypervisor（二房东上岗）

**[板子-Linux]** 先做三件"环境准备"，再启动 hypervisor：

```bash
# 1. 限制 CPU 的恢复延迟（让核随时能被叫醒）
for c in 0 1 2 3 4 5; do echo 1 > /sys/devices/system/cpu/cpu$c/power/pm_qos_resume_latency_us; done

# 2. 调频策略改成 performance（可选，为了稳定）
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

# 3. 解绑 rpmsg（FreeRTOS 如果要跟 Linux 通信会用到，先让开）
echo c0100000.rpmsg-ca55 > /sys/bus/platform/drivers/imx-rpmsg/unbind
```

然后是核心两条：

```bash
modprobe jailhouse
jailhouse enable /usr/share/jailhouse/cells/imx95.cell
```

**为什么**：

| 命令 | 干嘛的 | 类比 |
|---|---|---|
| `modprobe jailhouse` | 把 Jailhouse 的**内核模块**装进 Linux | 二房东**进门** |
| `jailhouse enable imx95.cell` | 让 Jailhouse 正式接管硬件，按 `imx95.cell` 的分配单把硬件分成 root cell | 二房东**接管整栋楼**，跟 Linux 签合同：这间归你 |

`imx95.cell` 就是"Linux 自己那份合同"。

**看到什么算成功**：

```bash
jailhouse cell list
```

输出类似：

```text
ID   Name      State      CPUs
0    imx95     running    0-5
```

说明 hypervisor 已经上岗，Linux 现在跑在"受管"状态。

---

### 阶段 6：创建 FreeRTOS 的 cell，把 FreeRTOS 启动起来

**[板子-Linux]** 三条命令，顺序不能乱：

```bash
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/rt_latency.bin -a 0xf0000000
jailhouse cell start freertos
```

**为什么**（还是租房比喻）：

| 命令 | 干嘛的 | 类比 |
|---|---|---|
| `cell create` | 按 `.cell` 文件创建一个新 cell（第二份合同：这个核、这段内存归 FreeRTOS） | **划出一间房** |
| `cell load` | 把 FreeRTOS 二进制搬进这块内存 | **把家具搬进房间** |
| `cell start` | 把那个核从 Linux 手里收回来，交给 FreeRTOS 开始跑 | **开门营业** |

关于 `-a 0xf0000000`：

- `-a` 是 **a**ddress（加载地址）
- `0xf0000000` = 3.75GB，就是这块内存的起始地址
- **为什么必须写它**：`.cell` 文件里写好了"FreeRTOS 的代码要放在 0xf0000000"，FreeRTOS 的二进制也是**按这个地址编译**的。地址对不上，一启动就跑飞
- 这个地址正好在 Linux 用不到的那片内存里（见第二部分）

**看到什么算成功**：

```bash
jailhouse cell list
```

应该多出一行：

```text
ID   Name      State      CPUs
0    imx95     running    0-5
1    freertos  running    5
```

`freertos` 那个 cell 的状态是 `running` —— **FreeRTOS 已经在 A55 的核上跑起来了**。

---

### 阶段 7：怎么确认"真的在跑"（重点看这里）

**先说一个会让你懵的事：看不到 FreeRTOS 的串口打印是正常的。**

原因：Harpoon 的 FreeRTOS 配置里，它的输出串口是 **LPUART3**（地址 0x42570000），
而这块板子（FRDM-IMX95-PRO）的 J22 只引出了 UART1/2/7，**LPUART3 根本没引出来**。

所以不能用"有没有打印"判断成没成。用下面**三条独立证据**：

```bash
# 证据 1：cell 状态是 running
jailhouse cell list

# 证据 2：从 Linux 里看到核少了一个
nproc                    # 应该输出 5（原来是 6）

# 证据 3：FreeRTOS 在持续触发虚拟机退出（说明它真的在跑指令）
jailhouse cell stats freertos
```

**证据 3 怎么看**：`jailhouse cell stats` 需要终端界面，运行前先把工具目录加进 PATH：

```bash
export PATH=$PATH:/usr/share/jailhouse/tools
jailhouse cell stats freertos
```

看到 `vmexits_total` 这个数**一直在涨**、而且 `vmexits_mmio` 占绝大多数，就说明 FreeRTOS 在不停地往外写（就是在往它的串口打印，只是我们看不到）。

三个证据都成立，**这个方案就算跑通了**。

---

### 阶段 8：停止与恢复

**[板子-Linux]** 按顺序拆掉：

```bash
jailhouse cell shutdown freertos    # 让 FreeRTOS 停下
jailhouse cell destroy freertos     # 拆掉这间"房"
jailhouse disable                   # 二房东下岗，资源还给 Linux
modprobe -r jailhouse               # 把模块卸载掉
```

**最省事的恢复方式**：直接断电重启。因为 `setenv` 没写存储、cell 和 inmate 都在内存里，**断电后一切回到原样**。

---

## 附：可能遇到的问题

| 现象 | 原因 | 怎么办 |
|---|---|---|
| 串口报 `Access to the port 'COMxx' is denied` | 别的软件占着串口 | 关掉其他串口窗口 |
| 抢不到 U-Boot 提示符，命令打在 Linux 里了 | autoboot 只有 2 秒 | 上电同时不停按回车，别用 Ctrl-C |
| `setenv` 敲了但没生效（MemTotal 还是 15GB） | 停在 `u-boot=>` 太久被看门狗复位了 | 抢到提示符后**立刻**敲三条命令 |
| `jailhouse enable` 报错 | 内存参数没设（阶段 4 白做了） | 回阶段 4 重设 |
| `jailhouse cell stats` 报 `execvp: No such file or directory` | 工具目录不在 PATH | `export PATH=$PATH:/usr/share/jailhouse/tools` |
| `jailhouse cell stats` 报 `_curses.error: setupterm` | 需要真终端 | 用 `ssh -tt` 连板子，或设 `TERM=xterm` |
| 串口突然没反应，像板子死机 | 之前 Ctrl-C 刷太多，把串口登录服务刷死了 | 内核没死，换 SSH 连；或者干脆断电重启 |

---

## 相关

- 为什么要这么设计、两条流程的本质区别 → [[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
- 当时上板的完整记录和原始输出 → [[10-项目/FRDM-IMX95-PRO/Harpoon验证与复现.md|Harpoon 验证与复现]]
- 判定"厂商包能不能用手头板子"的方法 → [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse 与 Harpoon 的分层与判定]]
