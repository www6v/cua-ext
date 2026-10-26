# Cua Spaces Web 快速参考

## 🚀 快速启动

```bash
# 最简单的方式
cd cua-main/apps/cua-spaces-web
pnpm install --ignore-workspace
pnpm dev
```

访问: http://localhost:5174

## 📝 Demo 模式参数

| URL | 说明 |
|-----|------|
| `http://localhost:5174/` | 默认 Demo（已登录） |
| `?demo=fresh` | 未登录，显示 onboarding |
| `?demo=locked` | Keyvault 锁定 |
| `?demo=fresh,locked` | 组合 |
| `?bridge=demo` | 强制 demo 模式 |

## 📂 主要页面

| 路由 | 页面 | 功能 |
|------|------|------|
| `/` | 主页 | Spaces 列表 |
| `/machines` | Machines | 设备管理 |
| `/agents` | Agents | AI 代理 |
| `/keyvault` | Keyvault | 凭证管理 |
| `/settings` | Settings | 设置 |
| `/onboarding` | Onboarding | 首次引导 |

## 🛠️ 常用命令

```bash
# 安装依赖
pnpm install --ignore-workspace

# 开发模式
pnpm dev

# 构建生产版本
pnpm build

# 预览生产版本
pnpm preview

# 类型检查
pnpm typecheck

# 运行测试
pnpm test

# 构建 WASM（需要 Rust）
pnpm core

# 截图所有路由
pnpm screenshots

# 性能测试
pnpm perf
```

## 📦 技术栈

- React 19
- TypeScript 7
- Vite 8
- TanStack Router
- Zustand
- Tailwind CSS 4
- Rust WASM (可选)

## 🔧 系统要求

**必需**:
- Node.js 18+
- pnpm 8+

**可选** (WASM):
- Rust stable
- wasm-bindgen-cli 0.2.126
- wasm32-unknown-unknown target

## 📖 文档

- [README.md](./README.md) - 部署指南
- [TECHNICAL-ANALYSIS.md](./TECHNICAL-ANALYSIS.md) - 技术分析

## 🎯 关键文件

| 文件 | 说明 |
|------|------|
| `src/main.tsx` | 应用入口 |
| `src/bridge/index.ts` | Bridge API |
| `src/bridge/hooks.ts` | React hooks |
| `src/bridge/store.ts` | 状态管理 |
| `src/bridge/protocol.ts` | 操作协议 |
| `src/bridge/adapters/demo.ts` | Demo 适配器 |

## 💡 常用 Hooks

```typescript
import { 
  useSpaces, 
  useMachines, 
  useAgents,
  useKeyvault,
  useSettings,
  useSession
} from '@/bridge'

// Spaces
const { data: spaces, createSpace, startSpace } = useSpaces()

// Machines
const { data: machines } = useMachines()

// Agents
const { data: agents, pauseAgent } = useAgents()

// Keyvault
const { data: keyvault, unlock } = useKeyvault()

// Settings
const { data: settings, updateSetting } = useSettings()
```

## 🐛 调试

```bash
# 打开开发者工具
F12 或 Cmd+Option+I (Mac)

# 查看 Bridge 状态
在控制台输入:
window.__CUA_BRIDGE__

# 查看路由信息
window.__TANSTACK_ROUTER__
```

## 📚 学习资源

- [React 文档](https://react.dev)
- [TanStack Router](https://tanstack.com/router)
- [Zustand 文档](https://docs.pmnd.rs/zustand)
- [Vite 文档](https://vitejs.dev)
- [Tailwind CSS](https://tailwindcss.com)

## ❓ 常见问题

**Q: 端口被占用？**
```bash
pnpm dev --port 3000
```

**Q: 没有 WASM？**
Demo 模式使用 TypeScript fallback，功能完全可用。

**Q: 如何连接真实后端？**
需要在 Electron 或 Tauri 环境中运行。

**Q: 构建失败？**
```bash
# 清理缓存
rm -rf node_modules dist
pnpm install --ignore-workspace
```

---

更多详情查看 [README.md](./README.md)
