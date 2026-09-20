---
type: 知识库
scope: i.MX95
doc_type: 原理
status: 已整理
evidence: 实机验证
tags: [i.MX95, 启动, 多核与异构, 编译构建]
updated: 2026-09-18
---

# Harpoon 方案完整流程

> 一句话：Harpoon 不是"另一条打包烧录的流水线"，而是**另一种运行架构**——
> 你原来那条 IAR→imx-mkimage→flash.bin→UUU 的流程属于「启动期静态加载」，
> Harpoon（A55 上跑 FreeRTOS）属于「Linux 运行期动态加载」。
>
> **要照着做的话看这篇**：[[10-项目/IMX95-EVK/Harpoon复现|Harpoon 复现：手把手操作]]
> （每步标了在电脑/板子-U-Boot/板子-Linux 哪个环境操作）。本篇只讲"为什么这样设计"。
>
> **官方依据**：本篇的架构描述以 **Harpoon 用户指南 UG10170 Rev 3.3**（`HRPNUG_3.3.pdf`，86 页）为准，
> 官方文档没写到的部分（Pro 板实机行为）单独标证据等级。

## 〇、官方文档怎么说（UG10170 摘要）

先摆官方定义，后面各节再展开。这一节的内容全部来自 **UG10170 Rev 3.3**，属**官方资料明确说明**。

| 事项 | 官方原文 / 结论 | 章节 |
|---|---|---|
| Jailhouse 是什么 | `Jailhouse is a simple hypervisor that assigns hardware resources to a guest OS instead of virtualising them. For instance, a CPU core is statically assigned to a specific guest and is not shared with other guests.` | §1.4 |
| inmate 是什么 | `Harpoon-apps is a set of real-time application running on Jailhouse's inmate cell. It is built on top of Zephyr or FreeRTOS, using zephyr and/or MCUXpresso drivers.` | §1.3 |
| cell 配置里写什么 | CPU 核、中断线、内存区域、虚拟 PCI 设备 | §1.4 |
| **i.MX 95 给 inmate 几个核** | **CPU5 单核**：`.cpus = { 0b100000, }` | §1.4 |
| 想用 2 个核怎么办 | `For a multicore (SMP) cell, two cores can be used.`（原文举例是 i.MX 8M：`.cpus = { 0b1100, }`） | §1.4 |
| **cell 配置源码在哪** | Harpoon meta-layer 的 Jailhouse recipe 补丁里：`configs/arm64/imx95-harpoon-freertos.c`（hello_world 与 rt_latency 用例）、`configs/arm64/imx95-harpoon-zephyr.c`、`configs/arm64/imx95.c`（root cell） | §1.4 |
| **guest cell 的 LPUART 归谁配** | `Harpoon provides a custom System Manager configuration that describes the hardware used for its applications, such as the TPM and LPUART usage for its guest cell.` | §1.5 |
| SM 配置在哪 | `directly embedded in the Real-Time Edge SW v3.1 Yocto recipes or in the Harpoon meta-layer for i.MX Yocto` | §1.5 |
| **官方支持哪些板子** | i.MX 8M Mini EVKB / 8M Nano EVK / 8M Plus EVK / i.MX 93 EVK / **i.MX 95 15x15 LPDDR4x EVK** / **i.MX 95 19x19 LPDDR5 EVK**——**没有 FRDM-IMX95-PRO** | §3.1 |
| 官方怎么启动 | U-Boot 里 `setenv jh_root_dtb imx95-19x19-evk-harpoon.dtb` + **`run jh_mmcboot`** | §4.2 |
| 官方怎么跑应用 | `harpoon_set_configuration.sh freertos latency` + **`systemctl start harpoon`** | §4.6 |
| 官方预期输出 | inmate cell console 上应打印 `INFO: hello_func : Hello world.` / `tic tac tic tac ...` | §4.3 |
| 应用源码怎么拉 | `west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww` | §6.2 |
| 已知问题 | HRPN-1191：i.MX 95 EVK 上用默认 BSP 启动命令开机、重启后再 `run jh_mmcboot`，会启动失败并自动重启（无功能影响，再执行一次即可） | §5 |

**两条最重要的推论**：

