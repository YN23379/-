---
type: 项目档案
scope: i.MX95 19x19 LPDDR5 EVK（IMX95LPD5EVK-19）
doc_type: 参考
status: 已完成
evidence: 实机验证
tags: [Harpoon, Jailhouse, 多核与异构, 实时性]
updated: 2026-09-22
---

# rt_latency 原始日志（TC 1–6）

> 本文是 [[10-项目/IMX95-EVK/开发日志.md|开发日志]] 的附录，只放原始输出，分析见开发日志。
> 板子：i.MX95 19x19 LPDDR5 EVK，RTE 3.3 系统（SD 卡），harpoon v3.5.0。
> 环境：`harpoon_set_configuration.sh freertos latency` + `systemctl start harpoon`，
> 依次执行 `harpoon_ctrl latency -r 1` 到 `-r 6`。
> Linux 侧串口是 COM7，inmate 控制台是 **COM9**（下面全部是 COM9 的输出）。

---

## TC 1：无额外负载

```text
INFO main_task             : Harpoon v3.5.0
INFO main_task             : running
INFO rpmsg_init            : RPMSG init ...
INFO rpmsg_init            : RPMSG link up
INFO start_test_case       : ---
INFO start_test_case       : Running test case 1:
INFO benchmark_task        : running
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 791 max 1541 rms^2 626923 stddev^2 227 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 99866 134 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2045 max 3958 rms^2 4187075 stddev^2 4039 absmin 2000 absmax 3958
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 99884 116 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 791 max 1500 rms^2 626986 stddev^2 217 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 199737 263 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2044 max 4125 rms^2 4185584 stddev^2 3917 absmin 2000 absmax 4125
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 199768 230 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 791 max 1500 rms^2 627074 stddev^2 224 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 224371 297 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2045 max 3958 rms^2 4186337 stddev^2 3926 absmin 2000 absmax 4125
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 224404 262 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
```

（第三个窗口只有 224,668 个样本 ≈ 2.47 秒，因为紧接着执行了 `harpoon_ctrl latency -s`。）

---

## TC 2：CPU 负载

```text
INFO start_test_case       : Running test case 2:
INFO benchmark_task        : running
INFO cpu_load_task         : running
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1541 rms^2 627602 stddev^2 179 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 75247 85 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 3916 rms^2 4105640 stddev^2 3245 absmin 2000 absmax 3916
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 75291 41 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1541 rms^2 627689 stddev^2 193 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 175140 192 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4291 rms^2 4106660 stddev^2 3536 absmin 2000 absmax 4291
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 175228 103 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1500 rms^2 627544 stddev^2 155 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 235068 253 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4291 rms^2 4107081 stddev^2 3628 absmin 2000 absmax 4291
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 235179 139 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO start_test_case       : ---
```

---

## TC 3：IRQ 负载

```text
INFO start_test_case       : Running test case 3:
INFO benchmark_task        : running (with IRQ load)
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 791 mean 909 max 1666 rms^2 827127 stddev^2 432 absmin 791 absmax 1666
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 39967 44 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 8666 mean 9215 max 10041 rms^2 84923815 stddev^2 7037 absmin 8666 absmax 10041
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 0 0 0 0 0 0 117 39893 1 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 791 mean 908 max 1625 rms^2 826180 stddev^2 370 absmin 791 absmax 1666
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 139896 115 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 6750 mean 9214 max 10916 rms^2 84918837 stddev^2 7152 absmin 6750 absmax 10916
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 0 0 0 0 1 1 403 139599 7 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 791 mean 909 max 4125 rms^2 827013 stddev^2 613 absmin 791 absmax 4125
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 185341 157 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 6958 mean 9214 max 11000 rms^2 84916008 stddev^2 7380 absmin 6750 absmax 11000
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 0 0 0 0 2 2 546 184937 11 1 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
```

---

## TC 4：CPU + 信号量负载

