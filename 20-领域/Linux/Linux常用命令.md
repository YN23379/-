---
type: 知识库
scope: Linux 通用（命令与排查手段）
doc_type: 参考
status: 已整理
evidence: 实机验证
tags: [Linux, 命令, 排查, 存储, 网络]
updated: 2026-09-22
---

# Linux 常用命令

> **适用范围**：嵌入式 Linux 开发与排查。命令本身跨发行版通用，示例来自 i.MX95 板子的实际输出。
>
> **本文的写法约定**：每条命令给 **英文全称 / 作用 / 核心选项 / 示例 / 怎么读输出**。
> 只列"能解决什么问题"，不罗列全部选项——完整选项用 `man <命令>` 或 `<命令> --help`。
>
> **相邻**：命令背后的原理 → [[20-领域/Linux/嵌入式Linux.md|嵌入式Linux]]；内核机制 → [[20-领域/Linux/Linux内核.md|Linux内核]]。

---

## 一、存储：确认设备、容量、挂载

排查"数据在哪个设备上"这类问题。**写卡、刷机、挂载前必须先确认设备名，认错会抹掉系统。**

### `lsblk` —— 列出块设备

**英文全称**：list block devices

**作用**：把系统里所有**块设备**（可以按固定大小的块随机读写的存储设备：硬盘、eMMC、SD 卡、U 盘）及其**分区**按树形列出来，同时显示容量和挂载点。

**核心选项**

| 选项 | 作用 |
|---|---|
| （不加） | 树形显示：设备 → 分区 → 挂载点 |
| `-f` | 额外显示文件系统类型、UUID、卷标 |
| `-o 列名,...` | 自选列，例如 `-o NAME,SIZE,FSTYPE,MOUNTPOINT` |
| `-p` | 显示完整设备路径（`/dev/mmcblk0p1` 而不是 `mmcblk0p1`） |
| `-d` | 只显示设备，不显示分区 |

**示例**

```bash
$ lsblk
NAME         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
mtdblock0     31:0    0  128M  0 disk
mmcblk0      179:0    0 59.3G  0 disk
|-mmcblk0p1  179:1    0  256M  0 part /run/media/boot-mmcblk0p1
`-mmcblk0p2  179:2    0 10.2G  0 part /
mmcblk0boot0 179:32   0 31.5M  1 disk
mmcblk0boot1 179:64   0 31.5M  1 disk
mmcblk1      179:96   0 29.7G  0 disk
`-mmcblk1p1  179:97   0 29.4G  0 part /run/media/mmcblk1p1
```

**怎么读输出**

| 列 | 含义 |
|---|---|
| `NAME` | 设备名。**`mmcblk0` 是设备，`mmcblk0p1` 是它的第 1 个分区**（`p` 后是分区号） |
| `SIZE` | 容量 |
| `RO` | 只读标志，`1` = 只读 |
| `TYPE` | `disk` = 整块设备，`part` = 分区 |
| `MOUNTPOINTS` | 挂载点。**空的说明没挂载** |

**命名规律**

| 名字 | 是什么 |
|---|---|
| `mmcblk0` / `mmcblk1` | eMMC 和 SD 卡（**哪个是哪个要看容量和挂载点，不能凭序号猜**） |
| `mmcblk0boot0` / `boot1` | eMMC 的两个**独立启动分区**（存启动容器的，不出现在普通分区表里） |
| `mtdblock0` | NOR/NAND Flash |
| `sdX` | SATA/USB 硬盘 |

**本项目为什么用**：写 SD 卡前确认设备名。板子上 `mmcblk0` 是 eMMC（59.3G）、`mmcblk1` 是 SD 卡（29.7G）——**认错就把板子系统抹了**。

**相邻**：`blkid` 看 UUID 和文件系统类型；`fdisk -l` 看分区表详情。

### `df` —— 看文件系统空间

**英文全称**：disk free

