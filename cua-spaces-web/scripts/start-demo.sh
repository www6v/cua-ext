#!/bin/bash
# Cua Spaces Web Demo 启动脚本
# 用法: ./start-demo.sh [--port PORT] [--no-wasm]

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WEB_APP_DIR="$PROJECT_ROOT/apps/cua-spaces-web"

# 默认参数
PORT=${PORT:-5174}
SKIP_WASM=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --no-wasm)
            SKIP_WASM=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --port PORT    指定端口号 (默认: 5174)"
            echo "  --no-wasm      跳过 WASM 构建 (使用 TypeScript fallback)"
            echo "  -h, --help     显示帮助"
            echo ""
            echo "环境变量:"
            echo "  PORT           端口号 (可被 --port 覆盖)"
            echo ""
            echo "示例:"
            echo "  $0                    # 使用默认配置启动"
            echo "  $0 --port 3000        # 使用端口 3000"
            echo "  $0 --no-wasm          # 跳过 WASM，使用纯 TypeScript"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Cua Spaces Web Demo"
echo "=========================================="
echo ""
echo "项目路径: $WEB_APP_DIR"
echo "端口: $PORT"
echo "WASM 构建: $([ "$SKIP_WASM" = true ] && echo '跳过' || echo '启用')"
echo ""

# 检查依赖
echo "检查依赖..."
if ! command -v pnpm &> /dev/null; then
    echo "错误: 未找到 pnpm，请先安装 pnpm"
    echo "安装: npm install -g pnpm"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "错误: 未找到 Node.js"
    exit 1
fi

echo "✓ Node.js: $(node --version)"
echo "✓ pnpm: $(pnpm --version)"
echo ""

# 进入项目目录
cd "$WEB_APP_DIR"

# 安装依赖
echo "安装依赖..."
if [ ! -d "node_modules" ]; then
    pnpm install --ignore-workspace
    echo "✓ 依赖安装完成"
else
    echo "✓ 依赖已存在，跳过安装"
fi
echo ""

# 构建 WASM (可选)
if [ "$SKIP_WASM" = false ]; then
    echo "构建 WASM 核心..."
    if command -v rustc &> /dev/null && command -v wasm-bindgen &> /dev/null; then
        pnpm core
        echo "✓ WASM 构建完成"
    else
        echo "⚠ Rust 工具链不完整，跳过 WASM 构建"
        echo "  将使用 TypeScript fallback（仅用于 demo 模式）"
    fi
else
    echo "跳过 WASM 构建（使用 --no-wasm）"
fi
echo ""

# 启动开发服务器
echo "=========================================="
echo "启动开发服务器..."
echo "=========================================="
echo ""
echo "访问地址: http://localhost:$PORT"
echo ""
echo "Demo 模式参数:"
echo "  ?demo=fresh      - 未登录状态，显示 onboarding"
echo "  ?demo=locked     - Keyvault 锁定状态"
echo "  ?bridge=demo     - 强制使用 demo 模式"
echo ""
echo "按 Ctrl+C 停止服务器"
echo ""

pnpm dev --port $PORT
