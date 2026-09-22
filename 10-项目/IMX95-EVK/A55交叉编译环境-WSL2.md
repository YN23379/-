---
type: 项目档案
scope: i.MX95 19x19 LPDDR5 EVK（IMX95LPD5EVK-19）/ 开发环境
doc_type: 教程
status: 进行中
evidence: 实机验证
tags: [编译构建, 工具与环境, 多核与异构]
updated: 2026-09-22
---

# A55 交叉编译环境（WSL2）

给 A55 编 FreeRTOS 用的环境。**编译在电脑上做，板子不装编译器。**

## 为什么单独建一个 WSL2 发行版

| | 已有的 `UbuntuBuild` | 新建的 `IMX95A55` |
|---|---|---|
| 定位 | M7 那套在用 | **A55 专用** |
| WSL 版本 | **WSL1** | **WSL2** |
| 位置 | `F:\project\Learning\RTOS\tools\wsl\UbuntuBuild` | `F:\wsl\IMX95A55` |

**不把 WSL1 转成 WSL2 的原因**：转换不可逆，而 `UbuntuBuild` 是 M7 那套在用的，
转出问题不好回退。新建一个互不干扰。

**WSL1 为什么不适合干这个活**：

- syscall 兼容层慢，`west update` 要拉几个 G、编译又是几千个文件
- 跨 `/mnt/f` 访问 Windows 磁盘极慢，而工作区在 F 盘
- 少数构建脚本的检测在 WSL1 上会失败

**WSL2 是完整 Linux 内核**（实测 `6.18.33.2-microsoft-standard-WSL2`），没这些问题。

## 环境构成

| 项 | 值 |
|---|---|
| 发行版名 | `IMX95A55` |
| 系统 | Ubuntu 24.04.5 LTS |
| WSL 版本 | 2（`wsl -l -v` 确认） |
| 磁盘位置 | **`F:\wsl\IMX95A55`**（不占 C 盘） |
| 默认用户 | `chen`（有 sudo，免密） |
| 内存/CPU 上限 | 8GB / 4 核（写在 `.wslconfig`） |

**安装时直接指定位置**，避免装到 C 盘再迁移：

```powershell
wsl --install -d Ubuntu-24.04 --location 'F:\wsl\IMX95A55' --name IMX95A55
```

> **两个坑**：
> 1. `wsl --install` 会先装 `VirtualMachinePlatform` 组件，**必须重启才生效**，否则命令跑完也没用。
> 2. 下载镜像慢，命令可能看起来"卡住"，用 `wsl -l -v` 确认是否已建出来。

## 已装的工具

| 工具 | 版本 | 用途 |
|---|---|---|
| `git` | 2.43.0 | 取源码 |
| `python3` | 3.12.3 | west 依赖 |
| `cmake` | 3.28.3 | 构建 |
| `ninja-build` | — | 构建后端 |
| `build-essential` | — | gcc/make 等 |
| **`west`** | 1.5.0 | **项目管理，拉 harpoon-apps 及其依赖** |
| **AArch64 GCC** | **13.2.rel1** | **编 A55 代码** |

**工具链路径**（写在 `/etc/profile.d/imx95a55.sh`）：

```
/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf
```

环境变量：

```bash
export ARMGCC_DIR=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf
export PATH=$ARMGCC_DIR/bin:$PATH
```

**验证**：

```bash
aarch64-none-elf-gcc --version
# aarch64-none-elf-gcc (Arm GNU Toolchain 13.2.rel1 (Build arm-13.7)) 13.2.1 20231009
```

## 装的时候踩到的三个坑

**① pip 直连 PyPI 超时** → 换清华源

```bash
pip3 install --break-system-packages -i https://pypi.tuna.tsinghua.edu.cn/simple west
```

`--break-system-packages` 是 Ubuntu 24.04 需要的（它默认禁止 pip 装到系统 Python）。

**② 工具链下载很慢**（124MB，约 1.3MB/分钟，总共花了约 80 分钟）

没有找到可用的国内镜像。**建议挂着下，别中断**。

**③ `wsl -e bash script.sh` 不读环境变量**

`wsl -e bash xxx.sh` 是非登录非交互 shell，**不读 `/etc/profile.d/*`**，所以 `ARMGCC_DIR` 是空的。
用 `wsl -e bash -lc '...'`（登录 shell）就正常。**这是 WSL 的调用方式问题，不是环境没配好。**

## 依赖怎么拉：用镜像，不要用 git

**这是本次最大的教训。** GitHub 直连实测 **4 KB/s**，用镜像 **1.39 MB/s**，**差 350 倍**。

