---
type: 知识库
scope: Linux
doc_type: 原理
status: 已整理
evidence: 教材课程
tags: [Android, Linux, 启动, 驱动]
updated: 2026-09-18
---

# Android 系统架构

> 一句话：Android = **Linux 内核 + 一套自己的用户空间**。它用 Linux 管硬件，但不用 Linux 的那套用户世界（glibc/init/工具链全换了）。

## 一、分层架构（从上到下）

```text
┌──────────────────────────────────────────────┐
│ 应用层  Launcher / 电话 / 短信 / 你的 App (.apk) │
├──────────────────────────────────────────────┤
│ Java API Framework                             │
│   ActivityManager(WMS/PMS) / Content Providers │
│   View System / Resource Manager / Notification│
├──────────────────────────────────────────────┤
│ 系统服务 + Runtime                              │
│   Native 服务：SurfaceFlinger / AudioFlinger   │
│   ART 虚拟机（dex 字节码 → 机器码）              │
│   Core Libraries（Java 标准库的 Android 实现）  │
├──────────────────────────────────────────────┤
│ HAL 硬件抽象层（用户空间）                        │
│   Camera HAL / Audio HAL / Sensors HAL ...     │
│   （老版本 so+函数表 → 新版本 HIDL/AIDL 接口）    │
├──────────────────────────────────────────────┤
│ Linux 内核                                     │
│   进程/内存/电源管理 · Binder驱动 · 显示/摄像头   │
│   驱动 · IPC(binder/ashmem)                     │
└──────────────────────────────────────────────┘
```

**层间怎么通信**（这是面试重点）：

- App 调 Framework API（如 `getSystemService()`）→ Framework 服务通过 **Binder IPC** 跨进程到 Native 服务 → Native 调 **HAL** 接口 → HAL 通过 **系统调用** 进内核 → 内核驱动控制 I2C/SPI 等硬件总线。
- **HAL 在用户空间**，作用是"隔离芯片差异"：高通/联发科的相机实现不同，但 HAL 接口统一，上层 Framework 不用关心。
- HAL 实现的演进：早期是 `.so` 动态库 + 函数表（legacy HAL）→ 现代 HIDL/AIDL 接口描述（Binderized HAL 可独立进程）。

## 二、Android 是 Linux 吗？（关键辨析）

**内核是 Linux，但不是标准 GNU/Linux 发行版。** 三处根本差异：

| 组件 | 标准 Linux | Android | 为什么 |
|---|---|---|---|
| C 库 | glibc | **Bionic**（自己写的 libc） | 体积小、启动快、授权（BSD 而非 LGPL） |
| init | SysVinit / systemd | **/init + init.rc**（自有解析器） | 要管理的是"服务+Zygote"，不是 shell 会话 |
| 驱动 | 标准 Linux 驱动 | 加了 **Binder/ashmem/low memory killer** 等专用驱动 | 进程隔离和内存回收按 App 生命周期设计 |

> 面试表述："Android 基于 Linux 内核（用它做进程/内存/电源/驱动模型），但在用户空间自成体系——
> 没有 glibc 也没有 systemd。所以它不是通常意义的 Linux 发行版。"

## 三、启动流程（链式过程）

```text
上电 → Boot ROM → Bootloader(U-Boot/aboot)
    → Linux 内核初始化（驱动、挂载 rootfs）
    → 启动第一个用户进程 /init
        → 解析 init.rc，启动守护服务（vold/netd/logd...）
        → 启动 Zygote（预加载 Framework 常用类与资源）
    → Zygote fork 出 SystemServer
        → 启动 AMS / WMS / PMS 等核心服务
    → AMS 启动 Launcher（桌面）
    → 用户点图标 → Zygote fork 出该 App 进程（共享已加载资源）
```

**为什么要有 Zygote？**——App 进程不从头加载 Framework，而是 **fork 自 Zygote**：
预加载的类和资源通过写时复制（COW）共享，启动快、省内存。这是 Android 启动设计的核心巧思。

**App 进程里跑什么？** 每个 App 一个**独立的 ART 虚拟机实例**（所以"进程隔离"由内核保证），
App 崩溃不影响其他 App——这就是为什么 Android 能"杀后台"而系统不死。

## 四、驱动在 Android 里怎么暴露（与标准 Linux 相同 + 特殊点）

- 标准 Linux 方式：驱动注册字符设备 → `/dev/xxx` → 用户态 `open/read/write/ioctl`；或 sysfs 节点配置参数。
- Android 特有：
  - **Binder**（`/dev/binder`）：进程间通信主力，Framework 层无处不在；
  - **ashmem**：匿名共享内存；
  - **Low Memory Killer**：按 App 优先级杀进程回收内存（标准 OOM killer 不懂"前后台"）；
  - **wakelocks**：电源管理锁（标准内核后来吸收了 wakeup_source）。

## 五、面试高频追问

- **Android 和 Linux 的关系？** 内核是 Linux（改过），用户空间自研（Bionic/init/ART），不是 GNU/Linux。
- **App 之间怎么通信？** Binder（Framework 层表现为 AIDL 接口）；Binder 是 Android 特有驱动，基于内存映射一次拷贝。
- **为什么 App 崩溃系统不死？** 每个App独立进程+独立 ART 实例，内核进程隔离保证。
- **Zygote 为什么快？** fork + 写时复制，共享预加载资源。
- **HAL 为什么放用户空间？** 隔离芯片厂商差异、便于二进制兼容、避免 GPL 传染到厂商闭源驱动。

## 来源

- 分层架构（应用层/Framework/Native+Runtime/HAL/内核）与 Binder/JNI/HAL 通信链路整理自
  [Android 官方平台架构文档](https://developer.android.google.cn/guide/platform)（AOSP source.android.com 的 Architecture 章节同源）
- 启动流程（Bootloader→init→Zygote→SystemServer→Launcher）整理自原笔记 +
  [《图解 Android 系统的启动》- 腾讯云开发者社区](https://cloud.tencent.cn/developer/article/1734269)
- "Android 不是标准 GNU/Linux"三处差异（Bionic/init.rc/专用驱动）为整理时的辨析补充，
  依据为 AOSP 文档对 Bionic 与 init 的描述
- 原笔记自带的 HAL 演进（函数表→HIDL/AIDL）、驱动 `/dev/xxx` 访问方式保留

## 相关

**同目录**

- [[20-领域/Linux/Linux内核.md|Linux内核]]
- [[20-领域/Linux/嵌入式Linux.md|嵌入式Linux]]

**导航**：[[20-领域/Linux/README.md|Linux]]
