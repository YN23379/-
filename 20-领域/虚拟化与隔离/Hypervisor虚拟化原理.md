---
type: 知识库
scope: 虚拟化与隔离
doc_type: 原理
status: 已整理
evidence: 官方资料
tags: [虚拟化, 安全与隔离, 多核与异构, 架构]
updated: 2026-09-21
---

# Hypervisor 虚拟化原理

> 这篇讲**虚拟化这件事本身的原理**：hypervisor 是什么、分几类、靠什么机制实现隔离。
> 不绑定某块板子或某个芯片，是离开 i.MX95 也能用的通用知识。
>
> 具体到 Jailhouse 怎么用（cell / inmate / 命令行）→ [[20-领域/芯片与平台-i.MX95/Jailhouse分区式虚拟化原理.md|Jailhouse 分区式虚拟化原理]]

## 这篇知识解决什么问题

"Hypervisor 是所有虚拟化技术的核心"这句话经常见，但**它到底凭什么能隔离、凭什么一个 CPU 能同时跑两个操作系统**，多数资料讲不到点上。

这篇要回答四个问题：

1. hypervisor 到底处在哪一层、管什么？
2. Type 1 和 Type 2 差在哪，为什么嵌入式都用 Type 1？
3. **CPU、内存、外设这三样，分别是怎么被"虚拟化"的？**
4. 全虚拟化、半虚拟化、分区式，这三条技术路线有什么本质区别？

## 一、hypervisor 是什么，在哪一层

**全称**：hypervisor，也叫 **VMM**（Virtual Machine Monitor，虚拟机监视器）。

**位置**：夹在**物理硬件**和**操作系统**之间的一层软件。

```text
        ┌──────────┐  ┌──────────┐
        │  VM 1    │  │  VM 2    │     来宾操作系统（Guest OS）
        │ (Linux)  │  │ (RTOS)   │
        └────┬─────┘  └─────┬────┘
             └──────┬───────┘
              ┌─────▼──────┐
              │ hypervisor │            ← 就是这一层
              └─────┬──────┘
        ┌───────────▼───────────┐
        │   CPU / 内存 / 外设    │        物理硬件
        └───────────────────────┘
```

**它干的活**：把一份物理硬件**切成几份**，让多个操作系统**以为自己独占**硬件。

**一个很好用的类比**（IBM developerWorks 的说法）：

> **hypervisor 之于操作系统，就像操作系统之于进程。**
>
> 操作系统把 CPU、内存这些资源虚拟化给**进程**用；hypervisor 是干同样的事，只不过对象不是进程，而是**整个操作系统**。

**为什么需要它**：早期服务器利用率极低（有统计说服务器只有 5% 时间在工作），虚拟化能把一台机器当几台用，省硬件、省电、省运维。**这是服务器领域的动机**。

嵌入式领域的动机不太一样，主要是两个：

| 动机 | 说明 |
|---|---|
| **功能安全 / 信息安全隔离** | 把关键功能（仪表、刹车）和非关键功能（娱乐）隔开，一个崩了不影响另一个 |
| **实时性** | Linux 抖动大，把实时任务隔离到单独的核上跑 RTOS |

## 二、Type 1 与 Type 2

| | **Type 1（裸金属型）** | **Type 2（宿主型）** |
|---|---|---|
| 跑在哪 | **直接跑在硬件上** | 跑在**另一个操作系统**之上 |
| 层次 | 硬件 → hypervisor → VM | 硬件 → 宿主 OS → hypervisor → VM |
| 性能 | 高（少一层） | 低（多一层） |
| 典型产品 | Xen、VMware ESXi、**Jailhouse** | QEMU、VirtualBox、VMware Workstation |
| 用在哪 | 服务器、嵌入式 | 个人电脑做实验 |

**判据**：看**它下面还有没有操作系统**。有就是 Type 2。

> **注意一个常见的分类混乱**：不少中文资料把 **KVM 归为 Type 1**。IBM 那篇原文确实这么写
> （"KVM 本身是一个基于操作系统的 hypervisor"）。但严格说 KVM 是**内核模块**，
> 加载在 Linux 里，它更接近"混合型"。

**更准确的划分是三分类**

| 类型 | 特征 | 例子 |
|---|---|---|
| Type 1 裸金属 | 直接跑硬件，无宿主 OS | Xen、ESXi、**Jailhouse** |
| Type 2 宿主型 | 依赖宿主 OS，作为普通进程 | QEMU、VirtualBox |
| **混合型** | 作为内核模块集成进 OS 内核 | **KVM**、KVM+Xen |


> **对本项目的意义**：**Jailhouse 是明确的 Type 1**，但它有个特别之处——**它是加载进 Linux 内核的模块**，
> 却**不依赖 Linux 来跑**。加载后 hypervisor 接管硬件，Linux 自己变成"第一个 guest"。
> 见 [[20-领域/芯片与平台-i.MX95/Jailhouse分区式虚拟化原理.md|Jailhouse 分区式虚拟化原理]]。

