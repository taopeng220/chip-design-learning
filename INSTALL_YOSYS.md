# 在 Windows 上安装 Yosys

## 方法 1: OSS CAD Suite（最简单，推荐）⭐

### Step 1: 下载 OSS CAD Suite

访问官网下载页面：
**https://github.com/YosysHQ/oss-cad-suite-build/releases/latest**

或者直接下载 Windows 版本：
**https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-03-11/oss-cad-suite-windows-x64-20240311.exe**

### Step 2: 运行安装程序

1. 双击下载的 `.exe` 文件
2. 选择安装位置（建议：`C:\oss-cad-suite`）
3. 点击 Install
4. 等待安装完成（约 5 分钟）

### Step 3: 添加到 PATH

**选项 A: 自动添加（安装程序会询问）**
- 安装时勾选 "Add to PATH"

**选项 B: 手动添加**
1. 打开"环境变量"设置
2. 编辑用户变量 PATH
3. 添加：`C:\oss-cad-suite\bin`

### Step 4: 验证安装

打开新的 Git Bash 或 PowerShell：
```bash
yosys -V
```

应该看到类似输出：
```
Yosys 0.37+43 (git sha1 XXXXXXX, clang 17.0.6 -fPIC -Os)
```

---

## 方法 2: 使用 MSYS2 + pacman（需要 MSYS2）

如果您已经有 MSYS2（看起来您有 MinGW64）：

```bash
# 更新包管理器
pacman -Syu

# 安装 Yosys
pacman -S mingw-w64-x86_64-yosys
```

---

## 方法 3: 从源码编译（高级，耗时）

```bash
git clone https://github.com/YosysHQ/yosys.git
cd yosys
make config-msys2-64
make -j4
make install
```

---

## 快速测试安装

安装完成后，运行：
```bash
cd /c/Users/btao/Documents/GitHub/chip-design-learning/learning-examples/yosys/01_simple_adder
yosys synth.ys
```

如果看到综合输出，说明安装成功！🎉
