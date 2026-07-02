---
name: IDE 集成设计
layer: meta
category: ai-builder
description: >
  教 AI 如何设计和构建 IDE 集成桥接系统。
  当用户想要实现 IDE 扩展、代码编辑器集成、开发工具集成时触发。
  关键词：IDE 集成、bridge、VS Code 扩展、编辑器集成。
---

# IDE 集成设计

教 AI 如何设计和构建 IDE 集成桥接系统，让 Agent 能与 IDE 交互。

## 能力概览

| 能力 | 说明 |
|------|------|
| 消息桥接 | Agent 和 IDE 之间传递消息 |
| 文件操作 | 读写 IDE 中的文件（带路径安全检查） |
| 代码编辑 | 编辑 IDE 中的代码 |
| 终端集成 | 在 IDE 终端中执行命令 |
| UI 扩展 | 在 IDE 中显示自定义 UI（Webview） |

## 构建方案选择

**先问用户需求，再选方案：**

```
IF 用户只需要文件操作 + 简单命令:
    → 方案一（轻量版）— stdio 消息 + 文件操作
ELSE IF 用户需要完整 IDE 扩展:
    → 方案二（完整版）— VS Code 扩展 + WebSocket + Webview
ELSE IF 用户已有 IDE 插件:
    → 方案三（集成版）— 在现有插件上扩展
```

| 你的需求 | 推荐方案 | 状态 |
|---------|----------|------|
| 简单文件操作 + 命令 | 方案一 | ✅ 可用 |
| 完整 VS Code 扩展 | 方案二 | ✅ 生产验证 |
| 集成现有插件 | 方案三 | ⚠️ 社区贡献，待验证 |

---

## Agent 执行规范

### 核心约束

- **先问用户需求**：了解用户要做什么类型的 IDE 集成
- **先问 IDE 类型**：确认用户使用哪个 IDE（VS Code、JetBrains、Vim）
- **路径必须安全**：文件操作必须验证路径不越界
- **错误要捕获**：JSON 解析、文件操作都要 try-catch
- **不要猜测需求**：让用户告诉你具体需要什么功能

### 当前实现范围

本文档的代码实现了以下能力：

| 能力 | 方案一 | 方案二 |
|------|--------|--------|
| 双向消息通信 | ✅ stdio | ✅ WebSocket |
| 文件操作（安全） | ✅ 带路径检查 | ✅ 带路径检查 |
| 多监听器 | ✅ | ✅ |
| JSON 安全解析 | ✅ | ✅ |
| 错误恢复（重连） | ❌ | ✅ 指数退避 |
| 消息队列 | ❌ | ✅ 缓存重发 |
| Webview UI | ❌ | ✅ |
| 终端集成 | ❌ | ✅ |

---

## 前置条件

### 方案一（轻量版）

无外部依赖，纯 Node.js 实现。

### 方案二（完整版）

| 依赖 | 版本 | 用途 |
|------|------|------|
| TypeScript | 5.0+ | 类型安全 |
| Node.js | 18+ | 运行时 |
| ws | 8.0+ | WebSocket |
| @types/vscode | 1.0+ | VS Code API 类型（可选） |

---

## 方案一：轻量版

适合简单场景：stdio 消息通信 + 安全文件操作。

### Step 1：定义消息协议

```typescript
// bridge/types.ts
interface BridgeMessage {
  id: string;
  type: 'request' | 'response' | 'event';
  method: string;
  params?: any;
  result?: any;
  error?: string;
}

interface BridgeConnection {
  send(message: BridgeMessage): void;
  onMessage(callback: (message: BridgeMessage) => void): () => void;
  close(): void;
}
```

### Step 2：创建 stdio 桥接连接

