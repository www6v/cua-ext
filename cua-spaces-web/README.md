# Cua Spaces Web Demo 部署指南

## 📋 目录

- [项目简介](#项目简介)
- [快速开始](#快速开始)
- [系统要求](#系统要求)
- [部署方式](#部署方式)
- [运行 Demo](#运行-demo)
- [功能特性](#功能特性)
- [架构分析](#架构分析)
- [常见问题](#常见问题)

---

## 项目简介

**Cua Spaces Web** 是 Cua 项目的 Web UI 前端应用，提供了一个完整的图形界面来管理 AI 代理的桌面环境（Spaces）。

### 核心功能

- 🖥️ **Spaces 管理**：创建、启动、停止和删除虚拟桌面环境
- 🤖 **Agents 管理**：监控和管理 AI 代理的运行状态
- 🔐 **Keyvault**：安全存储和管理凭证
- 🌐 **Machines**：管理连接的计算资源
- ⚙️ **Settings**：配置应用设置和实验性功能
- 📺 **实时流媒体**：查看和操控远程桌面

### 技术栈

- **前端框架**: React 19 + TypeScript
- **构建工具**: Vite 8
- **路由**: TanStack Router
- **状态管理**: Zustand
- **样式**: Tailwind CSS 4
- **核心模块**: Rust WASM (可选)

---

## 快速开始

### 最简单的启动方式

```bash
# 1. 进入项目目录
cd cua-main/apps/cua-spaces-web

# 2. 安装依赖
pnpm install --ignore-workspace

# 3. 启动开发服务器
pnpm dev
```

访问 http://localhost:5174 即可看到 Demo 界面！

### 使用部署脚本

```bash
# 完整部署（包含所有依赖检查和 WASM 构建）
cd cua-ext/cua-spaces-web
./scripts/deploy.sh

# 快速启动 Demo
./scripts/start-demo.sh
```

---

## 系统要求

### 必需

- **Node.js**: 18+ (推荐 20+)
- **pnpm**: 8+
- **操作系统**: Linux, macOS, Windows

### 可选（用于完整功能）

- **Rust**: stable 工具链
- **wasm-bindgen-cli**: 0.2.126
- **wasm32-unknown-unknown target**

**注意**: 没有 Rust 工具链时，Demo 模式会使用 TypeScript fallback，功能完全可用。

---

## 部署方式

### 方式 1: 开发模式（推荐用于学习和测试）

```bash
cd cua-main/apps/cua-spaces-web
pnpm dev
```

**特点**:
- 热重载（HMR）
- 源代码调试
- 自动刷新
- 端口: 5174

### 方式 2: 生产构建

```bash
# 构建生产版本
pnpm build

# 预览生产构建
pnpm preview
```

**输出**: `dist/` 目录，可部署到任何静态文件服务器

### 方式 3: 使用部署脚本

```bash
# 自动检测依赖并安装
./scripts/deploy.sh

# 自定义端口启动
./scripts/start-demo.sh --port 3000

# 跳过 WASM 构建（更快）
./scripts/start-demo.sh --no-wasm
```

---

## 运行 Demo

### Demo 模式参数

在 URL 中添加参数可以控制 Demo 的初始状态：

| 参数 | 说明 | 示例 |
|------|------|------|
| `?demo=fresh` | 未登录状态，显示 onboarding 流程 | `http://localhost:5174/?demo=fresh` |
| `?demo=locked` | Keyvault 锁定状态 | `http://localhost:5174/?demo=locked` |
| `?demo=fresh,locked` | 组合：未登录 + Keyvault 锁定 | `http://localhost:5174/?demo=fresh,locked` |
| `?bridge=demo` | 强制使用 demo 模式（在真实 host 中） | `http://localhost:5174/?bridge=demo` |

### Demo 数据

Demo 模式使用内存数据，包含：

- **4 个持久化代理**: Claude Code, Codex, Hermes, OpenClaw
- **5 个运行中的代理会话**: 包括一个实时写入的会话（run-ada-7）
- **Spaces 示例**: 展示不同状态的 Space
- **Keyvault 示例**: 展示凭证管理界面
- **Machines 示例**: 展示连接的设备

### 主要页面

| 路由 | 页面 | 功能 |
|------|------|------|
| `/` | 主页 | Spaces 列表和管理 |
| `/machines` | Machines | 计算资源管理 |
| `/agents` | Agents | AI 代理管理 |
| `/keyvault` | Keyvault | 凭证管理 |
| `/settings` | Settings | 应用设置 |
| `/onboarding` | Onboarding | 首次使用引导 |
| `/notifications` | Notifications | 通知中心 |

---

## 功能特性

### Spaces 管理

- **创建 Space**: 支持多种操作系统（macOS, Linux, Windows）
- **生命周期管理**: 启动、停止、删除
- **实时监控**: 查看 Space 状态和资源使用
- **流媒体查看**: 实时查看和操控远程桌面
- **图片即代码**: PiP (画中画) 模式

### Agents 管理

- **持久化代理**: 查看和管理已配置的代理
- **运行监控**: 实时查看代理执行状态
- **对话时间线**: 查看代理的对话历史
- **暂停/恢复**: 控制代理执行
- **内存和例行程序**: 管理代理的长期记忆和自动化任务

### Keyvault（凭证保险库）

- **安全存储**: 加密存储应用凭证
- **分组管理**: 按应用和网站分组
- **访问控制**: 锁定/解锁，设置无人值守访问
- **审批流程**: 审批或拒绝凭证使用请求
- **授权管理**: 撤销已授予的访问权限

### Machines（计算资源）

- **本地机器**: 管理当前机器
- **远程机器**: 连接其他设备
- **配对码**: 通过二维码或链接添加机器
- **状态监控**: 查看机器在线状态和连接信息

### Settings（设置）

- **通用设置**: 主题、菜单栏、快捷键
- **设备管理**: 查看和管理连接的设备
- **实验性功能**: 启用/禁用实验特性
- **存储设置**: Cua Volume 配置
- **登录项**: 开机自启动配置

---

## 架构分析

### 整体架构

```
┌─────────────────────────────────────────────────────┐
│                    Web UI (React)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  Routes  │  │Components│  │  Hooks   │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       └──────────────┴──────────────┘               │
│                      │                              │
│              ┌───────┴────────┐                     │
│              │  Bridge Store  │                     │
│              └───────┬────────┘                     │
└──────────────────────┼──────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────┴────────┐           ┌────────┴────────┐
│   DataAdapter  │           │   App Core      │
│  (protocol.ts) │           │   (WASM/TS)     │
└───────┬────────┘           └─────────────────┘
        │
┌───────┴──────────────────────────────────┐
│              Host Adapters               │
│  ┌─────────┐  ┌──────────┐  ┌────────┐  │
│  │  Tauri  │  │ Electron │  │ WebKit │  │
│  └─────────┘  └──────────┘  └────────┘  │
│                                          │
│  ┌─────────┐                             │
│  │  Demo   │  ← 内存数据，无需后端       │
│  └─────────┘                             │
└──────────────────────────────────────────┘
```

### Bridge 层

Bridge 是 Web UI 的核心抽象层，负责连接 UI 和不同的宿主环境。

**主要文件**:
- `src/bridge/index.ts` - 导出所有 hooks 和组件
- `src/bridge/store.ts` - 状态管理核心
- `src/bridge/protocol.ts` - 操作协议定义
- `src/bridge/detect.ts` - 自动检测宿主环境
- `src/bridge/hooks.ts` - React hooks 集合

**支持的宿主**:
1. **Tauri**: 原生桌面应用
2. **Electron**: 跨平台桌面应用
3. **WebKit**: SwiftUI macOS 应用
4. **Demo**: 浏览器独立运行（内存数据）

### App Core

应用核心用 Rust 编写，编译为 WASM，提供：

- **状态派生**: 从原始数据派生 UI 状态
- **业务逻辑**: Space 创建、Keyvault 操作等
- **类型安全**: 与 TypeScript 共享类型定义

**无 WASM 时**: TypeScript fallback 提供 Demo 所需的基本功能

### 状态管理

使用 Zustand 进行状态管理：

```typescript
// 简化的 store 结构
const store = {
  spaces: Space[],
  machines: Machine[],
  agents: Agent[],
  settings: Settings,
  
  // Actions
  createSpace: (config) => Promise<void>,
  startSpace: (id) => Promise<void>,
  stopSpace: (id) => Promise<void>,
  // ...
}
```

### 路由系统

使用 TanStack Router，支持：

- **文件系统路由**: `src/routes/` 目录结构
- **类型安全**: 完整的类型推断
- **预加载**: 意图预加载（hover 时）
- **滚动恢复**: 记住滚动位置

---

## 目录结构

```
cua-spaces-web/
├── src/
│   ├── main.tsx                 # 应用入口
│   ├── index.css                # 全局样式
│   ├── routeTree.gen.ts         # 路由树（自动生成）
│   │
│   ├── routes/                  # 页面路由
│   │   ├── __root.tsx          # 根布局
│   │   ├── index.tsx           # 主页
│   │   ├── spaces/             # Spaces 相关页面
│   │   ├── machines/           # Machines 页面
│   │   ├── agents/             # Agents 页面
│   │   ├── keyvault/           # Keyvault 页面
│   │   ├── settings/           # Settings 页面
│   │   ├── onboarding/         # Onboarding 流程
│   │   └── notifications/      # 通知页面
│   │
│   ├── components/              # UI 组件
│   │   ├── ui/                 # 基础 UI 组件
│   │   ├── shell/              # 应用外壳
│   │   ├── space-detail/       # Space 详情组件
│   │   ├── video/              # 视频流组件
│   │   ├── viewer/             # 查看器组件
│   │   └── ...
│   │
│   ├── bridge/                  # Bridge 层（核心）
│   │   ├── index.ts            # 公共 API
│   │   ├── store.ts            # 状态管理
│   │   ├── hooks.ts            # React hooks
│   │   ├── protocol.ts         # 操作协议
│   │   ├── derive.ts           # 状态派生
│   │   ├── adapters/           # 宿主适配器
│   │   │   ├── demo.ts         # Demo 适配器
│   │   │   ├── tauri.ts        # Tauri 适配器
│   │   │   ├── electron.ts     # Electron 适配器
│   │   │   └── webkit.ts       # WebKit 适配器
│   │   ├── contracts/          # 类型合约
│   │   ├── core/               # WASM 核心
│   │   └── ops/                # 操作实现
│   │
│   ├── lib/                     # 工具库
│   │   ├── utils.ts
│   │   ├── theme.ts
│   │   └── ...
│   │
│   ├── hooks/                   # 全局 hooks
│   ├── stores/                  # 全局 stores
│   └── crash-reporting/         # 崩溃报告
│
├── scripts/
│   ├── build-core-wasm.mjs     # WASM 构建脚本
│   ├── screenshots.mjs         # 截图工具
│   └── perf.mjs                # 性能测试
│
├── e2e/                         # E2E 测试
│   ├── parity.spec.ts          # Parity 测试
│   └── ...
│
├── package.json
├── vite.config.ts
├── tsconfig.json
└── README.md
```

---

## 开发指南

### 添加新页面

1. 在 `src/routes/` 创建路由文件：

```typescript
// src/routes/my-page.tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/my-page')({
  component: MyPage,
})

function MyPage() {
  return <div>My Page</div>
}
```

2. 路由会自动生成到 `routeTree.gen.ts`

### 使用 Bridge Hooks

```typescript
import { useSpaces, useMachines, useAgents } from '@/bridge'

function MyComponent() {
  const { data: spaces, isLoading, error } = useSpaces()
  const { data: machines } = useMachines()
  const { data: agents } = useAgents()
  
  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>
  
  return (
    <div>
      {spaces.map(space => (
        <div key={space.id}>{space.name}</div>
      ))}
    </div>
  )
}
```

### 调用操作

```typescript
const { createSpace, startSpace } = useSpaces()

// 创建 Space
await createSpace({
  name: 'My Space',
  image: 'ubuntu:24.04',
  on: 'local'
})

// 启动 Space
await startSpace(spaceId)
```

---

## 常见问题

### Q: 为什么没有 WASM 核心？

A: WASM 需要 Rust 工具链。Demo 模式使用 TypeScript fallback，功能完全可用。完整部署请安装 Rust 并运行 `pnpm core`。

### Q: 如何连接真实的 Space？

A: Demo 模式使用内存数据，无法连接真实后端。要连接真实 Space，需要：
1. 在 Electron 或 Tauri 环境中运行
2. 或使用 `cua` CLI 创建和管理 Space

### Q: 端口被占用怎么办？

A: 使用 `--port` 参数指定其他端口：

```bash
pnpm dev --port 3000
# 或
./scripts/start-demo.sh --port 3000
```

### Q: 如何构建生产版本？

A: 

```bash
pnpm build
```

输出在 `dist/` 目录，可部署到任何静态文件服务器。

### Q: 支持哪些浏览器？

A: 
- Chrome 90+
- Firefox 88+
- Safari 15+
- Edge 90+

### Q: 如何查看日志？

A: 打开浏览器开发者工具（F12），查看 Console 面板。

---

## 相关资源

- **项目文档**: `cua-main/README.md`
- **开发指南**: `cua-main/Development.md`
- **测试指南**: `cua-main/TESTING.md`
- **Bridge 架构**: `src/bridge/README.md`
- **流式传输示例**: `cua-main/examples/streaming/`

---

## 许可证

FSL-1.1-MIT (Functional Source License)

- ✅ 免费使用
- ✅ 自托管
- ✅ 修改和分发
- ❌ 不可作为竞争性托管服务提供
- ✅ 2 年后自动转为 MIT

---

## 贡献

欢迎贡献！请参阅 `cua-main/.github/CONTRIBUTING.md`。

---

**最后更新**: 2026-10-26
