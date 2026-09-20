---
type: 项目档案
scope: FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）
doc_type: 原理
status: 待验证
evidence: 实机验证
tags:
  - 协议
  - 启动
  - 安全与隔离
  - 存储
updated: 2026-09-17
---

# 理解：i.MX95 启动逻辑、资源隔离与权限

> 2026-09-17 精简：理解-01/02/03 本来是一个主题的连续三篇（互相交叉引用），合成一篇。对应验收要求 1（启动逻辑）、2（资源隔离与权限）、5（群组分布），3/4 给出初稿。

## 目录

- 一、理解-01：i.MX95 启动逻辑、资源隔离与权限（FRDM-IMX95-PRO）
- 二、理解-02：i.MX95 上电启动全流程（超详细）
- 三、理解-03：外设归属与权限矩阵（FRDM-IMX95-PRO / mx95frdm-pro 配置）

---

## 一、理解-01：i.MX95 启动逻辑、资源隔离与权限（FRDM-IMX95-PRO）

## 理解-01：i.MX95 启动逻辑、资源隔离与权限（FRDM-IMX95-PRO）

> 类型：项目档案 / 理解文档。板型：FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）。
> 对应要求：1（启动逻辑）、2（资源隔离与权限）、5（群组分布）；3、4（地址空间/内存分布）给出初稿与待补清单。
> 证据标注：`官方文档` / `源码可以确认` / `实机验证得到` / `待验证`。
> 主要一手来源：
> - 板级 SM 配置：`F:\project\Learning\RTOS\tools\imx-sm-src\imx-sm-master\configs\other\mx95frdm-pro.cfg`（1023 行）
> - U-Boot 源码：`F:\project\Learning\RTOS\tools\uboot-imx-source\board\freescale\imx95_frdm\`
> - 实机串口日志：`F:\project\Learning\RTOS\build\logs\`（COM17=A55、COM19=M33/SM）

### 〇、先建立三层心智模型（不然后面全是名词）

i.MX95 不是一个"CPU 加外设"的芯片，而是一个**多核 + 多域 + 权限管理器**的系统。理解它要分三层：

| 层 | 谁在管 | 关键概念 | 与本项目的关系 |
|---|---|---|---|
| ① 启动与安全层 | Boot ROM + ELE（EdgeLock Enclave） | 启动介质选择、AHAB 容器、签名校验、生命周期 | 决定"上电后谁先跑" |
| ② 系统管理层 | **M33 上跑的 SM（System Manager）** | LM（逻辑机）、DOM（域）、资源 OWNER/ACCESS、TRDC/RDC、SCMI、LMM | 决定"哪个核能用哪个外设" |
| ③ 计算层 | A55×6 / M7 / M33 本体 | 地址空间、TCM/OCRAM/DRAM、异常级 | 决定"代码放哪、怎么跑" |

一句话：**A55 上跑的 Linux 或 FreeRTOS 并不是"老大"——它能不能碰某个外设，由 ② 层决定。** 这也是历史项目里
"remoteproc 报 `lmm(1) not under Linux Control`、换 root 也没用"的根本原因。

---

### 一、要求 1：启动逻辑（谁先启动？怎么启动？其他核怎么启动？）

#### 1.1 冷启动的完整链条

```text
上电
 └─ Boot ROM（片内固化，A55 复位后最先执行）
     ├─ 依据 SW4 引脚决定启动介质（x010=eMMC / x011=SD / x001=USB串行下载 / x100=QSPI）
     ├─ 从介质读出启动容器（imx-boot-*.bin-flash_a55，即 flash.bin）
     ├─ 由 ELE 做 AHAB 容器校验（签名/生命周期）
     └─ 把容器内的镜像释放给各核：
         ├─ M33 的 SM 固件  → 先跑（它是"操作系统之上的操作系统"）
         └─ A55 的 SPL      → 并行/随后跑
             └─ SPL 载入 BL31(ATF) → BL31 载入 U-Boot → U-Boot 载入 Linux