1. **核数没有争议**：官方 i.MX95 就是 **CPU5 单核**给 inmate，和实机测到的一致。
   "2 个核"是**额外需求**，要自己改 `.cpus` 位图（`0b110000`）并重编 cell。
2. **改 console 不止改 cell**：UG10170 §1.5 明说 **guest cell 用哪路 LPUART 写在定制版 SM 配置里**。
   所以 EVK 的 cell 拿到 Pro 板上不通，**光改 cell 可能不够，SM 配置也要一起改**。

> ⚠️ 官方文档（UG10170 §5）里**没有**"inmate 无输出"这条已知问题，
> 而 §4.3 明确写了应该有输出 → **我们遇到的确实是异常状态，不是设计如此**。

## 一、先对齐：你的 M7 流程 vs Harpoon 流程

| 阶段 | 你的 M7 流程（启动期静态加载） | Harpoon 方案（运行期动态加载） |
|---|---|---|
| 编译 FreeRTOS | IAR 编译 → `hello.bin`（链接到 **M7 TCM 地址**） | ARM GCC 编译 → inmate `xxx.bin`（链接到 **A55 cell 内存，入口 0xf0000000**） |
| 编译系统固件 | SM 源码编译出 SM bin | 不需要（Linux 起来后，hypervisor 由内核模块加载） |
| 打包 | `imx-mkimage` 把 ELE/SM/M7 固件/BL31/U-Boot 打成 `flash.bin` | **不需要把 FreeRTOS 打进容器**——它不是启动链的一部分 |
| 烧录 | `flash.bin` 改成 UUU 认的名字 → UUU 发送 | **同一条 UUU 流水线**，只是烧的是含 Jailhouse 的 Linux 镜像（Pro 板原厂镜像本身就带） |
| FreeRTOS 何时上电运行 | **复位后立即**：SM 按启动配置把固件加载进 TCM 并 release M7 | **Linux 跑起来之后**：手动/脚本用 jailhouse 工具加载并启动 |
| 谁启动 FreeRTOS | SM（System Manager，启动容器里的组件） | root cell 里的 Linux 用户态进程（`jailhouse` 命令） |
| 占用资源 | 整个 M7 核 + 它的 TCM/外设（启动前就划好） | 从**正在跑 Linux 的 A55** 里划出 1 个核 + 一段内存 + 指定外设 |

**为什么 M7 能"打包进 flash.bin"而 A55 不能？**
M7 是从核，SM 在启动早期（Linux 之前）就能加载并 release 它，所以固件必须作为**启动容器的组件**静态烧录。
而 Harpoon 要的是"从正在跑 Linux 的 A55 里抽一个核出来"，Linux 已经占着所有资源，
只能由 Linux 里的 hypervisor **运行时**做这件事——这就是两条流程本质不同的根源。

## 二、离线准备阶段（PC 侧）

| 步骤 | 核心动作 | 关键细节 |
|---|---|---|
| 1. 取得运行环境 | 需要一个带 Jailhouse 的 Linux rootfs + 内核 | Pro 板**原厂镜像自带 Jailhouse**（内核 6.18.2 配套的模块/工具/cell）；Harpoon 包里的 Jailhouse 是 6.12.34 版，**与 Pro 内核不匹配，不能用** |
| 2. 取得 cell 配置 | `imx95.cell`（root cell）+ `imx95-harpoon-freertos.cell`（inmate cell） | `.cell` 是 C 结构体编译出的二进制配置，声明 CPU/内存/中断/外设归谁；root cell 那份还定义了 hypervisor 自身的内存（`0xffc00000+0x400000`） |
| 3. 取得 inmate 二进制 | FreeRTOS 应用（如 `hello_world.bin`） | **必须按 inmate cell 的内存布局链接**（入口 `0xf0000000`）——这就是为什么不能直接用 M7 的 hello.bin：链接地址完全不同 |
| 4. 控制脚本（可选） | `jh_harpoon.sh`、`harpoon_ctrl`、`harpoon.conf` | 它们只是把第 3 节那串命令包起来；**注意**包内 `harpoon.conf` 默认指向 audio 变体（i.MX95 没有这个 cell/bin），正式用法是先跑 `harpoon_set_configuration.sh freertos latency` 重新生成 |