```text
INFO start_test_case       : Running test case 4:
INFO benchmark_task        : running
INFO cpu_load_task         : running (with extra semaphore load)
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 791 max 1500 rms^2 626800 stddev^2 179 absmin 541 absmax 1500
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 54439 73 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2045 max 4041 rms^2 4187092 stddev^2 3979 absmin 2000 absmax 4041
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 54444 67 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 791 max 1541 rms^2 626871 stddev^2 206 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 154308 204 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2045 max 4166 rms^2 4186951 stddev^2 3989 absmin 2000 absmax 4166
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 154331 178 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 625 mean 791 max 1333 rms^2 626960 stddev^2 131 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 160546 208 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2045 max 3708 rms^2 4186635 stddev^2 3668 absmin 2000 absmax 4166
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 160567 184 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
```

---

## TC 5：CPU + Linux 负载

> **注意**：这个用例**不会自己加 Linux 负载**，需要手动在 Linux 侧另外压。
> 本次没有压，所以数据实际等同于 TC2。

```text
INFO start_test_case       : Running test case 5:
WARN rt_latency_init       : Linux load must be run manually!
INFO benchmark_task        : running
INFO cpu_load_task         : running
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1541 rms^2 627615 stddev^2 162 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 93667 91 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4333 rms^2 4106400 stddev^2 3398 absmin 2000 absmax 4333
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 93707 50 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1458 rms^2 627478 stddev^2 156 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 160601 153 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4333 rms^2 4106643 stddev^2 3474 absmin 2000 absmax 4333
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 160662 90 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
```

---

## TC 6：CPU + cache flush

> **注意**：harpoon v3.5.0 只刷 I-Cache，**D-Cache 刷新还是 TODO 没实现**。
> 所以这个用例实际测的是"CPU 负载 + 只刷 I-Cache"。

```text
INFO start_test_case       : Running test case 6:
INFO benchmark_task        : running
INFO cache_inval_task      : running
WARNING:  TODO: Flush D-Cache
INFO cpu_load_task         : running
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 541 mean 792 max 1541 rms^2 627587 stddev^2 179 absmin 541 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 32963 41 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4000 rms^2 4106525 stddev^2 3439 absmin 2000 absmax 4000
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 0 32981 22 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1541 rms^2 628113 stddev^2 215 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 132829 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 1958 mean 2026 max 4250 rms^2 4108930 stddev^2 3781 absmin 1958 absmax 4250
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 1 132910 90 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
INFO rtos_apps_stats_print : stats(F0762308) irq delay (ns) min 500 mean 792 max 1541 rms^2 627971 stddev^2 201 absmin 500 absmax 1541
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 232701 303 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO rtos_apps_stats_print : stats(F0762500) irq to sched (ns) min 2000 mean 2025 max 4291 rms^2 4107522 stddev^2 3544 absmin 1958 absmax 4291
INFO rtos_apps_hist_print  : n_slot 20 slot_size 1000
INFO rtos_apps_hist_print  : 0 1 232846 151 6 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
INFO print_stats           : late alarm scheduling: 0
INFO print_stats           :
```

---

## 附：harpoon_ctrl 完整用法

`harpoon_ctrl -h` 的原始输出：

