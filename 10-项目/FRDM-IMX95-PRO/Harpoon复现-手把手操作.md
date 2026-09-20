---
type: 项目档案
scope: FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）
doc_type: 教程
status: 已整理
evidence: 实机验证
tags: [Harpoon, Jailhouse, 启动, 多核与异构, i.MX95]
updated: 2026-09-20
---

# Harpoon 复现操作手册（从头到尾照做）

> **本文只讲"手怎么动"**：每一步在哪台机器上做、敲什么、屏幕上会出现什么、做完接着做第几步。
> "为什么这样设计"放在最后第六部分，先不用看。
>
> 三个操作环境的标记，认准它就不会走错地方：
>
> | 标记 | 在哪 | 提示符 |
> |---|---|---|
> | **[电脑]** | 你的 Windows 笔记本 | `PS F:\...>` |
> | **[板子-U-Boot]** | 板子的引导程序（Linux 还没起来） | `u-boot=>` |
> | **[板子-Linux]** | 板子里已经跑起来的 Linux | `root@frdm-imx95:~#` |

---

## 第一部分：开始前必须知道的 3 件事（3 分钟看完）

### 1. 整个复现要分两轮，中间必须重启一次

```text
第一轮（板子在 Linux 里）：
    把 3 个文件传进板子          ← 必须 Linux 跑着才能联网传文件
    ↓
    【重启板子】
    ↓
第二轮（重启后）：
    先在 U-Boot 里设内存参数      ← 必须 Linux 还没启动才能设
    再进 Linux 启用 Jailhouse
    最后把 FreeRTOS 跑起来
```

**为什么非要重启？** 因为这两件事的位置是死固定的：
- **传文件**只有 Linux 起来了才能做（要联网）
- **设内存参数**只有 Linux 没起来时才能做（在 U-Boot 里）
- 而 U-Boot 永远跑在 Linux 前面

所以顺序只能是：**Linux 传文件 → 重启 → U-Boot 设参数 → 又进 Linux → 启用 Jailhouse**。一次上电做不完，这不是步骤绕，是板子的启动顺序决定的。

**所以你不是一上来就进 U-Boot**：第一轮全在 Linux 里，U-Boot 是第二轮才进。

### 2. 重启/断电什么会丢，什么不会丢

| 东西 | 重启后 | 为什么 |
|---|---|---|
| 传进板子的 3 个文件 | **还在** | 写进板子的 eMMC 存储了，永久保存 |
| U-Boot 里设的参数（`setenv`） | **丢** | 只改内存没存盘（没 `saveenv`），重启就没 |
| 加载的 cell 和 inmate | **丢** | 只在内存里 |

**结论**：传文件**做一次就够了**（以后再跑不用重传）；但**每次要跑 FreeRTOS，都得重走一遍"重启 → U-Boot 设参数 → Linux 启用"**。

### 3. 今天可以只做一半

第一轮（第 1~5 步，传文件）和第二轮（第 6~13 步）可以分两次做。今天时间不够就先只做第一轮，传完文件收工，明天上班直接做第二轮。

---

## 第二部分：准备工作

**[硬件]** 都要接好再开始：

| 东西 | 接在哪 |
|---|---|
| 电源 | 板子电源口 |
| 串口线 | 板子的 **J22** 调试口（一头接电脑 USB） |
| 网线 | 板子网口 ↔ 电脑网口（直连，不用路由器） |

**[电脑]** 打开串口软件（MobaXterm 或任意串口终端）。连接参数：

```text
端口：COM17        ← A55 的调试串口
波特率：115200
数据位：8  校验：None  停止位：1  流控：None
```

**不确定哪个 COM 口是 A55？** 挨个连上看，能出现 Linux 登录提示符的就是（板子上有 A55/M7/SM 三个串口，分别在 COM17/COM18/COM19）。

> **串口打不开报 `Access to the port 'COM17' is denied`**：说明别的程序占着它（比如 MobaXterm 里另一个串口标签页）。把其他串口窗口关掉再连。

---

## 第三部分：第一轮 —— 在 Linux 里把文件传进板子（第 1~5 步）

### 第 1 步：给板子上电，进 Linux

**[板子]** 板子电源打开（或者按复位键）。

**[电脑]** 串口窗口里开始滚启动日志。

**屏幕上应该看到**：一堆启动信息滚过去，最后停在类似这样的地方：

