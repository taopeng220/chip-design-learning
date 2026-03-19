# Scheduler 深度解析 - 从 FusionCompiler 角度理解

**分析者：** taopeng220
**日期：** 2026-03-12
**源文件：** `gpu-architecture/tiny-gpu/src/scheduler.sv`

---

## 📋 目录
1. [Scheduler 本质](#scheduler-本质)
2. [7状态详解](#7状态详解)
3. [关键代码分析](#关键代码分析)
4. [时序分析（FC角度）](#时序分析)
5. [回答Day 1的遗留问题](#回答遗留问题)

---

## 🎯 Scheduler 本质

### 定义
```systemverilog
module scheduler #(
    parameter THREADS_PER_BLOCK = 4,  // 每个Block有4个线程
) (
    input wire clk,
    input wire reset,
    input wire start,                  // 开始执行信号
    output reg [7:0] current_pc,       // 当前程序计数器
    output reg [2:0] core_state,       // 核心状态
    output reg done                    // 完成信号
);
```

**核心作用：** 管理单个 Core 处理 1 个 Block 的**整个控制流**

### 类比理解
```
FusionCompiler          |  GPU Scheduler
─────────────────────   |  ──────────────
控制综合的各个阶段       |  控制指令执行的各个阶段
compile_ultra           |  状态机驱动
自动优化决策            |  自动调度决策
```

---

## 📊 7状态详解

### 状态编码
```systemverilog
localparam
    IDLE    = 3'b000,  // 空闲，等待启动
    FETCH   = 3'b001,  // 取指令
    DECODE  = 3'b010,  // 解码
    REQUEST = 3'b011,  // 请求数据
    WAIT    = 3'b100,  // 等待内存
    EXECUTE = 3'b101,  // 执行计算
    UPDATE  = 3'b110,  // 更新寄存器
    DONE    = 3'b111;  // 完成
```

### 状态转换表

| 当前状态 | 条件 | 下一状态 | 延迟 | 说明 |
|---------|------|----------|------|------|
| IDLE | start=1 | FETCH | 1 cycle | 等待启动信号 |
| FETCH | fetcher_state=FETCHED | DECODE | N cycles | 等待取指完成 |
| DECODE | - | REQUEST | 1 cycle | 解码是同步的 |
| REQUEST | - | WAIT | 1 cycle | 发起请求是同步的 |
| WAIT | all LSUs done | EXECUTE | N cycles | 等待内存访问 |
| EXECUTE | - | UPDATE | 1 cycle | ALU计算是同步的 |
| UPDATE | RET=0 | FETCH | 1 cycle | 继续下一条指令 |
| UPDATE | RET=1 | DONE | 1 cycle | 遇到返回指令 |
| DONE | - | DONE | - | 停留在完成状态 |

### 时序图（一条指令的生命周期）
```
Cycle:  1      2      3      4      5      6      7
State:  IDLE | FETCH | DECODE | REQUEST | WAIT | EXECUTE | UPDATE
        │      │       │         │        │      │         │
        │      │取指   │解码     │发请求  │等待  │ALU计算  │写回
        │      │       │         │        │      │         │
        └─启动 └──────────────────────────────────────────>下条指令
```

---

## 🔬 关键代码分析

### 1. WAIT 状态 - 最复杂的逻辑

```systemverilog
WAIT: begin
    // 检查所有LSU是否完成
    reg any_lsu_waiting = 1'b0;
    for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
        // 确保没有LSU处于REQUESTING(2'b01)或WAITING(2'b10)状态
        if (lsu_state[i] == 2'b01 || lsu_state[i] == 2'b10) begin
            any_lsu_waiting = 1'b1;
            break;  // 有一个在等待就退出
        end
    end

    // 如果所有LSU都完成了，进入下一阶段
    if (!any_lsu_waiting) begin
        core_state <= EXECUTE;
    end
end
```

**为什么要这样做？**
- 因为有 **THREADS_PER_BLOCK=4** 个线程
- 每个线程有自己的 LSU（Load-Store Unit）
- **必须等所有线程的内存访问都完成** 才能继续
- 这就是 **SIMD 的同步特性**：所有线程步调一致！

**FC角度理解：**
```
类似 compile_ultra 等待所有模块都优化完
不能某个模块优化完就继续，必须全部完成
```

### 2. UPDATE 状态 - PC更新逻辑

```systemverilog
UPDATE: begin
    if (decoded_ret) begin
        // 遇到RET指令，Block执行完毕
        done <= 1;
        core_state <= DONE;
    end else begin
        // TODO: Branch divergence. For now assume all next_pc converge
        current_pc <= next_pc[THREADS_PER_BLOCK-1];

        // 继续下一条指令
        core_state <= FETCH;
    end
end
```

**重要发现：**
```systemverilog
current_pc <= next_pc[THREADS_PER_BLOCK-1];  // 只取最后一个线程的PC！
```

**这意味着什么？**
- 所有线程共享一个 PC（程序计数器）
- **假设所有线程的 next_pc 都一样**（无分支分化）
- 代码注释也说了：`TODO: Branch divergence`
- **这是简化版实现**，真实GPU需要处理分支分化！

---

## ⏱️ 时序分析（FC角度）

### 关键路径分析

**一条指令的最短延迟：**
```
FETCH(1) + DECODE(1) + REQUEST(1) + WAIT(0) + EXECUTE(1) + UPDATE(1) = 5 cycles
```
*假设WAIT状态立即通过（无内存访问）*

**一条指令的最长延迟：**
```
FETCH(N) + DECODE(1) + REQUEST(1) + WAIT(M) + EXECUTE(1) + UPDATE(1) = N+M+4 cycles
```
*FETCH取决于Program Memory延迟，WAIT取决于Data Memory延迟*

### 吞吐量分析

**IPC (Instructions Per Cycle)：**
- 单线程视角：IPC ≈ 1/5 = 0.2（很低！）
- **但是！4个线程并行执行**
- 有效IPC = 0.2 × 4 = **0.8**

**对比FC综合中的流水线：**
```
FC: compile_ultra内部有流水线，多个设计点并行探索
GPU Scheduler: 没有流水线，是串行状态机
    → 改进空间：流水化！（类似CPU的5级流水线）
```

### 时序约束（如果要综合）

假设目标频率 100MHz (10ns period)：

| 状态转换 | 组合逻辑 | 估算延迟 | 是否满足？ |
|---------|---------|---------|-----------|
| IDLE→FETCH | start信号 | < 0.5ns | ✅ |
| FETCH→DECODE | fetcher_state比较 | < 1ns | ✅ |
| DECODE→REQUEST | - | < 0.5ns | ✅ |
| REQUEST→WAIT | - | < 0.5ns | ✅ |
| WAIT→EXECUTE | **for循环+多个OR** | **~3-5ns** | ⚠️ |
| EXECUTE→UPDATE | decoded_ret判断 | < 0.5ns | ✅ |

**潜在时序问题：WAIT状态**
```systemverilog
for (int i = 0; i < THREADS_PER_BLOCK; i++)
    if (lsu_state[i] == 2'b01 || lsu_state[i] == 2'b10)
        any_lsu_waiting = 1'b1;
```

**FC角度优化：**
- 当前：串行检查4个LSU（4级OR门链）
- 优化：并行检查（树形结构）
- Logic Level: 4级 → 2级（log2(4)）

---

## 🎓 回答遗留问题

### ❓ 问题1：Scheduler如何调度线程？

**答案：**

Scheduler **不是**真正的"调度器"（不会在线程间切换）！

它的"调度"是指：
1. **统一控制所有线程**：所有线程执行相同的指令
2. **状态机驱动**：FETCH→DECODE→...→UPDATE循环
3. **同步等待**：WAIT状态确保所有线程完成内存访问才继续

**真正的并行在哪？**
- 每个线程有独立的ALU、LSU、Registers
- Scheduler发出统一指令，所有ALU同时执行
- 这就是 **SIMD**：Single Instruction, Multiple Data

**类比：**
```
Scheduler = 指挥家
4个线程 = 4个乐手
指挥家挥手（FETCH/DECODE/EXECUTE）→ 所有人同时演奏
```

### ❓ 问题2：Warp的概念是什么？

**Warp ≈ Block（在tiny-gpu中）**

- **Warp**：NVIDIA术语，一组线程同时执行相同指令
- **tiny-gpu的Block**：4个线程 = 1个Warp
- 真实GPU：1个Warp = 32个线程（NVIDIA）或64个（AMD）

**为什么要Warp？**
- 硬件成本：1个Decoder控制32个ALU，比32个Decoder便宜得多！
- SIMD效率：适合数据并行任务（图形、AI）

### ❓ 问题3：如何处理分支divergence（分支分化）？

**当前tiny-gpu：不处理！**

代码明确说了：
```systemverilog
// TODO: Branch divergence. For now assume all next_pc converge
current_pc <= next_pc[THREADS_PER_BLOCK-1];  // 只取一个线程的PC
```

**什么是分支分化？**
```c
// GPU kernel伪代码
if (threadID % 2 == 0)
    result = a + b;  // Thread 0, 2 走这里
else
    result = a * b;  // Thread 1, 3 走这里
```

**问题：**
- 线程0和2的next_pc指向加法
- 线程1和3的next_pc指向乘法
- **但Scheduler只能选一个PC！**

**真实GPU的解决方案：**
1. **串行化执行**
   - 先执行if分支（禁用else分支的线程）
   - 再执行else分支（禁用if分支的线程）
   - 性能损失！

2. **Stack-based方法**
   - 用Stack记录分支点
   - 回溯执行不同路径

**tiny-gpu假设：**
- 所有线程的分支结果一样
- 适用于：简单kernel，无条件分支

---

## 💡 总结

### 核心要点

1. **Scheduler = 7状态FSM**
   - IDLE → FETCH → DECODE → REQUEST → WAIT → EXECUTE → UPDATE

2. **SIMD的体现**
   - 所有线程共享一个Decoder
   - 所有线程执行相同指令
   - WAIT状态同步所有线程

3. **简化设计**
   - 无流水线（性能低但简单）
   - 无分支分化处理（限制灵活性）

4. **改进方向**
   - 流水化状态机（提高IPC）
   - 支持分支分化（真实GPU必需）
   - 优化WAIT逻辑（降低时序压力）

### FC角度的理解

| GPU Scheduler | FusionCompiler 类比 |
|--------------|---------------------|
| 状态机控制流 | compile流程控制 |
| SIMD统一控制 | 批量处理多个设计点 |
| WAIT同步 | 等待所有优化任务完成 |
| 时序优化空间 | 减少critical path |

---

**学习感悟：**

原来Scheduler不是"调度"线程（切换），而是"指挥"线程（同步）！

就像FusionCompiler的compile_ultra，虽然内部很复杂，但本质是状态机驱动的流程控制。

理解了本质，代码就不难了！🚀