**作用**：显示**已挂载文件系统**的容量、已用、可用。和 `lsblk` 的区别：`lsblk` 看的是**块设备**，`df` 看的是**挂载好的文件系统**。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-h` | human-readable，用 K/M/G 显示而不是字节数 |
| `-T` | 额外显示文件系统类型 |
| `-i` | 显示 inode 使用情况（不是空间，是文件数量） |
| `-a` | 包含所有文件系统（含 0 大小的伪文件系统） |

**示例**

```bash
$ df -h /tmp
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           6.6G  8.0K  6.6G   1% /tmp
```

**怎么读输出**

| 列 | 含义 |
|---|---|
| `Filesystem` | 文件系统来源。**显示 `tmpfs` 说明是内存盘** |
| `Size` / `Used` / `Avail` | 总容量 / 已用 / 可用 |
| `Mounted on` | 挂载点 |

**关键用法：判断某个目录是不是内存盘**

```bash
$ df -h /tmp
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           6.6G  8.0K  6.6G   1% /tmp        ← tmpfs = 内存盘，重启即丢
```

**为什么重要**：往 `/tmp` 放文件前先确认它是不是 tmpfs。是的话文件只在内存里，**重启就没了**，同时也意味着**不占 eMMC 寿命**。

### `mount` / `umount` —— 挂载 / 卸载

**英文全称**：mount（挂载）；umount = unmount（卸载）

**作用**：把存储设备上的文件系统接到目录树上（挂载），或断开（卸载）。**Linux 里访问任何文件都要先挂载。**

**核心选项**

| 命令 | 选项 | 作用 |
|---|---|---|
| `mount` | （无参数） | 列出当前所有挂载 |
| | `-t 类型` | 指定文件系统类型（ext4/vfat/nfs…） |
| | `-o 选项` | 挂载参数，如 `ro`（只读）、`rw`、`sync` |
| `umount` | （无参数） | 卸载指定挂载点或设备 |
| | `-l` | lazy，等引用释放后再卸载（设备忙时用） |

**示例**

```bash
# 挂载 SD 卡的第二个分区到 /mnt/t
mkdir -p /mnt/t
mount /dev/mmcblk1p2 /mnt/t
ls /mnt/t
umount /mnt/t
```

**判断挂载是否成功**：命令返回 0 且能 `ls` 出内容。失败会报 `wrong fs type` / `bad superblock` / `can't read superblock`——**这些错误说明文件系统本身有问题，不是挂载参数问题**。

**本项目为什么用**：验证 SD 卡写卡是否完整。`mount /dev/mmcblk1p2` 挂不上，说明 rootfs 没写全。

### `dd` —— 按字节复制（写镜像）

**英文全称**：data duplicator（一说 disk dump，无官方全称）

**作用**：**不加任何解释地按块复制数据**。写整盘镜像、备份分区、造空文件都用它。

**核心选项**

| 选项 | 作用 |
|---|---|
| `if=文件` | input file，源 |
| `of=设备` | output file，目标。**这里写错设备 = 数据全毁** |
| `bs=大小` | block size，一次读写多少字节。写卡常用 `8M` |
| `count=N` | 只复制 N 个块 |
| `status=progress` | 显示进度（GNU 版支持） |
| `oflag=direct` | 绕过页缓存直接写，写大镜像时更快更稳 |
| `conv=fsync` | 结束时同步落盘 |

**示例：把镜像写进 SD 卡**

```bash
zstd -dc image.wic.zst | dd of=/dev/mmcblk1 bs=8M oflag=direct status=progress
sync
```

**示例：只看设备开头几个字节**（不写，安全）

```bash
head -c 8388608 /dev/mmcblk0 | grep -aoE "mx95[A-Za-z0-9_-]{2,20}" | sort -u
```

