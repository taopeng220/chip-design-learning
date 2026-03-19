# Floorplan 深入 - 芯片布图规划的艺术与科学

📅 日期：2026-03-13
🎯 深入理解 Floorplan 的关键决策、优化目标和实战策略

---

## 🎯 为什么 Floorplan 如此重要？

### 核心思想

```
Floorplan = 芯片设计的"建筑规划"

就像盖房子：
  - 先定地基大小（Die Size）
  - 再定各房间位置（Macro Placement）
  - 然后规划水电（Power Network）
  - 最后才能装修（Standard Cell Placement）

如果地基规划错了：
  - 房间太挤 → 后期无法布线
  - 水电不合理 → IR Drop 问题
  - 布局不佳 → 时序无法收敛
```

---

## 📊 Floorplan 的影响范围

### 对整个设计的影响

```
好的 Floorplan                    坏的 Floorplan
─────────────────────────────────────────────────────
✅ 关键路径短                      ❌ 关键路径长
   → Timing 容易满足                  → Timing 违规

✅ 布线通道充足                    ❌ 拥塞严重
   → Routing 快速收敛                 → Routing 失败

✅ 功率网络合理                    ❌ IR Drop 大
   → 供电稳定                         → 功能错误

✅ 热点分散                        ❌ 热点集中
   → 散热均匀                         → 可靠性问题

✅ 利用率合理                      ❌ 过度拥挤/浪费
   → 面积优化                         → 成本增加
```

---

## 🔍 Floorplan 的三大核心决策

### 决策 1: 芯片尺寸（Die Size & Core Size）

#### 什么是 Die 和 Core？

```
┌─────────────────────────────────────┐
│  Die Area（整个芯片）                │
│  ┌───────────────────────────────┐  │
│  │ Core Area（核心逻辑区）         │  │
│  │                               │  │
│  │  ┌─────┐  ┌─────┐            │  │
│  │  │Macro│  │Macro│  Standard  │  │
│  │  │     │  │     │    Cells   │  │
│  │  └─────┘  └─────┘            │  │
│  │                               │  │
│  └───────────────────────────────┘  │
│         ↑ Margin                    │
│    IO Pads, Seal Ring, etc.         │
└─────────────────────────────────────┘
```

#### 关键参数

**1. Utilization（利用率）**

```
Utilization = (Standard Cell Area + Macro Area) / Core Area

例子：
  Standard Cell Area: 100 um²
  Macro Area: 50 um²
  Core Area: 200 um²

  Utilization = (100 + 50) / 200 = 75%
```

**推荐值：**
```
设计类型           | 推荐 Utilization | 原因
──────────────────┼─────────────────┼──────────────────
小设计 (<10K)     | 50-60%          | 给 Routing 留空间
中等设计 (10K-1M) | 60-75%          | 平衡面积和布线
大设计 (>1M)      | 70-85%          | 优化面积，但需要更多优化
高频设计          | 60-70%          | 留空间给时序优化
低功耗设计        | 65-75%          | 平衡功耗和面积
```

**过高/过低的后果：**

```
Utilization 过高（>85%）：
  ❌ 布线通道不足
  ❌ Congestion 严重
  ❌ Timing 难以优化（没空间插 buffer）
  ❌ 可能 Routing 失败

Utilization 过低（<50%）：
  ❌ 芯片面积浪费
  ❌ Wire 长度增加（单元分散）
  ❌ 功耗增加（长线）
  ❌ 成本增加
```

---

**2. Aspect Ratio（长宽比）**

```
Aspect Ratio = Width / Height

例子：
  Square:      100um × 100um  → AR = 1.0
  Rectangle:   200um × 50um   → AR = 4.0
```

**推荐值：**
```
AR = 1.0 ~ 2.0  （接近正方形）

原因：
  ✅ 最短的平均线长
  ✅ 时钟树容易平衡
  ✅ 功率网络对称
  ✅ 热分布均匀
```

