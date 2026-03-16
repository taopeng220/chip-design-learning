# Day 4 学习笔记 - Placement 算法深入（RePlAce）

📅 日期：2026-03-16
🎯 主题：OpenROAD Placement 算法 - RePlAce
📚 Phase 1: Week 1（算法深入）

---

## 🎯 学习目标

通过学习 RePlAce（Replace）算法，理解：
1. Placement 的本质是什么优化问题
2. 全局布局（Global Placement）vs 详细布局（Detailed Placement）
3. 如何从 FusionCompiler 的角度理解 OpenROAD
4. 工业界和学术界的算法差异

---

## 📖 Placement 是什么？

### 问题定义

**输入：**
```
- 门网表（Netlist）：N 个标准单元
- 芯片尺寸（Floorplan）：W × H 的布局区域
- 连接关系（Nets）：单元之间的连线
```

**输出：**
```
- 每个单元的坐标：(x₁, y₁), (x₂, y₂), ..., (xₙ, yₙ)
```

**目标：**
```
最小化总线长（Total Wirelength）
  同时满足：
  ✅ 单元不重叠
  ✅ 单元在合法位置（行对齐）
  ✅ 密度均匀（避免拥塞）
```

---

### 数学建模

#### 优化目标：最小化 HPWL

**HPWL (Half-Perimeter Wirelength)：**

对于一个 net 连接的所有 pin：
```
HPWL = (max_x - min_x) + (max_y - min_y)
```

**总目标函数：**
```
Minimize:  Σ HPWL(net_i)
           i=1 to M
```

**约束条件：**
```
1. 无重叠约束：
   cells[i] ∩ cells[j] = ∅  (i ≠ j)

2. 边界约束：
   0 ≤ x_i ≤ W - cell_width
   0 ≤ y_i ≤ H - cell_height

3. 行对齐约束：
   y_i = k × row_height  (k ∈ ℤ)

4. 密度约束：
   density(bin) ≤ target_density
```

---

### 为什么 Placement 很难？

**这是一个 NP-Hard 问题！**

#### 复杂度分析

假设：
- N = 100,000 个单元（中等规模设计）
- 芯片尺寸 = 1000 × 1000 个可放置位置

**可能的布局方案数量：**
```
(1000 × 1000)^100000 ≈ 10^600000
```

**宇宙中的原子数量：**
```
≈ 10^80
```

**结论：**
- 不可能枚举所有方案
- 需要启发式算法（Heuristic）
- 需要分阶段求解

---

## 🔧 RePlAce 算法概览

### 算法思路

**RePlAce = Reverse-engineering inspired PLACEment**

核心思想：**分而治之 + 迭代优化**

```
Placement = Global Placement + Detailed Placement

Global Placement:
  - 忽略单元重叠
  - 优化总线长
  - 快速求解（允许不合法）
  - 输出：单元大致位置

Detailed Placement:
  - 消除重叠
  - 单元对齐到行
  - 微调优化
  - 输出：合法布局
```

---

### 完整流程

```
┌─────────────────────────────────────────┐
│ 1. Initial Placement (初始布局)          │
│    - 随机放置 or 中心放置                │
│    - 建立初始解                          │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 2. Global Placement (全局布局)           │
│    ┌─────────────────────────┐          │
│    │ Repeat until converge:  │          │
│    │  a) Solve Quadratic     │          │
│    │     Wirelength Model    │          │
│    │  b) Apply Density Force │          │
│    │  c) Update positions    │          │
│    └─────────────────────────┘          │
│    输出：单元重叠，但线长优化            │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 3. Legalization (合法化)                 │
│    - 消除单元重叠                        │
│    - 对齐到标准单元行                    │
│    - 尽量保持 Global 的优化结果          │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 4. Detailed Placement (详细布局)         │
│    - 局部单元交换和移动                  │
│    - 进一步优化线长                      │
│    - 输出：最终合法布局                  │
└─────────────────────────────────────────┘
```

---

## 🌍 Global Placement 详解

### 核心思想

**将离散优化问题松弛为连续优化问题**

原问题（离散）：
```
单元只能放在离散的格点上
→ NP-Hard 组合优化
```

松弛后（连续）：
```
允许单元坐标为实数 (x, y)
允许单元重叠
→ 可用数值优化方法求解
```