**为什么危险**：`dd` 不检查目标是不是你想要的那个设备。`of=` 写成 `/dev/mmcblk0` 而不是 `mmcblk1`，就会把 eMMC 抹掉。

**用前必做**：`lsblk` 确认设备名 + 容量对得上。

**相邻**：`zstd` / `gzip` / `xz` 解压，`sync` 落盘。

### `sync` —— 把缓存刷到存储

**英文全称**：synchronize

**作用**：把内存里还没写回磁盘的数据**强制刷到存储设备**。

**为什么需要**：Linux 写文件先写页缓存，不立即落盘。**拔卡、断电前不 `sync`，数据会丢。**

**示例**

```bash
dd if=image of=/dev/sdX bs=8M
sync                    # ← 不跑这行就拔卡 = 镜像不完整
```

---

## 二、网络：确认地址、传文件

### `ip` —— 查看和配置网络

**英文全称**：internet protocol（命令名就叫 `ip`，属于 iproute2 套件）

**作用**：查看和配置网络接口、地址、路由。**取代了老的 `ifconfig` / `route` / `arp`。**

**核心子命令**

| 子命令 | 作用 |
|---|---|
| `ip addr` | 看接口的 IP 地址 |
| `ip link` | 看/改接口的链路状态（up/down） |
| `ip route` | 看路由表 |
| `ip neigh` | 看 ARP 邻居表 |

**核心选项**

| 选项 | 作用 |
|---|---|
| `-br` | brief，一行一个接口，只显示关键信息 |
| `-4` / `-6` | 只看 IPv4 / IPv6 |
| `-c` | 彩色输出 |

**示例**

```bash
$ ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             DOWN
eth1             UP             169.254.86.80/16 fe80::204:9fff:fe0a:3e59/64
can0             DOWN
```

**怎么读输出**

| 列 | 含义 |
|---|---|
| 接口名 | `lo` 本地回环、`eth0`/`eth1` 以太网、`can0` CAN 总线 |
| 状态 | `UP` = 启用，`DOWN` = 关闭，`UNKNOWN` = 无载波 |
| 地址 | IPv4 和 IPv6 地址 |

**两个常见坑**

1. **`eth0` 默认 DOWN**：板子的网口默认是关的，要 `ip link set eth0 up` 才有地址。
2. **`169.254.x.x` 是链路本地地址（APIPA）**：网线直连两台机器时自动协商出来的，**不需要 DHCP、不需要手工配 IP**。但**每次重启都会变**——所以脚本里不能写死，要每次查。

**示例：拉起来并查地址**

```bash
ip link set eth0 up
ip -br addr
```

**相邻**：`ping` 测连通性，`ssh` / `scp` 走网络。

### `ssh` —— 远程登录

**英文全称**：Secure SHell

**作用**：加密登录远程主机，在对面执行命令。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-o BatchMode=yes` | 不交互，认证失败直接退出（脚本里用） |
| `-o StrictHostKeyChecking=no` | 首次连接不询问是否信任主机（脚本里用） |
| `-o ConnectTimeout=N` | 连接超时秒数 |
| `-p 端口` | 指定端口（默认 22） |
| `命令` | 不登录，直接执行一条命令后退出 |

**示例**

```bash
# 登录
ssh root@169.254.86.80

# 不登录，直接执行（脚本里最常用）
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@169.254.86.80 'uname -a'

# 多行命令
ssh root@<IP> '
  echo "MemTotal: $(grep MemTotal /proc/meminfo)"
  nproc
'
```

**为什么对嵌入式排查很有用**：**串口会被外设抢走，SSH 不会。** 板子上的程序占了调试串口时，SSH 仍然能操作。

**相邻**：`scp` 传文件，`sshd` 服务端。

### `scp` —— 远程复制文件

**英文全称**：secure copy

**作用**：基于 SSH 的加密文件传输，**用法和 `cp` 几乎一样**，只是路径可以带 `用户@主机:` 前缀。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-r` | 递归复制目录 |
| `-P 端口` | 指定端口（注意是大写 P，`ssh` 是小写 p） |
| `-o 选项` | 透传给 ssh 的选项 |

