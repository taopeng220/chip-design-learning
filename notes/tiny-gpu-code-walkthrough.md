# tiny-gpu 代码深度解读

> 基于FC综合经验的硬件分析

---

## 🔍 核心代码剖析

### 1. ALU模块 (alu.sv) - 60行代码

#### 架构图：
```
        ┌─────────────────────────────────┐
        │         ALU (per thread)        │
        │                                 │
Input:  │  rs (8-bit) ──┐                │
        │               ├──→ Arithmetic  │
        │  rt (8-bit) ──┘    Logic       │
        │                       ↓         │
Control:│  decoded_alu_arithmetic_mux     │
        │    00: ADD                      │
        │    01: SUB                      │
        │    10: MUL    ← 关键路径！      │
        │    11: DIV    ← 最长路径！      │
        │                       ↓         │
Output: │              alu_out (8-bit)   │
        └─────────────────────────────────┘
```

#### 关键代码分析：

```systemverilog
// 第42-56行：算术运算
case (decoded_alu_arithmetic_mux)
    ADD: alu_out_reg <= rs + rt;      // 单周期，快
    SUB: alu_out_reg <= rs - rt;      // 单周期，快
    MUL: alu_out_reg <= rs * rt;      // ⚠️ 关键路径！
    DIV: alu_out_reg <= rs / rt;      // ⚠️⚠️ 最慢！
endcase
```

#### 从FC角度分析：

**时序问题：**
1. **MUL (乘法器)**
   - 8x8 = 16位结果，只取低8位
   - 组合逻辑延迟：约3-5ns (@28nm)
   - **FC建议：**
     ```tcl
     # 可能需要multi-cycle path
     set_multicycle_path -setup 2 -through [get_pins alu/MUL]

     # 或者插入pipeline
     # rs -> REG -> MUL -> REG -> result
     ```

2. **DIV (除法器)**
   - 最慢的组合逻辑！
   - 延迟：约10-15ns (@28nm)
   - **FC建议：**
     ```tcl
     # 必须pipeline或iterative实现
     # 选项1: 4-cycle pipeline divider
     # 选项2: 改成iterative (8 cycles)
     ```

**面积估算（单个ALU）：**
```
ADD/SUB:  ~50 gates each
MUL:      ~800 gates (8x8 Booth multiplier)
DIV:      ~1500 gates (或改成序列除法减少到~300 gates)
MUX:      ~50 gates
Total:    ~2500 gates per ALU
```

**如果32个thread：**
```
32 ALUs = 80,000 gates ≈ 20,000 NAND2等效
```

#### 优化策略（FC视角）：

```verilog
// 优化1：Shared Multiplier
// 不是每个thread都同时需要MUL
// 可以4个thread共享1个MUL → 面积减少75%

// 优化2：Pipeline MUL/DIV
module alu_pipelined (
    ...
);
    // Stage 1: Booth encoding
    // Stage 2: Partial products
    // Stage 3: Wallace tree
    // Stage 4: Final adder
endmodule

// 优化3：Approximate Computing (如果允许)
// 对某些应用，8-bit精度够了，用查找表近似
```

---

### 2. Scheduler模块 (scheduler.sv) - 116行代码 ⭐⭐⭐

#### 状态机图：

```
                    ┌──────┐
                    │ IDLE │
                    └───┬──┘
                        │ start
                        ↓
    ┌────────→ ┌───────┴────────┐
    │          │     FETCH      │  获取指令
    │          └───────┬────────┘
    │                  │ fetcher_state==FETCHED
    │                  ↓
    │          ┌───────┴────────┐
    │          │     DECODE     │  解码（1 cycle）
    │          └───────┬────────┘
    │                  │
    │                  ↓
    │          ┌───────┴────────┐
    │          │    REQUEST     │  请求数据（1 cycle）
    │          └───────┬────────┘
    │                  │
    │                  ↓
    │          ┌───────┴────────┐
    │          │      WAIT      │ ⚠️ 可能多周期！
    │          └───────┬────────┘  等待memory
    │                  │ all LSU ready
    │                  ↓
    │          ┌───────┴────────┐
    │          │    EXECUTE     │  执行ALU（1 cycle）
    │          └───────┬────────┘
    │                  │
    │                  ↓
    │          ┌───────┴────────┐
    │          │     UPDATE     │  更新寄存器/PC
    │          └───────┬────────┘
    │                  │
    │         ┌────────┴────────┐
    │         │ RET?            │
    │         └─┬──────────────┬┘
    │    No     │              │ Yes
    └───────────┘              ↓
                         ┌─────┴────┐
                         │   DONE   │
                         └──────────┘
```

#### 核心代码分析：

**第77-92行：WAIT状态 - 最关键！**

```systemverilog
WAIT: begin
    // 检查所有LSU是否完成
    reg any_lsu_waiting = 1'b0;
    for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
        if (lsu_state[i] == REQUESTING || lsu_state[i] == WAITING) begin
            any_lsu_waiting = 1'b1;
            break;  // ⚠️ 只要有一个等待，就继续等
        end
    end

    if (!any_lsu_waiting) begin
        core_state <= EXECUTE;
    end
end
```

**为什么这个很重要？**

```
场景：Matrix multiplication kernel

Thread 0: LOAD A[0]  ─────┐
Thread 1: LOAD A[1]  ─────┤
Thread 2: LOAD A[2]  ─────┤─→ 等待最慢的那个！
Thread 3: LOAD A[3]  ─────┘

如果memory latency = 10 cycles
→ Scheduler在WAIT状态停留10 cycles
→ 所有ALU闲置！
→ 利用率低！
```

