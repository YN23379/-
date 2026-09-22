---
type: 项目档案
scope: IMX95-EVK
doc_type: 操作
status: 待上板
evidence: 源码确认
tags: [多核与异构, 调试, 驱动, 安全与隔离]
updated: 2026-09-22
---

# A55 inmate 的 UART 收发与 GPIO 验证方案

> 板型：IMX95LPD5EVK-19（19x19 LPDDR5 EVK）
> 软件：Real-Time Edge 3.3 SD 镜像 + Harpoon（jailhouse v0.12）
> 证据等级：第一节到第四节若无特别标注，均为**源码确认**（cell 解码 + SDK 头 + harpoon-apps 源码 + SM 配置源码）。
> 第五节的操作**已实机执行完毕**（2026-09-22）。四项验证全部通过，见下面的「实测结论」。

## 一句话结论

**UART 收发、GPIO 输入、GPIO 输出四项已在 IMX95LPD5EVK-19 上实机验证通过。**

| 要求 | 状态 | 证据 |
|---|---|---|
| UART 发 | ✅ | 横幅和全部 `STEPn` 正常打出 |
| UART 收 | ✅ | 按键被逐个收到并回显（`got 0x00000077` 等） |
| GPIO 输入 | ✅ | 不按键时 `samples==0 : 0`；按住键时 `samples==0 : 2768`、`edges : 84` |
| GPIO 输出 | ✅ | 软件位翻转的字串被 PC 正常收到：`[[GPIO-TX]] bit-banged on GPIO2_IO14 @115200 [END]` |

**关键结论：加 GPIO 不需要改 SM 配置、不需要重烧启动容器。** 只要两处：

1. `.cell` 里加一段 RGPIO2（stage-2）
2. inmate 的一级页表加一条（stage-1，用 `app_mmu.h`）

SM 那一层（`mx95rte.cfg` 的 A55 non-secure 段）**本来就写了 `GPIO2 OWNER`**，不用动。

产物：

| 产物 | 路径 | 说明 |
|---|---|---|
| 新 cell | `build\a55-bin\imx95-harpoon-freertos-gpio.cell` | 在原 cell 基础上追加 1 段 RGPIO2 |
| 测试程序 | `build\a55-bin\hello_world.bin` | UART 收 + GPIO 输入 + GPIO 输出，菜单驱动 + 超时自动全跑 |
| cell 生成脚本 | `build\tools\cell_add_gpio.py` | 可重复执行，自带结构自检 |
| 程序源码 | `build\tools\verify_uart_gpio_main.c` | 安装到 `harpoon-apps/hello_world/freertos/main.c` |
| **app_mmu.h** | `build\tools\verify_app_mmu.h` | **必须一起装**，给 inmate 的一级页表补 GPIO2 |
| 安装+编译脚本 | `build\tools\install_and_build_verify.sh` | 一条命令装好上面两个并编译 |

> **踩坑记录（2026-09-22 第一次上板失败）**：只加了 cell 一段，程序一读 `GPIO2` 就死，
> COM 口上只剩崩溃前已经排空的一行。原因是 **jailhouse 的 cell 只是 stage-2，inmate 自己的
> 一级页表（stage-1 MMU）是另一张白名单**。详见第三节 3.4。

## 一、inmate 到底拿到了什么

`.cell` 是二进制，格式由 jailhouse 的 `include/jailhouse/cell-config.h` 定义（`JAILHOUSE_CONFIG_REVISION = 14`）。
按该结构解 `imx95-harpoon-freertos.cell`（772 字节，脚本 `build\tools\cell_real.py`），结果自洽：
解码消耗的字节数 0x304 正好等于文件长度。

头部：

```text
signature = "JHCLL"   architecture = 2 (ARM64)   revision = 14
name = "freertos"     flags = 0x80000001 = VIRTUAL_CONSOLE_ACTIVE | PASSIVE_COMMREG
cpu_set = 2000000000000000  -> CPU index 5      ← 与 UG10170 §1.4 的 0b100000 一致
cpu_reset_address = 0xf0000000                  ← 与 jailhouse cell load -a 一致
num_memory_regions = 16, num_irqchips = 2, num_pci_devices = 1
```

16 个内存段：

| # | phys | size | flags | 是什么 |
|---|---|---|---|---|
| 0 | 0xff9f0000 | 0x1000 | R\|ROOTSHARED | ivshmem 共享区 |
| 1 | 0xff9f1000 | 0x9000 | R\|W\|ROOTSHARED | 同上 |
| 2 | 0xff9fa000 | 0x2000 | R\|ROOTSHARED | 同上 |
| 3 | 0xff9fc000 | 0x2000 | R\|W\|ROOTSHARED | 同上 |
| 4 | 0xff9fe000 | 0x2000 | R\|ROOTSHARED | 同上 |
| 5 | 0xc0000000 | 0x1000 | R\|W\|IO\|ROOTSHARED | RPMsg 共享区（harpoon dtb 的 reserved-memory） |
| 6 | 0xc0100000 | 0x10000 | R\|W\|ROOTSHARED | 同上 |
| 7 | 0xc0200000 | 0x100000 | R\|W\|ROOTSHARED | 同上 |
| **8** | **0x424f0000** | 0x10000 | R\|W\|IO | **TPM4** |
| **9** | **0x42570000** | 0x10000 | R\|W\|IO | **LPUART3（inmate 控制台）** |
| **10** | **0x44320000** | 0x10000 | R\|W\|IO | **TPM2** |
| 11 | 0x445d0000 | 0x1000 | R\|W\|IO | MU3_MUA（`AON__MUI_A3__MUA`），与 SM 通信的邮箱 |
| 12 | 0x445d1000 | 0x1000 | R\|W\|ROOTSHARED | SMT 共享内存 |
| 13 | 0xf0000000 | 0x1000000 | R\|W\|X\|LOAD | inmate 代码区（16 MB） |
| 14 | 0x20480000 | 0xa0000 | R\|W\|X | OCRAM |
| 15 | 0x00000000 | 0x1000 | R\|W\|COMM | jailhouse 通信页 |

两个 irqchip（都是 GICD 0x48000000）：

| irqchip | pin_base | 位图 | 授权的中断号 | 对应外设 |
|---|---|---|---|---|
| 0 | 32 | `40000000 00000000 40000401 00000000` | 62 / 96 / 106 / 126 | TPM2_IRQn / **LPUART3_IRQn** / TPM4_IRQn / Reserved126 |
| 1 | 160 | `00000000 00000000 00000000 00000010` | 260 | MU3_A_IRQn（SCMI 邮箱） |

中断号来源：`mcux-sdk/devices/MIMX9596/MIMX9596_ca55.h`（`TPM2_IRQn=62`、`LPUART3_IRQn=96`、`TPM4_IRQn=106`、`MU3_A_IRQn=260`）。

**结论：LPUART3 的寄存器窗口和中断号都在 cell 里，收发两个方向都没有 jailhouse 这一层的障碍。**

## 二、UART 为什么能直接验

| 环节 | 证据 | 位置 |
|---|---|---|
| 用哪个串口 | `BOARD_DEBUG_UART_BASEADDR = LPUART3_BASE`、`BOARD_DEBUG_UART_INSTANCE = 3` | `common/freertos/boards/imx95lpd5evk19/board.h:25-27` |
| 用哪个中断 | `BOARD_UART_IRQ = LPUART3_IRQn`、`BOARD_UART_IRQ_HANDLER = LPUART3_IRQHandler` | 同上 `board.h:28-29` |
| 引脚怎么配 | `pin_mux_lpuart3()` **同时**配 TX（`GPIO_IO14__LPUART3_TX`）和 RX（`GPIO_IO15__LPUART3_RX`），RX 带输入使能 + 下拉（`PAD_PD_MASK`），TX 带驱动能力 `DSE(15)` | `board.c:26-35` |
| 引脚谁来配 | `hal_config.h` 里 `SM_PINCTRL=1`、`IOMUXC_PINCTRL=0`，`hal_pinctrl.c:18-38` 走 `SM_PINCTRL_SetPinMux()` 经 SCMI 请 SM 代写 → **cell 不需要映射 IOMUXC** | `components/pinctrl/hal_pinctrl.c` |

物理通路（`UM12022` §1.7 Table 6 原文）：D24/D25 是 "Cortex M7 UART" 的收发指示灯，正文注明
"UART3 TXD and RXD signals for debugging the Arm Cortex-M7 core of the target processor are muxed with
GPIO_IO14 and GPIO_IO15"。这两个脚走 FT4232H 通道 A（`UM12022` §2.21.5：`FTA_SEL` 为低时通道 A 作 UART）。
**所以 inmate 的控制台和 M7 的调试串口是同一个物理口**，就是看到 `Goodbye world` 的那个 COM 口。