**示例**

```bash
# 本地 → 远程
scp file.bin root@169.254.86.80:/tmp/

# 一次传多个
scp a.cell b.bin c.bin root@169.254.86.80:/tmp/

# 远程 → 本地
scp root@169.254.86.80:/proc/device-tree/model .

# 递归传目录
scp -r ./mydir root@169.254.86.80:/tmp/
```

**相邻**：`rsync` 支持增量同步，传大目录比 `scp` 快。

---

## 三、内核与驱动：看日志、管模块

### `dmesg` —— 看内核环形缓冲区

**英文全称**：display message（一说 driver message）

**作用**：打印**内核**的输出。设备初始化、驱动报错、硬件异常都记在这里。**和用户态日志（`journalctl`）是两回事。**

**核心选项**

| 选项 | 作用 |
|---|---|
| `-T` | 把时间戳转成可读日期（默认是开机后秒数） |
| `-w` | 持续输出新消息（类似 `tail -f`） |
| `-l 级别` | 按级别过滤，如 `-l err,warn` |
| `-H` | 人类可读 + 分页 |
| `-c` | 打印后清空缓冲区 |

**示例**

```bash
# 看串口和网络相关
dmesg | grep -iE "lpuart|ttyLP|eth"

# 只看错误和警告
dmesg -l err,warn

# 持续跟
dmesg -w
```

**怎么读时间戳**：默认格式 `[   12.345678]` 是**开机后的秒数**。要绝对时间用 `dmesg -T`。

**本项目为什么用**：定位 jailhouse 报错、看 LPUART 注册情况、看 `lmm(1) not under Linux Control` 这类内核消息。

**相邻**：`journalctl` 看 systemd 管的用户态日志。

### `modprobe` / `lsmod` / `modinfo` —— 内核模块

| 命令 | 英文全称 | 作用 |
|---|---|---|
| `lsmod` | list modules | 列出已加载的内核模块 |
| `modinfo` | module information | 看某个模块的信息（路径、版本、依赖、参数） |
| `modprobe` | module probe | 加载模块（**会自动处理依赖**） |
| `modprobe -r` | — | 卸载模块 |

**和 `insmod` 的区别**：`insmod` 只认文件路径、**不处理依赖**；`modprobe` 从模块目录找、**自动解决依赖**。**优先用 `modprobe`。**

**核心选项**

| 命令 | 选项 | 作用 |
|---|---|---|
| `modprobe` | `-r` | 卸载 |
| | `-n` | 只显示会做什么，不实际执行 |
| `modinfo` | `-F 字段` | 只输出某个字段，如 `-F filename` |
| `lsmod` | — | 输出三列：模块名、大小、被引用次数 |

**示例**

```bash
# 看模块在不在、什么版本
$ modinfo jailhouse
filename:       /lib/modules/6.12.34-lts-next-.../updates/driver/jailhouse.ko
version:        v0.12 (387-g7b9bbf71-dirty)
firmware:       jailhouse.bin
description:    Management driver for Jailhouse partitioning hypervisor

# 加载
modprobe jailhouse

# 确认加载了
$ lsmod | grep jailhouse
jailhouse              40960  1

# 卸载
modprobe -r jailhouse
```

**怎么读 `modinfo`**

| 字段 | 含义 |
|---|---|
| `filename` | `.ko` 文件的实际路径（**能看出内核版本对不对**） |
| `version` | 模块自己的版本 |
| `firmware` | 这个模块需要加载的固件名 |
| `vermagic` | 模块编译时的内核版本 + 配置（**不匹配就加载不了**） |

**本项目为什么用**：确认 jailhouse 模块在不在、版本是多少、和包里的 cell 配不配套。

---

