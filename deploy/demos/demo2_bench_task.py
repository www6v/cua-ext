#!/usr/bin/env python3
"""
Demo 2: Cua Bench 基准测试任务
==============================

演示内容:
- 使用 cua-bench 运行简单任务
- 展示沙箱创建 → 任务执行 → 评估 → 结果
- 无需 API Key（oracle 验证）

运行方式:
    source .venv/bin/activate
    python demos/demo2_bench_task.py

需要:
- Docker 运行中
- cua-bench 已安装
"""

import asyncio
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def print_header(title: str):
    print()
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)
    print()


def print_step(step: int, description: str):
    print(f"\n📌 步骤 {step}: {description}")
    print("-" * 40)


def check_cb_available():
    """检查 cb 命令是否可用"""
    try:
        result = subprocess.run(
            ["cb", "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def demo_bench_list():
    """列出可用的基准测试数据集"""
    print_step(1, "列出可用的基准测试数据集")

    try:
        result = subprocess.run(
            ["cb", "dataset", "list"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            print("   可用数据集:")
            for line in result.stdout.strip().split("\n")[:10]:
                if line.strip():
                    print(f"   • {line.strip()}")
            return True
        else:
            print(f"   ⚠️  cb dataset list 返回错误: {result.stderr[:200]}")
            return False
    except Exception as e:
        print(f"   ⚠️  无法列出数据集: {e}")
        return False


def demo_bench_run_simple():
    """运行最简单的基准测试任务"""
    print_step(2, "运行 hello_file_env 任务（最简单的任务）")

    print("   任务描述: 在文件中写入一个单词")
    print("   验证方式: 检查文件内容是否匹配")
    print()

    start_time = time.time()

    try:
        # 运行任务
        result = subprocess.run(
            ["cb", "run", "example_tasks/hello_file_env"],
            capture_output=True,
            text=True,
            timeout=120,
            env={**os.environ, "CUA_TELEMETRY_ENABLED": "false"},
        )

        elapsed = time.time() - start_time

        print(f"   执行时间: {elapsed:.1f}s")
        print(f"   退出码: {result.returncode}")

        if result.stdout:
            # 输出最后几行
            lines = result.stdout.strip().split("\n")
            print(f"\n   输出（最后 10 行）:")
            for line in lines[-10:]:
                print(f"   {line}")

        if result.returncode == 0:
            print("\n   ✅ 任务执行成功！")
            return True
        else:
            print(f"\n   ⚠️  任务执行返回非零退出码")
            if result.stderr:
                print(f"   错误: {result.stderr[:500]}")
            return False

    except subprocess.TimeoutExpired:
        print("   ⚠️  任务超时（120s）")
        return False
    except Exception as e:
        print(f"   ⚠️  运行失败: {e}")
        return False


def demo_bench_dry_run():
    """展示 dry-run 模式"""
    print_step(3, "Dry-run 模式（仅显示计划，不实际运行）")

    try:
        result = subprocess.run(
            ["cb", "run", "example_tasks/hello_file_env", "--dry-run"],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "CUA_TELEMETRY_ENABLED": "false"},
        )

        if result.stdout:
            print("   执行计划:")
            for line in result.stdout.strip().split("\n")[:15]:
                if line.strip():
                    print(f"   {line}")
        return True
    except Exception as e:
        print(f"   ⚠️  dry-run 失败: {e}")
        return False


def demo_bench_python_api():
    """使用 Python API 运行基准测试"""
    print_step(4, "使用 Python API（如果可用）")

    try:
        # 尝试导入 cua_bench
        from cua_bench import run_task
        print("   ✅ cua_bench 模块可用")

        # 注意：实际的 API 调用可能需要根据版本调整
        print("   （Python API 的详细用法请参考官方文档）")
        return True

    except ImportError:
        print("   ⚠️  cua_bench 模块不可直接导入")
        print("   请使用 CLI 命令 'cb run ...' 运行基准测试")
        return False


def demo_show_results():
    """展示如何查看结果"""
    print_step(5, "查看运行结果")

    # 结果目录
    results_dir = Path.home() / ".local" / "share" / "cua-bench" / "runs"

    if results_dir.exists():
        runs = sorted(results_dir.iterdir(), reverse=True)[:5]
        if runs:
            print(f"   最近的运行结果（{results_dir}）:")
            for run_dir in runs:
                summary_file = run_dir / "summary.json"
                if summary_file.exists():
                    try:
                        summary = json.loads(summary_file.read_text())
                        status = "✅" if summary.get("stats", {}).get("pass", 0) > 0 else "❌"
                        print(f"   {status} {run_dir.name}")
                    except Exception:
                        print(f"   • {run_dir.name}")
                else:
                    print(f"   • {run_dir.name} (无 summary)")
        else:
            print("   暂无运行结果")
    else:
        print(f"   结果目录不存在: {results_dir}")
        print("   运行 'cb run ...' 后结果会保存在此")


def main():
    print_header("Demo 2: Cua Bench 基准测试")

    print("本 Demo 展示如何使用 Cua Bench 运行计算机使用基准测试。")
    print("最简单的任务 (hello_file_env) 只需创建一个文件，无需 AI 模型。")

    # 检查 cb 命令
    if not check_cb_available():
        print("\n❌ cb 命令不可用。请确保已运行:")
        print("   bash 04-setup-python-env.sh")
        print("   source .venv/bin/activate")
        sys.exit(1)

    print("\n✅ cb 命令可用")

    # 运行各个演示
    demo_bench_list()
    success = demo_bench_run_simple()
    demo_bench_dry_run()
    demo_bench_python_api()
    demo_show_results()

    # 总结
    print_header("Demo 2 完成" + (" ✅" if success else " ⚠️"))

    print("演示了以下能力:")
    print("  • 列出可用的基准测试数据集")
    print("  • 运行简单的 oracle 任务（无需 API Key）")
    print("  • Dry-run 模式预览执行计划")
    print("  • 查看运行结果")
    print()
    print("进一步探索:")
    print("  cb run example_tasks/test_click_env     # GUI 点击任务")
    print("  cb run example_tasks/basic_gui_env      # 基础 GUI 交互")
    print("  cb run datasets/cua-bench-basic         # 完整数据集")
    print("  cb run my_task --agent cua-agent --model anthropic/claude-sonnet-4-20250514")

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