**当前只缺软件**：`common/freertos/uart.c:16` 用
`#if (defined(UART_ADAPTER_NON_BLOCKING_MODE) && (UART_ADAPTER_NON_BLOCKING_MODE > 0U))` 包住中断收，
而这个宏**全工程和 mcux-sdk 里都没有定义**（grep 命中的全是使用处）→ `uart_irq_init()` 是空函数。
另外 `flags.cmake` 里传了 `-DDEBUG_CONSOLE_RX_ENABLE=0`，调试控制台本身也不做接收。

本方案**不打开中断收**，改成直接轮询 `LPUART3->STAT[RDRF]` 读 `LPUART3->DATA`，
并在初始化时自己补一句 `LPUART_EnableRx(LPUART3, true)`（打开 `CTRL[RE]`，bit18）。
这样不碰 CMake、不碰共享的 `flags.cmake`，改动面最小。

## 三、GPIO 为什么缺一段，缺的是什么

### 3.1 SM（TRDC/RDC）这一层已经放行

板上 RTE 镜像用的 SM 配置是 **`mx95rte.cfg`**（`tools\imx-sm-src\imx-sm-master\configs\other\mx95rte.cfg`，1019 行）。

`LM2`（AP）内部再分两段，**Linux 和 jailhouse inmate 都跑在第二段（A55 non-secure）**：

```text
419  LM2   name="AP", rpc=scmi, boot=3, skip=1, did=3, default
415  # A55 secure EENV          （419–524 行）
525  # A55 non-secure EENV      （525 行起）
529  DFMT0: sa=nonsecure
```

A55 non-secure 段的资源表里：

| 行 | 内容 |
|---|---|
| 723-726 | `GPIO2 OWNER`、`GPIO3 OWNER`、`GPIO4 OWNER`、`GPIO5 OWNER` |
| 768 | `LPUART3 ACCESS` |
| 925-926 | `PIN_GPIO_IO14 ACCESS`、`PIN_GPIO_IO15 ACCESS` |
| 911-948 | 其余 `PIN_*` 都是 `OWNER` |
| 209（LM0/SM 段） | `GPIO1 OWNER` ← **GPIO1 归 SM，动不了** |
| 221（LM0/SM 段） | `IOMUXC OWNER` ← **IOMUXC 寄存器 inmate 不能直读，所以没法回读 mux 值** |

inmate 的 SCMI 身份：`mx95rte.cfg:540` 是 `SCMI_AGENT2 name="AP-NS-agent0" / MAILBOX type=mu, mu=3`（Linux 用的就是它），
1007/1014 行又声明了 `AP-NS-agent1`（mu=5）和 `AP-NS-agent2`（mu=7），两个都标了 **`dup=2`（AP-NS-agent0 的副本）**。

inmate 侧源码用的是 MU3：

```text
common/freertos/boards/imx95lpd5evk19/sm_config.h:10   SM_PLATFORM_MU_INST 7 /* MU3 */
mcux-sdk/components/sm/porting/platform/imx95/ca55/sm_platform.h:22  #define SM_PLATFORM_MU_INST 7 /* default MU3_MUA */
```

`MU3_MUA = AON__MUI_A3__MUA = 0x445D0000`，正是 cell 内存段 [11]；`MU3_A_IRQn = 260`，
正是 cell irqchip[1] 授权的那个号。两边完全对上。

**判断**：inmate 以 `dup=2` 方式继承 A55 non-secure 段的资源权限，所以 **GPIO2 在 SM/TRDC 层已经可用**。

> **2026-09-22 实机验证：判断成立。** 测试 `[2a]`/`[2b]`/`[2c]` 三个 SCMI 请求
> （含把 `GPIO_IO15` 切成 GPIO 功能）全部返回 `SUCCESS`，说明 SM 这一层确实已经放行，
> **不用改 SM 配置，也不用重烧启动容器**。

### 3.2 jailhouse 这一层缺 RGPIO 的地址段

16 个内存段里**没有任何一个落在 RGPIO 上**：

| 实例 | 基地址 | 原 cell 里有吗 |
|---|---|---|
| GPIO1 | 0x47400000 | 否（且归 SM） |
| **GPIO2** | **0x43810000** | **否** |
| GPIO3 | 0x43820000 | 否 |
| GPIO4 | 0x43840000 | 否 |
| GPIO5 | 0x43850000 | 否 |

`industrial` 版 cell 也一样（它多出来的是 CAN2 `0x425b0000`、MSGINTR2 `0x446a0000`、NETC 那一组
`0x4ca00000`/`0x4cac0000`/`0x4cc00000`/`0x4ccc0000`/`0x4cd00000`，中断多给 `CAN2_IRQn=70` 和 `MSGINTR2_IRQn=269`）。

### 3.3 第一处：往 cell 里加一段 RGPIO

`build\tools\cell_add_gpio.py` 在原 cell 的 memory_regions 末尾追加一段，并把段数从 16 改成 17：

```text
phys = 0x43810000   virt = 0x43810000   size = 0x1000   flags = 0x0013 (R|W|IO)
```

顺带把 cell 的 `name` 从 `freertos` 改成 `freertos-gpio`，这样不会覆盖板上已知可用的那份。

窗口大小取 4 KB 的依据：`RGPIO_Type` 结构体（`MIMX9596_ca55.h:385152-385176`）最大的寄存器是
`ISFR[2]`，结束在 0x128，4 KB 足够；Linux 设备树里 `gpio@43810000` 的 `reg` 也是 `<0x00 0x43810000 0x00 0x1000>`。

**没有加 GPIO 中断**：本方案只做电平和方向，用不上引脚中断。

脚本自检三项：结构解析长度==文件长度、原有 16 段逐字节未变、尾部（irqchip/pci 等）逐字节未变。
再加独立解码器交叉验证：

```text
imx95-harpoon-freertos-gpio.cell  (804 字节)
  name='freertos-gpio'  mem=17  irqchip=2  pci=1
  cpu_reset_address = 0xf0000000   cpu_set -> CPU 5
   [16] phys=0x43810000 virt=0x43810000 size=0x1000  flags=0x0013 R|W|IO
  consumed 0x324 / file 0x324
```

### 3.4 第二处：inmate 的一级页表（第一次上板就死在这里）

**这是本次最容易漏掉的一层。** jailhouse 的 cell 配的是 **stage-2**（hypervisor 的二级页表），
而 inmate 自己在 `BOOT_InitMemory()` 里建的是一张 **stage-1 白名单**。两张表都放行，物理访问才通。

白名单在 `common/freertos/boards/imx95lpd5evk19/mmu.c:87-116`：

```c
static const struct ARM_MMU_region mmu_regions[] = {
	MMU_REGION_FLAT_ENTRY("GIC",     GIC_DISTRIBUTOR_BASE, KB(1216), ...),
	MMU_REGION_FLAT_ENTRY("LPUART3", LPUART3_BASE,         KB(64),   ...),
	MMU_REGION_FLAT_ENTRY("MU3",     AON__MUI_A3__MUA_BASE, KB(4),   ...),
	MMU_REGION_FLAT_ENTRY("TPM2",    TPM2_BASE,            KB(64),   ...),
	MMU_REGION_FLAT_ENTRY("TPM4",    TPM4_BASE,            KB(64),   ...),
	MMU_REGION_FLAT_ENTRY("MU3_SRAM", AON__MUI_A3__MUA_BASE + 0x1000, KB(4), ...),
#ifdef APP_MMU_ENTRIES
	APP_MMU_ENTRIES
#endif
};
```

**GPIO2 不在里面。** 所以即使 cell 配了，读 `0x43810000` 仍然是 **EL1 translation fault**，
hypervisor 直接把整个 cell 打死。

补法用的是 NXP 自己留的口子，**不用改公共的 `mmu.c`**：在应用自己的板级目录下放一个 `app_mmu.h`。
`mmu.c:7-9` 有 `#if __has_include("app_mmu.h")`，`mmu.c:113-115` 有 `#ifdef APP_MMU_ENTRIES`。

NXP 的 `industrial` 应用就是这么补 CAN2 的：

```text
industrial/freertos/boards/imx95lpd5evk19/app_mmu.h
    #define APP_MMU_ENTRIES		\
        MMU_REGION_FLAT_ENTRY("CAN2", CAN2_BASE, KB(64), \
                              MT_DEVICE_nGnRE | MT_P_RW_U_RW | MT_NS),  \
```

