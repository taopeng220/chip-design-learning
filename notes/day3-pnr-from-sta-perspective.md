# 从 STA 角度理解物理实现（P&R）

📅 日期：2026-03-13
🎯 针对熟悉 STA 但不熟悉 P&R 操作的学习者

---

## 💡 核心思想

**您熟悉的 STA 等式：**

```
Slack = Required Time - Arrival Time

其中：
Arrival Time = Launch Clock Delay + Cell Delay + Wire Delay
Required Time = Capture Clock Delay + Period - Setup Time
```

**P&R 的本质就是：**
通过物理实现的各个步骤，**控制和优化这个等式中的各项延迟**！

---

## 🔍 STA 中的延迟来自哪里？

### 在综合后（Yosys 输出）

**这时候的网表：**
```verilog
AND2_X1 u1 (.A(a), .B(b), .Z(c));
DFF u2 (.D(c), .CK(clk), .Q(q));
```

**STA 分析时：**
```
Cell Delay:
  - AND2_X1: 0.5ns  ← 来自 Liberty 文件
  - DFF: 0.3ns      ← 来自 Liberty 文件

Wire Delay: ???    ← 未知！没有布局布线！
Clock Delay: ???   ← 未知！没有时钟树！
```

**问题：** 综合后的 STA 是**估算**，不准确！

---

### P&R 后（OpenROAD 输出）

**经过物理实现：**
```
每个单元有了实际位置：
  AND2_X1 u1 在 (100, 200)
  DFF u2 在 (150, 200)

连线有了实际走线：
  u1.Z → u2.D 的线长 = 50um
  电阻 = 0.1Ω/um × 50um = 5Ω
  电容 = 0.2fF/um × 50um = 10fF

Wire Delay = RC delay = 5Ω × 10fF = 50ps

时钟树有了实际结构：
  Clock Delay = 0.8ns
```

**现在：** STA 分析是**精确**的！

---

## 🎯 P&R 各步骤的时序影响

### 全局视图

```
综合网表（Yosys）
    ↓
  【时序未知】
    ↓
┌─────────────────────────────────────┐
│  Floorplan（布图规划）                │
│                                     │
│  决定：芯片尺寸、宏单元位置           │
│  影响：Wire Delay 的大致范围          │
│  此时：Wire Delay 仍是估算            │
└─────────────────────────────────────┘
    ↓
  【Wire Delay = 粗估】
    ↓
┌─────────────────────────────────────┐
│  Placement（布局）                   │
│                                     │
│  决定：每个标准单元的精确位置          │
│  影响：Wire Delay 变精确              │
│  此时：可以计算线长和负载             │
└─────────────────────────────────────┘
    ↓
  【Wire Delay = 较准确】
    ↓
┌─────────────────────────────────────┐
│  CTS（时钟树综合）                   │
│                                     │
│  决定：时钟网络的结构                 │
│  影响：Clock Delay 和 Skew           │
│  此时：时序约束可以验证               │
└─────────────────────────────────────┘
    ↓
  【Clock Delay = 精确】
    ↓
┌─────────────────────────────────────┐
│  Routing（布线）                     │
│                                     │
│  决定：每条线的实际走线路径            │
│  影响：Wire Delay 最终确定            │
│  此时：寄生参数提取，STA 最准确        │
└─────────────────────────────────────┘
    ↓
  【所有 Delay 精确】
    ↓
  最终 GDS
```

---

## 📐 详解：Floorplan（布图规划）

### 是什么？

**Floorplan 就是决定：**
- 芯片的形状和尺寸（Die Size, Core Size）
- 大的模块（Macro）放在哪里
- 电源网络的结构
- IO Pad 的位置

### 类比理解

```
想象设计一座房子：

Floorplan = 画平面图
  - 房子多大？
  - 卧室、客厅、厨房在哪？
  - 水电管道怎么走？

还没有：
  - 家具摆放（那是 Placement）
  - 具体线路（那是 Routing）
```

---

### 对时序的影响

**关键时序参数：Die Size**

```
场景 1: Die Size 太小
┌─────────────┐
│  密集！      │  ← 单元挤在一起
│ □□□□□□□□    │     Wire 短 ✅
│ □□□□□□□□    │     但拥塞 ❌
└─────────────┘
Wire Delay: 小（线短）
Routing: 困难（太挤）

场景 2: Die Size 太大
┌─────────────────────────┐
│                         │
│   □    □    □           │  ← 单元分散
│                         │     Wire 长 ❌
│        □    □           │     但宽松 ✅
└─────────────────────────┘
Wire Delay: 大（线长）
Routing: 容易（空间大）

场景 3: Die Size 合适
┌─────────────────┐
│  □□□  □□□       │  ← 平衡
│  □□□  □□□       │
└─────────────────┘
Wire Delay: 中等
Routing: 平衡
```

