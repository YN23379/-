---
type: 知识库
scope: Linux
doc_type: 未分类
status: 已整理
evidence: 实机验证
tags: [驱动, 启动, 编译构建]
updated: 2026-09-17
---



# 🟢 第五层：嵌入式 Linux 开发基础

嵌入式 Linux 是物联网、智能设备、工业控制等领域的核心技术之一。本层重点掌握从 Bootloader 到驱动的开发过程，理解 Linux 系统构成及其移植方法。

---

## 🔹 嵌入式 Linux 系统概览

### 📌 嵌入式 Linux 特点

- 可裁剪、可定制、模块化强
- 支持多种架构（ARM、MIPS、RISC-V 等）
- 社区支持强大（开源内核、驱动丰富）

### 📌 系统组成

```text
[Bootloader] → [Kernel] → [Root File System] → [User Application]
```

- **Bootloader**：负责上电后硬件初始化、加载内核（如 U-Boot）
- **Kernel**：Linux 内核，管理硬件与系统资源
- **RootFS**：根文件系统，包含用户空间程序
- **应用层**：运行用户程序、脚本、服务等

---

## 🔹 启动流程详解

### 📌 通用启动流程

```text
Power On →
  BootROM →
    Bootloader (SPL/U-Boot) →
      Load & Decompress Kernel →
        Kernel 初始化 →
          挂载 RootFS →
            启动 init →
              Shell / App
```

### 📌 U-Boot（主流 Bootloader）

- 二阶段：SPL（初始化内存）+ U-Boot 本体
- 功能：串口输出、TFTP 下载、引导内核、环境变量配置等
- 命令示例：
```bash
setenv bootargs console=ttyS0 root=/dev/mmcblk0p2
tftp 0x80008000 zImage
bootz 0x80008000 - 0x83000000
```

---

## 🔹 设备树（Device Tree）

### 📌 基本概念

- 描述硬件资源的结构化信息
- 独立于内核源码，提高可移植性
- 文件类型：`.dts`（源文件）、`.dtsi`（包含文件）、`.dtb`（二进制）

### 📌 示例结构

```dts
uart1: serial@40011000 {
    compatible = "vendor,uart";
    reg = <0x40011000 0x400>;
    interrupts = <5>;
    status = "okay";
};
```

### 📌 编译设备树

```bash
make ARCH=arm CROSS_COMPILE=arm-linux- dtbs
```

---

## 常用 Linux 命令与开发工具

> **详细条目见 [[20-领域/Linux/Linux常用命令.md|Linux 常用命令]]**——那边每条命令都给**英文全称、作用、核心选项、示例、怎么读输出**。
> 本节只留"什么场景用什么"的索引，不再罗列浅表命令。

### 按场景查命令

| 想干什么 | 用什么 | 在详细条目里 |
|---|---|---|
| 看有哪些存储设备、哪个是 eMMC 哪个是 SD | `lsblk` | 一、存储 |
| 看某个目录是不是内存盘 | `df -h <目录>` | 一、存储 |
| 挂载 / 卸载设备 | `mount` / `umount` | 一、存储 |
| 写整盘镜像到 SD 卡 | `zstd -dc x.wic.zst \| dd of=/dev/sdX bs=8M` | 一、存储 |
| 看板子 IP / 拉起网口 | `ip -br addr` / `ip link set eth0 up` | 二、网络 |
| 传文件到板子 / 登录 | `scp` / `ssh` | 二、网络 |
| 看内核报错 | `dmesg` | 三、内核与驱动 |
| 看模块版本 / 加载模块 | `modinfo` / `modprobe` | 三、内核与驱动 |
| 读内核状态 | `cat /proc/...`、`/sys/...` | 四、文本与二进制 |
| 搜设备或固件里的字符串 | `grep -aoE "..." /dev/xxx` | 四、文本与二进制 |
| 判断文件是什么格式 | `head -c 16 f \| od -A d -t x1` | 四、文本与二进制 |
| 确认内核版本 / 核数 | `uname -r` / `nproc` | 五、系统信息 |
| 管理 systemd 服务 | `systemctl` | 六、服务与压缩 |
| **验证某个外设归不归当前域** | Python + `/dev/mem` | 七、特殊手段 |

### 基础操作（不在详细条目里，但要会）