本项目照抄，新建 `hello_world/freertos/boards/imx95lpd5evk19/app_mmu.h`（源码见 `build\tools\verify_app_mmu.h`）：

```c
#define APP_MMU_ENTRIES		\
	MMU_REGION_FLAT_ENTRY("GPIO2",					\
			      GPIO2_BASE, KB(4),			\
			      MT_DEVICE_nGnRE | MT_P_RW_U_RW | MT_NS),  \
```

**验证这个文件真的生效了**（编译级铁证，不用上板）：

```text
CMakeFiles/.../mmu.c.obj.d   里出现 app_mmu.h        <- 头文件被包含了
objdump -s hello_world.elf   里出现 GPIO2 的页表条目 0x43810000
```

#### 3.4.1 第一次上板的失败过程（留档）

只加了 cell 那一段就上板，结果：

```text
COM9:
INFO: verify build running (UART + GPIO test)
（之后什么都没有，敲键也没反应）
```

**排查思路**：`hello_func` 和 `verify_task` 都是最高优先级，`verify_task` 里有一段
`vTaskDelay(pdMS_TO_TICKS(10))`，所以它让出 CPU 时 `hello_func` 打出了那一行。
之后 `verify_task` 恢复运行，打进横幅等 5 行，然后读 `GPIO2->VERID` → 异常 → cell 被打死。
**横幅那 5 行是丢在输出缓冲里了**，不是没执行。

两个原因叠在一起：

| 现象 | 原因 |
|---|---|
| 一行横幅都看不到 | 调试控制台是**非阻塞**的（`flags.cmake` 里 `-DDEBUG_CONSOLE_TRANSFER_NON_BLOCKING=1`，实现里走 `SerialManager_WriteNonBlocking`），输出先进环形缓冲；inmate 一死，缓冲里的字全部丢掉 |
| 一读 GPIO2 就异常 | cell 配了 stage-2，但 inmate 的一级页表白名单里没有 GPIO2 |

**两条对应的改法**：

1. 验证程序里所有关键输出改成直接调 `LPUART_WriteBlocking(LPUART3, ...)`，绕开环形缓冲；
   并且把流程改成"**先报再做**"（`STEP0`/`STEP1`/...），看到最后一条 STEP 就知道下一步死在哪。
2. 新建 `app_mmu.h` 补一级页表条目。

改完之后的输出长这样，出问题能一眼定位：

```text
STEP0: banner ok -> LPUART3 TX works
STEP1: cntfrq = 0x016E3600
STEP1: bit_ticks per bit = 208
STEP2: enabling LPUART3 RX ...
STEP2: done
STEP3: reading RGPIO2 @0x43810000 (cell + MMU check) ...
STEP3: VERID = 0x........
STEP3: GPIO2 reachable -> cell entry AND MMU entry both OK
```

**这条经验的通用形式**：在 Harpoon inmate 上新增一个外设，要连过**三层**——
SM 资源表（TRDC/RDC）→ jailhouse cell（stage-2）→ inmate 一级页表（stage-1）。
前两层是"能不能访问"，第三层是"地址有没有映射"。缺任何一层，现象都是"程序直接没了"。

### 3.5 引脚选哪根、怎么观察

EVK 上**没有用户可控的 LED，也没有接到 SoC 的用户按键**（`UM12022` §1.7/§1.8 逐条列出）：

- LED：D2–D5 电源指示、D12/D13 CAN 收发器 INH、D22/D23 Wi-Fi/BT 状态、D24/D25 UART3 收发指示、D38–D40 FT4232H/PMIC 状态——**全部由硬件或 PHY 驱动**。
- 按键：SW2 → PMIC 的 `FCCU1`；SW3 → SoC 的 `ONOFF` 脚；SW5/SW6 → CAN 收发器 `WAKE`；SW8 → I2C 扩展器 `PCAL6408A`。
- J37（1x4 排针，`M2_GPIO1/2/3_RSVD`）**默认不焊**；J20/J21 是 ADC 输入排针。
- `PIN_GPIO_IO14/15` 之外，A55 non-secure 段虽然把别的 `PIN_*` 标成 `OWNER`，但那些脚在板上都没有引出到可插线的地方。

#### ★ 这些 GPIO 脚在板上到底在哪（原理图追出来的）

**结论：这块 EVK 没有任何 GPIO 排针，和 Pro 板完全不一样。** 原因是它是 **SOM + 底板** 两块板的结构。

追一遍 `GPIO_IO00–IO37` 这 38 根网络在两块原理图里的走向：

| 在哪 | 出现的位置 | 说明 |
|---|---|---|
| **SOM 原理图** `SPF-87754_B1.pdf` | p6（SoC 引脚）、**p11（板对板连接器 J1/J2/J3/J5）** | 38 根**全部**走到板对板连接器 |
| **底板原理图** `SPF_87753_B.pdf` | **只有 p4**（J1–J4 连接器页） | 底板上**没有任何功能电路**用它们 |

**也就是说：这 38 根脚停在 J1–J4 的连接器焊盘上，没有引到任何能插线的地方。** 板对板连接器是 0.4 mm 间距的 DF40 系列，SOM 压在上面，探针根本伸不进去。

**唯一的例外是 `GPIO_IO14` / `GPIO_IO15`**，它们多走了一段：

```text
SOM 原理图 p7（调试串口电路）
  GPIO_IO15 ──→ UART3_RXD ──→ TP212 ─┐
  GPIO_IO14 ──→ UART3_TXD ──→ TP213 ─┤
                                     │  页面标注：#UART3  CORTEX-M7  CONSOLE
                                     │  另一处标注：# UART3 muxed with GPIO14/15
                                     ↓
底板原理图 p4（J1–J4 连接器页）
  GPIO_IO14 / GPIO_IO15 ──→ UART3_TXD / UART3_RXD ──→ TP280 / TP281
                                     ↓
底板原理图 p24（FT4232H / 远程调试页）
  UART3_RXD / UART3_TXD ──→ TP273 / TP274 ──→ FT4232H 通道 A
                                     ↓
                            J31（USB Type-C）──→ PC 上的 COM9
```

**所以 `GPIO_IO14/15` 的物理观察点是有的**：

| 观察方式 | 位置 | 依据 |
|---|---|---|
| **串口** | J31 → PC 的 **COM9** | `UM12022` §2.21.5，`FTA_SEL` 低时通道 A 作 UART |
| **测试点（SOM 侧）** | **TP212（RXD）/ TP213（TXD）** | SOM 原理图 p7 |
| **测试点（底板侧）** | **TP280 / TP281** | 底板原理图 p4 |
| **测试点（FT4232H 侧）** | **TP273 / TP274** | 底板原理图 p24 |

**量电平建议用底板上的 TP280/TP281 或 TP273/TP274** —— SOM 是叠在上面的，TP212/213 在 SOM 板上不好碰。

> **这些测试点的坐标是原理图文字提取出来的，没在实物上核对过**（`待验证`）。上板前先对照 `LAY-87753_B.brd` 或 PCB 丝印找一下位置。

#### J37 那三个脚不是 SoC GPIO

之前看着像 GPIO 排针的 **J37**（1x4，DNP 未焊），追下来是 **M.2 连接器（J24）的保留信号**：

- 网络名 `M2_GPIO1_RSVD` / `M2_GPIO2_RSVD` / `M2_GPIO3_RSVD`
- 底板原理图 p19 上它们和 `M.2 SKT KEY-E`、`WIFI/BT Module` 画在同一块，还串了 **DNP 的 100K 电阻（R851/R852）**
- `M2` 指的是 **M.2 连接器**，不是 SOM

**所以 J37 和 SoC 的 GPIO 没有关系，焊上排针也测不了。**

#### I2C 扩展器的引脚也全被占了

板上 6 片 I2C GPIO 扩展器（`UM12022` §2.6，Table 20–27），逐个看下来：

| 器件 | 地址 | 引脚用途 |
|---|---|---|
| U15 PCAL6524 | 0x22 | USB 电源、PCIe 复位、M.2 控制、eMMC 复位、时钟选择 |
| U16 PCAL6408A | 0x20 | Wi-Fi/BT 唤醒、PMIC 状态、SW8 按键 |
| U88 PCAL6416A | 0x21 | ENET2、CAN1 收发器控制、PDM/CAN 选择 |
| U93 PCAL6408A | 0x21 | 10G PHY 复位、ENET1 复位 |
| U86 PCAL6408A | 0x21 | 音频编解码器、CAN2 收发器控制 |
| U94 PCAL6408A | 0x20 | CSI 摄像头复位（DNP） |