**对 STA 的影响：**
```
Die Size 太小：
  - Wire Delay 小 ✅
  - 但可能 Routing 失败，需要 detour（绕路）
  - 最终 Wire Delay 反而大 ❌

Die Size 太大：
  - Wire Delay 大 ❌
  - 功耗也大 ❌

最佳：根据 Utilization（利用率）选择
  - 通常 60-80% utilization
```

---

### OpenROAD Floorplan 命令

```tcl
initialize_floorplan \
  -die_area "0 0 1000 1000" \    # Die 尺寸 1000um × 1000um
  -core_area "10 10 990 990" \    # Core 区域（留 margin）
  -site unit                      # 标准单元格子

# 设置 IO
place_pins -hor_layers M3 M5 -ver_layers M2 M4

# 生成电源网络
pdngen
```

**此时的 STA：**
```
report_checks

Warning: Wire loads are estimated
Slack: -2.5ns  ← 不准确！只是估算
```

---

## 📍 详解：Placement（布局）

### 是什么？

**Placement 就是决定：**
每一个标准单元的精确位置（坐标）

### 类比理解

```
继续房子的类比：

Placement = 摆放家具
  - 沙发放在客厅的哪个角落
  - 床放在卧室的哪个位置
  - 桌子、椅子的具体摆放

目标：
  - 方便使用（信号路径短 = Wire Delay 小）
  - 不拥挤（Routing 容易）
  - 美观（工整对齐）
```

---

### Placement 的两个阶段

#### 1️⃣ Global Placement（全局布局）

**目标：** 找到大致位置，最小化线长

```
初始状态（随机）：
┌─────────────────┐
│ □  □            │
│        □  □     │
│  □         □    │
└─────────────────┘

优化后（聚类）：
┌─────────────────┐
│ □□□             │  ← 相关的单元靠近
│ □□□             │
│    □□□          │
└─────────────────┘
```

**算法：**
- 目标函数：最小化 HPWL（Half-Perimeter Wire Length）
- 约束：密度均匀（避免过度拥挤）

**OpenROAD 使用：** RePlAce（学术界著名算法）

---

#### 2️⃣ Detailed Placement（详细布局）

**目标：** 精细调整，对齐到标准单元格子

```
Global Placement（可能重叠）：
┌─────────────────┐
│ □□              │
│  □□  ← 重叠！    │
└─────────────────┘

Detailed Placement（合法化）：
┌─────────────────┐
│ □ □             │  ← 对齐格子
│ □ □             │     无重叠
└─────────────────┘
```

**OpenROAD 使用：** OpenDP（详细布局）

---

### 对时序的影响

**Placement 决定了 Wire Delay！**

```
例子：关键路径

DFF1 → AND → OR → DFF2

Bad Placement（分散）：
┌─────────────────────────┐
│ DFF1                    │  ← 距离远
│                         │
│            AND          │     Wire 长 ❌
│                         │
│                    OR   │     Wire Delay 大
│                         │
│                    DFF2 │
└─────────────────────────┘

Wire Delay: ~500ps
Slack: -150ps  ← 时序违规！

Good Placement（紧凑）：
┌─────────────────────────┐
│ DFF1→AND→OR→DFF2        │  ← 距离近
│                         │     Wire 短 ✅
│                         │     Wire Delay 小
└─────────────────────────┘

Wire Delay: ~50ps
Slack: +300ps  ← 时序满足！
```

---

### Placement 的优化目标

**多目标优化：**

1. **最小化线长**（Wire Delay）
   ```
   HPWL = Σ (线长)
   ```

2. **时序驱动**（Timing-Driven）
   ```
   优先优化关键路径（Slack < 0 的路径）
   ```

3. **避免拥塞**（Congestion）
   ```
   密度约束：每个区域不超过 X% 利用率
   ```

---

### OpenROAD Placement 命令

```tcl
# Global Placement
global_placement \
  -density 0.7 \              # 70% 利用率
  -timing_driven              # 时序驱动

# Detailed Placement
detailed_placement

# 此时可以做 STA
report_checks

Slack: -0.5ns  ← 比 Floorplan 后准确多了
                 （但仍有 Clock Delay 误差）
```

---

## ⏰ 详解：CTS（Clock Tree Synthesis）

### 是什么？

**CTS 就是：**
构建时钟分配网络，把时钟信号从源点传递到所有寄存器

### 为什么需要 CTS？

