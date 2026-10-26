#!/usr/bin/env bash
# 03-build-rust-core.sh — 从源码构建 Cua Rust 核心 SDK
#
# 用法:
#   bash 03-build-rust-core.sh          # 构建核心 SDK
#   bash 03-build-rust-core.sh --test   # 构建并运行测试
#   bash 03-build-rust-core.sh --full   # 构建所有组件

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
CUA_LIBS="$CUA_MAIN/libs/cua"

show_help() {
    cat <<'EOF'
从源码构建 Cua Rust 核心 SDK

用法:
  bash 03-build-rust-core.sh          构建核心 SDK (cua-sdk)
  bash 03-build-rust-core.sh --test   构建并运行测试
  bash 03-build-rust-core.sh --full   构建所有主要组件
  bash 03-build-rust-core.sh --clean  清理构建产物

前置条件:
  - protoc 已安装 (bash 01-install-system-deps.sh)
  - Rust 工具链 (rustup 会自动下载 1.97.1)

构建产物:
  - libs/cua/target/release/libcua_sdk.so  — 共享库
  - libs/cua/target/release/cua            — CLI 二进制
  - libs/cua/python/cua/_native.py         — Python 绑定
EOF
}

check_prerequisites() {
    local failed=0

    if ! command -v protoc &>/dev/null; then
        log_error "protoc 未安装。运行: bash 01-install-system-deps.sh"
        ((failed++))
    fi

    if ! command -v cargo &>/dev/null; then
        log_error "Rust/Cargo 未安装"
        ((failed++))
    fi

    if [[ ! -d "$CUA_LIBS" ]]; then
        log_error "找不到 $CUA_LIBS"
        ((failed++))
    fi

    return $failed
}

build_core_sdk() {
    log_info "构建 cua-sdk (release mode)..."
    cd "$CUA_LIBS"

    # 构建核心 SDK
    cargo build --release -p cua-sdk

    if [[ -f target/release/libcua_sdk.so ]] || [[ -f target/release/libcua_sdk.dylib ]]; then
        log_ok "cua-sdk 构建成功"
        ls -lh target/release/libcua_sdk.* 2>/dev/null || true
    else
        log_warn "构建完成但未找到共享库（可能已静态链接）"
    fi
}

build_cli() {
    log_info "构建 cua CLI..."
    cd "$CUA_LIBS"
    cargo build --release -p cua-cli

    if [[ -f target/release/cua ]]; then
        log_ok "cua CLI 构建成功: $(ls -lh target/release/cua | awk '{print $5}')"
    fi
}

build_fixtures() {
    log_info "构建测试 fixtures..."
    cd "$CUA_LIBS"

    if [[ -f scripts/build-test-fixtures.sh ]]; then
        bash scripts/build-test-fixtures.sh
        log_ok "测试 fixtures 构建完成"
    else
        log_warn "scripts/build-test-fixtures.sh 不存在，跳过"
    fi
}

generate_python_bindings() {
    log_info "生成 Python UniFFI 绑定..."
    cd "$CUA_LIBS"

    if [[ -f scripts/stage-uniffi-library.mjs ]]; then
        node scripts/stage-uniffi-library.mjs
        log_ok "Python 绑定生成完成"
    else
        log_warn "scripts/stage-uniffi-library.mjs 不存在，跳过"
    fi
}

run_tests() {
    log_info "运行核心测试..."
    cd "$CUA_LIBS"

    # Proto 合约检查
    if [[ -f scripts/check-proto.sh ]]; then
        log_info "检查 Protobuf 合约..."
        bash scripts/check-proto.sh || log_warn "Protobuf 检查失败（可能缺少 buf）"
    fi

    # 核心 crate 测试
    log_info "运行 cargo test..."
    cargo test --locked \
        -p cua-sdk \
        -p cua-proto \
        -- --test-threads=4

    log_ok "测试完成"
}

build_all() {
    log_info "构建所有主要组件..."
    cd "$CUA_LIBS"

    build_core_sdk
    echo ""
    build_cli
    echo ""
    build_fixtures
    echo ""
    generate_python_bindings

    echo ""
    log_ok "所有组件构建完成！"
}

clean_build() {
    log_info "清理构建产物..."
    cd "$CUA_LIBS"
    cargo clean
    log_ok "清理完成"
}

main() {
    echo ""
    echo "=========================================="
    echo "  Cua Rust 核心 SDK 构建"
    echo "=========================================="
    echo ""

    case "${1:-}" in
        --test)
            check_prerequisites || exit 1
            build_core_sdk
            echo ""
            run_tests
            ;;
        --full)
            check_prerequisites || exit 1
            build_all
            ;;
        --clean)
            clean_build
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            check_prerequisites || exit 1
            build_core_sdk
            echo ""
            build_cli
            echo ""
            build_fixtures
            echo ""
            generate_python_bindings
            echo ""
            log_ok "构建完成！"
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
