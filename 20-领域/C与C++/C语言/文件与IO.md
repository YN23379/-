---
type: 知识库
scope: C与C++
doc_type: 原理
status: 已整理
evidence: 教材课程
tags: [C语言, 文件系统, 进程与线程, 内存管理]
updated: 2026-09-17
---

#文件

## 文件权限
```bash
# 权限分解：
- r w x   r - x   r - -
所有者  同组用户  其他用户

# 数字计算：
r w x = 4+2+1 = 7
r - x = 4+0+1 = 5
r - - = 4+0+0 = 4
所以是 754 ✅


chown -R root:root dir 可以将dir下所有文件的所有者和所属组变为root
chown        # 修改文件所有者(owner)和组(group)
-R           # 递归处理，包括子目录和文件
root:root    # 所有者:组
dir          # 目标目录

# 效果：将dir及其所有内容的所有者和组都设为root

```


|命令|作用|常用参数|
|---|---|---|
|`chmod`|修改权限|-R(递归), -v(显示详情)|
|`chown`|修改所有者/组|-R(递归)|
|`chgrp`|修改组|-R(递归)|
|`umask`|设置默认权限掩码|如022|
|`mkdir`|创建目录|-p(创建父目录), -m(设置权限)|
```shell
mkdir -p 的特性：
-p, --parents  # 1. 创建多级目录
               # 2. 目录已存在时不报错（静默跳过）
```
- 不加 `-p`：目录存在时报错 "File exists"
- 加 `-p`：目录存在时**不报错**，静默继续
- 常用于脚本中，避免错误检查


## 标准IO缓冲
标准I/O库在用户空间维护的数据中转区，目的是**减少系统调用次数**，提升I/O效率。数据先累积在缓冲区，满或满足条件时一次性读写，避免频繁的read/write系统调用开销。"

### 三种缓冲模式

**1. 全缓冲 (Fully Buffered)**

- **场景**：普通磁盘文件
    
- **特点**：缓冲区满（通常4KB）或调用`fflush()`才实际I/O
    
- **设置**：`setvbuf(stream, buf, _IOFBF, size)`

**2. 行缓冲 (Line Buffered)**

- **场景**：终端设备（stdin/stdout）
    
- **特点**：遇到换行符`\n`、缓冲区满或需要输入时刷新
    
- **注意**：`printf()`不立即输出，加`\n`或`fflush`才刷新

**3. 无缓冲 (Unbuffered)**

- **场景**：标准错误stderr（错误信息需立即显示）
    
- **特点**：每次I/O操作都直接调用系统调用
    
- **设置**：`setbuf(stream, NULL)` 或 `setvbuf(stream, NULL, _IONBF, 0)`
    

**终端用行缓冲，文件用全缓冲，错误用无缓冲**。
多进程/线程中缓冲区可能混乱，需要`fflush`同步。嵌入式日志系统通常设为无缓冲，确保崩溃前信息不丢失。"





## 文件函数





### remove
```
#include <stdio.h>
```


### rename
```c
#include <stdio.h>
int rename(char * oldname, char * newname);
```
参数:oldname为旧文件名，newname为新文件名。  
返回值:修改文件名成功则返回0，否则返回-1。
重命名文件：
- 如果newname指定的文件存在，则会被删除。
- 如果newname与oldname不在一个目录下，则相当于移动文件。
重命名目录：
- 如果oldname和oldname都为目录，则重命名目录。
- 如果newname指定的目录存在且为空目录，则先将newname删除。
- 对于newname和oldname两个目录，调用进程必须有写权限。
- 重命名目录时，newname不能包含oldname作为其路径前缀。例如，不能将/usr更名为/usr/foo/testdir，因为老名字（ /usr/foo）是新名字的路径前缀，因而不能将其删除。
### stat
![[90-附件/stat结构体.png|1000]]
```c
#include <sys/types.h> 
#include <sys/stat.h> 
#include <unistd.h> 
 
int stat(const char *pathname, struct stat *buf); 

```
pathname：用于指定一个需要查看属性的文件路径。
buf：struct stat 类型指针，用于指向一个 struct stat 结构体变量。调用 stat 函数的时候需要传入一个 struct stat 变量的指针，获取到的文件属性信息就记录在 struct stat 结构体中。
返回值：成功返回 0；失败返回-1，并设置 error。

---

## 二进制模式与换行符（原「文件」笔记）

### 优先使用二进制模式
windows上\n就是写入\r\n，但是unix/linux环境\n就是\n，这就是为什么在进行文件格式解析、网络编程或嵌入式开发时，应该优先使用二进制模式。

---

## 文件描述符与 close（原笔记名与内容不符，实为 IO 资源管理）

## open/close

对于类似打开文件的函数，它们都占有对应的一个文件描述符，每一个进程的文件描述符是有上限的
每一次open都需要对应调用一次close
close的作用是：
1. **释放内核资源**：每个打开的文件在内核中都有对应的数据结构（file结构体）
    
2. **回收文件描述符**：文件描述符是进程级的有限资源
    
3. **确保数据持久化**：对于写入操作，close()会触发缓冲区刷盘

也为了避免资源泄露，
```c
// 必须close的：
open() → close()
socket() → close() 
opendir() → closedir()
fopen() → fclose()
mmap() → munmap()

// 不需要close的：
malloc() → free()  // 用户态内存
pthread_create() → pthread_join()  // 线程资源
```

---

## 文件 / 管道 / Socket 的区别

- **文件**：通常是**随机访问**的（可以用 `lseek` 跳转到任意位置）。数据是静态存在的。
    
- **管道**：是**单向**的字节流，数据一旦被读取就消失了。
    
- **Socket**：通常是**顺序访问**的字节流，并且是**双向**的。它代表的是一条**通信通道**，具有连接的概念（需要 `connect`, `accept`, `bind`, `listen` 等额外调用来建立通道）。

---

## 附：从标准输入读数组（scanf / fgets+strtok）

### 数组初始化

`%d`会自动跳过前面的空白字符（空格、换行、制表符）。
所以能直接在循环用scanf 的输入分隔实现数组初始化
如果是逗号隔开各元素,则`scanf("%d,", &arr[i]); `加上逗号

如果是二维数组
```c
for(int i = 0; i < n; i++) {
    for(int j = 0; j < n; j++) {
        scanf("%d", &matrix[i][j]);
    }
}
//有逗号就加上,"%d,"
```

若不确定分隔符
```c
// 读取一行，然后解析
char line[1000];
fgets(line, sizeof(line), stdin);

// 使用strtok分割字符串
char* token = strtok(line, " ,\n");  // 支持空格、逗号、换行分隔
while(token != NULL) {
    arr[i++] = atoi(token);
    token = strtok(NULL, " ,\n");
}
```

```c
struct TreeNode** stk = malloc(sizeof(struct TreeNode*) * 100);//正确

struct TreeNode* stk[100] = malloc(sizeof(struct TreeNode*) * 100);//错误
// 每个stk[i]需要单独分配：
stk[0] = malloc(sizeof(struct TreeNode));
```
- `stk[100]` 是在栈上分配的数组，不是指针
    
- 数组名是常量，不能作为左值被赋值
    
- 只能在定义时初始化，不能后续赋值

<!-- related-generated -->
## 相关

**同目录**

- [[20-领域/C与C++/C语言/函数_编译链接与宏.md|函数_编译链接与宏]]
- [[20-领域/C与C++/C语言/基础与进阶总览.md|基础与进阶总览]]
- [[20-领域/C与C++/C语言/字符串.md|字符串]]

**导航**：[[20-领域/C与C++/C语言/README.md|C语言]]
