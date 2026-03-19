# Day 4 学习笔记 - CTS 算法深入（TritonCTS）

📅 日期：2026-03-16
🎯 主题：OpenROAD CTS 算法 - TritonCTS
📚 Phase 1: Week 1（算法深入）

---

## 🎯 学习目标

通过学习 TritonCTS 算法，理解：
1. 时钟树构建的本质和挑战
2. 常见时钟树拓扑结构
3. Skew 最小化算法
4. Buffer 插入策略
5. 从 STA 角度理解 CTS

---

## ⏰ CTS 是什么？

### 问题定义

**输入：**
```
- 布局结果（Placement）：所有 FF 的位置
- 时钟源位置（Clock Source）
- 时钟约束（SDC）：
  - 目标频率
  - Skew 要求
  - Transition 要求
```

**输出：**
```
- 时钟树拓扑（Clock Tree）
- Buffer 位置和大小
- 时钟网络（Clock Net）
```

**目标：**
```
✅ 最小化 Skew（时钟偏差）
✅ 满足 Transition 约束
✅ 降低功耗
✅ 平衡延迟
```

---

### 为什么 CTS 重要？

回顾 STA Setup 方程：

```
Setup Slack = Required Time - Arrival Time
            = (Capture Clock + Period - Setup) - (Launch Clock + Logic + Wire)

Skew = Capture Clock - Launch Clock

如果 Skew 大：
  → Slack 可能违规
  → 时序失败
  → 芯片不工作！
```

**例子：**

```
假设：
  Period = 1.0 ns
  Logic + Wire = 0.8 ns
  Setup = 0.1 ns

理想情况（Skew = 0）:
  Slack = (0 + 1.0 - 0.1) - (0 + 0.8)
        = 0.9 - 0.8
        = +0.1 ns ✅

Skew = 0.15 ns（CTS 做得不好）:
  Slack = (0.15 + 1.0 - 0.1) - (0 + 0.8)
        = 1.05 - 0.8
        = +0.25 ns

  看起来更好？错！

  考虑 Worst Case:
    Launch Clock 可能是 0.15 ns
    Capture Clock 可能是 0 ns
    → Negative Skew!

  Slack = (0 + 1.0 - 0.1) - (0.15 + 0.8)
        = 0.9 - 0.95
        = -0.05 ns ❌ 违规！
```

**结论：**
- **Skew 必须小**（通常 < 5% of Period）
- Skew 越小，时序余量越安全

---

## 🌳 时钟树拓扑结构

### 1. H-Tree（H 树）

#### 结构

```
                    CLK Source
                        │
                    ┌───┴───┐
                    │   B0  │ (Buffer)
                    └───┬───┘
                        │
          ┌─────────────┼─────────────┐
          │                           │
      ┌───┴───┐                   ┌───┴───┐
      │   B1  │                   │   B2  │
      └───┬───┘                   └───┬───┘
          │                           │
    ┌─────┼─────┐               ┌─────┼─────┐
    │           │               │           │
┌───┴───┐   ┌───┴───┐       ┌───┴───┐   ┌───┴───┐
│  FF1  │   │  FF2  │       │  FF3  │   │  FF4  │
└───────┘   └───────┘       └───────┘   └───────┘
```

#### 特点

**✅ 优点：**
- Skew 天然很小（对称结构）
- 延迟平衡（所有路径长度相同）
- 易于设计和验证

**❌ 缺点：**
- Wire Length 长（绕路）
- 功耗高（冗余走线）
- 对不规则布局适应性差

**适用场景：**
- 规则的矩形布局
- 高性能设计（对 Skew 要求极高）
- FF 分布均匀

---

### 2. X-Tree（X 树）

#### 结构

```
        CLK Source
            │
        ┌───┴───┐
        │   B0  │
        └───┬───┘
            │
    ┌───────┼───────┐
    │       │       │
    ↓       ↓       ↓
   FF1  ┌───┴───┐  FF2
        │   B1  │
        └───┬───┘
            │
        ┌───┼───┐
        ↓   ↓   ↓
       FF3 FF4 FF5
```

#### 特点

**类似 H-tree，但 X 形分叉：**
- 45° 走线
- 适应不规则形状
- Skew 仍然较小

---

### 3. Fish-bone（鱼骨树）

#### 结构

```
CLK ───────────────────────────────── (主干 Spine)
       │   │   │   │   │   │   │
       ↓   ↓   ↓   ↓   ↓   ↓   ↓
      FF1 FF2 FF3 FF4 FF5 FF6 FF7  (分支 Ribs)
```

