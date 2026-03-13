# Wire Load Models 深入理解

📅 日期：2026-03-13
🎯 针对熟悉 STA 的工程师

---

## 🔍 什么是 Wire Load Model？

### 定义

**Wire Load Model (WLM)** = 在没有实际布局布线时，**估算** wire delay 的模型

---

## 📊 综合阶段的 Wire Delay 估算方法

### 方法 1: Zero Wire Load（最简单）

```
假设：所有连线 Wire Delay = 0

优点：
  - 最乐观
  - 综合速度快
  - 适合快速迭代

缺点：
  - 完全不准确
  - Slack 过于乐观
  - 可能导致后续时序违规
```

**示例：**
```
综合时（Zero Wire Load）：
  Cell Delay: 0.5ns
  Wire Delay: 0ns        ← 假设为 0
  Total: 0.5ns
  Slack: +1.5ns  ← 乐观！

Routing 后（实际）：
  Cell Delay: 0.5ns
  Wire Delay: 0.4ns      ← 实际测量
  Total: 0.9ns
  Slack: +1.1ns  ← 缩水了！
```

---

### 方法 2: Wire Load Model（统计模型）

**基于统计的估算：**

```liberty
/* Liberty 文件中的 Wire Load Model */

wire_load("typical") {
  capacitance : 1.0;    /* 单位电容 */
  resistance : 0.05;    /* 单位电阻 */
  slope : 0.5;          /* 电容随距离增长系数 */

  fanout_length(1, 10);   /* 扇出=1 时，平均线长 10um */
  fanout_length(2, 15);   /* 扇出=2 时，平均线长 15um */
  fanout_length(3, 20);
  fanout_length(4, 25);
  fanout_length(5, 30);
}
```

**计算方法：**
```
例子：一个 AND 门驱动 3 个 OR 门

Step 1: 查表
  fanout = 3 → 估算线长 = 20um

Step 2: 计算电容
  C = capacitance × length
    = 1.0 fF/um × 20um
    = 20fF

Step 3: 计算电阻
  R = resistance × length
    = 0.05 Ω/um × 20um
    = 1Ω

Step 4: 计算 Wire Delay
  Wire Delay = R × C = 1Ω × 20fF = 20ps
```

**优点：**
- 比 Zero Wire Load 准确
- 基于历史数据统计
- 综合速度仍然快

**缺点：**
- 仍是估算（±30% 误差）
- 不考虑实际布局
- 不同设计差异大

---

### 方法 3: Topographical Mode（拓扑模式）

**FusionCompiler 的高级功能：**

```tcl
# 启用 Topographical Mode
set_app_var compile_ultra_ungroup_small_hierarchies false
compile_ultra -topographical

# 进行虚拟布局
create_placement -floorplan
```

**工作原理：**
```
1. 在综合时进行"虚拟布局"
   - 不是真正的 Placement
   - 只是估算单元的大致位置

2. 根据虚拟位置计算距离
   - Distance(u1, u2) = 估算距离

3. 计算 Wire Delay
   - Wire Delay = f(distance)
   - 比 WLM 准确

准确度：±15%
```

**优点：**
- 更准确（物理感知）
- 综合质量更好
- 减少后续 P&R 的 ECO

**缺点：**
- 综合时间更长
- 仍不如实际 Placement 准确

---

## 📈 各阶段 Wire Delay 精度对比

### 精度演进图

```
阶段                  | 方法                | 误差范围    | Slack 可信度
─────────────────────┼───────────────────┼───────────┼─────────────
综合（Zero WL）       | Wire Delay = 0     | ±100%     | 很低 ⭐
综合（WLM）          | 统计模型            | ±30-50%   | 低 ⭐⭐
综合（Topo Mode）    | 虚拟布局            | ±15-30%   | 中 ⭐⭐⭐
Floorplan 后         | 面积估算            | ±20-30%   | 中 ⭐⭐⭐
Placement 后         | 实际距离            | ±10-20%   | 较高 ⭐⭐⭐⭐
Routing 后（预估）   | 预估走线            | ±5-10%    | 高 ⭐⭐⭐⭐
Routing 后（SPEF）   | 寄生提取            | ±2-5%     | 最高 ⭐⭐⭐⭐⭐
```

---

## 🎯 实际案例：Wire Delay 的演变

### 设计：中等规模数据通路

```verilog
// 关键路径
DFF1.Q → MUX.A → ADDER.A → AND.A → DFF2.D

扇出：
  - MUX.A: 1
  - ADDER.A: 1
  - AND.A: 1
```

### 各阶段的 Wire Delay

#### 综合阶段（Zero Wire Load）