**回顾 Setup Time 公式：**

```
Setup Constraint:
Arrival Time at DFF2.D ≤ Capture Clock Arrival + Period - Setup

如果：
  - Launch Clock Delay = 0.5ns
  - Capture Clock Delay = 1.2ns

Skew = 1.2ns - 0.5ns = 0.7ns

问题：Skew 太大，浪费 Period！
```

**CTS 的目标：**
```
最小化 Clock Skew（时钟偏斜）

理想：所有 DFF 的 Clock Delay 相同
  - Launch Clock Delay = 0.8ns
  - Capture Clock Delay = 0.8ns
  - Skew = 0ns  ← 完美！
```

---

### CTS 的结构

**没有 CTS（直接连线）：**

```
        CLK Source
             │
    ┌────────┼────────┬────────┐
    │        │        │        │
   DFF1     DFF2     DFF3    DFF4

问题：
  - 扇出太大（1 驱动 N 个 DFF）
  - 负载不平衡
  - Skew 大
```

**有 CTS（时钟树）：**

```
        CLK Source
             │
          ┌──┴──┐  ← Buffer
          │     │
      ┌───┴─┐ ┌─┴───┐
      │     │ │     │
    DFF1  DFF2 DFF3 DFF4

优点：
  - 平衡的树形结构
  - 每个分支延迟相同
  - Skew 小（几十 ps）
```

---

### CTS 的关键概念

#### 1️⃣ Clock Latency（时钟延迟）

```
从 CLK Source 到 DFF.CK 的延迟

CTS 前：未知（估算 0 或经验值）
CTS 后：精确（实际 buffer 链延迟）
```

#### 2️⃣ Clock Skew（时钟偏斜）

```
不同 DFF 之间的 Clock Latency 差异

Skew = max(Latency) - min(Latency)

目标：Skew < 50ps（10% of period）
```

#### 3️⃣ Clock Tree Topology（拓扑结构）

**常见结构：**

**H-Tree（H 型树）：**
```
        Root
         │
    ┌────┼────┐
    │    │    │
   ┌┴┐  ┌┴┐  ┌┴┐
   │ │  │ │  │ │
  DFF DFF DFF DFF

优点：对称，Skew 小
缺点：Buffer 多，功耗大
```

**Binary Tree（二叉树）：**
```
      Root
       │
    ┌──┴──┐
    │     │
  ┌─┴─┐ ┌─┴─┐
  │   │ │   │
 DFF DFF DFF DFF

优点：简单
缺点：不对称，Skew 可能大
```

---

### 对时序的影响

**CTS 前后的 STA 对比：**

```
CTS 前：
─────────────────────────────────────
Path: DFF1.Q → DFF2.D

Launch Clock (ideal): 0.0ns
  + Cell Delay: 0.5ns
  + Wire Delay: 0.3ns
Arrival Time: 0.8ns

Capture Clock (ideal): 0.0ns + Period
Required Time: 2.0ns - 0.1ns = 1.9ns

Slack: 1.9 - 0.8 = 1.1ns  ← 不准确！

CTS 后：
─────────────────────────────────────
Path: DFF1.Q → DFF2.D

Launch Clock Latency: 0.85ns  ← 实际延迟
  + Cell Delay: 0.5ns
  + Wire Delay: 0.3ns
Arrival Time: 1.65ns

Capture Clock Latency: 0.87ns  ← 实际延迟
Capture Clock: 0.87ns + Period
Required Time: 2.87ns - 0.1ns = 2.77ns

Slack: 2.77 - 1.65 = 1.12ns  ← 精确！

Skew = 0.87 - 0.85 = 20ps  ← 很小
```

---

### OpenROAD CTS 命令

```tcl
# 运行 CTS
clock_tree_synthesis \
  -root_buf BUFX4 \           # 时钟 buffer 类型
  -buf_list "BUFX2 BUFX4" \   # 可用的 buffer
  -sink_clustering_size 5     # 聚类大小

# CTS 后的 STA
report_checks -path_delay min_max

Slack (Setup): +0.8ns  ← 更准确
Slack (Hold): +0.05ns  ← Hold 也要检查
```

---

## 🛤️ 详解：Routing（布线）

### 是什么？

**Routing 就是：**
为每一条连线（net）找到实际的金属走线路径

### 类比理解

```
继续房子的类比：

Routing = 铺设电线和水管
  - 家具（单元）已经摆好了
  - 时钟（时钟树）已经搭好了
  - 现在要连接所有电器

目标：
  - 所有设备都连上
  - 线路不交叉（或通过过孔）
  - 线路最短（Wire Delay 小）
```

