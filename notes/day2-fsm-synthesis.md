# Day 2 (续): FSM 综合实战 - 交通灯控制器

📅 日期：2026-03-12
🎯 目标：通过状态机实例深入理解 Yosys 综合过程

---

## 🎉 今天的成就

### ✅ 完成的内容

1. **创建了完整的 FSM 设计**
   - 3 状态交通灯控制器
   - 包含状态寄存器、次态逻辑、输出逻辑
   - 标准的三段式状态机写法

2. **理解了 Yosys 的 FSM 处理流程**
   - `fsm_detect` - 检测状态机
   - `fsm_extract` - 提取FSM结构
   - `fsm_opt` - 优化状态机
   - `synth` - 综合成门级

3. **学会了 RTL → 门级的映射关系**
   - 状态寄存器 → DFF
   - 次态逻辑 → MUX + 比较器
   - 输出逻辑 → 2-to-3 译码器

4. **对比了 FusionCompiler vs Yosys**
   - 工具流程差异
   - 输出网表差异
   - 各自的优势和局限

---

## 💡 关键知识点

### 1. FSM 的本质

```
三段式状态机的组成:
┌────────────────────┐
│  时序逻辑          │  → DFF (存储状态)
│ (状态寄存器更新)   │
└────────────────────┘
         ↓
┌────────────────────┐
│  组合逻辑          │  → MUX/AND/OR (计算次态)
│ (次态逻辑)         │
└────────────────────┘
         ↓
┌────────────────────┐
│  组合逻辑          │  → Decoder (生成输出)
│ (输出逻辑)         │
└────────────────────┘
```

**综合后:**
- RTL 中的 `reg [1:0] state` → 2 个 D触发器
- RTL 中的 `case` 语句 → MUX树或AND-OR逻辑

---

### 2. 状态编码的影响

| 编码方式 | Binary | One-hot | Gray |
|---------|--------|---------|------|
| **3状态需要** | 2 bits | 3 bits | 2 bits |
| **DFF数量** | 2个 | 3个 | 2个 |
| **组合逻辑** | 较复杂 | 简单 | 中等 |
| **适用场景** | 面积优先 | 速度优先 | 低功耗 |

**在 FusionCompiler 中:**
- 工具根据约束自动选择最优编码
- `set_fsm_encoding` 可手动指定

**在 Yosys 中:**
- 默认保持 RTL 编码
- `fsm_recode -encoding <type>` 手动改变

---

### 3. Yosys FSM 命令详解

#### `fsm_detect`
```
功能: 扫描设计，识别哪些逻辑是状态机
输出: 标记 FSM 单元
```

#### `fsm_extract`
```
功能: 把 FSM 从 RTL 提取成专门的数据结构
输出: FSM 内部表示（状态表、转换表）
```

#### `fsm_opt`
```
功能: 优化 FSM（状态最小化、编码优化）
输出: 优化后的 FSM
```

#### `fsm_map`
```
功能: 把 FSM 重新映射成 RTL（已被 synth 包含）
输出: 优化后的 RTL
```

**对比 FusionCompiler:**
- FC 在 `elaborate` 阶段自动完成这些
- Yosys 分步骤，便于理解和调试

---

### 4. 综合结果分析

**输入 RTL: 约 80 行**
```verilog
module traffic_light (...);
  reg [1:0] current_state;
  reg [3:0] counter;
  always @(posedge clk) ...
  always @(*) ...
endmodule
```

**输出网表: 约 100-150 行门级代码**
```verilog
module traffic_light (...);
  $_DFF_N_ state_reg_0 (...);
  $_DFF_N_ state_reg_1 (...);
  $_AND_ gate_1 (...);
  $_MUX_ mux_1 (...);
  // ... 更多门
endmodule
```

**统计:**
- 6 个 DFF (2状态 + 4计数器)
- ~25-30 个组合逻辑门
- 总计 ~32-36 个单元

---

## 🆚 FusionCompiler vs Yosys 对比总结

### 综合流程对比

**FusionCompiler:**
```
read_verilog design.v
elaborate
compile_ultra
↓
一步到位，自动优化
```

**Yosys:**
```
read_verilog design.v
hierarchy -top
fsm_detect      ← 手动触发 FSM 识别
fsm_extract     ← 提取结构
fsm_opt         ← 优化
synth           ← 综合
↓
分步执行，过程可见
```

---

### 输出对比