---

### Quadratic Wirelength Model

#### 为什么用二次模型？

原始 HPWL 不可微分（有 max/min）：
```
HPWL = (max_x - min_x) + (max_y - min_y)
```

**二次模型（可微分）：**

对于一个 net 的线长：
```
Wirelength ≈ Σ Σ w_ij · ||(x_i, y_i) - (x_j, y_j)||²
            i  j
```

其中 w_ij 是连接权重。

**总目标函数：**
```
Φ(x, y) = Σ Σ w_ij · [(x_i - x_j)² + (y_i - y_j)²]
          i  j
```

这是一个**二次规划**问题，可以高效求解！

---

### Density Force（密度力）

#### 问题

纯粹最小化线长会导致：
```
❌ 所有单元堆在芯片中心
❌ 极端的单元重叠
❌ 无法 legalize
```

#### 解决方案：加入密度约束

**将芯片划分为 Bins（格子）：**

```
┌─────┬─────┬─────┬─────┐
│ Bin │ Bin │ Bin │ Bin │
│  1  │  2  │  3  │  4  │
├─────┼─────┼─────┼─────┤
│ Bin │ Bin │ Bin │ Bin │
│  5  │  6  │  7  │  8  │
├─────┼─────┼─────┼─────┤
│ Bin │ Bin │ Bin │ Bin │
│  9  │ 10  │ 11  │ 12  │
└─────┴─────┴─────┴─────┘
```

**计算每个 Bin 的密度：**
```
Density(bin) = Total_Cell_Area_in_bin / Bin_Area
```

**添加惩罚项：**
```
如果 Density(bin) > Target:
  → 施加"排斥力"，推开单元
  → 类似物理模拟中的电荷排斥
```

---

### 迭代优化流程

```
初始化：随机或中心放置单元

Repeat for each iteration:

  Step 1: 计算线长梯度
    ∇Φ_wirelength = 计算每个单元对线长的贡献

  Step 2: 计算密度梯度
    ∇Φ_density = 计算密度过高区域的排斥力

  Step 3: 合并梯度
    ∇Φ_total = α · ∇Φ_wirelength + β · ∇Φ_density

  Step 4: 更新单元位置
    x_new = x_old - learning_rate · ∇Φ_total

  Step 5: 检查收敛
    if (变化 < threshold):
      break

输出：单元位置（可能重叠）
```

**参数调整：**
- α, β：平衡线长和密度
- learning_rate：步长
- 迭代次数：通常 50-200 次

---

## 📐 Legalization（合法化）

### 目标

将 Global Placement 的结果（有重叠）转换为合法布局（无重叠）。

**要求：**
```
✅ 单元不重叠
✅ 单元对齐到标准单元行
✅ 尽量保持 Global 的位置（不要移动太远）
```

---

### Tetris-based Legalization

RePlAce 使用类似"俄罗斯方块"的算法：

```
算法流程：

1. 按 x 坐标排序单元
   cells = sort_by_x(all_cells)

2. 逐行处理
   for each row:
     current_x = 0

     for each cell in this_row:
       if (current_x + cell.width ≤ row_end):
         # 空间够，直接放置
         place_cell(current_x, row.y)
         current_x += cell.width
       else:
         # 空间不够，移到下一行
         next_row, current_x = find_space()
         place_cell(current_x, next_row.y)

3. 微调优化
   - 如果单元移动太远，尝试插入到前面的空隙
   - 交换相邻单元以减少线长
```

---

### 白空间分配

**问题：**
- 如果 Utilization = 70%，有 30% 白空间
- 如何分配这些空隙？

**策略：**

```
1. 均匀分布（Uniform）
   - 每行平均分配白空间
   - 简单但不一定最优

2. 密度驱动（Density-driven）
   - 拥塞区域分配更多空间
   - 关键路径区域保留余量

3. 时序驱动（Timing-driven）
   - Critical Path 上的单元分散
   - 减少 Wire Delay
```

---

## 🎨 Detailed Placement

### 目标

在合法布局基础上，进一步优化线长和时序。

---

### 常用技术

#### 1. Cell Reordering（单元重排序）

在同一行内交换单元位置：

