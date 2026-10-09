---
type: 项目档案
scope: IMX95-EVK
doc_type: 参考
status: 进行中
evidence: 源码可确认
tags: [Harpoon, Jailhouse, 多核与异构, 调研]
updated: 2026-10-09
---

# 给 NXP 的同步信息与问题清单（2026-10-09）

> 背景：先问了"harpoon-apps 的 FreeRTOS 支不支持多核"，对方回"我先看下"。
> 这一步是把**我们这边的事实全部摊开**，让对方不用来回问就能回答。
> 下面「一」是**可直接复制发送的正文**，「二」是每条事实的出处（自己复查用），
> 「三」是这次顺带查出来、要一起同步给 NXP 的三条。

---

## 一、可直接发送的正文

---

王工，补充一下我这边的环境和我做过的事，方便你判断。

### 1. 板子和系统

- 板子：**IMX95LPD5EVK-19**（i.MX95 19x19 LPDDR5 EVK）
- 系统：**Real-Time Edge 3.3 的 SD 卡镜像**，包名 `Real-time_Edge_v3.3_IMX95-19X19-LPDDR5-EVK`
  - 镜像文件：`nxp-image-real-time-edge-imx95-19x19-lpddr5-evk.rootfs.wic.zst`（1.80 GB）
  - 内核：`6.12.34-rt11-lts-next`
  - jailhouse：`2023.03+git0+f64de0b8f6-r0`（运行日志显示 `v0.12 (388-gf64de0b8-dirty)`）
- 启动方式：**从 SD 卡启动**（SW7[1:4] = x011），U-Boot 里 `setenv jh_root_dtb imx95-19x19-evk-harpoon.dtb` + `run jh_mmcboot`

### 2. 板子上跟 Harpoon 有关的文件 —— 都是 SD 镜像自带的，我没动

```text
/usr/share/jailhouse/cells/imx95.cell                              ← root cell
/usr/share/jailhouse/cells/imx95-harpoon-freertos.cell             ← 我基于它改的
/usr/share/jailhouse/cells/imx95-harpoon-freertos-industrial.cell
/usr/share/jailhouse/inmates/uart-demo.bin
/usr/share/harpoon/inmates/freertos/hello_world.bin                （66,040 B）
/usr/share/harpoon/inmates/freertos/rt_latency.bin                 （94,848 B）
/usr/share/harpoon/inmates/freertos/industrial.bin                 （422,240 B）
/usr/share/harpoon/scripts/jh_harpoon.sh, harpoon_configure.sh
/usr/bin/harpoon_ctrl, /usr/bin/harpoon_set_configuration.sh
/usr/lib/systemd/system/harpoon.service
/etc/harpoon/harpoon.conf
```

（我把 SD 镜像的 rootfs 挂出来逐条核对过这些文件。）

### 3. 我自己编的那部分

- 源码：`github.com/NXP/harpoon-apps`，tag **`harpoon_3.3.0`**，commit **`fb1a66c`**
- 依赖按仓库自带的 `west.yml` 拉，**一个都没改**：

| 依赖 | 来源 | commit | 本地改动 |
|---|---|---|---|
| FreeRTOS-Kernel | `nxp-mcuxpresso/FreeRTOS-Kernel` | `c747fc1595cfc914021a6534adba86d6b152aac8`（**V11.0.1**） | 0 |
| mcux-sdk | `nxp-mcuxpresso/mcux-sdk` | `0db10da15d9cc6222744d4854b2cb532b646dcd4` | 0 |
| rtos-abstraction-layer | `github.com/NXP/rtos-abstraction-layer` | `ccf7c68248b5ebef682eb4ef96434412087ccf5e` | 0 |
| heterogeneous-multicore | `nxp-real-time-edge-sw/heterogeneous-multicore` | `8140eb0bb2f28219ed1c00cdcf5564abedf1f338` | 0 |
| middleware/multicore | `nxp-mcuxpresso/mcux-sdk-middleware-multicore` | `5b8772984399c3fa4c1bc3d530db09fef74349c7` | 0 |

