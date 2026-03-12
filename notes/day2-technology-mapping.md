# Day 2 (续): Technology Mapping - 从通用门到工艺库

📅 日期：2026-03-12
🎯 目标：理解工艺映射原理，连接逻辑综合和物理实现

---

## 🎯 什么是 Technology Mapping？

### 简单来说：

```
Yosys 综合输出:           Technology Mapping:      真实芯片:
通用门（抽象）    ───────►  选择具体实现    ───────►  标准单元（物理）

$_AND_                    AND2_X1                   实际晶体管电路
$_DFF_                    DFFR_X2                   真实触发器
$_MUX_                    MUX2_X4                   多路选择器单元
```

---

## 🆚 通用门 vs 标准单元

### Yosys 的通用门（技术无关）

```verilog
// Yosys 输出
$_AND_ gate1 (
    .A(a),
    .B(b),
    .Y(out)
);

$_DFF_P_ reg1 (
    .C(clk),
    .D(d),
    .Q(q)
);
```

**特点：**
- ❌ 没有具体的驱动能力
- ❌ 没有延迟信息
- ❌ 没有功耗数据
- ❌ 没有物理尺寸
- ✅ 只有逻辑功能

---

### 标准单元库（工艺相关）

```verilog
// 映射到 180nm 工艺库
AND2_X1 gate1 (    // 2输入AND，1倍驱动
    .A1(a),
    .A2(b),
    .ZN(out)
);

DFFR_X2 reg1 (     // 带复位DFF，2倍驱动
    .CK(clk),
    .D(d),
    .RN(rst_n),
    .Q(q)
);
```

**特点：**
- ✅ 有具体的驱动能力（X1, X2, X4...）
- ✅ 有延迟信息（从 .lib 文件）
- ✅ 有功耗数据
- ✅ 有物理尺寸（面积）
- ✅ 可以进行时序分析和 P&R

---

## 📊 对比 FusionCompiler vs Yosys

### FusionCompiler 的工艺映射

```tcl
# FusionCompiler 脚本
read_verilog design.v
set_app_var target_library "tech_lib.db"   # ← 指定工艺库
compile_ultra                               # ← 自动映射
```

**内部流程：**
```
RTL → 逻辑综合 → 工艺映射 → 优化 → 网表
              └────┬────┘
                自动完成（黑盒）
```

**FusionCompiler 做什么：**
1. 读取 `.db` 或 `.lib` 文件（工艺库）
2. 自动选择最优的标准单元
3. 根据约束（时序/面积/功耗）优化
4. 输出已映射的网表

**您看不到：**
- 具体选择了哪个门（除非看报告）
- 为什么选择这个门
- 有哪些备选方案

---

### Yosys 的工艺映射

```tcl
# Yosys 脚本
read_verilog design.v
synth -top top_module          # ← 综合成通用门

# 工艺映射（需要手动指定）
dfflibmap -liberty tech.lib    # ← 映射寄存器
abc -liberty tech.lib           # ← 映射组合逻辑

write_verilog mapped.v          # ← 输出映射后网表
```

**流程：**
```
RTL → Yosys综合 → 通用门 → 工艺映射 → 标准单元网表
                     ↓           ↓
                  可见过程    手动控制
```

**Yosys 做什么：**
1. 先综合成通用门（$_AND_, $_DFF_ 等）
2. 读取 `.lib` 文件（Liberty 格式）
3. **分步映射**：
   - `dfflibmap`: 映射寄存器（DFF/LATCH）
   - `abc`: 映射组合逻辑（AND/OR/MUX...）
4. 输出已映射的网表

**您能看到：**
- ✅ 每一步的转换过程
- ✅ 选择了哪些标准单元
- ✅ 映射前后的对比

---

## 🔍 深入：工艺映射的本质

### 问题：如何选择标准单元？

假设工艺库有这些 AND 门：

| 标准单元 | 输入数 | 驱动能力 | 延迟 | 面积 | 功耗 |
|---------|--------|---------|------|------|------|
| AND2_X1 | 2 | 低 | 0.5ns | 1x | 1x |
| AND2_X2 | 2 | 中 | 0.3ns | 1.5x | 1.8x |
| AND2_X4 | 2 | 高 | 0.2ns | 2x | 3x |
| AND3_X1 | 3 | 低 | 0.6ns | 1.2x | 1.2x |
| AND4_X1 | 4 | 低 | 0.7ns | 1.5x | 1.5x |