---

### Routing 的两个阶段

#### 1️⃣ Global Routing（全局布线）

**目标：** 为每条线规划大致路径（不精确到具体轨道）

```
芯片划分成 Grid：
┌───┬───┬───┬───┐
│   │   │   │   │
├───┼───┼───┼───┤
│ A │   │   │ B │  ← 需要连接 A 到 B
├───┼───┼───┼───┤
│   │   │   │   │
└───┴───┴───┴───┘

Global Routing 结果：
┌───┬───┬───┬───┐
│   │   │   │   │
├───┼───┼───┼───┤
│ A →→→→→→→ B │  ← 大致路径
├───┼───┼───┼───┤
│   │   │   │   │
└───┴───┴───┴───┘
```

**算法：** 迷宫路由（Maze Routing）、A* 搜索

**OpenROAD 使用：** FastRoute

---

#### 2️⃣ Detailed Routing（详细布线）

**目标：** 分配精确的金属轨道，满足 DRC

```
Global Routing（网格级）：
  A →→→ B

Detailed Routing（轨道级）：
  Layer M1: ─────  ← 精确轨道
  Layer M2:    │   ← 可能需要换层
             Via   ← 过孔
```

**OpenROAD 使用：** TritonRoute（ISPD 竞赛获奖算法）

---

### 多层金属布线

**现代工艺的金属层：**

```
M7-M9: 顶层（粗金属）   ← Power/Ground
  ↕
M5-M6: 中层            ← 长距离信号、时钟
  ↕
M3-M4: 中层            ← 普通信号
  ↕
M1-M2: 底层（细金属）   ← 短距离连接

每层有方向：
  M1: 水平
  M2: 垂直
  M3: 水平
  M4: 垂直
  ...
```

**为什么需要多层？**
```
单层不够：
  100 万条线，挤在一层 → 不可能

多层解决：
  - 水平线用 M1, M3, M5
  - 垂直线用 M2, M4, M6
  - 通过 Via（过孔）换层
```

---

### 对时序的影响

**Routing 最终确定 Wire Delay！**

```
Placement 后（估算）：
  Wire Delay = C × 线长
  （假设直线距离）

Routing 后（精确）：
  实际走线可能绕路、换层

例子：
  A 到 B 直线距离：100um

  实际路由：
    - M1: 50um 水平
    - Via: M1→M2
    - M2: 80um 垂直（绕开拥塞区）
    - Via: M2→M1
    - M1: 30um 水平

  实际线长：160um（比直线长 60%！）

  实际 Wire Delay：
    = R × C
    = (160um × 0.1Ω/um) × (160um × 0.2fF/um)
    = 16Ω × 32fF
    = 512ps

  估算 Wire Delay：
    = (100um × 0.1Ω/um) × (100um × 0.2fF/um)
    = 10Ω × 20fF
    = 200ps

  差异：512 - 200 = 312ps  ← 很大！
```

---

### Routing 后的寄生提取

**完成 Routing 后：**

```tcl
# 提取寄生参数（RC）
extract_parasitics

# 生成 SPEF 文件（Standard Parasitic Exchange Format）
write_spef design.spef
```

**SPEF 文件内容：**
```spef
*D_NET net123 5.2E-12   ← 总电容 5.2pF
*CONN
*P u1:Z O
*I u2:A I
*CAP
1 u1:Z 2.1E-12          ← u1 输出端电容
2 net123:1 1.5E-12      ← 线上某点电容
3 u2:A 1.6E-12          ← u2 输入端电容
*RES
1 u1:Z net123:1 15.0    ← 电阻 15Ω
2 net123:1 u2:A 20.0    ← 电阻 20Ω
*END
```

**带 SPEF 的 STA：**
```tcl
read_spef design.spef
report_checks -path_delay min_max

Slack (Setup): +0.2ns  ← 最精确！
Slack (Hold): +0.03ns
```

---

### OpenROAD Routing 命令

```tcl
# Global Routing
global_route \
  -congestion_iterations 100

# Detailed Routing
detailed_route

# 检查 DRC
check_drc

# 寄生提取
extract_parasitics

# 最终 STA
read_spef design.spef
report_checks
```

---

## 📊 P&R 各阶段的 STA 精度对比

### 时序精度演进