| 命令 | 作用 |
|---|---|
| `ls -l` / `ls -a` | 列目录（长格式 / 含隐藏文件） |
| `cd` / `pwd` | 切目录 / 显示当前目录 |
| `cp` / `mv` / `rm` | 复制 / 移动 / 删除 |
| `mkdir -p` | 建目录（含中间层） |
| `chmod` / `chown` | 改权限 / 改属主 |
| `sudo` / `whoami` / `id` | 提权 / 看当前用户 |
| `ps` / `top` / `kill` / `nice` | 看进程 / 杀进程 / 调优先级 |
| `ping` | 测连通性 |

### 软件包管理（按发行版）

| 工具 | 用在哪 |
|---|---|
| `apt` / `dpkg` | Debian 系（Ubuntu、WSL） |
| `opkg` | OpenWrt、部分嵌入式 rootfs |
| `yum` / `dnf` | Red Hat 系 |

### Shell 脚本与自动化
- `#!/bin/sh` 或 `#!/bin/bash`：脚本头部声明
- 脚本权限设置：`chmod +x script.sh`
- 示例：

```sh
# !/bin/bash
for i in {1..5}
do
   echo "Test $i"
done
```

### 交叉编译相关命令（Makefile 环境）

**`make`** —— *GNU Make*，按 Makefile 里写的依赖关系决定"哪些文件需要重新编译、按什么顺序编译"，只重编改动过的部分。
- `-j$(nproc)`：并行编译，用满所有核；`nproc` 先问出核数再传进去
- `-C <目录>`：先切到该目录再找 Makefile，常用于一行命令编多个子项目
- `ARCH=` / `CROSS_COMPILE=`：交叉编译内核/设备树时必须显式指定，Makefile 不会自己猜
- 示例：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8 dtbs`

**`aarch64-linux-gnu-gcc`** —— *GNU Compiler Collection*，交叉编译器。名字里的三段分别是：目标架构（aarch64）、目标系统（linux-gnu，即链接 glibc）、工具名。
- `-c`：只编译成 `.o`，不链接
- `-o <文件>`：指定输出名
- `-I<目录>` / `-L<目录>` / `-l<库名>`：头文件路径 / 库路径 / 链接哪个库
- `--sysroot=<目录>`：指定目标系统的根目录，避免误用宿主机头文件
- 示例：`aarch64-linux-gnu-gcc -c hello.c -o hello.o`

**`file`** —— 读文件头部魔数判断真实类型，不看扩展名。
- `-b`：只输出类型描述，不带文件名
- `-L`：跟符号链接，看它指向的真实文件
- 为什么用它：交叉编译后确认产物到底是不是 aarch64，别把 x86 的二进制拷到板子上
- 示例：`file hello` → `ELF 64-bit LSB executable, ARM aarch64, ...`

---

## 🔹 Linux 驱动开发模型

### 📌 驱动分层模型

```text
[硬件设备] ←→ [总线] ←→ [Device] ←→ [Driver] ←→ [内核]
```

- **总线（bus）**：如 platform、i2c、spi 总线
- **设备（device）**：描述具体外设
- **驱动（driver）**：实现对设备的控制逻辑

### 📌 字符设备驱动框架

```c
struct file_operations fops = {
    .open = my_open,
    .read = my_read,
    .write = my_write,
    .release = my_release,
};