| 特性 | Yosys | FusionCompiler |
|------|-------|----------------|
| **门类型** | `$_DFF_`, `$_AND_`, `$_MUX_` | `DFFR_X1`, `AND2_X2`, `MUX2_X1` |
| **技术库** | 通用门（技术无关） | 特定工艺库 |
| **物理信息** | ❌ 无 | ✅ 有坐标 |
| **时序信息** | ❌ 无 | ✅ 有延迟 |
| **面积** | ❌ 估算 | ✅ 精确 |
| **下一步** | 需要 tech mapping | 直接可以 P&R |

---

## 🎓 学到的综合原理

### 原理 1: 时序逻辑 = 寄存器
```verilog
// RTL
always @(posedge clk)
  q <= d;

// 综合成
$_DFF_P_ dff (.C(clk), .D(d), .Q(q));
```

### 原理 2: 组合逻辑 = 门
```verilog
// RTL
assign y = sel ? b : a;

// 综合成
$_MUX_ mux (.A(a), .B(b), .S(sel), .Y(y));
```

### 原理 3: Case语句 = MUX树
```verilog
// RTL
case (state)
  2'b00: out = a;
  2'b01: out = b;
  2'b10: out = c;
endcase

// 综合成
MUX4 (
  .I0(a), .I1(b), .I2(c), .I3(1'b0),
  .S(state),
  .O(out)
);
```

---

## 🤔 思考与练习

### Q1: 为什么 FusionCompiler 不需要手动 fsm_detect？
**答案：**
- FusionCompiler 在 `elaborate` 阶段自动识别
- 但过程是黑盒，用户看不到
- Yosys 暴露每一步，适合学习

---

### Q2: 如果状态数从 3 增加到 5，会怎样？
**Binary 编码：**
- 需要 ⌈log₂(5)⌉ = 3 bits
- DFF: 2个 → 3个
- 次态逻辑更复杂

**One-hot 编码：**
- 需要 5 bits
- DFF: 3个 → 5个
- 次态逻辑更简单

---

### Q3: 为什么要分三段式写状态机？
**答案：**
- 明确分离时序和组合逻辑
- 避免 latch（组合逻辑必须完备）
- 综合工具更容易识别和优化
- 便于仿真调试

---

## 📂 今天创建的文件

```
eda-tools/yosys/03_fsm_traffic_light/
├── traffic_light.v              # RTL 设计
├── synth.ys                     # 综合脚本
├── FSM_ANALYSIS.md              # FSM 理论分析
├── VISUAL_GUIDE.md              # 可视化指南
└── synth_result_simplified.v   # 综合结果示例
```

---

## 📈 学习进度

### Phase 1: 开源 EDA 工具链 (4-6周)

**Week 1: Yosys 基础**
- ✅ Day 1: Yosys 介绍和简单加法器
- ✅ Day 2: MUX 综合对比
- ✅ Day 2: FSM 综合实战 ← **当前位置**
- ⏳ Day 3: Technology mapping (映射到真实工艺库)
- ⏳ Day 4: 完整设计综合（FIFO/UART）

**Week 2-3: OpenROAD**
- ⏳ P&R 基础
- ⏳ 时序优化
- ⏳ 物理验证

**Week 4: OpenLane 自动化**
- ⏳ RTL → GDS 全流程

---

## 🎯 下一步计划

您现在有 3 个选项：

### 选项 A: 实战安装 Yosys ⚡
- 在 Windows 上安装 Yosys
- 亲自运行交通灯综合
- 查看真实的综合报告

### 选项 B: 继续理论学习 📚
- 学习 Technology Mapping（工艺映射）
- 了解如何对接 OpenROAD
- Sky130 开源 PDK 介绍

### 选项C: 综合更复杂设计 🚀
- FIFO 缓冲器
- UART 串口
- 简单的 CPU（8-bit）

---

## 💭 今天的感悟

### Yosys 的学习价值
- ✨ **透明性**: 每一步都看得见
- ✨ **灵活性**: 可以单步调试综合过程
- ✨ **对比性**: 理解商业工具的内部原理

### 与工作经验对比
- 在公司用 FusionCompiler: 快速、强大、黑盒
- 用 Yosys 学习: 慢一点、但理解更深
- **两者互补，相得益彰！**

---

**今天学得怎么样？准备好继续了吗？** 😊

请告诉我您想选择 A、B 还是 C！