#### 特点

**✅ 优点：**
- Wire Length 短
- 功耗低
- 简单实现

**❌ 缺点：**
- Skew 较大（不同分支延迟不同）
- 需要仔细平衡

**适用场景：**
- 低功耗设计
- FF 线性分布（如 Scan Chain）

---

### 4. Binary Tree（二叉树）

#### 结构

```
           CLK
            │
        ┌───┴───┐
        │   B0  │
        └───┬───┘
            │
      ┌─────┴─────┐
      │           │
  ┌───┴───┐   ┌───┴───┐
  │  B1   │   │  B2   │
  └───┬───┘   └───┬───┘
      │           │
   ┌──┴──┐     ┌──┴──┐
   │     │     │     │
  FF1   FF2   FF3   FF4
```

#### 特点

**最常用的结构：**
- 灵活性好（适应任意布局）
- Skew 可控（通过平衡调整）
- Wire Length 中等

**TritonCTS 主要使用此拓扑！**

---

## 🔧 TritonCTS 算法核心

### 算法流程

```
┌──────────────────────────────────────┐
│ 1. Clustering (聚类)                  │
│    - 将 FF 分组                       │
│    - 使用 K-means 或层次聚类         │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 2. Topology Generation (拓扑生成)     │
│    - 构建二叉树结构                   │
│    - 自底向上构建                     │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 3. Buffer Insertion (插入 Buffer)     │
│    - 计算 Buffer 位置和大小           │
│    - 满足 Transition 约束             │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 4. Skew Balancing (平衡 Skew)        │
│    - 调整 Buffer 位置和大小           │
│    - 插入 Delay Cell（如需要）        │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 5. Legalization (合法化)              │
│    - 确保 Buffer 在合法位置           │
│    - 避免 DRC 违规                    │
└──────────────────────────────────────┘
```

---

## 📊 1. Clustering（聚类）

### 目标

将成千上万个 FF 分组，形成层次结构。

---

### K-means Clustering

**算法：**

```
输入: N 个 FF 的位置 (x_i, y_i)
输出: K 个簇（Cluster）

Step 1: 初始化 K 个中心点

Step 2: Repeat until converge:
  a) 分配 FF 到最近的中心
     for each FF:
       cluster[i] = argmin distance(FF, center[k])

  b) 更新中心点
     for each cluster:
       center[k] = mean position of FFs in cluster[k]

Step 3: 输出簇
```

---

### 例子

假设 8 个 FF，分成 4 个簇：

```
初始 FF 位置:
  FF1 (10, 10)   FF5 (100, 10)
  FF2 (15, 12)   FF6 (105, 15)
  FF3 (12, 18)   FF7 (102, 12)
  FF4 (18, 15)   FF8 (110, 18)

K-means 聚类 (K=2):

Cluster 1:           Cluster 2:
  FF1, FF2            FF5, FF6
  FF3, FF4            FF7, FF8
  Center: (13, 13)    Center: (104, 13)
```

---

### 为什么需要聚类？

```
如果不聚类，直接构建时钟树：
  - 8 个 FF → 7 个 Buffer
  - 某些 Buffer 到 FF 的距离很远
  - Wire Delay 大且不均衡
  - Skew 大 ❌

聚类后：
  - 近距离 FF 共享 Buffer
  - Wire Delay 小且均衡
  - Skew 小 ✅
```

---

## 🌲 2. Topology Generation（拓扑生成）

### 自底向上构建

**思路：**

```
Level 0 (叶节点):
  FF1, FF2, FF3, ..., FF8

Level 1:
  合并相邻的 FF，插入 Buffer
  B1 = merge(FF1, FF2)
  B2 = merge(FF3, FF4)
  B3 = merge(FF5, FF6)
  B4 = merge(FF7, FF8)

Level 2:
  B5 = merge(B1, B2)
  B6 = merge(B3, B4)

Level 3:
  B7 = merge(B5, B6)  → 根节点（连到 CLK Source）
```

---

### DME 算法（Deferred Merge Embedding）

**核心思想：**

在合并两个子树时，选择 Buffer 位置使得到两个子节点的延迟**完全相等**。

---

#### 详细步骤

假设合并两个节点 A 和 B：

```
节点 A: 位置 (x_A, y_A), 到叶节点延迟 = d_A
节点 B: 位置 (x_B, y_B), 到叶节点延迟 = d_B

目标: 找到 Buffer 位置 (x_B, y_B) 使得:
  Wire_Delay(Buffer → A) + d_A = Wire_Delay(Buffer → B) + d_B
```