## 三、三个资源分别怎么被虚拟化

hypervisor 要虚拟化的东西归为三类：**CPU、内存、外设（I/O）**。三者的手法完全不同。

### 3.1 CPU 虚拟化

**核心矛盾**：CPU 只有一套特权指令和寄存器，多个 OS 都要用。

**要解决**：让 guest OS 执行特权指令时**不能真的执行**，得被 hypervisor 拦下来。

**三条路线**：

| 路线 | 做法 | 代价 |
|---|---|---|
| **全虚拟化**（Full） | guest 的敏感指令被硬件/二进制翻译**偷偷拦下**，guest 完全不知情 | 需要硬件支持，或有翻译开销 |
| **半虚拟化**（Para） | **改 guest 的代码**，把特权操作换成主动调用 hypervisor（hypercall） | 要改 OS 源码，但性能好 |
| **分区式**（Partitioning） | **不做虚拟化，直接把核分给 guest**，一个核只归一个 guest | 核数固定，不能超卖 |

> **"敏感指令"是理解全虚拟化的关键**：指那些在用户态和内核态行为不同的指令。
> 传统 x86 有些敏感指令在用户态不触发异常，导致"经典虚拟化漏洞"。
> Intel VT-x / AMD-V 就是为此加的硬件支持。

**ARM 上的对应机制**：

ARMv8-A 引入了 **Exception Level（EL）**：

```text
EL0  用户态
EL1  内核态（Linux 内核、RTOS 都跑这）
EL2  hypervisor 层        ← 虚拟化的关键
EL3  安全监控（TrustZone / ATF）
```

**hypervisor 跑在 EL2**，guest OS 跑在 EL1。guest 执行特权操作 → 硬件自动陷入 EL2 → hypervisor 处理。

**这就是"硬件辅助虚拟化"在 ARM 上的形态**，对应 x86 的 VT-x。i.MX95 的 A55 支持 EL2。

**两种模式（ARM 特有，容易搞混）**：

| 模式 | 含义 |
|---|---|
| **VHE**（Virtualization Host Extensions） | EL1 和 EL2 的寄存器合并，**宿主内核可以直接当 hypervisor 用**，减少切换开销 |
| **NVHE**（Non-VHE） | 传统的 EL1/EL2 分离 |

> 你在 i.MX95 上看到的 `kvm-arm.mode=nvhe` 就是指定用 NVHE 模式——
> 因为 Jailhouse 要自己占 EL2，不能让 KVM 用 VHE 混进 EL1 来抢。

### 3.2 内存虚拟化

**核心矛盾**：guest OS 以为自己在管物理内存，其实那是"假的物理内存"。

**两层地址翻译**：

```text
guest 虚拟地址 (VA)
   ↓ guest 自己的页表（guest OS 管）
guest 物理地址 (IPA, Intermediate Physical Address)   ← guest 以为这是"物理"
   ↓ hypervisor 的页表（★ 关键：stage-2 页表）
真实物理地址 (PA)
```

**关键机制叫 stage-2 翻译**（x86 上叫 EPT/NPT）：

- **stage-1**：guest OS 自己管的页表（VA → IPA）
- **stage-2**：**hypervisor 管的页表**（IPA → PA）

**stage-2 就是隔离的命门**：hypervisor 通过 stage-2 页表规定"这个 guest 只能访问哪些真实物理地址"。**访问了不归它的地址 → 硬件触发异常 → 陷入 hypervisor**。

> **这正是 Jailhouse 记 `vmexits` 的来源**。FreeRTOS 写串口寄存器（MMIO 地址），
> 那地址不在它的 stage-2 映射里 → 被拦 → 记一次 vmexit。

**优化**：两级查表要查两次太慢，硬件加了 **TLB 合并 / 影子页表** 等手段。

### 3.3 外设（I/O）虚拟化

**核心矛盾**：设备是物理的，一个串口/网卡怎么给多个 guest 用。

**三条路线**：

| 路线 | 做法 | 性能 | 例子 |
|---|---|---|---|
| **全模拟** | hypervisor **完全用软件模拟**一个假设备 | 最差 | QEMU 模拟网卡 |
| **半虚拟化** | guest 装**专用驱动**，直接和 hypervisor 对话 | 好 | virtio |
| **直通**（Passthrough） | **整个设备直接分给一个 guest**，不做模拟 | 最好（接近原生） | VFIO、**Jailhouse** |

> **Jailhouse 走的是第三条：直通 / 分区**。它不做设备模拟，而是**把一个串口整个给某个 cell**。
> 好处是性能几乎无损耗；代价是**设备不能共享**（一个串口只能归一个 cell）。

## 四、三条技术路线的本质区别

这是全篇最重要的一张表：

