# Day 3 学习总结 - OpenROAD 与物理实现深入

📅 日期：2026-03-13
⏰ 学习时长：约 5 小时
🎯 Phase 1: 开源 EDA 工具链（Week 1）

---

## 🎉 今天的成就

### ✅ 完成的学习内容

#### 1. OpenROAD 工具链概览
- 理解了 OpenROAD 在 EDA 流程中的定位（物理实现）
- 对比了 OpenROAD vs FusionCompiler 的功能和差异
- 学习了开源工具链的模块化架构

#### 2. 从 STA 角度理解 P&R
- 深入理解了 P&R 各阶段如何影响时序
- 掌握了 Placement/CTS/Routing 对 STA 的影响
- 理解了从"估算"到"精确"的演变过程

#### 3. Wire Load Models 深入
- Zero Wire Load vs Wire Load Model vs 实际延迟
- 理解了综合阶段时序不准确的原因
- 学会了判断 STA 报告的可信度

#### 4. 完整 OpenROAD 流程实例
- 通过 4-bit Counter 设计演示了完整流程
- 从 RTL → Yosys → ABC → OpenROAD → GDS
- 观察了各阶段 Slack 的演变（+8.03 → +7.76ns）

#### 5. Estimated vs Propagated 详解
- Wire Delay: estimated（基于距离估算）
- Clock Delay: propagated（CTS 后的实际值）
- 学会了解读 STA 报告中的标记

#### 6. Floorplan 深度剖析 ⭐
- 三大核心决策（芯片尺寸、Macro 摆放、功率规划）
- Macro 摆放的黄金法则
- 实战案例（CPU + Cache 优化）
- 10 条 Floorplan 黄金法则

---

## 📚 关键知识点

### 1. P&R 流程的本质

```
P&R = 让 STA 从"不准确"变成"精确"

Floorplan:  确定芯片框架 → Wire Delay 估算（±30%）
Placement:  确定单元位置 → Wire Delay 较准（±15%）
CTS:        构建时钟树   → Clock Delay 精确
Routing:    实际走线     → Wire Delay 精确（±5%）
SPEF:       寄生提取     → 所有 Delay 精确 ✅
```

---

### 2. 各阶段对时序的影响

#### 关键发现

**Placement → CTS:**
- Slack 几乎不变（+8.03 → +8.05ns）
- 原因：Launch 和 Capture Clock 都增加，相互抵消
- 只有 Skew (0.02ns) 影响

**CTS → Routing:**
- Slack 减少 3%（+8.05 → +7.82ns）
- 原因：Wire Delay 增加（实际走线比直线长）

**Routing → SPEF:**
- Slack 微调（+7.82 → +7.76ns）
- 精确 RC 参数提取

---

### 3. STA 报告解读

#### Estimated vs Propagated

```
(estimated) - Wire Delay 估算
  - 出现时机：Placement 后，Routing 前
  - 含义：基于 Manhattan 距离估算
  - 误差：±10-20%

(propagated) - Clock Delay 实际化
  - 出现时机：CTS 后
  - 含义：实际时钟树延迟，不再是 ideal (0)
  - 精度：准确 ✅

判断 STA 可信度：
  □ Clock 是 propagated? → 是✅ / ideal❌
  □ Wire Delay 无 (est)? → 是✅ / 有(est)⚠️
  □ 读入了 SPEF? → 是✅ / 否⚠️
```

---

### 4. Floorplan 的三大核心决策

#### 决策 1: 芯片尺寸

```
Utilization = (Cell Area + Macro Area) / Core Area

推荐值：60-75%

过高（>85%）：
  ❌ Routing 困难
  ❌ Congestion 高
  ❌ 难以优化

过低（<50%）：
  ❌ 面积浪费
  ❌ Wire 长
  ❌ 成本高

Aspect Ratio: 1.0 - 2.0（接近正方形最佳）
```

---

#### 决策 2: Macro 摆放

**黄金法则：**

1. **避免中心摆放**
   - Macro 靠边 → Standard Cells 连续区域
   - Macro 在中心 → Cells 分割，布线困难