```text
Usage:
harpoon_ctrl [audio|latency|pipeline|element|routing|can|ethernet] [options]

Options:

Audio options:
        -f <frequency> audio clock frequency (in Hz)
                       imx8m{n,m,p}: supporting 44100, 48000, 88200, 96000, 176400, 192000 Hz
                       imx93: supporting 48000, 96000 Hz
                              supporting 48000, 96000, 192000 Hz using MX93AUD-HAT
                       Will use default frequency 48000Hz if not specified
        -p <frames>    audio processing period (in frames)
                       Supporting 2, 4, 8, 16, 32 frames
                       Supporting 2, 4, 8 frames on MX93AUD-HAT
                       Will use default period 8 frames if not specified
        -a <mac_addr>  set hardware MAC address (default 00:bb:cc:dd:ee:14)
        -r <id>        run audio mode id:
                       0 - dtmf playback
                       1 - sine wave playback
                       2 - playback & recording (loopback)
                       3 - audio pipeline
                       4 - AVB audio pipeline
                       5 - SMP audio pipeline on imx8m{n,m,p}
                       6 - AVB audio pipeline (with MCR support) only on i.mx8mp
                       7 - SMP + AVB audio pipeline on imx8m{n,m,p}
                       8 - SMP + AVB audio pipeline (with MCR support) only on i.mx8mp
        -H             select the MX93AUD-HAT extension audio board. Only on i.mx93
        -s             stop running audio mode

Latency options:
        -r <id>        run latency test case id
        -q             quiet testing (Do not dump stats regularly, but only once on test case stop)
        -s             stop running test case

Audio pipeline options:
        -a <pipeline_id>  audio pipeline id (default 0)
        -d                audio pipeline dump

Audio element options:
        -a <pipeline_id>  audio pipeline id (default 0)
        -d                audio element dump
        -e <element_id>   audio element id (default 0)
        -t <element_type> audio element type (default 0):
                          0 - dtmf source
                          1 - routing
                          2 - sai sink
                          3 - sai source
                          4 - sine source
                          5 - avtp source
                          6 - avtp sink

Routing audio element options:
        -a <pipeline_id>  audio pipeline id (default 0)
        -c                connect routing input/output
        -d                disconnect routing input/output
        -e <element_id>   routing element id (default 0)
        -i <input_id>     routing element input  (default 0)
        -o <output_id>    routing element output (default 0)

Industrial CAN options:
        -r <id>        run CAN mode id:
                       0 - Multiple Nodes and Messages Tx+Rx on the imx8mp and the imx93}
        -n <node_type> acting as node 'A' or 'B' (default 'A')
                       0 - node 'A'
                       1 - node 'B'
        -o <protocol>  use CAN or CAN FD (default '0')
                       0 - use CAN
                       1 - use CAN FD
        -s             stop CAN

Industrial ethernet options:
        -a <mac_addr>  set hardware MAC address (default 00:bb:cc:dd:ee:14)
        -p <period_ns> set processing period in ns (default 100000)
        -r <id>        run ethernet mode id:
                       0 - genAVB/TSN stack with TSN application
                       1 - mcux-sdk API:
                            imx8m{m,n}:    ENET on Zephyr and FreeRTOS
                            imx8mp, imx93: ENET_QoS on Zephyr
                       2 - mcux-sdk API with PHY loopback mode:
                            imx8mp, imx93: ENET_QoS on Zephyr
        -m <app_mode>  for genAVB/TSN: app mode (default 'NETWORK_ONLY', if not specified)
                       0 - mode is 'MOTOR_NETWORK'
                       2 - mode is 'NETWORK_ONLY'
        -i <role>      for genAVB/TSN: endpoint role (default 'controller', if not specified)
                       0 - role is 'IO device 0'
                       1 - role is 'IO device 1'
        -n <n_io_dev>  for NETWORK_ONLY and MOTOR_NETWORK app modes: number of connected io_devices (default is '1' if not specified. Max is '2')
                           max of two enpoints supported
        -c <ctrl_st>   for genAVB/TSN motor control: control strategy to be utilized (default is '0' if not specified)
                       0 - SYNCHRONIZED
                       1 - FOLLOW
                       2 - HOLD_INDEX
                       3 - INTERLACED
                       4 - STOP
                       5 - IDENTIFY
        -s             stop ethernet

Common options:
        -v             print version
```

## 附：`systemctl start harpoon` 的完整启动日志