**特殊情况：**
```
长条形设计（AR > 3）：
  - 适用场景：受封装限制（如 DIMM 条）
  - 代价：平均线长增加，时序更难
  - 对策：
    * 层次化设计（水平分区）
    * 多个时钟域
    * 精心的 Macro 摆放
```

---

**3. Core to Die Margin**

```
Margin = (Die Size - Core Size) / 2

例子：
  Die: 100um × 100um
  Core: 90um × 90um
  Margin: (100-90)/2 = 5um
```

**Margin 的作用：**
```
1. IO Pads 放置区域
2. Seal Ring（密封环）
3. Corner Cell
4. ESD 保护电路
5. 给 Power Ring 留空间
```

**推荐值：**
```
Margin = 5um ~ 20um（取决于工艺）

Sky130:   约 5-10um
TSMC 7nm: 约 10-20um
```

---

### 决策 2: 宏单元摆放（Macro Placement）

#### 什么是 Macro？

**Macro = 预设计的大模块**

```
常见 Macro 类型：
  - SRAM/Memory（存储器）
  - Analog Block（模拟电路）
  - Hard IP（硬核 IP，如 PCIe, USB）
  - Multiplier（乘法器）
  - Custom Block（定制模块）

特点：
  - 尺寸大（比标准单元大得多）
  - 形状固定（不能拆分）
  - 位置影响整个设计
```

---

#### Macro 摆放的黄金法则

**法则 1: 避免中心摆放（除非必要）**

```
Bad Floorplan（Macro 在中心）：
┌─────────────────────────────┐
│                             │
│      ┌───────────┐          │
│      │           │          │  ← Standard Cells 被分割
│      │   Macro   │          │     在两侧，难以连接
│      │           │          │
│      └───────────┘          │
│                             │
└─────────────────────────────┘

问题：
  ❌ Standard Cells 分散在 Macro 周围
  ❌ 跨 Macro 的连线很长
  ❌ Routing 困难

Good Floorplan（Macro 靠边）：
┌─────────────────────────────┐
│ ┌─────┐                     │
│ │Macro│   Standard Cells    │  ← Cells 连续，易于布线
│ │     │   (连续区域)        │
│ └─────┘                     │
└─────────────────────────────┘

优点：
  ✅ Standard Cells 在连续区域
  ✅ 布线通道顺畅
  ✅ 优化容易
```

---

**法则 2: 考虑连接关系（Connectivity）**

```
设计中的模块连接：
  CPU Core ←→ L1 Cache ←→ L2 Cache

Bad Placement（距离远）：
┌─────────────────────────────┐
│ ┌────┐              ┌────┐ │
│ │CPU │              │L2  │ │  ← L1 和 CPU/L2 都很远
│ └────┘              └────┘ │     数据路径长
│                             │
│         ┌────┐              │
│         │L1  │              │
│         └────┘              │
└─────────────────────────────┘

Wire Length: 很长，Timing 差

Good Placement（聚类）：
┌─────────────────────────────┐
│ ┌────┐┌────┐┌────┐          │
│ │CPU ││L1  ││L2  │          │  ← 紧密相邻
│ └────┘└────┘└────┘          │     数据路径短
│                             │
│    Standard Cells           │
└─────────────────────────────┘

Wire Length: 短，Timing 好
```

**实现方法：**
```tcl
# FusionCompiler / OpenROAD
# 创建 Macro Cluster
create_cluster macro_cluster
add_to_cluster macro_cluster {CPU L1_Cache L2_Cache}
```

---

**法则 3: 对齐和通道（Alignment & Channel）**

```
Bad Alignment（不对齐）：
┌─────────────────────────────┐
│ ┌─────┐                     │
│ │  A  │    ┌─────┐          │  ← Macro 高度不同
│ └─────┘    │  B  │          │     造成碎片化空间
│            │     │          │     Standard Cell 难摆放
│            └─────┘          │
└─────────────────────────────┘

Good Alignment（对齐）：
┌─────────────────────────────┐
│ ┌─────┐  ┌─────┐            │
│ │  A  │  │  B  │            │  ← 底部对齐
│ │     │  │     │            │     形成规则空间
│ └─────┘  └─────┘            │
│ ────────────────────        │  ← Routing Channel
│    Standard Cells           │
└─────────────────────────────┘
```

