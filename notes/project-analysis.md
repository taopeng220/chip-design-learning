# 项目分析与综合策略

## 📊 NyuziProcessor 架构分析

### 基本信息
- **类型：** GPGPU微处理器
- **语言：** SystemVerilog
- **目标：** 计算密集型任务
- **特点：** 完整的工具链（编译器、模拟器、测试）

### 硬件模块结构

```
hardware/core/
├── Core Pipeline
│   ├── ifetch_tag_stage.sv      # 取指令（Tag阶段）
│   ├── ifetch_data_stage.sv     # 取指令（Data阶段）
│   ├── instruction_decode_stage.sv  # 指令解码
│   ├── int_execute_stage.sv     # 整数执行单元
│   ├── fp_execute_stage[1-5].sv # 浮点流水线（5级）
│   └── writeback_stage.sv       # 写回
│
├── Cache System
│   ├── dcache_tag_stage.sv      # 数据缓存Tag
│   ├── dcache_data_stage.sv     # 数据缓存Data
│   ├── cache_lru.sv             # LRU替换策略
│   └── l1_l2_interface.sv       # L1-L2接口
│
└── Special Units
    ├── cam.sv                   # Content Addressable Memory
    ├── control_registers.sv     # 控制寄存器
    └── io_interconnect.sv       # IO互连
```

### 架构特点

#### 1. SIMT执行模型
- 每个核心支持多线程
- SIMD宽度：16（一次处理16个数据）
- 类似NVIDIA的Warp概念

#### 2. 流水线设计
```
5级整数流水线
IF → ID → EX → MEM → WB

5级浮点流水线
FP1 → FP2 → FP3 → FP4 → FP5
```

#### 3. 内存层次
```
L1 ICache ────┐
L1 DCache ────┼─→ L2 Cache ─→ DDR
```

### 综合挑战（从FC角度）

#### 挑战1：长流水线时序
- **问题：** 5级FP流水线，可能有长路径
- **FC策略：**
  - Pipeline balancing
  - Retiming优化
  - 插入寄存器切割路径

#### 挑战2：大量并行单元
- **问题：** 16-way SIMD，面积大
- **FC策略：**
  - Resource sharing分析
  - Clock gating减少动态功耗
  - 多阈值电压优化（HVT/SVT/LVT）

#### 挑战3：复杂互连
- **问题：** Cache、核心、IO互连复杂
- **FC策略：**
  - 层次化综合（hierarchical synthesis）
  - 约束继承（constraint propagation）
  - Interface timing budgeting

---

## 📊 tiny-gpu 架构分析

### 目录结构
```
tiny-gpu/
├── src/           # Verilog源码
├── test/          # 测试文件
├── docs/          # 文档
└── gds/           # 版图输出
```

### 特点
- **简化设计：** 适合快速理解GPU概念
- **完整流程：** 从RTL到GDS
- **教学导向：** 代码清晰，注释详细

### 学习价值
1. 快速建立GPU概念
2. 理解基本图形流水线
3. 小规模设计，适合完整综合实验

---

## 🎯 综合实验计划

### 实验1：tiny-gpu完整综合流程
**目标：** 用开源工具完成RTL到GDS

**步骤：**
1. **Yosys综合**
   ```bash
   yosys -p "synth -top gpu_top" tiny_gpu.v
   ```

2. **OpenROAD布局布线**
   - Floorplan
   - Place
   - CTS
   - Route

3. **对比FC流程**
   - 时序报告对比
   - 面积对比
   - QoR分析

### 实验2：Nyuzi单核综合
**目标：** 综合一个完整的GPGPU核心

**策略：**
1. **模块化综合**
   - 先综合小模块（ALU, Cache等）
   - 逐步集成

2. **时序优化**
   - 识别关键路径
   - 应用FC经验（pipeline, retiming）

3. **面积优化**
   - Resource sharing
   - Operator merging

### 实验3：自定义GPU模块
**目标：** 设计并综合一个小型GPU计算单元

**内容：**
- 设计SIMD ALU
- 添加简单调度器
- 完整综合流程
- 性能分析

---

## 📝 FC vs 开源工具对比实验

### 对比维度

| 维度 | FusionCompiler | Yosys+OpenROAD | 备注 |
|------|----------------|----------------|------|
| Fmax | ??? MHz | ??? MHz | 待测试 |
| Area | ??? um² | ??? um² | 待测试 |
| Power | ??? mW | ??? mW | 待测试 |
| Runtime | ??? min | ??? min | 待测试 |

### 测试设计
选择一个中等规模模块（如Nyuzi的integer_execute_stage）：
1. FC综合（如果有环境）
2. Yosys综合
3. 详细对比QoR

---

## 🚀 下一步行动

### Week 1-2: 环境准备
- [ ] 编译Yosys
- [ ] 安装OpenROAD
- [ ] 配置PDK（SkyWater 130nm）
- [ ] 运行tiny-gpu仿真

### Week 3-4: tiny-gpu综合
- [ ] Yosys综合实验
- [ ] 时序分析
- [ ] 优化迭代
- [ ] 记录经验

### Week 5-6: Nyuzi架构分析
- [ ] 阅读代码
- [ ] 理解SIMT实现
- [ ] 运行仿真
- [ ] 提取关键模块

### Week 7-8: Nyuzi模块综合
- [ ] 选择子模块
- [ ] 综合实验
- [ ] 应用FC经验
- [ ] 对比分析

---

**持续更新此文档...**