**没有一片是空着给用户用的。** 只有零星几个引脚标 "Not connected"（U93 P4–P7、U86 P6、U15 P2_5/6/7），但那是 I2C 扩展器的脚，不是 SoC GPIO，而且也要飞线才够得着。

#### 在文档里怎么查这类问题

| 想查什么 | 去哪 |
|---|---|
| 板上有没有某个连接器 | `UM12022` **Table 3**（p9）连接器总表、**Table 4**（p10）SOM 连接器 |
| LED / 按键接在哪 | `UM12022` **§1.7**（p11）LED、**§1.8**（p12）按键 —— 两张表逐条列了信号名 |
| I2C 扩展器的引脚分配 | `UM12022` **§2.6**（p27–30）Table 20–27 |
| 某个 SoC 信号在板上走哪 | **底板原理图** `SPF_87753_B.pdf`，按网络名全文搜 |
| SoC 引脚 → SOM 连接器 | **SOM 原理图** `SPF-87754_B1.pdf` p6（引脚）、p11（连接器） |
| 板对板连接器每个脚是什么 | **底板原理图 p4** |
| 测试点在哪 | 底板原理图 p4 / p24；SOM 原理图 p7 / p11 |

**顺带一个观察**：底板上 `TP` 开头的测试点很多（p1、p4–p15、p19–p24 都有），但**绝大多数是电源轨和接口信号的**。搜下来只有 UART3 这组挂了 `GPIO_IO14/15` 的网络名。

所以只能用 `GPIO_IO14` / `GPIO_IO15` 这两根，而它们正是 LPUART3 的 TX/RX，mux 值 0 就是 `GPIO2_IO14` / `GPIO2_IO15`
（`hal_pinctrl_platform.h:160-161,167-168`，`__GPIO2_IO_BIT14` / `__GPIO2_IO_BIT15` 的 muxMode 都是 `0x00`）。

围绕"只有这一个 COM 口"这一点，测试程序的设计是：

| 测试 | IO14 | IO15 | 观察方式 | 需要外部器件吗 |
|---|---|---|---|---|
| [1] UART 收 | LPUART3_TX（控制台） | LPUART3_RX | 在终端敲键，看回显 | 不用 |
| [2] GPIO 输入 | LPUART3_TX（控制台） | **GPIO2_IO15 输入** | 按住键时该线出现低电平，程序统计 0 的样本数和跳变次数，结果打到控制台 | 不用 |
| [3] GPIO 输出 | **GPIO2_IO14 输出** | LPUART3_RX | 软件位翻转在 IO14 上发一段文字，同一个终端能收到就是通了 | 不用 |

- 测试 [2] 只动 IO15，**控制台（IO14）始终是 LPUART3_TX**，所以结果能正常打印。
- 测试 [3] 要动 IO14，**期间控制台 TX 断开**，所以程序在切走之前先声明"下面这段是位翻转出来的"，
  发完 `[[GPIO-TX]]` 之后再往 LPUART3 写一遍 `[[LPUART3-TX]]`，最后把 IO14 切回 LPUART3_TX。

  这样看到哪个 marker 就能直接定位问题：
    - 只看到 `[[GPIO-TX]]` → 复用生效 + GPIO 输出正常；
    - 只看到 `[[LPUART3-TX]]` → SM 没接受 mux 请求（引脚还是 LPUART3_TX）；
    - 两个都没看到 → 位翻转代码或时序有问题。

- 位翻转速率取 **115200**，和调试控制台同速率，**终端不用切波特率**。时间基准用 ARM generic timer：
  `mrs cntvct_el0` 读计数、`mrs cntfrq_el0` 读频率。可用性有源码依据——FreeRTOS 的 tick 用的就是
  这个 EL1 虚拟定时器（`common/freertos/FreeRTOS_tick_config.c:40` `#define ARM_TIMER ARM_TIMER_VIRTUAL`）。
  每个字节发送期间关中断（`taskENTER_CRITICAL`），避免 1 ms 的 tick 打断 87 µs 的字节。

### 3.6 还有一层：PCNS/PCNP

之前在 Pro 板上踩过一次：BL31 的 `bl31_plat_arch_setup()` 会把 GPIO2 的 `PCNS`/`PCNP` 全写成 `0xffffffff`，
把所有权引脚设成非安全/非特权，导致当时**安全特权态**的 M7 读 0、写无效
（见 [SD启动GPIO权限问题结论](../FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md)）。

A55 上的 Linux/inmate 是**非安全**态，和 BL31 设的属性方向一致，**预计不会撞**。这是**推测**，
所以测试 [0] 会把 `PCNS`/`PCNP` 原样打出来，实机一看就知道。

## 四、测试程序长什么样

源码：`build\tools\verify_uart_gpio_main.c`（安装到 `harpoon-apps/hello_world/freertos/main.c`）。
编译产物：`build\a55-bin\hello_world.bin`，70,104 字节，入口 `0xf0000000`，
sha256 `da8fca32f62cb1da0cda43c77f4dd86710c9b2956cde62499b47efe5fb2b1e25`。

上电后先自动打一段诊断，然后进菜单：

```text
===== A55 inmate UART / GPIO 验证 =====
  RGPIO2_BASE  = 0x43810000
  LPUART3_BASE = 0x42570000
  cntfrq       = 24000000 Hz

-- [0] RGPIO2 寄存器直读  base=0x43810000 --
   VERID=0x........  PARAM=0x........
   PDDR =0x........  PDOR =0x........  PDIR =0x........
   PIDR =0x........  PCNS =0x........  PCNP =0x........
   判定：VERID 不是 0 也不是 0xFFFFFFFF 就说明寄存器读到了

命令：1=UART收  2=GPIO输入  3=GPIO输出  4=全部  5=再读寄存器
>
```

**[0] 是全流程最关键的一步**：能打印出这几行，说明 `0x43810000` 真的可访问了，cell 改动生效。
如果打完标题就卡死或整块复位，说明访问被拦——那就回到第三节检查 cell 和 SM。

各命令的行为：

- `1` UART 收：等 10 秒，期间在终端敲任意键。收到就打印 `收到 0x41 ('A') -> UART 收 OK`。
- `2` GPIO 输入：提示"现在开始采样 8 秒，请一直按住键盘上任意一个键不放"，
  然后把 IO15 切成 `GPIO2_IO15` 输入，密集采样 `PDIR`，统计 1/0 的样本数和跳变次数。
- `3` GPIO 输出：把 IO14 切成 `GPIO2_IO14` 输出，软件位翻转发 `[[GPIO-TX]] ...`，
  再写一遍 `[[LPUART3-TX]] ...`，最后切回 LPUART3_TX。
- `4` 依次跑 1、2、3。
- `5` 重新读一遍寄存器。

**关于 `2` 的采样方式**：不是慢慢轮询，而是 40 轮"忙采样 100 ms + 让出 100 ms"，
总共约 8 秒。忙采样期间一秒能取几十万次样本，所以 115200 下 87 µs 的起始位能被抓到。

### 4.4 v2 的形态（实际在板上跑的那一版）

上面 4.1–4.3 描述的是 v1。v1 上板后一读 GPIO2 就死，原因是输出走了非阻塞缓冲 +
一级页表缺 GPIO2（见 3.4.1）。v2 改了两件事：

1. **所有关键输出改成 `say()`**，直接 `LPUART_WriteBlocking(LPUART3, ...)`，绕开环形缓冲：

```c
static void say(const char *s)
{
    (void)LPUART_WriteBlocking(LPUART3, (const uint8_t *)s, strlen(s));
}
```

   数值打印也自己写了 `say_hex` / `say_dec`（手写 16 进制 / 10 进制），不依赖 `printf`。

2. **启动自检改成"先报再做"**，每步一个 `STEPn`：

```text
==================================================
===== A55 inmate UART / GPIO verify (v2)     =====
==================================================
STEP0: banner ok -> LPUART3 TX works
STEP1: reading cntfrq_el0 ...
STEP1: cntfrq = 0x016E3600
STEP1: bit_ticks per bit = 208
STEP2: enabling LPUART3 RX ...
STEP2: done
STEP3: reading RGPIO2 @0x43810000 (cell + MMU check) ...
STEP3: VERID = 0x02010001
STEP3: GPIO2 reachable -> cell entry AND MMU entry both OK
STEP4: RGPIO2 register dump
   VERID=0x02010001  PARAM=0x00000002
   PDDR =0x00000010  PDOR =0x00000010  PDIR =0x00000034
   PIDR =0x00000000  PCNS =0xFFFFFFFF  PCNP =0xFFFFFFFF
commands: 1=UART RX  2=GPIO IN  3=GPIO OUT  4=all  5=dump regs
>
```

