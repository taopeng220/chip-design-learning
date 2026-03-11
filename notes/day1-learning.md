# Day 1 学习笔记 - tiny-gpu入门

**日期：** 2026-03-11
**学习者：** taopeng220

---

## 今天学到了什么

### 1. GPU的核心概念

**GPU = 简单核心 × 大量 + 统一控制**

比喻：
- CPU = 几个大厨，每个都很强，可以做不同菜
- GPU = 100个工人，同时做相同的动作（拧螺丝）

### 2. SIMD执行模型

**SIMD = Single Instruction, Multiple Data（单指令，多数据）**

例子：把图片变亮
- CPU：循环100次，每次处理1个像素
- GPU：100个线程同时处理，每个处理1个像素

硬件实现：
```
1个Decoder（解码器）
    ↓
  指令：ADD
    ↓
┌───┬───┬───┬───┐
│ALU│ALU│ALU│ALU│ ... 32个
└───┴───┴───┴───┘
 ↓   ↓   ↓   ↓
1+2 3+4 5+6 7+8  (不同的数据)
```

### 3. tiny-gpu架构

**组件：**
- DCR（设备控制寄存器）：设置线程数
- Dispatcher（分发器）：分配任务到Core
- Core（计算核心）：执行计算
  - Scheduler：调度线程
  - Decoder：解码指令
  - ALU ×32：算术单元
  - Registers ×32：寄存器

**工作流程：**
1. 设置线程数（比如100个）
2. Dispatcher分成Blocks（比如4个Block，每个25线程）
3. 每个Core处理1个Block
4. Core内32个线程并行执行

---

## FC综合角度的分析

### 时序挑战

**问题：** MUL和DIV的logic level太长

| 操作 | Logic Levels | 延迟估算 |
|------|--------------|----------|
| ADD/SUB | 5-8 | ~1-2ns |
| MUL | 10-15 | ~3-5ns |
| DIV | 20-30 | ~10-15ns ❌ |

**解决方案（我的选择）：**
- ✅ 移除DIV硬件单元（改用软件）
- ✅ Pipeline MUL（3级流水线）
- ✅ 目标100MHz

### 面积估算

**配置：** 4 cores × 32 threads = 128并行

```
每个ALU: ~2500 gates
128个ALU: 320,000 gates

优化策略：
- Resource sharing（共享乘法器）
- 移除DIV
- Clock gating
```

---

## 关键代码理解

### ALU模块（alu.sv）

```systemverilog
case (decoded_alu_arithmetic_mux)
    ADD: alu_out_reg <= rs + rt;  // 加法
    SUB: alu_out_reg <= rs - rt;  // 减法
    MUL: alu_out_reg <= rs * rt;  // 乘法 ⚠️
    DIV: alu_out_reg <= rs / rt;  // 除法 ❌
endcase
```

**理解：**
- 每个线程有独立的ALU
- 所有ALU同时执行相同指令
- rs, rt是输入，alu_out是输出

---

## 疑问和TODO

### 已解决：
- ✅ 为什么GPU快？→ 并行！
- ✅ 什么是SIMD？→ 统一指令，不同数据
- ✅ Logic level过长怎么办？→ Pipeline

### 待探索：
- ⏳ Scheduler如何调度？
- ⏳ Memory访问如何管理？
- ⏳ 实际运行效果如何？

---

## 下一步计划

1. 学习使用GitHub管理笔记 ✅ (正在进行)
2. 运行仿真看实际效果
3. 深入理解Scheduler模块
4. 开始学习NyuziProcessor

---

**学习感想：**

今天理解了GPU的本质，不再觉得神秘。原来就是很多简单的ALU在统一控制下并行工作！

从FC角度看，GPU的综合挑战主要是时序和面积。需要做好trade-off。

期待明天的学习！🚀
