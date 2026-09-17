---
type: 项目档案
scope: FRDM-IMX95-PRO
doc_type: 未分类
status: 待整理
evidence: 待标注
tags: []
updated: 2026-09-17
---

# 汇报主链：FreeRTOS 从选板到上板验证

> 用途：口述提纲。照着节点讲，节点之间补一句因果。
> 标记说明：带【核心】的节点是重点，展开讲；其余节点一句话带过。
> 两个核心的详细讲解见《汇报稿-FreeRTOS上板历程-知识梳理.md》第六节和第七节。

```text
官网找资料：按快速入门启动 A55 Linux，确认板子正常；下载原理图、引脚图
|
|
登录 Linux 看板载固件：FreeRTOS 的 bin/elf 都是 m7_TCM，以为 FreeRTOS 跑在 M7
|
|
找烧录方法：remoteproc 失败（lmm 不归 Linux 控制）；U-Boot 搬 TCM 失败（无写权限）；JTAG/SWD 只有焊点、无 J-Link；改用 USB+UUU
|
|
下 SDK（无 Pro 版，用 i.MX95 19x19）：IAR 编译 FreeRTOS 示例，得到 M7 的 bin
|
|
发现 bin 不能直接烧：Boot ROM 要的是启动容器，要有核心和装载地址
|
|
拆原厂启动镜像：ELE、V2X、DDR 初始化、M33 SM、SPL、BL31、U-Boot、TEE、Quick Boot
|
|
组装 flash.bin：WSL 里用 imx-mkimage；SM 用 Arm GNU 14.2.rel1，M7 用 IAR
|
|
uuu 烧录，反复调整：ELE 版本、Quick Boot、64KB 保留区、USB 重试，最后看到 hello world
|
|
测串口：LPUART7 到 COM18，打印和回显正常
|
|
测 GPIO：IO14 输出有方波，IO15 输入回接后同步
|
|
【核心一】GPIO 三层初始化：第一层 IOMUXC 引脚复用，第二层 SM 配置加 TRDC 所有权和访问权，第三层 RGPIO 方向和读写。三层缺一不可
|
|
GPIO 无权限怎么改：GPIO2 默认归 A55，把 M33 的 SM 配置里 GPIO2 OWNER 给 M7，同时保留 A55 的 ACCESS 和 API；整块拿走会让 A55 看门狗复位
|
|
掉电保持：USB 只到 RAM，改用 SD 卡；新问题 BL31 把 PCNS/PCNP 全置 1，M7 读写失效，最后 M7 按位夺回
|
|
【核心二】权限隔离主链：SM 管电源时钟复位引脚和各核；LM0/1/2 是逻辑机；LMM 管逻辑机生命周期；TRDC 按域 ID 判访问；SCMI 走 MU 申请服务；主链是 Boot ROM、ELE、DDR、SM，再拉 M7 和 A55
|
|
实时性理解：规定时间内完成，分硬实时和软实时，不能只看平均，要看抖动和最坏情况
|
|
实时性初测：DWT 周期计数器，500 毫秒任务，看周期抖动和执行时间，很稳；但先做多任务再测更真实
|
|
LED 任务：IO14 输出，500 毫秒翻转，翻转完阻塞
|
|
抢占实验：两个 LED 两个优先级，高优先级忙等占 CPU，低优先级到点拿不到 CPU，间隔变大，证明抢占
|
|
FreeRTOS 理解：抢占式固定优先级；任务创建代替裸机标志位；队列是生产者消费者；还有信号量和互斥量
```

## 讲的时候重点展开两个核心

- **核心一，GPIO 三层初始化**：IOMUXC、SM 配置加 TRDC、RGPIO。主讲三层各管什么，缺一层会怎样，PCNS 和 PCNP 的坑怎么来的怎么解。
- **核心二，权限隔离主链**：SM、LMM、TRDC、SCMI。主讲为什么需要隔离，每个角色管什么，主链怎么串起来，M7 用外设要过哪两道关。
