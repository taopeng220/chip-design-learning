# Yosys 综合演示 - 预期输出

## 运行命令
```bash
yosys synth.ys
```

## 预期输出流程

### 1️⃣ 读入 RTL（read_verilog adder.v）
```
-- Running command `read_verilog adder.v' --
1. Parsing Verilog input from `adder.v' to AST representation.
2. Generating RTLIL representation for module `\adder_4bit'.
Successfully finished Verilog frontend.
```

**对应 FusionCompiler：** `read_verilog` 或 `analyze/elaborate`

---

### 2️⃣ 设置层次结构（hierarchy -top adder_4bit）
```
-- Running command `hierarchy -top adder_4bit' --
Top module:  \adder_4bit
```

**对应 FusionCompiler：** `current_design adder_4bit`

---

### 3️⃣ 综合（synth -top adder_4bit）
```
-- Running command `synth -top adder_4bit' --

3.1. Beginning synthesis
3.2. Executing Verilog-2005 frontend
3.3. Executing proc pass (convert processes to netlists)
3.4. Executing opt_expr pass (perform const folding)
3.5. Executing opt_clean pass (remove unused cells and wires)
3.6. Executing wreduce pass (reduce word size of operations)
3.7. Executing techmap pass (map to technology primitives)
    - Mapping adder to basic logic gates
3.8. Executing opt pass (optimize design)
```

**对应 FusionCompiler：** `compile_ultra` 或 `compile`

**Yosys 做了什么？**
- 把 `a + b + cin` 拆解成逻辑门
- 优化掉不必要的逻辑
- 映射到基本单元（AND, OR, XOR, NOT等）

---

### 4️⃣ 输出网表（write_verilog adder_synth.v）
```
-- Running command `write_verilog adder_synth.v' --
Writing Verilog backend to `adder_synth.v'
```

---

### 5️⃣ 统计报告（stat）
```
-- Running command `stat' --

=== adder_4bit ===

   Number of wires:                 13
   Number of wire bits:             18
   Number of public wires:           7
   Number of public wire bits:      12
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                  9
     $_AND_                          4
     $_OR_                           1
     $_XOR_                          4
```

**这个报告告诉我们：**
- 设计用了 **9 个门**（4个AND，1个OR，4个XOR）
- 相当于 FusionCompiler 的 `report_area` 或 `report_qor`

---

## 综合后的网表长什么样？

综合后的 `adder_synth.v` 会把您的简洁代码：
```verilog
assign {cout, sum} = a + b + cin;
```

转换成具体的门级实现（类似 PrePlace 网表）：
```verilog
module adder_4bit(a, b, cin, sum, cout);
  input [3:0] a;
  input [3:0] b;
  input cin;
  output [3:0] sum;
  output cout;

  wire _00_, _01_, _02_, ...;  // 中间信号

  $_XOR_ gate_1 (.A(a[0]), .B(b[0]), .Y(_00_));
  $_XOR_ gate_2 (.A(_00_), .B(cin), .Y(sum[0]));
  $_AND_ gate_3 (.A(a[0]), .B(b[0]), .Y(_01_));
  // ... 更多门
endmodule
```

---

## 🔍 关键差异对比

| 项目 | FusionCompiler | Yosys |
|------|----------------|-------|
| **输入约束** | SDC文件（时序约束） | 不需要（纯逻辑综合） |
| **工艺库** | 需要（.lib文件） | 可选（默认用通用门） |
| **物理信息** | 需要 Floorplan | 不需要（无物理感知） |
| **优化目标** | 时序、面积、功耗 | 主要是逻辑优化 |
| **输出** | 有时序的网表 | 纯逻辑网表 |

**Yosys 的定位：**
- 更像是 FusionCompiler 流程中的**最前端部分**
- 只做逻辑综合，不考虑物理
- 如果需要物理优化 → 交给 OpenROAD

---

## 下一步

如果您想**亲自运行这个例子**，我可以帮您：
1. 快速安装 Yosys（Windows 上 5-10 分钟）
2. 运行这个综合，看真实输出
3. 查看生成的门级网表

**想试试真实运行吗？** 😊