```typescript
// bridge/StdioBridge.ts
import * as readline from 'readline';

class StdioBridgeConnection implements BridgeConnection {
  private listeners = new Set<(msg: BridgeMessage) => void>();
  private rl: readline.Interface;
  
  constructor() {
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    this.rl.on('line', (line: string) => {
      try {
        const message = JSON.parse(line) as BridgeMessage;
        this.listeners.forEach(cb => cb(message));
      } catch {
        // 忽略非 JSON 行（可能是用户输入）
      }
    });
  }
  
  send(message: BridgeMessage): void {
    process.stdout.write(JSON.stringify(message) + '\n');
  }
  
  onMessage(callback: (message: BridgeMessage) => void): () => void {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }
  
  close(): void {
    this.rl.close();
  }
}
```

### Step 3：实现安全文件操作

```typescript
// bridge/FileOperations.ts
import * as fs from 'fs';
import * as path from 'path';

class FileOperations {
  private rootPath: string;
  
  constructor(rootPath: string) {
    this.rootPath = path.resolve(rootPath);
  }
  
  private validatePath(filePath: string): string {
    const fullPath = path.resolve(this.rootPath, filePath);
    if (!fullPath.startsWith(this.rootPath)) {
      throw new Error(`路径越界: ${filePath}`);
    }
    return fullPath;
  }
  
  async readFile(filePath: string): Promise<string> {
    const fullPath = this.validatePath(filePath);
    return fs.promises.readFile(fullPath, 'utf-8');
  }
  
  async writeFile(filePath: string, content: string): Promise<void> {
    const fullPath = this.validatePath(filePath);
    const dir = path.dirname(fullPath);
    await fs.promises.mkdir(dir, { recursive: true });
    await fs.promises.writeFile(fullPath, content, 'utf-8');
  }
  
  async listFiles(dirPath: string): Promise<string[]> {
    const fullPath = this.validatePath(dirPath);
    return fs.promises.readdir(fullPath);
  }
  
  async deleteFile(filePath: string): Promise<void> {
    const fullPath = this.validatePath(filePath);
    await fs.promises.unlink(fullPath);
  }
}
```

### 方案一限制

- 不支持自动重连
- 不支持消息队列
- 不支持 Webview UI
- 不支持终端集成

---

## 方案二：完整版

VS Code 扩展 + WebSocket 桥接 + Webview UI。

### Step 1：VS Code 扩展入口

```typescript
// vscode/extension.ts
import * as vscode from 'vscode';
import { WebSocketBridgeConnection } from '../bridge/BridgeConnection';
import { MessageHandler } from '../bridge/MessageHandler';
import { FileOperations } from '../bridge/FileOperations';

let connection: WebSocketBridgeConnection | null = null;
let handler: MessageHandler | null = null;

export function activate(context: vscode.ExtensionContext) {
  const rootPath = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || '';
  const fileOps = new FileOperations(rootPath);
  handler = new MessageHandler();
  
  // 注册文件操作
  handler.register('readFile', (params) => fileOps.readFile(params.path));
  handler.register('writeFile', (params) => fileOps.writeFile(params.path, params.content));
  handler.register('listFiles', (params) => fileOps.listFiles(params.path));
  
  // 注册 VS Code 命令
  handler.register('showInfo', (params) => {
    vscode.window.showInformationMessage(params.message);
    return { success: true };
  });
  
  handler.register('openFile', async (params) => {
    const doc = await vscode.workspace.openTextDocument(params.path);
    await vscode.window.showTextDocument(doc);
    return { success: true };
  });
  
  // 连接到 Agent 服务
  connectToAgent(context);
  
  // 注册命令
  context.subscriptions.push(
    vscode.commands.registerCommand('extension.connectAgent', () => {
      connectToAgent(context);
    })
  );
}

function connectToAgent(context: vscode.ExtensionContext) {
  const wsUrl = vscode.workspace.getConfiguration('agent').get('wsUrl', 'ws://localhost:3000');
  
  connection = new WebSocketBridgeConnection(wsUrl, {
    onReconnect: () => {
      vscode.window.showInformationMessage('Agent 已重连');
    },
    onMaxRetries: () => {
      vscode.window.showErrorMessage('Agent 连接失败，已停止重试');
    }
  });
  
  connection.onMessage(async (message) => {
    if (message.type === 'request' && handler) {
      const response = await handler.handle(message);
      connection?.send(response);
    }
  });
}

export function deactivate() {
  connection?.close();
}
```