int major = register_chrdev(0, "mydev", &fops);
```

### 📌 平台驱动开发流程

1. 定义 `platform_device`
2. 编写并注册 `platform_driver`
3. 通过 `of_match_table` 匹配设备树节点
4. 实现 `probe/remove` 等接口

---

## 🔹 根文件系统构建

### 📌 常见文件系统类型

- ext3/ext4：标准 Linux 文件系统
- squashfs：只读压缩文件系统，适合嵌入式
- initramfs：内存文件系统

### 📌 文件系统布局（典型）

```
/
├── bin/       → 常用命令
├── sbin/      → 系统工具
├── etc/       → 配置文件
├── dev/       → 设备节点
├── lib/       → 库文件
├── proc/      → 内核虚拟文件系统
├── sys/       → 设备/驱动信息
├── usr/       → 用户软件
├── tmp/       → 临时目录
└── home/      → 用户主目录
```

### 📌 构建方式

- BusyBox + 自制文件结构
- Buildroot：快速构建定制系统
- Yocto：更灵活、工业级构建方案

---

## 🔹 工具链与调试手段

### 📌 交叉编译工具链

- gcc-arm-linux-gnueabi
- arm-none-eabi-gcc
- 使用环境变量指定：
```bash
export CROSS_COMPILE=arm-linux-
```

### 📌 GDB 调试

- GDB Server + Remote Debug
```bash
gdb-multiarch vmlinux
target remote :1234
```

### 📌 常用调试工具

**`strace`** —— *system call trace*，把程序发出的每一次系统调用（open/read/mmap/ioctl…）连参数和返回值一起打出来。程序"跑起来没反应又不报错"时，先用它看它到底卡在哪一个调用上。
- `-f`：连它 fork 出来的子进程一起跟
- `-e trace=openat,read`：只看关心的几类调用，不然输出会淹没你
- `-p <PID>`：挂到已经在跑的进程上，不用重启它
- 示例：`strace -f -e trace=openat ./myapp 2>&1 | tail -20`

**`ldd`** —— *list dynamic dependencies*，列出一个可执行文件运行时需要哪些 `.so`，以及这些库在系统里能不能找到。
- 输出里出现 `not found`，说明板子上缺库或库路径不对，这是"宿主机上能跑、拷到板子就报错"的头号原因
- 示例：`ldd ./hello` → 每行一个库 + 它在板子上的路径

**`top`** —— 实时刷新进程列表，看 CPU、内存占用。`htop` 是它的交互式增强版（颜色、鼠标、树状视图），嵌入式 rootfs 上通常没装。

**`lsmod`** —— *list modules*，列当前已加载的内核模块。
**`insmod`** —— *insert module*，加载一个 `.ko` 文件，**需要给完整路径，不处理依赖**。
**`modprobe`** —— 同样加载模块，但会去 `/lib/modules/$(uname -r)/` 找、并自动先加载依赖的模块。日常优先用 `modprobe`，`insmod` 只在调试一个刚编出来、还没装进模块目录的 `.ko` 时用。

**`dmesg`** —— 内核日志。详细选项见 [[20-领域/Linux/Linux常用命令.md|Linux 常用命令]] 第三节。

---

## 🔹 常见开发平台

| 平台        | 特点                         |
|-------------|------------------------------|
| Raspberry Pi | 社区活跃，支持 Linux 全栈     |
| Allwinner / Rockchip | 国产主控，适配良好    |
| BeagleBone   | 支持 PRU、实时协处理器       |
| STM32MP1     | 支持 Linux + Cortex-M 协同   |

---

### 🔹 嵌入式系统安全基础
1. 威胁模型分析
- 物理攻击：
  - 探针访问调试接口（JTAG/SWD）读取 Flash 内容。
  - 电压 / 时钟干扰导致程序异常（故障注入攻击）。
- 网络攻击：
  - 中间人攻击（MITM）篡改通信数据。
  - 恶意固件注入（利用未加密 OTA 通道）。
- 软件攻击：
  - 缓冲区溢出执行恶意代码。
  - 逆向工程获取算法逻辑（如加密密钥）。

2. 安全设计原则
- 最小权限原则：

每个组件仅拥有完成任务所需的最小权限（如 MPU 配置）。

- 防御纵深：

多层次安全机制（如安全启动 + 通信加密 + 运行时防护）。

- 故障安全：

系统在异常情况下自动进入安全状态（如看门狗复位）。

---

### 🔹 安全启动（Secure Boot）

> 保证启动时加载的固件是可信的

1. 基本原理
```plaintext
BootROM → 加载并验证一级Bootloader → 加载并验证二级Bootloader → 加载并验证应用固件
```
- 信任链传递：

每个阶段只信任经过上一阶段验证的代码。

2. 数字签名验证流程
```c
// 简化的签名验证伪代码
bool VerifyFirmwareSignature(uint8_t *firmware, uint32_t size, uint8_t *signature) {
    // 1. 从OTP读取可信根公钥
    const uint8_t *trusted_public_key = GetTrustedPublicKey();
    
    // 2. 计算固件哈希值
    uint8_t calculated_hash[32];
    SHA256(firmware, size, calculated_hash);
    
    // 3. 使用公钥解密签名获取原始哈希
    uint8_t decrypted_hash[32];
    RSA_PKCS1_Verify(trusted_public_key, signature, decrypted_hash);
    
    // 4. 比较哈希值
    return (memcmp(calculated_hash, decrypted_hash, 32) == 0);
}
```
3. STM32 Secure Boot 实现
- 选项字节配置：
```c
// 启用读保护（RDP）
HAL_FLASH_OB_Unlock();
FLASH_OBProgramInitTypeDef obInit = {0};
obInit.OptionType = OPTIONBYTE_RDP;
obInit.RDPLevel = OB_RDP_LEVEL_1;  // 禁用调试接口
HAL_FLASHEx_OBProgram(&obInit);
HAL_FLASH_OB_Lock();
```
- TrustZone 配置（适用于 STM32L5 等支持型号）：
```c
// 配置安全/非安全区域
MPU_Region_InitTypeDef MPU_InitStruct = {0};

