---
type: 知识库
scope: 芯片与平台-i.MX95
doc_type: 原理
status: 已整理
evidence: 源码确认
tags: [虚拟化, Jailhouse, 安全与隔离, 多核与异构, 排查方法]
updated: 2026-09-21
---

# Jailhouse 分区式虚拟化原理

> 通用虚拟化原理（Type1/Type2、CPU/内存/外设怎么虚拟化）→ [[20-领域/虚拟化与隔离/Hypervisor虚拟化原理.md|Hypervisor 虚拟化原理]]
>
> 这篇讲 **Jailhouse 具体怎么落地**：cell 是什么、四条命令背后做了什么、`.cell` 文件里到底存了什么。
> 本文的 cell 字段解析是**对本项目实际 cell 文件逐字节解开**得到的（`源码确认`），不是转述文档。

## 这篇知识解决什么问题

Jailhouse 的命令看着简单，但第一次用会有一堆疑问：

- `cell create` 之后名字为什么就叫 `freertos` 了？谁起的？
- `-a 0xf0000000` 这个地址哪来的、为什么是这个值？
- `.cell` 是二进制，**怎么知道里面配了什么**？
- `vmexits_mmio` 是什么、为什么一直在涨？
- root cell 和 inmate cell 有什么区别？

这篇逐条回答，并且给出**自己解 cell 文件的完整方法**。

## 一、Jailhouse 是什么

**出处**：Siemens 开源的**分区式 hypervisor**，GPL-2.0。NXP 在 `imx-jailhouse` 仓库里做板级适配。

**类型**：**Type 1（裸金属型）**，但形态特殊：

```text
它不是"先启 hypervisor 再启 OS"，
而是：
  1. Linux 正常启动（这时 Linux 独占全部硬件）
  2. 加载 jailhouse 内核模块
  3. jailhouse enable —— hypervisor 把自己装进内存，接管硬件
  4. 从此 Linux 变成"root cell"，只是众多 cell 中的一个
```

**这个设计的巧妙处**：hypervisor **不需要自己的驱动栈**。板子的初始化（DDR、时钟、外设）全由 Linux 做完，hypervisor 直接接管。所以 Jailhouse 代码量很小（几万行量级），启动也快。

**官方原话**（UG10170 §1.4）：

> `Jailhouse is a simple hypervisor that assigns hardware resources to a guest OS instead of virtualising them. For instance, a CPU core is statically assigned to a specific guest and is not shared with other guests.`

两个关键词：

| 词                  | 含义                      |
| ------------------ | ----------------------- |
| **assign**（分配）     | 不做模拟，硬件**整块分**给某个 guest |
| **statically**（静态） | 分了就不变，不共享、不超卖           |

## 二、cell / inmate / root cell

| 名词             | 是什么                                   | 类比      |
| -------------- | ------------------------------------- | ------- |
| **hypervisor** | 分区程序本身                                | 二房东     |
| **cell**       | 一份**资源分配单**（`.cell` 文件），写明哪些核/内存/外设归谁 | 租房合同    |
| **root cell**  | **第一个 cell**，就是 Linux 自己              | 房东自住的房间 |
| **inmate**     | 住进其他 cell 的程序（RTOS）                   | 租客      |

**root cell 的特殊之处**：

1. 它是 **`jailhouse enable` 时创建的第一个 cell**
2. 它**拥有 hypervisor 没分出去的全部资源**
3. 它的配置文件（`imx95.cell`）还**额外描述 hypervisor 自己要占的内存**
4. 文件签名的 magic 不同（见下面第五节）

**"inmate" 这个词**：字面是"同住者/囚犯"。Jailhouse 用它指"住在非 root cell 里的 guest 程序"。

## 三、四条命令背后做了什么

以 i.MX95 上跑 FreeRTOS 为例：

```bash
modprobe jailhouse                                        # ① 装模块
jailhouse enable /usr/share/jailhouse/cells/imx95.cell    # ② 激活 hypervisor
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell   # ③ 建 cell
jailhouse cell load freertos <bin> -a 0xf0000000          # ④ 装程序
jailhouse cell start freertos                             # ⑤ 启动
```

### ① `modprobe jailhouse`

