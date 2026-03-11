# tiny-gpu 深度分析

> 学习日期：2026-03-11
> 分析者：taopeng220
> 背景：FusionCompiler + GPU综合经验

---

## 📊 项目概览

### 基本信息
- **名称：** tiny-gpu
- **目的：** 教学型最小GPU实现
- **代码量：** <15个SystemVerilog文件
- **特点：** 代码简洁，注释详细，专注GPGPU核心概念

### 设计哲学
> 简化GPU设计，去除图形专用硬件，聚焦通用计算加速器的核心原理

**关注点：**
1. **架构** - GPU长什么样？
2. **并行化** - SIMD如何在硬件实现？
3. **内存** - 如何应对内存带宽限制？

---

## 🏗️ 架构分析

### 整体架构图

```
┌─────────────────────────────────────────────────────────┐
│                        GPU                              │
│  ┌──────────────┐                                       │
│  │ Device       │  启动控制                              │
│  │ Control Reg  │  (thread_count)                       │
│  └──────────────┘                                       │
│         ↓                                               │
│  ┌──────────────┐                                       │
│  │  Dispatcher  │  线程组织与分发                        │
│  │              │  (blocks → cores)                     │
│  └──────────────┘                                       │
│         ↓                                               │
│  ┌──────┬──────┬──────┐                                │
│  │Core 0│Core 1│Core N│  并行计算核心                   │
│  └──────┴──────┴──────┘                                │
│         ↓                                               │
│  ┌──────────────┐   ┌──────────────┐                   │
│  │ Data Memory  │   │ Program Mem  │                   │
│  │ Controller   │   │ Controller   │                   │
│  └──────────────┘   └──────────────┘                   │
│         ↓                   ↓                           │
│  ┌──────────────┐   ┌──────────────┐                   │
│  │ Data Memory  │   │ Program Mem  │  外部存储          │
│  │ (8-bit addr) │   │ (8-bit addr) │                   │
│  │ (8-bit data) │   │ (16-bit inst)│                   │
│  └──────────────┘   └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 模块详解（12个文件）

### 1. **gpu.sv** (顶层模块)
**作用：** GPU顶层，集成所有子模块

**关键组件：**
- Device Control Register (DCR)
- Dispatcher
- 多个Core实例
- Memory Controllers (Data + Program)
- Cache (WIP)

**接口：**
```systemverilog
module gpu (
    input clk,
    input reset,
    input start,                    // 启动信号
    input [7:0] thread_count,       // 线程总数
    output done,                    // 完成信号
    // Memory interfaces...
);
```

---

### 2. **dcr.sv** (Device Control Register)
**作用：** 存储kernel执行元数据

**功能：**
- 存储thread_count
- 简单的配置寄存器

**代码量：** ~20行（极简）

---

### 3. **dispatch.sv** (线程分发器)
**作用：** 将线程组织成blocks，分配给cores

**核心逻辑：**
```
总线程数 → 分成多个blocks → 分配给可用core
```

**关键概念：**
- **Block**: 一组可以在单个core上并行执行的线程
- **调度策略**: 轮询分配给空闲core

---

### 4. **core.sv** ⭐ 核心模块
**作用：** 计算核心，执行一个block的线程

**内部结构：**
```
core/
├── Scheduler       # 线程调度
├── Fetcher        # 指令获取
├── Decoder        # 指令解码
├── 每线程资源：
│   ├── ALU        # 算术逻辑单元
│   ├── LSU        # Load/Store单元
│   ├── PC         # 程序计数器
│   └── Registers  # 寄存器堆
```

**并行策略：**
- 每个线程有独立的ALU、PC、寄存器
- 所有线程**同步**执行相同指令（SIMD）

---

### 5. **scheduler.sv** ⭐⭐ 关键！
**作用：** 管理block内所有线程的执行

**执行模型：**
```
1. 同步执行 - 所有线程执行相同指令
2. 顺序执行 - 一条指令完成后再执行下一条
3. 异步Load/Store处理
```

**状态机：**
```
IDLE → FETCH → DECODE → EXECUTE → (WAIT_LSU) → NEXT_INST
```

**挑战：**
- Load/Store延迟处理
- 资源利用率最大化

---

### 6. **fetcher.sv**
**作用：** 从program memory异步获取指令

**流程：**
```
1. 读取当前PC
2. 请求program memory controller
3. 接收instruction
4. 传递给decoder
```

---

### 7. **decoder.sv**
**作用：** 解码16-bit指令为控制信号

**ISA格式：**
```
┌────────┬────────┬────────┬────────┐
│ opcode │  dst   │  src1  │  src2  │
│ 4-bit  │ 4-bit  │ 4-bit  │ 4-bit  │
└────────┴────────┴────────┴────────┘
```

**指令类型：**
- ALU操作 (ADD, SUB, MUL, DIV, etc.)
- LSU操作 (LOAD, STORE)
- 控制流 (JUMP, BEQ, etc.)

---

### 8. **alu.sv** (算术逻辑单元)
**作用：** 执行算术和逻辑运算

**支持操作：**
```systemverilog
ADD, SUB, MUL, DIV, MOD,
AND, OR, XOR, NOT,
SLT, SEQ, ...
```

**设计：** 组合逻辑，单周期执行

---

### 9. **lsu.sv** (Load/Store单元)
**作用：** 处理内存读写

**特点：**
- 异步操作（多周期）
- 与data memory controller交互
- 支持8-bit地址，8-bit数据

---

### 10. **pc.sv** (程序计数器)
**作用：** 每个线程的独立PC

**功能：**
- 自增（默认）
- 跳转（分支指令）

---

### 11. **registers.sv** (寄存器堆)
**作用：** 每个线程的寄存器文件

**规格：**
- 16个寄存器（4-bit地址）
- 8-bit数据宽度

---

### 12. **controller.sv** (Memory Controller)
**作用：** 管理对global memory的访问

**功能：**
1. 请求队列管理
2. 根据带宽限制节流
3. 响应路由

**关键：** 解决多核并发访问冲突

---

## 🎯 关键设计点

### 1. SIMD执行模型

```
传统CPU:
Thread 0: ADD R1, R2, R3
Thread 1: SUB R1, R2, R3  (不同指令)