// 配置SRAM为安全区域
MPU_InitStruct.Number = MPU_REGION_0;
MPU_InitStruct.BaseAddress = 0x20000000;
MPU_InitStruct.Size = MPU_REGION_SIZE_512KB;
MPU_InitStruct.SubRegionDisable = 0x00;
MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
MPU_InitStruct.DisableExec = DISABLE;
MPU_InitStruct.IsShareable = ENABLE;
MPU_InitStruct.IsCacheable = DISABLE;
MPU_InitStruct.IsBufferable = DISABLE;
HAL_MPU_ConfigRegion(&MPU_InitStruct);
```

---

### 🔹 固件加密与防逆向

1. **AES 加密固件**，防止泄露源码逻辑

- 加密流程：
  - 开发阶段：使用工具链（如 GCC 插件）加密固件。
  - 部署阶段：Bootloader 解密后加载到 RAM 执行。
- 密钥管理：
  - 主密钥存储在 OTP（一次性可编程）区域。
  - 会话密钥通过主密钥派生（如 AES-KDF）

2. Flash 读保护（RDP）

| RDP 级别   | 保护效果                                 | 可逆性                  |
|------------|------------------------------------------|-------------------------|
| Level 0    | 无保护（默认）                           | 是                      |
| Level 1    | 禁止调试接口，Flash 只能运行不能读取     | 降级会擦除所有 Flash    |
| Level 2    | 永久禁止调试接口和 Flash 读取            | 不可逆                  |

3. 代码混淆技术  
- 控制流平坦化：

将线性代码转换为基于状态机的结构，增加逆向难度。

- 指令替换：

用等效指令序列替换关键操作（如a+b替换为a-(-b)）。


---

### 🔹 权限隔离与防护

1. MPU（内存保护单元）配置
```c
// 配置MPU保护关键数据区
void ConfigureMPU(void) {
    // 使能MPU
    HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
    
    // 配置区域0保护关键代码区
    MPU_Region_InitTypeDef MPU_InitStruct = {0};
    MPU_InitStruct.Number = MPU_REGION_0;
    MPU_InitStruct.BaseAddress = 0x08000000;  // Flash起始地址
    MPU_InitStruct.Size = MPU_REGION_SIZE_128KB;
    MPU_InitStruct.SubRegionDisable = 0x00;
    MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
    MPU_InitStruct.AccessPermission = MPU_REGION_PRIV_RW_URO;  // 特权可读写，用户只读
    MPU_InitStruct.DisableExec = DISABLE;
    MPU_InitStruct.IsShareable = DISABLE;
    MPU_InitStruct.IsCacheable = DISABLE;
    MPU_InitStruct.IsBufferable = DISABLE;
    HAL_MPU_ConfigRegion(&MPU_InitStruct);
}
```
2. TrustZone 安全域隔离
- 安全资产分类：

| 类别       | 示例                         | 存储位置         |
|------------|------------------------------|------------------|
| 密钥       | TLS 私钥、加密密钥           | 安全 SRAM        |
| 敏感算法   | 密码验证、加密函数           | 安全代码区       |
| 安全服务   | OTA 签名验证、证书管理       | 安全任务         |

- 安全 / 非安全通信：
```c
// 从非安全代码调用安全服务
__attribute__((section(".nonsecure_call")))
uint32_t SecureService_Call(uint32_t service_id, uint32_t param1, uint32_t param2) {
    // 通过SVC指令切换到安全模式
    __asm("SVC #0");
    // 返回值通过R0传递
}
```

---

### 🔹 Bootloader 开发建议

- 通用功能：下载、校验、重启、回滚
- 支持双分区升级（Slot A / Slot B）
- 防止电量中断、写失败后的砖机风险
- 可设置升级标志位（Upgrade Flag）

---

## 🔚 小结

嵌入式 Linux 是从单片机迈向高性能系统开发的核心门槛，掌握其启动流程、设备树结构与驱动框架是后续学习内核裁剪、系统移植与 IoT 平台开发的基础。