**如果要实现 `y = a & b`，选哪个？**

---

### FusionCompiler 的选择策略：

```
IF 时序关键路径:
    选择 AND2_X4 (最快，但贵)
ELSE IF 需要驱动很多扇出:
    选择 AND2_X2 (平衡)
ELSE:
    选择 AND2_X1 (省面积)
```

**基于：**
- SDC 约束（时序要求）
- 扇出负载
- 优化目标（面积/速度/功耗）

---

### Yosys (ABC) 的选择策略：

```
默认策略:
    最小化延迟（如果有时序库）
    或最小化面积（如果没有时序信息）

手动控制:
    abc -liberty tech.lib -D 1000    # 优化延迟
    abc -liberty tech.lib -A          # 优化面积
```

**基于：**
- Liberty 文件的信息
- 用户指定的优化目标
- 局部优化（不考虑全局时序）

---

## 📖 Liberty 文件 (.lib) 详解

### 什么是 Liberty 文件？

Liberty 是**工艺库的标准描述格式**，包含：
- 标准单元的功能
- 时序信息（延迟、建立时间、保持时间）
- 功耗信息
- 面积信息

### Liberty 文件示例

```liberty
/* 简化的 Liberty 文件示例 */

library(example_tech) {
  /* 工艺参数 */
  technology : cmos;
  delay_model : table_lookup;

  /* 单元定义: 2输入 AND 门，1倍驱动 */
  cell(AND2_X1) {
    area : 1.5;                    /* 面积 */

    pin(A) {
      direction : input;
      capacitance : 0.002;          /* 输入电容 */
    }

    pin(B) {
      direction : input;
      capacitance : 0.002;
    }

    pin(Y) {
      direction : output;
      function : "A & B";            /* 逻辑功能 */

      timing() {
        related_pin : "A";
        cell_rise(delay_template) {
          values("0.05, 0.06, 0.08"); /* A→Y 上升延迟 */
        }
        cell_fall(delay_template) {
          values("0.04, 0.05, 0.07"); /* A→Y 下降延迟 */
        }
      }

      timing() {
        related_pin : "B";
        /* B→Y 的延迟... */
      }
    }

    /* 功耗信息 */
    leakage_power : 0.001;
  }

  /* DFF 单元定义 */
  cell(DFFR_X1) {
    area : 5.0;
    ff(IQ, IQN) {
      next_state : "D";
      clocked_on : "CK";
      clear : "!RN";
    }

    pin(CK) {
      direction : input;
      clock : true;
    }

    pin(D) {
      direction : input;
      capacitance : 0.003;

      timing() {
        related_pin : "CK";
        timing_type : setup_rising;
        rise_constraint(setup_template) {
          values("0.1, 0.12, 0.15");  /* Setup time */
        }
      }

      timing() {
        related_pin : "CK";
        timing_type : hold_rising;
        rise_constraint(hold_template) {
          values("0.02, 0.03, 0.04"); /* Hold time */
        }
      }
    }

    pin(Q) {
      direction : output;
      function : "IQ";

      timing() {
        related_pin : "CK";
        timing_type : rising_edge;
        cell_rise(delay_template) {
          values("0.3, 0.35, 0.4");   /* CK→Q 延迟 */
        }
      }
    }
  }
}
```

---

## 🔧 Yosys 工艺映射命令详解

### 1. `dfflibmap` - 映射寄存器

```tcl
dfflibmap -liberty tech.lib
```

**功能：**
- 把 `$_DFF_P_`, `$_DFF_N_` 等通用寄存器
- 映射到库中的 DFF 单元

**映射规则：**
```
$_DFF_P_        → DFFP_X1    (正边沿，无复位)
$_DFF_N_        → DFFN_X1    (负边沿，无复位)
$_DFFR_PPP_     → DFFR_X1    (正边沿，异步复位)
```

---

### 2. `abc` - 映射组合逻辑

```tcl
abc -liberty tech.lib [选项]
```