**Channel Routing（通道布线）：**
```
在 Macro 之间留出空间（Channel）：
  - 用于 Routing（布线通道）
  - 用于 Clock Tree
  - 用于 Power Straps

推荐 Channel 宽度：
  - 最小：5-10 个 standard cell 行
  - 推荐：10-20 个 standard cell 行
  - 高频设计：20-30 个 standard cell 行
```

---

**法则 4: 对称性（Symmetry）**

```
对称布局的好处：

时钟树：
┌─────────────────────────────┐
│        Clock Root            │
│            │                 │
│      ┌─────┴─────┐          │
│      │           │          │
│   ┌──┴──┐     ┌──┴──┐      │
│   │  A  │     │  B  │      │  ← A 和 B 对称
│   └─────┘     └─────┘      │     Clock Latency 相同
└─────────────────────────────┘

功率网络：
┌─────────────────────────────┐
│ VDD─┬───────────┬───────VDD │
│     │           │           │  ← 对称的 Power Strap
│  ┌──┴──┐     ┌──┴──┐       │     IR Drop 均衡
│  │  A  │     │  B  │       │
│  └─────┘     └─────┘       │
│ VSS─┴───────────┴───────VSS │
└─────────────────────────────┘
```

---

#### Macro 摆放的优化目标

**多目标优化问题：**

```
Minimize:
  1. Total Wire Length（总线长）
       HPWL = Σ (BoundingBox 半周长)

  2. Congestion（拥塞）
       避免过度密集的区域

  3. Timing Violation（时序违规）
       关键路径要短

  4. IR Drop
       功率网络要合理

Subject to:
  - Macro 不能重叠
  - Macro 必须对齐到 placement grid
  - 保留足够的 routing channel
  - 满足对称性要求（如果有）
```

---

### 决策 3: 功率规划（Power Planning）

#### 功率网络结构

**层次结构：**

```
┌─────────────────────────────────────────┐
│  1. Power Pads（功率焊盘）               │
│     - 从外部供电                         │
│     - 多个 VDD/VSS pads                 │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  2. Power Ring（功率环）                 │
│     - 包围整个 Core                      │
│     - 粗金属（Top Metal）                │
│     - 低电阻                             │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  3. Power Straps（功率条带）             │
│     - 横竖交叉的网格                     │
│     - 中层金属（M5-M7）                  │
│     - 覆盖整个芯片                       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  4. Power Rails（功率轨）                │
│     - Standard Cell 的供电               │
│     - 底层金属（M1）                     │
│     - 每行 Cell 都有                     │
└─────────────────────────────────────────┘
```

---

**图示：**

```
俯视图：

┌──────────────────────────────────────┐
│ ╔════════════════════════════════╗  │  ← Power Ring (VDD)
│ ║  ═══╬═══╬═══╬═══╬═══╬═══╬═══  ║  │  ← Power Straps (竖)
│ ║     ║   ║   ║   ║   ║   ║     ║  │
│ ║  ═══╬═══╬═══╬═══╬═══╬═══╬═══  ║  │  ← Power Straps (横)
│ ║     ║   ║   ║   ║   ║   ║     ║  │
│ ║  ═══╬═══╬═══╬═══╬═══╬═══╬═══  ║  │
│ ║     ║   ║   ║   ║   ║   ║     ║  │
│ ║  Standard Cells with Rails     ║  │
│ ║     (M1 power rails)            ║  │
│ ╚════════════════════════════════╝  │
│                                      │
└──────────────────────────────────────┘
```

---

#### 功率规划的关键参数

**1. Strap Width & Spacing**