**Merging Region（可合并区域）：**

所有满足上述条件的 Buffer 位置形成一个区域（通常是曼哈顿距离的等高线）。

```
        A (d_A = 0.3 ns)
         \
          \
           \  Merging Region
            \ (满足延迟平衡)
             \
              B (d_B = 0.5 ns)

在这个区域内选择 Buffer 位置：
  - 优先靠近中心（减少总线长）
  - 避免拥塞区域
  - 考虑 Buffer 可用位置
```

---

### 例子

```
合并 FF1 和 FF2:

FF1: (10, 10), delay_to_leaf = 0
FF2: (20, 10), delay_to_leaf = 0

目标: 找 Buffer 位置 (x, y) 使得:
  distance(Buffer, FF1) = distance(Buffer, FF2)

解: (15, 10) - 中点
  distance = 5 um (Manhattan)
  延迟平衡 ✅
```

---

## 🔌 3. Buffer Insertion（插入 Buffer）

### 为什么需要 Buffer？

**问题：**

```
如果直接连接 CLK Source 到所有 FF:

CLK ──────────────────────────────── FF1 (距离 1mm)
      └──────────────────────────── FF2 (距离 5mm)

Wire Delay:
  FF1: 0.1 ns
  FF2: 0.5 ns

Skew = 0.5 - 0.1 = 0.4 ns ❌ 太大！
```

**解决方案：**

```
插入 Buffer 平衡延迟:

CLK ──→ Buffer ──────→ FF1
         └──→ Delay ──→ FF2

调整 Delay Cell 或 Buffer 大小:
  FF1: 0.3 ns (Buffer + Short Wire)
  FF2: 0.3 ns (Buffer + Long Wire)

Skew = 0 ✅
```

---

### Buffer 位置选择

**原则：**

1. **几何中心**
   - Buffer 靠近其 fanout 的中心
   - 减少总线长

2. **延迟平衡**
   - DME 算法保证

3. **合法位置**
   - 避开已放置的单元
   - 避开 Macro
   - 在 Standard Cell Row 上

4. **Transition 约束**
   - 确保信号边沿速度满足要求
   - 避免信号退化

---

### Buffer 大小选择

**Trade-off：**

```
大 Buffer:
  ✅ Driving 能力强
  ✅ 能驱动长 Wire
  ✅ Transition 好
  ❌ 延迟大
  ❌ 功耗高
  ❌ 面积大

小 Buffer:
  ✅ 延迟小
  ✅ 功耗低
  ✅ 面积小
  ❌ Driving 能力弱
  ❌ 只能驱动短 Wire
  ❌ Transition 可能违规
```

**选择策略：**

```
根据 fanout 和 wire length:

If (wire_length < 100 um and fanout < 10):
  → 使用小 Buffer (BUF_X1)

Else if (wire_length < 500 um and fanout < 50):
  → 使用中 Buffer (BUF_X4)

Else:
  → 使用大 Buffer (BUF_X8 或 X16)
```

---

## ⚖️ 4. Skew Balancing（平衡 Skew）

### Skew 的来源

即使使用 DME 算法，仍然可能有 Skew：

**原因：**

```
1. Wire 模型不准确
   - 估算 vs 实际
   - RC 参数变化

2. Buffer 延迟变化
   - PVT (Process, Voltage, Temperature)
   - 负载电容差异

3. 布线绕路
   - Congestion 导致绕线
   - 实际 wire length > Manhattan distance

4. Placement 调整
   - Legalization 移动了 FF
   - 与 CTS 时的位置不同
```

---

### 平衡技术

#### 1. Buffer Sizing（调整 Buffer 大小）

```
如果某条路径延迟小：
  → 使用小 Buffer（增加延迟）

如果某条路径延迟大：
  → 使用大 Buffer（可能减少延迟，但通常相反）

注意: Buffer 大小主要影响 transition，对延迟影响有限
```

---

#### 2. Wire Snaking（绕线）

增加 wire length 来增加延迟：

```
原始:
  A ────→ B  (100 um, 0.1 ns)

绕线:
  A ──┐
      │
      └──→ B  (150 um, 0.15 ns)

增加延迟 0.05 ns
```

**缺点：**
- 浪费面积
- 增加功耗
- 不优雅

---

#### 3. Delay Cell Insertion（插入延迟单元）

插入专用的 Delay Cell：