```
Before:  [A] [B] [C] [D]

如果 A 和 C 有很多连接：

After:   [C] [B] [A] [D]

→ 减少线长
```

---

#### 2. Local Refinement（局部优化）

```
选择一个小窗口（例如 10×10 单元）：

┌─────────────┐
│ □ □ □ □ □   │
│ □ □ ■ □ □   │  ■ = 目标单元
│ □ □ □ □ □   │  □ = 邻居
└─────────────┘

在窗口内重新布局：
  - 固定周围单元
  - 优化窗口内的排列
  - 使用小规模精确算法
```

---

#### 3. Single-Segment Clustering

```
识别强连接的单元簇：

   [A]─────[B]
    │       │
    │       │
   [C]─────[D]

将簇作为整体移动：
  - 保持簇内相对位置
  - 优化簇的整体位置
```

---

## 📊 RePlAce 算法特点

### ✅ 优点

1. **快速**
   - 100K 单元 < 10 分钟
   - 可扩展到百万级

2. **开源**
   - 代码透明
   - 可以学习和修改

3. **质量尚可**
   - 线长通常优于随机 20-30%
   - 小规模设计足够用

4. **模块化**
   - Global/Legalization/Detailed 分离
   - 易于理解和改进

---

### ⚠️ 局限性

1. **不如商业工具**
   - FusionCompiler 的 Placement 质量更高
   - 线长差距 5-15%

2. **时序优化弱**
   - 主要优化线长
   - 时序驱动能力有限

3. **对复杂约束支持不足**
   - Multi-voltage domains
   - Complex placement blockages
   - Advanced optimization directives

4. **需要调参**
   - α, β 等参数需手动调整
   - 没有智能自适应

---

## 🆚 RePlAce vs FusionCompiler Placement

### 对比表格

| 特性 | RePlAce | FusionCompiler |
|------|---------|----------------|
| **算法** | Quadratic + Density Force | 多算法混合（保密） |
| **优化目标** | 主要线长 | 线长 + 时序 + 功耗 |
| **时序驱动** | 基础 | 强大（Topographical） |
| **全局优化** | 有 | 非常强（全流程协同） |
| **运行时间** | 快（分钟级） | 较慢（小时级） |
| **质量** | 中等 | 优秀 |
| **可调性** | 参数多，需手动 | 自动优化 |
| **透明度** | 开源，可学习 | 黑盒 |
| **适用场景** | 学习，小项目 | 工业生产 |

---

### FusionCompiler 的优势

#### 1. 时序驱动布局（Timing-Driven Placement）

**RePlAce：**
```
主要考虑线长
→ 所有 net 权重相同
→ 不区分 critical path
```

**FusionCompiler：**
```
根据时序 slack 分配权重
→ Critical path net 权重高
→ 非关键路径可以牺牲
→ 直接优化 WNS/TNS
```

**例子：**

```
Path A: Slack = -0.5ns (Critical) ❌
Path B: Slack = +2.0ns (Safe)     ✅

FusionCompiler:
  → 优先缩短 Path A 的 wire
  → Path B 可以稍微长一点
  → 最终 Path A 满足时序 ✅

RePlAce:
  → 两条路径权重相同
  → 可能优化了 Path B，Path A 仍违规 ❌
```

---

#### 2. 物理感知综合（Topographical Synthesis）

**FusionCompiler 独有功能：**

```
综合阶段就考虑物理信息：

  1. 估算单元位置（Virtual Placement）
  2. 估算线长
  3. 根据估算结果优化逻辑
  4. 例如：插入 Buffer 减少 Wire Delay

→ 综合和布局协同优化
→ QoR 显著提升
```

**RePlAce：**
```
只负责 Placement
不影响逻辑
→ 分离优化，结果次优
```

---

#### 3. 全局迭代优化

**FusionCompiler：**
```
compile_ultra 流程：

  综合 → Placement → 时序分析
    ↑                        ↓
    └────── 反馈优化 ─────────┘

  多次迭代：
    - 根据实际 Wire Delay 调整逻辑
    - 根据时序结果调整 Placement
    - 协同收敛
```

**RePlAce：**
```
单向流程：
  Placement → 输出

  不迭代
  不反馈
```

---

## 💡 从 RePlAce 理解 Placement 本质

### 核心启示

