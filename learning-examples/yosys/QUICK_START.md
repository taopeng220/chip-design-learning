# Yosys 快速开始指南

## 🎯 目标

在 10-15 分钟内完成 Yosys 安装并运行第一个综合例子！

---

## 📦 Step 1: 安装 Yosys

### 方法 A: 下载安装程序（推荐，5分钟）

1. **打开浏览器，访问：**
   ```
   https://github.com/YosysHQ/oss-cad-suite-build/releases/latest
   ```

2. **下载 Windows 版本：**
   - 找到文件名类似 `oss-cad-suite-windows-x64-20240311.exe` 的链接
   - 点击下载（约 500MB，需要 2-3 分钟）

3. **运行安装程序：**
   - 双击下载的 `.exe` 文件
   - 选择安装路径：`C:\oss-cad-suite`（或其他您喜欢的位置）
   - 勾选 "Add to PATH"（重要！）
   - 点击 Install，等待完成

4. **验证安装：**
   - 打开**新的** Git Bash 窗口（必须是新窗口，让 PATH 生效）
   - 运行：
     ```bash
     yosys -V
     ```
   - 应该看到版本信息

---

### 方法 B: 便携版（无需安装，3分钟）

如果您不想安装，可以下载便携版：

1. **下载便携版压缩包：**
   ```
   https://github.com/YosysHQ/oss-cad-suite-build/releases
   ```
   找到 `.zip` 文件

2. **解压到任意位置：**
   ```bash
   # 例如解压到
   C:\Tools\oss-cad-suite\
   ```

3. **临时添加到 PATH：**
   ```bash
   export PATH="/c/Tools/oss-cad-suite/bin:$PATH"
   ```

4. **验证：**
   ```bash
   yosys -V
   ```

---

## 🚀 Step 2: 运行第一个综合例子

### 例子 1: 简单加法器（1分钟）

```bash
# 进入例子目录
cd /c/Users/btao/Documents/GitHub/chip-design-learning/learning-examples/yosys/01_simple_adder

# 运行综合
yosys synth.ys

# 查看生成的网表
cat adder_synth.v
```

**预期输出：**
- 看到综合过程的详细日志
- 生成 `adder_synth.v` 门级网表文件

---

### 例子 2: MUX 对比（2分钟）

```bash
cd ../02_mux_example

# 方式1: 保留 MUX
yosys synth_with_mux.ys

# 方式2: 分解成基本门
yosys synth_no_mux.ys

# 对比两个网表
diff mux_with_mux.v mux_with_gates.v
```

---

### 例子 3: 交通灯 FSM（3分钟）

```bash
cd ../03_fsm_traffic_light

# 运行综合
yosys synth.ys

# 查看统计报告
grep "Number of cells" -A 10 yosys.log
```

---

## 🐛 常见问题

### Q1: 运行 `yosys -V` 提示 "command not found"

**原因：** PATH 未设置或未生效

**解决：**
1. 关闭当前终端，重新打开**新的** Git Bash
2. 或者手动添加 PATH：
   ```bash
   export PATH="/c/oss-cad-suite/bin:$PATH"
   ```
3. 验证 PATH：
   ```bash
   echo $PATH | grep oss-cad-suite
   ```

---

### Q2: 安装程序下载太慢

**解决：**
- 使用国内镜像（如果有）
- 或者先下载便携版 `.zip` 文件
- 晚上下载（网速更快）

---

### Q3: 安装后占用空间很大

**说明：** OSS CAD Suite 包含很多工具，约 1-2GB
- 只需要 Yosys 的话，可以下载单独的 Yosys 二进制
- 但推荐保留完整套件，后续学习会用到

---

## ✅ 验证清单

安装成功后，确认以下命令都能运行：

```bash
# Yosys 版本
yosys -V

# 帮助信息
yosys -h

# 交互式模式（输入 exit 退出）
yosys

# 运行脚本
yosys -s learning-examples/yosys/01_simple_adder/synth.ys
```

---

## 📚 下一步

安装完成后，您可以：

1. **运行三个例子** - 看真实的综合输出
2. **修改 RTL** - 尝试改变设计，看综合结果变化
3. **阅读文档** - 深入理解每个综合步骤

**准备好了吗？开始综合之旅吧！** 🎉