```
Delay Cell = 不改变逻辑的 Buffer
           = 只增加延迟，不增加 driving

例子:
  DELAY_X1: 延迟 0.05 ns
  DELAY_X2: 延迟 0.10 ns
  DELAY_X4: 延迟 0.20 ns
```

**用法：**

```
如果 Path A 比 Path B 快 0.1 ns:

Path A: CLK → B1 → FF1  (延迟 0.3 ns)
Path B: CLK → B2 → FF2  (延迟 0.4 ns)

插入 DELAY_X2 到 Path A:

Path A: CLK → B1 → DELAY → FF1  (0.3 + 0.1 = 0.4 ns)
Path B: CLK → B2 → FF2          (0.4 ns)

Skew = 0 ✅
```

---

#### 4. Useful Skew（有用偏差）

**激进优化技术：**

故意创建 Skew 来优化时序！

**原理：**

```
Setup 方程:
  Slack = (Capture + Period - Setup) - (Launch + Logic + Wire)

如果 Capture > Launch (正 Skew):
  → Setup Slack 增加 ✅

Hold 方程:
  Slack = (Arrival) - (Capture + Hold)
        = (Launch + Logic + Wire) - (Capture + Hold)

如果 Capture > Launch (正 Skew):
  → Hold Slack 减少 ⚠️

需要平衡!
```

**例子：**

```
Critical Path (Setup 快违规):
  Launch FF1 → Logic (0.8 ns) → Capture FF2
  Period = 1.0 ns
  Setup Slack = -0.05 ns ❌

Useful Skew 优化:
  延迟 FF1 的时钟 0.1 ns
  → Launch 延迟
  → Setup Slack = -0.05 + 0.1 = +0.05 ns ✅

但要检查:
  其他路径的 Hold Slack 是否变差
```

**FusionCompiler 支持 Useful Skew，TritonCTS 不支持（太复杂）**

---

## 📐 5. Legalization（合法化）

### 目标

确保所有 Buffer 位置合法。

---

### 挑战

**问题：**

```
CTS 算法计算的 Buffer 最优位置可能：
  ❌ 与已放置的 Cell 重叠
  ❌ 在 Macro 上
  ❌ 不在 Standard Cell Row 上
  ❌ 在 Routing Blockage 上
```

---

### 解决方案

#### 1. 最小移动 Legalization

```
算法:

For each illegal buffer:
  1. 找到最近的合法位置
  2. 移动 Buffer
  3. 更新连线

  如果移动距离 > threshold:
    → 重新计算 Skew
    → 可能需要调整其他 Buffer
```

---

#### 2. 增量优化

```
If (legalization 后 Skew 增加太多):
  1. 尝试插入额外 Buffer
  2. 调整 Buffer 大小
  3. 插入 Delay Cell
  4. 重新平衡子树
```

---

## 🆚 TritonCTS vs FusionCompiler CTS

### 对比表格

| 特性 | TritonCTS | FusionCompiler |
|------|-----------|----------------|
| **拓扑** | Binary Tree | 多种（智能选择） |
| **算法** | DME（经典） | 专有算法（更优） |
| **Useful Skew** | ❌ 不支持 | ✅ 支持 |
| **Multi-Corner** | 基础 | 强大 |
| **Skew 质量** | 中等（10-50ps） | 优秀（<10ps） |
| **功耗优化** | 基础 | 多种技术 |
| **运行时间** | 快 | 较慢 |
| **可调性** | 参数少 | 参数多 |

---

### FusionCompiler 的优势

#### 1. Useful Skew Optimization

**TritonCTS：**
```
目标: Skew = 0

所有 FF 的时钟延迟尽量相同
不考虑逻辑路径
```

**FusionCompiler：**
```
目标: 最大化 Slack（可能 Skew ≠ 0）

分析所有时序路径
故意创建有用的 Skew
优化 WNS/TNS
```

---

#### 2. Multi-Corner Multi-Mode

**TritonCTS：**
```
主要考虑 Typical Corner
对 PVT 变化支持有限
```

**FusionCompiler：**
```
同时优化多个 Corner:
  - Fast/Slow Corner
  - Different VDD
  - Different Temperature

确保所有 Corner 都满足时序
```

---

#### 3. 时钟门控（Clock Gating）

**Clock Gating：**

```
目的: 省功耗

当某些 FF 不需要翻转时，关闭其时钟：

       ┌─────────┐
CLK ───┤ AND Gate├─→ Gated CLK → FF
       └────┬────┘
            │
        Enable

Enable = 1: FF 正常工作
Enable = 0: 时钟关闭，省功耗
```

