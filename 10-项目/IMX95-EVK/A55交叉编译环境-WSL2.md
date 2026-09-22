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

## 只装 FreeRTOS 需要的，不装 Zephyr

`harpoon-apps` 的 `west.yml` 里定义了一堆依赖，**但跑 FreeRTOS 用不到全部**：

| 项目 | 要不要 | 说明 |
|---|---|---|
| `harpoon-apps` | ✅ 要 | 示例应用本体 |
| `mcux-sdk`、`CMSIS_5` | ✅ 要 | FreeRTOS 用的驱动和 CMSIS |
| `FreeRTOS-Kernel` | ✅ 要 | 内核 |
| `heterogeneous-multicore`、`mcux-sdk-middleware-multicore`、`rpmsg-lite` | ✅ 要 | 核间通信（RPMsg） |
| **`zephyr`** | ❌ **不要** | **另一个 RTOS，我们只用 FreeRTOS**（约 1GB） |
| **`GenAVB_TSN`**（`gen_avb_sdk`） | ❌ 不要 | 音频/工业应用才用 |
| **`rtos-abstraction-layer`** | ❌ 不要 | 音频/工业应用才用 |
| `hal_nxp` | ❌ 不要 | Zephyr 的 HAL |

**默认的 `west update` 会把上面全部拉下来**，包括用不到的 Zephyr。**指定项目名可以只拉需要的**：

```bash
cd ~/hww
west update mcux-sdk FreeRTOS-Kernel CMSIS_5 heterogeneous-multicore \
            mcux-sdk-middleware-multicore rpmsg-lite
```

**已经在拉的怎么补救**：直接删掉不需要的目录，然后按上面只拉需要的。

```bash
rm -rf ~/hww/zephyr ~/hww/gen_avb_sdk ~/hww/rtos-abstraction-layer
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
cd hww && west update <只列需要的项目>
```

跨 `/mnt/f` 的性能损失在 WSL2 里有几十倍。编好的 `.bin` 再拷到 Windows 侧。

## 日常用法

```powershell
# 进入环境
wsl -d IMX95A55

# 在里面
cd ~/hww
cd harpoon-apps/<应用>/freertos/boards/imx95lpd5evk19/armgcc_aarch64
./build_ddr_release.sh
```

## 待补

- `west update` 拉取依赖的完整结果（进行中）
- 实际编出一个 `hello_world.bin` 并验证

## 相关

- Harpoon 开发流程 → [[10-项目/FRDM-IMX95-PRO/Harpoon复现.md|Harpoon 复现：手把手操作]]
- EVK 到手计划 → [[10-项目/IMX95-EVK/EVK-19x19到手操作计划.md|EVK-19x19 到手操作计划]]
