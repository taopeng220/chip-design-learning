# FSM 综合分析 - 交通灯控制器

## 🎯 设计概述

**功能：** 3状态交通灯控制器
```
GREEN (10 cycles) → YELLOW (3 cycles) → RED (10 cycles) → GREEN ...
```

**输入：**
- `clk` - 时钟
- `rst_n` - 异步复位（低有效）

**输出：**
- `red` - 红灯
- `yellow` - 黄灯
- `green` - 绿灯

---

## 📊 RTL 设计结构

### 1. 状态定义（Binary 编码）
```verilog
S_GREEN  = 2'b00
S_YELLOW = 2'b01
S_RED    = 2'b10
```

**为什么用 2 bit？**
- 3 个状态最少需要 ⌈log₂(3)⌉ = 2 bits

### 2. FSM 三大部分

#### (1) 状态寄存器（时序逻辑）
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= S_GREEN;
    else
        current_state <= next_state;
end
```
**综合结果：** 2个 D触发器（DFF）存储状态

---

#### (2) 次态逻辑（组合逻辑）
```verilog
always @(*) begin
    case (current_state)
        S_GREEN:  if (counter >= 9) next_state = S_YELLOW;
        S_YELLOW: if (counter >= 2) next_state = S_RED;
        S_RED:    if (counter >= 9) next_state = S_GREEN;
    endcase
end
```
**综合结果：** 多路选择器 + 比较器

---

#### (3) 输出逻辑（组合逻辑）
```verilog
always @(*) begin
    case (current_state)
        S_GREEN:  green = 1;
        S_YELLOW: yellow = 1;
        S_RED:    red = 1;
    endcase
end
```
**综合结果：** 译码器（2-to-3 decoder）

---

## 🔧 Yosys FSM 处理流程

### Step 1: `fsm_detect` - 检测 FSM
Yosys 分析代码，识别出这是一个状态机：
```
检测到 FSM: traffic_light.$fsm$traffic_light.v:21$1
  - 状态变量: current_state
  - 输入信号: counter
  - 输出信号: next_state, red, yellow, green
```

---

### Step 2: `fsm_extract` - 提取 FSM
把 FSM 从 RTL 中提取出来，形成专门的 FSM 数据结构：
```
FSM 提取结果:
  - 状态数: 3
  - 输入位宽: 4 (counter)
  - 输出位宽: 5 (next_state[2] + 3个灯)
  - 转换数: 3
```

---

### Step 3: `fsm_opt` - 优化 FSM

#### 可能的优化：
1. **状态最小化**
   - 检查是否有等价状态可以合并
   - 此例中 3 个状态功能不同，无法合并

2. **状态编码优化**
   - Binary 编码: `00, 01, 10` (我们的设计)
   - One-hot 编码: `001, 010, 100`
   - Gray 编码: `00, 01, 11`

**Yosys 默认行为：** 保持您的编码（Binary）

---

### Step 4: `synth` - 综合成门级

#### 状态寄存器 → DFF
```verilog
// 2 个 D触发器
$_DFF_N_ state_reg_0 (
    .C(clk),
    .D(next_state[0]),
    .Q(current_state[0])
);

$_DFF_N_ state_reg_1 (
    .C(clk),
    .D(next_state[1]),
    .Q(current_state[1])
);
```

#### 次态逻辑 → MUX + Comparator
```verilog
// 比较 counter >= threshold
// 根据 current_state 选择 next_state
$_MUX4_ next_state_mux (...);
```

#### 输出逻辑 → Decoder
```verilog
// 2-to-3 译码
red    = (current_state == 2'b10);
yellow = (current_state == 2'b01);
green  = (current_state == 2'b00);
```

---

## 📈 综合统计（预期）

```
=== traffic_light ===

   Number of wires:                 25
   Number of wire bits:             42
   Number of memories:               0
   Number of processes:              0
   Number of cells:                 30
     $_AND_                          8
     $_DFF_N_                        6    ← 2个状态位 + 4个计数器位
     $_MUX_                         10
     $_NOT_                          4
     $_OR_                           2
```

**关键观察：**
- **6 个 DFF**: 2个存状态 + 4个存计数器
- **组合逻辑**: MUX + AND/OR/NOT 实现次态和输出

---

## 🆚 FusionCompiler vs Yosys FSM 处理对比

| 特性 | FusionCompiler | Yosys |
|------|----------------|-------|
| **FSM 识别** | 自动识别 | `fsm_detect` 手动触发 |
| **状态编码** | 多种算法（auto/onehot/binary/gray）<br>根据时序/面积优化选择 | 默认保持 RTL 编码<br>可手动指定 `fsm_recode` |
| **状态最小化** | 自动优化 | `fsm_opt` |
| **Safe FSM** | 支持（添加错误恢复状态） | 需手动实现 |
| **时序优化** | 考虑时序（状态编码会影响时序）| 不考虑时序 |
| **报告** | `report_fsm` 详细报告 | `fsm_info` 基本信息 |

---

## 💡 关键概念：状态编码的影响

### Binary 编码 (我们的设计)
```
S_GREEN  = 00
S_YELLOW = 01
S_RED    = 10
```
**优点：** 状态位最少（2 bits → 2 个 DFF）
**缺点：** 组合逻辑可能复杂

### One-hot 编码
```
S_GREEN  = 001
S_YELLOW = 010
S_RED    = 100
```
**优点：** 次态逻辑简单（每个状态只改变1位）
**缺点：** 需要 3 个 DFF（更多面积）

### 在 FusionCompiler 中：
- 工具会根据时序/面积目标**自动选择**最优编码
- 高速设计常用 one-hot（减少组合逻辑延迟）
- 面积敏感设计用 binary（减少寄存器）

### 在 Yosys 中：
- 默认**保持您的编码**
- 可以用 `fsm_recode -encoding onehot` 强制改变

---

## 🎓 学习要点

### 1️⃣ FSM 综合的本质
把三段式状态机：
```
时序逻辑（状态寄存器）
     ↓
组合逻辑（次态逻辑）
     ↓
组合逻辑（输出逻辑）
```

转换成：
```
DFF（寄存器）+ MUX/Decoder（组合逻辑）
```

### 2️⃣ Yosys 的透明度
- FusionCompiler 把 FSM 优化藏在黑盒里
- Yosys 让您**看到每一步**：detect → extract → opt → synth
- 非常适合**学习综合原理**！

### 3️⃣ 对比您的工作经验
- 在 FusionCompiler 中，您写完 FSM RTL 后直接 `compile_ultra`
- Yosys 让您理解工具**内部**做了什么
- 这就是开源工具的学习价值！✨

---

## 🔍 思考题

### Q1: 如果把状态编码改成 One-hot，需要几个 DFF？
**答案：** 3 个 DFF（每个状态一位）

### Q2: 计数器也是状态机吗？
**答案：** 是！4-bit 计数器是 16 状态的 FSM
- Yosys 也会识别出来

### Q3: 为什么 FusionCompiler 不需要手动 fsm_detect？
**答案：** FusionCompiler 在 `elaborate` 阶段自动做了
- 但您看不到过程
- Yosys 把每一步分开，便于学习

---

## 下一步

- [ ] 实际运行 Yosys，看真实输出
- [ ] 修改状态编码，对比综合结果
- [ ] 添加 testbench，仿真验证
- [ ] 学习 Yosys 的 FSM 可视化功能