GPU (SIMD):
All Threads: ADD R1, R2, R3  (相同指令，不同数据)
```

**硬件实现：**
- 单个指令解码器
- 多个ALU（每线程一个）
- 统一控制信号

### 2. 内存带宽管理

**问题：** 多核同时访问内存，带宽不足

**解决：**
- Memory Controller节流
- 请求队列
- Cache（减少重复访问）

### 3. 异步Load/Store

**挑战：** 内存延迟 >> 计算延迟

**策略：**
- Scheduler等待LSU完成
- 未来优化：Warp scheduling（切换到其他线程）

---

## 💡 从FC综合角度分析

### 时序分析

#### 关键路径预测：

1. **ALU路径**
   ```
   Decoder → ALU (MUL/DIV) → Writeback
   ```
   - **风险：** MUL/DIV组合逻辑深
   - **FC策略：**
     - 插入pipeline寄存器
     - 使用DSP block（如果FPGA）

2. **Memory Controller路径**
   ```
   Request Queue → Arbiter → Memory Interface
   ```
   - **风险：** 多核仲裁逻辑复杂
   - **FC策略：**
     - 优化仲裁算法
     - 可能需要multi-cycle path

3. **Scheduler FSM**
   ```
   State Logic → Control Signals → Distribution
   ```
   - **风险：** 控制逻辑扇出大
   - **FC策略：**
     - Buffer插入
     - 逻辑复制减少扇出

### 面积分析

#### 资源消耗估计（单Core）：

```
Per Thread:
- ALU: ~500 gates
- Registers (16x8-bit): 128 FF
- PC: 8 FF
- LSU logic: ~200 gates

Per Core (假设32 threads/block):
- 32 × ALU = 16K gates
- 32 × 128 FF = 4096 FF
- Scheduler: ~2K gates
- Fetcher/Decoder: ~1K gates

Total per Core: ~20K gates ≈ 5000 NAND2等效
```

#### FC优化策略：

1. **Resource Sharing**
   - 多个线程共享decoder（已实现）
   - 可能共享ALU（牺牲并行度）

2. **Clock Gating**
   ```
   inactive threads → gate clock
   idle cores → gate clock
   ```

3. **Memory Compiler**
   - Register file用SRAM替代FF（如果够大）

### 功耗分析

#### 功耗热点：

1. **动态功耗**
   - ALU切换（每周期）
   - Memory访问（高功耗）
   - Clock tree

2. **静态功耗**
   - 大量FF（寄存器堆）

#### FC优化：

```tcl
# 多阈值电压
set_attribute -name LEAKAGE_POWER -value low [get_cells scheduler/*]
set_attribute -name LEAKAGE_POWER -value high [get_cells alu/*]

# Clock gating
set_clock_gating_style -sequential_cell latch -num_stages 2

# Power domain (如果支持)
create_power_domain PD_CORE -elements {core/*}
```

---

## 🔬 实验计划

### 实验1：仿真验证（今天）
```bash
cd test/
# 运行matrix addition测试
```

### 实验2：Yosys综合（本周）
```bash
# 综合单个模块
yosys -p "read_verilog alu.sv; synth; write_verilog alu_synth.v"

# 分析面积和时序
```

### 实验3：完整综合（下周）
```bash
# 综合整个GPU
# 对比不同配置（core数量、thread数）
```

---

## 📝 学习笔记

### 核心收获

1. **GPU = 多核 + SIMD + 内存管理**
   - 不是魔法，就是并行的CPU + 统一控制

2. **SIMD的硬件本质**
   - 共享decoder，独立ALU
   - 控制统一，数据各异

3. **内存是瓶颈**
   - 计算快，访存慢
   - 需要clever调度和cache

### 与NyuziProcessor对比

| 特性 | tiny-gpu | NyuziProcessor |
|------|----------|----------------|
| 代码量 | ~12文件 | ~100+文件 |
| 复杂度 | 教学级 | 工业级 |
| Pipeline | 简单顺序 | 多级流水线 |
| Scheduling | 同步顺序 | Warp scheduling |
| ISA | 16-bit简化 | 完整RISC-V-like |
| 适合 | 快速入门 | 深度学习 |

### 下一步

- [ ] 运行仿真，看实际执行
- [ ] 用Yosys综合ALU模块
- [ ] 分析综合报告
- [ ] 对比FC结果（如果有环境）

---

**更新时间：** 2026-03-11
**状态：** 架构分析完成 ✅
