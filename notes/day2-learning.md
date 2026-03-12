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

#### Scheduler的作用
```
Dispatcher发来的Block
    ↓
Scheduler（调度器）
    ↓
决定哪些线程执行，哪些等待
    ↓
送到执行单元（ALU等）
```

（待补充：深入分析代码后填写）

---

## 🎯 今天的目标

- [x] 学习Git分支基础
- [x] 创建day2学习分支
- [ ] 深入分析tiny-gpu的Scheduler代码
- [ ] 理解线程调度机制
- [ ] 更新学习笔记

---

## 💡 学习感想

今天学会了Git分支，原来可以这样安全地实验！每天创建一个分支，失败了也不怕影响主分支。

期待深入学习Scheduler机制！🚀
