---
name: 工具系统设计
layer: action
category: tool
description: >
  为 AI Agent 构建模块化、可组合、可扩展的工具系统。
  当用户想要设计工具注册、工具执行、权限控制、工具编排时触发。
  关键词：工具系统、工具注册、tool registry、tool execution、MCP、工具模块化。
---

# 工具系统设计

教 AI Agent 如何构建一个模块化的工具系统，让 Agent 能调用外部能力完成任务。

## 核心理念

**每个工具是一个独立模块**，包含：
- 输入 schema（定义参数）
- 权限模型（决定谁能用）
- 执行逻辑（实际操作）
- 输出格式（返回结果）

工具之间互不依赖，通过注册表统一管理。

## 架构总览

```
┌─────────────────────────────────────────┐
│              Agent 核心                  │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ Query Engine │  │ Permission Sys  │   │
│  └──────┬──────┘  └────────┬────────┘   │
│         │                  │            │
│  ┌──────▼──────────────────▼────────┐   │
│  │         Tool Registry            │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌────┐ │   │
│  │  │Tool1│ │Tool2│ │Tool3│ │... │ │   │
│  │  └─────┘ └─────┘ └─────┘ └────┘ │   │
│  └──────────────────────────────────┘   │
│         │                               │
│  ┌──────▼──────────────────────────┐    │
│  │      Tool Execution Engine      │    │
│  │  schema → permission → execute  │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## 执行流程

1. **Schema 验证** — Zod 校验输入参数
2. **权限检查** — 根据规则决定是否执行
3. **实际执行** — 运行工具逻辑
4. **结果返回** — 输出结构化结果

## 核心类型

### ToolResult（统一返回类型）

```typescript
type ToolResult<T> = 
  | { success: true; data: T }
  | { success: false; error: string };
```

### Tool 接口

```typescript
interface Tool<Input, Output, Progress = { stage: string; percent: number }> {
  name: string;
  description: string;
  inputSchema: ZodSchema<Input>;
  permission: PermissionModel;
  execute(input: Input, context: ToolContext): Promise<ToolResult<Output>>;
  
  // 可选：根据上下文判断工具是否可用（如 feature flag 控制）
  isAvailable?: (context: ToolContext) => boolean;
  
  // 可选：渲染进度（大部分工具用默认 Progress 即可）
  renderProgress?(progress: Progress): React.ComponentType;
}
```

### PermissionRule

```typescript
interface PermissionRule<Input> {
  // condition 同时接收 input 和 context
  condition: (input: Input, context: ToolContext) => boolean;
  action: 'allow' | 'deny' | 'prompt';
  reason?: string;
}
```

### ToolContext

```typescript
interface ToolContext {
  cwd: string;
  messages: Message[];
  permissions: PermissionState;
  mcpServers: MCPServer[];
  abortSignal: AbortSignal;
  onProgress: (progress: Progress) => void;
}
```

## 权限模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `auto` | 符合规则自动批准 | 日常开发 |
| `prompt` | 每次询问用户 | 安全敏感 |
| `rule` | 基于规则判断 | 灵活控制 |
| `deny` | 禁止执行 | 危险操作 |

## 工具分类

| 类别 | 工具示例 | 权限 |
|------|----------|------|
| 文件操作 | FileRead, FileWrite, Glob, Grep | 读自动批准，写需确认 |
| 命令执行 | Bash, PowerShell | 需确认 |
| 网络请求 | WebFetch, WebSearch | 自动批准 |
| Agent 协作 | Agent, SendMessage | 需确认 |
| 任务管理 | TaskCreate, TaskUpdate | 自动批准 |

## 工具注册表

```typescript
class ToolRegistry {
  private tools: Map<string, Tool<any, any, any>> = new Map();
  
  register(tool: Tool<any, any, any>): void {
    this.tools.set(tool.name, tool);
  }
  
  get(name: string): Tool<any, any, any> | undefined {
    return this.tools.get(name);
  }
  
  getAll(): Tool<any, any, any>[] {
    return Array.from(this.tools.values());
  }
  
  // 按需加载：只返回当前可用的工具
  getForContext(context: ToolContext): Tool<any, any, any>[] {
    return this.getAll().filter(tool => 
      tool.isAvailable?.(context) ?? true
    );
  }
}
```

## 工具执行引擎

### 单工具执行

```typescript
async function executeTool(
  tool: Tool<any, any, any>,
  input: any,
  context: ToolContext
): Promise<ToolResult> {
  // 1. Schema 验证
  const validatedInput = tool.inputSchema.parse(input);
  
  // 2. 权限检查
  const permission = await checkPermission(tool, validatedInput, context);
  if (permission.denied) {
    return { success: false, error: permission.reason };
  }
  
  // 3. 执行
  const result = await tool.execute(validatedInput, context);
  
  // 4. 记录
  logToolExecution(tool.name, validatedInput, result);
  
  return result;
}
```

### 并行执行（拓扑排序）

```typescript
interface ToolCall {
  toolName: string;
  input: any;
  deps?: string[];  // 依赖的其他工具名
}

async function executeToolsParallel(
  calls: ToolCall[],
  context: ToolContext
): Promise<Map<string, ToolResult>> {
  const results = new Map<string, ToolResult>();
  const remaining = [...calls];
  
  while (remaining.length > 0) {
    // 找出所有依赖已满足的调用
    const ready = remaining.filter(call => 
      !call.deps?.some(dep => 
        remaining.some(r => r.toolName === dep)
      )
    );
    
    if (ready.length === 0) {
      throw new Error('循环依赖');
    }
    
    // 并行执行这一批
    const batchResults = await Promise.all(
      ready.map(async call => {
        const tool = registry.get(call.toolName);
        const result = await executeTool(tool, call.input, context);
        return [call.toolName, result] as const;
      })
    );
    
    // 记录结果，移除已完成的调用
    for (const [name, result] of batchResults) {
      results.set(name, result);
      remaining.splice(remaining.findIndex(r => r.toolName === name), 1);
    }
  }
  
  return results;
}
```

## 目录结构

```
tools/
├── index.ts          # 注册表
├── types.ts          # 类型定义
├── BashTool/
│   ├── index.ts      # 实现
│   ├── schema.ts     # Schema
│   ├── permission.ts # 权限
│   └── security.ts   # 安全检查
└── FileReadTool/
    ├── index.ts
    └── schema.ts
```

## 最佳实践

1. **单一职责** — 每个工具只做一件事
2. **自包含** — 目录包含所有文件
3. **无状态** — 不保存跨调用状态
4. **可测试** — 可以独立测试
5. **幂等** — 相同输入产生相同输出

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 工具未调用 | Schema 验证失败 | 检查输入参数 |
| 权限被拒 | 违反权限规则 | 检查 permission 配置 |
| 执行超时 | 操作时间过长 | 增加 timeout |
| MCP 不可用 | 服务器未连接 | 检查 MCP 配置 |
| 并行执行卡住 | 存在循环依赖 | 检查 deps 配置 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Zod | v4+ | Schema 验证 |
| React | 18+ | UI 渲染（可选） |