```text
Initializing Jailhouse hypervisor v0.12 (388-gf64de0b8-dirty) on CPU 4
Code location: 0x0000ffffc0200800
Page pool usage after early setup: mem 71/993, remap 0/131072
Initializing processors:
 CPU 4... OK
 CPU 5... OK
 CPU 3... OK
 CPU 1... OK
 CPU 2... OK
 CPU 0... OK
Initializing unit: irqchip
Initializing unit: ARM SMMU v3
Initializing unit: ARM SMMU
Initializing unit: PVU IOMMU
Initializing unit: PCI
Adding virtual PCI device 00:00.0 to cell "imx95"
Adding virtual PCI device 00:01.0 to cell "imx95"
Adding virtual PCI device 00:02.0 to cell "imx95"
Adding virtual PCI device 00:03.0 to cell "imx95"
Page pool usage after late setup: mem 125/993, remap 208/131072
Activating hypervisor
[   35.677881] pci-host-generic ff700000.pci: host bridge /pci@0 ranges:
[   35.677905] pci-host-generic ff700000.pci:      MEM 0x00ff800000..0x00ff807fff -> 0x00ff800000
[   35.677972] pci-host-generic ff700000.pci: ECAM at [mem 0xff700000-0xff7fffff] for [bus 00]
[   35.678134] pci-host-generic ff700000.pci: PCI host bridge to bus 0004:00
[   35.678146] pci_bus 0004:00: root bus resource [bus 00]
[   35.678151] pci_bus 0004:00: root bus resource [mem 0xff800000-0xff807fff]
[   35.678183] pci 0004:00:00.0: [110a:4106] type 00 class 0xff0000 conventional PCI endpoint
[   35.678203] pci 0004:00:00.0: BAR 0 [mem 0x00000000-0x00000fff]
[   35.678575] pci 0004:00:01.0: [110a:4106] type 00 class 0xff0001 conventional PCI endpoint
[   35.678599] pci 0004:00:01.0: BAR 0 [mem 0x00000000-0x00000fff]
[   35.679135] pci 0004:00:02.0: [110a:4106] type 00 class 0xffc002 conventional PCI endpoint
[   35.679158] pci 0004:00:02.0: BAR 0 [mem 0x00000000-0x00000fff]
[   35.679583] pci 0004:00:03.0: [110a:4106] type 00 class 0xffc003 conventional PCI endpoint
Adding virtual PCI device 00:00.0 to cell "freertos"
Shared memory connection established, peer cells:
 "imx95"
Created cell "freertos"
Page pool usage after cell creation: mem 148/993, remap 208/131072
[   35.679608] pci 0004:00:03.0: BAR 0 [mem 0x00000000-0x00Cell "freertos" can be loaded
000fff]
[   35.681884] pci 0004:Started cell "freertos"
00:00.0: BAR 0 [mem 0xff800000-0xff800fff]: assigned
[   35.681904] pci 0004:00:01.0: BAR 0 [mem 0xff801000-0xff801fff]: assigned
[   35.681913] pci 0004:00:02.0: BAR 0 [mem 0xff802000-0xff802fff]: assigned
[   35.681921] pci 0004:00:03.0: BAR 0 [mem 0xff803000-0xff803fff]: assigned
[   35.681931] pci_bus 0004:00: resource 4 [mem 0xff800000-0xff807fff]
[   35.682582] uio_ivshmem 0004:00:00.0: enabling device (0000 -> 0002)
[   35.682656] uio_ivshmem 0004:00:00.0: state_table at 0x00000000ff9f0000, size 0x0000000000001000
[   35.682667] uio_ivshmem 0004:00:00.0: rw_section at 0x00000000ff9f1000, size 0x0000000000009000
[   35.682676] uio_ivshmem 0004:00:00.0: input_sections at 0x00000000ff9fa000, size 0x0000000000006000
[   35.682682] uio_ivshmem 0004:00:00.0: output_section at 0x00000000ff9fa000, size 0x0000000000002000
[   35.683993] ivshmem-net 0004:00:01.0: enabling device (0000 -> 0002)
[   35.684112] ivshmem-net 0004:00:01.0: TX memory at 0x00000000ffa01000, size 0x000000000007f000
[   35.684120] ivshmem-net 0004:00:01.0: RX memory at 0x00000000ffa80000, size 0x000000000007f000
[   35.692972] The Jailhouse is opening.
[   35.771889] psci: CPU5 killed (polled 0 ms)
[   35.791513] Created Jailhouse cell "freertos"
[   36.312348] imx-rpmsg c0100000.rpmsg-ca55: assigned reserved memory node vdevbuffer-ca55@c0200000
[   36.313288] virtio_rpmsg_bus virtio0: rpmsg host is online
[   36.313313] virtio_rpmsg_bus virtio0: creating channel rpmsg-raw addr 0x1e
```

> **注意**：日志里 `Cell "freertos" can be loaded` 和 `Started cell "freertos"` 这两行
> 被内核的 PCI 打印**穿插打断了**（`pci 0004:00:03.0: BAR 0 ...` 插在中间），
> 这是串口上两个输出流交织的结果，不是真的出错。

## 相关

- [[10-项目/IMX95-EVK/开发日志.md|IMX95-EVK 开发日志]] —— 数据分析和结论
- [[10-项目/IMX95-EVK/Harpoon复现.md|Harpoon 复现操作手册]]
- [[10-项目/IMX95-EVK/README.md|IMX95-EVK 项目档案]]