```

**实机证据（同一次冷启动抓到）**：

| 串口 | 内容 | 说明 |
|---|---|---|
| COM19（M33/SM） | `DDR OEI: SOC MIMX95(B0), Board mx95lp5` / `IMX+DMEM load ... TRAINING complete ... done, err = 0` / `Hello from SM (Build 819, Commit c450f539, Mar 10 2026)` | **DDR 训练由 SM 侧固件（DDR OEI）完成**，早于 A55 的 SPL |
| COM17（A55） | `U-Boot SPL 2025.04-g99518e6b6f20` → `NOTICE: BL31: v2.12.0 (lf-6.18.2-1.0.0)` → `U-Boot 2025.04` → `Linux 6.18.2` | A55 链：SPL→ATF→U-Boot→Linux |

- `源码可以确认`：SM 配置里 `BOARD DEBUG_UART_INSTANCE=2` → SM 的调试口是 **LPUART2**，这就解释了为什么 SM 日志在 COM19 而不是 COM17。
- `实机验证得到`：COM17 上 U-Boot 打印 `Loading Environment from MMC... bad CRC, using default environment`、`Model: NXP FRDM-IMX95-PRO board`、`DRAM: 15.8 GiB` —— DRAM 容量能在 U-Boot 阶段报出，说明**DDR 已在 SM 侧初始化完成**。

#### 1.2 "其他核怎么启动"——有三套机制，别混为一谈

##### (a) SM 的逻辑机启动序（`源码可以确认`）

`mx95frdm-pro.cfg` 里每个 LM 有 `boot=` 字段，构成 SM 的启动顺序表：

```text
LM0  name="SM",  rpc=none,  boot=1, did=2, safe=feenv   ← 第 1 个（SM 自身）
LM1  name="M7",  rpc=scmi,  boot=2, skip=1, did=4, safe=seenv
LM2  name="AP",  rpc=scmi,  boot=3, skip=1, did=3, default
```

读法（**已由 SM 官方配置文档 `sm\doc\config.md` 330–388 行确认，此处更正早前猜测**）：
- `boot=N` = **SM 启动时按顺序启动该 LM 的次序**（0=不自动启动；可用 `LMM_Boot()`/`SCMI_LmmBoot()` 后续启动）；
- `skip=1` = `bootSkip`，"**容器里没有该 LM 的镜像时不要报错**"（**不是**"跳过启动"）；
- 另有 `rtime`（微秒级延迟，用于给实时核让路）与 `start[]/stop[]` 上下电命令序列，详见
  `2026-09-17-理解-02-上电启动全流程超详细.md`。

##### (b) 显式电源/时钟上电序列（`源码可以确认`）——这才是"怎么启动"的细节

M7（LM1）：

```text
PD_M7   start=1, stop=2      ← 先开 M7 所在电源域
CPU_M7P start=2, stop=1      ← 再放 CPU 出复位
```

A55（LM2，6 核）：

```text
VOLT_ARM  start=1|1, stop=9      ← 先建立 ARM 电压（1|1 表示某种条件组合）
PD_A55P   start=2,   stop=8
PERF_A55  start=3|3              ← 性能档位（对应工作频率）
CPU_A55C0 start=4
CPU_A55C1..C5  stop=7..2         ← 各核独立的停/启位
CPU_A55P  stop=1
```

结论：**"启动一个核"= 电压 → 电源域 → 性能档位（频率）→ 释放 CPU 复位**，顺序不能反。这也解释了为什么改 SM 配置时如果把 A55 需要的资源挪走，会出现 WDOG3→FCCU 复位 LM2（历史项目实测现象）。

##### (c) 运行期热启动（Linux/其他核发起，`源码可以确认` + `实机验证得到`）

- 各 LM 通过 **SCMI** 与 SM 通信：`SCMI_AGENT0 name="M7"`（MU9）、`SCMI_AGENT1 name="AP-S"`（MU1）、`SCMI_AGENT2 name="AP-NS"`（MU3）。
- SM 配置里 `LMM_2 ALL` 出现在 **LM1(M7) 的 API 列表**里 → **M7 有权控制 LM2（即 A55）的启动/停止**；反过来历史项目实测 A55 控制不了 M7（`lmm(1) not under Linux Control`）——因为权限是**单向**给的。
- 所以"谁拉起 M7"这件事的答案取决于 SM 配置给谁开了 LMM API，而不是取决于谁先上电。

#### 1.3 三种启动别混淆（自查表）

| 说法 | 主导者 | 触发时机 | 本项目实例 |
|---|---|---|---|
| 冷启动 | Boot ROM + ELE | 上电/复位 | SPL→BL31→U-Boot→Linux 全链 |
| LM 启动 | M33 上的 SM | SM 启动序列或 SCMI 请求 | SM 拉起 A55 链、M7 |
| 热启动 | Linux 等主体 | 运行期 | `remoteproc` 想拉起 M7（被权限挡住） |

---

### 二、要求 2：资源隔离与权限分配

#### 2.1 四层权限模型（从抽象到硬件）

| 层 | 概念 | 在配置文件里的写法 | 硬件落点 |
|---|---|---|---|
| 1 | **域 Domain（DID）** | `DOM0 name="ELE", did=0`、`DOM12 name="V2X", did=12` | 总线上的 domain ID / 安全属性 |
| 2 | **逻辑机 LM** | `LM0/LM1/LM2`（SM / M7 / AP） | 每个 LM 有自己的 EENV（执行环境）与安全态 |
| 3 | **资源归属** | `OWNER` / `ACCESS` / `READONLY` / `test` | SM 据此生成 TRDC/RDC 与时钟/电源策略 |
| 4 | **硬件访问控制** | `TRDC_A..TRDC_W`、DFMT（域格式）、`sa=`/`pa=`（安全/特权属性） | TRDC（外设与内存的域访问控制）、RDC、GPC 电源域 |

#### 2.2 SM 配置里实际写了什么（Pro 板，节选）

**LM0 = SM（M33）** —— 它自己拥有的关键资源：

```text
LM0 name="SM", rpc=none, boot=1, did=2, safe=feenv
OWNER: perm=sec_rw, api=all
GPIO1      OWNER          ← GPIO1 归 SM
LPUART2    OWNER          ← SM 自己的调试串口（= COM19）
ELE        OWNER
MU1_B..MU6_B  OWNER
TRDC_A/C/D/E/G/H/M/N/V/W  OWNER   ← SM 拥有所有 TRDC 控制器
WDOG1/WDOG2  OWNER
```

**LM1 = M7** —— 关键资源：

```text
LM1 name="M7", rpc=scmi, boot=2, skip=1, did=4, safe=seenv
M7P        OWNER   # 注释明确写着 "CPUs must be first"
LPUART3    OWNER, test
LPUART7    OWNER   ← M7 的调试串口（= COM18）
CAN_FD1    OWNER
IRQSTEER_M7/LPIT1/LPTMR1/LPTMR2/LPTPM1/MSGINTR1/MSGINTR2  OWNER
MU5_A / MU7_B / MU8_B / MU_ELE5  OWNER
V2X_SHE1 / WDOG5 / TSTMR2  OWNER
PIN_GPIO_IO14 / IO15 / IO36 / IO37  OWNER   ← 正是历史项目 M7 用的 4 根引脚
M7MIX  DATA 0x020380000-0x02047FFFF
M7MIX  DATA 0x04A060000-0x04A09FFFF
DDR    EXEC 0x080000000-0x089FFFFFF
```

**LM2 = AP（A55）** —— 关键资源：

```text
LM2 name="AP", rpc=scmi, boot=3, skip=1, did=3, default
A55C0..A55C5  OWNER   # "CPUs must be first"
A55P          OWNER, sema=0x442313F8
ARM_PLL       OWNER
MU1_A / MU_ELE1 / MU_ELE2  OWNER
GPIO2/3/4/5   OWNER
LPUART1       OWNER   ← A55 的调试串口（= COM17，即 Linux console）
LPUART4/5/6/8 OWNER（LPUART8 带 test）
MU2_A/3_A/4_A/6_A/7_A/8_A  OWNER
NETC / NETC0/1/2 / NETC_LDID1..8 / NETC_VSI0..5 ...  OWNER
EDMA1 全部通道、EDMA2 的部分通道、EDMA3 全部通道  OWNER
V2X_APP0 / V2X_DEBUG  OWNER
# Memory
OCRAM  EXEC 0x020480000 size 256K
DDR    EXEC 0x08A000000-0x08DFFFFFF
```

**DOM0 = ELE（安全协处理器域）** 与 **DOM12 = V2X** 也在同一文件里分配 DDR 段（例：V2X 对 `0x080000000-0x08AFFFFFF` 只有 READONLY）。

#### 2.3 三种归属语义怎么理解

| 写法 | 含义 | 判断依据 |
|---|---|---|
| `OWNER` | 该 LM 独占该资源（可读写、可配置） | 源码中 `OWNER: perm=...` 定义的权限被套用 |
| `ACCESS` | 可访问但不拥有（例如 `EDMA2_MP ACCESS` 给 ELE 域、`EDMA2_MP ACCESS` 给 A55） | 共享场景，注释里明确写了"Sharing MP access may not be safe if FuSa SW using EDMA2" |
| `READONLY` | 只读（如 M7 对 `FSB`、V2X 对 DDR 大部分区） | 防止误改 |
| `test` | 测试用途标记（如 `LPUART3 OWNER, test`、`PD_M7 test`） | 与正式归属并列 |

#### 2.4 串口映射由此可解释（把历史结论钉死）

| COM | 内核名 | 归属 LM | 配置依据 |
|---|---|---|---|
| COM17 | ttyLP0（LPUART1，0x44380000） | **LM2 / A55** | `LPUART1 OWNER` 在 A55 段 |
| COM18 | ttyLP? （LPUART7，0x42690000） | **LM1 / M7** | `LPUART7 OWNER` 在 M7 段 |
| COM19 | LPUART2（0x44390000） | **LM0 / SM(M33)** | `LPUART2 OWNER` 在 SM 段 + `BOARD DEBUG_UART_INSTANCE=2` |

这三条同时满足"软件链路（SM 配置）"和"实机（谁打印谁应答）"，可以当作定论使用。

#### 2.5 权限为什么"root 也没用"

Linux 里的 root 是 **LM2（A55）内部**的超级用户，它的权限上限由 **LM2 的 EENV** 决定。
SM 没给 LM2 的 API/资源，Linux 里任何操作都越不过去——所以历史上：

- `remoteproc` 加载 M7 → `lmm(1) not under Linux Control`（因为 `LMM_1` 没在 A55 的 API 列表里）；
- U-Boot `prepaux` 写 M7 TCM → 同步异常（A55 没有 M7 TCM 的写权限）；
- 改 `mx95frdm-pro-m7gpio.cfg`（把 `GPIO2 OWNER` 给 LM1、同时保留 LM2 的 `ACCESS`/`PERLPI_GPIO2 ALL`）后 M7 才拿到 GPIO2。

---

### 三、要求 5：群组分布（LM / DOM）

#### 3.1 逻辑机（LM）与域（DOM）全景

| 群组 | 名称 | boot | did | safe | 角色 |
|---|---|---|---|---|---|
| LM0 | SM | 1 | 2 | feenv（first-execution env?） | 系统管理器，跑在 M33，管时钟/电源/引脚/权限 |
| LM1 | M7 | 2 | 4 | seenv | 实时核（本板默认给实时任务） |
| LM2 | AP | 3 | 3 | default | 应用核群（A55×6），默认跑 Linux |
| DOM0 | ELE | — | 0 | — | 安全子系统（密钥、AHAB 校验、TRNG） |
| DOM10 | ISP | — | 10 | — | 图像处理域 |
| DOM12 | V2X | — | 12 | — | 车规 V2X 域（有独立 DDR 段与只读约束） |

#### 3.2 与实机对照（交叉验证）

- Linux dmesg 报 `arm-scmi ... i.MX LMM: 3 Logical Machines` → **与 LM0/LM1/LM2 三台完全对上**。
- Linux 拿到 SM 的 CPU 列表：`m33p`、`m7p`、`a55c0`…`a55c5`、`a55p` → 与配置里的 `CPU_A55C0..C5`、`CPU_M7P` 对应。
- Linux 报 `SM Config = mx95frdm-pro, mSel = 0` → 说明当前生效的是 **Pro 板配置 + mSel=0 这组启动/停止序列**（配置里每个 LM 都有 mSel=0/1/2 三套，见 1.2(b)）。

#### 3.3 mSel 是什么（已确认）

配置里每个 LM 都有 `mSel=0 / 1 / 2` 三组 Start/Stop 序列（例：LM1 的 `MODE msel=1, boot=2`）。
`imx-mkimage` 的说明（`Readme.imx95` 第 35–36 行）写明：**`MSEL=m` 是传给 SM 的 mode select 值，用于在
运行时选择"启动哪些核、采用哪套上下电顺序"的启动配置**。实机 dmesg 报 `SM Config = mx95frdm-pro, mSel = 0`，
即当前使用第 0 套配置。

---

### 四、要求 3 / 4：地址空间与内存分布（初稿）

#### 4.1 三核看到的地址不一样（核心观念）

i.MX95 上同一个物理存储，不同核看到的地址可能不同（TCM 尤其明显）：

| 存储 | M7 本地视角 | 系统/其他核视角 | 证据 |
|---|---|---|---|
| M7 ITCM | `0x00000000` 起 | 系统别名 `0x203C0000`（SDK） | 历史项目实测 + SDK 头文件 |
| M7 MIX / TCM 区 | — | `0x020380000-0x02047FFFF`（SM 配置给 LM1 的 DATA） | SM 配置 |
| OCRAM | — | `0x020480000`（SM 给 A55 EXEC 256K；ELE 域另有 352K） | SM 配置 |
| DDR | — | `0x080000000` 起（16GB 到 `0x87FFFFFFF`） | SM 配置 + U-Boot `DRAM: 15.8 GiB` |

**要点：M7 用"本地 0 地址"访问自己的 TCM，A55 必须用"系统别名"地址访问同一块存储**——这是历史项目里
"TCM 版 BIN 要先读进 DDR、再复制到 0x203C0000"的原因。

#### 4.2 SM 配置里的内存划分（可作分区图底稿）

```text
ELE 域     : M33_TCM_SYS 0x020200000 +256K ; OCRAM 0x020480000 +352K ; DDR 0x080000000-0x87FFFFFFF
V2X 域     : DDR 0x080000000-0x08AFFFFFF READONLY ; 0x08B000000-0x08BFFFFFF DATA ; 其余 READONLY
LM1 (M7)   : M7MIX 0x020380000-0x02047FFFF ; M7MIX 0x04A060000-0x04A09FFFF ; DDR EXEC 0x080000000-0x089FFFFFF
LM2 (A55)  : OCRAM EXEC 0x020480000 +256K ; DDR EXEC 0x08A000000-0x08DFFFFFF
```

#### 4.3 Linux 侧的"看不见"区域（Jailhouse 相关，`实机验证得到`）

- 默认启动：Linux 看到 15.75 GB（`MemTotal: 16097536 kB`）。
- 带 `jh_root_mem=0x58000000@0x90000000,0xc0000000@0x180000000` 启动：Linux 只看到 **4.19 GB**，于是
  `0xf0000000+0xf700000`（inmate 区）与 `0xffc00000+0x400000`（hypervisor 区）空出来给 Jailhouse。
- 另有一批 Linux 自身预留：`linux,cma` 960MB、`optee_core@0x8c000000` 32MB、`optee_shm@0x8e000000` 2MB、
  `vpu_boot@0xa0000000` 1MB、`vdev0vring@0x88000000` 等（启动日志里的 `OF: reserved mem:` 行）。

#### 4.4 待补清单（阶段 D 要完成）

- [ ] 完整 memory map 表：把 TRM/SDK 头文件（`MIMX9596_*.h`）里的外设基址、DDR 控制器/PHY、GIC、MU、TRDC 基址整理成一张表
- [ ] A55 异常级与 MMU：EL3→EL2→EL1→EL0 在本板各由谁占用（ATF / KVM / Linux）
- [ ] M33 与 M7 的向量表、TCM 大小与别名（需查 RM + SDK 链接脚本）
- [ ] MIX/电源域与内存的对应（M7MIX/OCRAM/NPUMIX 等）
- [ ] Jailhouse 视角的内存（root cell / inmate / hypervisor）与 SM 配置内存段的交叉核对

---

### 五、这张图能不能解释我们踩过的坑（自检）

| 历史现象 | 用本文模型解释 |
|---|---|
| `lmm(1) not under Linux Control` | LM2 的 API 列表里没有 `LMM_1`，A55 无权控制 M7 那个 LM |
| U-Boot `prepaux` 写 M7 TCM 触发同步异常 | A55 对 M7MIX/TCM 无访问权限（TRDC） |
| 把 GPIO2 从 A55 整块拿走导致 A55 起不来、WDOG3→FCCU 复位 | 动了 LM2 启动链依赖的资源，触发 LM2 的 fault 反应（`FAULT_WDOG3 reaction=lm_reset`） |
| 改 SM 配置后 M7 才拿到 GPIO2 | `GPIO2 OWNER` 从 LM2 改到 LM1，同时保留 `PERLPI_GPIO2 ALL` 给 A55 |
| Harpoon 的 inmate 控制台在 LPUART3 但看不到 | LPUART3 在 Pro 板配置里归 **LM1(M7)** 且是 `test` 性质，J22 也没引出该 UART |
| 断电后 `jh_root_mem` 失效 | 它只是 U-Boot 环境变量，而环境区 CRC 损坏、每次用默认环境 |

---

### 六、证据索引

```text
SM 配置（Pro 板）      : tools\imx-sm-src\imx-sm-master\configs\other\mx95frdm-pro.cfg
                         （LM0 115 行 / LM1 340 行 / LM2 443 行 / A55-NS 549 行起）
