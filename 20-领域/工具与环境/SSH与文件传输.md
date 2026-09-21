---
type: 知识库
scope: 工具与环境
doc_type: 怎么做
status: 已整理
evidence: 源码确认
tags: [启动, 文件系统, 多核与异构]
updated: 2026-09-17
---

# SSH、SCP与SFTP使用

## 一、三个工具的关系

SSH、SCP 和 SFTP 都建立在 SSH 协议之上，区别在于用途不同。

| 工具 | 主要用途 | 当前使用场景 |
|---|---|---|
| SSH | 远程登录并执行命令 | 登录 i.MX95 的 Linux |
| SCP | 在本地和远程主机之间复制文件 | 从开发板取出 M7 固件 |
| SFTP | 通过 SSH 进行交互式文件管理 | 在 MobaXterm 中浏览和下载文件 |

三者都需要远程主机开启 SSH 服务，并通过用户名、密码或密钥完成身份验证。SSH 负责建立加密连接，SCP 和 SFTP 在这个连接中传输文件。

## 二、SSH的工作原理

SSH 是 Secure Shell 的缩写，用于在不可信网络上安全访问远程Linux。连接过程大致分为：

1. 电脑通过网卡连接开发板的IP地址和22端口。
2. 开发板上的 SSH 服务端返回主机身份信息。
3. 电脑验证主机密钥，确认连接对象。
4. 双方协商加密算法并建立加密通道。
5. 用户输入用户名和密码，或使用密钥完成登录认证。
6. 认证通过后，开发板启动一个远程Shell，电脑输入的命令在开发板Linux中执行。

SSH连接成功后，命令行中的`root@imx95-19x19-lpddr5-frdm-pro`表示当前Shell运行在开发板上，不是在Windows本地运行。

常用命令：

```powershell
ssh root@192.168.50.2
```

如果使用IPv6链路本地地址，需要带网卡接口编号：

```powershell
ssh root@'fe80::204:9fff:fe0b:4261%12'
```

其中`%12`表示使用Windows中编号为12的网卡。`fe80::`地址只在当前局域网链路有效，不能脱离这张网卡单独使用。

退出远程Shell：

```sh
exit
```

## 三、SCP的工作原理

SCP 是 Secure Copy 的缩写，用于复制文件。它不是串口传输，也不是烧录工具，只是把文件从一个文件系统复制到另一个文件系统。

例如从开发板复制文件到电脑：

```powershell
scp root@192.168.50.2:/lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.elf F:\project\Learning\RTOS\board_firmware\
```

命令结构：

```text
scp 用户名@远程地址:远程文件路径 本地目标路径
```

复制BIN文件：

```powershell
scp root@192.168.50.2:/lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.bin F:\project\Learning\RTOS\board_firmware\
```

使用IPv6时：

```powershell
scp 'root@fe80::204:9fff:fe0b:4261%12:/lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.bin' 'F:\project\Learning\RTOS\board_firmware\'
```

复制前要注意：

- 远程路径是开发板Linux中的路径。
- 本地路径是Windows中的路径。
- 路径中有特殊字符时使用单引号。
- 目标目录需要提前存在。
- SCP成功只表示文件传输成功，不表示固件已经运行或已经烧录。

复制后在Windows检查哈希：

```powershell
Get-FileHash 'F:\project\Learning\RTOS\board_firmware\imx95-19x19-evk_m7_TCM_hello_world.bin' -Algorithm SHA256
```

也可以在开发板上检查：

```sh
sha256sum /lib/firmware/imx95-19x19-evk_m7_TCM_hello_world.bin
```

两边哈希相同，才能确认传输过程中内容没有变化。

## 四、SFTP的工作原理

SFTP 是 SSH File Transfer Protocol 的缩写，是基于 SSH 的文件传输协议。它支持查看远程目录、上传、下载、创建目录和删除文件等操作。

在MobaXterm中建立SSH会话并登录后，左侧的文件窗口通常就是SFTP窗口。进入：

```text
/lib/firmware
```

将文件拖到电脑目录，就相当于执行了一次SFTP下载。SFTP的优点是可以直观看到目录和文件，不需要手动输入完整路径；缺点是批量操作和重复操作不如命令行方便。

命令行也可以进入SFTP：

```powershell
sftp root@192.168.50.2
```

常用SFTP命令：

```text
pwd                 查看远程当前目录
lpwd                查看本地当前目录
ls                  查看远程目录
lls                 查看本地目录
cd /lib/firmware    切换远程目录
lcd F:\temp         切换本地目录
get 文件名          下载文件
put 文件名          上传文件
exit                退出SFTP
```

## 五、网线直连开发板

电脑和开发板可以用网线直接连接，不需要路由器。开发板执行：

```sh
ip link set eth0 up
ip addr add 192.168.50.2/24 dev eth0
ip -br addr show eth0
```

Windows连接开发板的以太网适配器设置为：

```text
IP地址：192.168.50.1
子网掩码：255.255.255.0
默认网关：不填写
```

之后测试：

```powershell
ping 192.168.50.2
ssh root@192.168.50.2
```

本次实际使用的是IPv6链路本地地址：

```text
fe80::204:9fff:fe0b:4261
```

能够Ping通并通过SSH登录，说明网线、网卡和Linux网络协议已经正常。网络连接只解决文件访问和远程登录，不能代替J7的USB下载，也不能代替JTAG调试器。

## 六、SSH文件操作与烧写的区别

通过SSH、SCP或SFTP复制一个`.elf`或`.bin`，只是改变了文件所在位置：

```text
电脑文件系统 <-> Linux文件系统
```

它不会自动让M7执行，也不会修改eMMC启动区域。M7是否运行，还需要remoteproc、U-Boot或启动容器负责加载和启动。文件是否写入eMMC或SD卡，则需要使用对应的烧写命令。

当前板载文件的正确理解是：

- `/lib/firmware`中的文件是Linux文件系统里的M7固件资源。
- `remoteproc`可以读取其中的ELF并尝试启动M7。
- BIN可以作为启动容器中的M7镜像。
- SCP和SFTP只能把文件取出或放入，不能完成M7启动流程。

## 七、本次实际结果

当前已通过网线直连开发板，取得IPv6地址并完成Ping测试，也已经能够通过MobaXterm和PowerShell的SSH登录板载Linux。板载`/lib/firmware`中存在多组19x19平台M7固件，其中`rpmsg_lite_pingpong_rtos_linux_remote`和`rpmsg_lite_str_echo_rtos`包含FreeRTOS任务、队列和调度器相关符号，属于后续验证FreeRTOS的重点文件。

下一步应优先保存这两组官方ELF和BIN，再尝试通过remoteproc加载官方FreeRTOS ELF。若仍然因为`lmm(1) not under Linux Control`失败，再把官方BIN放入匹配的启动容器，通过J7和UUU进行启动验证。

---

scp虚拟机的项目传到开发板上，发现文件内容有些损坏：部分代码变成{},很多地方出现{}，原因是**源文件是在 Windows 环境下创建或编辑的**，然后通过 `scp` 二进制传输到 Linux，行尾符原封不动地过来了。
设置vim的format为unix就可以解决
set ff=unix
- **移除**了所有 Windows 行尾符 `\r\n` (CR+LF)
    
- **转换**为 Unix 行尾符 `\n` (LF)
    
- **一次性修复**了整个文件