## 四、文本与二进制：看文件内容

### `cat` —— 输出文件内容

**英文全称**：concatenate（连接）

**作用**：把文件内容打到标准输出。**名字叫"连接"是因为可以一次给多个文件，它们会被首尾相接输出。**

**核心选项**

| 选项 | 作用 |
|---|---|
| `-n` | 显示行号 |
| `-A` | 显示所有不可见字符（排查换行符、制表符问题） |

**示例：读 procfs / sysfs**

Linux 把内核状态暴露成文件，`cat` 就是读它们的标准手段：

```bash
cat /proc/cmdline              # 内核命令行
cat /proc/meminfo              # 内存信息
cat /proc/partitions           # 分区表
cat /proc/device-tree/model    # 板型（注意末尾没有换行）
cat /sys/class/remoteproc/remoteproc1/state
```

**为什么 `cat` 一个"文件"能读到内核信息**：`/proc` 和 `/sys` 是**虚拟文件系统**，文件内容是内核**即时生成**的，不是存在磁盘上的。写它们还能改内核状态（比如 `/sys/.../unbind`）。

**相邻**：`less` 分页看大文件，`head` / `tail` 看头尾。

### `head` / `tail` —— 看头几行 / 尾几行

| 命令 | 英文全称 | 作用 |
|---|---|---|
| `head` | — | 输出文件**开头**若干行（默认 10 行） |
| `tail` | — | 输出文件**末尾**若干行（默认 10 行） |

**核心选项**

| 命令 | 选项 | 作用 |
|---|---|---|
| `head` | `-n N` | 前 N 行 |
| | `-c N` | 前 N **字节**（读二进制设备时用这个） |
| `tail` | `-n N` | 后 N 行 |
| | `-f` | 持续跟（`follow`），文件增长就输出 |
| | `-F` | 同 `-f`，但文件被轮转后能重新打开 |

**示例**

```bash
head -2 /proc/meminfo                # 前两行（MemTotal 和 MemFree）
tail -20 /var/log/messages
tail -f /var/log/syslog

# 读块设备的前 8 MB（不写，安全）
head -c 8388608 /dev/mmcblk0 | grep -aoE "mx95[A-Za-z0-9_-]{2,20}" | sort -u
```

**`head -c` 读块设备的技巧**：直接 `grep` 整个设备会很慢（几十 GB），**先用 `head -c` 截取开头一段再搜**。

### `grep` —— 按模式搜索文本

**英文全称**：global regular expression print

**作用**：在输入里找**匹配正则表达式**的行并输出。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-i` | 忽略大小写 |
| `-E` | 用扩展正则（`+` `?` `|` 不用转义） |
| `-a` | **把二进制文件当文本处理**（搜设备/固件时**必须加**） |
| `-o` | 只输出匹配到的部分，不输出整行 |
| `-c` | 只输出匹配行数 |
| `-v` | 反向，输出不匹配的行 |
| `-n` | 显示行号 |
| `-r` | 递归搜目录 |
| `-A N` / `-B N` / `-C N` | 额外显示后 N 行 / 前 N 行 / 前后各 N 行 |

**示例**

```bash
# 搜内核日志
dmesg | grep -iE "lpuart|ttyLP"

# 搜二进制设备（-a 不能省，否则 grep 会说 "Binary file matches" 不显示内容）
grep -aoE "mx95[A-Za-z0-9_-]{2,20}" /dev/mmcblk0boot0 | sort -u

# 递归搜源码
grep -rn "jh_root_mem" tools/uboot-imx-source/board/

