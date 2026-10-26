# "Open Window" 按钮无响应问题说明

## 🔍 问题分析

您点击的 **"Open window"** 按钮在 Demo 模式下没有效果，这是**预期行为**，不是 bug。

## 📌 原因

### 技术原因

"Open window" 功能需要**原生宿主环境**的支持，而当前运行在**纯浏览器 Demo 模式**下。

```typescript
// src/bridge/adapters/demo.ts (第 414-417 行)

// There is no window to open in the browser; the Space only has to exist.
"spaces.open": ({ spaceId }) => {
  findRow(spaceId);  // 只验证 Space 存在
  return null;       // 不执行任何操作
},
```

### 架构说明

"Open window" 功能在不同宿主环境中的实现：

| 宿主环境 | 实现方式 | 当前状态 |
|---------|---------|---------|
| **Tauri** | 调用 `open_space_window` Tauri 命令 | ✅ 可用 |
| **Electron** | 调用宿主 API 打开新窗口 | ✅ 可用 |
| **WebKit (SwiftUI)** | 调用 `spaces.open` WebKit 方法 | ✅ 可用 |
| **Demo (浏览器)** | 仅验证 Space 存在 | ⚠️ 不可用 |

## 💡 工作原理

### 在真实宿主环境中

1. 用户点击 "Open window" 按钮
2. 调用 `openSpace(spaceId)` → `adapter.call("spaces.open", ...)`
3. 宿主适配器调用原生 API：
   - **Tauri**: `invoke("open_space_window", { space: {...} })`
   - **Electron**: `cuaDesktop.invoke("cua:bridge", { method: "spaces.openStream", ... })`
   - **WebKit**: `postMessage({ method: "spaces.open", ... })`
4. 宿主打开一个新窗口，显示 Space 的桌面流
5. 显示 toast 提示：*"Opening {name} - Its desktop opens in a separate window."*

### 在 Demo 模式中

1. 用户点击 "Open window" 按钮
2. 调用 `openSpace(spaceId)` → `adapter.call("spaces.open", ...)`
3. Demo 适配器验证 Space 存在
4. 返回 `null`，**无实际操作**
5. Toast 提示可能显示，但不会打开任何窗口

## ✅ 解决方案

### 方案 1: 使用真实宿主环境（推荐）

要在真实环境中使用 "Open window" 功能，需要：

#### 使用 Electron 环境

```bash
# 1. 构建 Web UI
cd cua-main/apps/cua-spaces-web
pnpm build

# 2. 构建并启动 Electron 应用
cd ../cua-spaces-desktop
pnpm install --ignore-workspace
pnpm build
pnpm start
```

#### 使用 Tauri 环境

```bash
# 需要安装 Tauri 依赖
cargo install tauri-cli

# 在 Tauri 项目中运行
cargo tauri dev
```

#### 使用 SwiftUI (macOS) 环境

```bash
# 构建 Web UI
cd cua-main/apps/cua-spaces-web
pnpm build

# 构建并启动 macOS 应用
cd ../cua-spaces-macos
CUA_WEBUI_DIST=$PWD/../cua-spaces-web/dist scripts/build-app.sh debug
CUA_SPACES_START_VIEW=webui ".build/app/Cua Spaces.app/Contents/MacOS/CuaSpacesMac"
```

### 方案 2: 在 Demo 中测试其他功能

虽然 "Open window" 在 Demo 模式不可用，但你可以测试其他功能：

✅ **可用功能**:
- Spaces 列表和管理
- 创建、启动、停止 Space
- Agents 管理
- Keyvault 凭证管理
- Machines 设备管理
- Settings 设置
- Onboarding 流程

❌ **不可用功能** (需要真实宿主):
- Open window (打开桌面流窗口)
- 实时桌面流传输
- Teleport (应用传送)
- Share (共享)
- Native 视频播放

### 方案 3: 连接真实 Space

如果你有真实的 Space 运行，可以通过真实宿主环境连接：

```bash
# 1. 创建并启动 Space
cua sb create ubuntu --name my-space
cua sb start my-space

# 2. 在 Electron/Tauri/SwiftUI 应用中连接
# Space 会自动出现在列表中

# 3. 点击 "Open window" 打开桌面流
```

##  快速验证

要验证 "Open window" 功能是否工作，检查以下几点：

1. **是否在真实宿主中运行？**
   - 检查 URL 栏：`http://localhost:5174` = Demo 模式 ❌
   - 检查应用标题：Electron/Tauri 应用会有原生窗口 ✅

2. **是否看到 toast 提示？**
   - Demo 模式：可能显示 "Opening..." 但无实际窗口
   - 真实宿主：显示提示并打开新窗口

3. **是否有新窗口打开？**
   - Demo 模式：不会打开 ❌
   - 真实宿主：会打开包含桌面流的新窗口 ✅

##  相关代码

### 按钮位置

```typescript
// src/components/space-detail/stream-surface.tsx (第 176-178 行)
<Button className="mt-4" onClick={() => void open()}>
  <AppWindowIcon /> Open window
</Button>
```

### 点击处理

```typescript
// src/components/space-detail/stream-surface.tsx (第 132-136 行)
const open = () =>
  openSpace(spaceId).then(
    () => toast(`Opening ${name}`, { description: "Its desktop opens in a separate window." }),
    (e: unknown) => toast(`Couldn't open ${name}`, { description: e instanceof Error ? e.message : String(e), type: "error" }),
  );
```

### Demo 适配器实现

```typescript
// src/bridge/adapters/demo.ts (第 414-417 行)
"spaces.open": ({ spaceId }) => {
  findRow(spaceId);  // 只验证 Space 存在
  return null;       // 不执行任何操作
},
```

### Tauri 适配器实现

```typescript
// src/bridge/adapters/tauri.ts (第 187 行)
await invoke("open_space_window", { 
  space: { id: spaceId, name: name ?? spaceId, os } 
});
```

## 🔧 开发建议

如果你在开发这个功能：

1. **在 Demo 中添加模拟**

```typescript
// src/bridge/adapters/demo.ts
"spaces.open": ({ spaceId }) => {
  findRow(spaceId);
  
  // 添加模拟行为（可选）
  console.log(`[Demo] Would open window for Space: ${spaceId}`);
  // 可以打开一个新浏览器标签页作为模拟
  // window.open(`/space/${spaceId}/stream`, '_blank');
  
  return null;
},
```

2. **添加功能检测**

```typescript
// 在组件中检测是否支持
const canOpenWindow = useBridge().mode !== 'demo';

<Button 
  disabled={!canOpenWindow}
  onClick={() => void open()}
>
  <AppWindowIcon /> 
  {canOpenWindow ? 'Open window' : 'Open window (not available in demo)'}
</Button>
```

3. **添加用户提示**

```typescript
const open = () => {
  if (useBridge().mode === 'demo') {
    toast('Demo mode', { 
      description: 'Open window is only available in Electron, Tauri, or SwiftUI hosts.',
      type: 'info' 
    });
    return;
  }
  
  openSpace(spaceId).then(...)
};
```

## 📖 总结

| 问题 | 答案 |
|------|------|
| 这是 bug 吗？ | 不是，是预期行为 |
| 为什么没效果？ | Demo 模式不支持打开原生窗口 |
| 如何让它工作？ | 在 Electron/Tauri/SwiftUI 环境中运行 |
| Demo 能测试什么？ | 除窗口打开外的所有 UI 功能 |
| 需要真实后端吗？ | 不需要，但需要真实宿主环境 |

---

**文档版本**: 1.0  
**最后更新**: 2026-10-26  
**问题分类**: 功能限制（非 bug）
