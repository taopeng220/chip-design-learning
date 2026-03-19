#!/bin/bash
# Yosys 自动安装脚本（Windows）

set -e

echo "=========================================="
echo "  Yosys 安装脚本 for Windows"
echo "=========================================="
echo ""

# 安装目录
INSTALL_DIR="/c/oss-cad-suite"
DOWNLOAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-03-11/oss-cad-suite-windows-x64-20240311.exe"

echo "Step 1: 检查安装目录..."
if [ -d "$INSTALL_DIR" ]; then
    echo "✓ 发现已存在的安装: $INSTALL_DIR"
    echo ""
    echo "检查 Yosys 是否已安装..."
    if [ -f "$INSTALL_DIR/bin/yosys.exe" ]; then
        echo "✓ Yosys 已经安装！"
        echo ""
        "$INSTALL_DIR/bin/yosys.exe" -V
        echo ""
        echo "如果想重新安装，请先删除 $INSTALL_DIR"
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo "  需要手动安装"
echo "=========================================="
echo ""
echo "由于安全限制，我们不能自动下载和安装可执行文件。"
echo "请按以下步骤手动安装："
echo ""
echo "1. 打开浏览器访问："
echo "   https://github.com/YosysHQ/oss-cad-suite-build/releases/latest"
echo ""
echo "2. 下载 Windows 版本（文件名类似）："
echo "   oss-cad-suite-windows-x64-YYYYMMDD.exe"
echo ""
echo "3. 双击运行安装程序"
echo ""
echo "4. 选择安装位置: C:\\oss-cad-suite"
echo ""
echo "5. 安装完成后，运行以下命令添加到 PATH:"
echo "   export PATH=\"/c/oss-cad-suite/bin:\$PATH\""
echo ""
echo "6. 验证安装:"
echo "   yosys -V"
echo ""
echo "=========================================="