| | **全虚拟化** | **半虚拟化** | **分区式** |
|---|---|---|---|
| 代表 | KVM、VMware | Xen（早期）、Lguest | **Jailhouse** |
| guest 知不知道被虚拟化 | 不知道 | **知道**（改了代码） | 知道 |
| 硬件是否被模拟 | 模拟 | 部分模拟 | **完全不模拟** |
| 硬件能否共享 | 能（分时） | 能 | **不能**（整块分走） |
| 开销 | 中 | 低 | **极低** |
| 实时性 | 差 | 较好 | **好** |
| 资源利用率 | 高 | 高 | 低（不能超卖） |

**一句话记住区别**：

> - **全虚拟化**："我模拟一套假的给你，你随便用"
> - **半虚拟化**："我改改你，让你配合我"
> - **分区式**："我直接把硬件切开，各拿各的，谁也别碰谁的"

**分区式的哲学**（Jailhouse 官方原话）：

> `Jailhouse is a simple hypervisor that assigns hardware resources to a guest OS instead of virtualising them.`

**"assign instead of virtualise"** —— 分配，而不是虚拟化。

**代价**：不能超卖。你有 6 个核、2 个 guest，最多就是切开分，不能让 2 个 guest 各以为自己有 6 个核。

**收益**：**开销极小、实时性极好、隔离是硬件级的**。这正是嵌入式实时场景要的。

## 五、为什么嵌入式实时场景偏爱分区式

对照需求看：

| 需求 | 分区式为什么合适 |
|---|---|
| **实时性** | 不做模拟，没有额外开销；核是独占的，不会被别的 guest 抢 |
| **确定性** | 核、内存、外设都是静态分配的，**行为可预测** |
| **隔离强度** | 靠硬件 stage-2 页表，不靠软件检查 |
| **认证** | 代码量小（Jailhouse 号称只有几万行），容易做安全认证 |
| **启动快** | 没有设备模拟的初始化过程 |

**反过来，分区式不适合**：

- 要跑很多 guest（核不够分）
- 要超卖资源（云服务器场景）
- 要动态迁移 guest

## 六、常见误区

- **"hypervisor 就是个虚拟机软件"**：它本质是**资源分配器 + 隔离器**，不是"模拟器"。分区式连模拟都不做。
- **"虚拟化一定要模拟硬件"**：错。直通和分区都不模拟。
- **"KVM 是 Type 2"**：KVM 本身是内核模块（混合型），但**它加载后 Linux 内核就变成了 hypervisor**，这点又像 Type 1。分类要看他强调哪个角度。
- **"有硬件虚拟化支持才能做虚拟化"**：软件也能做（二进制翻译），只是性能差。硬件支持（VT-x / ARM EL2）是**为了性能和安全**。
- **"guest 访问非法地址会被 hypervisor 检查出来"**：不是"检查"，是**硬件直接触发异常**。hypervisor 只是处理异常，不负责逐个检查。
- **把 EL2 和 TrustZone 搞混**：EL2 是虚拟化层，EL3 才是安全世界。两者解决不同问题，可以同时存在。

## 七、适用范围与依据

- **适用范围**：虚拟化通用原理。EL0–EL3、VHE/NVHE、stage-2 是 **ARMv8-A 特有**的表述，x86 对应概念为 Ring/VT-x、EPT。
- **依据等级**：
  - hypervisor 定义与分层、Type 1/2 划分、hypervisor 内部要素（hypercall、页映射器、调度器）：**官方资料明确说明**，来源 IBM developerWorks《剖析 Linux hypervisor》；
  - 三分法（含混合型）、分区式"assign instead of virtualise"、Jailhouse 定位：**官方资料明确说明**，来源 Jailhouse 官方文档；
  - EL0–EL3 与 VHE/NVHE：**官方资料明确说明**，来源 ARM 架构手册；
  - 三条技术路线对比表：综合整理，判定依据已分别注明。

- **参考资料**：
  - [Hypervisor 详解（CSDN 转载 IBM developerWorks《剖析 Linux hypervisor》）](https://blog.csdn.net/m0_49448331/article/details/115790827)
  - [Jailhouse 官方文档（Siemens）](https://github.com/siemens/jailhouse)
  - [Hypervisor 类型（Type1 / Type2 / 混合型）](https://tangzhangyin.blog.csdn.net/article/details/160204342)
  - [虚拟化（Hypervisor）技术详解](https://blog.csdn.net/weixin_45264425/article/details/136316641)
  - [ELCE 2016 Jailhouse Tutorial](http://events17.linuxfoundation.org/sites/events/files/slides/ELCE2016-Jailhouse-Tutorial.pdf)

- **项目证据**：
  - 实机上 `vmexits_mmio` 远多于其他类型，印证"非法 MMIO 访问会被硬件拦截"：[[10-项目/FRDM-IMX95-PRO/Harpoon复现|Harpoon 复现：手把手操作]]
  - `kvm-arm.mode=nvhe` 的实测背景：[[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
