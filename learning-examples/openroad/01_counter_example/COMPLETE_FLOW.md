# 完整 OpenROAD 流程实例 - 4-bit Counter

📅 日期：2026-03-13
🎯 从 RTL 到 GDS 的完整演示

---

## 📊 设计概述

### RTL 设计
```verilog
module counter (
    input  clk,
    input  rst_n,
    input  enable,
    output reg [3:0] count,
    output overflow
);
```

**功能：**
- 4-bit 同步计数器
- 异步复位（低有效）
- 使能控制
- 溢出标志

**规模：**
- 4 个 DFF（存储 count）
- 1 个 4-bit 加法器（count + 1）
- 1 个比较器（检测 overflow）
- 约 30-40 个标准单元

**时序约束：**
- 时钟频率：100MHz（周期 10ns）
- 输入延迟：2ns
- 输出延迟：2ns

---

## 🔄 完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: RTL 设计                                             │
│   counter.v                                                  │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Yosys 逻辑综合                                       │
│   - 读入 RTL                                                 │
│   - 综合成通用门                                              │
│   输出：counter_synth.v（通用门网表）                         │
│                                                              │
│   【STA: Wire Delay = 未知，不可信】                         │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: ABC 工艺映射                                         │
│   - 映射到标准单元库（Sky130）                                │
│   输出：counter_mapped.v（标准单元网表）                      │
│                                                              │
│   【STA: 有 Cell Delay，但 Wire Delay 仍是估算】             │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: OpenROAD - Floorplan                                │
│   - 初始化芯片尺寸                                            │
│   - 放置 IO Pad                                              │
│   - 生成电源网络                                              │
│                                                              │
│   【STA: Wire Delay ≈ 面积估算，Slack ±30%】                 │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: OpenROAD - Placement                                │
│   - Global Placement（优化线长）                             │
│   - Detailed Placement（合法化）                             │
│   输出：每个单元的精确位置                                     │
│                                                              │
│   【STA: Wire Delay ≈ 实际距离，Slack ±15%】                 │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 6: OpenROAD - CTS                                      │
│   - 构建时钟树                                                │
│   - 平衡 Clock Latency                                       │
│   输出：Clock Buffer 网络                                     │
│                                                              │
│   【STA: Clock Delay 精确，Slack ±10%】                      │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 7: OpenROAD - Routing                                  │
│   - Global Routing（规划路径）                               │
│   - Detailed Routing（实际走线）                             │
│   输出：完整的金属走线                                         │
│                                                              │
│   【STA: Wire Delay 精确（预估），Slack ±5%】                │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 8: OpenROAD - Parasitic Extraction                    │
│   - 提取寄生 RC                                               │
│   - 生成 SPEF 文件                                            │
│                                                              │
│   【STA: 所有 Delay 精确，Slack 可信 ✅】                     │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 9: 输出 GDS                                             │
│   - 生成最终版图                                              │
│   - 可以送去制造                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Step 1: Yosys 综合

### 1.1 创建综合脚本

**文件：`synth.ys`**

```tcl
# Yosys 综合脚本

# 读入 RTL
read_verilog counter.v

# 设置顶层
hierarchy -top counter

# 进行综合
synth -top counter

# 输出通用门网表
write_verilog counter_synth.v

# 查看统计
stat
```

### 1.2 运行 Yosys

```bash
yosys synth.ys
```

### 1.3 预期输出

```
=== counter ===

   Number of wires:                 18
   Number of wire bits:             25
   Number of public wires:           6
   Number of public wire bits:      13
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                 28
     $_AND_                          4
     $_DFF_N_                        4    ← 4 个 DFF
     $_MUX_                          6
     $_NAND_                         2
     $_NOR_                          3
     $_NOT_                          5
     $_OR_                           2
     $_XOR_                          2

Synthesis finished.
```

**关键观察：**
- 4 个 DFF（存储 count[3:0]）
- 约 24 个组合逻辑门
- 总共 28 个单元

---

## 🔧 Step 2: 工艺映射（假设使用 Sky130）

### 2.1 创建映射脚本

**文件：`map.ys`**

```tcl
# 读入综合后的网表
read_verilog counter_synth.v

# 读入 Sky130 标准单元库
read_liberty -lib sky130_fd_sc_hd__tt_025C_1v80.lib

# 设置顶层
hierarchy -top counter

# 映射寄存器
dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib

# 映射组合逻辑
abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib

# 清理
clean

# 输出标准单元网表
write_verilog -noattr -noexpr counter_mapped.v

# 统计（带库信息）
stat -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
```