# 带上下文
grep -n -A5 "Reset_Handler" startup_MIMX95_cm33.S
```

**`-a` 为什么关键**：grep 默认会检测文件是不是二进制。搜 `/dev/mmcblk0`、`.bin`、`.ko` 这类文件时不加 `-a`，它只会告诉你"Binary file matches"而不显示内容。

### `find` —— 按条件找文件

**英文全称**：find（动词，查找）

**作用**：在目录树里**按名字、类型、大小、时间等条件**找文件。和 `grep` 的分工：**`find` 找文件，`grep` 找内容。**

**核心选项**

| 选项 | 作用 |
|---|---|
| `-name 模式` | 按文件名（区分大小写） |
| `-iname 模式` | 按文件名（忽略大小写） |
| `-type f/d/l` | 只要普通文件 / 目录 / 符号链接 |
| `-maxdepth N` | 最多往下几层（**搜大目录时必加，否则很慢**） |
| `-size +10M` | 大于 10 MB |
| `-exec 命令 {} \;` | 对每个结果执行命令 |

**示例**

```bash
# 找 jailhouse 相关文件（限制深度，否则全盘扫描很慢）
find / -maxdepth 4 -iname "*jailhouse*" 2>/dev/null

# 找所有 .cell 文件
find /usr/share -type f -name "*.cell"

# 找大于 100 MB 的文件
find / -type f -size +100M -maxdepth 5 2>/dev/null
```

**`2>/dev/null` 的作用**：把"权限不足"的报错丢掉。搜 `/` 时不加会刷屏。

> ⚠️ **排查时不要随便加 `2>/dev/null`**——它会吞掉真正的错误。只在确认报错是权限问题时用。

### `od` —— 按各种进制看二进制

**英文全称**：octal dump

**作用**：把文件按**指定进制**显示。看文件头、判断格式（ELF？裸二进制？压缩？）时用。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-t x1` | 按十六进制，每字节 |
| `-t x4` | 按十六进制，每 4 字节 |
| `-t c` | 按字符 |
| `-A d` | 偏移用十进制显示 |
| `-N 字节数` | 只看前 N 字节 |
| `-v` | 不省略重复行 |

**示例：判断一个文件是什么格式**

```bash
$ head -c 16 jailhouse.bin | od -A d -t x1
0000000 7f 45 4c 46 ...        ← 7f 45 4c 46 = ELF 魔数

$ head -c 16 rt_latency.bin | od -A d -t x1
0000000 00 0d 00 58 ...        ← 不是 ELF，是裸机器码
```

**常见魔数**

| 开头字节 | 格式 |
|---|---|
| `7f 45 4c 46` | ELF（可执行文件） |
| `28 b5 2f fd` | Zstandard 压缩 |
| `1f 8b` | gzip |
| `fd 37 7a 58 5a 00` | xz |
| `50 4b 03 04` | ZIP |

### `base64` —— 编解码 base64

**英文全称**：base64（一种把二进制编码成 64 个可打印字符的编码方式）

**作用**：把二进制转成纯文本（或反过来）。**用途：通过只能传文本的通道（串口、剪贴板）传二进制。**

**核心选项**

| 选项 | 作用 |
|---|---|
| （不加） | 编码 |
| `-d` | 解码 |

**示例**

```bash
# 把板子上的二进制文件编码后打印出来（可以粘到别处）
base64 /usr/share/jailhouse/cells/imx95.cell

# 本地接收后解码
ssh root@<IP> 'base64 /path/to/file' | base64 -d > local.file
```

**代价**：编码后体积变成 **4/3**（每 3 字节变 4 字符）。

**什么时候用**：串口只能传文本、没有网络、没有 U 盘时。文件小（几百 KB 以内）才划算。

---

## 五、系统信息：确认环境和版本

### `uname` —— 看内核和系统信息

**英文全称**：unix name

**作用**：打印系统和内核的基本信息。

**核心选项**

| 选项 | 作用 |
|---|---|
| `-a` | 全部信息 |
| `-r` | **只要内核版本**（最常用） |
| `-m` | 机器架构（`aarch64` / `x86_64`） |
| `-n` | 主机名 |

**示例**

