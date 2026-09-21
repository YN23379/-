---
type: 项目档案
scope: FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）
doc_type: 教程
status: 已整理
evidence: 实机验证
tags:
  - Harpoon
  - Jailhouse
  - 启动
  - 多核与异构
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

| 第几行   | 干嘛的                              |
| ----- | -------------------------------- |
| 第 1 行 | 让 CPU 核随时能被立刻叫醒，不许睡太沉            |
| 第 2 行 | 把 CPU 频率策略设成性能优先（稳定一点）           |
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

| 第几行   | 干嘛的                              | 类比      |
| ----- | -------------------------------- | ------- |
| 第 1 行 | 按配置文件划出一个新分区（哪个核、哪段内存归 FreeRTOS） | 划出一间房   |
| 第 2 行 | 把 FreeRTOS 程序搬进那块内存              | 把家具搬进房间 |
| 第 3 行 | 把那个核从 Linux 手里拿过来，让 FreeRTOS 开始跑 | 开门营业    |

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

### 先说结论（2026-09-20 当天查清了，比"接线"这一步更根本）

> **看不到输出，不是接线问题，也不是逻辑分析仪设置问题。**
> **是这份从 EVK 拿来的 cell 把 inmate 的 console 配在了 LPUART3，而 LPUART3 在这块 Pro 板上压根不归 Linux 域管。**
> 引脚控制权不在 Linux 手里，inmate 就算把寄存器写穿了，信号也出不了芯片。

**完整链条（每一环都有实测证据）**：

```text
FreeRTOS inmate 跑在 A55 CPU5（属于 Linux 域）
   ↓ 它往 LPUART3 的数据寄存器写     ← vmexits_mmio 1515 次，证明写了
   ↓
LPUART3 的引脚要在 IOMUX 里切到 UART3_TXD 功能，才出得来信号
   ↓ 但引脚控制权归 SM 分配，Linux 域要经 SCMI 申请
   ↓ Linux 域里根本没有 LPUART3 这个设备     ← 见下面证据 1、2
结果：J15-8 上永远不会有信号
```

## 下一步：为什么看不到输出，以及要改什么

### 证据 1：Linux 域里只有 3 个 LPUART，没有 LPUART3

**[板子-Linux]** 敲（这是驱动自己报的，最硬）：

```bash
cat /proc/tty/driver/* 2>/dev/null | head
```

**实测输出**：

```text
0: uart:FSL_LPUART mmio:0x44380010 irq:139 tx:34055 rx:2672 ...   ← LPUART0（就是 console）
4: uart:FSL_LPUART mmio:0x42590010 irq:137 tx:0 rx:0 ...          ← LPUART4（没人用过）
5: uart:FSL_LPUART mmio:0x425A0010 irq:138 tx:0 rx:0 ...          ← LPUART5（没人用过）
```

`dmesg` 印证（`0x42590000.serial` / `0x425a0000.serial` / `0x44380000.serial`）：

```bash
dmesg | grep -i -E "lpuart|ttyLP"
```

```text
42590000.serial: ttyLP4 at MMIO 0x42590010 ... is a FSL_LPUART
425a0000.serial: ttyLP5 at MMIO 0x425a0010 ... is a FSL_LPUART
44380000.serial: ttyLP0 at MMIO 0x44380010 ... is a FSL_LPUART   ← console
```

`ls -l /dev/ttyLP*` 也只有 `ttyLP0`、`ttyLP5`。

**→ 整个 Linux 域里没有任何东西指向 LPUART3（0x42570000）。**

### 证据 2：pinmux 表里根本没有 uart3 的引脚

**[板子-Linux]** 敲：

```bash
grep -i uart /sys/kernel/debug/pinctrl/scmi_dev.8-scmi-pinctrl-imx/pinmux-pins
```

**实测输出**（整个文件 129 行，uart 相关的只有这 4 行）：

```text
pin 116 (uart1rxd): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 117 (uart1txd): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 118 (uart2rxd): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 119 (uart2txd): (MUX UNCLAIMED) (GPIO UNCLAIMED)
```

**没有 uart3，也没有 uart4/5/7。**

再查我们要的那两个脚：

```bash
grep -E "pin (18|19) " /sys/kernel/debug/pinctrl/scmi_dev.8-scmi-pinctrl-imx/pinmux-pins
```

```text
pin 18 (gpioio14): (MUX UNCLAIMED) (GPIO UNCLAIMED)     ← 就是 J15-8
pin 19 (gpioio15): (MUX UNCLAIMED) (GPIO UNCLAIMED)     ← 就是 J15-10
```

> ### ⚠️ `UNCLAIMED` 千万不能理解成"这个脚空着、随便用"
>
> **正确读法**：这张表**只列出 SMCU 交给 Linux 域管的引脚**。`UNCLAIMED` 只说明**当前没有 Linux 驱动在占用它**，
> **完全看不到 M7 域在干什么**。
>
> **反证**：你 M7 项目里 J15-8/J15-10 做 GPIO 回环是**成功的**——那时 M7 域正在用这两个脚。
> 如果 `UNCLAIMED` 真是"没人用"，M7 就不该能用它。
>
> **所以：Linux 域视角看到的"空闲"，不等于物理引脚空闲。** 这是排查引脚问题时最容易踩的坑。

### 证据 3：路径名本身就说明引脚是 SM 代管的

```text
/sys/kernel/debug/pinctrl/scmi_dev.8-scmi-pinctrl-imx/
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

`scmi-pinctrl-imx` = **Linux 不直接写 IOMUX 寄存器，是通过 SCMI 这个"遥控器"请 SM 代写**。
设备树顶层里那个 `firmware` 节点就是 SCMI 接口。所以：

```text
Linux 设备树里申请某根引脚的 pinctrl
   ↓ SCMI 消息
AON M33 上的 SM
   ↓ SM 查这张脚的归属
   ↓ 不归 Linux 域 → 拒绝，IOMUX 保持原样