把 `jailhouse.ko` 装进 Linux。这个模块提供 `/dev/jailhouse` 设备节点，用户态的 `jailhouse` 命令通过它和内核通信。

> **注意**：此时**还没有虚拟化任何东西**，只是把工具装好了。

### ② `jailhouse enable <root.cell>`

**这一步是真正"变成 hypervisor"的时刻**。做了几件事：

1. **保存当前 Linux 的状态**（各核的上下文、异常向量等）
2. **把 Linux 自己"降级"成一个 cell**（root cell）
3. **给所有核装上 EL2 的异常向量**（hypervisor 入口）
4. **建立各 cell 的 stage-2 页表**（隔离的基础）
5. **把自己锁进内存**（防止被 Linux 换出）

实测输出（本项目）：

```text
Initializing Jailhouse hypervisor v0.12 (393-gcda91277-dirty) on CPU 1
Code location: 0x0000ffffc0200800        ← hypervisor 自己被放在哪
Page pool usage after early setup: mem 71/993, remap 0/131072
Initializing processors:
 CPU 1... OK   CPU 0... OK   CPU 2... OK
 CPU 5... OK   CPU 4... OK   CPU 3... OK    ← 每个核都装上 hypervisor 入口
Initializing unit: irqchip / ARM SMMU v3 / ARM SMMU / PVU IOMMU / PCI
Activating hypervisor                       ← 这一刻开始，Linux 不再是最高权限
```

> `Page pool` 那两行是 hypervisor **自己的内存池**，用来存页表等元数据。数字是"已用/总量"。

### ③ `jailhouse cell create <inmate.cell>`

读 `.cell` 文件，在 hypervisor 里**建一个数据结构**描述这个新 cell。

**关键**：**cell 的名字是这一步从 `.cell` 文件里读出来的**，不是你敲命令时指定的。

实测输出：

```text
Created cell "freertos"     ← 名字来自 .cell 文件里的 name 字段
```

**所以之后 `load` / `start` 里的 `freertos` 都是在引用这个已建好的 cell。**

> **验证方法**：如果 create 的是 `imx95-harpoon-freertos-industrial.cell`，名字**也是 `freertos`**
> —— 因为那个文件的 `name` 字段同样写着 `freertos`（本项目实测确认）。

### ④ `jailhouse cell load <name> <bin> -a <addr>`

**把二进制文件的内容，搬到 inmate 内存的指定物理地址。**

| 参数 | 含义 |
|---|---|
| `<name>` | 要往哪个 cell 装（`create` 时定的名字） |
| `<bin>` | 要装的文件 |
| `-a <addr>` | **address**，装到哪个物理地址 |

> **`-a` 这个地址必须和两处对上**：
> 1. `.cell` 里给 inmate 的内存段（否则 hypervisor 拒绝或写错地方）
> 2. **bin 编译时的链接地址**（否则搬过去执行就跑飞）

### ⑤ `jailhouse cell start <name>`

把分配给这个 cell 的**核从 Linux 手里拿走**，让核跳到 inmate 入口开始执行。

实测效果：

```text
ID      Name        State      Assigned CPUs    Failed CPUs
0       imx95       running    0-4                        ← Linux 少了一个核
1       freertos    running    5                          ← 5 号核归 FreeRTOS
```

**`start` 之后两个系统就同时跑了**，各自的核互不干扰。

## 四、vmexit 是什么

**定义**：guest 做了**它不该做的事**，硬件触发异常，控制权交给 hypervisor，hypervisor 处理完再放回去。**一次这样的往返叫一个 vmexit。**

**对 Jailhouse（分区式）来说，vmexit 主要是两类**：

| 类型 | 触发原因 | 本项目实测 |
|---|---|---|
| **`vmexits_mmio`** | guest 访问了**不在它 stage-2 映射里**的地址（通常是外设寄存器） | **1515** |
| `vmexits_management` | guest 主动请求 hypervisor（管理类操作） | 2 |
| `vmexits_total` | 总数 | 1517 |

**为什么 mmio 这么多**：FreeRTOS 在**反复写串口寄存器**（LPUART3 的寄存器地址 `0x42570000` 段）。