```
FusionCompiler:
  compile -no_wire_load  # Zero Wire Load

Path Analysis:
─────────────────────────────────────────
  DFF1.Q → MUX.A
    Cell Delay: 0.15ns
    Wire Delay: 0.00ns     ← Zero!

  MUX.A → ADDER.A
    Cell Delay: 0.25ns
    Wire Delay: 0.00ns     ← Zero!

  ADDER.A → AND.A
    Cell Delay: 0.35ns
    Wire Delay: 0.00ns     ← Zero!

  AND.A → DFF2.D
    Cell Delay: 0.10ns
    Wire Delay: 0.00ns     ← Zero!

Total Delay: 0.85ns
Slack: +1.15ns  (Period = 2ns)
```

---

#### 综合阶段（Wire Load Model）

```
FusionCompiler:
  set_wire_load_model -name "typical"
  compile_ultra

Path Analysis:
─────────────────────────────────────────
  DFF1.Q → MUX.A
    Cell Delay: 0.15ns
    Wire Delay: 0.02ns     ← 基于 fanout=1, length≈10um

  MUX.A → ADDER.A
    Cell Delay: 0.25ns
    Wire Delay: 0.02ns     ← fanout=1

  ADDER.A → AND.A
    Cell Delay: 0.35ns
    Wire Delay: 0.02ns     ← fanout=1

  AND.A → DFF2.D
    Cell Delay: 0.10ns
    Wire Delay: 0.02ns     ← fanout=1

Total Delay: 0.93ns
Slack: +1.07ns
```

**差异：** 0.93 - 0.85 = 0.08ns（约 10%）

---

#### Placement 后（实际距离）

```
OpenROAD / FusionCompiler:
  place_opt

实际布局：
  DFF1 在 (100, 100)
  MUX  在 (120, 100)  ← 距离 20um
  ADDER在 (160, 100)  ← 距离 40um
  AND  在 (180, 100)  ← 距离 20um
  DFF2 在 (200, 100)  ← 距离 20um

Path Analysis:
─────────────────────────────────────────
  DFF1.Q → MUX.A (20um)
    Cell Delay: 0.15ns
    Wire Delay: 0.04ns     ← 实际距离计算

  MUX.A → ADDER.A (40um)
    Cell Delay: 0.25ns
    Wire Delay: 0.08ns     ← 较长！

  ADDER.A → AND.A (20um)
    Cell Delay: 0.35ns
    Wire Delay: 0.04ns

  AND.A → DFF2.D (20um)
    Cell Delay: 0.10ns
    Wire Delay: 0.04ns

Total Delay: 1.05ns
Slack: +0.95ns
```

**差异：** 1.05 - 0.93 = 0.12ns（约 15%）

---

#### Routing 后（SPEF 提取）

```
OpenROAD / FusionCompiler:
  route_opt
  extract_parasitics

实际走线（可能绕路）：
  DFF1.Q → MUX.A:
    - M1: 15um 水平
    - Via M1→M2
    - M2: 10um 垂直
    - Via M2→M1
    - M1: 5um 水平
    实际线长: 30um (直线 20um)

  MUX.A → ADDER.A:
    - M1: 25um
    - Via M1→M2
    - M2: 20um（绕开拥塞区）
    - Via M2→M1
    - M1: 15um
    实际线长: 60um (直线 40um)

Path Analysis (with SPEF):
─────────────────────────────────────────
  DFF1.Q → MUX.A (实际 30um)
    Cell Delay: 0.15ns
    Wire Delay: 0.06ns     ← 比预估大 50%

  MUX.A → ADDER.A (实际 60um)
    Cell Delay: 0.25ns
    Wire Delay: 0.12ns     ← 比预估大 50%

  ADDER.A → AND.A (实际 25um)
    Cell Delay: 0.35ns
    Wire Delay: 0.05ns

  AND.A → DFF2.D (实际 22um)
    Cell Delay: 0.10ns
    Wire Delay: 0.044ns

Total Delay: 1.134ns
Slack: +0.866ns
```

**差异：** 1.134 - 1.05 = 0.084ns（约 8%）

---

### 总结对比

```
阶段              | Total Delay | Slack   | vs Final
─────────────────┼────────────┼────────┼─────────────
Zero Wire Load   | 0.85ns     | +1.15ns | -25% ⚠️
Wire Load Model  | 0.93ns     | +1.07ns | -18% ⚠️
Placement 后      | 1.05ns     | +0.95ns | -7%  ✅
Routing 后        | 1.134ns    | +0.866ns| Baseline ✅

关键发现：
- Zero WL 过于乐观（Slack 高估 33%）
- WLM 仍有 20% 误差
- Placement 已经较准确
- Routing 是最终真相
```

---

## 💡 为什么 Placement 影响更大？

### 您说"两个阶段都重要"是对的，但让我补充：

**Placement 决定了优化的上限！**

```
好的 Placement：
  - 关键路径单元靠近
  - 线长短
  - Routing 容易收敛

坏的 Placement：
  - 关键路径单元分散
  - 线长已经很长
  - Routing 再优化也救不回来
```

### 类比

```
Placement = 城市规划
  - 决定建筑物位置
  - 好的规划 → 交通便利
  - 坏的规划 → 修再多路也拥堵

Routing = 修路
  - 在规划基础上铺设道路
  - 好规划下，修路容易
  - 坏规划下，修路困难
```