SM 配置（RTE/Harpoon 包）: tools\imx-sm-src\imx-sm-master\configs\other\mx95rte.cfg   ← 可对比板级差异
U-Boot 板级             : tools\uboot-imx-source\board\freescale\imx95_frdm\imx95_frdm.c/.env
U-Boot 版本/启动链日志   : build\logs\20260917-140759-COM17.log（SPL→BL31→U-Boot→Linux）
SM/DDR OEI 日志         : build\logs\20260917-140759-COM19.log
Jailhouse cell          : build\rte-extract\usr\share\jailhouse\cells\imx95.cell / imx95-harpoon-freertos.cell
SDK 头文件（基址）      : SDK_26_06_00_IMX95LPD5EVK-19\devices\MIMX9596\MIMX9596_cm7_COMMON.h
```

### 七、下一步（按时间安排表）

1. 阶段 B 补完：把 1.1 的链条逐段配上源码行号（SPL/ATF/U-Boot 各自的入口与跳转条件），并把 `skip`/`mSel` 语义查清。
2. 阶段 C 补完：产出**外设归属矩阵**（外设 × LM × OWNER/ACCESS）+ TRDC 硬件映射，并做一次"改配置→实测权限变化"的闭环。
3. 阶段 D：补 4.4 的待办，产出完整地址空间/内存分布图。

---

## 二、理解-02：i.MX95 上电启动全流程（超详细）

## 理解-02：i.MX95 上电启动全流程（超详细）

> 类型：项目档案 / 理解文档（要求 1 的正文）。板型：FRDM-IMX95-PRO（i.MX95 B0，19x19，LPDDR5 16GB，eMMC 32GB）。
> 记录时间：2026-09-17。
> **一手来源（本次逐条读过原文）**：
> - SM 官方 README：`tools\imx-sm-src\imx-sm-master\README.md`
> - SM 架构文档：`tools\imx-sm-src\imx-sm-master\sm\doc\arch.md`（架构、LM、SCP 定义）
> - SM 配置文档：`tools\imx-sm-src\imx-sm-master\sm\doc\config.md`（`boot[]`/`rtime`/`start[]` 语义，330–400 行）
> - 板级 SM 配置：`tools\imx-sm-src\imx-sm-master\configs\other\mx95frdm-pro.cfg`
> - 容器打包说明：`tools\imx-mkimage\Readme.imx95`
> - 实机串口日志：`build\logs\20260917-140759-COM17.log`（A55）、`…-COM19.log`（M33/SM）

### 〇、一句话回答

**上电后最先执行的代码是 AON 域 Cortex-M33 上的片内 Boot ROM；最先"动起来"的子系统是 M33（SCP/SM）。**
它负责初始化 DDR、装载隔离（权限）配置，然后才按顺序把 M7、A55 从复位里放出来。
A55 上跑的第一个我们可见的软件是 **SPL**，之后才是 BL31(ATF) → U-Boot → Linux。

原文依据（SM README，逐字）：

> "The System Manager (SM) is an application that runs on a Cortex-M processor on many NXP i.MX processors.
> **The Cortex-M is the boot core, runs the boot ROM which loads the SM (and other boot code), and then branches
> to the SM.** The SM then configures some aspects of the hardware such as **isolation mechanisms** and then
> **starts other cores in the system**. After starting these cores, it enters a service mode where it provides
> access to clocking, power, sensor, and pin control via a client RPC API based on ARM's SCMI."

`arch.md` 补充：

> "On i.MX9, the **M33 core in the AON domain is the SCP** and runs the SM. The other cores (e.g. A55, M7) are
> user cores and communicate with the SM via an SCMI protocol. **SM owns the M33 core and does not support
> customers adding workloads to this core.**"

> 关于"第一条机器指令的具体地址"：它在 NXP 的掩膜 ROM 里，公开参考资料（RM/应用笔记）不给出该地址。
> 我们能确定并必须掌握的是**执行主体（AON M33）、执行顺序、以及每一步做什么**——下面逐段说明。

---

### 一、先看静态准备：启动容器里装了什么、被放到哪里

启动容器 = `imx-boot-<board>-sd.bin-flash_a55`（即俗称的 `flash.bin`）。它的作用是"一次性把所有核需要的东西装在一个文件里"。

| 容器内组件 | 作用 | 谁来消费 | 证据 |
|---|---|---|---|
| AHAB 容器头 + 签名 | 安全启动校验（ELE 执行） | Boot ROM / ELE | 实机 `ELE firmware version 2.0.5-fe6641ef` |
| **DDR OEI / LPDDR5 固件** | DDR 训练与初始化 | **M33（SM 侧）** | COM19 实机：`DDR OEI: SOC MIMX95(B0), Board mx95lp5 … TRAINING complete … done, err = 0` |
| **M33 SM 固件**（`m33_image.bin`） | 系统管理器本体 | M33 | 实机 `SM firmware Build 819, Commit c450f539` |
| **A55 SPL** | 一级引导（A55 上跑的第一段代码） | A55 | COM17 实机：`U-Boot SPL 2025.04-g99518e6b6f20` |
| **BL31（ATF）** | 安全监控/异常级切换（EL3） | A55 | COM17 实机：`NOTICE: BL31: v2.12.0(release):lf-6.18.2-1.0.0` |
| **U-Boot** | 二级引导（加载内核/设备树） | A55 | COM17 实机：`U-Boot 2025.04-g99518e6b6f20` |
| **TEE（OP-TEE）** | 安全世界 | A55 | 本地镜像内容（历史构建） |
| （可选）M7 镜像 | 实时核应用 | M7 | `imx-mkimage` 目标 `flash_lpboot_sm_m7*` |

容器打包方式由 `imx-mkimage` 决定，`Readme.imx95` 明确了几种"启动配置"目标：

```text
flash_lpboot_sm         仅 System Manager
flash_lpboot_sm_m7      SM + M7（TCM 或 DDR）
flash_lpboot_sm_a55     SM + A55（从 SD/eMMC 或 FlexSPI NOR）
flash_lpboot_sm_all     SM + A55 + M7
可选：OEI=YES（默认不用 OEI 镜像；OEI 名称为 oei.bin.ca55（singleboot）或 oei.bin.cm33（lpboot））
MSEL=m                  指定传给 SM 的 mode select 值，用于运行时选择"启动哪些核"的配置
UBOOT_LOAD_ADDR=0x90200000   （i.MX95 的 U-Boot 装载地址）
```

**要点**：`MSEL` 就是实机日志里那个 `mSel`。它决定 SM 用**哪一套启动配置档位**（见第四节）。

---

### 二、逐步流程（Step 0 → Step 12）

#### Step 0：POR 复位释放
- 电源上电/复位完成后，SoC 内部复位释放。
- **AON 域（always-on）先活**——AON 是"永远在线"的电源域，M33 与 BBNSM/RTC 等都在这里；A55/M7 所在的域此时仍未上电。
- `源码可以确认`：SM 配置里 A55 的启动第一步是 `VOLT_ARM start=1|1`，说明 **ARM 电压/集群域是"由 SM 后来才建立"的**，佐证 A55 上电前 M33 已经在跑。

#### Step 1：M33 执行 Boot ROM（上电后的第一段代码）
- 执行主体：**AON Cortex-M33**（`arch.md`：i.MX9 的 M33 在 AON 域担任 SCP）。
- Boot ROM 是片内掩膜 ROM，属于 NXP 内部实现；它在此阶段做的事：
  1. 建立最小运行环境（时钟、看门狗等基础配置）；
  2. **根据 SW4 引脚决定启动介质**；
  3. 从介质读出启动容器；
  4. 触发 **AHAB 校验流程**（把控制权交给 ELE 做签名/生命周期校验）；
  5. 把容器内的 SM 镜像（及其他核的引导代码）放到它们的运行位置，然后**跳转到 SM 入口**。
- `实机验证得到`：SW4 的实际效果（`x010`=eMMC 启动、`x001`=USB 串行下载等）与手册一致；USB 串行下载模式下 Boot ROM 直接等 UUU 通过 USB 灌入容器，这本身就证明 **Boot ROM 是"最先在跑"的那段代码**。

#### Step 2：ELE 执行 AHAB 校验（安全启动）
- ELE = **EdgeLock Enclave**，SoC 内独立的安全子系统（有自己的核与 ROM），在 SM 配置里被建模为 `DOM0 name="ELE", did=0`。
- 它校验容器签名、检查生命周期（open/closed）、提供 TRNG/密钥服务。
- 实机证据：U-Boot 打印 `ELE firmware version 2.0.5-fe6641ef`；Linux 侧 `fsl-se secure-enclave-0/1/2…: hsm0/v2x_dbg0/v2x_sv0/v2x_she0… interface to firmware, configured`。
- 若容器/固件版本不匹配（本项目历史踩过的坑），会在这一步或 SM 启动阶段失败——表现为"SM 起不来"。

#### Step 3：跳转到 SM，SM `main()` 开始（M33 上）
SM 的框架（`arch.md` 的 "SM Framework"）职责：

```text
- Boot:  main() 入口
         * 配置底层 device（SoC）与 board（板级）
         * 初始化实现数据，含 LMM、SCMI、RPC、Mailbox 等
         * 启动各个 logical machine
         * 之后变成 idle loop，空闲时把系统带入低功耗状态
- Monitor: UART 命令行（就是 COM19 上那个 "Press key to enter monitor mode" / "*** SM Debug Monitor ***"）
```

#### Step 4：SM 配置设备与板级
- `DEV_SM`（设备抽象，基于 MCUXpresso SDK 驱动：BBNSM/CACHE/CLOCK/CPU/ELE/IOMUXC/LPI2C/LPUART/MU1/PMIC/POWER/RESET…）
- `BRD_SM`（板级抽象：PMIC、I2C 扩展器、板级 RTC、板级传感器等）
- 实机证据：COM19 打印 `Hello from SM (Build 819…)`；U-Boot 里能看到 SM 已经能应答电源/时钟查询（PDO/TCPC 的电源协商日志）。

#### Step 5：★ SM 装载隔离（权限）配置——**在启动任何其他核之前**
`arch.md` 原文：

> "Isolate execution of different cores to prevent interference - this includes having **exclusive access the RDCs
> and loading their configuration before starting any other cores**"

这一步是理解"为什么 root 也没权限"的关键：**TRDC/RDC 的访问策略是 SM 在"还没有别的核在跑"的时候写好的**，
之后 A55/M7 一睁眼就已经在一个被限制好的世界里。SM 配置里 `TRDC_A…TRDC_W` 全部 `OWNER` 给 LM0(SM)，
就是这个意思。

#### Step 6：SM 初始化 LMM / SCMI / RPC / Mailbox
- 组件关系（`arch.md`）：`Mailbox → Transport(SMT) → RPC(SCMI 协议/agents) → LMM → Device/Board`
- 每个 LM 绑定一个 **RPC 实例**；一个 LM 可以有多个 **SCMI agent**，每个 agent 有独立的 **MU 邮箱通道**。
- 板级配置里对应的就是：

```text
SCMI_AGENT0 name="M7"    MAILBOX type=mu, mu=9   （M7 用 MU9）
SCMI_AGENT1 name="AP-S"  MAILBOX type=mu, mu=1   （A55 安全侧用 MU1）
SCMI_AGENT2 name="AP-NS" MAILBOX type=mu, mu=3   （A55 非安全侧用 MU3）
```

#### Step 7：★ SM 进入 LM 启动循环，按 `boot[]` 顺序启动各逻辑机
`config.md` 原文（330–388 行）：

> - *boot[]* — Array of **boot order of LM (0=no boot, else 1, 2, 3, …) per mSel**
> - *bootSkip[]* — **allow boot skip if no image (1=skip, def=0)** per mSel
> - *rtime* — **boot time of LM in uS, relative to start of LM boot loop**（最大 178 秒）
> - *start* — index into start array + 1, 0 = none
> - "The **boot value will determine if the LM will be booted when the SM boots**. The value indicates if it
>   should not (0=no) or the **order (1, 2, 3, …)** if it should. If not, it can be booted later using
>   `LMM_Boot()` or via SCMI using `SCMI_LmmBoot()`."
> - "If **bootSkip != 0** then **skip an error due to no image in the boot container**."
> - "The **rtime** value is the relative time the LM should boot in microseconds… It is useful to **delay the
>   start of an AP core to give RT cores a chance to boot**… for the M7 LM running a CAN stack would be 0 and
>   the rtime for the AP LM could be 50000 (50ms)."
> - "The start and stop values index into the start and stop arrays. These arrays contain start and stop commands
>   to be executed when an LM is booted or shutdown. **Commands are executed in order until the end of the array
>   or another LM item is encountered.**"

Pro 板实际取值（`mx95frdm-pro.cfg`）：

```text
LM0  name="SM",  rpc=none,  boot=1,                did=2, safe=feenv
LM1  name="M7",  rpc=scmi,  boot=2, skip=1,        did=4, safe=seenv
LM2  name="AP",  rpc=scmi,  boot=3, skip=1,        did=3, default
```

所以 SM 的启动循环顺序是：**自己(1) → M7(2) → A55/AP(3)**，中间可用 `rtime` 做微秒级错峰。

#### Step 8：启动 M7（LM1）——按 `start[]` 命令序列
```text
PD_M7   start=1, stop=2      ← 先开 M7 电源域（MIX）
CPU_M7P start=2, stop=1      ← 再释放 M7 CPU 复位
```
M7 拿到的资源（同文件 LM1 段）：`M7P`、`CAN_FD1`、`LPUART3(test)`、`LPUART7`、`MU5_A/MU7_B/MU8_B`、
`IRQSTEER_M7`、`LPIT1`、`LPTMR1/2`、`TPM1`、`V2X_SHE1`、`WDOG5`、引脚 `IO14/15/36/37`；
内存 `M7MIX 0x020380000-0x02047FFFF`、`0x04A060000-0x04A09FFFF`、DDR EXEC `0x080000000-0x089FFFFFF`。

#### Step 9：启动 A55 集群（LM2/AP）——最"啰嗦"的一步
```text
VOLT_ARM  start=1|1, stop=9     ← 建立 ARM 电压
PD_A55P   start=2,   stop=8     ← A55 平台域上电
PD_A55C0  stop=7                ← 各核电源域（停的时候用）
…
PERF_A55  start=3|3             ← 设定性能档位（频率）
CPU_A55C0 start=4               ← 释放 CPU0 复位（A55 的 boot core）
CPU_A55P  stop=1
```
A55 侧资源：`A55C0..A55C5`、`A55P`、`ARM_PLL`、`GPIO2..5`、`LPUART1/4/5/6/8`、`MU1_A/2_A/3_A/4_A/6_A/7_A/8_A`、
`NETC` 全套、`EDMA1/2/3`；内存 `OCRAM EXEC 0x020480000+256K`、`DDR EXEC 0x08A000000-0x08DFFFFFF`。

> 注意"CPU 必须排在第一项"：配置里反复出现注释 `# CPUs must be first`，说明 SM 解析资源列表时
> 把 CPU 作为该 LM 的标识资源优先处理。

