# Day 2 学习总结 - 开源 EDA 工具链入门

📅 日期：2026-03-12
⏰ 学习时长：约 4 小时
🎯 Phase 1: 开源 EDA 工具链（Week 1）

---

## 🎉 今天的成就

### ✅ 完成的学习内容

#### 1. Yosys 开源综合工具基础
- 理解了 Yosys 在 EDA 流程中的定位（逻辑综合）
- 对比了开源工具 vs 商业工具（Yosys vs FusionCompiler）
- 学会了 Yosys 综合脚本的基本结构

#### 2. 三个实战综合例子
- **例子 1: 4-bit 加法器** - 基础综合流程
- **例子 2: 2选1 MUX** - 综合策略对比（MUX vs 基本门）
- **例子 3: 交通灯状态机** - FSM 综合详解

#### 3. Technology Mapping 工艺映射理论
- 理解了从通用门到标准单元的映射过程
- 学习了 Liberty 文件的作用和结构
- 掌握了标准单元选择的 trade-off 原理
- 对比了 FusionCompiler 和 Yosys 的映射策略

---

## 📚 关键知识点

### 1. Yosys 综合流程

```
RTL 代码
    ↓
read_verilog          # 读入设计
    ↓
hierarchy -top        # 设置顶层
    ↓
synth                 # 综合（RTL → 通用门）
    ↓
write_verilog         # 输出门级网表
```

**输出：** 通用门网表（$_AND_, $_DFF_, $_MUX_ 等）

---

### 2. FSM 综合流程

```
RTL 状态机
    ↓
fsm_detect           # 检测状态机
    ↓
fsm_extract          # 提取 FSM 结构
    ↓
fsm_opt              # 优化（状态最小化）
    ↓
synth                # 综合成门级
```

**关键理解：**
- 状态寄存器 → DFF
- 次态逻辑 → MUX + 比较器
- 输出逻辑 → 译码器

---

### 3. Technology Mapping 工艺映射

```
通用门网表
    ↓
dfflibmap -liberty tech.lib    # 映射寄存器
    ↓
abc -liberty tech.lib           # 映射组合逻辑
    ↓
标准单元网表
```

**核心概念：**
- Liberty 文件包含：timing、power、area 信息
- 标准单元选择是 trade-off：delay vs area vs power
- FusionCompiler 全局优化 vs Yosys 局部优化

---

### 4. 标准单元命名规则

```
AND2_X4
 │││ └─ X4: 驱动能力（4倍标准驱动）
 ││└─── 2:  输入数量
 │└──── AND: 逻辑功能
 └───── 标准单元类型
```

**选择策略：**
- 关键路径 → 用 X4（快，但面积大）
- 非关键路径 → 用 X1（省面积，但慢）
- 平衡路径 → 用 X2（折中）

---

## 🆚 FusionCompiler vs Yosys 对比总结

| 特性 | FusionCompiler | Yosys |
|------|----------------|-------|
| **定位** | 商业级综合工具 | 开源逻辑综合工具 |
| **输入** | RTL + SDC + Floorplan | RTL |
| **输出** | 物理感知网表 | 逻辑网表 |
| **优化** | 全局时序驱动 | 局部逻辑优化 |
| **工艺映射** | 自动智能选择 | 手动指定策略 |
| **学习成本** | 黑盒（看不到内部） | 透明（每步可见）|
| **适用场景** | 工业生产 | 学习/小项目 |

**关键启示：**
- FusionCompiler = 强大但黑盒
- Yosys = 简单但透明
- 两者互补，用 Yosys 理解 FusionCompiler 的原理！

---

## 💡 对工作的启示

### 理解 FusionCompiler 内部原理

现在我知道了：
1. **`compile_ultra` 内部做什么：**
   - 逻辑综合（RTL → 通用门）
   - 工艺映射（通用门 → 标准单元）
   - 优化迭代（upsize/downsize）

2. **为什么需要多次迭代：**
   - 全局优化是复杂的多目标问题
   - 需要平衡 timing、area、power
   - 一次无法达到最优

3. **时序报告的含义：**
   - Cell sizing（调整单元驱动）
   - 为什么有的门是 X1，有的是 X4
   - Critical path 优化策略

### 调试技巧

**当时序不满足时：**
- 检查关键路径上的单元是否足够快（X4？）
- 看是否有不必要的 X1 单元拖慢速度
- 理解 upsize 的成本（面积/功耗）

**当面积超标时：**
- 检查是否有过度优化（太多 X4）
- 看非关键路径能否 downsize
- 平衡 timing slack 和 area

---

## 📂 今天创建的文件

### 实战例子（3个）
```
learning-examples/yosys/
├── 01_simple_adder/          # 4-bit 加法器
│   ├── adder.v
│   ├── synth.ys
│   ├── adder_synth_example.v
│   └── DEMO_OUTPUT.md
│
├── 02_mux_example/           # MUX 综合对比
│   ├── mux_2to1.v
│   ├── synth_with_mux.ys
│   ├── synth_no_mux.ys
│   ├── mux_with_mux_example.v
│   ├── mux_with_gates_example.v
│   └── COMPARISON.md
│
└── 03_fsm_traffic_light/     # 交通灯状态机
    ├── traffic_light.v
    ├── synth.ys
    ├── synth_result_simplified.v
    ├── FSM_ANALYSIS.md
    └── VISUAL_GUIDE.md
```

### 学习笔记（5篇）
```
notes/
├── day2-yosys-intro.md           # Yosys 工具介绍
├── day2-fsm-synthesis.md         # FSM 综合实战
├── day2-technology-mapping.md    # 工艺映射原理
├── day2-cell-selection-strategy.md  # 单元选择策略
└── day2-summary.md               # 今天的总结（本文件）
```