- 工具链：Arm GNU Toolchain **aarch64-none-elf 13.2.rel1**
- 自己编的应用：`hello_world`、`rt_latency`（都是官方例程改的），入口地址 `0xf0000000`

### 4. 我改了什么 —— 一共三处，都在应用侧

1. `hello_world/freertos/main.c` —— 改成自己的测试任务
2. **新增** `hello_world/freertos/boards/imx95lpd5evk19/app_mmu.h`
   —— 用 `mmu.c` 里留的 `APP_MMU_ENTRIES` 口子，给 inmate 的一级页表加了一条 GPIO2
   （写法照抄你们 `industrial/freertos/boards/imx95lpd5evk19/app_mmu.h` 里给 CAN2 加的那条）
3. **自己生成了一份 cell**：在原 `imx95-harpoon-freertos.cell` 的 `memory_regions` 末尾追加一段 RGPIO2
   （16 段 → 17 段），cell 名字改成 `freertos-gpio`，**其余字节一个没动**

> 通讯的 `mcux-sdk`、`FreeRTOS-Kernel`、`rtos-abstraction-layer` 都是 0 改动。

### 5. 现在的状态

- FreeRTOS 在 **A55 CPU5 单核**上跑通；UART 收发、GPIO 输入输出都实测验证过
- 性能/实时性测试做完（rt_latency 6 个用例 + 14 项基线），和 UG10170 Table 22 对得上
- **现在要做的：从 1 个 A55 核扩到 2 个**

### 6. 想请教的问题

1. **harpoon-apps 的 FreeRTOS 支持在多个 A55 核上跑吗？** 如果支持，是 SMP（一个实例管两个核）还是 AMP（每个核一个实例）？怎么开？
2. **FreeRTOS 侧有没有可用的 AArch64 SMP port？**
   我查了一下：`FreeRTOS-Kernel` 的 `portable/` 下没有任何 port 实现 `portGET_CORE_ID` / `portYIELD_CORE`；
   `include/FreeRTOS.h:401-409` 里 `configNUMBER_OF_CORES > 1` 且没有 `portYIELD_CORE` 会直接 `#error`。
   **你们内部有没有 AArch64 的 SMP port 可以给我们？**
3. 如果只能自己做：cell 的 `cpu_set` 从 `0x20` 改成 `0x30`（bit4+5）之后，
   除了改 `startup.S` 读 `MPIDR_EL1` 分流，还需要动别的吗？SM 侧（`mx95rte` 那份配置）要不要改？
4. 我的理解是：**`cell_start()` 里 jailhouse 会对 `cpu_set` 里每个核都调 `arch_reset_cpu()`**，
   所以两个核是同时从 `cpu_reset_address = 0xf0000000` 起来的，**不需要 PSCI / SCMI 去拉从核** —— 这个理解对吗？
5. Zephyr 侧有 SMP（`audio/zephyr/boards/*/build_smp.sh`），FreeRTOS 侧没有 —— **这个不对称是有意的吗？**

### 7. 另外三条我自己查到的，一并同步（可能你们已经知道）

1. **版本对不上**：RTE 3.3 镜像的 manifest 里 `harpoon-apps-*` 是 **`3.5-r0`**，
   而我是按 UG10170 Rev 3.3 §6.2 从 GitHub 拉的 **`harpoon_3.3.0`**。
   我对比过：3.5 已经迁到 **mcux-sdk-ng（v25.06.00）**，
   而且 **FreeRTOS 从 v11.0.1 升到了 v11.1.x**
   （提交 `c3ca733 freertos: FreeRTOS_helper: update API arguments for upversion FreeRTOS v11.1.x`）。
   → **我们要不要统一到 3.5？** 我现在用 3.3 编的 bin 配 3.5 系统的 cell/脚本，实测能跑，但这算不算受支持的组合？
