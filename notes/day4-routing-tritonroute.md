# Day 4 学习笔记 - Routing 算法深入（TritonRoute）

📅 日期：2026-03-16
🎯 主题：OpenROAD Routing 算法 - TritonRoute
📚 Phase 1: Week 1（算法深入）

---

## 🎯 学习目标

通过学习 TritonRoute 算法，理解：
1. Routing 的本质问题和挑战
2. Global Routing vs Detailed Routing 的区别
3. 网格图（Grid Graph）模型
4. 经典 Routing 算法（Maze Routing、Pattern Routing）
5. DRC（Design Rule Check）处理
6. Via 优化策略

---

## 🛣️ Routing 是什么？

### 问题定义

**输入：**
```
- Placement 结果：所有单元的位置
- CTS 结果：时钟树
- 门网表（Netlist）：所有需要连接的 Net
- Technology File：Metal 层信息、DRC 规则
```

**输出：**
```
- 每个 Net 的物理走线
- 使用的 Metal 层
- Via 位置（层间连接）
```

**目标：**
```
✅ 连接所有 Net
✅ 满足 DRC 规则
✅ 最小化总线长
✅ 避免 Congestion（拥塞）
✅ 优化时序（关键路径优先）
```

---

### 为什么 Routing 很难？

#### 问题规模

假设中等规模设计：
```
Nets: 100,000 个
Pins per net: 平均 3 个
Total connections: 300,000 个

Metal 层: 6-10 层
Grid 分辨率: 100 nm
芯片尺寸: 1mm × 1mm
Grid 数量: 10,000 × 10,000 = 100M 格子

搜索空间: 指数级！
```

---

#### 约束复杂

**Design Rules（设计规则）：**

```
1. Minimum Width（最小宽度）
   Wire width ≥ W_min

2. Minimum Spacing（最小间距）
   Distance between wires ≥ S_min

3. Via Rules（过孔规则）
   Via 尺寸、间距、封装

4. Antenna Rules（天线规则）
   防止工艺损伤

5. Density Rules（密度规则）
   Metal 密度均匀

6. ... 几十条规则
```

**冲突处理：**
```
如果两个 Net 想用同一条 Track:
  → 其中一个必须绕路
  → 可能增加很多线长
  → 可能影响时序
```

---

### Routing 问题的本质

**这是一个 Multi-Commodity Flow 问题（NP-Hard）！**

类比：
```
想象一个城市道路规划：
  - 100,000 辆车（Nets）
  - 每辆车有起点和终点（Pins）
  - 道路有限（Metal Tracks）
  - 不能撞车（DRC）
  - 希望总距离最短

如何规划所有车的路径？
```

**不可能找到全局最优解，只能用启发式算法。**

---

## 🗺️ Global Routing vs Detailed Routing

Routing 分两阶段进行：

### Global Routing（全局布线）

**目的：**规划大致路径，避免拥塞

**方法：**
```
1. 将芯片划分为粗粒度的 Tiles（通常 10-100 um）

   ┌─────┬─────┬─────┬─────┐
   │Tile │Tile │Tile │Tile │
   │  1  │  2  │  3  │  4  │
   ├─────┼─────┼─────┼─────┤
   │Tile │Tile │Tile │Tile │
   │  5  │  6  │  7  │  8  │
   └─────┴─────┴─────┴─────┘

2. 对每个 Net，分配经过的 Tiles

   Net A: Tile 1 → Tile 2 → Tile 3 (粗路径)

3. 检查 Tile 容量（Capacity）

   如果某个 Tile 容量超限 → Congestion
   → 需要重新规划路径
```

**特点：**
```
✅ 快速（粗粒度）
✅ 全局视角（避免拥塞）
❌ 不是实际走线
❌ 不考虑详细 DRC
```

---

### Detailed Routing（详细布线）

**目的：**在 GR 的指导下，生成实际金属走线

**方法：**
```
1. 细粒度 Grid（Track 级别，通常 100-500 nm）

2. 对每个 Net，在分配的 Tiles 内找实际路径

   Net A:
     Global Route: Tile 1 → Tile 2
     Detailed Route:
       (x1,y1,M1) → (x2,y1,M1) → Via → (x2,y2,M2) → ...

3. 满足所有 DRC 规则

4. 处理冲突（如果两个 Net 想用同一 Track）
```

**特点：**
```
✅ 精确（实际走线）
✅ 满足 DRC
✅ 可制造
❌ 慢（细粒度）
❌ 局部视角（可能 rip-up）
```