### 2.2 预期输出（映射到 Sky130）

```
=== counter ===

   Chip area for module '\counter': 125.123200

   Number of cells:                 28
     sky130_fd_sc_hd__and2_1         4
     sky130_fd_sc_hd__dfxtp_1        4    ← DFF with async reset
     sky130_fd_sc_hd__mux2_1         6
     sky130_fd_sc_hd__nand2_1        2
     sky130_fd_sc_hd__nor2_1         3
     sky130_fd_sc_hd__inv_1          5
     sky130_fd_sc_hd__or2_1          2
     sky130_fd_sc_hd__xor2_1         2

Total area: 125.1 um²
```

**关键观察：**
- 从通用门映射到了具体的 Sky130 单元
- 每个单元有了面积信息
- 可以估算芯片大小

---

## 📐 Step 3: OpenROAD Floorplan

### 3.1 创建 OpenROAD 脚本

**文件：`01_floorplan.tcl`**

```tcl
# ============================================
# OpenROAD Floorplan 脚本
# ============================================

# 读入设计和库
read_lef sky130_fd_sc_hd.tlef           # 工艺 LEF
read_lef sky130_fd_sc_hd.lef            # 标准单元 LEF
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog counter_mapped.v
link_design counter

# 初始化 Floorplan
# 芯片大小：根据面积估算
# 面积 = 125 um² → 需要考虑 utilization
# 假设 70% utilization → 总面积 = 125 / 0.7 = 179 um²
# 正方形：边长 ≈ 13.4 um → 使用 15um × 15um

initialize_floorplan \
  -die_area "0 0 15 15" \         # Die 15um × 15um
  -core_area "1 1 14 14" \        # Core 13um × 13um (留 margin)
  -site unithd                    # Sky130 标准单元格子

# 放置 IO Pins
# 简单设计，自动放置
place_pins -hor_layers met3 \
           -ver_layers met2

# 生成电源网络（PDN）
pdngen sky130_pdn_config.tcl

# 保存 Floorplan
write_def counter_floorplan.def

puts "Floorplan completed!"
```

### 3.2 查看芯片布局

```
Die Area: 15um × 15um = 225 um²
Core Area: 13um × 13um = 169 um²
Utilization: 125 / 169 = 74%  ← 合理

IO Pins:
  - clk: 左侧
  - rst_n: 左侧
  - enable: 左侧
  - count[3:0]: 右侧
  - overflow: 右侧
```

---

## 📍 Step 4: OpenROAD Placement

### 4.1 创建 Placement 脚本

**文件：`02_placement.tcl`**

```tcl
# ============================================
# OpenROAD Placement 脚本
# ============================================

# 读入 Floorplan 结果
read_lef sky130_fd_sc_hd.tlef
read_lef sky130_fd_sc_hd.lef
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_def counter_floorplan.def

# Global Placement
global_placement \
  -density 0.7 \                # 70% 密度
  -pad_left 2 \                 # 边界留白
  -pad_right 2

# Detailed Placement
detailed_placement

# 优化（可选）
improve_placement

# 保存 Placement 结果
write_def counter_placed.def

# 此时可以做初步 STA
puts "\n=== Post-Placement Timing ==="

# 设置时钟
create_clock -period 10.0 -name clk [get_ports clk]

# 设置输入延迟
set_input_delay -clock clk -max 2.0 [get_ports {enable rst_n}]

# 设置输出延迟
set_output_delay -clock clk -max 2.0 [get_ports {count[*] overflow}]

# 估算寄生参数（基于距离）
estimate_parasitics -placement

# 运行 STA
report_checks -path_delay min_max -format full_clock_expanded

puts "Placement completed!"
```

### 4.2 预期 STA 结果（Placement 后）

```
========================================
Post-Placement Timing Report
========================================

Startpoint: count_reg[0] (rising edge-triggered flip-flop)
Endpoint: count_reg[0] (rising edge-triggered flip-flop)
Path Group: clk
Path Type: max

Point                                    Incr       Path
------------------------------------------------------------
clock clk (rise edge)                    0.00       0.00
clock network delay (ideal)              0.00       0.00
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                         0.00       0.00 r
count_reg[0]/Q (sky130_fd_sc_hd__dfxtp_1)
                                         0.45       0.45 r
add_1/A (sky130_fd_sc_hd__ha_1)  (est)  0.05       0.50 r  ← Wire Delay 估算
add_1/S (sky130_fd_sc_hd__ha_1)         0.28       0.78 r
...
count_reg[0]/D (sky130_fd_sc_hd__dfxtp_1)
                                         0.03       1.85 r
data arrival time                                   1.85

clock clk (rise edge)                   10.00      10.00
clock network delay (ideal)              0.00      10.00
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                                   10.00 r
library setup time                      -0.12       9.88
data required time                                  9.88
------------------------------------------------------------
slack (MET)                                         8.03

========================================
Summary:
  Slack: +8.03ns  ← 很大！但不准确（Wire Delay 是估算）
  Arrival Time: 1.85ns
  Required Time: 9.88ns
========================================
```