**这里有个容易搞混的点**：`.cell` 里**已经把 LPUART3 分给了这个 cell**（见第六节解码结果），
那为什么写它还会 vmexit？

> 因为 **MMIO 访问本身天然要陷入**。stage-2 页表对**设备内存**的映射通常是"不可直接访问"的，
> hypervisor 会**模拟**这次访问（读出值/写入值再放回），这样才能做设备虚拟化的控制。
> 所以 **vmexit 多不代表配置错了**，反而证明 **inmate 真的在访问外设**。

## 五、`.cell` 文件怎么自己解开

这是最实用的一节。`.cell` 是二进制，但**结构固定**，可以直接解。

### 5.1 文件头

Jailhouse 的 cell 文件**没有加密**，就是 C 结构体的二进制 dump。结构定义在开源 Jailhouse 的
`hypervisor/include/jailhouse/cell-config.h` 里，开头是：

```c
struct jailhouse_cell_desc {
    char signature[4];      /* "JHCL" = cell, "JHSY" = system(root) cell */
    __u16 revision;
    __u16 check;
    char name[32];          /* ★ cell 名字就存在这里 */
    __u32 flags;
    ...
};
```

**本项目三个文件实测**（`源码确认` + `实机验证`）：

| 文件 | signature | revision | name 字段 |
|---|---|---|---|
| `imx95-harpoon-freertos.cell` | `JHCL` | 588 | **`freertos`** |
| `imx95-harpoon-freertos-industrial.cell` | `JHCL` | 588 | **`freertos`**（和上面同名！） |
| `imx95.cell`（root） | **`JHSY`** | 595 | （root cell 无名字） |

> **这就是"名字哪来的"的答案** —— 文件偏移 `0x08` 开始的 32 字节就是名字。
>
> 顺带注意：**两个 inmate cell 的名字都是 `freertos`**。所以如果你先 create 了
> `-freertos.cell`，再 create `-freertos-industrial.cell`，**名字会冲突**。

### 5.2 用 Python 解（可直接跑的脚本）

```python
import struct
d = open("imx95-harpoon-freertos.cell", "rb").read()

print("signature:", d[0:4].decode())                    # JHCL / JHSY
print("revision :", struct.unpack('<H', d[4:6])[0])
print("name     :", d[8:40].split(b"\x00")[0].decode())

# 扫全文，挑出"像外设/内存地址"的 32 位值
KNOWN = {0x42570000: "LPUART3", 0x424f0000: "TPM4", 0x44320000: "TPM2",
         0x48000000: "GIC", 0xf0000000: "inmate 内存段"}
for off in range(0x28, len(d) - 4, 4):
    v = struct.unpack('<I', d[off:off+4])[0]
    if v in KNOWN:
        print(f"  0x{off:03x}  {v:#010x}  {KNOWN[v]}")
```

> **本项目的脚本**：`F:\project\Learning\RTOS\build\tools\decode_cell.py`，
> 输出 `build\cell-decode2.txt` 和 `build\cell-final.txt`。

### 5.3 实测解码出的内容

**头部计数字段**（两个 inmate cell 对比）：

| 字段 | `-freertos.cell` | `-freertos-industrial.cell` | 说明 |
|---|---|---|---|
| `name` | `freertos` | `freertos` | 名字相同 |
| `num_memory_regions` | **8** | **8** | 内存段数量 |
| `num_irqchips` | **16** | **24** | 中断控制器条目数（industrial 用了更多中断） |
| `num_pci_devices` | 2 | 2 | 虚拟 PCI 设备（IVSHMEM 通信） |
| `console.type` | 1 | 1 | 控制台类型 |
| 文件大小 | 772 B | 1028 B | 差值主要来自中断表 |

**文件里出现的外设地址**（和 i.MX95 SDK 头对照后确认身份）：