### Step 2：WebSocket 桥接连接（带重连）

```typescript
// bridge/BridgeConnection.ts
import WebSocket from 'ws';

interface ConnectionOptions {
  maxRetries?: number;
  reconnectDelay?: number;
  onReconnect?: () => void;
  onMaxRetries?: () => void;
}

class WebSocketBridgeConnection implements BridgeConnection {
  private ws: WebSocket | null = null;
  private listeners = new Set<(msg: BridgeMessage) => void>();
  private messageQueue: BridgeMessage[] = [];
  private retryCount = 0;
  private maxRetries: number;
  private reconnectDelay: number;
  private options: ConnectionOptions;
  private url: string;
  
  constructor(url: string, options: ConnectionOptions = {}) {
    this.url = url;
    this.options = options;
    this.maxRetries = options.maxRetries || 5;
    this.reconnectDelay = options.reconnectDelay || 1000;
    this.connect();
  }
  
  private connect(): void {
    this.ws = new WebSocket(this.url);
    
    this.ws.on('open', () => {
      this.retryCount = 0;
      this.flushQueue();
    });
    
    this.ws.on('message', (data: string) => {
      try {
        const message = JSON.parse(data) as BridgeMessage;
        this.listeners.forEach(cb => cb(message));
      } catch {
        console.error('收到非 JSON 消息:', data);
      }
    });
    
    this.ws.on('close', () => {
      this.reconnect();
    });
    
    this.ws.on('error', (error: Error) => {
      console.error('WebSocket 错误:', error.message);
    });
  }
  
  private reconnect(): void {
    if (this.retryCount >= this.maxRetries) {
      this.options.onMaxRetries?.();
      return;
    }
    
    this.retryCount++;
    const delay = this.reconnectDelay * Math.pow(2, this.retryCount - 1);
    
    setTimeout(() => {
      this.options.onReconnect?.();
      this.connect();
    }, delay);
  }
  
  private flushQueue(): void {
    while (this.messageQueue.length > 0 && this.ws?.readyState === WebSocket.OPEN) {
      const msg = this.messageQueue.shift()!;
      this.ws.send(JSON.stringify(msg));
    }
  }
  
  send(message: BridgeMessage): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      this.messageQueue.push(message);
    }
  }
  
  onMessage(callback: (message: BridgeMessage) => void): () => void {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }
  
  close(): void {
    this.maxRetries = 0;
    this.ws?.close();
  }
}
```

### Step 3：消息处理器

```typescript
// bridge/MessageHandler.ts
class MessageHandler {
  private handlers = new Map<string, (params: any) => Promise<any>>();
  
  register(method: string, handler: (params: any) => Promise<any>): void {
    this.handlers.set(method, handler);
  }
  
  async handle(message: BridgeMessage): Promise<BridgeMessage> {
    const handler = this.handlers.get(message.method);
    
    if (!handler) {
      return {
        id: message.id,
        type: 'response',
        method: message.method,
        error: `方法 ${message.method} 未注册`
      };
    }
    
    try {
      const result = await handler(message.params);
      return {
        id: message.id,
        type: 'response',
        method: message.method,
        result
      };
    } catch (error) {
      return {
        id: message.id,
        type: 'response',
        method: message.method,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }
}
```

### Step 4：Webview UI

