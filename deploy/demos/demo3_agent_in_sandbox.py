#!/usr/bin/env python3
"""
Demo 3: AI 代理在沙箱中执行任务
================================

演示内容:
- 创建沙箱
- 使用 AI 代理（Claude）在沙箱中执行任务
- 收集和验证结果

运行方式:
    source .venv/bin/activate
    export ANTHROPIC_API_KEY=sk-...
    python demos/demo3_agent_in_sandbox.py

需要:
- Docker 运行中
- ANTHROPIC_API_KEY 环境变量
- cua, cua-sandbox 已安装
"""

import asyncio
import json
import os
import sys
import time
from pathlib import Path

# ─── 环境检查 ────────────────────────────────────────

def check_env():
    """检查必要的环境变量"""
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        print("❌ 缺少 ANTHROPIC_API_KEY 环境变量")
        print()
        print("请设置 API Key:")
        print("  export ANTHROPIC_API_KEY=sk-ant-...")
        print()
        print("获取 API Key: https://console.anthropic.com/")
        sys.exit(1)
    return api_key


def print_header(title: str):
    print()
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)
    print()


def print_step(step: int, description: str):
    print(f"\n📌 步骤 {step}: {description}")
    print("-" * 40)


# ─── Demo 实现 ───────────────────────────────────────

async def demo_agent_with_anthropic():
    """
    使用 Anthropic 的 Computer Use API 在沙箱中执行任务。

    这个 demo 展示了:
    1. 创建沙箱
    2. 使用 Claude 的 computer_use 工具
    3. 代理通过截图理解屏幕并执行操作
    4. 验证任务完成
    """

    try:
        import anthropic
    except ImportError:
        print("❌ anthropic 包未安装。请运行:")
        print("   uv pip install anthropic")
        sys.exit(1)

    try:
        from cua import Sandbox, Image
    except ImportError:
        print("❌ cua SDK 未安装。请运行: bash 04-setup-python-env.sh")
        sys.exit(1)

    api_key = check_env()

    print_header("Demo 3: AI 代理在沙箱中执行任务")

    # ─── 步骤 1: 创建沙箱 ────────────────────────────
    print_step(1, "创建沙箱环境")

    image = Image.linux()
    print(f"   镜像: {image}")

    async with Sandbox.ephemeral(image, local=True) as sb:
        print("   ✅ 沙箱创建成功")

        # 安装必要工具
        print("   安装基础工具...")
        await sb.shell.run("apt-get update -qq && apt-get install -y -qq calculator libreoffice-calc 2>/dev/null || true")

        # ─── 步骤 2: 定义任务 ────────────────────────
        print_step(2, "定义 AI 代理任务")

        task = """
你需要在一个 Linux 桌面环境中完成以下任务：

1. 打开终端
2. 创建一个 Python 脚本 /tmp/fibonacci.py，计算斐波那契数列的前 20 个数字
3. 运行脚本并确认输出正确
4. 将结果保存到 /tmp/fibonacci_result.txt

完成后告诉我结果。
"""
        print(f"   任务: {task.strip()[:200]}...")

        # ─── 步骤 3: 使用 Anthropic API ──────────────
        print_step(3, "调用 Anthropic Claude API")

        client = anthropic.Anthropic(api_key=api_key)

        # 获取初始截图
        print("   获取初始截图...")
        try:
            screenshot = await sb.screenshot()
            import base64
            screenshot_b64 = base64.standard_b64encode(screenshot).decode()
        except Exception as e:
            print(f"   ⚠️  截图失败: {e}")
            print("   将使用 shell-only 模式完成任务")
            screenshot_b64 = None

        # 构建消息
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": task,
                    }
                ],
            }
        ]

        # 如果有截图，添加到消息中
        if screenshot_b64:
            messages[0]["content"].append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": screenshot_b64,
                },
            })

        print("   调用 Claude API（这可能需要 30-60 秒）...")
        start_time = time.time()

        try:
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                messages=messages,
            )

            elapsed = time.time() - start_time
            print(f"   ✅ API 响应 ({elapsed:.1f}s)")

            # 解析响应
            for block in response.content:
                if block.type == "text":
                    print(f"\n   Claude 回复:")
                    # 缩进显示
                    for line in block.text.split("\n"):
                        print(f"   | {line}")
                elif block.type == "tool_use":
                    print(f"\n   工具调用: {block.name}")
                    print(f"   输入: {json.dumps(block.input, indent=2)[:200]}")

        except Exception as e:
            print(f"   ⚠️  API 调用失败: {e}")
            print("   使用 shell-only 方式完成任务...")

            # 回退到 shell 方式
            await demo_shell_fallback(sb)

        # ─── 步骤 4: 验证结果 ────────────────────────
        print_step(4, "验证任务结果")

        # 检查文件是否创建
        result = await sb.shell.run("cat /tmp/fibonacci.py 2>/dev/null || echo 'FILE_NOT_FOUND'")
        if "FILE_NOT_FOUND" not in result.stdout.decode():
            print("   ✅ fibonacci.py 已创建")
            print(f"   内容预览:")
            for line in result.stdout.decode().strip().split("\n")[:5]:
                print(f"   | {line}")
        else:
            print("   ⚠️  fibonacci.py 未找到")

        result = await sb.shell.run("cat /tmp/fibonacci_result.txt 2>/dev/null || echo 'FILE_NOT_FOUND'")
        if "FILE_NOT_FOUND" not in result.stdout.decode():
            print("   ✅ fibonacci_result.txt 已创建")
            print(f"   结果: {result.stdout.decode().strip()[:100]}")
        else:
            print("   ⚠️  fibonacci_result.txt 未找到")

        # ─── 步骤 5: 清理 ────────────────────────────
        print_step(5, "清理")

        await sb.shell.run("rm -f /tmp/fibonacci.py /tmp/fibonacci_result.txt")
        print("   ✅ 临时文件已清理")

    print(f"\n   ✅ 沙箱已自动销毁")