```text
frdm-imx95 login:
```

停下来不动了，就在等你登录。

**如果一直没反应**：按一下回车键，看有没有 `login:` 出现。

---

### 第 2 步：登录 root

**[板子-Linux]** 在 `login:` 那里输入：

```text
root
```

回车。（这个板子的 root **没有密码**，问密码就直接回车）

**屏幕上应该看到**：出现提示符

```text
root@frdm-imx95:~#
```

看到这个 `#` 就代表你是 root 了，后面所有命令都能敲。

**做完你人在**：板子的 Linux 里。接着做第 3 步。

---

### 第 3 步：让板子联网，拿到板子的 IP 地址

**[板子-Linux]** 依次敲（一行一行敲，每行回车）：

```bash
ip link set eth0 up
ip -brief addr
```

**第一行是干嘛的**：板子的网口默认是关着的，先打开。

**第二行是干嘛的**：看板子分到什么 IP 地址。

**屏幕上应该看到**（第二行的输出）：

```text
lo      UNKNOWN  127.0.0.1/8 ::1/128
eth0    UP       169.254.9.133/16 fe80::204:9fff:fe0b:4261/64
```

**把 `169.254.9.133` 这个数字抄下来**，第 4 步要用。你板子上的可能不一样，抄你自己的。

**如果 eth0 那行没有 169.254 开头的地址**：等一下再敲一次 `ip -brief addr`，两边自动协商要几秒钟。
**实测经常第一次只显示 IPv6 地址**（`fe80::...`），再敲一次才出现 IPv4 的 `169.254.x.x`。
还是没有就检查网线是不是插好了。

> **记住：这个 IPv4 地址每次重启都会变**（实测两次分别是 `169.254.9.133` 和 `169.254.206.207`）。
> 所以**每次 scp 之前都要重新查一遍**，不能拿上次的地址直接用。

**做完你人在**：板子的 Linux 里。接着做第 4 步。

---

### 第 4 步：从电脑把 3 个文件传进板子

> **⚠️ 先别急着传，检查板子上是不是已经有了。**
>
> 这些文件是存在板子 eMMC 里的，**只要传过一次就一直都在，重启也不会丢**。所以在**串口窗口**里先敲：
>
> ```bash
> ls /usr/share/jailhouse/cells/ | grep harpoon
> ls /usr/share/harpoon/inmates/freertos/
> ```
>
> - **如果两边都列出了文件**（比如看到 `imx95-harpoon-freertos.cell` 和 `hello_world.bin rt_latency.bin`）
>   → 说明以前传过、还在板子里，**第 4、5 步直接跳过，去做第 6 步**。
> - **如果缺文件** → 继续往下传，做完第 5 步再走。
>
> （2026-09-20 实测：板子上已经有了，所以这一轮 cp 命令报了"文件不存在"，但清单一查两个文件都在。**报错不等于失败，看清单为准。**）

**[电脑]** 串口窗口**不要关**（板子还在跑，关了就断线了）。**新开一个 PowerShell 窗口**，敲：

```powershell
cd F:\project\Learning\RTOS\build\rte-extract\usr\share
```

**这行是干嘛的**：切到放着那 3 个文件的目录。

然后敲（**把 IP 换成你第 3 步抄下来的**）：

```powershell
scp jailhouse\cells\imx95-harpoon-freertos.cell root@169.254.9.133:/tmp/
```

回车。

**屏幕上应该看到**：第一次连接会问一句：