**关键观察：**
- Wire Delay 标记为 `(est)` - 估算
- Slack 看起来很大（+8.03ns）
- 但这是基于距离的粗估，不是最终值

---

## ⏰ Step 5: OpenROAD CTS

### 5.1 创建 CTS 脚本

**文件：`03_cts.tcl`**

```tcl
# ============================================
# OpenROAD Clock Tree Synthesis 脚本
# ============================================

# 读入 Placement 结果
read_lef sky130_fd_sc_hd.tlef
read_lef sky130_fd_sc_hd.lef
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_def counter_placed.def

# 设置时钟约束
create_clock -period 10.0 -name clk [get_ports clk]
set_propagated_clock [all_clocks]  # 使用实际时钟延迟（不是 ideal）

# 运行 CTS
clock_tree_synthesis \
  -root_buf sky130_fd_sc_hd__clkbuf_4 \     # 时钟 buffer
  -buf_list "sky130_fd_sc_hd__clkbuf_2 \
             sky130_fd_sc_hd__clkbuf_4 \
             sky130_fd_sc_hd__clkbuf_8" \
  -sink_clustering_enable \
  -sink_clustering_size 5

# 保存 CTS 结果
write_def counter_cts.def

# CTS 后的 STA
puts "\n=== Post-CTS Timing ==="

set_input_delay -clock clk -max 2.0 [get_ports {enable rst_n}]
set_output_delay -clock clk -max 2.0 [get_ports {count[*] overflow}]

estimate_parasitics -placement

report_checks -path_delay min_max -format full_clock_expanded

# 检查 Clock Skew
report_clock_skew -setup

puts "CTS completed!"
```

### 5.2 预期 STA 结果（CTS 后）

```
========================================
Post-CTS Timing Report
========================================

Startpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Endpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

Point                                    Incr       Path
------------------------------------------------------------
clock clk (rise edge)                    0.00       0.00
clock network delay (propagated)         0.85       0.85  ← 实际时钟延迟！
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                         0.00       0.85 r
count_reg[0]/Q (sky130_fd_sc_hd__dfxtp_1)
                                         0.45       1.30 r
add_1/A (sky130_fd_sc_hd__ha_1)  (est)  0.05       1.35 r
add_1/S (sky130_fd_sc_hd__ha_1)         0.28       1.63 r
...
count_reg[0]/D (sky130_fd_sc_hd__dfxtp_1)
                                         0.03       2.70 r
data arrival time                                   2.70

clock clk (rise edge)                   10.00      10.00
clock network delay (propagated)         0.87      10.87  ← 实际时钟延迟！
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                                   10.87 r
library setup time                      -0.12      10.75
data required time                                 10.75
------------------------------------------------------------
slack (MET)                                         8.05

========================================
Clock Skew Report:
  Max Latency:   0.87ns (to count_reg[3])
  Min Latency:   0.85ns (to count_reg[0])
  Clock Skew:    0.02ns  ← 很小！CTS 做得好
========================================

Summary:
  Slack: +8.05ns
  Launch Clock: 0.85ns
  Capture Clock: 0.87ns
  Skew: 0.02ns  ← 平衡良好
```

**关键变化：**
- Clock Delay 从 `ideal 0.00ns` 变成 `propagated 0.85ns`
- Arrival Time 从 1.85ns 增加到 2.70ns
- Required Time 也增加（Capture Clock）
- Slack 几乎没变（Launch 和 Capture 都增加）
- **Skew 很小（20ps）**，说明时钟树平衡

---

## 🛤️ Step 6: OpenROAD Routing

### 6.1 创建 Routing 脚本

**文件：`04_routing.tcl`**

