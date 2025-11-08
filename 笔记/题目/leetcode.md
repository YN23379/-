#### 计算n！后面几位有几个0



## 贪心算法
**在每一步选择中都采取当前状态下最优的选择，从而希望导致全局最优**。

### [121. 买卖股票的最佳时机](https://leetcode.cn/problems/best-time-to-buy-and-sell-stock/)

一开始没怎么想好，看了下折线图一下子就知道怎么写了
重点是维持最低，保持记录最大收获

### [55. 跳跃游戏](https://leetcode.cn/problems/jump-game/)

试了可能一个小时，思路是有的，但是可惜考虑的太多了，思路不是很清晰，推到一定部分就不知道怎么写了，还是想复杂了






## 排序
### [215. 数组中的第K个最大元素](https://leetcode.cn/problems/kth-largest-element-in-an-array/)
==这题看题解都看了半天，用的是快速选择（快速排序变种），使用了 **Lomuto 分区方案的一种变体**（实际上是类似 Hoare 分区的双指针法）。==

## 技巧

### [136. 只出现一次的数字](https://leetcode.cn/problems/single-number/)

### [169. 多数元素](https://leetcode.cn/problems/majority-element/)


### [287. 寻找重复数](https://leetcode.cn/problems/find-the-duplicate-number/)
妙，双指针算法也就是Floyd判圈法
相遇后，从起点和相遇点同时同速前进，相遇点就是环的入口，也就是重复数字。
和这题一样[142. 环形链表 II](https://leetcode.cn/problems/linked-list-cycle-ii/)