| STEP | 做什么 | 过了说明什么 |
|---|---|---|
| 0 | 打横幅 | LPUART3 发送通 |
| 1 | `mrs cntfrq_el0` | generic timer 可读（位翻转的时间基准） |
| 2 | `LPUART_EnableRx(LPUART3, true)` | 打开了 `CTRL[RE]`（调试控制台自己没开接收） |
| 3 | 读 `GPIO2->VERID` | **cell（stage-2）+ 一级页表（stage-1）都通了** |
| 4 | 读全部 RGPIO2 寄存器 | 寄存器可读，顺便看 `PCNS`/`PCNP` |

**STEP3 是关键分界点**：没补 `app_mmu.h` 时会停在 `STEP3: reading ...` 那一行不动。

v2 还把 `hello_func` 去掉了（只留 `verify_task` 一个任务），
免得两个同优先级任务的执行顺序不确定、把输出搅乱。

### 4.5 v3（已做，待上板）

v2 的菜单只认 `1`–`5`，实测时在提示符下随手按键（收到 `0x61`/`0x44`/`0x77`/`0x64`/`0x39`）
全都回 `unknown command`。**输入本身是好的**（16 个字节值都对），是菜单太窄。v3 改了：

- 加字母别名：`r`=UART RX、`i`=GPIO 输入、`o`=GPIO 输出、`a`=全跑、`d`=dump 寄存器
- 加超时兜底：进菜单 5 秒没有有效命令就**自动把三个测试全跑一遍**
- GPIO 输入测试改成"先提示、等 5 秒、再采样 8 秒"，原来只提示一次来不及按住键

v3 产物：70,096 字节，入口 `0xf0000000`，
sha256 `ac3b158481bb3ba801951caaa452741484ffbb0818aea34258109744b98ea260`。

### 4.6 v3 实测卡住 → 发现 NXP SDK 的死循环，做 v4

v3 自动跑的结果：`[1] UART RX` 通过（收到 `0x32`），走到

```text
-- [2] GPIO IN: mux GPIO_IO15 -> GPIO2_IO15 --
```

**就再没有任何输出，也不回菜单。**

#### 根因：`sm_pinctrl.c` 出错时死循环

`mcux-sdk/components/sm/pinctrl/sm_pinctrl.c`：

```c
/* 第 55-57 行，SM_PINCTRL_SetPinMux 里 */
status = SCMI_PinctrlSettingsConfigure(channel, ..., configs);
/* Find something wrong ASAP(components/scmi/scmi_common.h: scmi error code) */
while (status != SCMI_ERR_SUCCESS);          /* ← status 再也不会被更新 */

/* 第 88-90 行，SM_PINCTRL_SetPinCfg 里同样 */
status = SCMI_PinctrlSettingsConfigure(channel, ..., &configs);
while (status != SCMI_ERR_SUCCESS);
```

**只要 SCMI 返回的不是 `SUCCESS`，这里就是死循环**——不返回、不打印、不超时。
现象就是"打完标题就没了"，而且 cell **还活着**（没有被 hypervisor 杀），占着 CPU 空转。

这解释了 v3 为什么卡在 `[2]`：`HAL_PinctrlSetPinMux(PIN_IO15_AS_GPIO2_IO15, 0U)` 里那次
SCMI 请求没成功。

#### 但为什么启动时的 LPUART3 请求没事

`board.c:26-35` 的 `pin_mux_lpuart3()` 也调同一个函数。**如果它也失败，程序在启动时就挂了，
我们连横幅都看不到。** 所以启动时那几次请求是 `SUCCESS` 的。

那么问题就变成二选一：

| 假设 | 现象会是什么 |
|---|---|
| A. SM 只肯给 LPUART3 功能，**不肯给 GPIO 功能**（`PIN_GPIO_IO15` 在 SM 配置里对 A55 只有 `ACCESS`，M7 才是 `OWNER`） | 启动成功、切 GPIO 失败。**要改 SM 配置并重烧启动容器** |
| B. SCMI 通路偶发失败（inmate 和 Linux **共用 MU3** 这个 SCMI agent，抢同一条 SMT 通道） | 时好时坏，重试可能就过 |

**两个假设的现象不一样，但都被那个死循环吞掉了**，必须把状态码打出来才能分辨。

#### v4 怎么改

1. **不再用 `HAL_PinctrlSetPinMux` / `HAL_PinctrlSetPinCfg`**，自己实现 `scmi_mux()` / `scmi_cfg()`。
   逻辑和 `sm_pinctrl.c` 一样（同样的 `scmi_pin_config_t`、同样的 attributes 算法），
   但**把状态码 return 出来**，并且打印成人能读的名字：

```c
static uint32_t scmi_mux(uint32_t muxRegister, uint32_t muxMode, ...)
{
    ...
    return SCMI_PinctrlSettingsConfigure(SM_PLATFORM_A2P, ..., attrs, configs);
}
```

2. **每一步先报再做**，并且把 SCMI 状态码打出来。关键是 `[2a]` 这个**校准点**：
   它发的是和启动时**一模一样**的 LPUART3 请求，所以它必须是 `SUCCESS`；
   如果它也失败，说明是假设 B（通路问题），而不是权限问题。

```text
-- [2] GPIO IN: mux GPIO_IO15 -> GPIO2_IO15 --
    [2a] scmi mux IO15 -> LPUART3_RX (same as boot) ...
    [2a] status = 0x00000000
             = SUCCESS
    [2b] scmi mux IO15 -> GPIO2_IO15 ...
    [2b] status = 0x........        <- 关键就看这一行
             = ...
```

3. **所有"切回去"的地方也改用安全版**。原来 `test_gpio_output()` 结尾用
   `HAL_PinctrlSetPinMux(PIN_IO14_AS_LPUART3_TX, 0U)` 把控制台切回来——
   **这一步要是死循环，控制台就永远回不来了**。v4 全改成 `scmi_mux()`。

4. 状态码翻译表（`components/imx_sm/components/scmi/scmi_common.h`）：

| 值 | 名字 | 含义 |
|---|---|---|
| 0 | `SCMI_ERR_SUCCESS` | 成功 |
| -1 | `NOT_SUPPORTED` | 不支持这个命令/特性 |
| -2 | `INVALID_PARAMETERS` | 参数不对 |
| -3 | `DENIED` | **没有权限** —— 假设 A 就是它 |
| -4 | `NOT_FOUND` | **SM 不认识这个引脚** —— SM 配置里没这一项 |
| -5 | `OUT_OF_RANGE` | 超出合法范围 |
| -6 | `BUSY` | 平台资源忙 |
| -7 | `COMMS_ERROR` | 消息没能正确传输 —— 假设 B |
| -8 | `GENERIC_ERROR` | 通用失败 |
| -9 | `HARDWARE_ERROR` | 硬件错 |
| -10 | `PROTOCOL_ERROR` | 协议错 |
| -11 | `IN_USE` | 资源被平台占用 |
| -129 | `CRC_ERROR` | CRC 校验失败 —— 假设 B |
| -133 | `SEQ_ERROR` | 收发序列错 —— 假设 B |

v4 产物：74,192 字节，入口 `0xf0000000`，
sha256 `cfa89895b73f35dfa45f50eeeb9d16eb869e181a98e990caf6199a187cfbe25c`。

#### v4 实测结果：全部 SUCCESS

```text
[2a] scmi mux IO15 -> LPUART3_RX (same as boot) ...  status = SUCCESS
[2b] scmi mux IO15 -> GPIO2_IO15 ...                 status = SUCCESS
[2c] scmi cfg IO15 pull-down ...                     status = SUCCESS
[2d] write GPIO2->PDDR ...                           PDDR = 0x00000010
```

三个请求全 `SUCCESS`，所以：

- **假设 A 不成立**（SM 并没有拒绝 GPIO 功能）——`PIN_GPIO_IO15` 的 `ACCESS` 权限**够用**，
  不需要改 SM 配置、不需要重烧启动容器。
- **假设 B 也不能证实**（不是传输错）。
- 那么 v3 那次卡住的原因**没有查实**。可能是一次偶发的 SCMI 错误被那个死循环吞掉了。
  **结论不变：会死循环的函数不能用**；但"为什么会出错"仍是**未解**（见第六节）。