> **第 2~3 步的东西具体从哪来？** 见 [[10-项目/IMX95-EVK/Harpoon复现|复现手册]]
> 的「三个文件的来源与用途」一节。一句话：**三个文件都在 Harpoon 包的 `rootfs.tar.zst` 里**，
> 路径分别是 `usr/share/jailhouse/cells/` 和 `usr/share/harpoon/inmates/freertos/`。
> cell 是二进制成品，**源码在 [NXP/harpoon-apps](https://github.com/NXP/harpoon-apps)，不在安装包里**。

## 三、烧录阶段

和你原流程**完全一样**：镜像经 `imx-mkimage` 打包 → 改名 → UUU 发送（或 SD 卡持久化）。
区别只在打包清单里**没有** FreeRTOS 固件。Pro 板直接用原厂 `flash_a55` 容器即可。

> 澄清一个容易误解的点： Harpoon 的"部署"主要不是烧录，而是**往正在运行的 Linux 里传几个文件**
> （cell 配置 + inmate 二进制）。本次复现实测用 `scp` 走网络最省事（板子 eth0 默认 DOWN，先
> `ip link set eth0 up` 拿到 169.254.x 链路本地地址）；串口 base64 是备用通道。

## 四、板上运行阶段（核心）

完整顺序（等价于 `jh_harpoon.sh start`，实测逐条跑通）：

```text
① U-Boot 阶段：规定 Linux 只能用哪几块内存 + 设内核参数（必须在做任何 Jailhouse 事之前）
   setenv jh_root_mem 0x58000000@0x90000000,0xc0000000@0x180000000
   setenv jh_clk kvm.enable_virt_at_load=false cpuidle.off=1 clk_ignore_unused kvm-arm.mode=nvhe
   run bsp_bootcmd
   → 起来后 MemTotal 从 ~15.8GB 降到 ~4.19GB，
     正好等于 jh_root_mem 两块之和（1.375 + 3.0 = 4.375GB）

② Linux 阶段：把实时性相关环境准备好
   for c in 0..5: echo 1 > .../cpu$c/power/pm_qos_resume_latency_us   # 限制 CPU 恢复延迟
   echo performance > .../scaling_governor                            # 调频策略（可选）
   echo c0100000.rpmsg-ca55 > /sys/bus/platform/drivers/imx-rpmsg/unbind

③ 激活 hypervisor（root cell）
   modprobe jailhouse
   jailhouse enable /usr/share/jailhouse/cells/imx95.cell
   jailhouse cell list        # → 0 imx95 running 0-5（Linux 从"6 个核"变成受管）

④ 创建并启动 inmate cell
   jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
   jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/xxx.bin -a 0xf0000000
   jailhouse cell start freertos

⑤ 验证（三条独立证据）
   jailhouse cell list          → 1  freertos  running  5     （Linux 只剩 5 个核）
   jailhouse cell stats freertos → vmexits_total 增长、vmexits_mmio 占绝大多数
   nproc                        → 5
```

## 五、关键细节（容易踩的坑）

1. **`jh_root_mem` 规定的是"Linux 能用的内存"，必须在 Linux 启动前设**。U-Boot 读它，通过
   `ft_board_setup` 重写设备树的 `/memory` 节点，把 Linux 的可用内存**限定**在这些块里。
   必须在启动前做的原因：Linux 一旦起来就会把物理内存全认下来，之后再想收回来就晚了。
   **推论（由实测推断，未逐行读 U-Boot 源码确认）**：两块之和 4.375GB ≈ 实测 MemTotal 4.19GB，
   说明其余内存 Linux 看不到，是留给 Jailhouse 划给 inmate 的；而 inmate 入口 `0xf0000000`(3.75GB)
   正好落在 Linux 第一块内存（2.25~3.625GB）之外——**这片区域 Linux 碰不到，所以能安全带外来程序**。
2. **inmate 的入口地址 `-a 0xf0000000` 不是随手写的**，它是 inmate cell 配置里给这块内存的起始地址；
   二进制必须按这个地址链接，否则 start 后直接跑飞。
3. **inmate 控制台是独立串口**：Harpoon FreeRTOS cell 配置里控制台是 LPUART3（`0x42570000`），
   **不占 Linux 的串口**（root cell 的 debug console 是 LPUART1）。

   > **2026-09-20 实测推翻"换个串口接上就能看"的想法**：
   > LPUART3 在这块 Pro 板上**不归 Linux 域**，所以不是"没引出"这么简单，而是**引脚控制权不在 Linux 手里**：
   > - `/proc/tty/driver/*`：Linux 域只有 **LPUART0 / LPUART4 / LPUART5** 三个实例，**没有 LPUART3**
   > - pinmux 表（129 行）里 **uart 相关只有 uart1rxd/txd、uart2rxd/txd**，**没有任何 uart3 引脚**
   > - 该表路径是 `scmi_dev.8-scmi-pinctrl-imx`，说明 Linux 是**经 SCMI 请 SM 代配引脚**的，SM 不给就配不了
   >
   > → **inmate 写 LPUART3 寄存器有效（`vmexits_mmio` 在涨），但信号出不了芯片。**
   > 可行方向是用 Linux 域已注册且空闲的 **LPUART4（`0x42590000`）/ LPUART5（`0x425A0000`）**，
   > 但 cell 是预编译二进制，改 console 必须取源码重编或问 NXP 要配置。
   > 详见 [[10-项目/IMX95-EVK/Harpoon复现|复现手册「下一步」一节]]。
4. **`jh_clk` 里那串参数不是装饰**：`kvm-arm.mode=nvhe`、`kvm.enable_virt_at_load=false` 保证 KVM
   不跟 Jailhouse 抢虚拟化硬件；`cpuidle.off=1` 防止核进深度休眠导致 inmate 的核失联。
5. **一切默认不持久**：`setenv` 没 `saveenv`（板子环境区 CRC 还是坏的），cell/inmate 都在 RAM 里，
   **断电即全部恢复**——复现是零风险的，但要做持久化得走 U-Boot `saveenv` 或改 DTB 三条路之一。
6. `jailhouse cell stats` 需要终端（curses）且要把 `/usr/share/jailhouse/tools` 加进 PATH，
   否则报 `execvp: No such file or directory` / `_curses.error`。

## 六、停止与恢复

```text
jailhouse cell shutdown freertos   # 停 inmate
jailhouse cell destroy  freertos   # 释放 cell
jailhouse disable                  # 关 hypervisor，资源还给 Linux
modprobe -r jailhouse
# 彻底恢复：断电重启（未 saveenv，无持久改动）
```

## 七、证据等级

| 结论 | 等级 | 出处 |
|---|---|---|
| `jh_harpoon.sh start` 的命令顺序 | 源码确认 | 读包内 `jh_harpoon.sh` 与 `harpoon.conf` |
| 完整命令序列能在 Pro 板跑通 FreeRTOS inmate | **实机验证** | `jailhouse cell list` 显示 `1 freertos running 5`，见 [[10-项目/IMX95-EVK/Harpoon验证与复现.md|项目实证]] |
| inmate 控制台 = LPUART3、入口 0xf0000000 | 源码确认 | 两份 cell 配置（`-freertos.cell`/`-industrial.cell`）内容一致 |
| Pro 原厂自带 Jailhouse、Harpoon 包版本不匹配 | **实机验证** | `modinfo jailhouse`、包内 manifest 对比 |
| `jh_root_mem` 改写 `/memory` 的机制 | 官方资料明确说明 | U-Boot `ft_board_setup`（`imx95_frdm.c`）源码 + Harpoon 文档 |

## 相关

- 判定"包能不能用于手头板子"的方法 → [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|Jailhouse 与 Harpoon 的分层与判定]]
- 上板全记录与原始输出 → [[10-项目/IMX95-EVK/Harpoon验证与复现.md|Harpoon 验证与复现]]
- A55 上跑 FreeRTOS 的三种形态 → [[20-领域/芯片与平台-i.MX95/i.MX95在A55上运行FreeRTOS的路径.md|A55 运行 FreeRTOS 的路径]]
- 对照的 M7 启动方式 → [[20-领域/芯片与平台-i.MX95/启动与烧录/STM32与i.MX95启动和开发流程对比.md|STM32 与 i.MX95 启动对比]]