```text
The authenticity of host '169.254.9.133' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

输入 `yes` 回车。然后开始传，最后显示进度：

```text
imx95-harpoon-freertos.cell          100%  772     1.2MB/s   00:00
```

（772 字节，很小，一闪就完了）

再传剩下两个：

```powershell
scp harpoon\inmates\freertos\hello_world.bin harpoon\inmates\freertos\rt_latency.bin root@169.254.9.133:/tmp/
```

**屏幕上应该看到**：

```text
hello_world.bin                      100%   66KB  10.5MB/s   00:00
rt_latency.bin                       100%   93KB  12.1MB/s   00:00
```

**如果报 `Permission denied`**：检查 IP 抄对没有。
**如果卡住不动**：板子和电脑的网络没通，回第 3 步检查 eth0 有没有地址。

**做完你人在**：电脑上的 PowerShell 里。接着做第 5 步（这一步要回到串口窗口）。

---

### 第 5 步：在板子里把文件放到正确位置

**[板子-Linux]** 回到**串口窗口**，敲：

```bash
mkdir -p /usr/share/harpoon/inmates/freertos
cp /tmp/imx95-harpoon-freertos.cell /usr/share/jailhouse/cells/
cp /tmp/hello_world.bin /tmp/rt_latency.bin /usr/share/harpoon/inmates/freertos/
```

**这三行是干嘛的**：Jailhouse 默认去 `/usr/share/jailhouse/cells/` 找 cell 文件、Harpoon 默认去 `/usr/share/harpoon/inmates/freertos/` 找 FreeRTOS 程序。把文件挪到这两个目录，后面敲命令就不用写一长串路径。

**屏幕上应该看到**：没有任何输出（Linux 里命令成功通常就是"没反应"）。没关系，用下面命令确认文件真的在了：

```bash
ls /usr/share/jailhouse/cells/ | grep harpoon
ls /usr/share/harpoon/inmates/freertos/
```

**应该看到**：

```text
imx95-harpoon-freertos.cell
hello_world.bin
rt_latency.bin
```

三个文件名都列出来，**第一轮就完成了**。

> **到这里可以收工**。文件已经永久存在板子里了，明天/下次接着做第二轮，不用重传。
> 如果现在就继续，往下做第 6 步。

---

## 第四部分：第二轮 —— 重启、设内存参数、把 FreeRTOS 跑起来（第 6~13 步）

### 第 6 步：重启板子

**[板子-Linux]** 在串口窗口敲：

```bash
reboot
```

回车。

**屏幕上应该看到**：Linux 开始关闭，然后屏幕滚一堆东西——**这时候要盯紧了，马上抢按键**（下一步）。

**做完你人在**：板子正在重启。**立刻做第 7 步**（只有 2 秒时间窗口）。

---

### 第 7 步：抢进 U-Boot 提示符（最容易失败的一步）

**[板子-U-Boot]** 板子重启后，**在串口窗口里不停地按回车键**（一下一下按，一秒按两三次）。

**为什么**：板子默认 2 秒后自动启动 Linux，只有在这 2 秒里按键才能停在 U-Boot。

**屏幕上应该看到**：

```text
U-Boot 2024.04 ...
...
u-boot=>
```

看到 `u-boot=>` 就成功了，**停在这里别动**。

**如果没抢到**：屏幕继续滚 Linux 日志、最后出现 `login:`，说明直接进 Linux 了。没关系，回到第 6 步再 `reboot` 一次重来。

> ⚠️ **千万别用 Ctrl-C 猛刷**！之前踩过这个坑：连续按 Ctrl-C 会把板子串口的登录服务搞坏，之后串口就彻底没反应了（板子其实没死，但你在这根串口上看不到任何东西）。**只用回车键。**

**做完你人在**：U-Boot 里。接着做第 8 步。

---

### 第 8 步：在 U-Boot 里敲 3 条命令

**[板子-U-Boot]** 在 `u-boot=>` 后面，**尽快**连着敲下面三行（每行回车）：

```text
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
run bsp_bootcmd
```

**屏幕上应该看到**：

- 前两行敲完回车，**U-Boot 什么反应都没有**（这是正常的，它不打印"设置成功"）
- 第三行敲完回车，板子开始启动 Linux，屏幕开始滚内核日志

**⚠️ 敲完第三条千万不要断电！** 断电的话 U-Boot 里刚设的参数就丢了，白做。让它自己滚完。

**为什么必须连着快点敲**：如果停在 `u-boot=>` 超过 1 分多钟不操作，板子的看门狗会把板子复位、自己跑回 Linux，那前两条 setenv 就白设了。

**如果手慢了、板子自己跑回 Linux 了**：回到第 6 步重新来，这次抢到提示符后动作快一点。

**做完你人在**：板子正在启动 Linux，等着它启动完（约 30 秒~1 分钟）。接着做第 9 步。

---

### 第 9 步：回到 Linux，**验证内存参数生效了**（验证点 1）

**[板子-Linux]** Linux 启动完会再次出现 `login:`，再登录一次：

```text
root
```

登进去后敲：

```bash
head -2 /proc/meminfo
```

**屏幕上应该看到**：

```text
MemTotal:        4398132 kB
MemFree:         3xxxxxxxx kB
```

**关键看 MemTotal 的数字**：

| 看到的数字 | 说明 | 下一步 |
|---|---|---|
| **约 4398132 kB**（4.2GB 左右） | ✅ 参数生效了，Linux 只能用 4.375GB，剩下的留给 FreeRTOS | 做第 10 步 |
| **15000000 kB 以上**（15GB 左右） | ❌ 参数没生效（多半是第 7/8 步超时了） | **回第 6 步重做** |

**为什么看这个数**：U-Boot 里设的 `jh_root_mem` 就是"Linux 只准用这么多内存"。这个数变小了，才证明参数真的生效、内存真的让出来给 FreeRTOS 了。

再顺便确认一下启动参数：

```bash
cat /proc/cmdline
```

**应该看到**里面有 `kvm-arm.mode=nvhe`、`cpuidle.off=1` 这些词。

**做完你人在**：板子的 Linux 里。接着做第 10 步。

---

### 第 10 步：做 3 项环境准备

**[板子-Linux]** 依次敲（一行一行敲）：

```bash
for c in 0 1 2 3 4 5; do echo 1 > /sys/devices/system/cpu/cpu$c/power/pm_qos_resume_latency_us; done
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo c0100000.rpmsg-ca55 > /sys/bus/platform/drivers/imx-rpmsg/unbind
```

**这三行是干嘛的**（一句话版）：

| 第几行 | 干嘛的 |
|---|---|
| 第 1 行 | 让 CPU 核随时能被立刻叫醒，不许睡太沉 |
| 第 2 行 | 把 CPU 频率策略设成性能优先（稳定一点） |
| 第 3 行 | 让 Linux 先松开一个通信模块，免得跟 FreeRTOS 抢 |

**屏幕上应该看到**：前两行没输出。**第三行会报错**，实测长这样：

```text
-sh: echo: write error: No such device
```

**这个错没关系，继续往下做。** 原因是这条路（`rpmsg-ca55`）在当前启动方式下本来就没挂成设备。
本次实测（2026-09-20）在这一步报了同样的错，后面 Jailhouse 照样正常启动、FreeRTOS 照样跑起来。

**做完你人在**：板子的 Linux 里。接着做第 11 步。

---

### 第 11 步：启动 Jailhouse（让"二房东"上岗）

**[板子-Linux]** 敲这两行：

```bash
modprobe jailhouse
jailhouse enable /usr/share/jailhouse/cells/imx95.cell
```

**这两行是干嘛的**：

- 第 1 行：把 Jailhouse 装进 Linux（"二房东进门"）
- 第 2 行：让它按 `imx95.cell` 这份分配单接管硬件（"二房东接管整栋楼，跟 Linux 签合同"）

**屏幕上应该看到**：可能有一两行提示信息，或者没输出。

然后敲这条**验证**（验证点 2）：

```bash
jailhouse cell list
```

**屏幕上应该看到**：

```text
ID   Name      State      CPUs
0    imx95     running    0-5
```

**看到 `imx95  running` 就说明 hypervisor 已经上岗了。**

**如果这条命令报 `jailhouse: command not found`**：说明 Jailhouse 没装上或者是路径问题，把报错原文记下来。

**如果 `jailhouse enable` 报错**：多半是第 9 步内存没设好，回去检查 MemTotal。

**做完你人在**：板子的 Linux 里。接着做第 12 步。

---

### 第 12 步：创建 FreeRTOS 的房间，把 FreeRTOS 启动起来

**[板子-Linux]** 三行，**顺序不能调**：

```bash
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/rt_latency.bin -a 0xf0000000
jailhouse cell start freertos
```

**这三行是干嘛的**：

| 第几行 | 干嘛的 | 类比 |
|---|---|---|
| 第 1 行 | 按配置文件划出一个新分区（哪个核、哪段内存归 FreeRTOS） | 划出一间房 |
| 第 2 行 | 把 FreeRTOS 程序搬进那块内存 | 把家具搬进房间 |
| 第 3 行 | 把那个核从 Linux 手里拿过来，让 FreeRTOS 开始跑 | 开门营业 |

**关于 `-a 0xf0000000`**：`-a` 后面跟的是"加载地址"，就是第 2 行要把程序放到内存的哪个位置。`0xf0000000` 是 cell 配置里规定好的地址，**照抄，别改**（改了 FreeRTOS 一启动就跑飞）。

**屏幕上应该看到**：可能有一两行提示。

**做完你人在**：板子的 Linux 里。接着做第 13 步（验证）。

---

### 第 13 步：验证 FreeRTOS 真的在跑（验证点 3、4、5）

**[板子-Linux]** 一共三条命令，逐个敲、逐个看：

**验证 3 —— cell 列表里多出 FreeRTOS：**

```bash
jailhouse cell list
```

**应该看到**（比第 11 步多出一行，而且 **imx95 那行的 CPU 少了一个**）：

```text
ID      Name        State      Assigned CPUs    Failed CPUs
0       imx95       running    0-4
1       freertos    running    5
```

**注意 `imx95` 从 `0-5` 变成了 `0-4`** —— 少的那个 **5 号核给了 FreeRTOS**。这就是"划走 1 个核"的直接证据。

看到 `freertos  running` → **FreeRTOS 已经在 A55 的核上跑起来了**。

**验证 4 —— Linux 少了一个核：**

```bash
nproc
```

**应该输出**：

```text
5
```

（原来是 6，现在 5，说明有 1 个核被 FreeRTOS 拿走了）

**验证 5 —— FreeRTOS 确实在持续执行（可选，但很有说服力）：**

```bash
export PATH=$PATH:/usr/share/jailhouse/tools
jailhouse cell stats freertos
```

**屏幕上应该看到**：一个实时刷新的界面，里面有一行 `vmexits_total`，**数字一直在往上跳**。

看几秒后按 `q` 退出。

**这行数字一直涨代表什么**：FreeRTOS 在不停执行指令、往外写东西（它在给它的串口打日志，只是我们看不到那个串口，见下面）。

> ### ⚠️ 有个事你可能已经发现了：FreeRTOS 没有任何打印输出
>
> **这是正常的，不代表失败。**
>
> 原因：Harpoon 的 FreeRTOS 默认往 **LPUART3** 这个串口打日志，但这块板子（FRDM-IMX95-PRO）的 J22 调试口**根本没有引出 LPUART3**（只引出了 UART1/2/7）。所以它的打印你在这块板上看不到。
>
> **所以判断成功与否，看上面那三条验证，不要看有没有打印。** 三条都成立（cell 是 running、nproc 变成 5、vmexits 在涨），这个方案就算**跑通了**。
>
> 想看到 FreeRTOS 的打印，需要改 cell 配置和固件、把它的输出串口换成板子上有的串口，重新编译——这是**下一个要单独做的事**，不在今天的复现范围内。

**做完你人在**：板子的 Linux 里，FreeRTOS 正在跑。接着做第 14 步。

---

### 第 14 步：收工（两种方式，选一个）

**方式 A：规矩地停掉（推荐，能看清每一步）**

**[板子-Linux]** 依次敲：

```bash
jailhouse cell shutdown freertos
jailhouse cell destroy freertos
jailhouse disable
modprobe -r jailhouse
```

**四行分别干嘛的**：让 FreeRTOS 停下 → 拆掉房间 → 二房东下岗把资源还给 Linux → 卸载模块。

**方式 B：直接重启（最省事）**

```bash
reboot
```

因为 U-Boot 的参数没存盘、cell 和 inmate 都在内存里，**一重启就全恢复原样了**。板子不会有任何残留改动。

---

### 第 15 步：把结果记下来

回到**[电脑]**，把今天的结果记一下（下次要用）：

```text
1. 第 9 步 MemTotal = ________ kB     （证明参数生效）
2. 第 11 步 cell list 输出 = ________  （证明 hypervisor 起来了）
3. 第 13 步 cell list 输出 = ________  （证明 FreeRTOS 在跑）
4. 第 13 步 nproc = ________
5. 哪一步卡住了、报什么错 = ________
```

**为什么要记**：下次再跑，看到一样的数字就说明一切正常；数字不一样，就是中间某步出问题了。

---

## 第 15 步之后：2026-09-20 实测结果（第二次完整复现，5 个验证点全过）

**这次是照本文档从头走完的，结论：方案跑通。**

| 验证点 | 实际输出 | 结果 |
|---|---|---|
| 1 内存参数生效 | `MemTotal: 4398132 kB`、`MemFree: 3824920 kB` | ✅ |
| 1 附 内核参数 | `cat /proc/cmdline` 含 `kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe` | ✅ |
| 2 hypervisor 启动 | `Jailhouse hypervisor v0.12`，CPU 0~5 全部 OK，`Activating hypervisor`；`cell list` → `0 imx95 running 0-5` | ✅ |
| 3 FreeRTOS 启动 | `Created cell "freertos"` → `Cell "freertos" can be loaded` → `Started cell "freertos"`；`cell list` → `1 freertos running 5`（imx95 变为 `0-4`） | ✅ |
| 4 Linux 少一核 | `nproc` = `5` | ✅ |
| 5 确实在执行 | `vmexits_total 1517`、`vmexits_mmio 1515`、`vmexits_management 2` | ✅ mmio 占绝对多数 |
| 收工 | `shutdown`→`destroy`→`disable`（释放 CPU 0~5）→`modprobe -r` 全部成功 | ✅ |

**本次与文档预期不同的 3 处（文档已按实测修正）**：

1. **第 4/5 步可以跳过**：板子上**已经有** cell 和 inmate 文件（以前传过，存在 eMMC 里没丢），
   所以那轮 `cp /tmp/hello_world.bin ...` 报了 `No such file or directory`——**报错但清单里文件是全的**。
   教训：传文件前先 `ls` 看一眼，别白传，也别把"cp 报错"当成失败。
2. **第 10 步第三行必报错**：`echo c0100000.rpmsg-ca55 > .../unbind` 报
   `-sh: echo: write error: No such device`（不是文档原先猜的 `No such file`）。无害，继续做。
3. **`cell list` 的实际表格多一列**：有 `Failed CPUs` 列，且 `imx95` 的 CPU 变成 `0-4`。

**一个要记住的坑**：板子的 IPv4 地址**每次重启都会变**（这次是 `169.254.206.207`，
上一次复现是 `169.254.9.133`）。`ip -brief addr` 有时第一次只显示 IPv6 地址
（`fe80::...`），等几秒再敲一次才会出现 `169.254.x.x`。**每次 scp 前都要重新查一遍 IP。**

**核数确认**：实际是 **1 个核**（5 号核给了 FreeRTOS，Linux 剩 0-4）。
（备注：周报里写的"两个核"与此不符，如果要按 2 核跑，需要改 cell 配置里的 CPU 分配后重新验证。）

---

## 下一步：为什么看不到输出，以及要改什么

**现状**：1 个核跑通了，但 FreeRTOS 的打印一个字都看不到。

**原因**：FreeRTOS 的输出串口是 **LPUART3**（cell 配置里定的），而板子的 J22 只引出了 UART1/2/5/7，
**LPUART3 的引脚根本没接到任何排针上**。所以不是"程序没跑"，是"它的嘴对着墙说话"。

**要看到输出，必须让 FreeRTOS 的串口有个"听众"。** 三条路，按代价从低到高：

### 路径 0（最优先，先试这个）：直接接一根串口线到 J15-8

**依据**（两处证据拼起来）：

| 结论 | 依据等级 | 出处 |
|---|---|---|
| `UART3_TXD` 与 `GPIO_IO14` 复用、`UART3_RXD` 与 `GPIO_IO15` 复用 | **官方资料明确说明** | EVK 手册 UM12022（`UART3_TXD ... multiplexed with GPIO_IO14`） |
| `J15-8` = GPIO_IO14、`J15-10` = GPIO_IO15 | **实机验证** | 本工程 M7 项目用 J15-8 短接 J15-10 做 GPIO 回环，OUT/IN 同步成功 |
| 所以 LPUART3 的 TX 就在 J15-8 上，接 USB-TTL 就能收到 | **待验证**（推断） | 由上两条推出，还没实际接过 |

**接法**：

```text
USB-TTL 转接器            FRDM-IMX95-PRO
   RXD  ────────────────  J15-8   (GPIO_IO14 / LPUART3_TXD)
   GND  ────────────────  J15 上任一 GND 针
   TXD      （不接！）
