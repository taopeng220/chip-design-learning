# EDA工具学习笔记

## Yosys vs FusionCompiler 对比

### 综合流程对比

#### FusionCompiler流程
```tcl
# FC典型综合流程
set_top_module xxx
read_verilog xxx.v
link
compile_ultra
report_timing
report_area
```

#### Yosys流程
```yosys
# Yosys综合脚本
read_verilog xxx.v
hierarchy -check -top xxx
proc; opt; fsm; opt; memory; opt
techmap; opt
abc -liberty xxx.lib
write_verilog synth.v
```

### 关键差异

| 特性 | FusionCompiler | Yosys |
|------|----------------|-------|
| 综合算法 | 私有优化算法 | ABC + 自定义Pass |
| Technology Mapping | 高度优化 | 可见、可定制 |
| 时序优化 | 自动化程度高 | 需要手动调优 |
| 学习曲线 | 黑盒工具 | 白盒，可深入理解 |

---

## 学习记录

### Day 1: Yosys基础
- [ ] 安装Yosys
- [ ] 运行第一个综合脚本
- [ ] 理解基本命令

### Day 2: 自定义Pass
- [ ] 学习Pass API
- [ ] 编写简单Pass

---

## 问题记录

### 问题1：...
**解决方案：** ...

---
