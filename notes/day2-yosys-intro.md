# Day 2: Yosys 开源综合工具入门

📅 日期：2026-03-12
🎯 目标：理解 Yosys 综合流程，对比 FusionCompiler

---

## 🔍 今天学到了什么

### 1. 开源 EDA vs 商业 EDA

| 特性 | FusionCompiler (商业) | Yosys (开源) |
|------|---------------------|--------------|
| License | 需要购买 💰 | 完全免费 ✅ |
| 学习环境 | 只能在公司 | 随时随地 ✅ |
| 源代码 | 闭源 | 开源可学习 ✅ |
| 物理感知 | 有（Floorplan驱动） | 无 |
| 时序优化 | 强大 | 基础 |

---

### 2. Yosys 在 EDA 流程中的位置

```
FusionCompiler 完整流程：
RTL → [逻辑综合] → [物理综合] → [P&R] → GDS
      └─────────────── 一体化 ────────────┘

开源工具链：
RTL → [Yosys 逻辑综合] → [OpenROAD 物理实现] → GDS
          ↑                      ↑
      只做逻辑优化          做物理相关的所有事
```

**Yosys 的定位：**
- FusionCompiler 流程的**最前端部分**
- 纯逻辑综合，不考虑物理位置
- 把 RTL 转换成门级网表（用基本逻辑门）

---

### 3. 第一个综合实验：4-bit 加法器

**文件位置：**
`/eda-tools/yosys/01_simple_adder/`

**RTL 代码（adder.v）：**
```verilog
module adder_4bit (
    input  [3:0] a, b,
    input        cin,
    output [3:0] sum,
    output       cout
);
    assign {cout, sum} = a + b + cin;
endmodule
```

**综合脚本（synth.ys）：**
```tcl
read_verilog adder.v       # 读RTL
hierarchy -top adder_4bit   # 设置顶层
synth -top adder_4bit       # 综合
write_verilog adder_synth.v # 输出网表
stat                        # 报告统计
```

---

### 4. Yosys vs FusionCompiler 命令对比

| 功能 | FusionCompiler | Yosys |
|------|----------------|-------|
| 读RTL | `read_verilog` 或 `analyze/elaborate` | `read_verilog` |
| 设置顶层 | `current_design` | `hierarchy -top` |
| 综合 | `compile_ultra` | `synth` |
| 输出网表 | `write -f verilog` | `write_verilog` |
| 查看统计 | `report_area`, `report_qor` | `stat` |

---

### 5. 综合结果理解

**原始 RTL（1行）：**
```verilog
assign {cout, sum} = a + b + cin;
```

**综合后网表（~60行门级代码）：**
- 使用了基本逻辑门：`$_XOR_`, `$_AND_`, `$_OR_`
- 实现了全加器逻辑
- 类似 FusionCompiler 的 PrePlace 网表（但无物理信息）

**统计结果：**
- 9个门（4个XOR + 4个AND + 1个OR）
- 这就是一个 4-bit 纹波进位加法器的标准实现！

---

## 🎓 关键概念

### Yosys 不需要的东西（vs FusionCompiler）：
❌ **SDC 约束文件** - Yosys 不做时序优化
❌ **Floorplan** - Yosys 不考虑物理位置
❌ **工艺库 (.lib)** - Yosys 默认用通用门（可以后期映射）

### Yosys 只需要的东西：
✅ **RTL 代码** (.v 文件)
✅ **综合脚本** (.ys 文件)

---

## 🤔 思考题

### Q1: 为什么 Yosys 不需要 SDC？
**答：** Yosys 只做**逻辑综合**（把RTL转成门），不做**时序优化**。
时序优化需要知道目标频率、延迟等 → 这是 OpenROAD 的工作。

### Q2: Yosys 输出的网表能直接做 P&R 吗？
**答：** 不能直接做。需要先用特定工艺库**映射**（technology mapping）。
流程：Yosys通用门 → 工艺映射 → 工艺库门 → OpenROAD P&R

### Q3: 和 FusionCompiler 比，Yosys 的优势是什么？
**答：**
- ✅ 免费，在家也能学
- ✅ 开源，可以看源码理解算法
- ✅ 轻量，适合学习和小项目

---

## 📚 下一步学习

- [ ] **实际安装 Yosys**（如果想动手运行）
- [ ] **学习 technology mapping**（映射到真实工艺库）
- [ ] **尝试综合更复杂的设计**（比如状态机、FIFO）
- [ ] **对接 OpenROAD**（完成 RTL → GDS 全流程）

---

## 📂 相关文件

- RTL设计：`../eda-tools/yosys/01_simple_adder/adder.v`
- 综合脚本：`../eda-tools/yosys/01_simple_adder/synth.ys`
- 演示输出：`../eda-tools/yosys/01_simple_adder/DEMO_OUTPUT.md`
- 网表示例：`../eda-tools/yosys/01_simple_adder/adder_synth_example.v`