#### Step 10：A55 跑起来后自己的链条（我们最熟悉的一段）
```text
A55 从 Boot ROM 给它的入口（SPL）开始执行
 └─ SPL：初始化串口/DDR 校验、从启动介质读入后续镜像
     ├─ 载入 BL31(ATF) 到 EL3 运行 → 建立安全监控、异常级、PSCI
     ├─ 载入 U-Boot   → 设备树、环境变量、启动菜单/脚本
     └─ U-Boot 载入 Linux Image + DTB → 启动内核
```
实机日志（COM17）逐行对应：

```text
U-Boot SPL 2025.04-g99518e6b6f20 (Feb 02 2026 - 05:52:54 +0000)   ← A55 第一段可见代码
SYS Boot reason: por … / LM Boot reason: por …                     ← SM 记录的复位原因
Trying to boot from MMC1 / Boot stage: Primary / Image set: 0, offset: 0x8000
NOTICE: BL31: v2.12.0(release):lf-6.18.2-1.0.0                     ← ATF
U-Boot 2025.04-g99518e6b6f20                                       ← U-Boot
Model: NXP FRDM-IMX95-PRO board / DRAM: 15.8 GiB                   ← DDR 已就绪（SM 之前已训练完）
Loading Environment from MMC… *** Warning - bad CRC, using default environment
Starting kernel …                                                  ← Linux
```

#### Step 11：SM 进入 service mode（长期状态）
SM 启动完各 LM 后**不退出**，进入 idle loop + SCMI 服务模式，持续提供：
时钟/电源/复位/传感器/引脚/性能(LMM)/BBM(RTC)/CPU/Misc/FuSa 等协议服务。
`实机验证得到`：Linux 起来后 dmesg 里能看到它和 SM 的交互：

```text
arm-scmi arm-scmi.0.auto: SCMI Protocol v2.1 'NXP:IMX' Firmware version 0x333
arm-scmi arm-scmi.0.auto: SM Version = Build 819, Commit c450f539 Mar 10 2026
arm-scmi arm-scmi.0.auto: Board = i.MX95 EVK, attr=0x00000000
arm-scmi arm-scmi.0.auto: SM Config = mx95frdm-pro, mSel = 0
arm-scmi arm-scmi.0.auto: i.MX LMM: 3 Logical Machines
arm-scmi arm-scmi.0.auto: i.MX CPU: name: m33p / m7p / a55c0 … a55c5 / a55p
```

#### Step 12：运行期（我们做 A55 FreeRTOS 时依赖的就是这一层）
- 任一 LM 想启动/复位另一个 LM：走 **LMM 协议**（`SCMI_LmmBoot()` / `LMM_Boot()`），**前提是 SM 配置里给了它 `LMM_x` 的权限**。
- 本项目实例：LM1(M7) 的 API 列表里有 `LMM_2 ALL`（能管 A55），而 LM2(A55) **没有** `LMM_1` → 所以历史项目里 Linux `remoteproc` 拉 M7 直接被拒（`lmm(1) not under Linux Control`）。

---

### 三、完整时序图（文字版，一张图看懂）

```text
POR ──► [M33/AON] Boot ROM
           ├─ 读 SW4 选介质
           ├─ 读容器 → ELE/AHAB 校验
           └─ 装载 SM 镜像 → 跳转 SM main()
                 │
                 ├─ DEV_SM/BRD_SM 初始化（时钟/PMIC/引脚/看门狗…）
                 ├─ 写 TRDC/RDC 隔离策略   ◄── 此刻还没有别的核在跑
                 ├─ LMM + SCMI + MU(MB) 初始化
                 └─ LM 启动循环（按 boot[] 顺序 + rtime 错峰）
                       ├─ LM0 SM 自身 (boot=1)
                       ├─ LM1 M7     (boot=2)：PD_M7 → CPU_M7P
                       └─ LM2 AP/A55 (boot=3)：VOLT_ARM → PD_A55P → PERF_A55 → CPU_A55C0…
                             │
                             └─► [A55] SPL → BL31(EL3) → U-Boot → Linux
                                        （此后 M33 进入 service mode，长期服务 SCMI 请求）
```

---

### 四、和启动相关的配置字段（全表，来自 `config.md`）

| 字段 | 含义 | 本项目取值 |
|---|---|---|
| `boot[]` | 每个 mSel 下该 LM 的**启动顺序**（0=不自动启动） | SM=1、M7=2、AP=3 |
| `bootSkip[]` / `skip` | 容器里**没有该 LM 镜像时不要报错** | M7=1、AP=1 |
| `rtime` | 相对"SM 开始启动 LM"的时刻，延迟多少**微秒**启动（可给实时核让路） | 配置默认（未显式改） |
| `autoBoot` | 自动启动条件（如 `LMM_AUTO_NONE`） | 默认 |
| `start` / `stop` | 索引到 start/stop 命令数组（+1 偏移，0=none） | 见 M7/A55 序列 |
| `mSel` / `MSEL` | 启动配置档位（可有多套 start/stop/boot 组合） | 实机生效 `mSel = 0` |
| `safeType` | 安全等级：0=NS-EENV / 1=F-EENV / 2=S-EENV | SM=feenv、M7=seenv、AP=default |
| `group` | LM 分组 | 默认 |
| `SCMI_AGENTn` + `MAILBOX` | 每个 agent 的邮箱（MU）通道 | M7→MU9、AP-S→MU1、AP-NS→MU3 |
| `LMM_x` API | 允许控制哪个 LM（LMM 协议） | M7 有 `LMM_2 ALL` |

---

### 四之补：**真正生效的启动配置**（读 `configtool` 生成的头文件，实机同源）

来源：`F:\project\Learning\RTOS\tools\wsl\UbuntuBuild\rootfs\root\imx95-wdog-baseline\imx-sm\configs\mx95frdm-pro\config_lmm.h`
（由 `configtool` 从 `configs\other\mx95frdm-pro.cfg` 生成，9811 B，与板上跑的 SM 同源）。

```c
/* LM 定义（真正编译进 SM 的值） */
SM_LM0_CONFIG { .name="SM", rpcType=NONE,   .boot[0]=1, .boot[1]=1, .boot[2]=1, .safeType=FEENV }
SM_LM1_CONFIG { .name="M7", rpcType=SCMI, .rpcInst=0, .boot[0]=2, .boot[1]=2,
                .bootSkip[0]=1, .start=1, .stop=1, .safeType=SEENV }
SM_LM2_CONFIG { .name="AP", rpcType=SCMI, .rpcInst=1, .boot[0]=3,
                .bootSkip[0]=1, .start=7, .stop=7 }

SM_NUM_LM   = 3U
SM_LM_NUM_MSEL = 3U          /* 三档启动配置 */
SM_LM_CFG_NAME = "mx95frdm-pro"
SM_LM_DEFAULT  = 2U          /* 调试监视器默认选中 LM2(AP) */
```

**启动命令表 `SM_LM_START_DATA`（mSel=0 就是实机在用的那一档，共 18 条）**：

| 序 | LM | 命令 | 目标资源 | 参数 | 含义 |
|---|---|---|---|---|---|
| 1 | M7 | `LMM_SS_PD` | `DEV_SM_PD_M7` | — | M7 电源域上电 |
| 2 | M7 | `LMM_SS_CPU` | `DEV_SM_CPU_M7P` | — | 释放 M7 出复位 |
| 3 | AP | `LMM_SS_VOLT` | `DEV_SM_VOLT_ARM` | 1 | 建立 ARM 电压 |
| 4 | AP | `LMM_SS_PD` | `DEV_SM_PD_A55P` | — | A55 平台域上电 |
| 5 | AP | `LMM_SS_PERF` | `DEV_SM_PERF_A55` | 3 | A55 性能档位=3 |
| 6 | AP | `LMM_SS_CPU` | `DEV_SM_CPU_A55C0` | — | **只释放 A55 的 CPU0** |

**三条关键结论（这次是"值"而不是"猜"）**：

1. **`rtime` 在 Pro 板里没有配置** —— 生成头文件里根本没有 `rtime` 字段 → 各 LM 之间**没有人为错峰**，就是按 boot 序号连续启动。（文档里描述的"M7 rtime=0、AP rtime=50000"是**举例**，不是本板配置。）
2. **★ SM 只启动 A55 的 CPU0**：启动表最后一条只有 `DEV_SM_CPU_A55C0`。**C1–C5 不在 SM 的启动列表里**，它们是由后续软件（ATF/U-Boot/Linux，经 **PSCI** 调用 SM 的 CPU 协议）逐个启动的。
   → 这就是"其他核怎么启动"的完整答案：**跨集群由 SM 按 boot[] 拉起；集群内部只有 boot core（C0）由 SM 释放，其余核由 OS/固件用 PSCI 热插拔式启动。**
3. **三档 mSel 的实际差异**（直接读 `boot[]` 数组）：
   - `mSel=0`：SM(1) → M7(2) → AP(3)　← **实机生效档**
   - `mSel=1`：SM(1) → M7(2)，**AP 不启动**（boot[1] 未定义=0）
   - `mSel=2`：只有 SM(1)
   停机顺序是反向的：AP 先 `CPU_A55P` → `PD_A55C5…C0` → `PD_A55P` → `VOLT_ARM`；M7 先 `CPU_M7P` → `PD_M7`。

**故障反应表 `SM_LM_FAULT_DATA`（解释了历史现象）**：