---

### 类比：GPS 导航

```
Global Routing = 规划高速公路路线
  "从北京到上海：走京沪高速"
  快速，粗略，避开拥堵路段

Detailed Routing = 规划具体车道
  "第 3 车道，保持 2 米车距，前方 500 米换到第 2 车道"
  精确，慢，考虑所有细节
```

---

## 🌍 Global Routing 详解

### 网格图模型（Grid Graph）

将芯片抽象为图：

```
节点（Nodes）= Tiles 中心点
边（Edges）= 相邻 Tiles 之间的连接

例子（4×4 Tiles）:

  1 ─── 2 ─── 3 ─── 4
  │     │     │     │
  5 ─── 6 ─── 7 ─── 8
  │     │     │     │
  9 ─── 10 ── 11 ── 12
  │     │     │     │
  13 ── 14 ── 15 ── 16
```

**边的权重（Cost）：**
```
Cost(edge) = 基础长度 + 拥塞惩罚

If (Tile 容量快满):
  → 增加 Cost（避免走这条路）

If (Tile 是关键路径):
  → 降低 Cost（优先走这条路）
```

---

### Maze Routing（迷宫算法）

最经典的 Routing 算法！

#### Lee 算法（Lee's Algorithm）

**思路：**波的传播

```
给定：Source (起点), Target (终点)

Step 1: 从 Source 开始，标记距离 0

  S(0) ─── · ─── · ─── ·
   │       │     │     │
   · ─── · ─── · ─── ·
   │       │     │     │
   · ─── · ─── · ─── T

Step 2: 向四周扩散，标记距离 1

  S(0) ─ (1) ─── · ─── ·
   │       │     │     │
  (1) ─── · ─── · ─── ·
   │       │     │     │
   · ─── · ─── · ─── T

Step 3: 继续扩散，标记距离 2, 3, ...

  S(0) ─ (1) ─ (2) ─ (3)
   │       │     │     │
  (1) ─ (2) ─ (3) ─ (4)
   │       │     │     │
  (2) ─ (3) ─ (4) ─ (5)
   │       │     │     │
  (3) ─ (4) ─ (5) ─ T(6)

Step 4: 到达 Target 时停止

Step 5: 回溯（Backtrace）找路径
  T(6) ← (5) ← (4) ← (3) ← (2) ← (1) ← S(0)

得到最短路径！
```

---

#### 伪代码

```python
def Lee_Routing(source, target, grid):
    queue = [source]
    distance = {source: 0}
    parent = {}

    # BFS 扩散
    while queue:
        current = queue.pop(0)

        if current == target:
            break  # 找到了

        for neighbor in neighbors(current):
            if neighbor not in distance and grid[neighbor] != blocked:
                distance[neighbor] = distance[current] + 1
                parent[neighbor] = current
                queue.append(neighbor)

    # 回溯路径
    path = []
    node = target
    while node != source:
        path.append(node)
        node = parent[node]
    path.append(source)
    path.reverse()

    return path
```

---

#### 优缺点

**✅ 优点：**
```
- 保证找到最短路径（如果存在）
- 算法简单，易于实现
- 可以处理障碍物
```

**❌ 缺点：**
```
- 速度慢（需要探索大量格子）
- 内存消耗大（存储所有距离）
- 对多 Pin 的 Net 不高效（需要多次运行）
```

---

### A* 算法（启发式 Maze Routing）

**改进 Lee 算法：**加入启发式函数

```
Lee 算法: 盲目扩散，探索所有方向
A* 算法: 优先向目标方向扩散

启发式函数 h(node):
  = Manhattan Distance to Target
  = |x_node - x_target| + |y_node - y_target|

优先级:
  Priority(node) = distance[node] + h(node)
                 = g(n) + h(n)

使用优先队列（Min-Heap）:
  每次扩展 Priority 最小的节点
```

---

#### 例子

```
Source S at (0, 0)
Target T at (3, 3)

Lee 算法扩散:
  均匀向四周，探索很多无用格子

  S → → → ·
  ↓ → → → ·
  ↓ → → → ·
  ↓ → → → T

A* 算法扩散:
  优先向右下（目标方向）

  S → → → ·
  · ↓ → → ·
  · · ↓ → ·
  · · · → T

探索格子更少 → 更快！
```

---

### Pattern Routing（模式布线）

**思路：**预定义常见走线模式，直接使用

#### L-Shape 和 Z-Shape

```
L-Shape:
  S ────────┐
            │
            └────── T

Z-Shape:
  S ────────┐
            │
         ┌──┘
         │
         └────── T
```