> **这个 SDK 死循环是真 bug，值得反馈给 NXP**：出错路径应该是有限次重试 + 返回状态码，
> 而不是 `while (status != SUCCESS);` 空转。它把"权限不足"这种可能遇到的正常错误
> 表现成了"程序卡死且无任何提示"。
> 本方案**没有改 SDK 文件**（`sm_pinctrl.c` 保持原样），只在应用侧绕开它。

## 五、傻瓜式上板步骤（待执行）

### 5.0 准备

板子按 [EVK-19x19到手操作计划](EVK-19x19到手操作计划.md) 上电：J5 接原装 12V 电源、SW4 打到 ON、
SW7[1:4] = `x011` 从 SD 卡启动。等 Linux 起来，找到 **LPUART3 那个 COM 口**
（判定方法：跑一遍官方的 `freertos/hello_world`，看到 `Hello world.` 的就是它）。
终端设 **115200 / 8 / None / 1**。

从 Windows 侧确认板子能 ping 通，记下 IP。

### 5.1 传文件

```powershell
cd F:\project\Learning\RTOS\build\a55-bin
scp hello_world.bin imx95-harpoon-freertos-gpio.cell root@<板子IP>:/tmp/
```

#### 5.1.1 断电重启之后必须重做两件事（踩过）

**2026-09-22 记录**：断电重启后再走 5.2，报了两个错：

```text
jailhouse cell destroy  freertos-gpio -> JAILHOUSE_CELL_DESTROY: No such file or directory
jailhouse cell create /tmp/...cell     -> JAILHOUSE_CELL_CREATE: Device or resource busy
jailhouse cell load freertos-gpio ...  -> JAILHOUSE_CELL_LOAD: No such file or directory
```

两件事各自独立，都不是代码问题：

| 错 | 原因 | 怎么办 |
|---|---|---|
| `LOAD: No such file or directory` | **`/tmp` 是 tmpfs，断电就没了。** 上次 scp 过去的 `.bin` 和 `.cell` 都不在了 | 重新 scp（就是 5.1 那两条） |
| `CREATE: Device or resource busy` | **CPU5 还被原来的 `freertos` cell 占着。** 重启后 harpoon 的流程会自己把 `freertos` 建起来（或上次留下的还在），我们的新 cell 也要 CPU5，`cell create` 就会 EBUSY | 先把 `freertos` 停掉再建；`jailhouse cell list` 能直接看到它 |

**所以重启后的正确顺序是**：先 `jailhouse cell list` 看清现状 → 停掉 `freertos` → 再建 `freertos-gpio`。

**另外**：这几条命令要**一条一条贴、一条一条等提示符**。
整段粘贴到串口终端上很容易串行（这次的日志里 `jailhouse cell load ...` 和结果就交错了，
中间还夹着上一次没执行完的半条命令）。

#### 5.1.2 `FATAL: instruction abort at 0x200` 的排查（踩过）

**2026-09-22 记录**：断电重启后重跑，`jailhouse cell start freertos-gpio` 报：

```text
FATAL: instruction abort at 0x200
FATAL: forbidden access (exception class 0x20)
Cell state before exception:
 pc: 0000000000000200   lr: 0000000000000000 spsr: 000003c5     EL1
 sp: 0000000000000000  elr: 0000000000000200  esr: 20 1 0000006
 x0..x29 全是 0
Parking CPU 5 (Cell: "freertos-gpio")
```

**这不是 U-Boot / 设备树的问题，是 cell 的入口地址不对。**

##### 怎么从这几个数字读出来

`esr = 0x20_1_0000006`：EC=0x20 = "Instruction Abort from a lower EL"，ISS=0x06 = 二级页表 translation fault。
`pc = elr = 0x200`：出错的那条指令在 `0x200`。

对照 jailhouse 源码 `hypervisor/arch/arm64/control.c` 的 `arm_cpu_reset()`：

```c
arm_write_sysreg(SP_EL0, 0);
arm_write_sysreg(SP_EL1, 0);
arm_write_sysreg(SPSR_EL1, 0);
...
arm_write_sysreg(VBAR_EL1, 0);
...
arm_write_sysreg(SPSR_EL2, RESET_PSR_AARCH64);   /* = 0x3c5 */
arm_write_sysreg(ELR_EL2, pc);
memset(&this_cpu_data()->guest_regs, 0, sizeof(union registers));
```

- `spsr = 0x3c5` 正是 `RESET_PSR_AARCH64`（EL1h + DAIF 全屏蔽）
- `sp = 0`、`x0..x29 = 0` 正是 `arm_cpu_reset` 的清零结果
- `VBAR_EL1` 被写成 **0**

**所以 CPU 是"刚复位"状态，而它的复位入口是 `0`，不是 `0xf0000000`。**

`0x200` 是 ARM64 异常向量表里的固定偏移 —— **"同步异常 / 当前 EL / 用 SP_ELx"** 那一项。
完整链条：

```text
1. cell 入口 = 0（不是 0xf0000000）
2. CPU 从 0x0 取指
   但 cell 只把物理 0x0 映射到【虚拟】0x80000000（cell 内存段 [15]）
   所以虚拟 0x0 没映射 -> 取指异常
3. 这个异常发生在 EL1 内部，走 VBAR_EL1(=0) 的向量表
   -> 跳到 0 + 0x200 = 0x200
4. 0x200 同样没映射 -> 第二次异常，这次被 hypervisor 抓到
   -> 打印 "instruction abort at 0x200"
```

**第一次异常在 cell 内部就被消化了**，所以只看到 0x200 这一条，看不到 0x0 那一条。

##### 入口为什么是 0

入口不是从 `.cell` 的 `cpu_reset_address` 来的，而是 **`jailhouse cell load ... -a <地址>` 记下来的**。
**`cell load` 没成功，入口就保持 0。**

这次的原因在前面那一段输出里已经写着了：

```text
jailhouse cell load freertos-gpio /tmp/hello_world.bin -a 0xf0000000
JAILHOUSE_CELL_LOAD: No such file or directory
```

**`/tmp/hello_world.bin` 不在** —— `/tmp` 是 tmpfs，断电重启就清空。后面再 `cell start`，
jailhouse 照样会启动 CPU，只是从 0 开始。

##### 怎么避免

**每次上板先确认文件在，而且 load 有回显。** 用 `&&` 串起来，任何一步失败就停：

```bash
ls -l /tmp/hello_world.bin /tmp/imx95-harpoon-freertos-gpio.cell ; \
jailhouse cell destroy freertos ; \
jailhouse cell destroy freertos-gpio ; \
jailhouse cell create /tmp/imx95-harpoon-freertos-gpio.cell && \
jailhouse cell load freertos-gpio /tmp/hello_world.bin -a 0xf0000000 && \
jailhouse cell start freertos-gpio
```

**必须看到 `Cell "freertos-gpio" can be loaded` 这一行**（这是 `cell load` 成功的回显），
再往下走 `cell start`。看不到就别 start。

文件正确性用哈希核对（`实机验证`前的静态核对）：

| 文件 | 大小 | SHA256 |
|---|---|---|
| `hello_world.bin`（v4） | 74,192 | `cfa89895b73f35dfa45f50eeeb9d16eb869e181a98e990caf6199a187cfbe25c` |
| `imx95-harpoon-freertos-gpio.cell` | 804 | `b9467715a34fced2a10eaf3471af84687aca1077f5fe768f67b334cf76367d8d` |

### 5.2 换 cell 并跑起来（在板子的串口终端里）

```bash
# 1) 先看现状：cell 0 是 root cell，别的都是已经建出来的
jailhouse cell list

# 2) 把占着 CPU5 的旧 cell 停掉（重启后 harpoon 会自己建一个叫 freertos 的）
jailhouse cell shutdown freertos || true
jailhouse cell destroy  freertos
#    如果它自己又回来了，先停服务：
#    systemctl stop harpoon

# 3) 确认 CPU5 空出来了
jailhouse cell list

# 4) 用带 GPIO 的新 cell 建一个（名字 freertos-gpio 是从文件里读的）
jailhouse cell create /tmp/imx95-harpoon-freertos-gpio.cell

# 5) 装载 + 启动
jailhouse cell load freertos-gpio /tmp/hello_world.bin -a 0xf0000000
jailhouse cell start freertos-gpio
```

**一条一条执行，每条等到提示符出来再贴下一条。**

命令行的前提条件（之前实测过）：**cell 必须先 shutdown/destroy 再 load**，否则报 busy；
`-a 0xf0000000` 必须和 ELF 入口、cell 的 `mem_regions` 三者一致。