| 故障源 | 反应 | 作用对象 |
|---|---|---|
| `SW3` | `LMM_REACT_GRP_RESET` | 分组复位 |
| `SW4` / `DRAM` | `LMM_REACT_SYS_RESET` | 整系统复位 |
| `M7_LOCKUP` / `M7_RESET` / `SW1` / `WDOG5` | `LMM_REACT_LM_RESET` | LM1（M7） |
| `SW0` | `LMM_REACT_FUSA` | LM1（交给安全框架） |
| **`SW2` / `WDOG3` / `WDOG4`** | **`LMM_REACT_LM_RESET`** | **LM2（A55/AP）** |

→ 历史项目里"把 GPIO2 整块从 A55 拿走 → A55 起不来、WDOG3 触发 FCCU 复位 LM2"，
根因就在这张表：**A55 的看门狗（WDOG3）被配置成"复位 A55 这个逻辑机"**。

### 五、必须纠正的两个误解（我上一版写错了一个，在此更正）

| 说法 | 正确理解 | 依据 |
|---|---|---|
| "A55 先上电，然后 M33 才起来" | **反了**。M33（AON）先跑 Boot ROM 与 SM，A55 的 ARM 电压都是 SM 后来建立的 | SM README + 配置里 `VOLT_ARM start=1` |
| "`skip=1` 表示默认不启动该 LM" | **错**（我上一版这么写过）。`skip` 是 **bootSkip**：容器里没有该镜像时**跳过报错**，与是否启动无关 | `config.md` 343–380 行 |
| "`mSel` 是某种安全模式" | `mSel` 是**启动配置档位**（MSEL=m），用来在不同产品形态间切换"启动哪些核/怎么上下电" | `Readme.imx95` 第 35–36 行 |
| "OEI 一定跑在 A55 上" | OEI 镜像有两种：`oei.bin.ca55`（singleboot）、`oei.bin.cm33`（lpboot）；本项目实机 DDR OEI 是 SM 侧先完成 | `Readme.imx95` 第 4 行 + COM19 日志 |
| "SM 是普通固件，可以自己加任务" | SM **独占 M33**，官方明确不支持客户在该核上加负载 | `arch.md` 第 38–39 行 |

---

### 六、与 STM32 的对比（帮助理解，但不能直接类比）

| 维度 | STM32（如 H7 双核） | i.MX95 |
|---|---|---|
| 上电第一段代码 | 片内 Boot ROM（Cortex-M）→ 用户 Flash 里的复位向量 | 片内 Boot ROM，但**执行在 AON M33 上**，且它管理的是一整套多核系统 |
| 有没有"系统管理器" | 没有 | **有**（M33 上的 SM），管时钟/电源/复位/引脚/PMIC/权限 |
| 核之间关系 | 各自独立，靠共享内存/IPCC 通信 | 由 SM 建模成"逻辑机"，**可被独立启动/复位/下电**，权限由 SM 静态分配 |
| 外设能不能随便用 | 能（除少数安全外设） | **不能**，要 SM 在配置里把 OWNER/ACCESS 给你 |
| 权限载体 | MPU/选项字节 | **TRDC/RDC + SM 配置**，且由 SM 在其他核启动前写好 |

---

### 七、待验证 / 待补充清单

- [x] ~~`rtime` 在 Pro 板配置里的实际取值~~ → **已解决：未配置**（见"四之补"）
- [x] ~~`boot[]`/`skip`/`mSel` 语义~~ → **已解决**（`config.md` 330–388 行 + 生成头文件实际值）
- [ ] Boot ROM 内部第一阶段的确切步骤与第一条指令地址（属 NXP 掩膜 ROM 内部实现，公开资料不给出）
- [ ] `autoBoot` 的具体条件枚举（`LMM_AUTO_NONE` 之外的取值）
- [ ] SPL 的入口地址；SPL 如何确认 DDR 已由 SM 初始化完毕（读 ATF/SPL 源码或 `imx-mkimage -parse`）
- [ ] BL31→U-Boot→Linux 的交接细节（ATF 传参、DTB 由谁提供、`bootargs` 组装位置）
- [ ] 容器里没有 M7 镜像时 `bootSkip` 的实际行为（实测：不装 M7 镜像启动一次，看 SM 监视器是否报错）
- [ ] A55 的 PSCI 启动 C1–C5 的具体路径（ATF 里 `plat_psci` 与 SCMI CPU 协议的对应）

### 关联

- 资源隔离/权限细节：`2026-09-17-理解-启动逻辑与资源隔离.md`
- 计划：`2026-09-17-A55-FreeRTOS-新要求与时间安排.md`
- 实机证据：`2026-09-17-Harpoon全过程与复现步骤.md`

---

## 三、理解-03：外设归属与权限矩阵（FRDM-IMX95-PRO / mx95frdm-pro 配置）

## 理解-03：外设归属与权限矩阵（FRDM-IMX95-PRO / mx95frdm-pro 配置）

> 类型：项目档案 / 理解文档（要求 2 的硬产出）。
> **数据来源**：`tools\imx-sm-src\imx-sm-master\configs\other\mx95frdm-pro.cfg`（1023 行）经 `build\tools\parse_sm_cfg.py` 自动解析，
> 中间产物 `build\sm-cfg-parsed.json`。**本文件中的表格全部由脚本生成，不是手工抄录**。
> 生成时间：2026-09-17。若要改配置，请改 `.cfg` 后用 configtool 重新生成头文件（见文末"怎么改"）。

### 一、怎么读这张矩阵

- 行 = 一个资源（外设/CPU/电源域/时钟/引脚/故障）；列 = 一个"执行环境"（EENV）：**域**（ELE/ISP/V2X）或**逻辑机**
  （SM=M33 / M7 / A55 安全侧 / A55 非安全侧）。
- 单元格里是**权限动词**：
  | 动词 | 含义 |
  |---|---|
  | `OWNER` | 独占拥有（可读写、可配置） |
  | `ACCESS` | 可访问但不是拥有者（共享场景，例如 `EDMA2_MP` 同时给 ELE 域和 A55） |
  | `READONLY` | 只读 |
  | `DATA` / `EXEC` | 该段内存可作为数据/可执行 |
  | `PRIV` / `ALL` / `SET` / `NOTIFY` / `TEST_MU` | **API 权限**（能否调用该 SCMI 接口、以什么级别） |
- **空白 = 该执行环境在配置里没有对该资源的任何授权**。空白不代表"不能访问硬件"，而是"SM 不会为该 EENV
  打开对应通道"，实际访问还会被 TRDC/RDC 硬件规则二次拦截。

**一句话结论**：A55（LM2）能碰什么，是**这份文件写死的**；Linux 里的 root 只是 A55 内部的超级用户，越不过这一层。
这就是历史上 `lmm(1) not under Linux Control`、`prepaux 写 M7 TCM 触发异常`、`抽走 GPIO2 后 A55 起不来` 的共同根因。

### 二、各区段概览（条目数）

| 区段（.cfg 中的标题） | 简称 | 资源 | 内存 | 引脚 | API |
|---|---|---|---|---|---|
| `ELE Domain` | ELE | 3 | 3 | 0 | 0 |
| `ISP Domain` | ISP | 0 | 0 | 0 | 0 |
| `V2X Domain` | V2X | 1 | 3 | 0 | 0 |
| `SM M33 EENV` | SM(M33) | 77 | 4 | 7 | 13 |
| `M7 EENV` | M7 | 21 | 3 | 4 | 12 |
| `A55 secure EENV` | A55-sec | 11 | 2 | 0 | 17 |
| `A55 non-secure EENV` | A55-NS | 287 | 6 | 117 | 30 |

### 三、资源归属矩阵（全量）


**A55 类**（7 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `A55C0` |  |  |  |  |  | OWNER |  |
| `A55C1` |  |  |  |  |  | OWNER |  |
| `A55C2` |  |  |  |  |  | OWNER |  |
| `A55C3` |  |  |  |  |  | OWNER |  |
| `A55C4` |  |  |  |  |  | OWNER |  |
| `A55C5` |  |  |  |  |  | OWNER |  |
| `A55P` |  |  |  |  |  | OWNER |  |

**ADC 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `ADC` |  |  |  |  |  |  | OWNER |

**ARM_PLL 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `ARM_PLL` |  |  |  |  |  | OWNER |  |

**CAN 类**（5 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `CAN_FD1` |  |  |  |  | OWNER |  |  |
| `CAN_FD2` |  |  |  |  |  |  | OWNER |
| `CAN_FD3` |  |  |  |  |  |  | OWNER |
| `CAN_FD4` |  |  |  |  |  |  | OWNER |
| `CAN_FD5` |  |  |  |  |  |  | OWNER |

**EDMA 类**（101 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `EDMA1_CH0` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH1` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH10` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH11` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH12` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH13` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH14` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH15` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH16` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH17` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH18` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH19` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH2` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH20` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH21` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH22` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH23` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH24` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH25` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH26` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH27` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH28` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH29` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH3` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH30` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH31` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH4` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH5` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH6` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH7` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH8` |  |  |  |  |  |  | OWNER |
| `EDMA1_CH9` |  |  |  |  |  |  | OWNER |
| `EDMA1_MP` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH0_1` | OWNER |  |  |  |  |  |  |
| `EDMA2_CH10_11` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH12_13` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH14_15` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH16_17` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH18_19` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH20_21` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH22_23` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH24_25` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH26_27` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH28_29` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH2_3` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH30_31` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH32_33` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH34_35` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH36_37` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH38_39` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH40_41` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH42_43` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH44_45` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH46_47` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH48_49` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH4_5` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH50_51` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH52_53` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH54_55` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH56_57` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH58_59` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH60_61_A` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH60_61_B` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH62_63_A` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH62_63_B` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH6_7` |  |  |  |  |  |  | OWNER |
| `EDMA2_CH8_9` |  |  |  |  |  |  | OWNER |
| `EDMA2_MP` | ACCESS |  |  |  |  |  | ACCESS |
| `EDMA3_CH0_1` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH10_11` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH12_13` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH14_15` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH16_17` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH18_19` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH20_21` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH22_23` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH24_25` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH26_27` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH28_29` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH2_3` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH30_31` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH32_33` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH34_35` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH36_37` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH38_39` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH40_41` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH42_43` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH44_45` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH46_47` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH48_49` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH4_5` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH50_51` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH52_53` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH54_55` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH56_57` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH58_59` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH60_61` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH62_63` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH6_7` |  |  |  |  |  |  | OWNER |
| `EDMA3_CH8_9` |  |  |  |  |  |  | OWNER |
| `EDMA3_MP` |  |  |  |  |  |  | OWNER |

**ELE 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `ELE` |  |  |  | OWNER |  |  |  |

**FLEXSPI 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `FLEXSPI1` |  |  |  |  |  |  | OWNER |

**FSB 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `FSB` |  |  |  | READONLY | READONLY |  | READONLY |

**GPC 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `GPC` |  |  |  | OWNER |  |  |  |

**GPIO 类**（5 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `GPIO1` |  |  |  | OWNER |  |  |  |
| `GPIO2` |  |  |  |  |  |  | OWNER |
| `GPIO3` |  |  |  |  |  |  | OWNER |
| `GPIO4` |  |  |  |  |  |  | OWNER |
| `GPIO5` |  |  |  |  |  |  | OWNER |

**I3C 类**（2 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `I3C1` |  |  |  |  |  |  | OWNER |
| `I3C2` |  |  |  |  |  |  | OWNER |

**IRQSTEER 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `IRQSTEER_M7` |  |  |  |  | OWNER |  |  |

**LPI2C 类**（8 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `LPI2C1` |  |  |  | OWNER |  |  |  |
| `LPI2C2` |  |  |  |  |  |  | OWNER |
| `LPI2C3` |  |  |  |  |  |  | OWNER |
| `LPI2C4` |  |  |  |  |  |  | OWNER |
| `LPI2C5` |  |  |  |  |  |  | OWNER |
| `LPI2C6` |  |  |  |  |  |  | OWNER |
| `LPI2C7` |  |  |  |  |  |  | OWNER |
| `LPI2C8` |  |  |  |  |  |  | OWNER |

