#!/usr/bin/env bash
# 05-run-all-demos.sh — 运行所有 Cua Demo
#
# 用法:
#   bash 05-run-all-demos.sh          # 运行所有 Demo
#   bash 05-run-all-demos.sh 1        # 仅运行 Demo 1
#   bash 05-run-all-demos.sh 1 3      # 运行 Demo 1 和 3
#   bash 05-run-all-demos.sh --check  # 检查环境是否就绪

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$DEPLOY_DIR/.venv"
DEMOS_DIR="$DEPLOY_DIR/demos"

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_demo()  { echo -e "${CYAN}[DEMO]${NC} $*"; }

show_help() {
    cat <<'EOF'
运行 Cua Demo

用法:
  bash 05-run-all-demos.sh          运行所有 Demo
  bash 05-run-all-demos.sh 1        仅运行 Demo 1
  bash 05-run-all-demos.sh 1 3      运行 Demo 1 和 3
  bash 05-run-all-demos.sh --check  检查环境是否就绪
  bash 05-run-all-demos.sh --list   列出所有 Demo

可用 Demo:
  1 - 沙箱基础操作（创建沙箱、执行命令、文件操作）
  2 - 基准测试任务（运行 hello_file_env）
  3 - AI 代理任务（需要 ANTHROPIC_API_KEY）
  4 - 桌面流式传输（截图序列）

前置条件:
  1. 运行过 01-install-system-deps.sh
  2. 运行过 02-install-cua-cli.sh（可选）
  3. 运行过 04-setup-python-env.sh
  4. Docker 运行中
EOF
}

# ─── 环境检查 ────────────────────────────────────────

check_env() {
    local failed=0
    echo ""
    echo "=========================================="
    echo "  检查 Demo 运行环境"
    echo "=========================================="
    echo ""

    # Python venv
    if [[ -d "$VENV_DIR" ]]; then
        log_ok "Python 虚拟环境: $VENV_DIR"
    else
        log_error "Python 虚拟环境不存在"
        log_info "请运行: bash 04-setup-python-env.sh"
        ((failed++))
    fi

    # Docker
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        log_ok "Docker: $(docker --version 2>&1 | head -1)"
    else
        log_error "Docker 不可用"
        log_info "请运行: bash 01-install-system-deps.sh"
        ((failed++))
    fi

    # Python 包
    if [[ -d "$VENV_DIR" ]]; then
        source "$VENV_DIR/bin/activate"

        if python -c "import cua" 2>/dev/null; then
            log_ok "cua SDK: 已安装"
        else
            log_error "cua SDK: 未安装"
            ((failed++))
        fi

        if command -v cb &>/dev/null; then
            log_ok "cua-bench: 已安装"
        else
            log_warn "cua-bench: 未安装（Demo 2 需要）"
        fi

        deactivate 2>/dev/null || true
    fi

    # Demo 3 需要 API Key
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_ok "ANTHROPIC_API_KEY: 已设置"
    else
        log_warn "ANTHROPIC_API_KEY: 未设置（Demo 3 需要）"
    fi

    # cua CLI（可选）
    if command -v cua &>/dev/null; then
        log_ok "cua CLI: $(cua --version 2>&1)"
    else
        log_warn "cua CLI: 未安装（可选）"
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_ok "环境检查通过！可以运行 Demo。"
        return 0
    else
        log_error "$failed 个必要条件缺失"
        return 1
    fi
}

list_demos() {
    echo ""
    echo "=========================================="
    echo "  可用 Demo 列表"
    echo "=========================================="
    echo ""
    echo "  1  沙箱基础操作"
    echo "     创建容器沙箱，执行 shell 命令，文件操作"
    echo "     需要: Docker, cua SDK"
    echo ""
    echo "  2  基准测试任务"
    echo "     运行 hello_file_env，验证 oracle 结果"
    echo "     需要: Docker, cua-bench"
    echo ""
    echo "  3  AI 代理任务"
    echo "     使用 Claude 在沙箱中执行编程任务"
    echo "     需要: Docker, ANTHROPIC_API_KEY"
    echo "     选项: --simple（不需要 API Key）"
    echo ""
    echo "  4  桌面流式传输"
    echo "     截图序列，模拟流式传输"
    echo "     需要: Docker, cua SDK"
    echo ""
}

# ─── Demo 运行函数 ──────────────────────────────────

run_demo_1() {
    log_demo "Demo 1: 沙箱基础操作"
    source "$VENV_DIR/bin/activate"
    python "$DEMOS_DIR/demo1_sandbox_basic.py"
    local exit_code=$?
    deactivate 2>/dev/null || true
    return $exit_code
}

run_demo_2() {
    log_demo "Demo 2: 基准测试任务"
    source "$VENV_DIR/bin/activate"
    python "$DEMOS_DIR/demo2_bench_task.py"
    local exit_code=$?
    deactivate 2>/dev/null || true
    return $exit_code
}

run_demo_3() {
    log_demo "Demo 3: AI 代理任务"

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        log_warn "ANTHROPIC_API_KEY 未设置，使用 --simple 模式"
        source "$VENV_DIR/bin/activate"
        python "$DEMOS_DIR/demo3_agent_in_sandbox.py" --simple
    else
        source "$VENV_DIR/bin/activate"
        python "$DEMOS_DIR/demo3_agent_in_sandbox.py"
    fi

    local exit_code=$?
    deactivate 2>/dev/null || true
    return $exit_code
}

run_demo_4() {
    log_demo "Demo 4: 桌面流式传输"
    source "$VENV_DIR/bin/activate"
    python "$DEMOS_DIR/demo4_streaming.py" --seconds 3
    local exit_code=$?
    deactivate 2>/dev/null || true
    return $exit_code
}

# ─── 主入口 ─────────────────────────────────────────

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --check)
            check_env
            exit $?
            ;;
        --list)
            list_demos
            exit 0
            ;;
        "")
            # 运行所有 Demo
            echo ""
            echo "╔══════════════════════════════════════════════════════╗"
            echo "║          Cua Demo 全套运行                         ║"
            echo "╚══════════════════════════════════════════════════════╝"
            echo ""

            check_env || {
                log_error "环境检查失败。请先完成前置步骤。"
                exit 1
            }

            local results=()
            local total=4
            local passed=0

            for i in 1 2 3 4; do
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                if "run_demo_$i"; then
                    results+=("✅ Demo $i: 成功")
                    ((passed++))
                else
                    results+=("❌ Demo $i: 失败")
                fi
            done

            # 汇总
            echo ""
            echo "╔══════════════════════════════════════════════════════╗"
            echo "║  运行结果汇总"
            echo "╠══════════════════════════════════════════════════════╣"
            for r in "${results[@]}"; do
                echo "║  $r"
            done
            echo "╠══════════════════════════════════════════════════════╣"
            echo "║  通过: $passed / $total"
            echo "╚══════════════════════════════════════════════════════╝"
            echo ""
            ;;
        *)
            # 运行指定的 Demo
            for demo_num in "$@"; do
                case "$demo_num" in
                    1) run_demo_1 ;;
                    2) run_demo_2 ;;
                    3) run_demo_3 ;;
                    4) run_demo_4 ;;
                    *)
                        log_error "未知的 Demo 编号: $demo_num"
                        list_demos
                        exit 1
                        ;;
                esac
            done
            ;;
    esac
}

main "$@"