**算法：**
```
For 2-Pin Net:
  If (可以直线连接):
    → 直线

  Else if (可以 L-Shape):
    → L-Shape

  Else if (可以 Z-Shape):
    → Z-Shape

  Else:
    → 调用 Maze Routing
```

**✅ 优点：**
```
极快（O(1)）
覆盖大部分简单情况
```

**❌ 缺点：**
```
不能处理复杂 Net
不能处理障碍物
```

---

### Steiner Tree（斯坦纳树）

**问题：**连接多个 Pin（3+ Pin Net）

#### 最小生成树 vs 斯坦纳树

**最小生成树（MST）：**
```
只连接给定的 Pins

  P1 ────── P2
   │
   │
  P3

总线长 = distance(P1,P2) + distance(P1,P3)
```

**斯坦纳树（Steiner Tree）：**
```
允许增加额外节点（Steiner Points）

  P1 ────── S1 ────── P2
             │
            P3

总线长 < MST（S1 是 Steiner Point）
```

---

#### RSMT（Rectilinear Steiner Minimum Tree）

在曼哈顿几何下的斯坦纳树。

**Heuristic 算法：**

```
1. 计算 Bounding Box（包围盒）

   Pins: P1(0,0), P2(5,0), P3(0,5)

   Bounding Box:
     (0,0) ────── (5,0)
       │            │
       │            │
     (0,5) ────── (5,5)

2. 使用 L-Shape 或 Z-Shape 连接

3. 局部优化（减少线长）
```

---

## 🎨 Detailed Routing 详解

### Track Assignment（轨道分配）

**Metal 层的物理结构：**

```
Metal 1 (M1): 水平走线
  Track 1: y = 0.1 um
  Track 2: y = 0.6 um
  Track 3: y = 1.1 um
  ...

Metal 2 (M2): 垂直走线
  Track 1: x = 0.1 um
  Track 2: x = 0.6 um
  Track 3: x = 1.1 um
  ...

Via: 连接不同 Metal 层
```

**Track 容量：**
```
每个 Track 同时只能有一条 Wire
如果两个 Net 要用同一 Track:
  → 其中一个必须换 Track 或绕路
```

---

### Conflict Resolution（冲突解决）

#### Rip-up and Reroute

**问题：**
```
Net A 和 Net B 都想用 Track 1:

Track 1: ────A────────
Track 2: (空闲)
         ────B──── (想用 Track 1，冲突！)
```

**解决方案：**
```
1. Rip-up（拆除）
   拆除 Net B 的当前走线

2. Reroute（重新布线）
   Net B 换到 Track 2

Track 1: ────A────────
Track 2: ────B────────  ✅ 冲突解决
```

---

#### Negotiated Congestion

**思路：**迭代优化

```
算法流程:

Iteration 1:
  对所有 Nets 进行 Routing（允许冲突）
  记录冲突的 Tracks

Iteration 2:
  对冲突的 Tracks 增加 Cost
  重新 Route 部分 Nets
  冲突减少

Iteration 3:
  继续增加 Cost
  重新 Route
  ...

直到：没有冲突或达到最大迭代次数
```

**Cost 函数：**
```
Cost(track) = base_cost + congestion_penalty

congestion_penalty = α × overflow × iteration_count

overflow = 使用量 - 容量
α = 惩罚系数
```

---

### Via 优化

**Via 的问题：**

```
Via = 连接不同 Metal 层的孔

问题:
  ❌ 增加电阻（Resistance）
  ❌ 增加制造成本
  ❌ 可能失效（Reliability 问题）
  ❌ 占用空间
```

**优化目标：**
```
✅ 最小化 Via 数量
✅ Via 聚集（减少 DRC 问题）
✅ 使用 Multi-Cut Via（可靠性）
```

---

#### Via 最小化技术

**1. Layer Assignment（层分配）**

```
优先在一层完成走线:

Bad:
  M1 ─── Via ─── M2 ─── Via ─── M1  (2 Vias)

Good:
  M1 ───────────────────────────── (0 Vias) ✅
```

---

**2. Track Continuity（轨道连续性）**

```
保持在同一 Track:

Bad:
  M1 Track 1 ─── Via ─── M2 ─── Via ─── M1 Track 2

Good:
  M1 Track 1 ──────────────────────────────── ✅
```

---

**3. Multi-Cut Via（多切口过孔）**