```
Strap Width:
  - 太窄：电阻大，IR Drop 大
  - 太宽：占用布线资源

推荐：
  VDD Strap Width = 1-5 um（取决于电流）
  Spacing = 50-200 um（取决于设计密度）

计算公式：
  R = ρ × L / (W × T)

  其中：
    ρ = 金属电阻率
    L = 长度
    W = Strap 宽度
    T = 金属厚度

  目标：IR Drop < 5% VDD
```

---

**2. Strap Layer Assignment**

```
典型分配（以 7-metal 工艺为例）：

M7 (Top):    Power Ring（最粗，全局分配）
M6:          Horizontal Power Straps
M5:          Vertical Power Straps
M4:          Signal Routing
M3:          Signal Routing
M2:          Signal Routing
M1 (Bottom): Power Rails + Local Signals
```

---

**3. Macro 的功率连接**

```
Macro 通常有自己的 Power Pin：

方法 1: Direct Connection（直接连接）
┌─────────────────────┐
│ ═════════════════   │  ← Power Strap
│     │ VDD Pin       │
│ ┌───┴───────────┐   │
│ │               │   │
│ │     Macro     │   │
│ │               │   │
│ └───┬───────────┘   │
│     │ VSS Pin       │
│ ═════════════════   │
└─────────────────────┘

方法 2: Ring Connection（环形连接）
┌─────────────────────┐
│     Power Strap     │
│ ┌═══════════════┐   │  ← Macro 周围的环
│ ║ ┌───────────┐ ║   │
│ ║ │   Macro   │ ║   │
│ ║ └───────────┘ ║   │
│ └═══════════════┘   │
└─────────────────────┘
```

---

## 🎨 Floorplan 策略

### 策略 1: Bottom-Up（自底向上）

**适用场景：**
- 有明确的层次结构
- 各模块已经设计好
- 大型设计（>1M gates）

**流程：**
```
1. 先做每个子模块的 Floorplan
   Module A: 100um × 50um
   Module B: 80um × 60um
   Module C: 120um × 40um

2. 再在顶层摆放这些模块
   ┌─────────────────────┐
   │ ┌────┐  ┌────┐      │
   │ │ A  │  │ B  │      │
   │ └────┘  └────┘      │
   │                     │
   │      ┌────┐         │
   │      │ C  │         │
   │      └────┘         │
   └─────────────────────┘

3. 顶层添加 glue logic
```

**优点：**
- ✅ 模块化，易于管理
- ✅ 可以并行设计
- ✅ 便于复用

**缺点：**
- ⚠️ 子模块边界可能不是最优
- ⚠️ 全局优化困难

---

### 策略 2: Top-Down（自顶向下）

**适用场景：**
- 平坦设计（Flat）
- 中小型设计
- 需要全局优化

**流程：**
```
1. 先确定整个芯片的 Floorplan
   - Die Size
   - IO 位置
   - 大的分区

2. 再细化各区域的布局
   - Macro 摆放
   - Standard Cell 区域

3. 最后 Placement
```

**优点：**
- ✅ 全局最优
- ✅ 灵活性高

**缺点：**
- ⚠️ 复杂度高
- ⚠️ 难以并行

---

### 策略 3: 数据流驱动（Dataflow-Driven）

**核心思想：**
根据数据流向摆放模块

**示例：数字信号处理（DSP）流水线**

```
数据流：
Input → FFT → Filter → IFFT → Output

Floorplan（水平流水线）：
┌─────────────────────────────────────┐
│  ┌───┐  ┌───┐  ┌──────┐  ┌────┐   │
│→ │FFT│→ │FIR│→ │ IFFT │→ │Out │ → │
│  └───┘  └───┘  └──────┘  └────┘   │
└─────────────────────────────────────┘

优点：
  ✅ 数据路径短
  ✅ Pipeline 高效
  ✅ Timing 容易收敛
```

---

### 策略 4: 时序驱动（Timing-Driven）

**核心思想：**
优先优化关键路径