```bash
$ uname -a
Linux imx95evk 6.12.34-lts-next-g8055316b4d75 #1 SMP PREEMPT Fri Aug 8 12:01:10 UTC 2025 aarch64 GNU/Linux

$ uname -r
6.12.34-lts-next-g8055316b4d75
```

**怎么读 `uname -r`**：`6.12.34` 是版本号，`-lts-next` 是发行版分支，`-g8055316b4d75` 是构建时的 git 提交。**判断"是不是同一套系统"就比这个串。**

**为什么重要**：内核模块（`.ko`）和内核版本**必须匹配**。`modinfo` 里的路径会带内核版本，`uname -r` 一比对就知道对不对。

### `nproc` —— 看可用 CPU 核数

**英文全称**：number of processors

**作用**：打印当前进程可用的 CPU 核数。

**示例**

```bash
$ nproc
6                ← 正常启动
$ nproc
5                ← 有一个核被 Jailhouse 划走了
```

**本项目为什么用**：**`nproc` 从 6 变 5，是"CPU 被成功划给 inmate"最直观的证据。**

### `hostname` —— 看/改主机名

**英文全称**：host name

**作用**：打印或设置主机名。

**示例**

```bash
$ hostname
imx95evk                          ← 原厂 eMMC 系统
$ hostname
imx95-19x19-lpddr5-evk            ← RTE 系统
```

**本项目为什么用**：**主机名能一眼区分跑的是哪套系统**。

### `which` / `command -v` —— 找命令在哪

**英文全称**：which（哪一个）

**作用**：给定命令名，找出**实际会被执行的那个文件**的路径。

**两者区别**

| 命令 | 特点 |
|---|---|
| `which` | 查 PATH 里的可执行文件，输出路径 |
| `command -v` | **POSIX 标准**，还能识别别名和 shell 内建命令，更可靠 |

**示例**

```bash
$ which jailhouse
/usr/sbin/jailhouse

$ which harpoon_ctrl
/usr/bin/harpoon_ctrl

$ command -v zstd || echo "没装 zstd"
没装 zstd
```

**本项目为什么用**：确认工具在不在。`command -v X || echo "没有"` 是脚本里判断"命令是否可用"的标准写法。

---

## 六、服务与压缩

### `systemctl` —— 管理 systemd 服务

**英文全称**：system control

**作用**：启停、查看由 **systemd** 管理的服务（后台进程）。

**核心子命令**

| 子命令 | 作用 |
|---|---|
| `start 服务名` | 启动 |
| `stop 服务名` | 停止 |
| `restart 服务名` | 重启 |
| `status 服务名` | 看状态（**排查第一步**） |
| `enable 服务名` | 设为开机自启 |
| `disable 服务名` | 取消开机自启 |
| `list-units` | 列出所有单元 |

**示例**

```bash
# Harpoon 官方启动方式
harpoon_set_configuration.sh freertos latency    # 先生成 /etc/harpoon/harpoon.conf
systemctl start harpoon
systemctl status harpoon

# 看某个服务为什么失败
systemctl status weston.service
```

**串口上看到的 `[FAILED] Failed to start Weston`** 就是 systemd 报的。用 `systemctl status` 看详情。

**相邻**：`journalctl -u 服务名` 看该服务的日志。

### `zstd` / `tar` —— 压缩与解压

| 命令 | 英文全称 | 作用 |
|---|---|---|
| `zstd` | Zstandard | 高压缩比 + 高速度的压缩工具 |
| `tar` | tape archive | 把多个文件打包成一个（**打包，不压缩**） |

**核心选项**

| 命令 | 选项 | 作用 |
|---|---|---|
| `zstd` | `-d` | 解压 |
| | `-c` | 输出到标准输出（**配合管道用**） |
| | `-k` | 保留原文件 |
| | `-19` | 最高压缩级别（默认 3） |
| `tar` | `-c` | 创建归档 |
| | `-x` | 解压归档 |
| | `-f 文件` | 指定归档文件名 |
| | `-t` | 只列出内容不解压 |
| | `-z` / `-J` | 用 gzip / xz 压缩 |