**LPIT 类**（2 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `LPIT1` |  |  |  |  | OWNER |  |  |
| `LPIT2` |  |  |  |  |  |  | OWNER |

**LPSPI 类**（8 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `LPSPI1` |  |  |  |  |  |  | OWNER |
| `LPSPI2` |  |  |  |  |  |  | OWNER |
| `LPSPI3` |  |  |  |  |  |  | OWNER |
| `LPSPI4` |  |  |  |  |  |  | OWNER |
| `LPSPI5` |  |  |  |  |  |  | OWNER |
| `LPSPI6` |  |  |  |  |  |  | OWNER |
| `LPSPI7` |  |  |  |  |  |  | OWNER |
| `LPSPI8` |  |  |  |  |  |  | OWNER |

**LPTMR 类**（2 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `LPTMR1` |  |  |  |  | OWNER |  |  |
| `LPTMR2` |  |  |  |  | OWNER |  |  |

**LPUART 类**（8 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `LPUART1` |  |  |  |  |  |  | OWNER |
| `LPUART2` |  |  |  | OWNER |  |  |  |
| `LPUART3` |  |  |  |  | OWNER |  |  |
| `LPUART4` |  |  |  |  |  |  | OWNER |
| `LPUART5` |  |  |  |  |  |  | OWNER |
| `LPUART6` |  |  |  |  |  |  | OWNER |
| `LPUART7` |  |  |  |  | OWNER |  |  |
| `LPUART8` |  |  |  |  |  |  | OWNER |

**M7P 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `M7P` |  |  |  |  | OWNER |  |  |

**MSGINTR 类**（2 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `MSGINTR1` |  |  |  |  | OWNER |  |  |
| `MSGINTR2` |  |  |  |  | OWNER |  |  |

**MU 类**（22 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `MU1_A` |  |  |  | TEST_MU |  | OWNER |  |
| `MU1_B` |  |  |  | OWNER |  |  |  |
| `MU2_A` |  |  |  | TEST_MU |  |  | OWNER |
| `MU2_B` |  |  |  | OWNER |  |  |  |
| `MU3_A` |  |  |  | TEST_MU |  |  | OWNER |
| `MU3_B` |  |  |  | OWNER |  |  |  |
| `MU4_A` |  |  |  | TEST_MU |  |  | OWNER |
| `MU4_B` |  |  |  | OWNER |  |  |  |
| `MU5_A` |  |  |  | TEST_MU | OWNER |  |  |
| `MU5_B` |  |  |  | OWNER |  |  |  |
| `MU6_A` |  |  |  | TEST_MU |  |  | OWNER |
| `MU6_B` |  |  |  | OWNER |  |  |  |
| `MU7_A` |  |  |  |  |  |  | OWNER |
| `MU7_B` |  |  |  |  | OWNER |  |  |
| `MU8_A` |  |  |  |  |  |  | OWNER |
| `MU8_B` |  |  |  |  | OWNER |  |  |
| `MU_ELE0` |  |  |  | OWNER |  |  |  |
| `MU_ELE1` |  |  |  |  |  | OWNER |  |
| `MU_ELE2` |  |  |  |  |  | OWNER |  |
| `MU_ELE3` |  |  |  |  |  |  | OWNER |
| `MU_ELE4` |  |  |  |  |  |  | OWNER |
| `MU_ELE5` |  |  |  |  | OWNER |  |  |

**NETC 类**（23 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `NETC` |  |  |  |  |  |  | OWNER |
| `NETC0` |  |  |  |  |  |  | OWNER |
| `NETC1` |  |  |  |  |  |  | OWNER |
| `NETC2` |  |  |  |  |  |  | OWNER |
| `NETC_ECAM` |  |  |  |  |  |  | OWNER |
| `NETC_EMDIO0` |  |  |  |  |  |  | OWNER |
| `NETC_IERB` |  |  |  |  |  |  | OWNER |
| `NETC_LDID1` |  |  |  |  |  |  | OWNER |
| `NETC_LDID2` |  |  |  |  |  |  | OWNER |
| `NETC_LDID3` |  |  |  |  |  |  | OWNER |
| `NETC_LDID4` |  |  |  |  |  |  | OWNER |
| `NETC_LDID5` |  |  |  |  |  |  | OWNER |
| `NETC_LDID6` |  |  |  |  |  |  | OWNER |
| `NETC_LDID7` |  |  |  |  |  |  | OWNER |
| `NETC_LDID8` |  |  |  |  |  |  | OWNER |
| `NETC_PRB` |  |  |  |  |  |  | OWNER |
| `NETC_TIMER0` |  |  |  |  |  |  | OWNER |
| `NETC_VSI0` |  |  |  |  |  |  | OWNER |
| `NETC_VSI1` |  |  |  |  |  |  | OWNER |
| `NETC_VSI2` |  |  |  |  |  |  | OWNER |
| `NETC_VSI3` |  |  |  |  |  |  | OWNER |
| `NETC_VSI4` |  |  |  |  |  |  | OWNER |
| `NETC_VSI5` |  |  |  |  |  |  | OWNER |

**PD_ 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `PD_M7` |  |  |  |  | test |  |  |

**SAI 类**（5 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `SAI1` |  |  |  |  |  |  | OWNER |
| `SAI2` |  |  |  |  |  |  | OWNER |
| `SAI3` |  |  |  |  |  |  | OWNER |
| `SAI4` |  |  |  |  |  |  | OWNER |
| `SAI5` |  |  |  |  |  |  | OWNER |

**SRC 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `SRC` |  |  |  | OWNER |  |  |  |

**SYSCTR 类**（4 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `SYSCTR_CMP` |  |  |  |  |  |  | OWNER |
| `SYSCTR_CTL` |  |  |  | OWNER |  |  |  |
| `SYSCTR_RD` |  |  |  | OWNER | READONLY |  |  |
| `SYSCTR_RD_STOP` |  |  |  |  |  |  | READONLY |

**TRDC 类**（10 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `TRDC_A` |  |  |  | OWNER |  |  |  |
| `TRDC_C` |  |  |  | OWNER |  |  |  |
| `TRDC_D` |  |  |  | OWNER |  |  |  |
| `TRDC_E` |  |  |  | OWNER |  |  |  |
| `TRDC_G` |  |  |  | OWNER |  |  |  |
| `TRDC_H` |  |  |  | OWNER |  |  |  |
| `TRDC_M` |  |  |  | OWNER |  |  |  |
| `TRDC_N` |  |  |  | OWNER |  |  |  |
| `TRDC_V` |  |  |  | OWNER |  |  |  |
| `TRDC_W` |  |  |  | OWNER |  |  |  |

**TSTMR 类**（2 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `TSTMR1` |  |  |  | OWNER |  |  |  |
| `TSTMR2` |  |  |  |  | OWNER |  |  |

**USDHC 类**（3 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `USDHC1` |  |  |  |  |  |  | OWNER |
| `USDHC2` |  |  |  |  |  |  | OWNER |
| `USDHC3` |  |  |  |  |  |  | OWNER |

**V2X 类**（8 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `V2X_ACC` | OWNER |  |  |  |  |  |  |
| `V2X_APP0` |  |  |  |  |  |  | OWNER |
| `V2X_DEBUG` |  |  |  |  |  |  | OWNER |
| `V2X_FH` |  |  | OWNER |  |  |  |  |
| `V2X_HSM1` |  |  |  |  |  |  | OWNER |
| `V2X_HSM2` |  |  |  |  |  |  | OWNER |
| `V2X_SHE0` |  |  |  |  |  |  | OWNER |
| `V2X_SHE1` |  |  |  |  | OWNER |  |  |

**WDOG 类**（5 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `WDOG1` |  |  |  | OWNER |  |  |  |
| `WDOG2` |  |  |  | OWNER |  |  |  |
| `WDOG3` |  |  |  |  |  |  | OWNER |
| `WDOG4` |  |  |  |  |  |  | OWNER |
| `WDOG5` |  |  |  |  | OWNER |  |  |

**XSPI 类**（1 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `XSPI` |  |  |  |  |  |  | OWNER |

**其他 类**（145 项）

