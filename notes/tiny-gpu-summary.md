# tiny-gpu 学习总结

## 🎓 今天的学习成果

### 完成内容 ✅
1. ✅ 克隆tiny-gpu项目
2. ✅ 分析项目架构（12个SV文件）
3. ✅ 深入理解核心模块（ALU + Scheduler）
4. ✅ 从FC综合角度分析设计
5. ✅ 创建详细学习笔记

---

## 📊 核心收获

### 1. GPU架构本质

```
┌─────────────────────────────────────┐
│   GPU = 并行 + SIMD + 内存管理      │
│                                     │
│   关键组件：                        │
│   • Dispatcher  → 任务分发         │
│   • Core (多个) → 并行计算         │
│   • Scheduler   → 线程调度         │
│   • Memory Ctrl → 带宽管理         │
└─────────────────────────────────────┘
```

**不是魔法，就是：**
- 很多简单的核心
- 统一的控制
- Clever的调度

### 2. SIMD执行模型

```verilog
// 单指令控制多线程
Decoder (1个) → Control Signals → ALU (32个)
                                  ↓
                              每个处理不同数据
```

**优点：**
- 硬件简单（共享decoder）
- 并行度高

**缺点：**
- 分支divergence效率低
- 依赖数据并行性

### 3. Memory Wall问题

```
ALU计算:    1 cycle   ███
Memory访问: 10 cycles ██████████████████████

利用率 = 1/30 ≈ 3% 😱

解决方案：
→ Warp Scheduling (在Nyuzi中会看到)
→ Cache
→ Prefetching
```

---

## 🔧 从FC综合角度的分析

### 时序挑战

| 模块 | 关键路径 | 预估延迟 | FC策略 |
|------|----------|----------|--------|
| ALU (ADD/SUB) | 加法器 | 1-2ns | OK |
| ALU (MUL) | 8x8乘法器 | 3-5ns | Multi-cycle或Pipeline |
| ALU (DIV) | 除法器 | 10-15ns | 必须Pipeline! |
| Scheduler FSM | 状态逻辑 | 2-3ns | OK |
| Memory Ctrl | 仲裁逻辑 | 3-4ns | 优化仲裁算法 |

**建议时钟频率：** 100-150 MHz (@28nm)

### 面积估算

```
配置：4 cores × 4 threads = 16 parallel threads

ALU (×16):        40K gates
Registers (×16):  10K gates
Scheduler (×4):    2K gates
LSU (×16):         8K gates
Memory Ctrl:       5K gates
Other:             1K gates
────────────────────────────
Total:            66K gates ≈ 16.5K NAND2
```

**对比：** 一个ARM Cortex-M0 ≈ 12K gates
→ 这个GPU相当于~1.5个M0核心的面积，但并行度高很多！

### 功耗估算

```
@100MHz, 28nm:
────────────────────
Dynamic: ~50mW
Static:  ~5mW
────────────────────
Total:   ~55mW
```

---

## 💡 关键设计洞察

### 1. 简单核心 × 数量 > 复杂核心

```
CPU思维: 1个超强核心，5GHz，乱序执行
GPU思维: 1000个简单核心，1GHz，顺序执行

对于并行任务: GPU赢！
```

### 2. 统一控制 = 硬件简化

```
传统多核CPU: 每个核心独立取指令、解码
GPU (SIMD):    所有核心共享decoder

节省: ~70% 控制逻辑面积
代价: 分支divergence时效率低
```

### 3. 调度是核心竞争力

```
简单调度 (tiny-gpu):
  WAIT状态死等memory
  利用率: 3%

高级调度 (Nvidia):
  切换到其他warp
  利用率: 80%+

→ 这就是为什么Nvidia值钱！
```

---

## 📈 与NyuziProcessor对比

| 特性 | tiny-gpu | NyuziProcessor |
|------|----------|----------------|
| **代码量** | 12文件, ~1000行 | 100+文件, ~50K行 |
| **Pipeline** | 简单6阶段 | 多级流水线 |
| **Scheduling** | 同步顺序执行 | Warp scheduling |
| **ISA** | 16-bit简化 | 完整RISC-like |
| **Cache** | 简单/WIP | 多级cache hierarchy |
| **目标** | 教学 | 可用系统 |
| **学习价值** | ⭐⭐⭐⭐⭐ 快速入门 | ⭐⭐⭐⭐⭐ 深度学习 |

