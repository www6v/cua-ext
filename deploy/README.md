# Cua 项目部署与 Demo 指南

> 本目录包含 Cua 项目的自动化部署脚本和可运行 Demo。

## 快速开始

```bash
# 1. 安装系统依赖（需要 sudo 权限）
bash 01-install-system-deps.sh

# 2. 安装 cua CLI 和 cua-driver
bash 02-install-cua-cli.sh

# 3. （可选）从源码构建 Rust 核心 SDK
bash 03-build-rust-core.sh

# 4. 创建 Python 虚拟环境并安装依赖
bash 04-setup-python-env.sh

# 5. 运行所有 Demo
bash 05-run-all-demos.sh
```

## 脚本说明

| 脚本 | 功能 | 需要 sudo | 需要网络 |
|------|------|-----------|----------|
| `01-install-system-deps.sh` | 安装 Docker, protoc, pnpm, buf | ✅ | ✅ |
| `02-install-cua-cli.sh` | 安装 cua CLI + cua-driver | ❌ | ✅ |
| `03-build-rust-core.sh` | 从源码构建 Rust SDK | ❌ | ✅（首次） |
| `04-setup-python-env.sh` | 创建 venv + 安装 Python 包 | ❌ | ✅ |
| `05-run-all-demos.sh` | 运行所有 Demo | ❌ | ❌ |

## Demo 列表

| Demo | 文件 | 描述 | 需要 API Key | 需要 Docker |
|------|------|------|--------------|-------------|
| Demo 1 | `demos/demo1_sandbox_basic.py` | 创建沙箱，执行 shell 命令 | ❌ | ✅ |
| Demo 2 | `demos/demo2_bench_task.py` | 运行基准测试任务 | ❌ | ✅ |
| Demo 3 | `demos/demo3_agent_in_sandbox.py` | AI 代理在沙箱中执行任务 | ✅ | ✅ |
| Demo 4 | `demos/demo4_streaming.py` | 桌面流式传输 | ❌ | ✅ |

## 环境变量

复制 `configs/.env.example` 为 `.env` 并填写必要的 API Key：

```bash
cp configs/.env.example .env
# 编辑 .env 文件
```

## 系统要求

- **操作系统**: Linux x86_64 (Ubuntu 22.04+)
- **Rust**: 1.97.1+ (rustup 会自动下载)
- **Python**: 3.12+
- **Node.js**: 20+
- **Docker**: 24+ (用于沙箱容器)
- **磁盘空间**: 10GB+ 可用

## 故障排除

### Docker 权限问题
```bash
sudo usermod -aG docker $USER
newgrp docker  # 或重新登录
```

### protoc 未找到
```bash
sudo apt-get install -y protobuf-compiler
protoc --version
```

### Python 包安装失败
```bash
# 使用 --extra-index-url 指向 Cua wheels
uv pip install --extra-index-url https://wheels.cua.ai/simple cua
```

### Rust 构建失败
```bash
# 确保 protoc 已安装
protoc --version
# 清理并重建
cd ../cua-main/libs/cua && cargo clean && cargo build --release -p cua-sdk
```
