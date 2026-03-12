# Day 2 学习笔记 - GitHub基础 + Scheduler深入

**日期：** 2026-03-12
**学习者：** taopeng220

---

## 🎓 GitHub学习进度

### 今天学会的Git/GitHub技能

#### 1. 查看远程仓库
```bash
git remote -v
# 显示远程仓库的URL
```

#### 2. 分支管理 ⭐
```bash
# 查看所有分支
git branch -a

# 创建并切换到新分支
git checkout -b <branch-name>

# 查看当前分支
git branch
```

**分支使用场景：**
- ✅ 每天的学习：创建 `day2-xxx-learning` 分支
- ✅ 实验新想法：创建 `experiment-xxx` 分支
- ✅ 主分支保持稳定：只合并成功的学习成果

---

## 🔍 技术学习：GPU Scheduler 调度机制

### 待探索问题（从Day 1继续）
1. ⏳ Scheduler如何调度线程？
2. ⏳ Warp的概念是什么？
3. ⏳ 如何处理分支divergence？

### 学习笔记

#### Scheduler的本质：7状态FSM（有限状态机）

**完整流程图：**
```
        ┌──────────┐
        │  IDLE    │ ← 复位后，等待start信号
        └────┬─────┘
             │ start=1
             ↓
        ┌──────────┐
        │  FETCH   │ ← 从Program Memory取指令
        └────┬─────┘    （等待fetcher完成）
             │ fetcher_state=FETCHED
             ↓
        ┌──────────┐
        │  DECODE  │ ← 解码指令（1 cycle）
        └────┬─────┘    生成控制信号
             │ 1 cycle
             ↓
        ┌──────────┐
        │ REQUEST  │ ← 发起内存/寄存器请求（1 cycle）
        └────┬─────┘
             │ 1 cycle
             ↓
        ┌──────────┐
        │   WAIT   │ ← 等待所有LSU完成内存访问
        └────┬─────┘    （可能多个cycle）
             │ all LSUs done
             ↓
        ┌──────────┐
        │ EXECUTE  │ ← ALU计算（1 cycle）
        └────┬─────┘
             │ 1 cycle
             ↓
        ┌──────────┐
        │  UPDATE  │ ← 更新寄存器和PC
        └────┬─────┘
             │
      ┌──────┴─────────┐
      │                │
   RET指令?         不是RET
      │                │
      ↓                ↓
  ┌──────┐      回到FETCH
  │ DONE │      (处理下一条指令)
  └──────┘
```

#### 从FusionCompiler角度理解

**类比FC的综合流程：**
```
FC综合流程                  GPU Scheduler流程
────────────────           ────────────────
elaborate（读入）    →     FETCH（取指令）
check_design（检查） →     DECODE（解码）
compile_ultra（综合）→     EXECUTE（执行）
write_file（输出）   →     UPDATE（写回）
```

都是**流水化的多阶段处理**！

---

#### 核心发现

**1. Scheduler不是"调度"而是"指挥"！**
```
误解：Scheduler在线程间切换（像OS调度器）
真相：Scheduler统一指挥所有线程（像指挥家）
```

**2. SIMD的精髓：同步执行**
- 所有线程执行相同指令
- WAIT状态等待所有LSU完成
- 共享一个PC（程序计数器）

**3. 当前的限制：无分支分化处理**
```systemverilog
// scheduler.sv:104
// TODO: Branch divergence
current_pc <= next_pc[THREADS_PER_BLOCK-1];  // 只取最后一个线程的PC
```

**详细分析见：** [scheduler-deep-dive.md](./scheduler-deep-dive.md)

---

## ✅ 回答Day 1的遗留问题

### ❓ Scheduler如何调度线程？
**答：** 不是调度（切换），是指挥（同步）！
- 7状态FSM：IDLE→FETCH→DECODE→REQUEST→WAIT→EXECUTE→UPDATE
- 所有线程步调一致，执行相同指令
- WAIT状态确保同步

### ❓ Warp的概念是什么？
**答：** Warp ≈ tiny-gpu的Block
- 一组线程（4个）同时执行相同指令
- 共享Decoder，降低硬件成本
- 真实GPU：Warp=32线程（NVIDIA）

### ❓ 如何处理分支divergence？
**答：** tiny-gpu不处理（简化设计）
- 假设所有线程的分支结果一样
- 真实GPU：串行化执行不同分支（性能损失）

---

## 🎯 今天的目标

- [x] 学习Git分支基础
- [x] 创建day2学习分支
- [x] 深入分析tiny-gpu的Scheduler代码
- [x] 理解线程调度机制
- [x] 更新学习笔记
- [x] 回答Day 1遗留问题

---

## 💡 学习感想

**GitHub学习：**
今天学会了Git分支，原来可以这样安全地实验！每天创建一个分支，失败了也不怕影响主分支。

**技术学习：**
Scheduler的分析让我恍然大悟！原来它不是"调度器"而是"指挥家"，统一指挥所有线程同步执行。

从FusionCompiler的角度理解GPU架构，感觉豁然开朗：
- Scheduler = 状态机（就像compile流程）
- SIMD = 批量处理（就像批量优化多个设计点）
- WAIT同步 = 等待所有任务完成

下一步想学习：
1. 真实GPU如何处理分支分化？
2. Memory访问的详细机制
3. 如何优化Scheduler的时序？

继续前进！🚀