2. **考虑连接关系**
   - 相关模块聚类
   - 数据流向优化
   - 减少 Wire Length

3. **对齐和通道**
   - Macro 对齐（底部/顶部）
   - 留出 Routing Channel（10-20 行）
   - 形成规则空间

4. **对称性**
   - 时钟树平衡
   - 功率网络对称
   - IR Drop 均衡

---

#### 决策 3: 功率规划

**层次结构：**

```
Power Pads（外部供电）
    ↓
Power Ring（包围 Core，粗金属）
    ↓
Power Straps（网格，中层金属）
    ↓
Power Rails（Standard Cell 供电，M1）
```

**关键参数：**
- Strap Width: 1-5 um（根据电流）
- Spacing: 50-200 um
- 目标：IR Drop < 5% VDD

---

### 5. 实战案例：CPU + Cache 优化

**Bad Floorplan:**
```
- Cache 在中心，分割 Standard Cell 区域
- Register File 距离 CPU Core 远
- Critical Path Wire Delay: 1.2ns
- Slack: -0.3ns ❌
```

**Good Floorplan:**
```
- Cache 靠边
- Register File 紧邻 Core
- CPU Core 形成连续区域
- Critical Path Wire Delay: 0.4ns（减少 67%！）
- Slack: +0.5ns ✅
```

**启示：**
- 同样的设计，只是 Floorplan 不同
- Wire Delay 差异 0.8ns
- Slack 从违规变满足
- **Floorplan 是优化的基础！**

---

## 🆚 OpenROAD vs FusionCompiler 对比总结

| 特性 | FusionCompiler | OpenROAD |
|------|----------------|----------|
| **类型** | 商业一体化 | 开源模块化 |
| **综合** | 物理感知综合 | Yosys（纯逻辑）|
| **Floorplan** | 智能自动 | 需手动调整 |
| **Placement** | 全局最优 | RePlAce（学术算法）|
| **CTS** | 工业级 | TritonCTS（基础）|
| **Routing** | 强大 | TritonRoute（不错）|
| **优化** | 全局迭代 | 局部优化 |
| **命令** | 简洁（10行）| 详细（100+行）|
| **学习曲线** | 陡（黑盒）| 平缓（透明）|
| **适用场景** | 工业生产 | 学习/小项目 |

**核心差异：**
- FusionCompiler：全局智能优化，黑盒
- OpenROAD：模块化透明，适合学习

---

## 💡 对工作的启示

### 1. 理解 FusionCompiler 内部原理

**现在我知道了：**
- `compile_ultra` 内部做了什么
- `place_opt` 如何优化 Wire Delay
- `clock_opt` 如何平衡时钟树
- 为什么需要多次迭代

**可以更好地：**
- 理解时序报告
- 调试 Placement/Routing 问题
- 设置合理的约束和优化目标

---

### 2. Floorplan 的重要性

**在实际工作中：**
- 评审 Floorplan 时的关键点
  * Utilization 是否合理？
  * Macro 摆放是否考虑连接关系？
  * 是否有足够的 Routing Channel？
  * 关键路径是否优化？

- 发现问题的能力
  * Macro 在中心 → 预警
  * Utilization > 85% → 风险
  * 不对称的布局 → 时钟/功率问题

---

### 3. 读懂 STA 报告

**关键技能：**

```
判断可信度：
  ✅ Clock propagated + 无 Wire (est) + 有 SPEF → 可信
  ⚠️ Clock ideal → 综合阶段，不可信
  ⚠️ Wire (est) → Placement 后，留 margin

理解 Slack 演变：
  - 综合后：过于乐观（Zero WL）
  - CTS 后：Clock 增加，Slack 几乎不变
  - Routing 后：Wire Delay 增加，Slack 减少
  - SPEF 后：最终值
```

---

## 📂 今天创建的文件

### 学习笔记（7篇）

```
notes/
├── day3-openroad-overview.md           # OpenROAD 工具链概览
├── day3-pnr-from-sta-perspective.md    # 从 STA 角度理解 P&R
├── day3-wire-load-models.md            # Wire Load Models 深入
├── day3-estimated-vs-propagated.md     # STA 报告解读
├── day3-floorplan-deep-dive.md         # Floorplan 深度剖析 ⭐
└── day3-summary.md                     # 今天的总结（本文件）
```