```tcl
# ============================================
# OpenROAD Routing 脚本
# ============================================

# 读入 CTS 结果
read_lef sky130_fd_sc_hd.tlef
read_lef sky130_fd_sc_hd.lef
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_def counter_cts.def

# 设置约束
create_clock -period 10.0 -name clk [get_ports clk]
set_propagated_clock [all_clocks]
set_input_delay -clock clk -max 2.0 [get_ports {enable rst_n}]
set_output_delay -clock clk -max 2.0 [get_ports {count[*] overflow}]

# Global Routing
global_route \
  -guide_file counter.route_guide \
  -congestion_iterations 100

# Detailed Routing
detailed_route \
  -output_drc counter_drc.rpt \
  -output_maze counter_maze.log \
  -verbose 1

# 保存 Routing 结果
write_def counter_routed.def

# Routing 后的 STA（预估）
puts "\n=== Post-Route Timing (Estimated) ==="

estimate_parasitics -global_routing

report_checks -path_delay min_max -format full_clock_expanded

puts "Routing completed!"
```

### 6.2 预期 STA 结果（Routing 后，预估寄生）

```
========================================
Post-Route Timing Report (Estimated)
========================================

Startpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Endpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

Point                                    Incr       Path
------------------------------------------------------------
clock clk (rise edge)                    0.00       0.00
clock network delay (propagated)         0.87       0.87
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                         0.00       0.87 r
count_reg[0]/Q (sky130_fd_sc_hd__dfxtp_1)
                                         0.45       1.32 r
add_1/A (sky130_fd_sc_hd__ha_1)         0.08       1.40 r  ← Wire Delay 增加
add_1/S (sky130_fd_sc_hd__ha_1)         0.28       1.68 r
...
count_reg[0]/D (sky130_fd_sc_hd__dfxtp_1)
                                         0.06       2.95 r
data arrival time                                   2.95

clock clk (rise edge)                   10.00      10.00
clock network delay (propagated)         0.89      10.89
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                                   10.89 r
library setup time                      -0.12      10.77
data required time                                 10.77
------------------------------------------------------------
slack (MET)                                         7.82

========================================
Summary:
  Slack: +7.82ns (比 CTS 后少了 0.23ns)
  Arrival Time: 2.95ns (比 CTS 后多了 0.25ns)
  Wire Delay 增加（实际走线比直线长）
========================================
```

**关键变化：**
- Wire Delay 进一步增加（实际走线）
- Slack 从 +8.05ns 减少到 +7.82ns
- 仍然满足时序，但裕量减少

---

## 📏 Step 7: 寄生参数提取

### 7.1 创建提取脚本

**文件：`05_extraction.tcl`**

```tcl
# ============================================
# OpenROAD Parasitic Extraction 脚本
# ============================================

# 读入 Routing 结果
read_lef sky130_fd_sc_hd.tlef
read_lef sky130_fd_sc_hd.lef
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_def counter_routed.def

# 提取寄生参数（RC）
extract_parasitics \
  -ext_model_file sky130.extmodel

# 写出 SPEF 文件
write_spef counter.spef

# 设置约束
create_clock -period 10.0 -name clk [get_ports clk]
set_propagated_clock [all_clocks]
set_input_delay -clock clk -max 2.0 [get_ports {enable rst_n}]
set_output_delay -clock clk -max 2.0 [get_ports {count[*] overflow}]

# 读入 SPEF
read_spef counter.spef

# 最终 STA
puts "\n=== Final Timing with SPEF ==="

report_checks -path_delay min_max -format full_clock_expanded -digits 3

# 生成详细报告
report_tns
report_wns
report_worst_slack

puts "Extraction completed!"
```

### 7.2 最终 STA 结果（带 SPEF）

```
========================================
Final Timing Report (with SPEF)
========================================

Startpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Endpoint: count_reg[0] (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

Point                                    Incr       Path
------------------------------------------------------------
clock clk (rise edge)                   0.000      0.000
clock network delay (propagated)        0.891      0.891  ← 精确
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                        0.000      0.891 r
count_reg[0]/Q (sky130_fd_sc_hd__dfxtp_1)
                                        0.453      1.344 r
add_1/A (sky130_fd_sc_hd__ha_1)        0.094      1.438 r  ← 精确 Wire Delay
add_1/S (sky130_fd_sc_hd__ha_1)        0.285      1.723 r
...
count_reg[0]/D (sky130_fd_sc_hd__dfxtp_1)
                                        0.068      3.012 r
data arrival time                                  3.012

clock clk (rise edge)                  10.000     10.000
clock network delay (propagated)        0.893     10.893  ← 精确
count_reg[0]/CK (sky130_fd_sc_hd__dfxtp_1)
                                                  10.893 r
library setup time                     -0.118     10.775
data required time                                10.775
------------------------------------------------------------
slack (MET)                                        7.763

========================================
Summary Report:
  WNS (Worst Negative Slack):    N/A (all paths met)
  TNS (Total Negative Slack):    0.000
  Worst Slack:                   +7.763ns
  Number of Endpoints:           4
  Number of Failing Endpoints:   0

Timing: PASS ✅
========================================
```