2. **3.5 也没有解决多核**：`git diff harpoon_3.3.0 harpoon_3.5.0` 显示
   `common/freertos/core/armv8a/startup.S` **一字未改**；3.5 的 `FreeRTOSConfig.h` 里**也没有** `configNUMBER_OF_CORES`。
   SMP 字样只出现在 `audio/zephyr/` 下。
3. **上游 FreeRTOS 也没有 AArch64 SMP port**：`FreeRTOS/FreeRTOS-Kernel` main 分支的 `portable/GCC/` 下，
   AArch64 只有 `ARM_AARCH64`、`ARM_AARCH64_SRE`、`ARM_CA53_64_BIT`、`ARM_CA53_64_BIT_SRE` 四个，**没有 SMP 版**。
   另外 `west.yml` 里 pin 的 `nxp-mcuxpresso/FreeRTOS-Kernel` 这个仓库，
   现在 GitHub API 返回 404（改名了还是转私有了？）

---

## 二、每条事实的出处（自己复查用）

| 事实 | 出处 |
|---|---|
| 板型 / SD 启动 / SW7=x011 | `UM12022` §2.22 |
| 镜像文件名、大小 | `Real-time_Edge_v3.3_...\real-time-edge\` 目录；`.wic.zst` = 1,801,343,763 B |
| 内核 `6.12.34-rt11-lts-next` | 板上 `uname -a`；manifest |
| jailhouse `f64de0b8` | manifest 三行：`jailhouse-imx`、`kernel-module-jailhouse-6.12.34-rt11-lts-next`、`pyjailhouse` |
| `harpoon-apps 3.5-r0` | 同一份 manifest 的 `harpoon-apps-freertos-hello-world` 等 7 行 |
| 官方文件清单 | 挂载 `.wic` 后 `build\rte-extract\` |
| harpoon-apps tag / commit | `git -C ~/hww/harpoon-apps log -1` → `fb1a66c (tag: harpoon_3.3.0)` |
| 本地改动只有两处 | `git status --porcelain` → `M main.c`、`?? app_mmu.h` |
| 依赖 commit | `~/hww/harpoon-apps/west.yml` |
| 依赖 0 改动 | 各仓库 `git status --porcelain` 计数为 0 |
| FreeRTOS V11.0.1 | `FreeRTOS-Kernel/include/task.h:56` |
| 没有 port 实现 SMP | `grep -rl portGET_CORE_ID portable/` → 空 |
| `FreeRTOS.h` 的 `#error` | `include/FreeRTOS.h:401-409` |
| 3.5 的 startup.S 没变 | `git diff harpoon_3.3.0 harpoon_3.5.0 -- common/freertos/core/armv8a/startup.S` → 空 |
| 3.5 升到 v11.1.x | `git log harpoon_3.3.0..harpoon_3.5.0` 里的 `c3ca733` |
| 上游没有 AArch64 SMP port | GitHub API：`FreeRTOS/FreeRTOS-Kernel/contents/portable/GCC`（main） |
| `nxp-mcuxpresso/FreeRTOS-Kernel` 404 | GitHub API 两次 404 |

---

## 三、发送前自己要记住的两点

1. **不要把"我们猜的"和"我们查到的"混在一起说。** 正文里第 6 条是**问**，第 7 条是**我们查到的**，
   已经分开写了，别合并。
2. **第 6.2 条是最值钱的**（有没有现成 SMP port）。如果对方回"没有"，那 SMP 就是数周级的工作量，
   要立刻回来和老大谈范围；如果回"有"，那就直接省掉整个移植。

---

## 相关

- [双核改造与测试规划](双核改造与测试规划.md) —— 改动清单、两条路线、阶段 0 实验
- [待向NXP确认的问题清单](待向NXP确认的问题清单.md) —— 之前那份
- [资料清单表](资料清单表.md)
- [编译部署流程](编译部署流程.md) —— cell/inmate 是什么、怎么换