**示例**

```bash
# 只解压不落盘，直接写设备
zstd -dc image.wic.zst | dd of=/dev/mmcblk1 bs=8M

# 解压到文件
zstd -d image.wic.zst

# 从归档里只抽几个文件
tar -xf rootfs.tar.zst ./usr/share/harpoon/ ./etc/harpoon/

# 只看归档里有什么
tar -tf rootfs.tar.zst | grep harpoon
```

**`-c` 为什么要加**：`zstd -d` 默认写文件，`zstd -dc` 输出到 stdout 才能接管道。

---

## 七、用 Python 直接访问物理内存（特殊手段）

**这不是标准命令，是一段脚本。** 用途：**验证某个物理地址能不能访问**。

**场景**：怀疑某个外设不归当前域管（被 TRDC/RDC 拦了），想快速验证，又不想翻配置文件。

**脚本**

```bash
python3 -c "
import mmap, os, struct
f = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
m = mmap.mmap(f, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, offset=<物理地址>)
print(hex(struct.unpack_from('<I', m, 0)[0]))
"
```

**怎么读结果**

| 结果 | 含义 |
|---|---|
| 打印出正常值，退出码 0 | ✅ **当前域能访问这个地址** |
| **SIGBUS**（退出码 135） | ❌ **当前域不能访问**——总线级拦截 |

**实测对比**（i.MX95 EVK，读 LPUART 寄存器）：

| 系统 | LPUART3（`0x42570000`） |
|---|---|
| 原厂 eMMC 系统 | ❌ SIGBUS，退出码 135 |
| RTE 系统 | ✅ `0x04040007`，退出码 0 |

**为什么能这么判断**：`mmap` 成功只说明映射建好了，**读的时候才真正发起总线访问**。访问被拦就触发总线错误，进程收到 SIGBUS 被杀死。

**前置条件**：`/dev/mem` 存在、有 root 权限、内核允许 `CONFIG_STRICT_DEVMEM` 之外的访问。

**相邻**：`busybox devmem <地址>` 更简单，但不是所有系统都有；内核 `dmesg` 里的 `sig=7` 就是这个 SIGBUS 的记录。

---

## 附：命令速查

| 想干什么 | 用什么 |
|---|---|
| 看有哪些存储设备、哪个是 eMMC 哪个是 SD | `lsblk` |
| 看某个目录是不是内存盘 | `df -h <目录>` |
| 挂载/卸载设备 | `mount` / `umount` |
| 写整盘镜像到 SD 卡 | `zstd -dc x.wic.zst \| dd of=/dev/sdX bs=8M` |
| 看板子 IP | `ip -br addr` |
| 板子网口没地址 | `ip link set eth0 up` |
| 传文件到板子 | `scp file root@<IP>:/tmp/` |
| 串口被抢了还能操作板子 | `ssh root@<IP>` |
| 看内核报错 | `dmesg` |
| 看模块版本 | `modinfo <模块>` |
| 搜设备/固件里的字符串 | `grep -aoE "..." /dev/xxx` |
| 判断文件格式 | `head -c 16 f \| od -A d -t x1` |
| 看内核命令行 | `cat /proc/cmdline` |
| 确认内核版本 | `uname -r` |
| 确认核数有没有变 | `nproc` |
| 验证某个外设归不归当前域 | Python + `/dev/mem` |

---

## 相关

- 命令背后的原理 → [[20-领域/Linux/嵌入式Linux.md|嵌入式Linux]]
- 内核机制 → [[20-领域/Linux/Linux内核.md|Linux内核]]
- 本项目实际用到这些命令的现场记录 → [[10-项目/IMX95-EVK/开发日志.md|IMX95-EVK 开发日志]]