**最终结论：**
- **Slack = +7.763ns**（最精确值）
- 所有路径满足时序
- 可以送去制造！

---

## 📊 各阶段时序对比总结

### Slack 演变

```
阶段               | Slack     | 可信度 | Wire Delay 来源
──────────────────┼──────────┼───────┼────────────────
Yosys 综合        | N/A       | ⭐     | Zero Wire Load
ABC 映射          | N/A       | ⭐     | 未做 STA
Floorplan 后      | +8.5ns    | ⭐⭐   | 面积估算
Placement 后      | +8.03ns   | ⭐⭐⭐  | 距离估算
CTS 后            | +8.05ns   | ⭐⭐⭐⭐| 距离估算
Routing 后（预估）| +7.82ns   | ⭐⭐⭐⭐| Global Route
SPEF 提取后       | +7.763ns  | ⭐⭐⭐⭐⭐| 精确 RC
```

### 关键观察

1. **Placement → CTS:**
   - Slack 几乎不变（+8.03 → +8.05）
   - 因为 Launch 和 Capture Clock 都增加
   - Skew 很小（20ps）

2. **CTS → Routing:**
   - Slack 减少（+8.05 → +7.82）
   - Wire Delay 增加（实际走线比直线长）
   - 约 3% 的 Slack 损失

3. **Routing → SPEF:**
   - Slack 微调（+7.82 → +7.763）
   - 精确 RC 参数
   - 最终可信值

---

## 🎯 与 FusionCompiler 对比

### 相同的设计，FusionCompiler 流程：

```tcl
# FusionCompiler 一体化流程
read_verilog counter.v
read_db sky130.db

# 设置约束
create_clock -period 10 [get_ports clk]
set_input_delay 2 -clock clk [get_ports {enable rst_n}]
set_output_delay 2 -clock clk [get_ports {count* overflow}]

# 一键完成所有步骤
compile_ultra -topographical

# Floorplan
initialize_floorplan -core_utilization 0.7
create_placement
create_power

# Place + CTS + Route
place_opt
clock_opt
route_opt

# 最终报告
report_timing
```

**FusionCompiler 优势：**
- ✅ 命令简洁（约 10 行 vs OpenROAD 的 100+ 行）
- ✅ 自动优化（不需要手动调参）
- ✅ 收敛保证
- ✅ 可能更好的 QoR

**OpenROAD 优势：**
- ✅ 完全免费
- ✅ 每步可见（学习价值）
- ✅ 可定制
- ✅ 开源

---

## 📝 完整命令总结

### 运行整个流程

```bash
# Step 1: Yosys 综合
yosys synth.ys

# Step 2: ABC 映射
yosys map.ys

# Step 3-8: OpenROAD 流程
openroad -no_splash << EOF
  source 01_floorplan.tcl
  source 02_placement.tcl
  source 03_cts.tcl
  source 04_routing.tcl
  source 05_extraction.tcl
  exit
EOF

# Step 9: 查看 GDS（需要 Magic 或 KLayout）
magic -T sky130A counter_routed.def &
```

---

## 💡 关键学习点

### 1. P&R 各阶段的作用

- **Floorplan**: 确定芯片大小和框架
- **Placement**: 决定 Wire Delay 的上限
- **CTS**: 平衡时钟，让 Skew 最小
- **Routing**: 实现实际连线，确定最终 Delay

### 2. STA 的演变

- 从"估算"到"精确"的过程
- 每个阶段 Wire Delay 越来越准
- 最终的 SPEF 才是可信的

### 3. 为什么需要分步

- 一步无法完成（计算量太大）
- 逐步细化，逐步优化
- 每步都有明确目标

---

## 🤔 思考题

### Q1: 如果 Placement 后 Slack = +0.5ns，Routing 后可能是多少？

**答案:**
- 可能：+0.3ns ~ +0.4ns
- Wire Delay 会增加（绕路）
- 约损失 10-20% 的 Slack

### Q2: 为什么 CTS 后 Slack 几乎不变？

**答案:**
- Launch Clock Delay 增加 0.85ns
- Capture Clock Delay 也增加 0.87ns
- 相互抵消！
- 只要 Skew 小，Slack 变化就小

### Q3: 如果最终 Slack = -0.5ns（违规），怎么办？

**答案:**
- 回到综合，放宽时序（upsize 关键路径单元）
- 或者降低时钟频率
- 或者优化 Placement（缩短关键路径）

---

**您理解这个完整流程了吗？有什么疑问？** 😊