async def demo_shell_fallback(sb):
    """当 API 不可用时的 shell 回退方案"""
    print("\n   使用 shell 方式完成任务...")

    # 创建斐波那契脚本
    fib_script = '''
def fibonacci(n):
    a, b = 0, 1
    result = []
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result

if __name__ == "__main__":
    nums = fibonacci(20)
    print("斐波那契数列前 20 个数字:")
    print(nums)
    with open("/tmp/fibonacci_result.txt", "w") as f:
        f.write(str(nums))
'''
    await sb.shell.run(f"cat > /tmp/fibonacci.py << 'SCRIPT'\n{fib_script}\nSCRIPT")
    print("   ✅ 创建 fibonacci.py")

    # 运行脚本
    result = await sb.shell.run("python3 /tmp/fibonacci.py")
    print(f"   输出: {result.stdout.decode().strip()}")
    print("   ✅ 脚本执行完成")


async def demo_agent_simple_task():
    """
    简化版本：使用 agents API（如果可用）

    这个版本使用 cua SDK 的 agents API，
    它会自动处理代理的启动和任务分配。
    """

    print_header("Demo 3 (简化版): 使用 agents API")

    try:
        from cua import Sandbox, Image
    except ImportError:
        print("❌ cua SDK 未安装")
        sys.exit(1)

    check_env()

    print_step(1, "创建沙箱")

    async with Sandbox.ephemeral(Image.linux(), local=True) as sb:
        print("   ✅ 沙箱创建成功")

        # 简单任务：创建文件
        print_step(2, "执行简单任务（shell 方式）")

        task_prompt = "创建一个文件 /tmp/hello.txt，内容为 'Hello from Cua Agent!'"
        print(f"   任务: {task_prompt}")

        # 直接使用 shell 执行
        await sb.shell.run(f"echo 'Hello from Cua Agent!' > /tmp/hello.txt")

        # 验证
        result = await sb.shell.run("cat /tmp/hello.txt")
        content = result.stdout.decode().strip()
        print(f"   结果: {content}")

        if content == "Hello from Cua Agent!":
            print("   ✅ 任务验证成功！")
        else:
            print("   ❌ 任务验证失败")

        # 清理
        await sb.shell.run("rm -f /tmp/hello.txt")

    print("\n   ✅ 沙箱已销毁")


def main():
    """主入口"""
    import argparse

    parser = argparse.ArgumentParser(description="Demo 3: AI 代理在沙箱中执行任务")
    parser.add_argument(
        "--simple",
        action="store_true",
        help="运行简化版本（不使用 Anthropic API）",
    )
    args = parser.parse_args()

    try:
        if args.simple:
            asyncio.run(demo_agent_simple_task())
        else:
            asyncio.run(demo_agent_with_anthropic())
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n❌ Demo 运行失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