```
单 Via:          Multi-Cut Via (2×2):
   □               ■ ■
                   ■ ■

优点:
  ✅ 更可靠（一个失效，其他还工作）
  ✅ 电阻更小
  ✅ 电流承载能力大

缺点:
  ❌ 占用更多空间
```

**使用策略：**
```
关键 Net（时钟、电源）: Multi-Cut Via
普通 Net: 单 Via
```

---

### DRC 处理

**常见 DRC 规则：**

#### 1. Minimum Width（最小宽度）

```
Rule: Wire width ≥ W_min

违规:
  ────▃▃▃──── (太细)

修复:
  ────████──── ✅
```

---

#### 2. Minimum Spacing（最小间距）

```
Rule: Distance ≥ S_min

违规:
  ████▃▃████  (间距太小)

修复:
  ████    ████ ✅
```

---

#### 3. Minimum Area（最小面积）

```
Rule: Wire area ≥ A_min

违规:
  ──  (小孤岛)

修复:
  ████ ✅ (扩展面积)
```

---

#### 4. Via Enclosure（过孔封装）

```
Rule: Via 周围必须有足够 Metal

违规:
  ─┬─  (Via 暴露)
   V

修复:
  ─█─  ✅ (Via 被封装)
   V
```

---

#### 5. Antenna Rule（天线规则）

**问题：**

```
制造过程中，长 Wire 像天线，积累电荷:

     Long Wire (1000 um)
  ─────────────────────┬─── Gate Oxide
                       │
                      ┴ (电荷损伤)
```

**修复：**
```
1. 插入 Diode（二极管）泄放电荷

     Long Wire
  ───────┬────────────┬─── Gate
         │            │
        ─┴─ Diode    ┴

2. 减少 Wire 长度（分段）

3. 上层 Metal（减少电荷积累）
```

---

## 🔧 TritonRoute 算法概览

### 算法流程

```
┌──────────────────────────────────────┐
│ 1. Global Routing (FastRoute 引擎)   │
│    - Tile-based 粗路径规划            │
│    - Congestion-aware                │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 2. Track Assignment (轨道分配)        │
│    - 将 GR 结果映射到实际 Tracks      │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 3. Initial Detailed Routing           │
│    - Panel-based Routing              │
│    - 并行处理                         │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 4. Search and Repair (搜索和修复)     │
│    - 检测 DRC 违规                    │
│    - Rip-up and Reroute               │
│    - 迭代优化                         │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│ 5. Via Optimization (过孔优化)        │
│    - 减少 Via 数量                    │
│    - Multi-Cut Via 插入               │
└──────────────────────────────────────┘
```

---

### TritonRoute 的特点

**✅ 优点：**

1. **高质量**
   - DRC Clean（几乎无违规）
   - 线长接近最优

2. **开源**
   - 代码透明
   - 可学习算法

3. **并行化**
   - Panel-based 处理
   - 利用多核 CPU

4. **工业化**
   - 实际芯片验证
   - Tape-out 可用

---

**⚠️ 局限性：**

1. **速度**
   - 比商业工具慢（2-5x）
   - 大规模设计耗时长

2. **内存消耗**
   - 细粒度 Grid 需要大内存
   - 百万级 Net 可能 OOM

3. **高级优化**
   - 时序驱动优化较弱
   - Shield 插入支持有限
   - Crosstalk 优化基础

---

## 🆚 TritonRoute vs FusionCompiler Routing

### 对比表格

| 特性 | TritonRoute | FusionCompiler |
|------|-------------|----------------|
| **GR 算法** | FastRoute | 专有算法 |
| **DR 算法** | Panel-based | 多算法混合 |
| **时序驱动** | 基础 | 强大（全流程） |
| **Crosstalk** | 不支持 | 完整支持 |
| **Shield 插入** | 有限 | 自动优化 |
| **Via 优化** | 基础 | 智能（Multi-Cut）|
| **DRC 收敛** | 好 | 优秀 |
| **运行时间** | 较慢 | 快（优化好）|
| **内存消耗** | 较大 | 优化好 |
| **质量** | 中等偏上 | 优秀 |

---

### FusionCompiler 的优势

#### 1. 时序驱动 Routing

**TritonRoute：**
```
主要优化线长
对时序关键路径没有特殊处理
```

**FusionCompiler：**
```
根据 Slack 分配优先级:

Critical Path (Slack < 0):
  → 最短路径
  → 最少 Via
  → 优先使用低阻抗 Metal 层

Non-Critical Path:
  → 可以绕路
  → 可以使用拥挤的 Track
```

