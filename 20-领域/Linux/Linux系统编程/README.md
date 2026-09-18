---
type: 索引
scope: Linux
doc_type: 教程
status: 已整理
evidence: 不适用
tags: [索引, 导航, Linux]
updated: 2026-09-18
---

# Linux 系统编程 导览

> 一句话：这一片回答「用户态程序怎么用 fork/线程/socket/信号/内存 干活」。

## 建议阅读顺序

1. 先 [[20-领域/Linux/Linux系统编程/Linux基础与开发环境.md|Linux基础与开发环境]] —— 环境变量、Shell、gcc/Makefile/GDB，**工欲善事先利其器**。
2. 再看 [[20-领域/Linux/Linux系统编程/进程控制.md|进程控制]] —— 进程/线程是后面一切的载体。
3. [[20-领域/Linux/Linux系统编程/多线程编程.md|多线程编程]] —— 并发、同步、线程池、死锁。
4. [[20-领域/Linux/Linux系统编程/网络编程.md|网络编程]] —— socket、TCP/UDP、IO 多路复用。
5. [[20-领域/Linux/Linux系统编程/内存管理.md|内存管理]] 与 [[20-领域/Linux/Linux系统编程/文件与文件系统.md|文件与文件系统]] —— 资源和数据从哪来。
6. 最后 [[20-领域/Linux/Linux系统编程/系统调用.md|系统调用]] 和 [[20-领域/Linux/Linux系统编程/信号处理.md|信号处理]] 收尾——它们是"进内核的门"和"异步通知"。

## 笔记地图（要点）

- [[20-领域/Linux/Linux系统编程/进程控制.md|进程控制]] —— fork/exec/wait、进程状态、IPC。
- [[20-领域/Linux/Linux系统编程/多线程编程.md|多线程编程]] —— pthread、互斥/条件变量、线程池、死锁。
- [[20-领域/Linux/Linux系统编程/网络编程.md|网络编程]] —— TCP/IP、socket、select/poll/epoll。（篇幅最大，96 KB）
- [[20-领域/Linux/Linux系统编程/内存管理.md|内存管理]] —— 虚拟内存、brk/mmap、内存分布。
- [[20-领域/Linux/Linux系统编程/文件与文件系统.md|文件与文件系统]] —— 根文件系统、inode、文件操作。
- [[20-领域/Linux/Linux系统编程/系统调用.md|系统调用]] —— 用户态进内核的门。
- [[20-领域/Linux/Linux系统编程/信号处理.md|信号处理]] —— 异步事件通知。
- [[20-领域/Linux/Linux系统编程/Linux基础与开发环境.md|Linux基础与开发环境]] —— 环境/工具链/命令。

## 相邻主题

- 内核长什么样 → [[20-领域/Linux/Linux内核.md|Linux内核]]
- 这些概念的底层原理 → [[20-领域/计算机系统/操作系统.md|操作系统]]
