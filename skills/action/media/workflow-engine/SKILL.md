---
name: 节点式工作流引擎
layer: action
category: media
status: unverified
description: >
  实现节点式工作流系统，支持节点注册、连接、执行。
  当用户想要构建可视化工作流、节点编辑器、数据处理管道时触发。
  关键词：工作流、节点、流程图、pipeline、workflow、节点编辑器。
---

# 节点式工作流引擎

实现 ComfyUI 风格的节点式工作流系统，支持可视化流程设计和执行。

## 核心理念

每个节点是一个独立的处理单元：
- **输入**：接收数据（来自其他节点或外部输入）
- **处理**：执行转换或操作
- **输出**：传递结果给下一个节点

节点之间通过**端口**连接，形成数据流图。

## 架构图

```
┌─────────────────────────────────────────────────┐
│                 Workflow Engine                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐     │
│  │ Node A  │───▶│ Node B  │───▶│ Node C  │     │
│  │ (输入)  │    │ (处理)  │    │ (输出)  │     │
│  └─────────┘    └─────────┘    └─────────┘     │
│       │              │              │           │
│       ▼              ▼              ▼           │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐     │
│  │ Node D  │───▶│ Node E  │───▶│ Node F  │     │
│  └─────────┘    └─────────┘    └─────────┘     │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 完整代码

### 1. 核心数据结构

```python
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Callable
from enum import Enum
import json
import time


class NodeType(Enum):
    """节点类型"""
    INPUT = "input"           # 输入节点
    PROCESS = "process"       # 处理节点
    OUTPUT = "output"         # 输出节点
    CONDITION = "condition"   # 条件节点
    MERGE = "merge"           # 合并节点
    SPLIT = "split"           # 分支节点


@dataclass
class Port:
    """节点端口"""
    name: str
    direction: str  # "input" 或 "output"
    data_type: str  # 数据类型（用于类型检查）
    connected_to: List[str] = field(default_factory=list)  # 连接的端口 ID


@dataclass
class Node:
    """工作流节点"""
    id: str
    name: str
    node_type: NodeType
    processor: Callable  # 处理函数
    inputs: Dict[str, Port] = field(default_factory=dict)
    outputs: Dict[str, Port] = field(default_factory=dict)
    config: Dict[str, Any] = field(default_factory=dict)
    position: tuple = (0, 0)  # 在画布上的位置


@dataclass
class Connection:
    """节点连接"""
    source_node_id: str
    source_port: str
    target_node_id: str
    target_port: str


@dataclass
class Workflow:
    """工作流"""
    id: str
    name: str
    nodes: Dict[str, Node] = field(default_factory=dict)
    connections: List[Connection] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