**步骤：**
```
1. 识别关键路径
   例如：DFF1 → ALU → MUX → DFF2（Slack = -0.5ns）

2. 将关键路径上的模块靠近摆放
   ┌─────────────────────┐
   │ ┌────┬────┬────┐    │
   │ │DFF1│ALU │MUX │DFF2│  ← 紧密相邻
   │ └────┴────┴────┘    │
   │                     │
   │  其他模块            │
   └─────────────────────┘

3. 非关键路径可以分散
```

**在 FusionCompiler 中：**
```tcl
# 识别关键路径
report_timing -max_paths 100 -nworst 10

# 创建时序驱动的 Placement Bound
set critical_cells [get_cells -of [get_timing_paths]]
create_bounds -name critical_region \
  -coordinate {10 10 50 50} \
  $critical_cells
```

---

## 🔧 Floorplan 的实战技巧

### 技巧 1: 利用率的精细控制

**问题：** 不同区域可能需要不同的利用率

**解决：** 分区设置

```tcl
# FusionCompiler
# 高速区域（时序关键）
set_utilization -region region_critical 0.60

# 普通区域
set_utilization -region region_normal 0.75

# 低速区域（可以挤一点）
set_utilization -region region_slow 0.80
```

```
Floorplan 效果：
┌─────────────────────────────────┐
│ Critical (60%)  │ Normal (75%)  │
│ ░░░░░░░░░░░░    │ ████████████  │
│ ░░░░░░░░░░░░    │ ████████████  │
│─────────────────┼───────────────│
│  Slow (80%)                     │
│  ██████████████████████████     │
└─────────────────────────────────┘

好处：
  - 关键路径区域宽松，易于优化
  - 非关键区域紧凑，节省面积
```

---

### 技巧 2: Halo（光环）和 Blockage

**Halo = 在 Macro 周围保留空间**

```
Without Halo（太挤）：
┌─────────────────────┐
│ ░░┌───────┐░░       │
│ ░░│ Macro │░░       │  ← Standard Cells 贴边
│ ░░└───────┘░░       │     Routing 困难
└─────────────────────┘

With Halo（宽松）：
┌─────────────────────┐
│    ┌───────┐        │
│  · │ Macro │ ·      │  ← Halo（禁止摆放）
│    └───────┘        │     Routing Channel
│ ░░░░░░░░░░░░░░      │
└─────────────────────┘
```

**设置方法：**
```tcl
# FusionCompiler / OpenROAD
set_halo \
  -left 5 \
  -right 5 \
  -top 5 \
  -bottom 5 \
  [get_cells macro_inst]
```

---

### 技巧 3: Pin Assignment 优化

**问题：** Macro 的 Pin 位置影响连线长度

**策略：** 将常用 Pin 放在靠近使用者的一侧

```
Bad Pin Assignment:
┌─────────────────────┐
│     ┌───────┐       │
│     │ RAM   │       │
│ ·WE │       │ D[0]· │  ← Write Enable 在左
│ ·RE │       │ D[1]· │     Data 在右
│     └───────┘       │     但使用者都在左边
│                     │
│  ┌────┐             │
│  │CPU │             │  ← CPU 在左边
│  └────┘             │     连线要绕过 RAM
└─────────────────────┘

Good Pin Assignment:
┌─────────────────────┐
│     ┌───────┐       │
│ ·WE │ RAM   │       │  ← 所有常用 Pin 在左
│ ·RE │       │       │     靠近 CPU
│ ·D[]│       │       │
│     └───────┘       │
│  ┌────┐             │
│  │CPU │             │  ← 连线很短
│  └────┘             │
└─────────────────────┘
```

**在 OpenROAD 中：**
```tcl
# 为 Macro 设置 Pin 方向偏好
set_macro_pin_direction -macro RAM_inst \
  -pin {WE RE D[*]} \
  -side left
```

---

### 技巧 4: 分区（Partitioning）

**大设计的必备策略**