```
阶段              | Wire Delay | Clock Delay | Slack 可信度
─────────────────┼───────────┼────────────┼─────────────
综合后（Yosys）   | 估算 ±50%  | 假设 0      | 低 ⭐
Floorplan 后      | 估算 ±30%  | 假设 0      | 低 ⭐⭐
Placement 后      | 估算 ±20%  | 假设 0      | 中 ⭐⭐⭐
CTS 后            | 估算 ±20%  | 精确 ±5%    | 较高 ⭐⭐⭐⭐
Routing 后        | 精确 ±5%   | 精确 ±5%    | 高 ⭐⭐⭐⭐⭐
提取寄生后        | 精确 ±2%   | 精确 ±2%    | 最高 ⭐⭐⭐⭐⭐
```

### 实际例子

**设计：简单的数据通路**

```
DFF1 → Adder → Mux → DFF2
Clock Period: 2ns
```

**各阶段的 Slack：**

```
综合后：
─────────────────────────────────────
Arrival Time: 1.2ns  (只有 Cell Delay)
Required Time: 1.9ns
Slack: +0.7ns  ← 看起来不错

Placement 后：
─────────────────────────────────────
Arrival Time: 1.6ns  (Cell + Wire估算)
Required Time: 1.9ns
Slack: +0.3ns  ← 紧张了

CTS 后：
─────────────────────────────────────
Arrival Time: 2.2ns  (Cell + Wire + Launch Clock)
Required Time: 2.7ns (Capture Clock)
Slack: +0.5ns  ← 时钟延迟抵消了一部分

Routing 后（提取寄生）：
─────────────────────────────────────
Arrival Time: 2.35ns (实际 Wire Delay 更大)
Required Time: 2.71ns
Slack: +0.36ns  ← 最终 Slack

结论：综合阶段的 +0.7ns 是乐观的！
      实际只有 +0.36ns
```

---

## 💡 关键启示

### 1. 为什么需要 P&R？

**从 STA 的角度：**

```
综合只给你 Cell Delay
  ↓
但不知道 Wire Delay 和 Clock Delay
  ↓
无法准确评估时序
  ↓
P&R 给出物理实现
  ↓
Wire Delay 和 Clock Delay 精确
  ↓
STA 结果可信
```

---

### 2. 为什么 P&R 要分这么多步骤？

**答案：逐步细化，逐步精确**

```
Floorplan: 确定大的框架（芯片大小）
           ↓
Placement: 确定每个单元位置（Wire Delay 可估算）
           ↓
CTS:       确定时钟网络（Clock Delay 精确）
           ↓
Routing:   确定实际走线（Wire Delay 精确）
```

**如果一步完成：**
- 计算量太大（组合爆炸）
- 无法收敛
- 质量差

---

### 3. OpenROAD vs FusionCompiler 的本质差异

**FusionCompiler:**
```
自动化程度高
  ↓
各步骤紧密耦合
  ↓
全局优化
  ↓
质量好，但黑盒
```

**OpenROAD:**
```
模块化
  ↓
各步骤相对独立
  ↓
局部优化
  ↓
质量中等，但透明
```

---

## 🎯 总结：P&R 流程图（STA 视角）

```
输入：综合后网表
│
│  【STA: Slack = ???  (不可信)】
│
├─► Floorplan
│     └─► 确定芯片尺寸
│
│  【STA: Wire Delay ≈ 估算】
│
├─► Placement
│     └─► 确定单元位置
│
│  【STA: Wire Delay = 较准确】
│
├─► CTS
│     └─► 构建时钟树
│
│  【STA: Clock Delay = 精确】
│
├─► Routing
│     └─► 实际走线
│
│  【STA: Wire Delay = 精确】
│
├─► Parasitic Extraction
│     └─► 提取 RC
│
│  【STA: 所有 Delay 精确】
│
└─► 输出：GDS + SPEF

     【STA: Slack = 可信！】
```

---

## 🤔 思考题

### Q1: 为什么不能在综合阶段就精确分析时序？

**答案：**
- 没有物理位置 → Wire Delay 未知
- 没有时钟树 → Clock Delay 未知
- STA 等式中的关键项缺失

---

### Q2: Placement 和 Routing 哪个对时序影响更大？

**答案：**
- **Placement 影响更大**
- Placement 决定了线长的下限
- Routing 只是在 Placement 的基础上实现
- Bad Placement → Routing 再好也救不回来

---

### Q3: 为什么 CTS 要在 Placement 之后？

**答案：**
- CTS 需要知道所有 DFF 的位置
- 才能构建平衡的时钟树
- 如果 Placement 改变，CTS 要重做

---

## 📚 下一步

您现在从 STA 的角度理解了 P&R 流程！

接下来可以：
- [ ] 看一个完整的 OpenROAD 实例
- [ ] 深入某个步骤（比如 Placement 算法）
- [ ] 学习 OpenLane（自动化流程）

---

**您觉得理解了吗？有什么疑问？** 😊