| 方式 | 实测速率 | 拉完 mcux-sdk（142MB）要多久 |
|---|---|---|
| `west update`（git fetch，走 SSH） | **~4 KB/s** | **几小时（实际没拉完）** |
| **`gh-proxy.com` 下载 tar 包** | **~1.39 MB/s** | **约 2 分钟** |

**测速方法**（以后换网络先测这个，别硬等）：

```bash
# 镜像
timeout 25 curl -s -o /dev/null -w '%{speed_download} B/s\n' --max-time 20 \
  "https://gh-proxy.com/https://github.com/nxp-mcuxpresso/mcux-sdk/archive/refs/heads/main.tar.gz"
```

### 要拉哪些（FreeRTOS 用）

| 项目 | 仓库 | 提交 | 解到哪 |
|---|---|---|---|
| harpoon-apps | `NXP/harpoon-apps` | tag `harpoon_3.3.0` | `~/hww/harpoon-apps` |
| mcux-sdk | `nxp-mcuxpresso/mcux-sdk` | `0db10da1…` | `~/hww/mcux-sdk` |
| FreeRTOS-Kernel | `nxp-mcuxpresso/FreeRTOS-Kernel` | `c747fc15…` | `~/hww/FreeRTOS-Kernel` |
| CMSIS_5 | `nxp-mcuxpresso/CMSIS_5` | `b5916939…` | `~/hww/mcux-sdk/CMSIS` |
| heterogeneous-multicore | `nxp-real-time-edge-sw/heterogeneous-multicore` | `8140eb0b…` | `~/hww/heterogeneous-multicore` |
| mcux-sdk-middleware-multicore | `nxp-mcuxpresso/mcux-sdk-middleware-multicore` | `5b877298…` | `~/hww/middleware/multicore` |
| rpmsg-lite | `nxp-mcuxpresso/rpmsg-lite` | `436596cd…` | `~/hww/middleware/multicore/rpmsg_lite` |
| **rtos-abstraction-layer** | **`NXP/rtos-abstraction-layer`** | `ccf7c682…` | `~/hww/rtos-abstraction-layer` |

**提交号从 `harpoon-apps/west.yml` 里查**。

**不装的**：`zephyr`（另一个 RTOS，约 1GB）、`GenAVB_TSN`、`hal_nxp`。

> ⚠️ **`rtos-abstraction-layer` 一定要装**，虽然名字像只给音频/工业用的，
> 但 **`hello_world` 的 CMakeLists 第 104 行也 `include(rtos_abstraction_layer)`**。
> 漏了它报 `include could not find requested file: rtos_abstraction_layer`。
>
> 而且它的仓库在 **`NXP/`** 下（west.yml 里没写 remote，用的默认 `nxp`），
> **不在** `nxp-real-time-edge-sw/` 下——这个坑我踩了一次。

### 批量下载脚本

`build\tools\dl.sh`（走镜像拉全部依赖）。核心就一行：

```bash
curl -fsSL -o /tmp/dl/$name.tar.gz \
  "https://gh-proxy.com/https://github.com/$owner/$repo/archive/$commit.tar.gz"
tar -xzf /tmp/dl/$name.tar.gz -C /tmp/dl/
cp -a /tmp/dl/${repo}-${commit}/. $target/
```

## 网络：WSL 里的 GitHub 被 Windows hosts 污染

**现象**：WSL 里 `github.com` 解析成 `127.0.0.1`，`git clone` 报
`Failed to connect to github.com port 443 after 8 ms`（**"8 毫秒"说明是本机拒绝，不是网络慢**）。

**原因**：Windows 的 hosts 文件里有大量 `127.0.0.1 github.com` 之类的条目（屏蔽用），
而 **WSL 默认会把自己的 `/etc/hosts` 和 DNS 都基于 Windows 生成**，
于是这个污染被带进了 WSL。

**解决**（三步，都要做）：

```bash
# 1. 关掉 WSL 自动生成 hosts 和 resolv.conf
sudo tee -a /etc/wsl.conf <<'EOF'
[network]
generateHosts = false
generateResolvConf = false
EOF

# 2. 清掉 /etc/hosts 里被污染的条目
sudo sed -i '/github/d' /etc/hosts

# 3. 指定能解析真实 IP 的 DNS
printf 'nameserver 223.5.5.5\nnameserver 119.29.29.29\n' | sudo tee /etc/resolv.conf

# 4. 重启 WSL 生效
```

```powershell
wsl --terminate IMX95A55
```

> **注意**：关掉 `generateResolvConf` 后，**WSL 每次重启会把 `/etc/resolv.conf` 删掉**，
> 要重新写一遍。如果嫌麻烦，可以在 `/etc/wsl.conf` 里加 `[boot] command=` 自动写。

**验证**：

```bash
getent hosts github.com        # 应返回真实 IP，如 20.205.243.166（不是 127.0.0.1）
git ls-remote https://github.com/NXP/harpoon-apps HEAD   # 能返回 hash 就通了
```

