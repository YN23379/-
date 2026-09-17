
## 架构
Android采用经典的分层架构。应用层通过Framework提供的API服务访问硬件功能，Framework服务通过Binder IPC和JNI与Native层通信。Native会调用HAL接口，HAL层位于用户空间，为各类硬件定义统一接口，隔离不同厂商的芯片差异。HAL的实现早期是动态库的函数表，现代版本使用HIDL/AIDL接口描述。HAL最终通过系统调用访问内核驱动，驱动直接控制I2C、SPI等硬件总线。


Bootloader是上电后第一段代码，初始化基本硬件、加载内核
Android启动流程：
Android启动是个完整的链式过程。从硬件上电开始，Bootloader加载Linux内核，内核初始化后启动第一个用户进程init。init根据init.rc脚本启动基础服务，最重要的是Zygote进程，它预加载了Framework的类和资源。Zygote孵化出SystemServer，SystemServer分阶段启动AMS、WMS、PMS等所有核心服务。最后AMS启动Launcher应用


在 Linux 下，驱动一般会注册为字符设备，通过 `/dev/xxx` 暴露给用户态，用户态用 `open/read/write` 或 `ioctl` 调用，或者通过 sysfs 节点去配置参数。