```
Physical Partitioning（物理分区）：

划分原则：
  1. 最小化跨分区的连线
  2. 平衡各分区的面积
  3. 尊重时钟域边界

示例：
┌─────────────────────────────┐
│ Partition 1 │ Partition 2   │
│  (Clock A)  │  (Clock B)    │
│             │               │
│  ░░░░░░     │   ████████    │
│  ░░░░░░     │   ████████    │
├─────────────┼───────────────┤
│ Partition 3 │ Partition 4   │
│  (Clock A)  │  (Clock C)    │
│  ░░░░░░     │   ▓▓▓▓▓▓▓▓    │
└─────────────────────────────┘

好处：
  - 降低单个 Placement 的复杂度
  - 可以并行优化
  - 便于分析和调试
```

---

## 📊 Floorplan 评估指标

### 如何判断 Floorplan 的好坏？

**指标 1: Wire Length（线长）**

```
Total HPWL (Half-Perimeter Wire Length):
  HPWL = Σ (BoundingBox 半周长)

好：HPWL 小 → 线短 → Timing 好
坏：HPWL 大 → 线长 → Timing 差

检查方法：
  report_design -physical
```

---

**指标 2: Congestion（拥塞）**

```
Congestion Map（拥塞热图）：

Low Congestion（好）:
┌─────────────────────┐
│ ░░░░░░ ░░ ░░░░░    │  ← 均匀分布
│ ░░ ░░░░░ ░░░░░░    │
│ ░░░ ░░░░░░ ░░░     │
└─────────────────────┘

High Congestion（坏）:
┌─────────────────────┐
│ ░░░░░░ ████████     │  ← 有热点
│ ░░░░░░ ████████     │     布线会失败
│ ░░░░░░ ████████     │
└─────────────────────┘

检查方法：
  report_congestion
  show_congestion_map
```

---

**指标 3: Timing (Estimated)（时序估算）**

```
即使在 Floorplan 阶段，也可以估算时序：

estimate_timing:
  - 基于 Macro 位置
  - 估算 Wire Delay
  - 粗略的 Slack

目标：
  - 所有路径 Estimated Slack > 20% Period
  - 例如：10ns 周期 → Slack > 2ns

如果不满足：
  → 调整 Floorplan
```

---

**指标 4: Utilization Distribution（利用率分布）**

```
检查各区域的利用率是否均衡：

Good（均衡）:
┌─────────────────────┐
│ 70%  │ 75%  │ 72%  │  ← 差异不大
├──────┼──────┼──────┤
│ 68%  │ 73%  │ 71%  │
└─────────────────────┘

Bad（不均）:
┌─────────────────────┐
│ 50%  │ 95%  │ 60%  │  ← 95% 太高！
├──────┼──────┼──────┤     会成为瓶颈
│ 65%  │ 40%  │ 70%  │
└─────────────────────┘
```

---

## 🆚 FusionCompiler vs OpenROAD Floorplan 对比

### FusionCompiler

**命令：**
```tcl
# 自动 Floorplan
initialize_floorplan \
  -core_utilization 0.7 \
  -core_offset {10 10 10 10}

# 自动 Macro 摆放
create_placement -floorplan

# 智能优化
optimize_floorplan
```

**特点：**
- ✅ 高度自动化
- ✅ 智能 Macro 摆放
- ✅ 全局优化
- ⚠️ 黑盒，难以精细控制

---

### OpenROAD

**命令：**
```tcl
# 手动指定 Floorplan
initialize_floorplan \
  -die_area "0 0 100 100" \
  -core_area "5 5 95 95"

# 手动或半自动 Macro 摆放
# 方法 1: 手动指定坐标
place_cell -cell macro1 -location {10 10}

# 方法 2: 使用 TritonFP（自动摆放）
macro_placement \
  -halo_width 5
```

**特点：**
- ✅ 完全控制
- ✅ 透明，可学习
- ⚠️ 需要更多手动调整
- ⚠️ 优化能力不如 FC

---

## 💡 实战案例：如何优化一个坏的 Floorplan

### 案例背景

```
设计：简单的 RISC-V CPU
模块：
  - CPU Core（Standard Cells）
  - Instruction Cache（SRAM Macro，128KB）
  - Data Cache（SRAM Macro，128KB）
  - Register File（SRAM Macro，2KB）

性能目标：500MHz（Period = 2ns）
```

