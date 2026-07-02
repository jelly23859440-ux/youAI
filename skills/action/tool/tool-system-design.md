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

## 1. 核心类型

### ToolResult（统一返回类型）

```typescript
type ToolResult<T> = 
  | { success: true; data: T }
  | { success: false; error: string };
```

### Tool 接口

```typescript
// tool.ts
interface Tool<Input, Output, Progress = { stage: string; percent: number }> {
  name: string;
  description: string;
  inputSchema: ZodSchema<Input>;      // Zod v4
  permission: PermissionModel;
  execute(input: Input, context: ToolContext): Promise<ToolResult<Output>>;
  
  // 可选：根据上下文判断工具是否可用（如 feature flag 控制）
  isAvailable?: (context: ToolContext) => boolean;
  
  // 可选：渲染进度（大部分工具用默认 Progress 即可）
  renderProgress?(progress: Progress): React.ComponentType;
}
```

### 输入 Schema

用 Zod 定义参数类型和验证：

```typescript
import { z } from 'zod';

const BashToolSchema = z.object({
  command: z.string().describe('要执行的 shell 命令'),
  workdir: z.string().optional().describe('工作目录'),
  timeout: z.number().optional().default(30000).describe('超时时间(ms)'),
});
```

### 权限模型

```typescript
type PermissionModel = 
  | { type: 'auto' }                    // 自动批准
  | { type: 'prompt' }                  // 每次询问用户
  | { type: 'rule', rules: PermissionRule[] }  // 基于规则
  | { type: 'deny' };                   // 禁止

interface PermissionRule<Input> {
  // condition 同时接收 input 和 context
  condition: (input: Input, context: ToolContext) => boolean;
  action: 'allow' | 'deny' | 'prompt';
  reason?: string;
}
```

### 执行上下文

```typescript
interface ToolContext {
  cwd: string;                    // 当前工作目录
  messages: Message[];            // 对话历史
  permissions: PermissionState;   // 权限状态
  mcpServers: MCPServer[];        // MCP 服务器
  abortSignal: AbortSignal;       // 中断信号
  onProgress: (progress: Progress) => void;  // 进度回调
}
```

## 2. 工具注册表

所有工具注册到一个中央注册表：

```typescript
// toolRegistry.ts
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
  
  // 按需加载：只返回当前需要的工具
  getForContext(context: ToolContext): Tool<any, any, any>[] {
    return this.getAll().filter(tool => 
      tool.isAvailable?.(context) ?? true
    );
  }
}
```

### 条件加载

通过 feature flag 控制工具是否可用：

```typescript
const tools = [
  feature('VOICE_MODE') ? voiceTool : null,
  feature('MCP_ENABLED') ? mcpTool : null,
  bashTool,  // 始终可用
  fileTool,  // 始终可用
].filter(Boolean);
```

## 3. 工具执行引擎

执行流程：**Schema 验证 → 权限检查 → 实际执行 → 结果返回**

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
  
  // 4. 记录（用于调试和审计）
  logToolExecution(tool.name, validatedInput, result);
  
  return result;
}
```

### 并行执行（拓扑排序）

多个工具可以并行执行，支持依赖链：

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

## 4. 权限系统

### 权限模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `default` | 每次工具调用都询问用户 | 安全敏感场景 |
| `auto` | 符合规则的自动批准 | 日常开发 |
| `plan` | 只读操作自动批准 | 规划阶段 |
| `bypass` | 跳过所有权限检查 | 测试/CI |

### 权限规则

```typescript
const permissionRules: PermissionRule[] = [
  // 读操作自动批准
  {
    condition: (input, ctx) => 
      ctx.tool.name.startsWith('File') && 
      ctx.tool.name.includes('Read'),
    action: 'allow',
    reason: '读操作安全'
  },
  // 写操作需要确认
  {
    condition: (input, ctx) => 
      ctx.tool.name.includes('Write'),
    action: 'prompt',
    reason: '写操作需要确认'
  },
  // 危险命令禁止
  {
    condition: (input, ctx) => 
      ctx.tool.name === 'Bash' && 
      /rm\s+-rf|drop\s+table/i.test(input.command),
    action: 'deny',
    reason: '危险操作'
  },
];
```

## 5. 工具模块化设计

### 目录结构

```
tools/
├── index.ts              # 工具注册表
├── types.ts              # 类型定义
├── Tool.ts               # 基础工具类
├── BashTool/
│   ├── index.ts          # 工具实现
│   ├── schema.ts         # 输入 schema
│   ├── permission.ts     # 权限规则
│   ├── security.ts       # 安全检查
│   └── UI.tsx            # 进度渲染
├── FileReadTool/
│   ├── index.ts
│   ├── schema.ts
│   └── imageProcessor.ts # 图片处理
├── FileWriteTool/
│   ├── index.ts
│   └── schema.ts
├── GrepTool/
│   ├── index.ts
│   └── schema.ts
└── AgentTool/
    ├── index.ts
    ├── runAgent.ts       # Agent 执行
    ├── agentMemory.ts    # Agent 记忆
    └── built-in/         # 内置 Agent 类型