**学习路径：**
```
tiny-gpu (1-2天) → 建立GPU概念
    ↓
NyuziProcessor (2-3周) → 理解工业级设计
    ↓
实战项目 (4-6周) → 自己设计GPU模块
```

---

## 🎯 下一步计划

### 短期（本周）

- [ ] **Day 1 (今天):** ✅ 完成架构分析
- [ ] **Day 2:** 运行仿真测试
  ```bash
  cd test/
  make test_matadd  # 矩阵加法
  make test_matmul  # 矩阵乘法
  ```
- [ ] **Day 3-4:** Yosys综合实验
  ```bash
  # 综合ALU模块
  yosys -p "read_verilog -sv alu.sv; synth; stat"
  # 分析面积和时序
  ```
- [ ] **Day 5-7:** 对比分析
  - 不同配置（threads数量）的影响
  - 优化策略（pipeline MUL vs组合逻辑）
  - 如果有FC环境，对比综合结果

### 中期（下周）

- [ ] **Week 2:** 开始NyuziProcessor分析
  - 对比tiny-gpu，看工业级如何实现
  - 重点：Warp scheduling机制

- [ ] **Week 3:** 综合实战
  - 用Yosys综合完整的tiny-gpu
  - 尝试优化（面积/性能trade-off）

---

## 📚 推荐阅读

### 理解今天的内容
1. **SIMD vs MIMD**
   - [Wiki: SIMD](https://en.wikipedia.org/wiki/SIMD)

2. **GPU架构基础**
   - 论文: "From High-Level Deep Neural Models to FPGAs"

3. **Memory Hierarchy**
   - 书籍: Computer Architecture (Hennessy & Patterson) - Chapter 2

### 准备Nyuzi学习
1. **Warp Scheduling**
   - [NVIDIA GPU Architecture Whitepaper]

2. **Cache Coherence**
   - 课程: CMU 15-418 (Parallel Architecture)

---

## 🤔 思考题

### 从FC综合角度思考：

1. **时序优化**
   ```
   问题: ALU的DIV操作延迟10ns，目标频率100MHz

   你会如何处理？
   A. Multi-cycle path
   B. Pipeline divider
   C. 改成iterative算法
   D. 用查找表近似

   各有什么优缺点？
   ```

2. **面积优化**
   ```
   问题: 32个ALU，每个都有MUL单元

   观察: 每个cycle只有少数thread执行MUL

   如何优化？保留多少个共享MUL合适？
   Trade-off是什么？
   ```

3. **功耗优化**
   ```
   问题: 某个kernel只用8个threads，但有32个ALU

   剩下24个ALU在空转，浪费功耗

   你的clock gating策略？
   如何检测哪些ALU是idle的？
   ```

---

## 📝 学习反思

### 今天最重要的3个收获：

1. **GPU不神秘**
   - 去掉fancy的包装，本质就是很多简单core + 统一控制
   - 理解了SIMD的硬件实现

2. **Memory is the bottleneck**
   - 不是计算慢，是访存慢
   - 所有高级GPU的优化都在解决这个问题

3. **简单设计的价值**
   - tiny-gpu只有1000行代码，但核心概念都有
   - 对比商业GPU几百万行，学习成本差距巨大
   - 先理解简单的，再看复杂的 → 事半功倍！

### 下次学习重点：

1. **运行仿真** - 看看GPU实际怎么执行的
2. **Yosys综合** - 实践FC经验
3. **开始Nyuzi** - 看工业级怎么做

---

**学习进度：** 🟩🟩🟩⬜⬜⬜⬜⬜ (Phase 2: 25% 完成)

**状态：** 架构理解 ✅ | 代码分析 ✅ | 仿真测试 ⏳ | 综合实验 ⏳

---

*更新时间: 2026-03-11 15:30*
*下次更新: 运行仿真后*
