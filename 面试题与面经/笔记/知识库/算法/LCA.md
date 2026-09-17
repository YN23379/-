# 最近公共祖先 (LCA) 问题

## 问题定义

**最近公共祖先** (Lowest Common Ancestor)：对于有根树 T 的两个节点 p、q，最近公共祖先表示为一个节点 x，满足：
- x 是 p、q 的祖先
- x 的深度尽可能大
- 一个节点可以是它自己的祖先

## 应用场景

1. 计算树中两节点的最短路径
2. 家族关系分析
3. 文件系统目录关系
4. 编译器的继承关系分析

## 标准递归解法

### 核心思想
每个递归调用返回"在当前子树中关于p和q的最有价值信息"

### 递归契约
- **返回NULL**：当前子树中既没有p也没有q
- **返回p或q**：在当前子树中找到了其中一个目标节点
- **返回其他节点**：已经找到了p和q的最近公共祖先

### 算法模板

```c
struct TreeNode* lowestCommonAncestor(struct TreeNode* root, struct TreeNode* p, struct TreeNode* q) {
    // 基础情况
    if (root == NULL) return NULL;
    if (root == p || root == q) return root;
    
    // 向左右子树询问
    struct TreeNode* left = lowestCommonAncestor(root->left, p, q);
    struct TreeNode* right = lowestCommonAncestor(root->right, p, q);
    
    // 决策逻辑
    if (left != NULL && right != NULL) return root;  // 左右都有信息 → 我是LCA
    if (left != NULL) return left;                   // 只有左边有信息
    return right;                                    // 只有右边有信息
}
```

### 时间复杂度

- **O(n)**：每个节点最多访问一次
    
- n为树中节点数量
    

### 空间复杂度

- **O(h)**：递归栈深度，h为树的高度
    
- 最坏情况O(n)（链状树）
    
- 平均情况O(log n)（平衡树）
    

### 关键理解点

1. **信息传递思维**：递归函数在传递"关于p和q的状态信息"
    
2. **信任递归**：相信子调用能正确返回它管辖范围内的信息
    
3. **决策在汇合点**：当信息从左右两边汇集时，当前节点就是LCA
    
4. **提前返回**：一旦找到LCA，直接返回结果，不再继续搜索

### 变种与扩展

1. **多叉树LCA**：遍历所有子节点，统计非NULL结果数量
    
2. **带父指针的LCA**：可以转化为链表相交问题
    
3. **多次查询优化**：使用Tarjan离线算法或倍增法
    
4. **BST中的LCA**：利用BST性质，O(h)时间解决