```

**结论**：LPUART3 的引脚不在这张表里，说明它压根不归 Linux 域。结合此前记录的
"SM 配置里 LPUART3 分配给 M7（标记 `test`）"，可以判断 **LPUART3 是 M7 的串口**。

**官方文档印证了这一点（UG10170 §1.5）**：

> `Harpoon provides a custom System Manager configuration that describes the hardware used for its applications,
> such as the TPM and **LPUART usage for its guest cell**.`

也就是说：**guest cell 用哪一路 LPUART，是写在 Harpoon 定制的那份 SM 配置里的**。
EVK 的 SM 配置给了 LPUART3，Pro 板的 SM 配置没给 —— 这和我们实测到的现象完全吻合。

### 结论：这是"配置本身在 Pro 板上不成立"，不是"还没调通"

| 环节 | 结论 | 证据等级 |
|---|---|---|
| Linux 域里有几个串口 | 只有 **LPUART0 / 4 / 5**，**没有 LPUART3** | **实机验证** |
| LPUART3 引脚是否在 Linux 域 | **不在**，129 行 pinmux 表里没有任何 uart3 | **实机验证** |
| J15-8 是什么 | `pin 18 (gpioio14)`，Linux 域显示 `UNCLAIMED` | **实机验证** |
| J15-8 上为什么没信号 | LPUART3 引脚不归 Linux 域，写了寄存器也出不来 | **由实测推断** |
| LPUART3 归谁 | 归 **M7 域** | **推测**，待 SM 配置确认 |
| guest cell 的 LPUART 由 SM 配置决定 | 是 | **官方资料明确说明**（UG10170 §1.5） |
| 官方支持这份 cell 用在哪块板 | **i.MX95 19x19 LPDDR5 EVK**，不含 FRDM-IMX95-PRO | **官方资料明确说明**（UG10170 §3.1） |
| 官方认为应该有输出 | 是，§4.3 写明 `hello_world` 应打印 `INFO: hello_func : Hello world.` | **官方资料明确说明**（UG10170 §4.3） |

**最后一行很重要**：官方**没有**把"inmate 无输出"列为已知问题，反而明确写了应该有输出。
所以这是**异常状态**，不是"设计如此"，值得追下去。

### 顺带确认：核数我们做对了

UG10170 §1.4 写明 **i.MX 95 的 inmate 就是 CPU5 单核**：

```c
// For i.MX 95, CPU core 5 is assigned to the cell:
.cpus = {
    0b100000,
    },
```

**和实机测到的 `1 freertos running 5` 完全一致。** 所以核数没问题，不用改。
（"2 个核"是额外需求：官方写法是 `.cpus = { 0b110000, }`，但原文只举了 i.MX 8M 的例子。）

---

## 下一步：要看到输出，可以走哪几条路

**要看到输出，必须让 FreeRTOS 的串口有个"听众"。** 四条路，按代价从低到高：

### 路径 0：接一根线到 J15-8（**已验证不通，仅作诊断用**）

**这一步保留，但作用变了 —— 它不再是"找输出"，而是"给结论盖章"。**

| 结论 | 依据等级 | 出处 |
|---|---|---|
| `UART3_TXD` 与 `GPIO_IO14` 复用、`UART3_RXD` 与 `GPIO_IO15` 复用 | **官方资料明确说明** | EVK 手册 UM12022 |
| `J15-8` = GPIO_IO14、`J15-10` = GPIO_IO15 | **实机验证** | 本工程 M7 项目用 J15-8 短接 J15-10 做 GPIO 回环成功 |
| J15-8 上能收到 LPUART3 的输出 | **已推翻** | pinmux 表无 uart3，LPUART3 不归 Linux 域（见上） |

**这里要纠正一个常见误解**：

> ❌ 错："GPIO_IO14 管发送、GPIO_IO15 管接收"
> ✅ 对："**同一个物理针脚，有两个可选身份**，由 IOMUX 二选一"

```text
J15-8 这个物理针脚
   ├── 身份 A：UART3_TXD（串口发数据）
   └── 身份 B：GPIO_IO14（普通输入输出）
   同一时刻只能选一个，由 IOMUX 决定