### 实战例子（1个）

```
learning-examples/openroad/01_counter_example/
├── counter.v                           # 4-bit Counter RTL
└── COMPLETE_FLOW.md                    # 完整流程演示（超详细）
```

**统计：**
- ✅ 8 个详细文档
- ✅ 1 个完整流程实例
- ✅ 约 8000+ 行学习材料

---

## 📈 学习进度

### Phase 1: 开源 EDA 工具链（4-6周）

#### Week 1: Yosys + OpenROAD 基础（60% 完成）✨

**Day 1-2: Yosys 逻辑综合**
- ✅ Yosys 基础和综合流程
- ✅ 三个实战例子（加法器、MUX、FSM）
- ✅ Technology Mapping 理论

**Day 3: OpenROAD 物理实现** ← 今天
- ✅ OpenROAD 工具链概览
- ✅ P&R 流程深入（从 STA 角度）
- ✅ 完整流程实例（RTL → GDS）
- ✅ Floorplan 深度剖析

**待学习：**
- ⏳ Day 4: OpenLane 自动化流程
- ⏳ Day 5: 实际运行工具（周末在家）

#### Week 2-3: OpenROAD 深入（待学习）
- ⏳ Placement 算法详解
- ⏳ CTS 算法详解
- ⏳ Routing 算法详解
- ⏳ 时序优化技巧

#### Week 4: OpenLane 实战（待学习）
- ⏳ 完整设计流片

### Phase 2: GPU 架构（6-8周，待继续）
- ⏳ tiny-gpu 深入分析

### Phase 3: 综合实战（4-6周，待开始）
- ⏳ 综合 GPU 设计

---

## 🎓 核心收获

### 1. P&R 流程的理解

**从 STA 角度看 P&R：**

```
Setup Slack = Required - Arrival
            = (Capture Clock + Period - Setup) - (Launch Clock + Logic + Wire)

P&R 各阶段优化什么：
  - Placement: 优化 Wire Delay（单元位置）
  - CTS: 优化 Clock Delay（平衡时钟树）
  - Routing: 确定最终 Wire Delay（实际走线）

为什么 CTS 后 Slack 几乎不变：
  - Launch Clock 和 Capture Clock 同时增加
  - 相互抵消，只有 Skew 影响
  - 好的 CTS → Skew 小 → Slack 稳定
```

---

### 2. Floorplan 是成功的关键

**核心思想：**
```
一个好的 Floorplan：
  ✅ 关键路径短（Wire Delay 小）
  ✅ Routing 通道充足（Congestion 低）
  ✅ 功率网络合理（IR Drop 小）
  ✅ 利用率适中（60-75%）

一个坏的 Floorplan：
  ❌ 后续再优化也救不回来
  ❌ 可能导致 Timing 无法收敛
  ❌ 可能导致 Routing 失败
  ❌ 浪费大量调试时间

结论：Floorplan 要花时间做好！
```

---

### 3. 工具理解的提升

**FusionCompiler 的价值：**
- 全局智能优化（时序驱动）
- 物理感知综合（Topographical）
- 强大的收敛保证
- 值那么多钱是有道理的

**OpenROAD 的价值：**
- 完全免费开源
- 透明，每步可见
- 适合学习 EDA 原理
- 中小规模设计足够用

**两者互补：**
- 工作用 FusionCompiler（效率）
- 学习用 OpenROAD（理解原理）
- 通过 OpenROAD 理解 FusionCompiler

---

## 💭 学习感悟

### 1. 从 STA 角度理解 P&R 的妙处

**之前（只看 STA 报告）：**
- 知道 Arrival Time、Required Time、Slack
- 但不知道这些数字怎么来的
- 不理解为什么 Placement/Routing 后会变化

**现在（理解 P&R）：**
- 知道 Wire Delay 是如何从估算到精确
- 理解 Clock Delay 从 ideal 到 propagated
- 明白 Slack 演变的内在逻辑
- 能判断 STA 报告的可信度