---

## 🔧 实际工作中的应用

### 1. 综合时的策略选择

**小设计（<10K gates）：**
```tcl
# 可以用 Zero Wire Load 快速迭代
compile -no_wire_load
```

**中等设计（10K-1M gates）：**
```tcl
# 推荐 Wire Load Model
set_wire_load_model -name "typical"
compile_ultra
```

**大设计（>1M gates）：**
```tcl
# 必须用 Topographical Mode
compile_ultra -topographical
```

---

### 2. 读懂时序报告

**综合阶段的报告（WLM）：**
```
Timing Path:
────────────────────────────────────
Point                 Incr    Path
────────────────────────────────────
clock clk (rise)      0.00    0.00
DFF1/CK               0.00    0.00
DFF1/Q         (0.15) 0.15    0.15
U1/A           (0.02) 0.02    0.17   ← Wire Delay (估算)
U1/Y           (0.25) 0.25    0.42
U2/A           (0.02) 0.02    0.44   ← Wire Delay (估算)
...

data arrival time              1.05  ← 不可信！
data required time             2.00
────────────────────────────────────
slack (MET)                    0.95  ← 过于乐观
```

**注意标记：**
- `(estimated)` - 估算值
- `(propagated)` - 实际值

---

**Routing 后的报告（SPEF）：**
```
Timing Path:
────────────────────────────────────
Point                 Incr    Path
────────────────────────────────────
clock clk (rise)      0.00    0.00
DFF1/CK (propagated)  0.85    0.85   ← 实际 Clock Delay
DFF1/Q         (0.15) 0.15    1.00
U1/A           (0.06) 0.06    1.06   ← 实际 Wire Delay
U1/Y           (0.25) 0.25    1.31
U2/A           (0.12) 0.12    1.43   ← 实际 Wire Delay
...

data arrival time              2.26  ← 可信！
data required time (propagated)2.87  ← 实际时钟
────────────────────────────────────
slack (MET)                    0.61  ← 真实 Slack
```

---

### 3. Margin 的设置

**基于不同阶段设置 Margin：**

```tcl
# 综合阶段（Zero WL 或 WLM）
set_clock_uncertainty 0.5  # 留 50% margin

# Placement 后
set_clock_uncertainty 0.3  # 减少到 30%

# Routing 后（SPEF）
set_clock_uncertainty 0.1  # 只留 10% 制造变化
```

**为什么需要 Margin？**
- 补偿 Wire Delay 估算误差
- 预留优化空间
- 避免后续时序违规

---

## 🎯 关键启示

### 1. Zero Wire Load 的陷阱

```
综合时：Slack = +1.5ns  ← 乐观
Routing 后：Slack = +0.3ns  ← 现实
差距：1.2ns！

问题：可能导致芯片失败！
```

**教训：**
- 永远不要相信 Zero WL 的 Slack
- 至少用 Wire Load Model
- 大设计必须用 Topographical Mode

---

### 2. 为什么商业工具贵？

**FusionCompiler 的价值：**
- ✅ 精确的 Wire Delay 模型
- ✅ 物理感知综合（Topographical）
- ✅ 全局优化
- ✅ 迭代收敛保证

**OpenROAD 的局限：**
- ⚠️ Yosys 只能 Zero WL 或简单 WLM
- ⚠️ 需要反复迭代（综合→P&R→再综合）
- ⚠️ 收敛不保证

---

### 3. 实际工作流程

**推荐：**
```
1. 综合（带 WLM）
   ↓
2. 快速 Placement（检查大致时序）
   ↓
3. 如果 Slack < Margin：
     重新综合（调整约束）
   ↓
4. 完整 P&R
   ↓
5. SPEF 后 STA（最终验证）
```

---

## 🤔 思考题

### Q1: 如果综合时 Slack = +0.5ns (WLM)，Routing 后可能是多少？

**答案：**
- 乐观：+0.3ns（估算误差小）
- 悲观：-0.2ns（估算误差大，时序违规）
- 所以要留 Margin！

---

### Q2: OpenROAD 能做 Topographical Synthesis 吗？

**答案：**
- Yosys 本身不支持
- 但可以迭代：
  1. Yosys 综合（Zero WL）
  2. OpenROAD Placement
  3. 提取 Wire Delay
  4. 反馈给 Yosys（手动）
  5. 重新综合

效果差，但可行。

---

## 📚 总结

### Wire Load 演进

```
估算精度：
Zero WL < WLM < Topo Mode < Placement < Routing

工具能力：
Yosys: Zero WL / 简单 WLM
FusionCompiler: WLM + Topo Mode
OpenROAD: 需要迭代

最佳实践：
- 综合：至少用 WLM
- 大设计：用 Topo Mode
- 小设计：可以 Zero WL 快速迭代
- 最终：必须 SPEF 验证
```

---

**您的 Zero Wire Load 概念提得非常好！** 这说明您确实有实战经验！👍
