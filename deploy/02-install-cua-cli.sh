#!/usr/bin/env bash
# 02-install-cua-cli.sh — 安装 cua CLI 和 cua-driver
#
# 用法:
#   bash 02-install-cua-cli.sh          # 安装 CLI + Driver
#   bash 02-install-cua-cli.sh --cli    # 仅安装 CLI
#   bash 02-install-cua-cli.sh --check  # 检查安装状态

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

CUA_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CUA_MAIN="$CUA_PROJECT_ROOT/cua-main"

show_help() {
    cat <<'EOF'
安装 cua CLI 和 cua-driver

用法:
  bash 02-install-cua-cli.sh          安装 CLI + Driver
  bash 02-install-cua-cli.sh --cli    仅安装 CLI
  bash 02-install-cua-cli.sh --check  检查安装状态

安装来源:
  - cua CLI:       curl -fsSL https://cua.ai/install.sh | sh
  - cua-driver:    curl -fsSL https://cua.ai/driver/install.sh | bash

可选: 如果网络受限，可以从源码构建 CLI:
  cd cua-main/libs/cua && cargo build --release -p cua-cli
EOF
}

check_installation() {
    local failed=0
    echo ""
    echo "=========================================="
    echo "  检查 cua 安装状态"
    echo "=========================================="
    echo ""

    # 检查 cua CLI
    if command -v cua &>/dev/null; then
        local cua_ver
        cua_ver=$(cua --version 2>&1 || echo "unknown")
        log_ok "cua CLI: $cua_ver"
        log_info "  路径: $(which cua)"
    else
        log_error "cua CLI: 未安装"
        ((failed++))
    fi

    # 检查 cua-driver
    if command -v cua-driver &>/dev/null; then
        local driver_ver
        driver_ver=$(cua-driver --version 2>&1 || echo "unknown")
        log_ok "cua-driver: $driver_ver"
        log_info "  路径: $(which cua-driver)"
    else
        log_error "cua-driver: 未安装"
        ((failed++))
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_ok "所有组件已安装！"
        return 0
    else
        log_warn "$failed 个组件缺失"
        return 1
    fi
}

install_cua_cli() {
    if command -v cua &>/dev/null; then
        log_ok "cua CLI 已安装: $(cua --version 2>&1)"
        return 0
    fi

    log_info "安装 cua CLI..."
    log_info "使用官方安装脚本: curl -fsSL https://cua.ai/install.sh | sh"
    echo ""

    # 非交互式安装，仅 CLI
    curl -fsSL https://cua.ai/install.sh | sh -s -- --cli-only --yes

    # 确保 ~/.local/bin 在 PATH 中
    if [[ -f "$HOME/.local/bin/cua" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        if ! echo "$PATH" | grep -q ".local/bin"; then
            log_warn "请添加以下内容到 ~/.bashrc:"
            echo '  export PATH="$HOME/.local/bin:$PATH"'
        fi
    fi

    if command -v cua &>/dev/null; then
        log_ok "cua CLI 安装成功: $(cua --version 2>&1)"
    else
        log_error "cua CLI 安装失败"
        log_info "尝试从源码构建:"
        echo "  cd $CUA_MAIN/libs/cua"
        echo "  cargo build --release -p cua-cli"
        echo "  sudo cp target/release/cua /usr/local/bin/"
        return 1
    fi
}

install_cua_driver() {
    if command -v cua-driver &>/dev/null; then
        log_ok "cua-driver 已安装: $(cua-driver --version 2>&1)"
        return 0
    fi

    log_info "安装 cua-driver..."
    log_info "使用官方安装脚本: curl -fsSL https://cua.ai/driver/install.sh | bash"
    echo ""

    /bin/bash -c "$(curl -fsSL https://cua.ai/driver/install.sh)"

    if command -v cua-driver &>/dev/null; then
        log_ok "cua-driver 安装成功: $(cua-driver --version 2>&1)"
    else
        log_warn "cua-driver 安装可能需要重新加载 shell"
        log_info "尝试: source ~/.bashrc 或重新登录"
    fi
}

build_from_source() {
    log_info "从源码构建 cua CLI..."

    if [[ ! -d "$CUA_MAIN/libs/cua" ]]; then
        log_error "找不到 cua-main/libs/cua 目录"
        log_error "请确认 Cua 项目路径: $CUA_MAIN"
        return 1
    fi

    # 确保 protoc 已安装
    if ! command -v protoc &>/dev/null; then
        log_error "需要先安装 protoc: bash 01-install-system-deps.sh"
        return 1
    fi

    cd "$CUA_MAIN/libs/cua"

    log_info "构建 cua-sdk..."
    cargo build --release -p cua-sdk

    log_info "构建 cua-cli..."
    cargo build --release -p cua-cli

    # 安装到 ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    cp target/release/cua "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/cua"

    log_ok "从源码构建完成"
    log_info "cua CLI: $HOME/.local/bin/cua"
}

main() {
    case "${1:-}" in
        --check)
            check_installation
            exit $?
            ;;
        --cli)
            install_cua_cli
            ;;
        --source)
            build_from_source
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            install_cua_cli
            echo ""
            install_cua_driver
            echo ""
            check_installation
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