如果 `jailhouse cell shutdown freertos` 报错（FreeRTOS inmate 里没有 jailhouse 驱动，收不到关机请求），
直接 `jailhouse cell destroy freertos`；再不行就先 `systemctl stop harpoon` 再手工建。

**改了 bin、cell 没改时，只要这三条**（2026-09-22 第二次部署用的就是这条）：

```bash
scp F:\project\Learning\RTOS\build\a55-bin\hello_world.bin root@<板子IP>:/tmp/   # Windows 侧
# 板上：
jailhouse cell shutdown freertos-gpio || true
jailhouse cell destroy  freertos-gpio
jailhouse cell create /tmp/imx95-harpoon-freertos-gpio.cell
jailhouse cell load freertos-gpio /tmp/hello_world.bin -a 0xf0000000
jailhouse cell start freertos-gpio
```

### 5.3 看输出

切到 LPUART3 那个终端。程序按"先报再做"的顺序打 `STEP0`–`STEP4`：

```text
STEP0: banner ok -> LPUART3 TX works
STEP1: reading cntfrq_el0 ...
STEP1: cntfrq = 0x016E3600
STEP1: bit_ticks per bit = 208
STEP2: enabling LPUART3 RX ...
STEP2: done
STEP3: reading RGPIO2 @0x43810000 (cell + MMU check) ...
STEP3: VERID = 0x........
STEP3: GPIO2 reachable -> cell entry AND MMU entry both OK
STEP4: RGPIO2 register dump
   VERID=0x........
   ...
commands: 1=UART RX  2=GPIO IN  3=GPIO OUT  4=all  5=dump regs
>
```

**看最后停在哪个 STEP，就知道问题在哪一层**：

| 最后看到的行 | 说明 | 下一步 |
|---|---|---|
| `STEP1` 之后没了 | `mrs cntfrq_el0` 被 trap | 少见；把 `cntfrq` 换成用 TPM2 计时 |
| `STEP3: reading ...` 之后没了 | **GPIO2 访问还是被拦** | 检查 bin 是不是新的（`STEP0` 里有 `v2` 字样）、`app_mmu.h` 有没有装 |
| `STEP3: VERID = 0x00000000` 或全 `F` | 地址通了但读出来不对 | 记数值，查 RGPIO2 的时钟有没有开 |
| `STEP3: GPIO2 reachable ...` | **cell + 一级页表都通了** | 继续 5.4 |

#### 第二次上板实测结果（2026-09-22，`实机验证`）

```text
STEP1: cntfrq = 0x016E3600              <- 24 MHz，和 SDK 一致
STEP1: bit_ticks per bit = 208          <- 24e6 / 115200 = 208.3
STEP3: VERID = 0x02010001               <- ★ GPIO2 读到了
STEP3: GPIO2 reachable -> cell entry AND MMU entry both OK
STEP4: RGPIO2 register dump
   VERID=0x02010001
   PARAM=0x00000002
   PDDR =0x00000010
   PDOR =0x00000010
   PDIR =0x31040400
   PIDR =0x00000000
   PCNS =0xFFFFFFFF
   PCNP =0xFFFFFFFF
```

**结论：cell（stage-2）和一级页表（stage-1）两层都通了，GPIO2 寄存器可以自由读写。**

逐项读这几个寄存器：

| 寄存器 | 值 | 怎么读 |
|---|---|---|
| `VERID` | `0x02010001` | FEATURE=0x0001、MINOR=0x01、MAJOR=0x02。**不是 0 也不是全 F，说明是真寄存器**，cell + MMU 都对 |
| `PARAM` | `0x00000002` | 参数寄存器，字段含义**待查** |
| `PDDR` | `0x00000010` | bit4 已经是**输出**方向——不是我们设的，是别的启动组件留下的 |
| `PDOR` | `0x00000010` | bit4 输出为 1，和 `PDDR` 一致 |
| `PDIR` | `0x31040400` | 读到高的脚：bit29/28/24/18/10。**bit14/15 = 0** |
| `PIDR` | `0x00000000` | 没有任何一根脚被禁止输入 |
| `PCNS` | `0xFFFFFFFF` | **所有脚被标成非安全**——和 Pro 板 M7 那次一模一样 |
| `PCNP` | `0xFFFFFFFF` | **所有脚被标成非特权** |

两点注意：

- **`PDIR` 的 bit14/15 是 0**，因为这时候 IO14/IO15 还复用成 LPUART3，pad 的输入没有接到 GPIO。
  等测试 `3` 把 IO15 切成 `GPIO2_IO15` 之后，这一位才会跟着线电平走（空闲应为 1）。
- **`PCNS`/`PCNP` 都是 `0xFFFFFFFF`**，说明 BL31 确实把 GPIO2 全部设成了非安全/非特权。
  Pro 板上 M7 是**安全特权态**，被这两条拦住（读 0、写无效）。
  A55 上的 Linux/inmate 是**非安全态**，按 "非安全能访问的，安全也能访问" 的模型预计不拦
  ——但这仍是**推测**，要看测试 `3` 能不能真的翻动引脚。

#### UART 收也通了

在提示符后面随手按键，程序逐个回显：

```text
got 0x00000061     <- 'a'
got 0x00000044     <- 'D'
got 0x00000077     <- 'w'
got 0x00000064     <- 'd'
got 0x00000039     <- '9'
...
    unknown command
```

**收到 16 个字节、内容与按键一致，UART 收方向验证通过。**
菜单没分发是因为按的键不在 `1`–`5` 里（见 4.5）。

| 要求 | 状态 |
|---|---|
| UART 发 | ✅ 已验证（横幅、STEP 全部正常打出） |
| UART 收 | ✅ 已验证（按键被逐个收到并回显） |
| GPIO 寄存器访问 | ✅ 已验证（`VERID=0x02010001`） |
| GPIO 输入 | ✅ 已验证（见 5.4.1） |
| GPIO 输出 | ✅ 已验证（见 5.4.1） |

#### 5.4.1 v4 实测全过程（2026-09-22，`实机验证` —— 四项全过）

```text
STEP3: VERID = 0x02010001
STEP3: GPIO2 reachable -> cell entry AND MMU entry both OK
STEP4: VERID=0x02010001 PARAM=0x00000002
       PDDR =0x00000010 PDOR =0x00000010 PDIR =0x31040400
       PIDR =0x00000000 PCNS =0xFFFFFFFF PCNP =0xFFFFFFFF

commands: 1/r=UART RX  2/i=GPIO IN  3/o=GPIO OUT  4/a=all  5/d=dump
          no command within 5s -> run all three tests automatically
>
no command in 5s -> running all three tests

-- [1] UART RX: type any key in this terminal within 10s --
    nothing in 10s -> UART RX FAIL          <- 自动跑时没来得及按键，后面手动补验

-- [2] GPIO IN: mux GPIO_IO15 -> GPIO2_IO15 --
    [2a] scmi mux IO15 -> LPUART3_RX (same as boot) ...
    [2a]00000000
             = SUCCESS
    [2b] scmi mux IO15 -> GPIO2_IO15 ...
    [2b]00000000
             = SUCCESS                       <- ★ SM 接受了 GPIO 功能
    [2c] scmi cfg IO15 pull-down ...
    [2c]00000000
             = SUCCESS
    [2d] write GPIO2->PDDR (clear bit15) ...
    [2d] ok, PDDR = 0x00000010               <- ★ 写 RGPIO2 成功，bit15 清零，bit4 不受影响
    level right after mux = 0x00000001       <- ★ bit15 = 1，说明 mux 真的生效了
    HOLD DOWN any key on the keyboard. Sampling starts in 5s ...
    sampling 8s ...
    samples==1 : 16218560
    samples==0 : 2768                        <- ★ 按住键时出现低电平
    edges      : 84                          <- ★ 有 84 次跳变
    -> GPIO IN OK
    [2e] scmi mux IO15 -> LPUART3_RX ...
    [2e]00000000
             = SUCCESS
    [2e] done

-- [3] GPIO OUT: mux GPIO_IO14 -> GPIO2_IO14, bit-bang --
    [3a] scmi mux IO14 -> GPIO2_IO14 ...
                                             <- [3a] 的状态行、[3b]/[3c]/[3d] 全部看不到
[[GPIO-TX]] bit-banged on GPIO2_IO14 @115200 [END]
                                             <- ★ 位翻转出来的字被 PC 正确收到
    [3e]00000000
             = SUCCESS
    [3e] 控制台已恢复
    bit_ticks per bit : 208

===== all tests done (auto) =====
>
got 0x00000032                               <- 手动敲 '2'
...
got 0x00000077
    -> UART RX OK                            <- ★ 手动补验 UART 收
```

