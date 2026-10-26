#!/usr/bin/env python3
"""
Demo 1: Cua 沙箱基础操作
========================

演示内容:
- 创建本地 Linux 容器沙箱
- 执行 shell 命令
- 文件系统操作
- 环境信息收集
- 沙箱生命周期管理

运行方式:
    source .venv/bin/activate
    python demos/demo1_sandbox_basic.py

需要:
- Docker 运行中
- cua / cua-sandbox 已安装
"""

import asyncio
import json
import os
import sys
import time
from pathlib import Path

# 尝试导入 cua SDK
try:
    from cua import Sandbox, Image
except ImportError:
    print("❌ cua SDK 未安装。请先运行: bash 04-setup-python-env.sh")
    print("   然后激活环境: source .venv/bin/activate")
    sys.exit(1)


def print_header(title: str):
    """打印标题"""
    print()
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)
    print()


def print_step(step: int, description: str):
    """打印步骤"""
    print(f"\n📌 步骤 {step}: {description}")
    print("-" * 40)


async def demo_sandbox_basic():
    """沙箱基础操作演示"""

    print_header("Demo 1: Cua 沙箱基础操作")

    # ─── 步骤 1: 创建沙箱 ────────────────────────────
    print_step(1, "创建本地 Linux 容器沙箱")

    image = Image.linux()
    print(f"   镜像: {image}")

    start_time = time.time()

    async with Sandbox.ephemeral(image, local=True) as sb:
        create_time = time.time() - start_time
        print(f"   ✅ 沙箱创建成功 ({create_time:.1f}s)")

        # ─── 步骤 2: 系统信息 ────────────────────────
        print_step(2, "收集系统信息")

        # uname -a
        result = await sb.shell.run("uname -a")
        print(f"   系统: {result.stdout.decode().strip()}")

        # CPU 信息
        result = await sb.shell.run("nproc")
        print(f"   CPU 核心数: {result.stdout.decode().strip()}")

        # 内存
        result = await sb.shell.run("free -h | grep Mem | awk '{print $2}'")
        print(f"   总内存: {result.stdout.decode().strip()}")

        # 磁盘
        result = await sb.shell.run("df -h / | tail -1 | awk '{print $4}'")
        print(f"   可用磁盘: {result.stdout.decode().strip()}")

        # ─── 步骤 3: 文件系统操作 ────────────────────
        print_step(3, "文件系统操作")

        # 创建目录
        await sb.shell.run("mkdir -p /tmp/cua-demo")
        print("   ✅ 创建目录 /tmp/cua-demo")

        # 写入文件
        await sb.shell.run("echo 'Hello from Cua Sandbox!' > /tmp/cua-demo/hello.txt")
        print("   ✅ 写入文件 hello.txt")

        # 读取文件
        result = await sb.shell.run("cat /tmp/cua-demo/hello.txt")
        print(f"   文件内容: {result.stdout.decode().strip()}")

        # 列出目录
        result = await sb.shell.run("ls -la /tmp/cua-demo/")
        print(f"   目录列表:\n{result.stdout.decode()}")

        # ─── 步骤 4: 运行程序 ────────────────────────
        print_step(4, "在沙箱中运行程序")

        # Python 脚本
        python_script = '''
import sys
import platform
import json

info = {
    "python_version": sys.version,
    "platform": platform.platform(),
    "architecture": platform.machine(),
    "cwd": __import__("os").getcwd(),
}
print(json.dumps(info, indent=2))
'''
        # 写入脚本
        await sb.shell.run(f"cat > /tmp/cua-demo/info.py << 'SCRIPT'\n{python_script}\nSCRIPT")

        # 运行脚本
        result = await sb.shell.run("python3 /tmp/cua-demo/info.py")
        info = json.loads(result.stdout.decode())
        print(f"   Python 版本: {info['python_version'].split()[0]}")
        print(f"   平台: {info['platform']}")
        print(f"   架构: {info['architecture']}")

        # ─── 步骤 5: 网络信息 ────────────────────────
        print_step(5, "网络信息")

        result = await sb.shell.run("hostname -I 2>/dev/null || echo 'N/A'")
        print(f"   IP 地址: {result.stdout.decode().strip()}")

        result = await sb.shell.run("cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -1")
        print(f"   DNS: {result.stdout.decode().strip()}")

        # ─── 步骤 6: 环境变量 ────────────────────────
        print_step(6, "沙箱环境变量")

        result = await sb.shell.run("env | sort | head -20")
        env_lines = result.stdout.decode().strip().split("\n")
        for line in env_lines[:10]:
            if "=" in line:
                key, _, value = line.partition("=")
                # 截断过长的值
                if len(value) > 40:
                    value = value[:40] + "..."
                print(f"   {key}={value}")
        if len(env_lines) > 10:
            print(f"   ... 共 {len(env_lines)} 个变量")

        # ─── 步骤 7: 截图（如有桌面环境）────────────
        print_step(7, "尝试截图（需要桌面环境）")

        try:
            screenshot = await sb.screenshot()
            screenshot_path = Path("/tmp/cua-demo/screenshot.png")
            screenshot_path.write_bytes(screenshot)
            print(f"   ✅ 截图已保存: {screenshot_path}")
            print(f"   截图大小: {len(screenshot) / 1024:.1f} KB")
        except Exception as e:
            print(f"   ⚠️  截图失败（可能没有桌面环境）: {e}")

        # ─── 步骤 8: 清理 ────────────────────────────
        print_step(8, "清理")

        await sb.shell.run("rm -rf /tmp/cua-demo")
        print("   ✅ 临时文件已清理")

    # Sandbox.ephemeral 退出时自动销毁沙箱
    print(f"\n   ✅ 沙箱已自动销毁")

    # ─── 总结 ────────────────────────────────────────
    print_header("Demo 1 完成 ✅")
    print("演示了以下能力:")
    print("  • 创建和销毁本地容器沙箱")
    print("  • 执行 shell 命令")
    print("  • 文件系统操作（创建、读写、列出）")
    print("  • 运行 Python 程序")
    print("  • 收集系统信息")
    print("  • 自动生命周期管理（ephemeral sandbox）")


def main():
    """主入口"""
    try:
        asyncio.run(demo_sandbox_basic())
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