**顺带一个观察**：修好后 `curl https://github.com` 仍然超时，但 **`git` 能正常访问**。
所以**判断网络通不通要用 git 测，别用 curl**，否则会误判。

## 源码放哪

**放在 WSL 自己的文件系统里，不要放 `/mnt/f`**：

```bash
cd ~ && west init -m https://github.com/NXP/harpoon-apps --mr harpoon_3.3.0 hww
cd hww
# 依赖用镜像下（见上面「依赖怎么拉」），不要用 west update 硬拉
```

跨 `/mnt/f` 的性能损失在 WSL2 里有几十倍。编好的 `.bin` 再拷到 Windows 侧。

## 编译自己的代码

**改哪**：应用目录下的 `main.c`（板级初始化 + 建任务）。想加自己的功能，**复制一个现成应用改最省事**。

```bash
cd ~/hww/harpoon-apps/hello_world/freertos
cat main.c          # 入口在这里
```

`main.c` 的结构：

```c
int main(void) {
    BOARD_InitMemory();          // 内存布局
    BOARD_InitPlatform();        // 平台初始化
    BOARD_InitClocks();          // 时钟
    BOARD_InitDebugConsole();    // 调试串口
    xTaskCreate(hello_func, ...);   // 建任务
    xTaskCreate(tictac_func, ...);
    vTaskStartScheduler();          // 启动调度器
}
```

**板级代码**在 `~/hww/harpoon-apps/common/freertos/boards/imx95lpd5evk19/`：
`board.c`、`mmu.c`、`memory.h`、`sm_config.h`、`hal_config.h`，
链接脚本在 `armgcc_aarch64/MIMX9596xxxxx_ca55_ddr_ram.ld`。

## 编译（已实测通过）

用封装好的脚本：

```bash
bash /mnt/f/project/Learning/RTOS/build/tools/build_a55.sh                 # hello_world
bash /mnt/f/project/Learning/RTOS/build/tools/build_a55.sh rt_latency      # 指定应用
bash /mnt/f/project/Learning/RTOS/build/tools/build_a55.sh hello_world debug
```

它做的事：设 `ARMGCC_DIR` → 进应用目录 → `build_ddr_release.sh` → 把 bin 拷到
`F:\project\Learning\RTOS\build\a55-bin\` → 打印入口地址和传板命令。

**手动编也行**：

```bash
export ARMGCC_DIR=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf
export PATH=$ARMGCC_DIR/bin:$PATH
cd ~/hww/harpoon-apps/<应用>/freertos/boards/imx95lpd5evk19/armgcc_aarch64
./build_ddr_release.sh
# 产物：ddr_release/<应用>.bin
```

## 编译结果（2026-09-22 实测）

| 应用 | 产物 | 大小 | 入口地址 |
|---|---|---|---|
| `hello_world` | `hello_world.bin` | 61,912 B | **`0xf0000000`** ✅ |
| `rt_latency` | `rt_latency.bin` | 90,712 B | **`0xf0000000`** ✅ |

**入口地址对上**是关键的验证点——它必须和 cell 配置里的内存段、
`jailhouse cell load -a 0xf0000000` 三者一致，否则装载后跑飞。

**和官方 bin 对比**：官方 `hello_world.bin` 是 66,040 B，我们自己编的是 61,912 B。
大小不同但同量级，差异来自工具链版本（官方没公布用的哪个 GCC 小版本）。
**能用与否要靠上板实测**，不能只看大小。

## 从编译到上板

```powershell
# Windows 侧（板子的 RTE 系统已起来，SSH 可用）
scp F:\project\Learning\RTOS\build\a55-bin\hello_world.bin root@<板子IP>:/tmp/
```

```bash
# 板上
modprobe jailhouse                              # 若尚未启用
jailhouse enable /usr/share/jailhouse/cells/imx95.cell
jailhouse cell create /usr/share/jailhouse/cells/imx95-harpoon-freertos.cell
jailhouse cell load freertos /tmp/hello_world.bin -a 0xf0000000
jailhouse cell start freertos
# 看 COM9（inmate 控制台）
```

> **重编后重跑**：`cell destroy` → `cell create` → `cell load` → `cell start`。
> 只换 bin 的话 `cell` 本身不用重建，但 `load` 必须在 `start` 之前。

## 相关

- 板上跑通记录（含 COM 口、SM 配置差异）→ [[10-项目/IMX95-EVK/开发日志.md|IMX95-EVK 开发日志]]
- Harpoon 开发流程 → [[10-项目/FRDM-IMX95-PRO/Harpoon复现.md|Harpoon 复现：手把手操作]]
- EVK 到手计划 → [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划]]