**这就是为什么需要Warp Scheduling！**

---

### 3. 完整执行流程示例

#### 场景：执行 `C[i] = A[i] + B[i]`

```
Instruction 1: LOAD R1, A[i]    # 加载A
Instruction 2: LOAD R2, B[i]    # 加载B
Instruction 3: ADD  R3, R1, R2  # 相加
Instruction 4: STORE R3, C[i]   # 存储结果
```

#### 时序图（4个thread同时执行）：

```
Cycle  | Thread 0      | Thread 1      | Thread 2      | Thread 3      | State
-------|---------------|---------------|---------------|---------------|----------
  0    | -             | -             | -             | -             | IDLE
  1    | FETCH(LOAD)   | FETCH(LOAD)   | FETCH(LOAD)   | FETCH(LOAD)   | FETCH
  2    | DECODE        | DECODE        | DECODE        | DECODE        | DECODE
  3    | LSU→req A[0]  | LSU→req A[1]  | LSU→req A[2]  | LSU→req A[3]  | REQUEST
 4-13  | wait...       | wait...       | wait...       | wait...       | WAIT ⏰
  14   | A[0] ready    | A[1] ready    | A[2] ready    | A[3] ready    | EXECUTE
  15   | R1←A[0]       | R1←A[1]       | R1←A[2]       | R1←A[3]       | UPDATE
  16   | FETCH(LOAD)   | FETCH(LOAD)   | FETCH(LOAD)   | FETCH(LOAD)   | FETCH
  ...  | (重复 for LOAD B[i])                                           | ...
  30   | FETCH(ADD)    | FETCH(ADD)    | FETCH(ADD)    | FETCH(ADD)    | FETCH
  31   | DECODE        | DECODE        | DECODE        | DECODE        | DECODE
  32   | -             | -             | -             | -             | REQUEST
  33   | -             | -             | -             | -             | WAIT (立即完成)
  34   | R3←R1+R2      | R3←R1+R2      | R3←R1+R2      | R3←R1+R2      | EXECUTE
  35   | update        | update        | update        | update        | UPDATE
  ...
```

**关键观察：**
- 10个cycle等待memory（cycle 4-13）
- ALU只用了1个cycle（cycle 34）
- **利用率 = 1/30 ≈ 3%** 😱

**这就是GPU设计的核心挑战！**

---

## 🎯 从FC角度的综合策略

### 时序约束（假设100MHz目标）

```tcl
# 主时钟
create_clock -period 10.0 -name clk [get_ports clk]

# 关键路径约束
set_max_delay 8.0 -from [get_pins scheduler/core_state_reg*] \
                  -to [get_pins */enable]

# 多周期路径（memory access）
set_multicycle_path -setup 10 \
    -from [get_pins lsu/*/addr_reg*] \
    -to [get_pins mem_controller/*/data_out*]

# False path（异步信号）
set_false_path -from [get_ports reset] \
               -to [get_pins */reset]

# Input/Output delays
set_input_delay 2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]
```

### 面积优化策略

```tcl
# 1. Resource sharing
compile_ultra -gate_clock -retime

# 2. 指定面积优先
set_max_area 50000  # 根据target调整

# 3. 使用DesignWare IP
set_implementation MUL DW02_mult  # 优化的乘法器

# 4. Clock gating
insert_clock_gating

# 5. 层次化综合
compile_ultra -incremental
```

### 功耗优化策略

```tcl
# 1. Multi-Vt optimization
set_attribute [get_lib_cells */BUFX*] dont_use false

# 2. Clock gating
set_clock_gating_style -num_stages 2

# 3. Operand isolation
set_operand_isolation_style -style and

# 4. Power gating (advanced)
# 为idle的core断电
```

---

## 📊 预估的综合结果

### 配置：4 cores × 4 threads/core = 16 parallel threads

```
模块              面积(NAND2)   频率(MHz)   功耗(mW@100MHz)
------------------------------------------------------------
ALU (×16)         40,000       200+        15
Registers (×16)   10,000       300+         5
Scheduler (×4)     2,000       250+         2
LSU (×16)          8,000       150-        10
Memory Ctrl        5,000       100-        20
Dispatcher         1,000       200+         1
------------------------------------------------------------
Total             66,000       100-150      53
```

**关键瓶颈：**
1. **Memory Controller** - 频率最低
2. **LSU** - 异步逻辑复杂
3. **ALU (DIV)** - 组合逻辑深

---

## 🚀 实验计划

### 实验1：基础仿真（今天）
```bash
cd test/
# 看看GPU实际怎么跑的
```

### 实验2：单模块综合（明天）
```bash
# 综合ALU，分析时序
yosys -p "read_verilog -sv alu.sv; synth; stat"
```

### 实验3：优化对比（本周）
```bash
# 对比：
# - 原始ALU vs Pipeline ALU
# - 面积 vs 性能 trade-off
```

---

## 💡 学习收获

### 1. GPU的本质
```
GPU = 简单核心 × 数量 + 统一控制
不是一个超级聪明的核心，而是很多听话的工人！
```

### 2. SIMD的代价
```
优点：硬件简单（共享decoder）
缺点：效率依赖于数据并行性
如果thread分支不同 → 性能大降
```

### 3. Memory Wall
```
计算很快（1 cycle）
访存很慢（10+ cycles）
→ 必须有clever调度hiding latency
```

### 4. 综合的挑战
```
从FC角度：
- 时序：MUL/DIV路径长
- 面积：大量重复单元
- 功耗：并行度高 → 切换多
需要balance！
```

---

**下一步：运行仿真，看实际执行！** 🚀