```

- **只接 RXD 和 GND，不要接 TXD** —— 我们只"听"，不"说"，避免两个输出打架
- **USB-TTL 必须是 3.3V 电平**的（J15 是 3.3V 系统，接 5V 电平有风险）
- 波特率按 **115200 8-N-1** 试（不对再试 921600 / 9600）

**然后**：跑一遍第 6~13 步（重启 → U-Boot 设参数 → jailhouse enable → cell create/load/start），
在这个 USB-TTL 的串口窗口里看有没有文字冒出来。

**如果什么都没有**：说明引脚的 IOMUX 还在 GPIO 功能上（没切到 UART），那就得走下面第 2、3 条。

### 路径 1：试 jailhouse 自带的 console 命令

板上 jailhouse 有 `console [-f|--follow]` 子命令（2026-09-20 实测 `jailhouse --help` 确认）：

```bash
jailhouse console -f
```

这个连的是 **hypervisor 自己的控制台**。如果 FreeRTOS 走的是"虚拟控制台"（输出经 hypervisor 转发），
这里就能看到；但它现在明显是在直接写 LPUART3 的寄存器（`vmexits_mmio` 1515 次占绝对多数），
所以**大概率看不到 FreeRTOS 的字**，但能看到 hypervisor 的日志（也许有线索）。**成本 5 分钟，值得一试。**

### 路径 2：问 NXP 要配置

直接说清需求要现成的 cell：

> "我要 Harpoon FreeRTOS 的 console 改成板子上引出的串口（UART1/UART2/UART7 任选），
> 另外 CPU 想用 2 个核，请给对应的 cell 文件。"

比自己搭 Yocto 快得多。

### 路径 3：自己改源码重编（最后才走）

下载 Real-Time Edge / Harpoon 源码（含 `meta-nxp-harpoon` 层），改 `imx95-harpoon-freertos.c` 里的
console 和 CPU 分配，交叉编译出新的 `.cell`。最彻底，但要搭 Yocto 环境，以天计。

**为什么必须走源码这条路（2026-09-20 查包的结果）**：

| 包里的东西 | 是什么 | 能不能改配置 |
|---|---|---|
| `imx95.cell`、`-freertos.cell`、`-industrial.cell` | **预编译成品**（二进制） | ❌ hex 硬改不现实 |
| `harpoon_set_configuration.sh` | 只是**选**用哪套 cell/bin，写进 `/etc/harpoon/harpoon.conf` | ❌ 不生成 cell |
| `jh_harpoon.sh` | 按 conf 里的路径依次敲 jailhouse 命令 | ❌ 不生成 cell |
| `.c / .h` 源码 | **一个都没有** | — |

`.cell` 是在源码树里由 C 文件编译出来的，包里只有结果没有源。
（板上 `jailhouse` 有 `config create ... [-c CONSOLE]` 子命令能生成**系统/root cell**配置，
但它生成的是 `imx95.cell` 那一类，不是 inmate cell，帮不上改 FreeRTOS 串口的忙。）

**建议顺序**：先花 10 分钟走**路径 0**（接根线，可能直接就成了）；同时把**路径 2**的问题发给 NXP；
路径 0 失败再试**路径 1**；都走不通才启动**路径 3**。

---

## 第五部分：卡住时的排查表

| 现象 | 大概原因 | 怎么办 |
|---|---|---|
| 串口打不开，报 `Access to the port 'COM17' is denied` | 别的软件占着串口 | 关掉其他串口窗口（尤其 MobaXterm 的其他标签页） |
| 板子上电后串口一直没反应 | 串口选错 / 没接好 | 挨个 COM 口试；按一下回车看有没有 login |
| 第 3 步 eth0 没有 169.254 地址 | 网线没插好 / 网口没起来 | 确认网线两端插好；`ip link set eth0 up` 后等 5 秒再查 |
| scp 卡住不动 | 网络不通 | 回第 3 步确认 eth0 有地址 |
| **抢不到 U-Boot 提示符** | autoboot 只有 2 秒 | 上电同时就不停按回车；**别用 Ctrl-C** |
| setenv 敲了但 MemTotal 还是 15GB | 停在 U-Boot 太久被看门狗复位了 | 抢到提示符后立刻敲三条命令 |
| `jailhouse enable` 报错 | 内存参数没生效 | 检查第 9 步 MemTotal 是不是 4398132 |
| `cell load` 报错 | 加载地址或文件路径不对 | 确认写的是 `-a 0xf0000000`，文件在 `/usr/share/harpoon/inmates/freertos/` |
| `jailhouse cell stats` 报 `execvp: No such file or directory` | 工具目录没加进 PATH | 先敲 `export PATH=$PATH:/usr/share/jailhouse/tools` |
| `jailhouse cell stats` 报 `_curses.error: setupterm` | 需要真正的终端 | 用 SSH 连板子（`ssh -tt root@板子IP`），或先 `export TERM=xterm` |
| 串口突然完全没反应了 | 之前 Ctrl-C 刷太多，串口登录服务被刷死了 | 板子没死，改用 SSH 连；或断电重启 |

---

## 第六部分：原理（先照着做完，再回来看这个）

### Harpoon 到底在干什么

**一句话：Linux 正用着 6 个 A55 核，Harpoon 让其中 1 个核让出来单独跑 FreeRTOS，两边同时运行互不打扰。**

三个名词，一个租房比喻：

| 名词 | 是什么 | 类比 |
|---|---|---|
| **hypervisor** | 硬件"二房东"，让 Linux 以为独占硬件，实际由它分配 | 二房东 |
| **cell** | 一份资源分配单（`.cell` 文件），写明哪个核、哪段内存归谁 | 租房合同 |
| **inmate** | 住进 cell 的程序，这里就是 FreeRTOS | 租客 |

NXP 用的这个二房东程序叫 **Jailhouse**。

### 跟你 M7 方案的区别

| | 你的 M7 方案 | Harpoon 方案 |
|---|---|---|
| FreeRTOS 跑在哪 | M7 核 | A55 的 1 个核 |
| **谁把它启动起来** | **SM**（开机早期，Linux 之前） | **Linux 起来之后**，敲 `jailhouse` 命令 |
| 固件怎么进去的 | 打包进 `flash.bin`，跟着启动镜像一起烧 | 用 `scp` 传文件进去，运行时加载 |
| 要不要重新烧板子 | 要 | 不用（板子原厂就带 Jailhouse） |

**一句话记住**：M7 的 FreeRTOS 是"**开机就装在楼里的固定住户**"，Harpoon 的 FreeRTOS 是"**楼盖好后临时搬进来的租客**"。

### 第 8 步那两个参数到底在干嘛

**`jh_root_mem`（内存分配）**

```text
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
```

格式是 **`大小@起始地址`**，逗号分隔两块：

| 第几块 | 大小 | 起始地址 | 换算 |
|---|---|---|---|
| 第一块 | `0x58000000` | `0x90000000` | 1.375 GB，从 2.25GB 到 3.625GB |
| 第二块 | `0xc0000000` | `0x180000000` | 3.0 GB |
| | | | **合计 4.375 GB** |

**含义：Linux 只准用这两块内存，一共 4.375 GB。剩下的内存 Linux 看不到，留着给 FreeRTOS 用。**

验证过了：设完之后 Linux 的 `MemTotal` 是 4398132 kB（4.19GB），和 4.375GB 基本对上（差的那点是内核自己留的）。

而且 FreeRTOS 被加载到 `0xf0000000`（3.75GB），这个地址**正好在 Linux 第一块内存（到 3.625GB）之外**——所以 Linux 根本碰不到那块地方，不会跟 FreeRTOS 打架。

> 这条"jh_root_mem 是 Linux 可用内存"的结论，依据是"两个数值相加 = 4.375GB，与实测 MemTotal 4.19GB 吻合"，属于**由实测推断**，还没去逐行读 U-Boot 源码确认。

**`jh_clk`（内核启动参数）**

```text
setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
```

这串是传给 Linux 内核的启动参数，四个各有用途：

| 参数 | 干嘛的 | 不设会怎样 |
|---|---|---|
| `kvm-arm.mode=nvhe` | 让 Linux 自带的 KVM 用 NVHE 模式 | 虚拟化硬件被 KVM 占着，Jailhouse 起不来 |
| `kvm.enable_virt_at_load=false` | 加载 KVM 时别立刻接管虚拟化硬件 | 同上，两边抢 |
| `cpuidle.off=1` | 关掉 CPU 深度休眠 | 分给 FreeRTOS 的核睡过去，叫不醒 |
| `clk_ignore_unused` | 别自动关掉"没人用"的时钟 | 有些外设时钟被关，起不来 |

**为什么要 `run bsp_bootcmd`**：这是板子原厂的"启动 Linux"命令。设完参数必须立刻执行它，因为停在 U-Boot 超时会被看门狗复位。

---

## 相关

- 两条流程的本质区别、设计取舍 → [[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
- 当时上板的完整记录和原始输出 → [[10-项目/FRDM-IMX95-PRO/Harpoon验证与复现.md|Harpoon 验证与复现]]
- 判定"厂商包能不能用手头板子"的方法 → [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse 与 Harpoon 的分层与判定]]
