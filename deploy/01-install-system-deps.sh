#!/usr/bin/env bash
# 01-install-system-deps.sh — 安装 Cua 项目所需的系统依赖
#
# 用法:
#   bash 01-install-system-deps.sh          # 安装所有依赖
#   bash 01-install-system-deps.sh --check  # 仅检查已安装的依赖
#   bash 01-install-system-deps.sh --help   # 显示帮助

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── 帮助 ──────────────────────────────────────────────
show_help() {
    cat <<'EOF'
Cua 项目系统依赖安装脚本

用法:
  bash 01-install-system-deps.sh          安装所有依赖
  bash 01-install-system-deps.sh --check  仅检查，不安装
  bash 01-install-system-deps.sh --help   显示此帮助

安装的组件:
  1. Docker        — 容器运行时（沙箱必需）
  2. protoc        — Protocol Buffers 编译器（Rust 构建必需）
  3. pnpm          — Node.js 包管理器（TypeScript 构建需要）
  4. buf           — Protobuf linting/breaking 检查工具

注意: Docker 和 protoc 安装需要 sudo 权限。
EOF
}

# ─── 检查函数 ──────────────────────────────────────────
check_command() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -1) || true
        log_ok "$name: $version"
        return 0
    else
        log_error "$name: 未安装"
        return 1
    fi
}

check_docker() {
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            local ver
            ver=$(docker --version 2>&1 | head -1)
            log_ok "Docker: $ver"
            return 0
        else
            log_warn "Docker 已安装但无法运行（权限问题？）"
            log_warn "尝试: sudo usermod -aG docker \$USER && newgrp docker"
            return 1
        fi
    else
        log_error "Docker: 未安装"
        return 1
    fi
}

check_all() {
    local failed=0
    echo ""
    echo "=========================================="
    echo "  检查系统依赖"
    echo "=========================================="
    echo ""

    check_docker       || ((failed++))
    check_command protoc "protoc" || ((failed++))
    check_command pnpm   "pnpm"   || ((failed++))
    check_command buf    "buf"    || ((failed++))

    # 额外检查
    echo ""
    echo "--- 额外检查 ---"
    check_command rustc  "Rust"   || ((failed++))
    check_command cargo  "Cargo"  || ((failed++))
    check_command python3 "Python" || ((failed++))
    check_command uv     "uv"     || ((failed++))
    check_command node   "Node.js" || ((failed++))

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_ok "所有依赖已就绪！"
        return 0
    else
        log_warn "$failed 个依赖缺失。运行此脚本（不带 --check）进行安装。"
        return 1
    fi
}

# ─── 安装函数 ──────────────────────────────────────────
install_docker() {
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        log_ok "Docker 已安装且可用"
        return 0
    fi

    log_info "安装 Docker..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker.io
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y docker
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm docker
    else
        log_error "不支持的包管理器。请手动安装 Docker。"
        return 1
    fi

    # 启动 Docker 服务
    if command -v systemctl &>/dev/null; then
        sudo systemctl enable --now docker 2>/dev/null || true
    fi

    # 添加当前用户到 docker 组
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        log_warn "已将 $USER 添加到 docker 组。请运行 'newgrp docker' 或重新登录以生效。"
    fi

    log_ok "Docker 安装完成"
}

install_protoc() {
    if command -v protoc &>/dev/null; then
        log_ok "protoc 已安装: $(protoc --version 2>&1)"
        return 0
    fi

    log_info "安装 protoc..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq protobuf-compiler
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y protobuf-compiler
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm protobuf
    else
        # 手动安装
        log_info "使用二进制安装 protoc..."
        local PB_REL="https://github.com/protocolbuffers/protobuf/releases/latest"
        local PB_VERSION
        PB_VERSION=$(curl -sI "$PB_REL" | grep -i location | sed 's/.*\/v//' | tr -d '\r\n')
        if [[ -z "$PB_VERSION" ]]; then
            PB_VERSION="29.3"
        fi
        curl -sSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PB_VERSION}/protoc-${PB_VERSION}-linux-x86_64.zip" \
            -o /tmp/protoc.zip
        sudo unzip -o /tmp/protoc.zip -d /usr/local bin/protoc
        sudo unzip -o /tmp/protoc.zip -d /usr/local 'include/*'
        rm -f /tmp/protoc.zip
    fi

    log_ok "protoc 安装完成: $(protoc --version 2>&1)"
}

install_pnpm() {
    if command -v pnpm &>/dev/null; then
        log_ok "pnpm 已安装: $(pnpm --version 2>&1)"
        return 0
    fi

    log_info "安装 pnpm..."

    if command -v npm &>/dev/null; then
        npm install -g pnpm
    elif command -v corepack &>/dev/null; then
        corepack enable
        corepack prepare pnpm@latest --activate
    else
        log_info "使用 standalone 安装 pnpm..."
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        # 添加到 PATH
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
    fi

    log_ok "pnpm 安装完成: $(pnpm --version 2>&1)"
}

install_buf() {
    if command -v buf &>/dev/null; then
        log_ok "buf 已安装: $(buf --version 2>&1)"
        return 0
    fi

    log_info "安装 buf..."

    mkdir -p "$HOME/.local/bin"

    curl -sSL "https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64" \
        -o "$HOME/.local/bin/buf"
    chmod +x "$HOME/.local/bin/buf"

    # 确保 ~/.local/bin 在 PATH 中
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        log_warn "请确保 ~/.local/bin 在 PATH 中"
        log_warn "添加: export PATH=\"\$HOME/.local/bin:\$PATH\" 到 ~/.bashrc"
    fi

    log_ok "buf 安装完成: $($HOME/.local/bin/buf --version 2>&1)"
}

install_all() {
    echo ""
    echo "=========================================="
    echo "  安装系统依赖"
    echo "=========================================="
    echo ""

    install_docker
    echo ""
    install_protoc
    echo ""
    install_pnpm
    echo ""
    install_buf

    echo ""
    echo "=========================================="
    log_ok "所有系统依赖安装完成！"
    echo "=========================================="
    echo ""
    log_warn "如果 Docker 权限有问题，请运行:"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker  # 或重新登录"
}

# ─── 主入口 ──────────────────────────────────────────
main() {
    case "${1:-}" in
        --check)
            check_all
            exit $?
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            install_all
            echo ""
            check_all
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
