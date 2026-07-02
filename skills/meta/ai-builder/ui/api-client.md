---
name: 前端 API 客户端
layer: meta
category: ai-builder
status: unverified
description: >
  生成前端调用后端 API 的客户端代码，支持 REST 和 WebSocket。
  当用户想要前后端打通、调用后端接口、实现实时通信时触发。
  关键词：API 客户端、前后端通信、REST 调用、WebSocket、接口对接。
---

# 前端 API 客户端

生成前端调用后端 API 的客户端代码，让前端能调用后端 Skill 提供的功能。

## 核心理念

前端需要调用后端的 API 来获取数据和执行操作。本 Skill 生成标准化的 API 客户端代码。

## 完整代码

### 1. REST API 客户端

```python
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import json


@dataclass
class APIClient:
    """REST API 客户端"""
    
    base_url: str
    timeout: int = 30
    
    def get(self, endpoint: str, params: Dict = None) -> Dict:
        """GET 请求"""
        return self._request("GET", endpoint, params=params)
    
    def post(self, endpoint: str, data: Any = None) -> Dict:
        """POST 请求"""
        return self._request("POST", endpoint, data=data)
    
    def put(self, endpoint: str, data: Any = None) -> Dict:
        """PUT 请求"""
        return self._request("PUT", endpoint, data=data)
    
    def delete(self, endpoint: str) -> Dict:
        """DELETE 请求"""
        return self._request("DELETE", endpoint)
    
    def _request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """发送请求"""
        # 生成 JavaScript 代码
        url = f"{self.base_url}{endpoint}"
        
        js_code = f'''
fetch("{url}", {{
  method: "{method}",{(f'''
  headers: {{
    "Content-Type": "application/json"
  }},''' if method in ["POST", "PUT"] else "")}
  {(f"body: JSON.stringify({json.dumps(kwargs.get('data', {}))})," if kwargs.get('data') else "")}
}})
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error("Error:", error));
'''
        
        return {"code": js_code, "description": f"{method} {endpoint}"}
    
    def generate_client_code(self) -> str:
        """生成完整的 API 客户端代码"""
        return f'''
// API 客户端
const API_BASE_URL = "{self.base_url}";

async function apiRequest(endpoint, options = {}) {{
  const url = `${{API_BASE_URL}}${{endpoint}}`;
  
  const response = await fetch(url, {{
    ...options,
    headers: {{
      "Content-Type": "application/json",
      ...options.headers
    }}
  }});
  
  if (!response.ok) {{
    throw new Error(`API error: ${{response.status}}`);
  }}
  
  return response.json();
}}

// GET 请求
export async function get(endpoint, params = {{}}) {{
  const queryString = new URLSearchParams(params).toString();
  const url = queryString ? `${{endpoint}}?${{queryString}}` : endpoint;
  return apiRequest(url);
}}

// POST 请求
export async function post(endpoint, data) {{
  return apiRequest(endpoint, {{
    method: "POST",
    body: JSON.stringify(data)
  }});
}}

// PUT 请求
export async function put(endpoint, data) {{
  return apiRequest(endpoint, {{
    method: "PUT",
    body: JSON.stringify(data)
  }});
}}

// DELETE 请求
export async function del(endpoint) {{
  return apiRequest(endpoint, {{ method: "DELETE" }});
}}
'''
```

### 2. WebSocket 客户端

```python
class WebSocketClient:
    """WebSocket 客户端"""
    
    def __init__(self, url: str):
        self.url = url
    
    def generate_client_code(self) -> str:
        """生成 WebSocket 客户端代码"""
        return f'''
// WebSocket 客户端
const ws = new WebSocket("{self.url}");

ws.onopen = () => {{
  console.log("Connected to server");
}};

ws.onmessage = (event) => {{
  const data = JSON.parse(event.data);
  console.log("Received:", data);
  // 处理消息
}};

ws.onerror = (error) => {{
  console.error("WebSocket error:", error);
}};

ws.onclose = () => {{
  console.log("Disconnected from server");
}};

// 发送消息
function sendMessage(data) {{
  ws.send(JSON.stringify(data));
}}
'''
    
    def generate_reconnection_code(self) -> str:
        """生成带重连的 WebSocket 客户端代码"""
        return f'''
// 带重连的 WebSocket 客户端
class ReconnectWebSocket {{
  constructor(url, maxRetries = 5) {{
    this.url = url;
    this.maxRetries = maxRetries;
    this.retryCount = 0;
    this.connect();
  }}
  
  connect() {{
    this.ws = new WebSocket(this.url);
    
    this.ws.onopen = () => {{
      console.log("Connected");
      this.retryCount = 0;
    }};
    
    this.ws.onmessage = (event) => {{
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    }};
    
    this.ws.onclose = () => {{
      if (this.retryCount < this.maxRetries) {{
        this.retryCount++;
        const delay = Math.min(1000 * Math.pow(2, this.retryCount), 30000);
        console.log(`Reconnecting in ${{delay}}ms...`);
        setTimeout(() => this.connect(), delay);
      }}
    }};
  }}
  
  handleMessage(data) {{
    // 处理消息
    console.log("Received:", data);
  }}
  
  send(data) {{
    this.ws.send(JSON.stringify(data));
  }}
}}
'''
```

### 3. React Hook 封装

```python
def generate_api_hook(service_name: str, endpoints: List[Dict]) -> str:
    """生成 React Hook 封装的 API 调用"""
    
    hook_code = f'''
import {{ useState, useCallback }} from 'react';

const API_BASE = process.env.REACT_APP_API_URL || "http://localhost:8000";

export function use{service_name.title().replace("-", "")}() {{
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  const request = useCallback(async (endpoint, options = {{}}) => {{
    setLoading(true);
    setError(null);
    
    try {{
      const response = await fetch(`${{API_BASE}}${{endpoint}}`, {{
        ...options,
        headers: {{
          "Content-Type": "application/json",
          ...options.headers
        }}
      }});
      
      if (!response.ok) {{
        throw new Error(`HTTP ${{response.status}}`);
      }}
      
      return await response.json();
    }} catch (err) {{
      setError(err.message);
      throw err;
    }} finally {{
      setLoading(false);
    }}
  }}, []);
  
  return {{ loading, error, request }};
}}
'''
    
    return hook_code
```

## 使用示例

```python
# REST 客户端
client = APIClient(base_url="http://localhost:8000/api")
code = client.generate_client_code()
print(code)

# WebSocket 客户端
ws = WebSocketClient("ws://localhost:8000/ws")
ws_code = ws.generate_client_code()
print(ws_code)

# React Hook
hook_code = generate_api_hook("user", [
    {"path": "/users", "method": "GET"},
    {"path": "/users", "method": "POST"}
])
print(hook_code)
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| CORS 错误 | 后端未配置跨域 | 检查后端 CORS 设置 |
| 连接失败 | WebSocket URL 错误 | 检查 ws:// 或 wss:// |
| 数据格式错误 | Content-Type 不对 | 检查请求头 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| fetch API | 浏览器内置 | HTTP 请求 |
| WebSocket | 浏览器内置 | 实时通信 |