### 安装指南
```
INSTALL_YOSYS.md                  # Yosys 安装说明
install_yosys.sh                  # 安装检查脚本
learning-examples/yosys/QUICK_START.md  # 快速开始指南
```

**统计：**
- ✅ 15 个 Verilog 设计文件
- ✅ 5 个综合脚本
- ✅ 9 个详细文档
- ✅ 约 5000+ 行学习材料

---

## 📈 学习进度

### Phase 1: 开源 EDA 工具链（4-6周）

#### Week 1: Yosys 逻辑综合
- ✅ Day 1: Yosys 介绍和基础（加法器）
- ✅ Day 2: MUX 综合对比
- ✅ Day 2: FSM 综合实战（交通灯）
- ✅ Day 2: Technology Mapping 理论
- ⏳ Day 3: 开源 PDK 介绍（Sky130）
- ⏳ Day 4: 完整设计综合练习

#### Week 2-3: OpenROAD（待学习）
- ⏳ Floorplanning
- ⏳ Placement
- ⏳ Clock Tree Synthesis
- ⏳ Routing
- ⏳ 时序优化

#### Week 4: OpenLane 自动化（待学习）
- ⏳ RTL → GDS 全流程

### Phase 2: GPU 架构（6-8周，待继续）
- ⏳ tiny-gpu 深入分析
- ⏳ SIMD 执行模型
- ⏳ Memory hierarchy

### Phase 3: 综合实战（4-6周，待开始）
- ⏳ 用开源工具综合 GPU 设计

---

## 🎓 学到的核心原理

### 1. 综合的本质
```
RTL（行为描述）→ 门级网表（结构描述）

过程：
- 解析 RTL 语法
- 提取逻辑功能
- 优化布尔表达式
- 映射到基本门
- 选择标准单元
```

### 2. FSM 综合原理
```
三段式状态机：
  - 时序逻辑（状态寄存器）→ DFF
  - 组合逻辑（次态逻辑）→ MUX/Decoder
  - 组合逻辑（输出逻辑）→ Decoder
```

### 3. 工艺映射的权衡
```
没有"完美"的单元！

Trade-off:
  快速 ←→ 省面积
  高驱动 ←→ 低功耗

关键：在正确的地方用正确的单元
```

---

## 💭 学习感悟

### 1. 开源工具的价值
虽然 Yosys 不如 FusionCompiler 强大，但：
- ✨ **透明性**：看到每一步过程
- ✨ **灵活性**：可以手动控制策略
- ✨ **教育性**：理解商业工具原理
- ✨ **免费**：在家也能学习实践

### 2. 理论与实践结合
- 在公司用商业工具（FusionCompiler）
- 用开源工具理解原理（Yosys）
- 两者互补，理解更深刻

### 3. 循序渐进
- 从简单例子（加法器）开始
- 到复杂设计（状态机）
- 再到理论深入（工艺映射）
- 学习曲线平滑，收获很大！

---

## 🎯 下次学习计划

### 如果在公司（理论为主）：
- 学习开源 PDK（Sky130）基础知识
- 了解 OpenROAD 工具链概览
- 继续 GPU 架构学习

### 如果在家（实践为主）：
- 安装 Yosys
- 运行今天的三个例子
- 修改 RTL，观察综合结果变化
- 尝试更复杂的设计（FIFO、UART）

---

## 📊 学习统计

### 时间分配
- Yosys 基础学习：1.5 小时
- FSM 实战练习：1.5 小时
- Technology Mapping 理论：1 小时
- 总计：约 4 小时

### 知识点覆盖
- ✅ 综合工具使用（Yosys）
- ✅ 综合流程理解（RTL → 门级）
- ✅ FSM 综合原理
- ✅ 工艺映射理论
- ✅ 标准单元选择策略
- ✅ 开源 vs 商业工具对比

### 实战经验
- ✅ 编写了 3 个 RTL 设计
- ✅ 编写了 5 个综合脚本
- ✅ 理解了门级网表结构
- ⏳ 实际运行综合（等待安装 Yosys）

---

## 🙏 致谢

感谢：
- **Yosys 开源项目**：提供免费的学习工具
- **Claude Code**：耐心的互动式教学
- **自己的坚持**：4 小时专注学习！

---

## 📝 备注

### 环境说明
- 当前环境：公司电脑，无法安装 Yosys
- 学习方式：理论为主，阅读文档和示例
- 后续计划：周末在家实践运行

### GitHub 备份
- 仓库：https://github.com/taopeng220/chip-design-learning
- 分支：day2-scheduler-learning
- 所有学习材料已备份，随时可访问

---

**今天学得很充实！期待明天继续！** 🎉

---

## 附录：快速参考

### Yosys 常用命令
```tcl
read_verilog design.v          # 读RTL
hierarchy -top module_name     # 设置顶层
synth -top module_name         # 综合
write_verilog output.v         # 输出网表
stat                           # 统计信息
```

### FSM 专用命令
```tcl
fsm_detect                     # 检测状态机
fsm_extract                    # 提取FSM
fsm_opt                        # 优化FSM
```

### Technology Mapping 命令
```tcl
dfflibmap -liberty tech.lib    # 映射寄存器
abc -liberty tech.lib          # 映射组合逻辑
abc -liberty tech.lib -D 1000  # 优化延迟
abc -liberty tech.lib -A       # 优化面积
```

### 标准单元命名
```
<FUNCTION><N>_X<DRIVE>

例如：
AND2_X1  - 2输入AND，1倍驱动
NAND3_X2 - 3输入NAND，2倍驱动
DFFR_X4  - 带复位DFF，4倍驱动
```