##### 每一项为什么算通过

| 项 | 关键证据 | 说明 |
|---|---|---|
| **UART 发** | `STEP0`–`STEP4` 全部正常打出 | LPUART3 TX 通 |
| **UART 收** | 手动敲键 → `got 0x00000077` / `-> UART RX OK` | LPUART3 RX 通 |
| **GPIO 输入** | 不按键：`samples==0 : 0`；按住键：`samples==0 : 2768`、`edges : 84` | 引脚电平真的跟着 PC 发数据在动 |
| **GPIO 输出** | `[[GPIO-TX]] bit-banged on GPIO2_IO14 @115200 [END]` | 软件位翻转的 8N1 帧被 FT4232H 正确解码 |

##### 几个"没出现的东西"同样是证据

`test_gpio_output()` 的设计是：切成 GPIO 之后**再往 LPUART3 写一遍** `[[LPUART3-TX]]`。
两段字哪段出现，就能区分"mux 生效了"还是"mux 没生效"：

| 观察 | 判定 |
|---|---|
| `[[GPIO-TX]]` 出现、`[[LPUART3-TX]]` **不**出现 | ✅ mux 生效 + GPIO 输出正确（**这次就是这个**） |
| 两段都出现 | mux 没生效，引脚一直是 LPUART3_TX |
| 两段都不出现 | 位翻转代码或时序有问题 |

同理，`[3a]` 的状态行和 `[3b]`/`[3c]`/`[3d]` 这几行**看不到**也是证据 ——
它们是在 IO14 已经切成 GPIO 之后才打印的，**打不到终端正好说明控制台 TX 真的被切走了**。

##### 另外两个意外收获

- **`PCNS`/`PCNP = 0xFFFFFFFF` 没有拦住 A55。** 说明 i.MX95 的 PCNS/PCNP 对
  **非安全态**主设备不起阻挡作用（非安全资源，非安全态本来就能访问）。
  和 Pro 板 M7 那次（安全特权态，被拦成"读 0、写无效"）是**两回事**，不能类比。
- **位翻转的时序是对的。** `bit_ticks per bit : 208` = 24 000 000 / 115 200 = 208.3。
  PC 能正确解出全部字符，说明"用 `CNTVCT_EL0` + `CNTFRQ_EL0` 做时间基准"这条路可行，
  而且每个字节期间关中断（`taskENTER_CRITICAL`）确实挡住了 1 ms 的 tick 干扰。

> 第一版（没有 `STEPn`、没有 `app_mmu.h`）就停在 `STEP0` 之前：只看到 `INFO: verify build running`，
> 之后什么都没有，敲键也没反应。原因见 3.4.1。

### 5.4 依次验证

在同一个终端里敲 `1`、回车，看 UART 收：

- 出现 `收到 0x31 ('1') -> UART 收 OK` —— **这一步本身就已经证明 UART 收通了**（菜单命令就是靠 UART 收进来的）。
- 10 秒没收到 —— 检查终端是不是 LPUART3 那个口、是不是 115200。

敲 `2`、回车，做 GPIO 输入：

- 看到提示后**一直按住键盘上任意一个键不放**，按满 8 秒再松手。
- 结果判定：

| 采样结果 | 含义 |
|---|---|
| `0 的样本 > 0` 且 `跳变 > 0` | **GPIO 输入 OK**（引脚电平跟着 PC 发的数据动） |
| `0 的样本 = 0`、`跳变 = 0` | 见下面的排查 |
| 采样期间敲的键还能在控制台看到别的反应 | 说明 IO15 **没有**切成 GPIO，仍是 LPUART3_RX（mux 请求没生效） |

敲 `3`、回车，做 GPIO 输出：

| 终端上出现的内容 | 含义 |
|---|---|
| 先 `[[GPIO-TX]] bit-banged on GPIO2_IO14 @115200`，再 `[[LPUART3-TX]] ...` | **GPIO 输出 OK**，复用也生效了 |
| 只出现 `[[LPUART3-TX]] ...` | 复用请求被 SM 拒绝，引脚一直是 LPUART3_TX |
| 两个都没出现 | 位翻转时序或代码问题（记录 `cntfrq` 的值） |
| `[[GPIO-TX]]` 那行是乱码 | 位翻转速率不准；`cntfrq` 打印值一并记录 |

最后敲 `4` 可以把三个测试一次跑完。

### 5.5 收尾

验证完把板子恢复成官方状态（后面还要跑 rt_latency 之类）：

```bash
jailhouse cell shutdown freertos-gpio || true
jailhouse cell destroy  freertos-gpio || true
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
jailhouse cell load freertos /usr/share/harpoon/inmates/freertos/hello_world.bin -a 0xf0000000
jailhouse cell start freertos
```

或者直接重启板子，走原来的 `harpoon_set_configuration.sh` + `systemctl start harpoon`。

### 5.6 复原编译环境（可选）

验证版改动一共两处，原始文件都备份好了：

```bash
cd ~/hww/harpoon-apps/hello_world/freertos
cp main.c.orig-hello main.c            # 还原 main.c
rm -f boards/imx95lpd5evk19/app_mmu.h  # 去掉一级页表补丁
bash /mnt/f/project/Learning/RTOS/build/tools/build_a55.sh hello_world release
```

## 六、问题与答案（2026-09-22 全部有结论）

| # | 问题 | 答案 |
|---|---|---|
| 1 | `STEP3` 能不能读出 RGPIO2 的 VERID | **能。** `VERID = 0x02010001`，cell（stage-2）+ 一级页表（stage-1）都生效 |
| 2 | `dup=2` 是否让 `AP-NS-agent1/2` 完整继承 `AP-NS-agent0` 的权限 | **不需要回答了。** inmate 走 MU3（= agent0），SCMI 请求全部返回 `SUCCESS`，说明权限已经够用 |
| 3 | `PIN_xxx ACCESS` 够不够申请改成 GPIO 功能 | **够。** `[2b] scmi mux IO15 -> GPIO2_IO15` 返回 `SUCCESS`。**这是本次最重要的结论之一** |
| 4 | 自己往 `.cell` 加 MMIO 段会不会被 jailhouse 拒绝 | **不会。** `cell create` 成功（`Created cell "freertos-gpio"`）。root cell 配置里并没有逐条列 MMIO |
| 5 | A55 非安全态下 `PCNS`/`PCNP = 0xFFFFFFFF` 还拦不拦 | **不拦。** 读到全 `F`（所有脚非安全、非特权），但 GPIO 输出照样驱动了引脚。**非安全态能访问非安全资源**——和 Pro 板 M7（安全特权态）被拦是两回事 |
| 6 | `0x445d1000` 是 SMT 共享内存还是 MU 扩展窗口 | **仍未定。** 从现象反推不出来，需要 SM 源码或 RM |
| 7 | inmate 的一级页表还漏了哪些外设 | **开放。** 现在只补了 GPIO2。要用别的外设（TPM 做计数器等）同样要检查 `mmu.c` 白名单 |

### 第六条之外的残余问题

- **v3 为什么卡死还没最终确定。** v4 绕开 `sm_pinctrl.c` 的死循环之后，同样的三个请求
  （`[2a]`/`[2b]`/`[2c]`）全部返回 `SUCCESS`。所以 v3 那次要么是偶发（SCMI 传输错，被死循环吞掉），
  要么是那个函数在某个条件下走到了不同分支。**结论不变：出错时会死循环的函数不能用**，
  但"为什么会出错"这个根因没有查实。
- **GPIO 输入测试的判据可以再收紧。** 这次是"按住键 → 2768 个低电平样本、84 次跳变"，
  足够证明通路，但如果要把 duty 也验准，应该用 PC 端发送固定码型（例如连续 0x00）+ 逻辑分析仪同时看。

## 相关

- [Harpoon复现](Harpoon复现.md)
- [开发流程：改代码 → 编译 → 上板生效](开发流程-改代码到上板.md)（路线 C 改 cell、路线 E 改 SM）
- [资料清单表](资料清单表.md)
- [SD启动GPIO权限问题结论](../FRDM-IMX95-PRO/SD启动GPIO权限问题结论.md)（PCNS/PCNP 那次踩坑）
- [i.MX95引脚控制：IOMUXC与RGPIO分工](../../20-领域/芯片与平台-i.MX95/i.MX95引脚控制-IOMUXC与RGPIO分工.md)
- [Jailhouse分区式虚拟化原理](../../20-领域/芯片与平台-i.MX95/Jailhouse分区式虚拟化原理.md)