```

### 工具自包含

每个工具目录包含所有需要的文件：
- `index.ts` — 工具实现和导出
- `schema.ts` — 输入验证 schema
- `permission.ts` — 权限规则（可选）
- `UI.tsx` — 进度渲染组件（可选）
- `utils.ts` — 工具内部工具函数（可选）

## 6. 工具分类

### 按能力分类

| 类别 | 工具示例 | 说明 |
|------|----------|------|
| **文件操作** | FileRead, FileWrite, FileEdit, Glob, Grep | 文件系统读写搜索 |
| **命令执行** | Bash, PowerShell | Shell 命令执行 |
| **网络请求** | WebFetch, WebSearch | 网络内容获取 |
| **Agent 协作** | Agent, SendMessage, TeamCreate | 多 Agent 通信 |
| **任务管理** | TaskCreate, TaskUpdate, TaskList | 任务状态管理 |
| **工具搜索** | ToolSearch, MCPTool | 动态工具发现 |
| **结构化输出** | SyntheticOutput | 生成结构化数据 |

### 按权限分类

| 权限级别 | 工具 | 说明 |
|----------|------|------|
| **只读** | FileRead, Glob, Grep, WebSearch | 自动批准 |
| **写入** | FileWrite, FileEdit, Bash | 需要确认 |
| **危险** | Bash(rm/drop), FileWrite(系统路径) | 需要特别确认 |
| **内部** | Config, SyntheticOutput | 仅 Agent 内部使用 |

## 7. MCP 集成

工具系统支持 MCP（Model Context Protocol）扩展：

```typescript
// MCP 工具适配
function adaptMCPTool(mcpTool: MCPTool): Tool {
  return {
    name: mcpTool.name,
    description: mcpTool.description,
    inputSchema: mcpJsonSchemaToZod(mcpTool.inputSchema),
    permission: { type: 'prompt' },
    execute: async (input, context) => {
      const server = context.mcpServers.find(s => 
        s.tools.includes(mcpTool.name)
      );
      return server.callTool(mcpTool.name, input);
    },
  };
}
```

## 8. 最佳实践

### 工具设计原则

1. **单一职责**：每个工具只做一件事
2. **自包含**：工具目录包含所有需要的文件
3. **无状态**：工具不保存跨调用状态
4. **可测试**：工具可以独立测试
5. **幂等**：相同输入产生相同输出（尽可能）

### Schema 设计

1. **必填字段用 `z.string()`**，可选字段用 `z.string().optional()`
2. **给每个字段加 `.describe()`**，AI 会参考描述决定参数
3. **用 `z.enum()` 限制选项**，不要让 AI 自由发挥
4. **给默认值**，减少 AI 决策负担

### 安全设计

1. **读操作自动批准**，写操作需要确认
2. **危险命令需要特别确认**（rm -rf, DROP TABLE 等）
3. **路径验证**：禁止访问系统目录
4. **命令注入检查**：验证输入合法性
5. **超时控制**：防止长时间运行

## 示例：构建一个 Git 工具

```typescript
// tools/GitTool/index.ts
import { z } from 'zod';
import { buildTool } from '../Tool';

const GitToolSchema = z.object({
  command: z.enum(['status', 'diff', 'log', 'commit', 'push', 'pull'])
    .describe('Git 命令'),
  args: z.string().optional().describe('额外参数'),
  message: z.string().optional().describe('commit 消息'),
});

export const GitTool = buildTool({
  name: 'Git',
  description: '执行 Git 操作',
  inputSchema: GitToolSchema,
  permission: {
    type: 'rule',
    rules: [
      // status/diff/log 自动批准
      {
        condition: (input, ctx) => ['status', 'diff', 'log'].includes(input.command),
        action: 'allow',
      },
      // commit/push/pull 需要确认
      {
        condition: (input, ctx) => ['commit', 'push', 'pull'].includes(input.command),
        action: 'prompt',
      },
    ],
  },
  execute: async (input, context) => {
    const result = await execGit(input.command, input.args, context.cwd);
    return { success: true, data: { output: result.stdout, error: result.stderr } };
  },
});
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 工具未被调用 | Schema 验证失败 | 检查输入参数是否符合 schema |
| 权限被拒绝 | 违反权限规则 | 检查 permission 配置 |
| 工具执行超时 | 操作时间过长 | 增加 timeout 或优化执行逻辑 |
| MCP 工具不可用 | 服务器未连接 | 检查 MCP 服务器配置 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Zod | v4+ | Schema 验证 |
| React | 18+ | UI 渲染（可选） |
| Ink | 4+ | 终端 UI（可选） |
