# 交通灯 FSM 综合可视化指南

## 📋 RTL → 门级网表 转换全景图

### 原始 RTL 代码（您写的）

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= S_GREEN;
    else
        current_state <= next_state;
end

always @(*) begin
    case (current_state)
        S_GREEN:  if (counter >= 9) next_state = S_YELLOW;
        S_YELLOW: if (counter >= 2) next_state = S_RED;
        S_RED:    if (counter >= 9) next_state = S_GREEN;
    endcase
end

always @(*) begin
    case (current_state)
        S_GREEN:  green = 1;
        S_YELLOW: yellow = 1;
        S_RED:    red = 1;
    endcase
end
```

---

### 综合后的结构（Yosys 生成的）

```
                           clk
                            │
                            ├──────┐
                            │      │
                            ▼      ▼
                      ┌─────────┐ ┌─────────┐
                      │  DFF[0] │ │  DFF[1] │  ◄── 状态寄存器 (2 bits)
                      └─────────┘ └─────────┘
                            │         │
                      current_state[1:0]
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
         ┌──────────────┐        ┌──────────────┐
         │  比较器逻辑   │        │   输出译码    │
         │ (counter>=X) │        │  (2-to-3)    │
         └──────────────┘        └──────────────┘
                │                       │
                ▼                       ▼
         ┌──────────────┐        ┌──────────────┐
         │  次态逻辑     │        │ red/yellow/  │
         │  (MUX/AND)   │        │    green     │
         └──────────────┘        └──────────────┘
                │
                ▼
           next_state[1:0]
                │
                └───────► (回到 DFF 输入)
```

---

## 🔍 细节分解

### Part 1: 状态寄存器（时序逻辑）

**RTL:**
```verilog
reg [1:0] current_state;

always @(posedge clk or negedge rst_n)
    if (!rst_n)
        current_state <= S_GREEN;
    else
        current_state <= next_state;
```

**综合成:**
```
        next_state[0] ──┐
                        │
                        ▼
              ┌────────────────┐
      clk ───►│   DFF with     │
    rst_n ───►│   async reset  │───► current_state[0]
              └────────────────┘

        next_state[1] ──┐
                        │
                        ▼
              ┌────────────────┐
      clk ───►│   DFF with     │
    rst_n ───►│   async reset  │───► current_state[1]
              └────────────────┘
```

**关键点:**
- 每个状态位 → 1 个 DFF
- 异步复位 → DFF 的 R 端口
- 上升沿触发 → DFF 的 C 端口

---

### Part 2: 次态逻辑（组合逻辑）

**RTL:**
```verilog
case (current_state)
    S_GREEN:  if (counter >= 9) next_state = S_YELLOW;
    S_YELLOW: if (counter >= 2) next_state = S_RED;
    S_RED:    if (counter >= 9) next_state = S_GREEN;
endcase
```

**综合成:**
```
current_state[1:0] ────┬───► 状态译码
                       │     (is_green? is_yellow? is_red?)
                       │              ▼
                       │     ┌────────────────┐
counter[3:0] ──────────┼────►│   比较器        │
                       │     │ (>=9? >=2?)    │
                       │     └────────────────┘
                       │              ▼
                       │     ┌────────────────┐
                       └────►│   MUX/AND/OR    │
                             │  (状态转换表)   │───► next_state[1:0]
                             └────────────────┘
```

**逻辑表达式:**
```
next_state[0] = (is_green  & counter_ge_9) |
                 (is_red    & counter_ge_9)

next_state[1] = (is_yellow & counter_ge_2) |
                 (is_red    & !counter_ge_9)
```

**门级实现:**
- 状态译码: AND/NOR 门
- 比较器: 4-bit 比较器（多级 AND/OR）
- 转换逻辑: MUX/AND/OR 树

---

### Part 3: 输出逻辑（组合逻辑）

**RTL:**
```verilog
case (current_state)
    S_GREEN:  green = 1;
    S_YELLOW: yellow = 1;
    S_RED:    red = 1;
endcase
```

**综合成 2-to-3 译码器:**
```
current_state[1:0]
       │
       ├─────► green  = !(state[0] | state[1])   // 00
       │
       ├─────► yellow = state[0] & !state[1]     // 01
       │
       └─────► red    = !state[0] & state[1]     // 10