---

#### 2. Crosstalk 优化

**Crosstalk（串扰）：**

```
问题:
  相邻的两条 Wire，信号互相干扰

  Wire A: ████████████
  Wire B: ████████████  (太近，耦合电容大)

  → Wire A 翻转时，影响 Wire B
  → 可能导致时序错误或功能错误
```

**FusionCompiler 优化：**
```
1. Spacing Rules（间距规则）
   关键 Net 增加间距

2. Shield Insertion（屏蔽线插入）
   在关键 Net 两侧插入 GND/VDD 线

   Wire A: ████████████
   Shield: ════════════ (GND)
   Wire B: ████████████  ✅ 隔离

3. Layer Assignment（层分配）
   关键 Net 使用不同 Metal 层
```

**TritonRoute：**
```
基本不处理 Crosstalk
需要手动设置规则
```

---

#### 3. 多层优化（Multi-Layer Optimization）

**FusionCompiler：**
```
智能选择 Metal 层:

M1-M2: 低层，电阻大，短距离
M3-M4: 中层，平衡，中距离
M5-M6: 高层，电阻小，长距离

关键路径:
  → 优先使用高层（M5-M6）
  → 减少 Wire Delay

时钟网络:
  → 使用最高层（M7-M8）
  → 减少 Skew

电源网络:
  → 使用粗 Metal（M8-M9）
  → 减少 IR Drop
```

**TritonRoute：**
```
基于 Track 可用性选择层
不太考虑性能差异
```

---

## 💡 从 TritonRoute 理解 Routing 本质

### 核心启示

#### 1. Routing 的本质

```
Routing = 图论 + 约束满足问题

给定:
  - N 个 Nets（每个有多个 Pins）
  - M 个 Metal 层
  - DRC 约束

找:
  - 每个 Net 的路径（在图中）
  - 使用的 Metal 层
  - Via 位置

目标:
  - 所有 Net 连通
  - 无冲突
  - 满足 DRC
  - 线长最短
  - 时序最优
```

**多目标优化，NP-Hard！**

---

#### 2. 为什么分 GR 和 DR？

```
如果直接 Detailed Routing:
  - Grid 太细（100nm 级别）
  - 搜索空间巨大
  - 无法在合理时间完成

Global Routing:
  - 粗粒度（10um 级别）
  - 快速规划大致路径
  - 避免全局拥塞

Detailed Routing:
  - 细粒度
  - 在 GR 指导下，局部优化
  - 满足 DRC

分而治之 → 效率提升
```

---

#### 3. Routing 与其他阶段的关系

```
Placement 影响 Routing:
  - 单元密集 → Routing 困难
  - 单元分散 → Wire 长

CTS 影响 Routing:
  - 时钟网络占用大量资源
  - 剩余 Track 减少

Routing 影响 Timing:
  - 实际 Wire Delay 确定
  - Via 增加延迟
  - 最终 STA 结果
```

**P&R 是一个整体！**

---

## 🧪 实际例子分析

### 4-bit Counter Routing

**网表：**
```
4 个 FF: FF0, FF1, FF2, FF3
Adder 逻辑: ADD0, ADD1, ADD2, ADD3
时钟网络: CLK_NET
数据网络: 多个（FF 到 Adder，Adder 到 FF）
```

---

### Global Routing

```
Step 1: 划分 Tiles（假设 4×4）

  ┌─────┬─────┬─────┬─────┐
  │  1  │  2  │  3  │  4  │
  ├─────┼─────┼─────┼─────┤
  │  5  │  6  │  7  │  8  │
  ├─────┼─────┼─────┼─────┤
  │  9  │ 10  │ 11  │ 12  │
  ├─────┼─────┼─────┼─────┤
  │ 13  │ 14  │ 15  │ 16  │
  └─────┴─────┴─────┴─────┘

Step 2: 单元位置
  FF0, ADD0 在 Tile 6
  FF1, ADD1 在 Tile 7
  FF2, ADD2 在 Tile 10
  FF3, ADD3 在 Tile 11

Step 3: 规划 Net 路径
  Net (FF0 → ADD1):
    GR Path: Tile 6 → Tile 7

  Net (ADD1 → FF1):
    GR Path: Tile 7 (同一 Tile)

  时钟网络:
    CLK → Tile 6, 7, 10, 11
```

---

### Detailed Routing