通过学习 RePlAce，我们理解了：

#### 1. Placement 的本质

```
Placement = 多目标优化问题

目标1: 最小化线长
  → 减少 Wire Delay
  → 减少功耗

目标2: 满足密度约束
  → 避免 Congestion
  → 确保可 Routing

目标3: 优化时序
  → 缩短 Critical Path
  → 提升频率

目标4: 其他（功耗、IR Drop...）
```

这些目标**互相冲突**：
- 最小线长 ↔ 密度均匀
- 缩短关键路径 ↔ 全局线长
- 需要权衡！

---

#### 2. 为什么需要分阶段

```
为什么 Global + Detailed？

如果直接求解带约束的优化问题：
  - 计算复杂度爆炸
  - 无法在合理时间内完成

分阶段的好处：
  - Global: 快速找到大致方向（松弛约束）
  - Detailed: 精细调整（满足约束）
  - 分而治之，提高效率
```

---

#### 3. 启发式算法的必要性

```
Placement 没有"最优解"：
  - 问题是 NP-Hard
  - 只能找"足够好"的解

不同算法有不同 trade-off：
  - RePlAce: 快，质量中等
  - 模拟退火: 慢，质量高
  - 商业工具: 快 + 质量高（但闭源）
```

---

## 🧪 实际例子分析

### 例子：4-bit Counter

还记得 Day 3 的 Counter 例子吗？让我们从 Placement 角度分析。

---

#### 网表结构

```
4 个 DFF (触发器)：
  FF0, FF1, FF2, FF3

Combinational Logic (组合逻辑)：
  加法器、进位链

连接关系：
  FF0 → Adder → FF1
  FF1 → Adder → FF2
  FF2 → Adder → FF3
  FF3 → Adder → FF0 (wrap around)
```

---

#### Placement 策略

**Bad Placement:**
```
FF0 ────────────→ Adder ────────────→ FF1
                                      ↓
FF3 ←────────────────────────────── FF2
↓
(long wire back to FF0)

问题：
  - FF3 → FF0 的线很长
  - Wire Delay 大
  - Slack 减少
```

**Good Placement:**
```
FF0 → Adder → FF1 → Adder → FF2 → Adder → FF3
                                             ↓
                            FF0 ←── Adder ───┘

线性排列：
  - 所有 wire 长度相似
  - Wire Delay 均衡
  - Slack 最大化
```

---

#### RePlAce 会如何处理？

```
1. Global Placement:
   - 识别 FF0-FF1-FF2-FF3 的链式连接
   - 二次模型优化 → 倾向于线性排列
   - 输出：类似线性的大致位置

2. Legalization:
   - 将 FF 对齐到标准单元行
   - 可能调整到相邻行
   - 保持相对顺序

3. Detailed:
   - 微调 Adder 和 FF 的位置
   - 减少总线长
   - 最终合法布局
```

---

## 📚 总结

### 今天学到的核心知识

#### 1. Placement 的数学本质

```
Placement = 约束优化问题

目标函数: Minimize Wirelength
约束条件: 无重叠 + 合法位置 + 密度均匀

解法: 启发式算法（因为 NP-Hard）
```

---

#### 2. RePlAce 的三阶段

```
Global Placement:
  - 松弛约束（允许重叠）
  - 快速优化线长
  - 二次模型 + 密度力

Legalization:
  - 消除重叠
  - 对齐到行
  - 尽量保持 Global 结果

Detailed Placement:
  - 局部优化
  - 单元交换和移动
  - 进一步降低线长
```

---

#### 3. 与 FusionCompiler 的差距

```
RePlAce:
  ✅ 开源、快速、可学习
  ❌ 时序优化弱、质量中等

FusionCompiler:
  ✅ 时序驱动、全局优化、质量高
  ❌ 闭源、昂贵、黑盒
```

---

## 🎯 下一步

我们已经深入理解了 Placement 算法，接下来学习：

### ⏭️ Day 4 继续：CTS 算法（TritonCTS）

时钟树构建的核心算法：
- H-tree、X-tree、Fish-bone 拓扑
- Skew 最小化
- Buffer 插入策略
- 从 STA 角度理解 CTS

---

**Placement 算法学习完成！准备好学习 CTS 了吗？** 🚀