```

### 2. 工作流引擎

```python
class WorkflowEngine:
    """工作流执行引擎"""
    
    def __init__(self):
        self.workflows: Dict[str, Workflow] = {}
        self.execution_log: List[Dict] = []
    
    def create_workflow(self, name: str) -> Workflow:
        """创建新工作流"""
        workflow_id = f"wf_{int(time.time() * 1000)}"
        workflow = Workflow(id=workflow_id, name=name)
        self.workflows[workflow_id] = workflow
        return workflow
    
    def add_node(self, workflow_id: str, node: Node) -> None:
        """添加节点到工作流"""
        workflow = self.workflows.get(workflow_id)
        if workflow:
            workflow.nodes[node.id] = node
    
    def connect(
        self, 
        workflow_id: str,
        source_node_id: str,
        source_port: str,
        target_node_id: str,
        target_port: str
    ) -> None:
        """连接两个节点"""
        workflow = self.workflows.get(workflow_id)
        if workflow:
            connection = Connection(
                source_node_id=source_node_id,
                source_port=source_port,
                target_node_id=target_node_id,
                target_port=target_port
            )
            workflow.connections.append(connection)
    
    def execute(self, workflow_id: str, initial_input: Any = None) -> Any:
        """执行工作流"""
        workflow = self.workflows.get(workflow_id)
        if not workflow:
            raise ValueError(f"工作流不存在: {workflow_id}")
        
        # 拓扑排序确定执行顺序
        execution_order = self._topological_sort(workflow)
        
        # 执行节点
        node_outputs: Dict[str, Any] = {}
        
        for node_id in execution_order:
            node = workflow.nodes[node_id]
            
            # 收集输入
            inputs = self._collect_inputs(node, workflow, node_outputs)
            
            # 执行节点
            try:
                output = node.processor(inputs, node.config)
                node_outputs[node_id] = output
                
                self.execution_log.append({
                    "node_id": node_id,
                    "node_name": node.name,
                    "success": True,
                    "timestamp": time.time()
                })
            except Exception as e:
                self.execution_log.append({
                    "node_id": node_id,
                    "node_name": node.name,
                    "success": False,
                    "error": str(e),
                    "timestamp": time.time()
                })
                raise
        
        # 返回最终输出
        return node_outputs.get(execution_order[-1]) if execution_order else None
    
    def _topological_sort(self, workflow: Workflow) -> List[str]:
        """拓扑排序确定执行顺序"""
        # 构建邻接表和入度
        in_degree: Dict[str, int] = {node_id: 0 for node_id in workflow.nodes}
        adj: Dict[str, List[str]] = {node_id: [] for node_id in workflow.nodes}
        
        for conn in workflow.connections:
            adj[conn.source_node_id].append(conn.target_node_id)
            in_degree[conn.target_node_id] += 1
        
        # BFS 拓扑排序
        queue = [node_id for node_id, degree in in_degree.items() if degree == 0]
        order = []
        
        while queue:
            node_id = queue.pop(0)
            order.append(node_id)
            
            for neighbor in adj[node_id]:
                in_degree[neighbor] -= 1
                if in_degree[neighbor] == 0:
                    queue.append(neighbor)
        
        if len(order) != len(workflow.nodes):
            raise ValueError("工作流存在循环依赖")
        
        return order
    
    def _collect_inputs(
        self, 
        node: Node, 
        workflow: Workflow, 
        node_outputs: Dict[str, Any]
    ) -> Dict[str, Any]:
        """收集节点的输入数据"""
        inputs = {}
        
        for conn in workflow.connections:
            if conn.target_node_id == node.id:
                source_output = node_outputs.get(conn.source_node_id)
                inputs[conn.target_port] = source_output
        
        return inputs
    
    def to_json(self, workflow_id: str) -> str:
        """导出工作流为 JSON"""
        workflow = self.workflows.get(workflow_id)
        if not workflow:
            raise ValueError(f"工作流不存在: {workflow_id}")
        
        data = {
            "id": workflow.id,
            "name": workflow.name,
            "nodes": {
                node_id: {
                    "name": node.name,
                    "type": node.node_type.value,
                    "config": node.config,
                    "position": list(node.position)
                }
                for node_id, node in workflow.nodes.items()
            },
            "connections": [
                {
                    "source": f"{c.source_node_id}.{c.source_port}",
                    "target": f"{c.target_node_id}.{c.target_port}"
                }
                for c in workflow.connections
            ]
        }
        
        return json.dumps(data, indent=2, ensure_ascii=False)
    
    def from_json(self, json_str: str, processors: Dict[str, Callable]) -> str:
        """从 JSON 加载工作流"""
        data = json.loads(json_str)
        
        workflow = self.create_workflow(data["name"])
        
        for node_id, node_data in data["nodes"].items():
            processor = processors.get(node_data["type"], lambda x, c: x)
            node = Node(
                id=node_id,
                name=node_data["name"],
                node_type=NodeType(node_data["type"]),
                processor=processor,
                config=node_data.get("config", {}),
                position=tuple(node_data.get("position", [0, 0]))
            )
            self.add_node(workflow.id, node)
        
        for conn_data in data.get("connections", []):
            source_parts = conn_data["source"].split(".")
            target_parts = conn_data["target"].split(".")
            self.connect(
                workflow.id,
                source_parts[0], source_parts[1],
                target_parts[0], target_parts[1]
            )
        
        return workflow.id
```

### 3. 内置节点

```python
# 输入节点
def input_node(inputs: Dict, config: Dict) -> Any:
    """输入节点：返回配置的值"""
    return config.get("value", None)

# 处理节点
def process_node(inputs: Dict, config: Dict) -> Any:
    """处理节点：对输入执行转换"""
    data = inputs.get("input")
    operation = config.get("operation", "identity")
    
    if operation == "upper":
        return str(data).upper() if data else data
    elif operation == "lower":
        return str(data).lower() if data else data
    elif operation == "length":
        return len(str(data)) if data else 0
    elif operation == "reverse":
        return str(data)[::-1] if data else data
    else:
        return data

# 条件节点
def condition_node(inputs: Dict, config: Dict) -> Any:
    """条件节点：根据条件选择输出路径"""
    data = inputs.get("input")
    condition = config.get("condition", "truthy")
    
    if condition == "truthy":
        return "true" if data else "false"
    elif condition == "greater_than":
        threshold = config.get("threshold", 0)
        return "true" if (data or 0) > threshold else "false"
    else:
        return "true" if data else "false"

# 输出节点
def output_node(inputs: Dict, config: Dict) -> Any:
    """输出节点：返回输入数据"""
    return inputs.get("input")
```

## 使用示例

```python
# 创建引擎
engine = WorkflowEngine()

# 创建工作流
workflow = engine.create_workflow("数据处理流程")

# 添加节点
engine.add_node(workflow.id, Node(
    id="input",
    name="输入数据",
    node_type=NodeType.INPUT,
    processor=input_node,
    config={"value": "Hello World"}
))

engine.add_node(workflow.id, Node(
    id="process",
    name="转大写",
    node_type=NodeType.PROCESS,
    processor=process_node,
    config={"operation": "upper"}
))

engine.add_node(workflow.id, Node(
    id="output",
    name="输出结果",
    node_type=NodeType.OUTPUT,
    processor=output_node
))

# 连接节点
engine.connect(workflow.id, "input", "output", "process", "input")
engine.connect(workflow.id, "process", "output", "output", "input")

# 执行工作流
result = engine.execute(workflow.id)
print(f"结果: {result}")  # 输出: HELLO WORLD

# 导出为 JSON
json_str = engine.to_json(workflow.id)
print(json_str)
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 循环依赖 | 节点连接形成环 | 检查连接关系 |
| 节点未执行 | 输入端口未连接 | 检查连接 |
| 执行顺序错误 | 拓扑排序失败 | 检查依赖关系 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