**常用选项：**
```tcl
abc -liberty tech.lib              # 默认优化
abc -liberty tech.lib -D 1000      # 优化延迟（delay）
abc -liberty tech.lib -A           # 优化面积（area）
abc -liberty tech.lib -constr constraints.sdc  # 考虑时序约束
```

**ABC 是什么？**
- 独立的逻辑综合和优化工具
- 由 UC Berkeley 开发
- Yosys 集成了 ABC 做工艺映射

---

### 3. 完整映射流程示例

```tcl
# 读入设计
read_verilog adder.v

# 逻辑综合（生成通用门）
synth -top adder_4bit

# 映射寄存器
dfflibmap -liberty sky130_fd_sc_hd.lib

# 映射组合逻辑
abc -liberty sky130_fd_sc_hd.lib

# 清理优化
opt_clean

# 输出映射后的网表
write_verilog -noattr -noexpr adder_mapped.v

# 统计
stat -liberty sky130_fd_sc_hd.lib
```

---

## 💡 关键概念总结

### 1. 为什么需要 Technology Mapping？

| 阶段 | 输出 | 能否制造？ | 能否时序分析？ |
|------|------|-----------|--------------|
| RTL | 行为描述 | ❌ | ❌ |
| 逻辑综合 | 通用门 | ❌ | ❌ |
| **工艺映射** | **标准单元** | ✅ | ✅ |
| P&R | 带坐标网表 | ✅ | ✅ |

**Technology Mapping 是从"抽象"到"具体"的桥梁！**

---

### 2. FusionCompiler vs Yosys 工艺映射对比

| 特性 | FusionCompiler | Yosys + ABC |
|------|----------------|-------------|
| **输入库格式** | .db / .lib | .lib (Liberty) |
| **映射时机** | 综合中自动 | 综合后手动 |
| **优化策略** | 全局最优（考虑时序） | 局部最优 |
| **单元选择** | 智能（考虑扇出、负载） | 基于延迟/面积 |
| **可控性** | 低（黑盒） | 高（分步控制）|
| **学习价值** | 工业级 | 理解原理 ✨ |

---

### 3. 标准单元的命名规则

以 `AND2_X4` 为例：
```
AND2_X4
│││ └─ X4: 驱动能力（4倍标准驱动）
│││
││└─── 2: 输入数量（2输入）
││
│└──── AND: 逻辑功能
│
└───── 标准单元类型
```

**常见单元：**
- `AND2_X1/X2/X4` - 2输入AND门
- `NAND2_X1/X2` - 2输入NAND门
- `MUX2_X1` - 2选1多路选择器
- `DFFR_X1/X2` - 带复位的D触发器
- `INV_X1/X2/X4` - 反相器（Buffer也算）

---

## 🤔 思考题

### Q1: 为什么 FusionCompiler 可以一步到位，Yosys 需要分步映射？

**答案：**
- FusionCompiler 是**商业工具**，内部集成了复杂的优化算法
  - 全局时序分析
  - 考虑物理信息（预布局）
  - 迭代优化

- Yosys 是**开源轻量级工具**，专注逻辑综合
  - 不做物理感知
  - 依赖外部工具（ABC）做映射
  - 分步清晰，便于学习

---

### Q2: 如果工艺库没有 MUX 单元，Yosys 怎么办？

**答案：**
ABC 会自动**分解** MUX：
```
MUX(A, B, S) = (S & B) | (!S & A)

映射成：
NOT_X1 + AND2_X1 + AND2_X1 + OR2_X1
```

这就是为什么要先综合成通用门 - 灵活性！

---

### Q3: 驱动能力（X1/X2/X4）是怎么选的？

**在 FusionCompiler 中：**
- 根据**扇出**（fanout）自动选择
- 驱动很多门 → 选 X4
- 只驱动1-2个门 → 选 X1

**在 Yosys/ABC 中：**
- 默认选择**最小面积**单元（X1）
- 后续由 OpenROAD 根据时序需求调整
- 或者手动指定优化策略

---

## 📚 下一步学习

现在您理解了工艺映射，下一步可以学习：

- [ ] **开源 PDK 介绍**（Sky130 工艺）
- [ ] **OpenROAD 基础**（P&R 工具）
- [ ] **完整流程演示**（RTL → GDS）

---

**先暂停一下，回答我最开始的问题，让我确认您理解了！** 😊
