---
type: 知识库
scope: 工具与环境
doc_type: 未分类
status: 已整理
evidence: 教材课程
tags: [工具]
updated: 2026-09-17
---

## 数学块
Obsidian 的数学块完全基于 **LaTeX** 语法，这是一种学术界广泛使用的文档排版系统，尤其擅长处理复杂的数学公式。

它通过集成 **MathJax** 或 **KaTeX** 这两个强大的 JavaScript 库来实现公式的渲染和显示。

1. **行内公式**：在文字流中插入公式，用**单个美元符号** `$` 包裹。
    
    - 语法：`这是质能方程 $E = mc^2$ 的一个例子。`
        
    - 效果：这是质能方程 $E = mc^2$ 的一个例子。
        
2. **块公式**：单独成行、居中的公式，用**两个美元符号** `$$` 包裹。

![[90-附件/数学块常用表达式.png]]
向下取整`$\lfloor x \rfloor$`$\lfloor x \rfloor$
向上取整`$\lceil x \rceil$` $\lceil x \rceil$

## 常用语法速查（复制即用）

| 目标 | 语法 | 说明 |
|---|---|---|
| 上下标 | `x^2`、`x_i`、`x_{i+1}` | 多字符必须加花括号 |
| 分数 | `\frac{a}{b}` | |
| 根号 | `\sqrt{x}`、`\sqrt[3]{x}` | n 次根用可选参数 |
| 求和 | `\sum_{i=1}^{n} i` | |
| 积分 | `\int_0^1 f(x)dx` | |
| 极限 | `\lim_{x \to 0}` | `\to` 是箭头 |
| 乘除/正负 | `\times` `\div` `\pm` | |
| 比较 | `\leq` `\geq` `\neq` `\approx` | |
| 希腊字母 | `\alpha \beta \theta \pi \omega` | 大写首字母大写如 `\Omega` |
| 取整 | `\lfloor x \rfloor` `\lceil x \rceil` | 向下/向上取整 |
| 省略号 | `\cdots`（居中）`\ldots`（贴底） | |
| 属于/无穷 | `\in` `\infty` | |
| 文字 | `\text{最大值}` | 中文/多字母必须用 `\text{}` |

**矩阵**（块公式内）：

```latex
$$
A = \begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
$$
```

**多行推导对齐**（`&` 标对齐点，`\\` 换行）：

```latex
$$
\begin{aligned}
T(n) &= T(n-1) + n \\
     &= T(n-2) + (n-1) + n \\
     &= \frac{n(n+1)}{2}
\end{aligned}
$$
```

**分段函数**：

```latex
$$
f(x) = \begin{cases}
1,   & n = 0 \\
n \cdot f(n-1), & n > 0
\end{cases}
$$
```

**常见坑**：

1. 多字符的上下标**必须加花括号**：`x_{max}` 对，`x^max` 错。
2. 公式里写中文要用 `\text{}` 包起来，否则间距错乱。
3. 数学块里换行用 `\\`，Markdown 本身的换行不生效。
4. **别在代码块里写公式**——不会被渲染成数学。
5. 复杂公式渲染卡顿就拆成多个块公式。


<!-- related-generated -->
## 相关

**同目录**

- [[20-领域\工具与环境\编译构建工具.md|编译构建工具（含 API 概念）]]
- [[20-领域/工具与环境/MobaXterm使用.md|MobaXterm使用]]
- [[20-领域/工具与环境/SSH与文件传输.md|SSH与文件传输]]

**导航**：[[20-领域/工具与环境/README.md|工具与环境]]