| 地址 | 是什么 | 依据 |
|---|---|---|
| **`0x42570000`** | **LPUART3** ← **inmate console 就是它** | SDK `LPUART3_BASE` |
| `0x424f0000` | TPM4 | SDK `TPM4_BASE` |
| `0x44320000` | TPM2 | SDK `TPM2_BASE` |
| `0x445d0000` / `0x445d1000` | 待确认（成对出现，疑似同一外设的两段） | — |
| `0x20480000` | 待确认 | — |
| **`0xf0000000`** | **inmate 内存段** ← `-a` 用的就是这个 | 与实机 `-a 0xf0000000` 一致 |
| `0x48000000` | GIC（中断控制器） | i.MX95 GIC 基址 |
| `0xc0000000` / `0xc0100000` / `0xc0200000` | 三块 64KB 区域（**成对出现，偏移固定 0x100000**，疑似 IVSHMEM 共享内存段） | 由数据形态推断 |

**root cell（`imx95.cell`，1680 字节）**：签名 `JHSY`，里面能找到 `0x44380000`（**LPUART0**，
就是 Linux 的 console）和 `0x80000000`（DDR 起始）—— **印证"root cell 描述的是 Linux 看到的世界"**。

> **`0xf0000000` 不是 TCM，是 DDR**：i.MX95 的 DRAM 从 `0x80000000` 开始，
> `0xf0000000` = 3.75GB 处，在 DDR 范围内。（TCM 是 M7 专用的小容量片上内存，地址完全不同。）
>
> **而且它落在 Linux 那两块内存之外**（Linux 拿的是 `0x90000000` 起 1.375GB + `0x180000000` 起 3GB），
> 所以 Linux 碰不到这块 —— **这是设计好的隔离**。

> ⚠️ **一个诚实的说明**：上面这些地址是**扫描文件、挑出"像地址的值"再和 SDK 对照**得到的，
> 属于 **`源码确认`（数据）+ 推断（字段归属）**。
> 具体"哪个偏移是 `phys_start`、哪个是 `size`"，需要对照 `cell-config.h` 里
> `struct jailhouse_memory` 的定义才能逐一对准。**本笔记不把推断写成事实。**
> 要精确知道，走 5.4 拿源码。

### 5.4 更省事的办法（如果有源码）

`.cell` 是由 **C 源码编译**出来的：

```bash
# 源码文件（UG10170 §1.4 给了确切路径）
configs/arm64/imx95-harpoon-freertos.c    # inmate cell
configs/arm64/imx95.c                     # root cell

# 拿源码的办法
west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww
cd hww && west update
```

**有源码时**直接看 `.c` 文件，比解二进制清楚得多。本文的解码方法是**拿不到源码时的替代手段**。

### 5.5 板上自带的检查工具

```bash
jailhouse config check  <file>     # 检查 cell 配置合法性
jailhouse config create <file>     # 生成系统/root cell 配置（不是 inmate cell）
jailhouse config collect           # 收集当前硬件配置
jailhouse hardware check           # 检查硬件是否支持虚拟化
```

> **注意**：`config create` 生成的是 **root/system cell**（`imx95.cell` 那一类），
> **不能生成 inmate cell**。所以改 inmate 配置仍要源码重编。

## 六、root cell 与 inmate cell 的区别

| | **root cell** | **inmate cell** |
|---|---|---|
| 文件签名 | `JHSY` | `JHCL` |
| 谁创建 | `jailhouse enable` 时自动 | 手动 `cell create` |
| 内容 | Linux 能用的**全部剩余资源** + **hypervisor 自己的内存** | 精确指定的核/内存/外设 |
| 数量 | 只能一个 | 可以多个 |
| 例子 | `imx95.cell` | `imx95-harpoon-freertos.cell` |

**实测 `imx95.cell`**：1680 字节，签名 `JHSY`，revision 595，里面能找到 `0x44380000`（LPUART0，就是 Linux console）
和 `0x80000000`（DDR 起始）等地址 —— **印证了"root cell 描述的是 Linux 看到的世界"**。

## 七、Linux 侧那几行环境配置在干什么

跑 Jailhouse 之前，官方脚本（`jh_harpoon.sh`）会让 Linux 做几件事：

```bash
# 1) 限制 CPU 从休眠恢复的延迟（每核）
for c in 0 1 2 3 4 5; do
  echo 1 > /sys/devices/system/cpu/cpu$c/power/pm_qos_resume_latency_us
done

# 2) 调频策略设成性能优先
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

# 3) 松开 rpmsg（Linux 与其他核的通信模块）
echo c0100000.rpmsg-ca55 > /sys/bus/platform/drivers/imx-rpmsg/unbind
```