```

**门数统计:**
- 2 个 NOT 门
- 4 个 AND/OR 门
- 总共 ~6 个门

---

## 📊 完整综合统计

### 设计规模
```
输入信号:     2 个 (clk, rst_n)
输出信号:     3 个 (red, yellow, green)
内部状态:     6 bits (2状态 + 4计数器)
```

### 单元统计（预期）
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
类型              数量      用途
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DFF               6个      状态存储
AND               ~8个     逻辑判断
OR                ~4个     逻辑合并
NOT               ~4个     信号取反
XOR               ~4个     加法器/比较
MUX               ~6个     信号选择
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总计              ~32个
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 延迟分析（无时序优化）
```
关键路径:
  counter[3:0] → 比较器 → 次态逻辑 → next_state → DFF

估算延迟（通用门）:
  - 比较器: ~3 级门延迟
  - 次态逻辑: ~2 级门延迟
  - 总计: ~5 级门延迟
  - 约 2-3ns (假设每级 0.5ns)
```

---

## 🆚 与 FusionCompiler 的对比

### Yosys 输出 (技术无关)
```verilog
$_DFF_N_ state_reg_0 (...);    // 通用 DFF
$_AND_   gate_1 (...);         // 通用 AND 门
$_MUX_   mux_1 (...);          // 通用 MUX
```

### FusionCompiler 输出 (映射到工艺库)
```verilog
DFFR_X1 state_reg_0 (          // 工艺库标准单元
  .D(next_state[0]),
  .CK(clk),
  .RN(rst_n),
  .Q(current_state[0])
);

AND2_X2 gate_1 (               // 2输入AND，2倍驱动
  .A1(...),
  .A2(...),
  .ZN(...)
);

MUX2_X1 mux_1 (                // 工艺库 MUX
  .A(...),
  .B(...),
  .S(...),
  .Z(...)
);
```

**关键差异:**
| 特性 | Yosys | FusionCompiler |
|------|-------|----------------|
| 单元类型 | 通用门 | 工艺库标准单元 |
| 驱动能力 | 未指定 | X1/X2/X4 等 |
| 物理信息 | 无 | 有（坐标、方向）|
| 时序信息 | 无 | 有（delay、constraint）|
| 面积 | 估算 | 精确值 |

---

## 🎯 实战练习建议

### 练习 1: 修改状态编码
把 Binary 改成 One-hot:
```verilog
parameter [2:0] S_GREEN  = 3'b001;
parameter [2:0] S_YELLOW = 3'b010;
parameter [2:0] S_RED    = 3'b100;
```

**观察:**
- DFF 数量变化 (2 → 3)
- 次态逻辑是否更简单？

---

### 练习 2: 添加第4个状态
添加 "ALL_RED" 状态（所有方向红灯）:
```
GREEN → YELLOW → RED → ALL_RED → GREEN
```

**观察:**
- 需要几个 DFF? (⌈log₂(4)⌉ = 2 bits, binary编码)
- 组合逻辑如何变化？

---

### 练习 3: 安全状态机
添加 default 状态处理:
```verilog
default: next_state = S_RED;  // 错误时进入安全状态
```

**观察:**
- 额外的安全逻辑如何实现？

---

## 💡 关键收获

### 1. FSM 综合不是黑魔法
- 时序逻辑 → DFF
- 组合逻辑 → MUX/AND/OR
- 一切都是基本逻辑门的组合！

### 2. Yosys 让您看到内部
- FusionCompiler: 一个命令搞定，看不到细节
- Yosys: 每一步都可见，适合学习

### 3. RTL 风格影响综合结果
- 三段式 vs 两段式
- Binary vs One-hot 编码
- 这些在门级都有体现

---

## 📚 推荐阅读顺序

1. ✅ 先看 `FSM_ANALYSIS.md` - 理解理论
2. ✅ 再看本文档 - 看可视化结构
3. ⏭️ 然后看 `synth_result_simplified.v` - 看实际代码
4. ⏭️ 最后实际运行 Yosys - 验证理解

---

**准备好进入下一个主题了吗？** 🚀