**收获：**
- STA 和 P&R 不再是割裂的
- 形成了完整的认知闭环
- 调试时序问题更有方向

---

### 2. Floorplan 的艺术性

**Floorplan 不仅是技术，更是艺术：**
- 需要经验（知道什么样的布局好）
- 需要直觉（权衡多个目标）
- 需要耐心（反复迭代优化）

**就像城市规划：**
- 好的规划让交通顺畅（Wire 短）
- 坏的规划后期再修也堵（Congestion）
- 前期多花时间规划，后期省力

---

### 3. 开源工具的学习价值

**通过 OpenROAD 学习：**
- 看到了每个步骤的输入输出
- 理解了算法的思路
- 知道了优化的方向

**反过来理解 FusionCompiler：**
- 明白了工具内部在做什么
- 知道了为什么需要多次迭代
- 理解了各种优化选项的含义

**两者结合：**
- 工作效率高（用 FC）
- 理解深刻（学 OpenROAD）
- 完美！

---

## 🎯 下次学习计划

### 选项 A: 继续 Week 1（推荐）
- OpenLane 自动化流程
- 一键式 RTL → GDS
- 实际开源芯片案例

### 选项 B: 深入算法细节
- Placement 算法（RePlAce）
- CTS 算法（TritonCTS）
- Routing 算法（TritonRoute）

### 选项 C: 实践操作（周末在家）
- 安装 Yosys + OpenROAD
- 运行 Counter 例子
- 看真实的输出

### 选项 D: 切换到 Phase 2
- GPU 架构学习
- tiny-gpu 代码分析

---

## 📊 学习统计

### 时间分配
- OpenROAD 概览：1 小时
- P&R 深入理解：1.5 小时
- 完整流程实例：1.5 小时
- Floorplan 深入：1 小时
- 总计：约 5 小时深度学习

### 知识点覆盖
- ✅ OpenROAD 工具链架构
- ✅ P&R 各阶段作用
- ✅ STA 时序演变
- ✅ Wire Load Models
- ✅ Estimated vs Propagated
- ✅ Floorplan 三大决策
- ✅ Macro 摆放策略
- ✅ 功率规划
- ✅ 实战优化案例

### 文档产出
- ✅ 7 篇深度笔记
- ✅ 1 个完整实例
- ✅ 8000+ 行学习材料
- ✅ 从理论到实践的完整覆盖

---

## 🙏 致谢

感谢：
- **OpenROAD 开源项目**：提供优秀的开源 P&R 工具
- **Claude Code**：耐心的互动式教学和深度讲解
- **自己的坚持**：5 小时高强度学习！
- **STA 基础**：让学习 P&R 事半功倍

---

## 📝 备注

### 环境说明
- 当前环境：公司电脑，无法安装工具
- 学习方式：理论深入 + 文档阅读
- 后续计划：周末在家实践运行

### GitHub 备份
- 仓库：https://github.com/taopeng220/chip-design-learning
- 分支：day2-scheduler-learning
- 所有学习材料已备份

---

**Day 3 圆满完成！期待下次继续学习！** 🎉

---

## 附录：快速参考

### P&R 流程速查

```
RTL
 ↓ Yosys
通用门网表
 ↓ ABC
标准单元网表
 ↓ Floorplan
确定芯片框架
 ↓ Placement
确定单元位置 → Wire Delay 估算
 ↓ CTS
构建时钟树 → Clock Delay 精确
 ↓ Routing
实际走线 → Wire Delay 精确
 ↓ SPEF
寄生提取 → 最终 STA
 ↓
GDS
```

### Floorplan 黄金法则速查

1. Utilization: 60-75%
2. Macro 靠边
3. 考虑连接关系
4. 对齐和通道
5. 对称性
6. 数据流优化
7. 时序驱动
8. 功率规划提前
9. 使用 Halo
10. 迭代优化

### STA 可信度判断

```
✅ 最可信：Clock (prop) + Wire 无(est) + SPEF
⚠️ 较可信：Clock (prop) + Wire 无(est)
⚠️ 不太可信：Clock (prop) + Wire (est)
❌ 不可信：Clock (ideal)
```
