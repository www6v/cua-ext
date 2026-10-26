#!/bin/bash
# Cua Spaces Web 完整部署脚本
# 包含所有依赖安装和配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WEB_APP_DIR="$PROJECT_ROOT/apps/cua-spaces-web"

echo "=========================================="
echo "Cua Spaces Web 完整部署"
echo "=========================================="
echo ""
echo "项目根目录: $PROJECT_ROOT"
echo "Web 应用目录: $WEB_APP_DIR"
echo ""

# 检查系统要求
echo "检查系统要求..."

# Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装"
    echo "请安装 Node.js 18+ (推荐 20+)"
    exit 1
fi
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "⚠ Node.js 版本过低 ($(node --version))，建议升级到 18+"
fi
echo "✓ Node.js: $(node --version)"

# pnpm
if ! command -v pnpm &> /dev/null; then
    echo "安装 pnpm..."
    npm install -g pnpm
fi
echo "✓ pnpm: $(pnpm --version)"

# Rust (可选，用于 WASM)
if command -v rustc &> /dev/null; then
    echo "✓ Rust: $(rustc --version)"

    # 检查 wasm32 target
    if rustup target list --installed | grep -q "wasm32-unknown-unknown"; then
        echo "✓ wasm32-unknown-unknown target 已安装"
    else
        echo "安装 wasm32-unknown-unknown target..."
        rustup target add wasm32-unknown-unknown
    fi

    # 检查 wasm-bindgen-cli
    if command -v wasm-bindgen &> /dev/null; then
        echo "✓ wasm-bindgen-cli: $(wasm-bindgen --version)"
    else
        echo "安装 wasm-bindgen-cli 0.2.126..."
        cargo install wasm-bindgen-cli --version 0.2.126
    fi
else
    echo "⚠ Rust 未安装，将跳过 WASM 构建"
    echo "  如需完整功能，请安装 Rust: https://rustup.rs/"
fi

echo ""
echo "=========================================="
echo "安装项目依赖"
echo "=========================================="
echo ""

cd "$WEB_APP_DIR"

# 安装 npm 依赖
echo "安装 npm 依赖..."
pnpm install --ignore-workspace
echo "✓ npm 依赖安装完成"
echo ""

# 构建 WASM
echo "=========================================="
echo "构建 WASM 核心模块"
echo "=========================================="
echo ""

if command -v rustc &> /dev/null && command -v wasm-bindgen &> /dev/null; then
    echo "构建 WASM..."
    pnpm core
    echo "✓ WASM 构建完成"
else
    echo "⚠ 跳过 WASM 构建（缺少 Rust 工具链）"
    echo "  Demo 模式将使用 TypeScript fallback"
fi

echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="
echo ""
echo "启动方式："
echo "  1. 快速启动（使用默认配置）:"
echo "     cd $WEB_APP_DIR"
echo "     pnpm dev"
echo ""
echo "  2. 使用启动脚本:"
echo "     $SCRIPT_DIR/start-demo.sh"
echo ""
echo "  3. 自定义端口:"
echo "     pnpm dev --port 3000"
echo ""
echo "访问地址: http://localhost:5174"
echo ""
echo "Demo 模式参数:"
echo "  ?demo=fresh      - 未登录状态，显示 onboarding 流程"
echo "  ?demo=locked     - Keyvault 锁定状态"
echo "  ?demo=fresh,locked - 组合使用"
echo "  ?bridge=demo     - 强制使用 demo 模式（在真实 host 中）"
echo ""
echo "主要页面路由:"
echo "  /                - 主页（Spaces 列表）"
echo "  /machines        - Machines 管理"
echo "  /agents          - Agents 管理"
echo "  /keyvault        - Keyvault（凭证管理）"
echo "  /settings        - 设置"
echo "  /onboarding      - 首次使用引导"
echo "  /notifications   - 通知"
echo ""