| 行 | 作用 | 不做的后果 |
|---|---|---|
| 1 | 防止核睡太深，**保证唤醒及时** | 核可能进深度休眠，**实时性变差** |
| 2 | 防止降频 | CPU 降频会**影响 rt_latency 测量** |
| 3 | 让 Linux 放开对核间通信的控制 | Linux 可能和被分走的核抢通信资源 |

**重要区分**：

- **1、2 行是"为了让实时性数据好看"**，跟能不能跑通无关
- **3 行是资源让渡**，理论上必要；但**本项目实测报 `No such device`**——
  说明该驱动在当前启动方式下根本没加载，**没有要松开的东西**，不影响运行

## 八、常见误区

- **"`load` 那一步创建了 cell"**：错。**`create` 就创建了，名字也是那时从 `.cell` 读的**。`load` 只是往里装程序。
- **"`-a` 可以随便写"**：错。必须和 `.cell` 的内存段 + bin 的链接地址**三者一致**。
- **"`0xf0000000` 是 TCM"**：错。那是 DDR 地址（i.MX95 的 DDR 从 `0x80000000` 起）。
- **"vmexit 多说明出问题了"**：错。**MMIO 访问天然产生 vmexit**，多说明 inmate 在积极访问外设。
- **"inmate 和 cell 是一回事"**：cell 是"房间"（资源集合），inmate 是"住进去的程序"。一个 cell 可以换不同的 inmate。
- **"root cell 也是一份普通 cell 配置"**：它的签名（`JHSY`）和内容都不同，还额外描述 hypervisor 自身内存。
- **"cell 文件是加密的/看不懂"**：**没有加密**，就是 C 结构体的二进制 dump，结构公开。

## 九、适用范围与依据

- **适用范围**：Jailhouse 的通用机制（cell 模型、四条命令、vmexit、文件格式）适用于所有平台。
  本文第五节的**具体地址值只适用于 i.MX95 / 本项目的 cell 文件**。

- **依据等级**：
  - cell 模型、"assign instead of virtualise"、CPU5 分配：**官方资料明确说明**（UG10170 §1.4）
  - 文件头结构（signature / revision / name 字段）：**源码确认**（Jailhouse 开源 `cell-config.h`）
  - 三个 `.cell` 文件的 signature / revision / name / 计数字段、文件内出现的外设地址与 SDK 对照：
    **源码确认 + 实机验证**（脚本 `decode_cell.py`，输出 `cell-final.txt`）
  - **"哪个偏移对应哪个字段"属于推断**：本文只给能验证的部分，字段归属未逐一对齐，已在上文标注
  - `vmexits_mmio` 1515 / `vmexits_management` 2：**实机验证**
  - LPUART 分配写在 SM 配置里：**官方资料明确说明**（UG10170 §1.5）

- **项目证据**：
  - 完整复现过程与原始日志：[[10-项目/FRDM-IMX95-PRO/Harpoon复现|Harpoon 复现：手把手操作]]
  - 方案层面对比：[[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
  - 踩过的坑（`UNCLAIMED` 误读、引脚域归属）：[[20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md|i.MX95 引脚控制]]

- **参考资料**：
  - [Jailhouse 官方仓库（Siemens）](https://github.com/siemens/jailhouse)
  - [NXP imx-jailhouse](https://github.com/nxp-imx/imx-jailhouse)
  - [ELCE 2016 Jailhouse Tutorial](http://events17.linuxfoundation.org/sites/events/files/slides/ELCE2016-Jailhouse-Tutorial.pdf)
  - [Harpoon 用户指南 UG10170 Rev 3.3](https://www.nxp.com.cn/docs/en/user-guide/UG10170.pdf)

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/虚拟化与隔离/Hypervisor虚拟化原理.md|Hypervisor 虚拟化原理]]
- [[20-领域/芯片与平台-i.MX95/i.MX95上Jailhouse与Harpoon的分层与判定方法.md|i.MX95 上 Jailhouse 与 Harpoon 的分层与判定方法]]
- [[20-领域/芯片与平台-i.MX95/Harpoon方案完整流程.md|Harpoon 方案完整流程]]