**FusionCompiler：**
```
自动识别可 Gating 的 FF
插入 Clock Gating Cell
优化 Gating 逻辑的 CTS
```

**TritonCTS：**
```
基本不支持 Clock Gating 优化
需要手动处理
```

---

## 💡 从 TritonCTS 理解 CTS 本质

### 核心启示

#### 1. CTS 的本质

```
CTS = 延迟平衡问题

给定 N 个 FF 的位置，构建一棵树，使得:
  - 从根到每个叶节点的延迟尽量相同
  - 总 Wire Length 尽量小
  - 功耗尽量低

多目标优化 + 树结构约束
```

---

#### 2. 为什么 Skew 很难做到 0？

```
理想情况（DME 算法）:
  - 几何对称
  - Wire 模型准确
  - Buffer 延迟一致
  → Skew = 0

实际情况:
  - FF 位置不规则（Placement 决定）
  - Wire 可能绕路（Congestion）
  - Buffer 延迟变化（PVT）
  - Legalization 移动 Buffer
  → Skew > 0

需要迭代优化和平衡技术
```

---

#### 3. CTS 与其他阶段的关系

```
Placement 影响 CTS:
  - FF 位置分散 → CTS 困难
  - FF 聚类 → CTS 容易

CTS 影响 Routing:
  - 时钟网络占用大量 Metal 资源
  - 需要预留 Routing 空间

CTS 影响 Timing:
  - 从 ideal clock 到 propagated
  - Skew 影响 Setup/Hold Slack
```

---

## 🧪 实际例子分析

### 4-bit Counter CTS

还记得 Counter 例子吗？

**时钟网络：**

```
4 个 FF: FF0, FF1, FF2, FF3

Clock Source → Buffer → FFs
```

---

#### TritonCTS 的处理

```
Step 1: Clustering
  - 4 个 FF 分成 2 个簇
  Cluster 1: FF0, FF1 (x = 0-50 um)
  Cluster 2: FF2, FF3 (x = 50-100 um)

Step 2: Topology Generation
  Level 1:
    B1 = merge(FF0, FF1) at (25, y)
    B2 = merge(FF2, FF3) at (75, y)

  Level 2:
    B0 = merge(B1, B2) at (50, y)  → 连到 CLK

Step 3: Buffer Insertion
  B0, B1, B2 位置确定
  选择 Buffer 大小（根据 fanout）

Step 4: Skew Balancing
  检查延迟:
    CLK → B0 → B1 → FF0: 0.25 ns
    CLK → B0 → B1 → FF1: 0.25 ns
    CLK → B0 → B2 → FF2: 0.26 ns ⚠️
    CLK → B0 → B2 → FF3: 0.26 ns ⚠️

  Skew = 0.01 ns (可接受)
```

---

#### 结果

```
从 Day 3 的 STA 报告:

Before CTS:
  launch clock clk (rise edge)   0.00
  clock network delay (ideal)    0.00  ← ideal

After CTS:
  launch clock clk (rise edge)   0.00
  clock network delay (propagated) 0.25  ← propagated

Skew: 约 0.01 ns (报告中体现在 capture clock)
```

**CTS 成功平衡了时钟延迟！** ✅

---

## 📚 总结

### 今天学到的核心知识

#### 1. CTS 的数学本质

```
CTS = 延迟平衡树构建问题

输入: N 个 FF 位置
输出: 时钟树（拓扑 + Buffer）
目标: Minimize Skew + Wirelength + Power
```

---

#### 2. TritonCTS 算法流程

```
1. Clustering: 聚类 FF
2. Topology: 自底向上构建树（DME）
3. Buffering: 插入 Buffer
4. Balancing: 平衡 Skew
5. Legalization: 合法化 Buffer 位置
```

---

#### 3. 常见时钟树拓扑

```
H-Tree:   Skew 最小，Wire 最长
X-Tree:   H-tree 变种
Fish-bone: Wire 短，Skew 大
Binary Tree: 最常用，平衡好
```

---

#### 4. Skew 平衡技术

```
1. Buffer Sizing
2. Wire Snaking
3. Delay Cell Insertion
4. Useful Skew（高级，FC 支持）
```

---

## 🎯 下一步

我们已经理解了 Placement 和 CTS 算法，最后一个核心算法：

### ⏭️ Day 4 继续：Routing 算法（TritonRoute）

布线算法的核心：
- Global Routing vs Detailed Routing
- 网格图模型
- Maze Routing、Pattern Routing
- DRC 处理
- Via 优化

---

**CTS 算法学习完成！准备好学习 Routing 了吗？** 🚀
