# 芯片设计进阶学习计划

> 作者：taopeng220
> 背景：FusionCompiler使用经验 + GPU模块综合经验
> 目标：开源EDA工具链 + GPU架构设计

---

## 📚 学习路线图

```
Phase 1: 开源EDA工具链 (4-6周)
├── Week 1-2: Yosys综合工具
│   ├── 基础使用：综合脚本编写
│   ├── 进阶：自定义Pass开发
│   └── 对比：FC vs Yosys的综合策略
├── Week 3-4: OpenROAD物理设计
│   ├── Floorplanning
│   ├── Placement & Routing
│   └── 时序优化
└── Week 5-6: OpenLane完整流程
    ├── PDK配置 (SkyWater 130nm)
    ├── 流程调优
    └── Tape-out一个小设计

Phase 2: GPU架构设计 (6-8周)
├── Week 1-2: tiny-gpu入门
│   ├── 理解GPU Pipeline
│   ├── Verilog实现分析
│   └── 仿真验证
├── Week 3-5: NyuziProcessor深度学习
│   ├── GPGPU架构分析
│   ├── SIMT执行模型
│   ├── Memory hierarchy
│   └── 综合实践
└── Week 6-8: 实战项目
    ├── 设计一个小型GPU模块
    ├── 完整的综合到P&R流程
    └── 性能分析与优化

Phase 3: 综合实战 (4-6周)
└── 用开源EDA工具链综合一个GPU设计
```

---

## 🎯 当前进度

- [x] 环境搭建
- [ ] Phase 1: EDA工具链
- [ ] Phase 2: GPU架构
- [ ] Phase 3: 综合实战

---

## 📁 目录结构

```
chip-design-learning/
├── eda-tools/          # 开源EDA工具相关
│   ├── yosys/          # Yosys学习与实验
│   ├── openroad/       # OpenROAD学习
│   └── openlane/       # OpenLane项目
├── gpu-architecture/   # GPU架构相关
│   ├── tiny-gpu/       # 入门GPU项目
│   ├── nyuzi/          # Nyuzi GPGPU处理器
│   └── custom-gpu/     # 自己的GPU设计
├── projects/           # 实战项目
│   └── gpu-eda-flow/   # GPU + EDA综合项目
└── notes/              # 学习笔记
    ├── eda-notes.md    # EDA工具笔记
    ├── gpu-notes.md    # GPU架构笔记
    └── synthesis.md    # 综合经验总结
```

---

## 🔗 关键资源

### EDA工具链
- [Yosys](https://github.com/YosysHQ/yosys) - 开源综合工具
- [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) - RTL到GDS
- [OpenLane](https://github.com/efabless/openlane2) - 自动化ASIC流程

### GPU架构
- [tiny-gpu](https://github.com/adam-maj/tiny-gpu) - 最小GPU实现
- [NyuziProcessor](https://github.com/jbush001/NyuziProcessor) - GPGPU架构

### 学习资料
- [OpenROAD Documentation](https://openroad.readthedocs.io/)
- [Yosys Manual](https://yosyshq.readthedocs.io/)
- GPU架构书籍：《GPU Gems》系列

---

## 💡 学习方法

### 对比学习法
每学一个开源工具，对比FusionCompiler：
- 相同点：理解通用算法
- 不同点：学习新思路
- 优劣分析：工业实践经验

### 项目驱动法
- 每个Phase都有实战项目
- 从小到大，逐步深入
- 记录问题与解决方案

---

## 📝 下一步行动

1. [ ] 克隆Yosys项目并编译
2. [ ] 克隆tiny-gpu项目并仿真
3. [ ] 克隆NyuziProcessor并分析架构
4. [ ] 搭建OpenLane环境

---

**Let's build chips! 🚀**