| 资源 | ELE | ISP | V2X | SM(M33) | M7 | A55-sec | A55-NS |
|---|---|---|---|---|---|---|---|
| `ANATOP` |  |  |  | OWNER |  |  |  |
| `ATU_A` |  |  |  | OWNER |  |  |  |
| `ATU_M` |  |  |  | OWNER |  |  |  |
| `AXBS_AON` |  |  |  | OWNER |  |  |  |
| `BBNSM` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_BBSMMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_CAMERAMIX` |  |  |  |  |  |  | OWNER |
| `BLK_CTRL_DDRMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_GPUMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_HSIOMIX` |  |  |  |  |  |  | OWNER |
| `BLK_CTRL_NETCMIX` |  |  |  |  |  |  | OWNER |
| `BLK_CTRL_NOCMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_NPUMIX` |  |  |  |  |  |  | OWNER |
| `BLK_CTRL_NS_AONMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_S_AONMIX` |  |  |  | OWNER |  |  |  |
| `BLK_CTRL_VPUMIX` |  |  |  |  |  |  | OWNER |
| `BLK_CTRL_WAKEUPMIX` |  |  |  | OWNER |  |  |  |
| `CAMERA1` |  |  |  |  |  |  | OWNER |
| `CAMERA2` |  |  |  |  |  |  | OWNER |
| `CAMERA3` |  |  |  |  |  |  | OWNER |
| `CAMERA4` |  |  |  |  |  |  | OWNER |
| `CAMERA5` |  |  |  |  |  |  | OWNER |
| `CAMERA6` |  |  |  |  |  |  | OWNER |
| `CAMERA7` |  |  |  |  |  |  | OWNER |
| `CAMERA8` |  |  |  |  |  |  | OWNER |
| `CCM` |  |  |  | OWNER |  |  |  |
| `DAP` |  |  |  | OWNER |  |  |  |
| `DC` |  |  |  |  |  |  | OWNER |
| `DC0` |  |  |  |  |  |  | OWNER |
| `DC1` |  |  |  |  |  |  | OWNER |
| `DC_2DBLIT` |  |  |  |  |  |  | OWNER |
| `DC_BLITINT` |  |  |  |  |  |  | OWNER |
| `DC_CMDSEQ` |  |  |  |  |  |  | OWNER |
| `DC_DISPENG` |  |  |  |  |  |  | OWNER |
| `DC_DISPENG_INT` |  |  |  |  |  |  | OWNER |
| `DC_FL0` |  |  |  |  |  |  | OWNER |
| `DC_FL1` |  |  |  |  |  |  | OWNER |
| `DC_INT_CTL` |  |  |  |  |  |  | OWNER |
| `DC_PIXENGINE` |  |  |  |  |  |  | OWNER |
| `DC_XPC` |  |  |  |  |  |  | OWNER |
| `DC_YUV0` |  |  |  |  |  |  | OWNER |
| `DC_YUV1` |  |  |  |  |  |  | OWNER |
| `DC_YUV2` |  |  |  |  |  |  | OWNER |
| `DC_YUV3` |  |  |  |  |  |  | OWNER |
| `DDR_CTRL` |  |  |  | OWNER |  |  |  |
| `DDR_PHY` |  |  |  | OWNER |  |  |  |
| `DDR_PM` |  |  |  | OWNER |  |  | ACCESS |
| `DRAM_PLL` |  |  |  | OWNER |  |  |  |
| `FLEXIO1` |  |  |  |  |  |  | OWNER |
| `FLEXIO2` |  |  |  |  |  |  | OWNER |
| `GIC` |  |  |  | ACCESS |  |  | OWNER |
| `GPR0` |  |  |  | OWNER |  |  |  |
| `GPR1` |  |  |  | OWNER |  |  |  |
| `GPR2` |  |  |  | OWNER |  |  |  |
| `GPR3` |  |  |  | OWNER |  |  |  |
| `GPR4` |  |  |  |  |  |  | OWNER |
| `GPR5` |  |  |  |  |  |  | OWNER |
| `GPR6` |  |  |  |  |  |  | OWNER |
| `GPR7` |  |  |  |  |  |  | OWNER |
| `GPU_NPROT` |  |  |  |  |  |  | OWNER |
| `GPU_PROT` |  |  |  |  |  |  | OWNER |
| `GPV_CAMERA` |  |  |  | OWNER |  |  |  |
| `GPV_CENTRAL` |  |  |  | OWNER |  |  |  |
| `GPV_DISPLAY` |  |  |  | OWNER |  |  |  |
| `GPV_HSIO` |  |  |  | OWNER |  |  |  |
| `GPV_MAIN` |  |  |  | OWNER |  |  |  |
| `GPV_MEGA` |  |  |  | OWNER |  |  |  |
| `GPV_VPU` |  |  |  | OWNER |  |  |  |
| `IOMUXC` |  |  |  | OWNER |  |  |  |
| `IOMUX_GPR` |  |  |  | OWNER |  |  |  |
| `ISI1` |  |  |  |  |  |  | OWNER |
| `ISI2` |  |  |  |  |  |  | OWNER |
| `ISI3` |  |  |  |  |  |  | OWNER |
| `ISI4` |  |  |  |  |  |  | OWNER |
| `ISI5` |  |  |  |  |  |  | OWNER |
| `ISI6` |  |  |  |  |  |  | OWNER |
| `ISI7` |  |  |  |  |  |  | OWNER |
| `ISI8` |  |  |  |  |  |  | OWNER |
| `ISP_CPU` |  |  |  |  |  |  | OWNER |
| `ISP_MGR` |  |  |  |  |  |  | OWNER |
| `JPEG_DEC` |  |  |  |  |  |  | OWNER |
| `JTAG` |  |  |  | OWNER |  |  |  |
| `LPTPM1` |  |  |  |  | OWNER |  |  |
| `LPTPM2` |  |  |  |  |  |  | OWNER |
| `LPTPM3` |  |  |  |  |  |  | OWNER |
| `LPTPM4` |  |  |  |  |  |  | OWNER |
| `LPTPM5` |  |  |  |  |  |  | OWNER |
| `LPTPM6` |  |  |  |  |  |  | OWNER |
| `LVDS` |  |  |  |  |  |  | OWNER |
| `M33P` |  |  |  | OWNER |  |  |  |
| `M33_CACHE_CTRL` |  |  |  | OWNER |  |  |  |
| `M33_PCF` |  |  |  | OWNER |  |  |  |
| `M33_PSF` |  |  |  | OWNER |  |  |  |
| `M33_TCM_ECC` |  |  |  | OWNER |  |  |  |
| `MIPI_CSI0` |  |  |  |  |  |  | OWNER |
| `MIPI_CSI1` |  |  |  |  |  |  | OWNER |
| `MIPI_DSI` |  |  |  |  |  |  | OWNER |
| `MIPI_PHY` |  |  |  |  |  |  | OWNER |
| `MJPEG_DEC1` |  |  |  |  |  |  | OWNER |
| `MJPEG_DEC2` |  |  |  |  |  |  | OWNER |
| `MJPEG_DEC3` |  |  |  |  |  |  | OWNER |
| `MJPEG_DEC4` |  |  |  |  |  |  | OWNER |
| `MJPEG_ENC` |  |  |  |  |  |  | OWNER |
| `MJPEG_ENC1` |  |  |  |  |  |  | OWNER |
| `MJPEG_ENC2` |  |  |  |  |  |  | OWNER |
| `MJPEG_ENC3` |  |  |  |  |  |  | OWNER |
| `MJPEG_ENC4` |  |  |  |  |  |  | OWNER |
| `NPU` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT0` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT1` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT2` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT3` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT4` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT5` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT6` |  |  |  |  |  |  | OWNER |
| `PCI1_LUT7` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT0` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT1` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT2` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT3` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT4` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT5` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT6` |  |  |  |  |  |  | OWNER |
| `PCI2_LUT7` |  |  |  |  |  |  | OWNER |
| `PCIE1_OUT` |  |  |  |  |  |  | OWNER |
| `PCIE1_ROOT` |  |  |  |  |  |  | OWNER |
| `PCIE2_OUT` |  |  |  |  |  |  | OWNER |
| `PCIE2_ROOT` |  |  |  |  |  |  | OWNER |
| `PDM` |  |  |  |  |  |  | OWNER |
| `ROMCP_M33` |  |  |  | OWNER |  |  |  |
| `SEMA41` |  |  |  |  |  |  | OWNER |
| `SEMA42` |  |  |  |  |  |  | OWNER |
| `SMMU` |  |  |  |  |  |  | OWNER |
| `SPDIF1` |  |  |  |  |  |  | OWNER |
| `SRAM_CTL_1` |  |  |  | OWNER |  |  |  |
| `SRAM_CTL_N` |  |  |  | OWNER |  |  |  |
| `TEMP_A55` |  |  |  | OWNER |  |  |  |
| `USB1` |  |  |  |  |  |  | OWNER |
| `USB2` |  |  |  |  |  |  | OWNER |
| `VIDEO_PLL1` |  |  |  |  |  |  | OWNER |
| `VPU` |  |  |  |  |  |  | OWNER |
| `VPU1` |  |  |  |  |  |  | OWNER |
| `VPU2` |  |  |  |  |  |  | OWNER |
| `VPU3` |  |  |  |  |  |  | OWNER |
| `VPU4` |  |  |  |  |  |  | OWNER |

### 四、内存归属（各 EENV 的 EXEC/DATA 段）


**ELE — 资源/范围/属性**（3 项）

| 资源 | 范围/属性 |
|---|---|
| `M33_TCM_SYS` | DATA, begin=0x020200000, size=256K |
| `OCRAM` | DATA, begin=0x020480000, size=352K |
| `DDR` | DATA, begin=0x080000000, end=0x87FFFFFFF, nodbg |
**V2X — 资源/范围/属性**（3 项）

| 资源 | 范围/属性 |
|---|---|
| `DDR` | READONLY, begin=0x080000000, end=0x08AFFFFFF, nodbg |
| `DDR` | DATA, begin=0x08B000000, end=0x08BFFFFFF, nodbg |
| `DDR` | READONLY, begin=0x08C000000, end=0x87FFFFFFF, nodbg |
**SM(M33) — 资源/范围/属性**（4 项）

| 资源 | 范围/属性 |
|---|---|
| `M33_ROM` | EXEC, begin=0x000000000, end=0x00003FFFF |
| `M33_TCM_CODE` | EXEC, begin=0x0201C0000, size=256K |
| `M33_TCM_SYS` | EXEC, begin=0x020200000, size=256K |
| `M7MIX` | DATA, begin=0x04A050000, end=0x04A0AFFFF |
**M7 — 资源/范围/属性**（3 项）

| 资源 | 范围/属性 |
|---|---|
| `M7MIX` | DATA, begin=0x020380000, end=0x02047FFFF |
| `M7MIX` | DATA, begin=0x04A060000, end=0x04A09FFFF |
| `DDR` | EXEC, begin=0x080000000, end=0x089FFFFFF |
**A55-sec — 资源/范围/属性**（2 项）

| 资源 | 范围/属性 |
|---|---|
| `OCRAM` | EXEC, begin=0x020480000, size=256K |
| `DDR` | EXEC, begin=0x08A000000, end=0x08DFFFFFF |
**A55-NS — 资源/范围/属性**（6 项）

| 资源 | 范围/属性 |
|---|---|
| `FLEXSPI1_MEM` | EXEC, begin=0x000000000, end=0x0FFFFFFFF |
| `OCRAM_C` | EXEC, begin=0x001000000, end=0x001017FFF |
| `OCRAM` | EXEC, begin=0x0204C0000, size=96K |
| `GPU` | DATA, begin=0x04D900000, end=0x04DD7FFFF |
| `DDR` | EXEC, begin=0x088000000, end=0x089FFFFFF, clr=8 |
| `DDR` | EXEC, begin=0x08E000000, end=0x87FFFFFFF |

### 五、引脚归属（IOMUX 级别）


**SM(M33) — 引脚/权限**（7 项）

| 引脚 | 权限 |
|---|---|
| `PIN_FCCU_ERR0` | OWNER |
| `PIN_I2C1_SCL` | OWNER |
| `PIN_I2C1_SDA` | OWNER |
| `PIN_PDM_BIT_STREAM1` | OWNER |
| `PIN_UART2_RXD` | OWNER |
| `PIN_UART2_TXD` | OWNER |
| `PIN_WDOG_ANY` | OWNER |
**M7 — 引脚/权限**（4 项）

| 引脚 | 权限 |
|---|---|
| `PIN_GPIO_IO14` | OWNER |
| `PIN_GPIO_IO15` | OWNER |
| `PIN_GPIO_IO36` | OWNER |
| `PIN_GPIO_IO37` | OWNER |
**A55-NS — 引脚/权限**（117 项）

| 引脚 | 权限 |
|---|---|
| `PIN_CCM_CLKO1` | OWNER |
| `PIN_CCM_CLKO2` | OWNER |
| `PIN_CCM_CLKO3` | OWNER |
| `PIN_CCM_CLKO4` | OWNER |
| `PIN_DAP_TCLK_SWCLK` | OWNER |
| `PIN_DAP_TDI` | OWNER |
| `PIN_DAP_TMS_SWDIO` | OWNER |
| `PIN_ENET1_MDC` | OWNER |
| `PIN_ENET1_MDIO` | OWNER |
| `PIN_ENET1_RD0` | OWNER |
| `PIN_ENET1_RD1` | OWNER |
| `PIN_ENET1_RD2` | OWNER |
| `PIN_ENET1_RD3` | OWNER |
| `PIN_ENET1_RX_CTL` | OWNER |
| `PIN_ENET1_RXC` | OWNER |
| `PIN_ENET1_TD0` | OWNER |
| `PIN_ENET1_TD1` | OWNER |
| `PIN_ENET1_TD2` | OWNER |
| `PIN_ENET1_TD3` | OWNER |
| `PIN_ENET1_TX_CTL` | OWNER |
| `PIN_ENET1_TXC` | OWNER |
| `PIN_ENET2_MDC` | OWNER |
| `PIN_ENET2_MDIO` | OWNER |
| `PIN_ENET2_RD0` | OWNER |
| `PIN_ENET2_RD1` | OWNER |
| `PIN_ENET2_RD2` | OWNER |
| `PIN_ENET2_RD3` | OWNER |
| `PIN_ENET2_RX_CTL` | OWNER |
| `PIN_ENET2_RXC` | OWNER |
| `PIN_ENET2_TD0` | OWNER |
| `PIN_ENET2_TD1` | OWNER |
| `PIN_ENET2_TD2` | OWNER |
| `PIN_ENET2_TD3` | OWNER |
| `PIN_ENET2_TX_CTL` | OWNER |
| `PIN_ENET2_TXC` | OWNER |
| `PIN_GPIO_IO00` | OWNER |
| `PIN_GPIO_IO01` | OWNER |
| `PIN_GPIO_IO02` | OWNER |
| `PIN_GPIO_IO03` | OWNER |
| `PIN_GPIO_IO04` | OWNER |
| `PIN_GPIO_IO05` | OWNER |
| `PIN_GPIO_IO06` | OWNER |
| `PIN_GPIO_IO07` | OWNER |
| `PIN_GPIO_IO08` | OWNER |
| `PIN_GPIO_IO09` | OWNER |
| `PIN_GPIO_IO10` | OWNER |
| `PIN_GPIO_IO11` | OWNER |
| `PIN_GPIO_IO12` | OWNER |
| `PIN_GPIO_IO13` | OWNER |
| `PIN_GPIO_IO16` | OWNER |
| `PIN_GPIO_IO17` | OWNER |
| `PIN_GPIO_IO18` | OWNER |
| `PIN_GPIO_IO19` | OWNER |
| `PIN_GPIO_IO20` | OWNER |
| `PIN_GPIO_IO21` | OWNER |
| `PIN_GPIO_IO22` | OWNER |
| `PIN_GPIO_IO23` | OWNER |
| `PIN_GPIO_IO24` | OWNER |
| `PIN_GPIO_IO25` | OWNER |
| `PIN_GPIO_IO26` | OWNER |
| `PIN_GPIO_IO27` | OWNER |
| `PIN_GPIO_IO28` | OWNER |
| `PIN_GPIO_IO29` | OWNER |
| `PIN_GPIO_IO30` | OWNER |
| `PIN_GPIO_IO31` | OWNER |
| `PIN_GPIO_IO32` | OWNER |
| `PIN_GPIO_IO33` | OWNER |
| `PIN_GPIO_IO34` | OWNER |
| `PIN_GPIO_IO35` | OWNER |
| `PIN_I2C2_SCL` | OWNER |
| `PIN_I2C2_SDA` | OWNER |
| `PIN_PDM_BIT_STREAM0` | OWNER |
| `PIN_PDM_CLK` | OWNER |
| `PIN_SAI1_RXD0` | OWNER |
| `PIN_SAI1_TXC` | OWNER |
| `PIN_SAI1_TXD0` | OWNER |
| `PIN_SAI1_TXFS` | OWNER |
| `PIN_SD1_CLK` | OWNER |
| `PIN_SD1_CMD` | OWNER |
| `PIN_SD1_DATA0` | OWNER |
| `PIN_SD1_DATA1` | OWNER |
| `PIN_SD1_DATA2` | OWNER |
| `PIN_SD1_DATA3` | OWNER |
| `PIN_SD1_DATA4` | OWNER |
| `PIN_SD1_DATA5` | OWNER |
| `PIN_SD1_DATA6` | OWNER |
| `PIN_SD1_DATA7` | OWNER |
| `PIN_SD1_STROBE` | OWNER |
| `PIN_SD2_CD_B` | OWNER |
| `PIN_SD2_CLK` | OWNER |
| `PIN_SD2_CMD` | OWNER |
| `PIN_SD2_DATA0` | OWNER |
| `PIN_SD2_DATA1` | OWNER |
| `PIN_SD2_DATA2` | OWNER |
| `PIN_SD2_DATA3` | OWNER |
| `PIN_SD2_RESET_B` | OWNER |
| `PIN_SD2_VSELECT` | OWNER |
| `PIN_SD3_CLK` | OWNER |
| `PIN_SD3_CMD` | OWNER |
| `PIN_SD3_DATA0` | OWNER |
| `PIN_SD3_DATA1` | OWNER |
| `PIN_SD3_DATA2` | OWNER |
| `PIN_SD3_DATA3` | OWNER |
| `PIN_UART1_RXD` | OWNER, test |
| `PIN_UART1_TXD` | OWNER |
| `PIN_XSPI1_DATA0` | OWNER |
| `PIN_XSPI1_DATA1` | OWNER |
| `PIN_XSPI1_DATA2` | OWNER |
| `PIN_XSPI1_DATA3` | OWNER |
| `PIN_XSPI1_DATA4` | OWNER |
| `PIN_XSPI1_DATA5` | OWNER |
| `PIN_XSPI1_DATA6` | OWNER |
| `PIN_XSPI1_DATA7` | OWNER |
| `PIN_XSPI1_DQS` | OWNER |
| `PIN_XSPI1_SCLK` | OWNER |
| `PIN_XSPI1_SS0_B` | OWNER |
| `PIN_XSPI1_SS1_B` | OWNER |

### 六、API 授权（谁能调用哪些 SCMI/NXP 扩展接口）


**SM(M33) — API 授权**（13 项）

| API | 权限 |
|---|---|
| `CLK_ADC` | ALL |
| `CLK_FRO` | ALL |
| `CLK_OSC24M` | ALL |
| `CLK_OSC32K` | ALL |
| `CLK_SYSPLL1_PFD0` | ALL |
| `CLK_SYSPLL1_PFD0_DIV2` | ALL |
| `CLK_SYSPLL1_PFD1` | ALL |
| `CLK_SYSPLL1_PFD1_DIV2` | ALL |
| `CLK_SYSPLL1_PFD2` | ALL |
| `CLK_SYSPLL1_PFD2_DIV2` | ALL |
| `CLK_SYSPLL1_VCO` | ALL |
| `CLK_TEMPSENSE_GPR_SEL` | ALL |
| `CLK_TMU` | ALL |
**M7 — API 授权**（12 项）

| API | 权限 |
|---|---|
| `BRD_SM_CTRL_BUTTON` | NOTIFY |
| `BRD_SM_CTRL_PCA2131` | ALL |
| `BRD_SM_CTRL_TEST` | ALL |
| `BRD_SM_CTRL_TEST_A` | ALL |
| `BRD_SM_RTC_PCA2131` | ALL |
| `BRD_SM_SENSOR_TEMP_PF09` | SET |
| `BUTTON` | NOTIFY |
| `FUSA` | ALL |
| `LMM_2` | ALL |
| `RTC` | PRIV |
| `SENSOR_TEMP_ANA` | ALL |
| `SYS` | ALL |
**A55-sec — API 授权**（17 项）

| API | 权限 |
|---|---|
| `PERF_A55` | ALL |
| `PERLPI_CAN2` | ALL |
| `PERLPI_CAN3` | ALL |
| `PERLPI_CAN4` | ALL |
| `PERLPI_CAN5` | ALL |
| `PERLPI_GPIO2` | ALL |
| `PERLPI_GPIO3` | ALL |
| `PERLPI_GPIO4` | ALL |
| `PERLPI_GPIO5` | ALL |
| `PERLPI_LPUART1` | ALL |
| `PERLPI_LPUART4` | ALL |
| `PERLPI_LPUART5` | ALL |
| `PERLPI_LPUART6` | ALL |
| `PERLPI_LPUART8` | ALL |
| `PERLPI_WDOG3` | ALL |
| `PERLPI_WDOG4` | ALL |
| `SYS` | ALL |
**A55-NS — API 授权**（30 项）

| API | 权限 |
|---|---|
| `AUDIO_PLL1` | ALL |
| `AUDIO_PLL2` | ALL |
| `BRD_SM_CTRL_BT_WAKE` | NOTIFY |
| `BRD_SM_CTRL_BUTTON` | NOTIFY |
| `BRD_SM_CTRL_PCIE1_WAKE` | NOTIFY |
| `BRD_SM_CTRL_PCIE2_WAKE` | NOTIFY |
| `BRD_SM_CTRL_SD3_WAKE` | NOTIFY |
| `BRD_SM_CTRL_TEST_A` | ALL |
| `BRD_SM_RTC_PCA2131` | PRIV |
| `BRD_SM_SENSOR_TEMP_PF09` | ALL |
| `BUTTON` | ALL, test |
| `CLOCK_DISP1PIX` | ALL |
| `CLOCK_EXT` | ALL |
| `CLOCK_EXT1` | ALL |
| `CLOCK_EXT2` | ALL |
| `CLOCK_HSIOPCIEAUX` | ALL |
| `CLOCK_OUT1` | ALL |
| `CLOCK_OUT2` | ALL |
| `CLOCK_OUT3` | ALL |
| `CLOCK_OUT4` | ALL |
| `CLOCK_USBPHYBURUNIN` | ALL |
| `CLOCK_VPUDSP` | ALL |
| `HSIO_PLL` | ALL |
| `LDB_PLL` | ALL |
| `LMM_1` | NOTIFY |
| `PERF_A55` | ALL |
| `RTC` | ALL, test |
| `SENSOR_TEMP_A55` | ALL |
| `SENSOR_TEMP_ANA` | SET |
| `SYS` | NOTIFY |

### 七、故障反应（谁被复位）


**SM(M33) — 故障/反应**（3 项）

| 故障 | 反应 |
|---|---|
| `FAULT_SW3` | OWNER, reaction=grp_reset |
| `FAULT_SW4` | OWNER, reaction=sys_reset |
| `FAULT_DRAM` | OWNER, reaction=sys_reset |
**M7 — 故障/反应**（5 项）

| 故障 | 反应 |
|---|---|
| `FAULT_M7_LOCKUP` | OWNER, reaction=lm_reset |
| `FAULT_M7_RESET` | OWNER, reaction=lm_reset |
| `FAULT_SW0` | OWNER, reaction=fusa |
| `FAULT_SW1` | OWNER, reaction=lm_reset |
| `FAULT_WDOG5` | OWNER, reaction=lm_reset |
**A55-sec — 故障/反应**（3 项）

| 故障 | 反应 |
|---|---|
| `FAULT_SW2` | OWNER, reaction=lm_reset |
| `FAULT_WDOG3` | OWNER, reaction=lm_reset |
| `FAULT_WDOG4` | OWNER, reaction=lm_reset |

### 八、怎么改（操作路径）

1. 改 `configs/other/mx95frdm-pro.cfg`（建议先复制成自己的板名，例如 `mx95frdm-pro-<用途>.cfg`）；
2. 用 `devices/MIMX95/configtool` 生成配置头文件（`config_lmm.h` / `config_trdc.h` / `config_scmi.h` …）——
   本工程已有的产物示例：`tools\wsl\UbuntuBuild\rootfs\root\imx95-m7-gpio-build\imx-sm\configs\mx95frdm-pro-m7gpio\`；
3. 编译 SM → 得到新的 `m33_image.bin`；
4. 用 `imx-mkimage` 把它替换进启动容器（`flash.bin`），或经 UUU 下载验证；
5. **注意**：改归属前先确认该资源是不是 A55 启动链的依赖（历史上把 GPIO2 整块从 A55 拿走 → WDOG3 复位 LM2）。

### 九、注意与待确认

- 本文只反映 **SM 配置层**的授权；**TRDC/RDC 硬件规则**（`config_trdc.h`）是第二道闸门，尚未逐条整理（列入后续）。
- `A55 non-secure EENV` 有 287 项资源，是最大的区段；它对应 Linux/客户 OS 实际使用的那一套权限。
- 生成脚本对注释格式有依赖（`# Resources` 等小标题）；若 NXP 更新 `.cfg` 格式，脚本需同步调整。

### 关联

- `2026-09-17-理解-启动逻辑与资源隔离.md`（四层权限模型、串口归属）
- `2026-09-17-理解-02-上电启动全流程超详细.md`（启动顺序与启动命令表）

<!-- related-generated -->
## 相关

**同目录**

- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO开发记录.md|FRDM-IMX95-PRO开发记录]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解.md|FRDM-IMX95-PRO-FreeRTOS任务创建与LED代码理解]]
- [[10-项目/FRDM-IMX95-PRO/FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程.md|FRDM-IMX95-PRO从上手到FreeRTOS外设验证完整流程]]
