# GPU架构学习笔记

## GPU基础架构

### GPU vs CPU对比

```
CPU: 少核心 + 强单线程性能 + 大缓存
GPU: 多核心 + 弱单线程性能 + SIMT执行

     CPU                      GPU
  ┌────────┐           ┌──┬──┬──┬──┐
  │ Core 1 │           │C │C │C │C │
  │  (强)  │           │1 │2 │3 │4 │... (数百个)
  ├────────┤           ├──┼──┼──┼──┤
  │ Core 2 │           │C │C │C │C │
  └────────┘           └──┴──┴──┴──┘
```

### GPU Pipeline基本结构

```
Input Assembler (IA)
    ↓
Vertex Shader (VS)
    ↓
Rasterizer
    ↓
Fragment/Pixel Shader (FS)
    ↓
Frame Buffer
```

---

## 关键概念

### 1. SIMT (Single Instruction Multiple Threads)
- GPU执行模型
- 一条指令控制多个线程
- Warp/Wavefront概念

### 2. Memory Hierarchy
```
Registers (最快)
    ↓
Shared Memory / L1 Cache
    ↓
L2 Cache
    ↓
Global Memory (DRAM)
```

### 3. Memory Coalescing
- 合并内存访问提高带宽利用率
- 对综合有重要影响

---

## 项目分析

### tiny-gpu架构
- [ ] Vertex处理单元
- [ ] 光栅化器
- [ ] Fragment处理器
- [ ] 综合结果分析

### NyuziProcessor架构
- [ ] SIMT核心
- [ ] Warp调度器
- [ ] Cache层次结构
- [ ] 综合挑战

---

## 综合经验

### 从FC综合经验应用到GPU设计

#### 时序优化
- GPU中的关键路径：...
- Pipeline插入策略：...

#### 面积优化
- 资源共享机会：...
- 多路复用：...

#### 功耗优化
- Clock gating：...
- Power domain：...

---
