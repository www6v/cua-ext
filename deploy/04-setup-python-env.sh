#!/usr/bin/env bash
# 04-setup-python-env.sh — 创建 Python 虚拟环境并安装 Cua 依赖
#
# 用法:
#   bash 04-setup-python-env.sh          # 创建环境 + 安装依赖
#   bash 04-setup-python-env.sh --check  # 检查环境状态
#   bash 04-setup-python-env.sh --dev    # 开发模式（从源码安装）

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$DEPLOY_DIR/.venv"
CUA_PROJECT_ROOT="$(cd "$DEPLOY_DIR/../.." && pwd)"
CUA_MAIN="$CUA_PROJECT_ROOT/cua-main"

show_help() {
    cat <<'EOF'
创建 Python 虚拟环境并安装 Cua 依赖

用法:
  bash 04-setup-python-env.sh          创建环境 + 安装预构建 wheels
  bash 04-setup-python-env.sh --dev    从源码安装（需先运行 03-build-rust-core.sh）
  bash 04-setup-python-env.sh --check  检查环境状态
  bash 04-setup-python-env.sh --clean  删除虚拟环境

安装的包:
  - cua                   — 核心 SDK
  - cua[sandbox]          — 高层沙箱 API
  - cua-bench[browser]    — 基准测试框架
  - anthropic             — Anthropic API 客户端
  - playwright            — 浏览器自动化

环境位置: .venv/
激活命令: source .venv/bin/activate
EOF
}

check_env() {
    echo ""
    echo "=========================================="
    echo "  检查 Python 环境"
    echo "=========================================="
    echo ""

    if [[ ! -d "$VENV_DIR" ]]; then
        log_error "虚拟环境不存在: $VENV_DIR"
        log_info "运行: bash 04-setup-python-env.sh"
        return 1
    fi

    # 激活环境
    source "$VENV_DIR/bin/activate"

    local failed=0

    # 检查 Python
    log_ok "Python: $(python --version 2>&1)"
    log_info "  路径: $(which python)"

    # 检查关键包
    for pkg in cua cua_sandbox cua_bench anthropic; do
        if python -c "import $pkg" 2>/dev/null; then
            local ver
            ver=$(python -c "import $pkg; print(getattr($pkg, '__version__', 'installed'))" 2>/dev/null || echo "installed")
            log_ok "$pkg: $ver"
        else
            log_error "$pkg: 未安装或导入失败"
            ((failed++))
        fi
    done

    # 检查 cb 命令
    if command -v cb &>/dev/null; then
        log_ok "cb (cua-bench CLI): $(which cb)"
    else
        log_warn "cb 命令不可用"
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_ok "Python 环境就绪！"
        log_info "激活: source $VENV_DIR/bin/activate"
        return 0
    else
        log_warn "$failed 个包缺失"
        return 1
    fi
}

create_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        log_ok "虚拟环境已存在: $VENV_DIR"
        return 0
    fi

    log_info "创建虚拟环境..."
    uv venv "$VENV_DIR" --python 3.12

    log_ok "虚拟环境创建完成"
}

install_wheels() {
    log_info "安装 Cua Python 包（预构建 wheels）..."

    source "$VENV_DIR/bin/activate"

    # 安装核心包
    log_info "安装 cua + cua[sandbox]..."
    uv pip install \
        --extra-index-url https://wheels.cua.ai/simple \
        cua "cua[sandbox]"

    # 安装基准测试
    log_info "安装 cua-bench..."
    uv pip install \
        --extra-index-url https://wheels.cua.ai/simple \
        "cua-bench[browser]"

    # 安装 Anthropic SDK（用于代理 demo）
    log_info "安装 anthropic SDK..."
    uv pip install anthropic

    # 安装其他工具
    log_info "安装开发工具..."
    uv pip install pytest pytest-asyncio rich

    # 安装 Playwright 浏览器
    log_info "安装 Playwright Chromium..."
    python -m playwright install chromium 2>/dev/null || {
        log_warn "Playwright 浏览器安装失败（可能需要额外系统依赖）"
        log_info "尝试: python -m playwright install-deps chromium"
    }

    log_ok "所有 Python 包安装完成"
}

install_from_source() {
    log_info "从源码安装 Cua Python 包..."

    source "$VENV_DIR/bin/activate"

    if [[ ! -d "$CUA_MAIN/libs/cua/python" ]]; then
        log_error "找不到源码: $CUA_MAIN/libs/cua/python"
        log_error "请先运行: bash 03-build-rust-core.sh"
        return 1
    fi

    # 安装核心 SDK（从源码路径）
    log_info "安装 cua（从源码）..."
    uv pip install -e "$CUA_MAIN/libs/cua/python"

    # 安装 cua-sandbox（从源码路径）
    log_info "安装 cua-sandbox（从源码）..."
    uv pip install -e "$CUA_MAIN/libs/python/cua-sandbox"

    # 安装 cua-bench（从源码路径）
    log_info "安装 cua-bench（从源码）..."
    uv pip install -e "$CUA_MAIN/libs/cua-bench[browser]"

    # 安装其他依赖
    uv pip install anthropic pytest pytest-asyncio rich

    log_ok "从源码安装完成"
}

clean_env() {
    if [[ -d "$VENV_DIR" ]]; then
        log_info "删除虚拟环境: $VENV_DIR"
        rm -rf "$VENV_DIR"
        log_ok "清理完成"
    else
        log_info "虚拟环境不存在，无需清理"
    fi
}

main() {
    case "${1:-}" in
        --check)
            check_env
            exit $?
            ;;
        --dev)
            create_venv
            echo ""
            install_from_source
            echo ""
            check_env
            ;;
        --clean)
            clean_env
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            create_venv
            echo ""
            install_wheels
            echo ""
            check_env
            echo ""
            log_info "使用方法:"
            echo "  source $VENV_DIR/bin/activate"
            echo "  python demos/demo1_sandbox_basic.py"
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