```

所以 J15-8 上要么是 UART3 的**发送**、要么是 GPIO14，**不可能同时是两者**；J15-10 同理（UART3 的接收 或 GPIO15）。

**用逻辑分析仪量 J15-8（现在的作用是验证结论）**：

```text
逻辑分析仪 CH0  ──────  J15-8
逻辑分析仪 GND  ──────  J15 上任一 GND 针     ← 必须共地
```

Logic 2 顺序（**顺序很关键**）：采样率 4 MS/s → 加 **Async Serial** 分析仪（CH0、115200、8、1、None、不反相）
→ 触发设 **CH0 Falling Edge + Start Capture** → **点 Start 进入等待触发** → 然后再敲：

```bash
jailhouse cell shutdown freertos
jailhouse cell start freertos
```

| Logic 2 看到 | 结论 |
|---|---|
| **一条平直线**（预期结果） | ✅ 证实：引脚不归 Linux 域，信号出不来 |
| 有方波、解码乱码 | 有信号，波特率不对，试 921600 / 9600 |
| 有方波、解出文字 | ❌ 推翻上面的结论 |

> **J15 才是给你引裸信号的排针**（2×20 EXPI，UM12527 §2.20）。
> **J22 是 USB Type-C + 板载 CH9114F 转接芯片，没有裸针脚可夹。**

### 路径 0.5（最现实）：改用 LPUART4 或 LPUART5

**依据**：这两个口 **Linux 域已经注册好、而且从没被用过**（`tx:0 rx:0`）。

| 串口 | 外设基址 | 设备节点 | 现状 |
|---|---|---|---|
| LPUART4 | `0x42590000` | `ttyLP4` | 已注册，空闲 |
| LPUART5 | `0x425A0000` | `ttyLP5` | 已注册，空闲 |

**它们是"Linux 域的、现成的、没占用的"串口，正是 inmate console 的理想目标。**

**但**：`.cell` 是预编译二进制，**改不了 console 地址**。所以这条路必须**问 NXP 要一份 console 指向 LPUART4/5 的 cell**，或走源码重编（路径 3）。
**好消息**：现在能把需求说得极其精确（连基址都给了），NXP 几乎不可能听不懂。

### 路径 1：`jailhouse console -f`（**已实测无效，划掉**）

```bash
jailhouse console -f
```

**2026-09-20 实测结果：只输出 hypervisor 自己的日志，不含任何 inmate 输出。** 实测原文：

```text
Initializing Jailhouse hypervisor v0.12 ... on CPU 1
Code location: 0x0000ffffc0200800
Initializing processors: CPU 1... OK  CPU 0... OK  CPU 2... OK  CPU 5... OK  CPU 4... OK  CPU 3... OK
Initializing unit: irqchip / ARM SMMU v3 / ARM SMMU / PVU IOMMU / PCI
Adding virtual PCI device 00:00.0 to cell "imx95"
...
Activating hypervisor
Adding virtual PCI device 00:00.0 to cell "freertos"
Shared memory connection established, peer cells: "imx95"
Created cell "freertos"
Cell "freertos" can be loaded
Started cell "freertos"
```

**看清楚这三段分别是谁打的**：

| 段落 | 谁打的 |
|---|---|
| `Initializing Jailhouse hypervisor ... CPU 0~5 OK ... Activating hypervisor` | **hypervisor 自己**（`jailhouse enable` 时） |
| `Adding virtual PCI device` / `Created cell` / `can be loaded` / `Started cell` | **hypervisor 自己**（你敲 `cell create/load/start` 时） |
| 重复的 `can be loaded` / `Started cell` | 你反复重试的那几次 |

**从头到尾没有一行是 FreeRTOS 打的。** 这印证了 inmate 走的是**直接 MMIO 写串口寄存器**，不是 hypervisor 虚拟控制台。**路径 1 排除。**

### 路径 2：问 NXP 要配置（**现在最推荐**）

因为已经把问题收敛得很具体了，问法可以很直接：

> "我手里是 FRDM-IMX95-PRO，想在 A55 上跑 FreeRTOS，用的是官方 Harpoon 方案。
> 现在能跑起来（`cell list` 显示 `freertos running 5`），但 **inmate 的 console 没有任何输出**。
>
> 我查了：
> - `/proc/tty/driver/*` 里 Linux 域只有 LPUART0/4/5，**没有 LPUART3**；
> - `pinmux-pins` 里**没有任何 uart3 引脚**；
> - 逻辑分析仪在 J15-8 上**测不到信号**。
>
> UG10170 §1.5 说 guest cell 的 LPUART 是在**定制版 SM 配置**里分配的。是不是 EVK 的 SM 配置把
> LPUART3 给了 guest cell，而 Pro 板的没有？**能否提供 Pro 板可用的 SM 配置 + cell**，
> 或者告诉我应该用哪一路 LPUART？"

**完整版问题清单**见 [[10-项目/IMX95-EVK/待向NXP确认的问题清单.md|待向 NXP 确认的问题清单]]。比自己搭 Yocto 快得多。

### 路径 3：自己改源码重编（最后才走）

> ⚠️ **注意**：路径 3 的源码仓库不是 Harpoon 包里的，要单独从 GitHub 取。
> 详见后面「三个文件的来源」一节。这里先记住：**`imx95-harpoon-freertos.cell` 的源码在
> [NXP/harpoon-apps](https://github.com/NXP/harpoon-apps) 仓库（tag `harpoon_3.3.0`），不在你下载的安装包里。**

**官方给的确切做法**（UG10170 §6.2）：

```bash
west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww
cd hww
west update
```

**要改的文件**（UG10170 §1.4 给了确切路径）：

| 要改什么 | 文件 | 在哪 |
|---|---|---|
| inmate console 串口、CPU 核数 | `configs/arm64/imx95-harpoon-freertos.c` | Harpoon meta-layer 的 Jailhouse recipe 补丁里 |
| root cell 配置 | `configs/arm64/imx95.c` | 同上 |
| **guest cell 的 LPUART 分配** | Harpoon **定制版 SM 配置** | `Real-Time Edge SW v3.1 Yocto recipes` 或 `meta-nxp-harpoon`（UG10170 §1.5） |

**注意最后一行**：光改 cell 可能不够，**SM 配置里那份 LPUART 分配也要一起改**。最彻底，但要搭 Yocto 环境，以天计。

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

**建议顺序**：先把**路径 2** 的问题发给 NXP（现在问得非常精确）；想先要个"看得见的输出"就直接提**路径 0.5**；
路径 0 的逻辑分析仪量一遍**给结论盖章**；都走不通才启动**路径 3**。

---

## 三个文件的来源与用途（`imx95-harpoon-freertos.cell` / `hello_world.bin` / `rt_latency.bin`）

### 短答

**是的，三个文件都来自你下载的那个 Harpoon 包**（Real-Time Edge 3.3），但**不是直接躺在文件夹里**——
它们打包在 rootfs 压缩包里，需要解包才能拿到。

```text
F:\project\Learning\RTOS\Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK\
├── SCR-REAL-TIME-EDGE-3.3.txt               ← 软件组成清单（说明每个包从哪个 git 仓库来）
└── real-time-edge\
    ├── nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.tar.zst   （1.78 GB）
    ├── nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.wic.zst   （1.80 GB，整盘镜像）
    ├── nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.manifest  ← 软件包清单
    ├── Image-imx95-19x19-lpddr5-evk.bin          （内核）
    ├── imx-boot-...-flash_a55.bin / -flash_all.bin（启动镜像）
    └── imx95-19x19-evk-*.dtb / *.dtbo            （一堆设备树，全是 EVK 的）
```

**解包位置**：`F:\project\Learning\RTOS\build\rte-extract\`

### 三个文件的确切位置与用途

| 文件 | 在包里的路径 | 大小 | 是什么 | 干什么用 |
|---|---|---|---|---|
| `imx95-harpoon-freertos.cell` | `usr/share/jailhouse/cells/` | 772 B | **Jailhouse cell 配置**（二进制结构体） | "租房合同"：写明哪个核、哪段内存归 FreeRTOS |
| `hello_world.bin` | `usr/share/harpoon/inmates/freertos/` | 66 040 B | **FreeRTOS inmate**（最简单的样例） | "租客"：只打印一句话的裸机程序，用来**验证通路** |
| `rt_latency.bin` | `usr/share/harpoon/inmates/freertos/` | 94 848 B | **FreeRTOS inmate**（实时性测试） | "租客"：测中断延迟/调度抖动的程序，**真正要用的那个** |

**同目录下还有的（一并列出，免得以后找）**：

| 文件 | 路径 | 用途 |
|---|---|---|
| `industrial.bin` | `usr/share/harpoon/inmates/freertos/` | 工业示例（EtherCAT/OPC-UA 方向） |
| `imx95-harpoon-freertos-industrial.cell` | `usr/share/jailhouse/cells/` | `industrial.bin` 配套的 cell |
| `imx95.cell` | `usr/share/jailhouse/cells/` | **root cell**（给 Linux 用的"总合同"），1680 B |
| `uart-demo.bin` | `usr/share/jailhouse/inmates/` | 串口演示 inmate（顺手可试） |
| `harpoon_set_configuration.sh` | `usr/bin/` | **只是选**用哪套 cell/bin，写进 `/etc/harpoon/harpoon.conf` |
| `harpoon_ctrl` | `usr/bin/` | Harpoon 控制程序 |
| `jh_harpoon.sh` | `usr/share/harpoon/scripts/` | 按 conf 里的路径依次敲 jailhouse 命令 |

### `.cell` 和 `.bin` 分别是什么，为什么不能随便改

```text
.cell  = 配置（谁住哪间房）  → 二进制结构体，由 C 源码编译而成
.bin   = 程序（住进去的人）  → 裸机可执行文件，由 FreeRTOS 源码编译而成
```

**关键事实（2026-09-20 查包确认）**：

| 包里的东西 | 能不能改配置 |
|---|---|
| `.cell` 三个文件 | ❌ **预编译成品**，hex 硬改不现实 |
| `.bin` 三个文件 | ❌ 预编译成品 |
| `harpoon_set_configuration.sh` | ❌ 只是**选**用哪套，不生成 cell |
| `jh_harpoon.sh` | ❌ 只是按 conf 敲 jailhouse 命令 |
| **`.c` / `.h` 源码** | **一个都没有** |

**所以改 console 串口、改 CPU 核数，包内无解，必须走源码。**

### 源码在哪（路径 3 要用）

从包里的 `SCR-REAL-TIME-EDGE-3.3.txt`（NXP Software Content Register，软件组成清单）可以查到每个组件的**出处 git 仓库**：

| 组件 | 版本/分支 | 仓库 |
|---|---|---|
| `imx-jailhouse.git` | `lf-6.12.34_2.1.0` | `https://github.com/nxp-imx/imx-jailhouse` |
| Jailhouse 上游 | — | `https://github.com/siemens/jailhouse`（Siemens，GPL-2.0） |
| `real-time-edge-baremetal` | 2025.04 | `https://github.com/nxp-real-time-edge-sw/real-time-edge-uboot` -b `baremetal-uboot_v2025.04-3.3.0` |
| `real-time-edge-icc` | 1.1 | `https://github.com/nxp-real-time-edge-sw/real-time-edge-icc` |
| **harpoon-apps**（cell + inmate 源码） | tag `harpoon_3.3.0` | `https://github.com/NXP/harpoon-apps` |
| Yocto 层（含 `meta-nxp-harpoon`） | `real-time-edge-3.3.0.xml` | `https://github.com/nxp-real-time-edge-sw/yocto-real-time-edge` -b `real-time-edge-walnascar` |

> **注意**：`SCR` 里**没有单独列出 harpoon-apps**——因为它作为 Yocto 层被整体收进去了。

### 官方用户指南给了准确路径和命令（UG10170）

**Harpoon 用户指南**（`HRPNUG_3.3.pdf`，即 **UG10170 Rev 3.3**，86 页，2025-03-26）把"源码在哪、怎么改"写得很清楚：

| 要知道的事 | 官方原文 / 结论 | 章节 |
|---|---|---|
| **cell 配置源码的确切文件** | cell 配置源码**以补丁形式嵌在 Harpoon meta-layer 的 Jailhouse recipe 里**，文件是 `configs/arm64/imx95-harpoon-freertos.c`（hello_world 与 rt_latency 用例） | §1.4 |
| **root cell 配置** | `configs/arm64/imx95.c`（我们板上那份 `imx95.cell` 就是从它编出来的） | §1.4 |
| **拉源码的准确命令** | `west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww` 然后 `west update` | §6.2 |
| 编译需要哪些仓库 | `FreeRTOS-Kernel`、`CMSIS_5`、`mcux-sdk`（FreeRTOS 应用）；`zephyr`、`hal_nxp`（Zephyr 应用）；工业/音频还要 `GenAVB_TSN`、`rtos-abstraction-layer` | §6.1 |
| **LPUART 归谁配** | `Harpoon provides a custom System Manager configuration that describes the hardware used for its applications, such as the TPM and **LPUART usage for its guest cell**.` | §1.5 |

> ### 🔑 这条最关键：改 console 不只是改 cell
>
> UG10170 §1.5 明确说：**guest cell 用哪一路 LPUART，是写在 Harpoon 定制的那份 SM 配置里的**。
> SM 配置在 `Real-Time Edge SW v3.1 Yocto recipes` 或 `Harpoon meta-layer for i.MX Yocto` 里。
>
> **意味着**：EVK 的 SM 配置把 LPUART3 分给了 guest cell，**Pro 板的 SM 配置没有这一条**。
> 所以想改 console，**要同时改 SM 配置和 cell 配置两处**，不是只改 cell 就行。
> 这也解释了为什么实测里 `pinmux-pins` 完全没有 uart3——**分配权在 SM 手里**。

**路径 3 要做的事**：取 `harpoon-apps` 源码 → 改 `imx95-harpoon-freertos.c` 里的 console 配置（LPUART3 → LPUART4/5）
和 CPU 分配 → **同时处理 SM 配置里的 LPUART 分配** → 用 Yocto 环境交叉编译出新的 `.cell` 和 `.bin`。**以天计。**

### 官方对 CPU 核数的定义（UG10170 §1.4）

| 板子 | inmate 占哪些核 | 官方原文 |
|---|---|---|
| i.MX 8M | CPU3 | `.cpus = { 0b1000, }` |
| i.MX 93 | CPU1 | `.cpus = { 0b10, }` |
| **i.MX 95** | **CPU5（单核）** | `.cpus = { 0b100000, }` |
| 多核 SMP 示例 | （举例是 i.MX 8M 用 2 核） | `.cpus = { 0b1100, }` |

**结论**：**官方 i.MX95 就是 CPU5 单核**，和我们实机测到的**完全一致**。
"2 个核"是额外需求——要改成 `.cpus = { 0b110000, }` 重编 cell，且官方只在 i.MX 8M 上举过 SMP 的例子。

### 一句话总结

> **三个文件都是 Harpoon 包（Real-Time Edge 3.3，EVK 版）里的**，
> 藏在 `rootfs.tar.zst` 内，路径是 `usr/share/jailhouse/cells/` 和 `usr/share/harpoon/inmates/freertos/`。
> `.cell` 是"合同"（哪个核、哪段内存），`.bin` 是"租客"（FreeRTOS 程序）。
> **包内只有编译好的成品、没有源码**，所以改配置必须去 `NXP/harpoon-apps` 取源码重编。

---

## 第五部分：卡住时的排查表

| 现象                                                           | 大概原因                                        | 怎么办                                                              |
| ------------------------------------------------------------ | ------------------------------------------- | ---------------------------------------------------------------- |
| 串口打不开，报 `Access to the port 'COM17' is denied`               | 别的软件占着串口                                    | 关掉其他串口窗口（尤其 MobaXterm 的其他标签页）                                    |
| 板子上电后串口一直没反应                                                 | 串口选错 / 没接好                                  | 挨个 COM 口试；按一下回车看有没有 login                                        |
| 第 3 步 eth0 没有 169.254 地址                                     | 网线没插好 / 网口没起来                               | 确认网线两端插好；`ip link set eth0 up` 后等 5 秒再查                          |
| scp 卡住不动                                                     | 网络不通                                        | 回第 3 步确认 eth0 有地址                                                |
| **抢不到 U-Boot 提示符**                                           | autoboot 只有 2 秒                             | 上电同时就不停按回车；**别用 Ctrl-C**                                         |
| setenv 敲了但 MemTotal 还是 15GB                                  | 停在 U-Boot 太久被看门狗复位了                         | 抢到提示符后立刻敲三条命令                                                    |
| `jailhouse enable` 报错                                        | 内存参数没生效                                     | 检查第 9 步 MemTotal 是不是 4398132                                     |
| `cell load` 报错                                               | 加载地址或文件路径不对                                 | 确认写的是 `-a 0xf0000000`，文件在 `/usr/share/harpoon/inmates/freertos/` |
| `jailhouse cell stats` 报 `execvp: No such file or directory` | 工具目录没加进 PATH                                | 先敲 `export PATH=$PATH:/usr/share/jailhouse/tools`                |
| `jailhouse cell stats` 报 `_curses.error: setupterm`          | 需要真正的终端                                     | 用 SSH 连板子（`ssh -tt root@板子IP`），或先 `export TERM=xterm`            |
| 串口突然完全没反应了                                                   | 之前 Ctrl-C 刷太多，串口登录服务被刷死了                    | 板子没死，改用 SSH 连；或断电重启                                              |
| **cell 是 running、vmexits 在涨，但串口一个字都没有**                      | **console 配在 LPUART3，而 LPUART3 不归 Linux 域** | **正常现象，不是失败**；见「下一步」四条路，走**路径 0.5 或路径 2**                        |
| **`jailhouse console -f` 只有 hypervisor 日志、没有 FreeRTOS 的字**   | inmate 走 MMIO 直写，不经虚拟控制台                    | **正常**，路径 1 已实测无效                                                |
| 逻辑分析仪在 J15-8 上是**一条平直线**                                     | 引脚没切到 UART3 功能（不归 Linux 域）                  | 不是仪器问题，见上文证据 1、2                                                 |
| `grep gpio14 .../pinmux-pins` 搜不到                            | **搜错关键字了**                                  | 该文件里引脚叫 `gpioio14`（无下划线），不是 `gpio14`                             |

---

## 第六部分：原理（先照着做完，再回来看这个）

### 原理速览：真正要吃透的只有 3 块

流程步骤很多，但**大部分细节不用记**。先看这张表，知道哪些该花时间：

| 步骤                              | 要不要懂原理   | 理由                      |
| ------------------------------- | -------- | ----------------------- |
| 传文件进板子                          | ❌ 不用     | 就是拷贝，和方案无关              |
| **U-Boot 设内存参数**                | ✅ **必须** | 整个方案的地基：凭什么 Linux 会让出内存 |
| Linux 三行环境配置                    | ⚠️ 知道大概  | 只为实时性数据好看，不影响跑通         |
| **`modprobe` + `enable`**       | ✅ **必须** | hypervisor 怎么"上位"       |
| **`create` / `load` / `start`** | ✅ **必须** | cell 机制的核心              |
| 传文件的路径、命令拼写、报错处理                | ❌ 不用     | 查文档就行                   |

### 一句话说清这个方案

> **Harpoon 方案就是在 Linux 运行的时候，由 Jailhouse 接管硬件资源（CPU 核、内存、外设），
> 把这些资源重新分配和隔离给不同的操作系统，让它们各自独占分到的那部分、并行运行、互不干扰。**
>
> **分配方案写在 cell 文件里，是静态的——改了要重新生成 cell 再加载。**

**注意主语**：接管硬件的是 **Jailhouse 本体（`jailhouse.ko` 内核模块）**，
`jailhouse` 那个命令行只是操作界面。所以是"**由** Jailhouse 接管"，不是"通过 Jailhouse 接管"。

**为什么必须"Linux 跑着的时候"做**：A55 上原本跑的就是 Linux，
**没有"Linux 还没起来"的时刻**可以给你先安排 FreeRTOS。所以只能在 Linux 起来之后现切。

### "动态加载"到底指什么（容易误解，先说清）

说这个方案是"**运行期动态加载**"时，**"动态"说的是 hypervisor 什么时候被装进去，不是指配置能随便改**。
这两个层面必须分开：

| 说的是什么 | 动态还是静态 | 说明 |
|---|---|---|
| **Jailhouse 什么时候被装进去** | **动态** | Linux 已经跑起来了，才 `modprobe` 把模块插进去。**不用重新烧板子** |
| **资源怎么分配（cell 配置）** | **静态** | `.cpus`、内存段、外设都**编译进 cell 文件**，运行时改不了 |

**对比你熟悉的 M7 方案就清楚了**：

```text
M7 方案：     FreeRTOS 固件打包进 flash.bin，开机时由 SM 加载
              → 上电前就得决定好，改固件要重新烧录              静态

Harpoon 方案： Linux 已经跑起来了，此时才敲命令把 Jailhouse 装进去
              → 系统运行中才加载，不用重新烧板子                动态
```

> **一句话**：**hypervisor 是运行期动态加载的；加载之后，资源分配是静态的。**
>
> **这个"静态"正是本项目的卡点**：Harpoon 包里**只有编译好的 `.cell`，没有源码**，
> 所以想改 console 串口或 CPU 核数，只能去 `harpoon-apps` 取源码重编
> （见后文「路径 3」和「三个文件的来源」）。

### 逐步理解：四条命令各自在干什么

**核心框架**：

> Linux 本来独占整台机器。Harpoon 做的事，是在 Linux 跑着的时候，从它手里"切"出一部分硬件
> （1 个核 + 一段内存 + 一个串口），交给另一个操作系统（FreeRTOS）单独用。切完两边同时跑，互不干扰。
>
> **切蛋糕的是 Jailhouse，切的方案写在 `.cell` 文件里。**

### 第一块：U-Boot 阶段为什么要改内存

**要解决的问题**：FreeRTOS 需要一块自己的内存。如果 Linux 把 16GB 全认了，FreeRTOS 住哪儿？

**做法**：启动 Linux 前先告诉它"你只有 4.375GB"。

```bash
setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
```

格式 **`大小@起始地址`**，逗号分隔两块：1.375GB@2.25GB + 3.0GB@6GB = **共 4.375GB**。

**原理**：U-Boot 去改设备树

```text
U-Boot 读到 jh_root_mem
   ↓ ft_board_setup() 函数
   ↓ fdt_fixup_memory_banks()
把设备树 /memory 节点从"16GB"改成"这两块，共 4.375GB"
   ↓
Linux 启动，只认这 4.375GB
```

**实测验证**：`MemTotal: 4398132 kB`（4.19GB），和 4.375GB 对得上（差的是内核自己留的）。

**为什么必须"Linux 启动前"做**：Linux 一旦起来，物理内存就被它全接管了，之后再想收回来极难。
所以只能在它还没睁眼的时候，就把设备树改掉。

**FreeRTOS 的内存在哪**：**在 Linux 看不到的那部分里**。

```text
0x80000000 ───────────── Linux 第一块（1.375GB）
0x90000000
   ...
0xE8000000 ───────────── 第一块结束
   ...
0xF0000000 ───────────── ★ FreeRTOS 在这（Linux 碰不到）
   ...
0x180000000 ──────────── Linux 第二块（3.0GB）
```

**为什么还有 `jh_clk`**：四个参数里只有**两个真正关键**：

| 参数                              | 作用                           | 不做会怎样                                  |
| ------------------------------- | ---------------------------- | -------------------------------------- |
| **`kvm-arm.mode=nvhe`**         | 让 Linux 自带的 KVM **不占用**虚拟化硬件 | **Jailhouse 起不来**（两个 hypervisor 抢 EL2） |
| **`cpuidle.off=1`**             | 关掉 CPU 深度休眠                  | **分给 FreeRTOS 的核睡死，叫不醒**               |
| `kvm.enable_virt_at_load=false` | 配套第一条                        | 同上                                     |
| `clk_ignore_unused`             | 别自动关"没人用"的时钟                 | 某些外设时钟被关                               |

**关键认知**：**ARM 的虚拟化扩展（EL2）是独占资源**。Linux 自己的 KVM 想用 EL2，Jailhouse 也要用 EL2——
**必须让 Linux 的 KVM 让开**。这就是 `nvhe` 的用意。

### 第二块：`enable` —— hypervisor 怎么上位

`modprobe` **只是把工具装好，还没虚拟化任何东西**。**`enable` 才是"变身"的那一刻。**

**enable 做的四件事**：

```text
1. 保存 Linux 当前状态（各核上下文、异常向量）
2. 把 Linux 自己"降级"成一个 cell → 它就是 root cell
3. 给所有核装上 EL2 的异常向量 ← 从此 CPU 有了"hypervisor 模式"
4. 建立各 cell 的 stage-2 页表 ← 隔离的物理基础
```

**实测输出印证**：

```text
Initializing processors:
 CPU 1... OK   CPU 0... OK   CPU 2... OK
 CPU 5... OK   CPU 4... OK   CPU 3... OK     ← 每个核都装了 hypervisor 入口
Initializing unit: irqchip / ARM SMMU / PVU IOMMU / PCI
Activating hypervisor                        ← 这一刻开始，Linux 不再是最高权限
```

**原理：ARM 的四个特权层级**

```text
EL0  用户程序
EL1  内核（Linux 内核、FreeRTOS 都在这层）
EL2  ★ hypervisor 层
EL3  安全监控（TrustZone / ATF）
```

**隔离怎么实现的**：

```text
guest 执行特权操作
   ↓ 硬件自动陷入 EL2      ← 注意：不是软件检查，是硬件触发
hypervisor 判断："这操作归不归你？"
   ↓ 归 → 放回去继续
   ↓ 不归 → 拦下，记一次 vmexit
```

**这是性能好的根本原因**：不逐条检查，靠硬件在"越界的那一刻"自动触发。

**为什么 Jailhouse 这么小**：**它不需要自己的驱动栈**。板子初始化（DDR、时钟、外设）**全由 Linux 做完了**，
hypervisor 直接接管。所以代码量只有几万行。

官方原话：`Jailhouse assigns hardware resources to a guest OS instead of virtualising them.`
—— **分配，而不是虚拟化**：不做设备模拟、不做指令翻译，**硬件整块切开各拿各的**。

### 第三块：`create` / `load` / `start`

```bash
jailhouse cell create <cell文件>                    # ① 读配置，划出一间房
jailhouse cell load freertos <bin> -a 0xf0000000    # ② 把程序搬进去
jailhouse cell start freertos                       # ③ 把核交出去
```

| 命令 | 干什么 | 关键点 |
|---|---|---|
| `create` | 读 `.cell`，在 hypervisor 里建一个 cell 结构 | **名字是这里从文件里读出来的** |
| `load` | 把 bin 搬到指定物理地址 | `-a` 必须和 cell 配置、bin 链接地址**三者一致** |
| `start` | 把分配的核从 Linux 手里拿走，让核跳到 inmate 入口 | 之后两个系统**同时跑** |

> **纠正一个常见误解**：**不是 `load` 创建了 `freertos`**。
> 实测输出 `Created cell "freertos"` 出现在 **`create`** 那一步——
> 名字**来自 `.cell` 文件里的 `name` 字段**（文件偏移 `0x08` 开始 32 字节，已解码确认）。
> `load` / `start` 里的 `freertos` 都是在**引用这个已建好的 cell**。

**`-a` 为什么要三者一致**：

```text
bin 编译时链接到 0xf0000000
   ↓ 代码里的跳转、数据访问都按这个地址算
load 时 -a 也必须是 0xf0000000
   ↓ 否则搬过去，代码一跳转就跑到别处 → 跑飞
cell 配置里给 inmate 的内存段也要覆盖这个地址
   ↓ 否则 hypervisor 不让你写
```

**`0xf0000000` 是 DDR，不是 TCM**：i.MX95 的 DDR 从 `0x80000000` 起，`0xf0000000` = 3.75GB 处。
（TCM 是 M7 专用的小容量片上内存，地址完全不同。）

### `vmexit` 是什么

**guest 做了不该做的事 → 硬件拦下 → 交给 hypervisor → 处理完放回。一次往返 = 一个 vmexit。**

实测：`vmexits_total 1517 / vmexits_mmio 1515 / vmexits_management 2`

**为什么 mmio 这么多**：FreeRTOS 在**反复写串口寄存器**（LPUART3 地址 `0x42570000`）。

> **反直觉的点**：`.cell` 里已经把 LPUART3 分给它了，为什么写它还 vmexit？
>
> **因为 MMIO 访问天然要陷入**——设备内存的映射在 stage-2 里是"不可直接访问"的，
> hypervisor 会模拟这次访问。所以 **vmexit 多不代表配错了**，反而证明 inmate 真的在访问外设。

### 整张图

```text
【离线】编出两样东西
   .cell  → "合同"：写清哪个核、哪段内存、哪个串口归 FreeRTOS
   .bin   → "租客"：FreeRTOS 程序本身

【U-Boot】趁 Linux 没起来，先把内存改小（16GB → 4.375GB）

【Linux】装 Jailhouse → enable（自己降级成 root cell，hypervisor 上位）
   → create（划房间）→ load（搬程序）→ start（交核）

【运行】两边同时跑；FreeRTOS 碰不该碰的 → 硬件拦 → vmexit
```

### 和板子上电流程的关系（把这个也串起来）

Harpoon 不是凭空能切的，它**站在启动链的最后一环**：

```text
上电 → SM 定规矩（写 TRDC/RDC 隔离，决定谁能用哪些外设）
     → 只放 A55 的 CPU0 出去
     → Linux 起来（只拿到 SM 给的那部分）
     → Harpoon 在 SM 定的规矩之内，再切一次
```

**Harpoon 不能违反 SM 定的规矩。** 它是"二房东"，房子是大房东（SM）先分好的。
详见 [[20-领域/芯片与平台-i.MX95/i.MX95多核与程序启动.md|i.MX95 多核与程序启动]]「上电流程与 SM 的角色」。

### Harpoon 到底在干什么

**一句话：Linux 正用着 6 个 A55 核，Harpoon 让其中 1 个核让出来单独跑 FreeRTOS，两边同时运行互不打扰。**

三个名词，一个租房比喻：

| 名词 | 是什么 | 类比 |
|---|---|---|
| **hypervisor** | 硬件"二房东"，让 Linux 以为独占硬件，实际由它分配 | 二房东 |
| **cell** | 一份资源分配单（`.cell` 文件），写明哪个核、哪段内存归谁 | 租房合同 + **房间** |
| **inmate** | 住进 cell 的程序，这里就是 FreeRTOS | 租客 |

NXP 用的这个二房东程序叫 **Jailhouse**。原理细节见
[[20-领域/芯片与平台-i.MX95/Jailhouse分区式虚拟化原理.md|Jailhouse 分区式虚拟化原理]]。

#### ⚠️ 一个容易理解错的点：cell 里没有"操作系统"

**cell 只是一个资源容器（房间），里面是空的。** 常见误解是以为 `create` 建出了"一个操作系统环境"，
于是会想"能不能进这个 cell 里装驱动、跑命令"——**不行**。

| 命令 | 做的事 | 类比 | **不是**在做什么 |
|---|---|---|---|
| `create` | 按 cell 文件**划出资源容器**（哪个核、哪段内存、哪些外设） | 划房间 | ❌ 不是"安装操作系统" |
| `load` | 把程序**搬到容器里的指定物理地址** | 搬家具 | ❌ 不是"装系统" |
| `start` | 把分配的核**从 Linux 手里拿走**，让核跳到程序入口执行 | 开门营业 | ❌ 不是"按名字启动某个系统" |

**房间一直是同一个房间，`load` 换的只是"住进去的人"。**

> **这也正好解释本项目的现象**：我们 `load` 了官方的 `rt_latency.bin`，cell 起来了、
> `vmexits_mmio` 也在涨——**说明程序真的在跑**。但它的串口打印出不来，
> 这跟"cell 里有没有操作系统"**毫无关系**，而是 **cell 配置里声明的那个串口（LPUART3）
> 在 Pro 板上不归 Linux 域**。
>
> **房间通了，出问题的是房间里的水管没接上。**

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

| 参数                              | 干嘛的                       | 不设会怎样                       |
| ------------------------------- | ------------------------- | --------------------------- |
| `kvm-arm.mode=nvhe`             | 让 Linux 自带的 KVM 用 NVHE 模式 | 虚拟化硬件被 KVM 占着，Jailhouse 起不来 |
| `kvm.enable_virt_at_load=false` | 加载 KVM 时别立刻接管虚拟化硬件        | 同上，两边抢                      |
| `cpuidle.off=1`                 | 关掉 CPU 深度休眠               | 分给 FreeRTOS 的核睡过去，叫不醒       |
| `clk_ignore_unused`             | 别自动关掉"没人用"的时钟             | 有些外设时钟被关，起不来                |

**为什么要 `run bsp_bootcmd`**：这是板子原厂的"启动 Linux"命令。设完参数必须立刻执行它，因为停在 U-Boot 超时会被看门狗复位。

---

## 相关

- 两条流程的本质区别、设计取舍 → [[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
- 当时上板的完整记录和原始输出 → [[10-项目/FRDM-IMX95-PRO/Harpoon验证与复现|Harpoon 验证与复现]]
- 判定"厂商包能不能用手头板子"的方法 → [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse 与 Harpoon 的分层与判定]]
- 引脚所有权怎么查、`UNCLAIMED` 怎么读 → [[20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md|i.MX95 引脚控制：IOMUXC 与 RGPIO 的分工]]
- 要发给 NXP 的问题（已按实测 + UG10170 更新）→ [[10-项目/IMX95-EVK/待向NXP确认的问题清单.md|待向 NXP 确认的问题清单]]
- 全部资料索引 → [[10-项目/IMX95-EVK/资料清单表.md|资料清单表]]

## 附一：官方文档的关键结论（UG10170 Rev 3.3）

**Harpoon 用户指南**就是 `HRPNUG_3.3.pdf`（**UG10170** Rev 3.3，86 页，2025-03-26），
在 `C:\Users\chen\Desktop\资料\IMX95\`，抽取文本在 `build\pdf-text\HRPNUG_3.3.txt`。

| 我们关心的事 | 官方原文 / 结论 | 章节 |
|---|---|---|
| **官方支持哪些板子** | 8M Mini EVKB / 8M Nano EVK / 8M Plus EVK / i.MX 93 EVK / **i.MX 95 15x15 LPDDR4x EVK** / **i.MX 95 19x19 LPDDR5 EVK**——**没有 FRDM-IMX95-PRO** | §3.1 |
| **i.MX95 给 inmate 几个核** | **CPU5 单核**：`.cpus = { 0b100000, }` | §1.4 |
| 想用 2 个核 | `For a multicore (SMP) cell, two cores can be used.`（举例是 i.MX 8M `.cpus = { 0b1100, }`） | §1.4 |
| **cell 配置源码文件** | `configs/arm64/imx95-harpoon-freertos.c`（hello_world / rt_latency）、`configs/arm64/imx95.c`（root cell） | §1.4 |
| **guest cell 的 LPUART 归谁配** | **Harpoon 定制版 SM 配置**里（`... such as the TPM and LPUART usage for its guest cell`） | §1.5 |
| 官方启动方式 | `setenv jh_root_dtb imx95-19x19-evk-harpoon.dtb` + `run jh_mmcboot` | §4.2 |
| 官方跑应用方式 | `harpoon_set_configuration.sh freertos latency` + `systemctl start harpoon` | §4.6 |
| **官方预期有输出** | `hello_world` 应在 inmate cell console 打印 `INFO: hello_func : Hello world.` / `tic tac tic tac ...` | §4.3 |
| 拉源码命令 | `west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww` | §6.2 |
| 已知问题 | HRPN-1191（i.MX95 EVK 上 `jh_mmcboot` 偶发启动失败自动重启）；**没有"inmate 无输出"这一条** | §5 |

**三条要点**：

1. **核数我们做对了** —— 官方就是 CPU5 单核，和实测一致。
2. **"无输出"是异常，不是设计如此** —— 官方说应该有输出，且没列为已知问题。
3. **改 console 要动两处** —— cell 配置 **和** 定制版 SM 配置，只改 cell 可能不够。

## 附二：资料版本与手册对应关系（容易搞混，务必认准）

| 手册编号 | 对应板子 | 调试口器件 | J22 是什么 |
|---|---|---|---|
| **UM12527** | **FRDM-IMX95-PRO**（**我们手上的板**） | **CH9114F (U67)** | **USB Type-C 调试口** |
| **UM12022** | IMX95LPD5EVK-19（**不是**我们的板） | FT4232H (U70) | **I2C 排针**（8-pin） |

> ⚠️ **本文早期版本犯过的错**：把 `UM12022`（EVK 手册）里 "J22 只引出 UART1/2/7" 的说法
> 套到了 Pro 板上。**这是错的** —— UM12527 §2.19 明确写着 Pro 板的 J22 是 **Type-C + CH9114F 四通道 USB 转串口**，
> A55/M33/M7 三个核的串口都从这**一个 Type-C** 出去，电脑上认成 4 个 COM 口（官方建议四个都打开，
> 因为 A55/M33/M7 的端口映射**不固定**）。
>
> **推论**：**J22 没有裸针脚可夹**，逻辑分析仪要夹的是 **J15（2×20 EXPI 排针，UM12527 §2.20）**。

| 文档 | 是什么 | 位置 |
|---|---|---|
| **HRPNUG_3.3.pdf** = **UG10170** Rev 3.3 | **Harpoon 用户指南**（86 页） | `C:\Users\chen\Desktop\资料\IMX95\` |
| **UM12527** | **FRDM-IMX95-PRO** 板手册 | 同上 |
| **UM12022** | IMX95LPD5EVK-19（EVK）板手册 | 同上 |
| 原理图 **SPF-95794_B1** | Pro 板原理图 | `...\FRDM-IMX95-PRO_DESIGNFILES\Schematic\` |