```
Step 1: Track Assignment

  M1 (水平):
    Track 1: FF0.Q → ADD1.A
    Track 2: FF1.Q → ADD2.A
    ...

  M2 (垂直):
    Track 1: 时钟树 Branch
    Track 2: 进位信号
    ...

Step 2: Via 插入

  FF0.Q (M1) ──→ Via ──→ ADD1.A (M2)

Step 3: DRC 检查

  检查所有 Wire 的:
    - Width ✅
    - Spacing ✅
    - Via Enclosure ✅

Step 4: 输出 DEF 文件（包含所有走线坐标）
```

---

### 从 Day 3 的 STA 结果看 Routing 影响

**Placement 后（Wire 估算）：**
```
data arrival time: 0.82 ns (estimated wire delay)
```

**Routing 后（实际 Wire）：**
```
data arrival time: 0.85 ns (actual wire delay)
```

**差异：**
```
Δ = 0.85 - 0.82 = 0.03 ns

原因:
  - 实际走线比 Manhattan 距离长（绕路）
  - Via 增加延迟
  - RC 参数更准确
```

**Slack 变化：**
```
Before Routing: +8.05 ns
After Routing:  +7.82 ns
Δ = -0.23 ns

Routing 导致 Slack 减少 3%
→ 这是正常的
→ 需要在 Placement/CTS 阶段留 Margin
```

---

## 📚 总结

### 今天学到的核心知识

#### 1. Routing 的数学本质

```
Routing = Multi-Commodity Flow 问题（NP-Hard）

输入: Nets + Pins + DRC Rules
输出: 物理走线
目标: 连通 + 无冲突 + 线长短 + 时序优
```

---

#### 2. GR vs DR 两阶段

```
Global Routing:
  - 粗粒度 Tile-based
  - 规划大致路径
  - 避免拥塞

Detailed Routing:
  - 细粒度 Track-based
  - 生成实际走线
  - 满足 DRC
```

---

#### 3. 经典算法

```
Maze Routing (Lee):
  - 保证最短路径
  - 慢，适合简单 Net

A* 算法:
  - 启发式加速
  - 平衡速度和质量

Pattern Routing:
  - 预定义模式
  - 极快，适合大部分 2-Pin Net

Steiner Tree:
  - 多 Pin 优化
  - 减少总线长
```

---

#### 4. DRC 处理

```
常见规则:
  - Minimum Width
  - Minimum Spacing
  - Via Enclosure
  - Antenna Rule

修复技术:
  - Rip-up and Reroute
  - Negotiated Congestion
  - Diode 插入
```

---

#### 5. Via 优化

```
目标: 减少 Via 数量

技术:
  - Layer Assignment
  - Track Continuity
  - Multi-Cut Via（关键 Net）
```

---

## 🎉 Day 4 完整学习总结

今天我们深入学习了 OpenROAD 的三大核心算法：

### 1️⃣ Placement（RePlAce）
```
✅ Global Placement（二次优化 + 密度力）
✅ Legalization（消除重叠）
✅ Detailed Placement（局部优化）
```

### 2️⃣ CTS（TritonCTS）
```
✅ Clustering（FF 聚类）
✅ DME 算法（延迟平衡）
✅ Buffer Insertion（Buffer 插入）
✅ Skew Balancing（Skew 优化）
```

### 3️⃣ Routing（TritonRoute）
```
✅ Global Routing（粗路径规划）
✅ Detailed Routing（精确走线）
✅ Maze Routing / A* 算法
✅ DRC 处理
✅ Via 优化
```

---

### 核心收获

**理解了 P&R 的本质：**
```
Placement = 约束优化（最小化线长 + 满足密度）
CTS       = 延迟平衡（最小化 Skew）
Routing   = 图论搜索（连通 + 满足 DRC）
```

**理解了算法的 Trade-off：**
```
质量 vs 速度
全局最优 vs 局部最优
启发式 vs 精确算法
```

**理解了与 FusionCompiler 的差距：**
```
OpenROAD:
  ✅ 开源、透明、可学习
  ❌ 质量中等、优化有限

FusionCompiler:
  ✅ 质量优秀、全局优化
  ❌ 闭源、昂贵、黑盒

两者互补学习！
```

---

## 🎯 下一步学习方向

### 选项 A: 完成 Week 1
- OpenLane 自动化流程
- 综合以上所有工具

### 选项 B: 实践操作
- 周末安装工具
- 运行 Counter 例子
- 查看真实输出

### 选项 C: 切换到 Phase 2
- GPU 架构深入
- tiny-gpu 代码分析

---

**Day 4 算法深入学习圆满完成！期待下次继续！** 🎉🚀
