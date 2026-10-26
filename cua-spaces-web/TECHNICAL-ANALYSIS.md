# Cua Spaces Web Demo 技术分析

## 📋 目录

- [概述](#概述)
- [核心架构](#核心架构)
- [Bridge 层深度解析](#bridge-层深度解析)
- [状态管理](#状态管理)
- [路由系统](#路由系统)
- [组件架构](#组件架构)
- [宿主适配器](#宿主适配器)
- [Demo 模式实现](#demo-模式实现)
- [性能优化](#性能优化)
- [安全考虑](#安全考虑)
- [扩展指南](#扩展指南)

---

## 概述

Cua Spaces Web 是一个现代化的 React 应用，采用了一系列先进技术来实现跨平台的桌面环境管理界面。

### 设计原则

1. **宿主无关性**: UI 代码不依赖于特定的宿主环境（Tauri/Electron/WebKit/Demo）
2. **类型安全**: 从 Rust 核心到 TypeScript UI，完整的类型链条
3. **状态派生**: 使用纯函数从原始数据派生 UI 状态
4. **可测试性**: Demo 模式使得无需真实后端即可测试 UI

### 技术选型理由

| 技术 | 选择理由 |
|------|----------|
| React 19 | 生态系统成熟，并发特性，Suspense |
| TypeScript | 类型安全，更好的 IDE 支持 |
| Vite | 快速的热重载，原生 ES 模块 |
| TanStack Router | 类型安全的路由，文件系统路由 |
| Zustand | 轻量级，简单，无 boilerplate |
| Tailwind CSS | 原子化 CSS，快速开发 |
| Rust + WASM | 性能关键路径，代码复用 |

---

## 核心架构

### 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Routes  │  │Components│  │   Hooks  │              │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘              │
└───────┼──────────────┼──────────────┼────────────────────┘
        │              │              │
┌───────┼──────────────┼──────────────┼────────────────────┐
│       └──────────────┴──────────────┘                    │
│                      Bridge Layer                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │  BridgeStore (Zustand)                             │ │
│  │  ├─ useSpaces()                                    │ │
│  │  ├─ useMachines()                                  │ │
│  │  ├─ useAgents()                                    │ │
│  │  ├─ useKeyvault()                                  │ │
│  │  └─ useSettings()                                  │ │
│  └────────────────────┬───────────────────────────────┘ │
│                       │                                 │
│  ┌────────────────────┴───────────────────────────────┐ │
│  │  DataAdapter (protocol.ts)                         │ │
│  │  - 统一的操作接口                                   │ │
│  │  - 事件订阅机制                                     │ │
│  └────────────────────┬───────────────────────────────┘ │
└───────────────────────┼──────────────────────────────────┘
                        │
┌───────────────────────┼──────────────────────────────────┐
│                       │      Adapter Layer               │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌─────────┐   │
│  │  Tauri  │  │ Electron │  │ WebKit  │  │  Demo   │   │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └────┬────┘   │
└───────┼────────────┼─────────────┼────────────┼──────────┘
        │            │             │            │
┌───────┼────────────┼─────────────┼────────────┼──────────┐
│       └────────────┴─────────────┴────────────┘         │
│                    Host / Backend                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │  App Core (Rust WASM / TypeScript fallback)      │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │  cua daemon / cua-spacesd                        │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

### 数据流

1. **用户操作** → 组件调用 hook action
2. **Hook action** → 调用 DataAdapter 方法
3. **DataAdapter** → 路由到对应的 Host Adapter
4. **Host Adapter** → 调用宿主 API（invoke/postMessage/native）
5. **宿主** → 执行操作，返回结果
6. **结果** → 沿调用链返回
7. **BridgeStore** → 更新状态
8. **React** → 重新渲染受影响的组件

### 事件流

```
宿主环境变化
    ↓
触发宿主事件（spaces:changed, keyvault.changed 等）
    ↓
Host Adapter 接收事件
    ↓
转换为统一的 HostEvent
    ↓
BridgeStore 处理事件
    ↓
重新获取相关数据
    ↓
更新状态
    ↓
React 重新渲染
```

---

## Bridge 层深度解析

Bridge 层是整个应用的核心抽象，它让 UI 代码完全不关心运行在哪个宿主环境中。

### BridgeProvider

```typescript
// src/bridge/BridgeProvider.tsx
export function BridgeProvider({ children }: { children: React.ReactNode }) {
  const mode = detectMode(window)  // 检测宿主环境
  const core = useCoreLoader(mode)  // 加载 WASM 核心
  
  return (
    <BridgeContext.Provider value={{ mode, core, data }}>
      {children}
    </BridgeContext.Provider>
  )
}
```

### 宿主检测

```typescript
// src/bridge/detect.ts
export function detectMode(win: HostWindow): BridgeMode {
  // 1. 检查是否强制使用 demo
  const forced = readForcedMode(win)
  if (forced) return forced
  
  // 2. 检测 Tauri
  if (win.__TAURI__ || win.__TAURI_INTERNALS__) return "tauri"
  
  // 3. 检测 Electron
  if (win.cuaDesktop && typeof win.cuaDesktop.invoke === "function") 
    return "electron"
  
  // 4. 检测 WebKit (SwiftUI)
  if (win.webkit?.messageHandlers?.cua) return "webkit"
  
  // 5. 默认使用 demo
  return "demo"
}
```

### DataAdapter 协议

```typescript
// src/bridge/protocol.ts
export interface DataAdapter {
  // Spaces 操作
  spaces: {
    list(): Promise<SpaceRow[]>
    create(config: CreateConfig, pendingId: string): Promise<SpaceRow>
    setPower(spaceId: string, on: boolean): Promise<void>
    delete(spaceId: string): Promise<void>
    open(spaceId: string): Promise<void>
  }
  
  // Machines 操作
  machines: {
    list(): Promise<MachineRow[]>
  }
  
  // Keyvault 操作
  keyvault: {
    overview(): Promise<KeyvaultOverview>
    unlock(passphrase?: string): Promise<void>
    setUnattended(itemIds: string[], unattended: boolean): Promise<void>
  }
  
  // Settings 操作
  settings: {
    get(): Promise<SettingsSnapshot>
    set(key: string, value: unknown): Promise<void>
  }
  
  // 事件订阅
  on(event: HostEvent, callback: () => void): () => void
}
```

### 状态派生

```typescript
// src/bridge/derive.ts
export function deriveSpaces(
  rows: SpaceRow[],
  creates: PendingCreate[],
  core: AppCore
): Space[] {
  // 1. 合并 pending creates
  const withPending = core.rowsToSpaces(rows, creates)
  
  // 2. 应用 power 变化
  const withPower = applyPowerChanges(withPending)
  
  // 3. 应用 delete 变化
  const withDelete = applyDeleteChanges(withPower)
  
  return withDelete
}
```

---

## 状态管理

### Zustand Store 结构

```typescript
// src/bridge/store.ts
interface BridgeStore {
  // 原始数据
  spaces: SpaceRow[]
  machines: MachineRow[]
  agents: PersistentAgent[]
  settings: SettingsSnapshot
  keyvault: KeyvaultOverview
  
  // 派生数据
  derivedSpaces: Space[]
  derivedMachines: Machine[]
  
  // 加载状态
  isLoading: {
    spaces: boolean
    machines: boolean
    agents: boolean
    settings: boolean
    keyvault: boolean
  }
  
  // 错误状态
  errors: {
    spaces?: Error
    machines?: Error
    agents?: Error
    settings?: Error
    keyvault?: Error
  }
  
  // Actions
  refreshSpaces(): Promise<void>
  refreshMachines(): Promise<void>
  refreshAgents(): Promise<void>
  refreshSettings(): Promise<void>
  refreshKeyvault(): Promise<void>
  
  // 操作
  createSpace(config: CreateConfig): Promise<void>
  startSpace(id: string): Promise<void>
  stopSpace(id: string): Promise<void>
  deleteSpace(id: string): Promise<void>
}
```

### 状态更新策略

1. **乐观更新**: 对于快速操作（如 start/stop），先更新 UI，后等待后端确认
2. **轮询**: 对于不支持事件的环境（如 Tauri），每 10 秒轮询一次
3. **事件驱动**: 优先使用宿主事件，实时更新状态
4. **缓存**: 避免重复请求，使用内存缓存

### 派生状态示例

```typescript
// 从 SpaceRow[] 派生 Space[]
function deriveSpaces(rows: SpaceRow[], creates: PendingCreate[]): Space[] {
  return rows.map(row => ({
    id: row.id,
    name: row.name,
    status: deriveStatus(row, creates),
    os: row.os,
    createdAt: row.createdAt,
    // ...
  }))
}

function deriveStatus(row: SpaceRow, creates: PendingCreate[]): SpaceStatus {
  // 1. 检查是否在创建中
  const creating = creates.find(c => c.spaceId === row.id)
  if (creating) return 'creating'
  
  // 2. 检查 power 状态
  if (row.power) return 'running'
  return 'stopped'
}
```

---

## 路由系统

### TanStack Router 配置

```typescript
// src/main.tsx
import { createRouter, RouterProvider } from '@tanstack/react-router'
import { routeTree } from './routeTree.gen'

const router = createRouter({
  routeTree,
  defaultPreload: 'intent',  // hover 时预加载
  scrollRestoration: true,   // 恢复滚动位置
})
```

### 文件系统路由

```
src/routes/
├── __root.tsx              # 根布局（所有页面共享）
├── index.tsx               # / (主页)
├── spaces/
│   ├── index.tsx           # /spaces
│   └── $spaceId.tsx        # /spaces/:spaceId
├── machines.tsx            # /machines
├── agents/
│   ├── index.tsx           # /agents
│   └── $agentName.tsx      # /agents/:agentName
├── keyvault.tsx            # /keyvault
├── settings.tsx            # /settings
└── onboarding.tsx          # /onboarding
```

### 路由参数

```typescript
// src/routes/spaces/$spaceId.tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/spaces/$spaceId')({
  component: SpaceDetail,
  validateSearch: (search) => ({
    dropped: search.dropped as string[] | undefined,
  }),
})

function SpaceDetail() {
  const { spaceId } = Route.useParams()
  const { dropped } = Route.useSearch()
  
  // ...
}
```

### 预加载策略

```typescript
// hover 链接时预加载路由
<Link to="/spaces/123" preload="intent">
  Space 123
</Link>

// 预加载数据
export const Route = createFileRoute('/spaces/$spaceId')({
  loader: async ({ params }) => {
    // 预加载 Space 详情
    return await fetchSpaceDetail(params.spaceId)
  },
})
```

---

## 组件架构

### 组件分层

```
┌─────────────────────────────────────┐
│         Page Components             │  # 路由组件，组织页面
│  (routes/*)                         │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│      Feature Components             │  # 功能组件，业务逻辑
│  (components/space-detail/*)        │
│  (components/keyvault/*)            │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│        UI Components                │  # 通用 UI 组件
│  (components/ui/*)                  │
│  Button, Card, Dialog, etc.         │
└─────────────────────────────────────┘
```

### Hook 使用模式

```typescript
// 1. 数据获取 hook
const { data: spaces, isLoading, error } = useSpaces()

// 2. 操作 hook
const { createSpace, deleteSpace } = useSpaces()

// 3. 订阅 hook
useEffect(() => {
  const unsubscribe = data.on('spaces.changed', () => {
    refresh()
  })
  return unsubscribe
}, [])
```

### 组件示例

```typescript
// Space 列表组件
function SpacesList() {
  const { data: spaces, isLoading } = useSpaces()
  const { startSpace, stopSpace } = useSpaces()
  
  if (isLoading) return <LoadingSpinner />
  
  return (
    <div className="space-y-4">
      {spaces.map(space => (
        <SpaceCard
          key={space.id}
          space={space}
          onStart={() => startSpace(space.id)}
          onStop={() => stopSpace(space.id)}
        />
      ))}
    </div>
  )
}
```

---

## 宿主适配器

### Demo 适配器

```typescript
// src/bridge/adapters/demo.ts
export class DemoAdapter implements DataAdapter {
  private spaces: SpaceRow[] = DEMO_SPACES
  private machines: MachineRow[] = DEMO_MACHINES
  
  async spaces_list(): Promise<SpaceRow[]> {
    // 模拟网络延迟
    await delay(100)
    return this.spaces
  }
  
  async spaces_create(config: CreateConfig): Promise<SpaceRow> {
    await delay(500)
    const newSpace: SpaceRow = {
      id: crypto.randomUUID(),
      name: config.name,
      // ...
    }
    this.spaces.push(newSpace)
    return newSpace
  }
  
  // ...
}
```

### Tauri 适配器

```typescript
// src/bridge/adapters/tauri.ts
export class TauriAdapter implements DataAdapter {
  async spaces_list(): Promise<SpaceRow[]> {
    return await window.__TAURI__.invoke('list_spaces')
  }
  
  async spaces_create(config: CreateConfig): Promise<SpaceRow> {
    return await window.__TAURI__.invoke('create_space', { config })
  }
  
  // 事件监听
  on(event: HostEvent, callback: () => void): () => void {
    const eventName = mapEventName(event)
    return window.__TAURI__.event.listen(eventName, callback)
  }
}
```

### Electron 适配器

```typescript
// src/bridge/adapters/electron.ts
export class ElectronAdapter implements DataAdapter {
  async spaces_list(): Promise<SpaceRow[]> {
    return await window.cuaDesktop.invoke('cua:bridge', {
      method: 'spaces.list',
      args: {}
    })
  }
  
  on(event: HostEvent, callback: (payload: any) => void): () => void {
    return window.cuaDesktop.on('cua:event', (payload) => {
      if (payload.event === event) {
        callback(payload.payload)
      }
    })
  }
}
```

### WebKit 适配器

```typescript
// src/bridge/adapters/webkit.ts
export class WebKitAdapter implements DataAdapter {
  async spaces_list(): Promise<SpaceRow[]> {
    const result = await window.webkit.messageHandlers.cua.postMessage({
      method: 'spaces.list',
      args: {}
    })
    return result.spaces
  }
  
  // WebKit 使用 CustomEvent
  on(event: HostEvent, callback: (payload: any) => void): () => void {
    const handler = (e: CustomEvent) => {
      if (e.detail.event === event) {
        callback(e.detail.payload)
      }
    }
    window.addEventListener('cua:event', handler)
    return () => window.removeEventListener('cua:event', handler)
  }
}
```

---

## Demo 模式实现

### 数据源

```typescript
// src/bridge/adapters/demo-data.ts
export const DEMO_SPACES: SpaceRow[] = [
  {
    id: 'space-1',
    name: 'Development',
    os: 'linux',
    power: true,
    createdAt: Date.now() - 86400000,
  },
  {
    id: 'space-2',
    name: 'Testing',
    os: 'macos',
    power: false,
    createdAt: Date.now() - 3600000,
  },
  // ...
]

export const DEMO_AGENTS: PersistentAgent[] = [
  {
    name: 'Claude Code',
    state: 'running',
    lastActive: Date.now(),
  },
  {
    name: 'Codex',
    state: 'paused',
    lastActive: Date.now() - 3600000,
  },
  // ...
]
```

### 模拟延迟

```typescript
// 模拟网络延迟，让体验更真实
async function simulateLatency(): Promise<void> {
  const delay = Math.random() * 200 + 50  // 50-250ms
  await new Promise(resolve => setTimeout(resolve, delay))
}
```

### 事件模拟

```typescript
// 模拟实时事件
class DemoAdapter {
  private eventListeners: Map<HostEvent, Set<() => void>> = new Map()
  
  // 模拟 Space 状态变化
  startSimulation() {
    setInterval(() => {
      // 随机触发事件
      if (Math.random() > 0.9) {
        this.emit('spaces.changed')
      }
    }, 5000)
  }
  
  private emit(event: HostEvent) {
    const listeners = this.eventListeners.get(event)
    if (listeners) {
      listeners.forEach(cb => cb())
    }
  }
}
```

---

## 性能优化

### 1. 代码分割

```typescript
// 路由级别的代码分割
const AgentsPage = lazy(() => import('./routes/agents'))

// 组件级别的代码分割
const HeavyComponent = lazy(() => import('./components/Heavy'))
```

### 2. 记忆化

```typescript
// 使用 React.memo 避免不必要的重渲染
const SpaceCard = React.memo(({ space }: { space: Space }) => {
  return <div>...</div>
})

// 使用 useMemo 缓存计算结果
const filteredSpaces = useMemo(() => {
  return spaces.filter(s => s.status === 'running')
}, [spaces])

// 使用 useCallback 缓存回调
const handleStart = useCallback((id: string) => {
  startSpace(id)
}, [startSpace])
```

### 3. 虚拟滚动

```typescript
// 对于长列表使用虚拟滚动
import { VirtualList } from '@legendapp/list'

function SpacesList({ spaces }: { spaces: Space[] }) {
  return (
    <VirtualList
      data={spaces}
      renderItem={({ item }) => <SpaceCard space={item} />}
      itemHeight={80}
    />
  )
}
```

### 4. 预加载

```typescript
// 路由预加载
<Link to="/spaces/123" preload="intent">
  Space 123
</Link>

// 数据预加载
export const Route = createFileRoute('/spaces/$spaceId')({
  loader: async ({ params }) => {
    return await fetchSpaceDetail(params.spaceId)
  },
})
```

---

## 安全考虑

### 1. 凭证处理

```typescript
// 凭证通过安全通道传递，不在 URL 中暴露
// Tauri: 使用系统 Keychain
// Electron: 使用 safeStorage API
// WebKit: 使用 macOS Keychain

// 示例：Keyvault unlock
async function unlockKeyvault(passphrase: string) {
  // 凭证通过加密通道传递
  await adapter.keyvault.unlock(passphrase)
  
  // 不在内存中保留明文凭证
  // passphrase 变量会被 GC 回收
}
```

### 2. 输入验证

```typescript
// 所有用户输入都经过验证
function validateSpaceName(name: string): string {
  // 移除危险字符
  return name.replace(/[<>\"'&]/g, '')
}

// 类型验证
function isSpaceId(id: unknown): id is string {
  return typeof id === 'string' && id.startsWith('space-')
}
```

### 3. XSS 防护

```typescript
// React 自动转义 JSX 中的内容
<div>{userInput}</div>  // 安全

// 避免使用 dangerouslySetInnerHTML
// 如必须使用，确保内容已清理
<div dangerouslySetInnerHTML={{ __html: sanitizedHtml }} />
```

### 4. CSRF 防护

```typescript
// 宿主适配器使用安全的 IPC 机制
// Tauri: invoke() 只能在应用内调用
// Electron: contextBridge 隔离
// WebKit: postMessage 只能在同一个 origin

// 不依赖 cookie 或 localStorage 进行认证
```

---

## 扩展指南

### 添加新的宿主适配器

1. 实现 DataAdapter 接口

```typescript
// src/bridge/adapters/my-host.ts
export class MyHostAdapter implements DataAdapter {
  async spaces_list(): Promise<SpaceRow[]> {
    // 调用你的宿主 API
    return await myHostAPI.listSpaces()
  }
  
  // 实现所有必需的方法...
}
```

2. 更新检测逻辑

```typescript
// src/bridge/detect.ts
export function detectMode(win: HostWindow): BridgeMode {
  // ... 现有检测
  
  // 添加你的宿主检测
  if (win.myHostGlobal) return "my-host"
  
  return "demo"
}
```

3. 更新 BridgeProvider

```typescript
// src/bridge/BridgeProvider.tsx
function createAdapter(mode: BridgeMode): DataAdapter {
  switch (mode) {
    case 'tauri': return new TauriAdapter()
    case 'electron': return new ElectronAdapter()
    case 'webkit': return new WebKitAdapter()
    case 'my-host': return new MyHostAdapter()  // 添加
    default: return new DemoAdapter()
  }
}
```

### 添加新的功能模块

1. 定义类型合约

```typescript
// src/bridge/contracts/my-feature.ts
export interface MyFeatureData {
  items: MyItem[]
  // ...
}

export interface MyItem {
  id: string
  name: string
  // ...
}
```

2. 扩展 DataAdapter

```typescript
// src/bridge/protocol.ts
export interface DataAdapter {
  // ... 现有接口
  
  myFeature: {
    list(): Promise<MyItem[]>
    create(item: CreateMyItem): Promise<MyItem>
    // ...
  }
}
```

3. 实现适配器方法

```typescript
// 在每个适配器中实现
class DemoAdapter {
  async myFeature_list(): Promise<MyItem[]> {
    return DEMO_ITEMS
  }
}
```

4. 创建 Hook

```typescript
// src/bridge/hooks.ts
export function useMyFeature() {
  const { data } = useBridge()
  
  return {
    items: data.myFeature.items,
    isLoading: data.myFeature.isLoading,
    create: data.myFeature.create,
  }
}
```

5. 使用 Hook

```typescript
function MyComponent() {
  const { items, create } = useMyFeature()
  
  return (
    <div>
      {items.map(item => (
        <div key={item.id}>{item.name}</div>
      ))}
    </div>
  )
}
```

---

## 总结

Cua Spaces Web 展示了一个现代化的、跨平台的 React 应用架构：

- **清晰的层次结构**: Presentation → Bridge → Adapter → Host
- **强大的抽象**: Bridge 层让 UI 完全不依赖宿主
- **类型安全**: 从 Rust 到 TypeScript 的完整类型链
- **可测试性**: Demo 模式支持独立测试
- **性能优化**: 代码分割、记忆化、虚拟滚动
- **安全性**: 安全的凭证处理和输入验证

这个架构不仅适用于 Cua 项目，也可以作为其他跨平台桌面应用的参考。

---

**文档版本**: 1.0  
**最后更新**: 2026-10-26  
**作者**: AI Assistant
