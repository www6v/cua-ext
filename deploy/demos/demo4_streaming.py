#!/usr/bin/env python3
"""
Demo 4: 桌面流式传输
====================

演示内容:
- 连接 cua-spacesd
- 启动桌面视频流（H.264）
- 捕获帧并保存

运行方式:
    source .venv/bin/activate
    python demos/demo4_streaming.py

需要:
- Docker 运行中
- cua SDK 已安装
- 沙箱中有桌面环境

注意:
这是一个高级 Demo，展示了 Cua 的实时流媒体能力。
流式传输使用 H.264 视频和 Opus 音频编码。
"""

import asyncio
import json
import os
import sys
import time
from pathlib import Path

# ─── 工具函数 ────────────────────────────────────────

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

async def demo_streaming_basic():
    """
    基础流式传输演示。

    连接到沙箱的 cua-spacesd，获取截图序列，
    展示实时桌面捕获能力。
    """

    try:
        from cua import Sandbox, Image
    except ImportError:
        print("❌ cua SDK 未安装。请运行: bash 04-setup-python-env.sh")
        sys.exit(1)

    print_header("Demo 4: 桌面流式传输")

    print("本 Demo 展示 Cua 的桌面流式传输能力。")
    print("将创建沙箱，定期截图，模拟流式传输效果。")

    # 输出目录
    output_dir = Path(os.environ.get("DEMO4_OUTPUT_DIR", "/tmp/cua-demo4-streaming"))
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n   输出目录: {output_dir}")

    # ─── 步骤 1: 创建沙箱 ────────────────────────────
    print_step(1, "创建带桌面环境的沙箱")

    async with Sandbox.ephemeral(Image.linux(), local=True) as sb:
        print("   ✅ 沙箱创建成功")

        # 检查桌面环境
        print("   检查桌面环境...")
        result = await sb.shell.run("echo $DISPLAY")
        display = result.stdout.decode().strip()
        if display:
            print(f"   ✅ DISPLAY={display}")
        else:
            print("   ⚠️  无 DISPLAY 环境变量（可能没有桌面）")
            print("   将使用截图 API 代替")

        # ─── 步骤 2: 开始截图序列 ────────────────────
        print_step(2, "开始截图序列（模拟流式传输）")

        stream_seconds = int(os.environ.get("DEMO4_STREAM_SECONDS", "5"))
        interval = 0.5  # 每 0.5 秒截图一次
        num_frames = int(stream_seconds / interval)

        print(f"   时长: {stream_seconds}s")
        print(f"   间隔: {interval}s")
        print(f"   预期帧数: {num_frames}")
        print()

        frames_captured = 0
        total_bytes = 0
        start_time = time.time()

        for i in range(num_frames):
            frame_start = time.time()

            try:
                # 截图
                screenshot = await sb.screenshot()

                # 保存帧
                frame_path = output_dir / f"frame_{i:04d}.png"
                frame_path.write_bytes(screenshot)

                frames_captured += 1
                total_bytes += len(screenshot)

                # 进度显示
                elapsed = time.time() - start_time
                fps = frames_captured / elapsed if elapsed > 0 else 0
                print(f"\r   帧 {frames_captured}/{num_frames} | "
                      f"{fps:.1f} fps | "
                      f"{len(screenshot)/1024:.0f} KB | "
                      f"{elapsed:.1f}s", end="", flush=True)

            except Exception as e:
                print(f"\n   ⚠️  帧 {i} 截图失败: {e}")

            # 等待下一帧
            frame_time = time.time() - frame_start
            sleep_time = max(0, interval - frame_time)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

        total_time = time.time() - start_time
        print()  # 换行

        # ─── 步骤 3: 统计信息 ────────────────────────
        print_step(3, "流式传输统计")

        print(f"   捕获帧数: {frames_captured}")
        print(f"   总时间: {total_time:.1f}s")
        print(f"   平均帧率: {frames_captured / total_time:.1f} fps")
        print(f"   总数据量: {total_bytes / 1024 / 1024:.1f} MB")
        print(f"   平均帧大小: {total_bytes / frames_captured / 1024:.0f} KB")

        # ─── 步骤 4: 检查帧文件 ──────────────────────
        print_step(4, "检查保存的帧文件")

        frame_files = sorted(output_dir.glob("frame_*.png"))
        print(f"   帧文件数: {len(frame_files)}")

        if frame_files:
            first = frame_files[0]
            last = frame_files[-1]
            print(f"   第一帧: {first.name} ({first.stat().st_size / 1024:.0f} KB)")
            print(f"   最后一帧: {last.name} ({last.stat().st_size / 1024:.0f} KB)")
            print(f"   输出目录: {output_dir}")

        # ─── 步骤 5: 生成摘要 ────────────────────────
        print_step(5, "生成摘要")

        summary = {
            "frames_captured": frames_captured,
            "total_time_seconds": round(total_time, 2),
            "average_fps": round(frames_captured / total_time, 1),
            "total_bytes": total_bytes,
            "average_frame_bytes": total_bytes // frames_captured if frames_captured else 0,
            "output_dir": str(output_dir),
        }

        summary_path = output_dir / "summary.json"
        summary_path.write_text(json.dumps(summary, indent=2))
        print(f"   摘要已保存: {summary_path}")

        # ─── 步骤 6: 清理 ────────────────────────────
        print_step(6, "清理")

        # 保留帧文件供用户查看
        print(f"   帧文件保留在: {output_dir}")
        print("   如需清理: rm -rf " + str(output_dir))

    print(f"\n   ✅ 沙箱已自动销毁")


async def demo_streaming_info():
    """
    展示流式传输的更多信息。

    如果 SDK 支持，可以获取编码参数、媒体能力等。
    """

    print_header("Demo 4 补充: 流式传输能力查询")

    try:
        from cua import Sandbox, Image
    except ImportError:
        print("❌ cua SDK 未安装")
        return

    async with Sandbox.ephemeral(Image.linux(), local=True) as sb:
        # 查询 spacesd 能力
        print("   查询 spacesd 能力...")

        try:
            env = await sb.spacesd(None)
            caps = await env.get_capabilities()
            print(f"   能力: {caps}")
        except Exception as e:
            print(f"   ⚠️  无法查询能力: {e}")

        # 检查媒体支持
        print("\n   检查媒体支持...")
        result = await sb.shell.run("which ffmpeg 2>/dev/null && ffmpeg -version 2>&1 | head -1 || echo 'ffmpeg not found'")
        print(f"   {result.stdout.decode().strip()}")


def main():
    """主入口"""
    import argparse

    parser = argparse.ArgumentParser(description="Demo 4: 桌面流式传输")
    parser.add_argument(
        "--seconds",
        type=int,
        default=int(os.environ.get("DEMO4_STREAM_SECONDS", "5")),
        help="流式传输时长（秒）",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=os.environ.get("DEMO4_OUTPUT_DIR", "/tmp/cua-demo4-streaming"),
        help="输出目录",
    )
    parser.add_argument(
        "--info",
        action="store_true",
        help="仅显示流式传输能力信息",
    )
    args = parser.parse_args()

    # 设置环境变量
    os.environ["DEMO4_STREAM_SECONDS"] = str(args.seconds)
    os.environ["DEMO4_OUTPUT_DIR"] = args.output

    try:
        if args.info:
            asyncio.run(demo_streaming_info())
        else:
            asyncio.run(demo_streaming_basic())
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