```typescript
// vscode/webview.ts
import * as vscode from 'vscode';

export function createWebviewPanel(context: vscode.ExtensionContext): vscode.WebviewPanel {
  const panel = vscode.window.createWebviewPanel(
    'agentUI',
    'Agent UI',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      localResourceRoots: [context.extensionUri]
    }
  );
  
  panel.webview.html = getWebviewContent();
  
  panel.webview.onDidReceiveMessage(
    async (message) => {
      // 处理来自 Webview 的消息
      switch (message.command) {
        case 'execute':
          const result = await executeCommand(message.command, message.args);
          panel.webview.postMessage({ type: 'result', data: result });
          break;
      }
    },
    undefined,
    context.subscriptions
  );
  
  return panel;
}

function getWebviewContent(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Agent UI</title>
  <style>
    body { font-family: var(--vscode-font-family); padding: 10px; }
    #output { white-space: pre-wrap; margin-top: 10px; }
  </style>
</head>
<body>
  <h2>Agent UI</h2>
  <div id="output"></div>
  <script>
    window.addEventListener('message', event => {
      const message = event.data;
      const output = document.getElementById('output');
      output.textContent += JSON.stringify(message, null, 2) + '\\n';
    });
  </script>
</body>
</html>`;
}
```

---

## 方案三：集成版

在现有 IDE 插件上扩展。

### VS Code 扩展集成

```typescript
// 如果已有 VS Code 扩展，只需添加消息处理
import * as vscode from 'vscode';

function extendExtension(context: vscode.ExtensionContext): void {
  // 添加新的命令
  context.subscriptions.push(
    vscode.commands.registerCommand('extension.agentCommand', async () => {
      // 与 Agent 通信
    })
  );
  
  // 添加新的 Webview
  // ...
}
```

### JetBrains 插件集成

```kotlin
// 如果已有 JetBrains 插件，实现 ToolWindowFactory
class AgentToolWindowFactory : ToolWindowFactory {
    override fun createToolWindowContent(project: Project, toolWindow: ToolWindow) {
        val content = toolWindow.contentManager.factory.createContent(
            AgentPanel(project)
        )
        toolWindow.contentManager.addContent(content)
    }
}
```

---

## 使用方法

### 方案一使用

```typescript
const bridge = new StdioBridgeConnection();
const fileOps = new FileOperations('/path/to/project');
const handler = new MessageHandler();

handler.register('readFile', (params) => fileOps.readFile(params.path));
handler.register('writeFile', (params) => fileOps.writeFile(params.path, params.content));

const unsubscribe = bridge.onMessage(async (message) => {
  const response = await handler.handle(message);
  bridge.send(response);
});

// 发送请求
bridge.send({
  id: '1',
  type: 'request',
  method: 'readFile',
  params: { path: 'src/index.ts' }
});
```

### 方案二使用

```typescript
const connection = new WebSocketBridgeConnection('ws://localhost:3000', {
  maxRetries: 5,
  onReconnect: () => console.log('已重连'),
  onMaxRetries: () => console.log('停止重连')
});

connection.onMessage(async (message) => {
  const response = await handler.handle(message);
  connection.send(response);
});
```

---

## 目录结构

```
bridge/
├── types.ts               # 类型定义
├── StdioBridge.ts         # 方案一：stdio 桥接
├── BridgeConnection.ts    # 方案二：WebSocket 桥接（带重连）
├── MessageHandler.ts      # 消息处理器
├── FileOperations.ts      # 文件操作（带路径安全检查）
└── vscode/
    ├── extension.ts       # VS Code 扩展入口
    ├── webview.ts         # Webview UI
    └── package.json       # 扩展配置
```

---

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 连接失败 | 服务器未启动 | 检查服务器状态 |
| 消息丢失 | 连接断开 | 方案二自动重连，方案一手动重连 |
| 文件操作失败 | 路径越界 | 检查路径安全检查日志 |
| JSON 解析错误 | 收到非 JSON 消息 | 检查消息格式 |
| error.message 崩溃 | error 不是 Error 对象 | 代码已用 `error instanceof Error ? error.message : String(error)` |

---

## 命令分类

| 类别 | 命令示例 | 说明 |
|------|----------|------|
| 连接管理 | Connect, Disconnect, Reconnect | 连接 |
| 消息传递 | SendMessage, OnMessage | 消息 |
| 文件操作 | ReadFile, WriteFile, ListFiles | 文件（带路径安全检查） |
| UI 扩展 | ShowPanel, UpdateUI | Webview UI |