---

### Bad Floorplan（初始）

```
┌─────────────────────────────────┐
│                                 │
│        ┌──────────┐             │
│        │   I$     │             │  ← Cache 在中间
│        │(128KB)   │             │
│        └──────────┘             │
│  ┌──────────┐                   │
│  │   D$     │     ┌──┐          │
│  │(128KB)   │     │RF│          │  ← 模块分散
│  └──────────┘     └──┘          │
│                                 │
│         CPU Core (Cells)        │
│         ░░░░░░░░░░░░░░░░        │
└─────────────────────────────────┘

问题诊断：
  ❌ I$ 在中间，分割了 Standard Cell 区域
  ❌ D$ 和 CPU Core 距离远
  ❌ RF（寄存器文件）太远
  ❌ Congestion 高（Core 被 Cache 包围）

Time分析：
  Critical Path: RF → ALU → D$
  Wire Delay: 1.2ns（太长！）
  Slack: -0.3ns ❌
```

---

### Good Floorplan（优化后）

```
┌─────────────────────────────────┐
│ ┌──────────┐                    │
│ │   I$     │   CPU Core         │  ← Cache 靠边
│ │(128KB)   │   ░░░░░░░░         │
│ │          │   ░░░░░░░░         │
│ └──────────┘   ░░┌──┐░░         │  ← RF 靠近 Core
│                ░░│RF│░░         │
│ ┌──────────┐   ░░└──┘░░         │
│ │   D$     │   ░░░░░░░░         │  ← D$ 靠近 Core
│ │(128KB)   │   ░░░░░░░░         │
│ └──────────┘                    │
└─────────────────────────────────┘

优化措施：
  ✅ I$ 和 D$ 移到边上
  ✅ CPU Core 形成连续区域
  ✅ RF 紧邻 Core（高频访问）
  ✅ D$ 紧邻 Core（数据路径短）

时序分析：
  Critical Path: RF → ALU → D$
  Wire Delay: 0.4ns（缩短了 0.8ns！）
  Slack: +0.5ns ✅

面积：
  相同的 Die Size
  但 Routing 更容易收敛
```

---

## 🎯 Floorplan 的黄金法则总结

### 10 条黄金法则

1. **Utilization 适中（60-75%）**
   - 太高 → Routing 失败
   - 太低 → 面积浪费

2. **Macro 靠边，不在中心**
   - 给 Standard Cells 连续空间

3. **考虑连接关系**
   - 相关模块靠近
   - 减少 Wire Length

4. **对齐和通道**
   - Macro 对齐
   - 留出 Routing Channel

5. **对称性**
   - 时钟树平衡
   - 功率网络对称

6. **数据流优化**
   - 按数据流向摆放
   - Pipeline 高效

7. **时序驱动**
   - 关键路径优先优化
   - 非关键路径可以宽松

8. **功率规划提前做**
   - Power Ring + Straps
   - 避免 IR Drop

9. **使用 Halo 和 Blockage**
   - 给 Macro 留空间
   - 避免过度拥挤

10. **迭代优化**
    - Floorplan 不是一次完成
    - 根据 Placement/Routing 反馈调整

---

## 🤔 思考题

### Q1: 为什么 Macro 在中心是坏的？

**答案：**
- Standard Cells 被分割成多个区域
- 跨 Macro 的连线长
- Routing 困难
- Congestion 高

---

### Q2: 如果设计有两个时钟域，Floorplan 应该怎么做？

**答案：**
- 物理分区，分别摆放两个时钟域
- 在边界处留出跨时钟域的同步电路区域
- 避免时钟树交叉

---

### Q3: 一个好的 Floorplan，能提升多少性能？

**答案：**
- 线长可以减少 30-50%
- Timing Slack 可以提升 20-30%
- 甚至可以让本来无法收敛的设计能够收敛
- **关键：Floorplan 是优化的基础！**

---

**您理解 Floorplan 的重要性了吗？** 😊
