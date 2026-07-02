---
name: UI 样式生成
layer: meta
category: ai-builder
status: unverified
description: >
  根据用户需求生成前端样式代码，支持 CSS、Tailwind、CSS-in-JS。
  当用户想要设计样式、美化界面、创建主题时触发。
  关键词：UI 样式、CSS、Tailwind、主题设计、界面美化。
---

# UI 样式生成

根据用户需求生成前端样式代码，支持多种样式方案。

## 核心理念

用户告诉 AI 想要什么样式，AI 生成对应的 CSS/Tailwind 代码。用户只需要描述"我要什么风格"，AI 负责"怎么实现"。

## 完整代码

### 1. CSS 样式生成器

```python
from typing import Dict, List


class CSSGenerator:
    """CSS 样式生成器"""
    
    def generate_theme(self, config: Dict) -> str:
        """
        生成主题样式
        
        config 示例:
        {
            "primaryColor": "#1890ff",
            "borderRadius": "8px",
            "fontFamily": "Arial, sans-serif"
        }
        """
        return f'''
:root {{
  --primary-color: {config.get("primaryColor", "#1890ff")};
  --border-radius: {config.get("borderRadius", "8px")};
  --font-family: {config.get("fontFamily", "Arial, sans-serif")};
  --text-color: #333;
  --bg-color: #f5f5f5;
  --card-bg: #fff;
  --shadow: 0 2px 8px rgba(0,0,0,0.1);
}}

* {{
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}}

body {{
  font-family: var(--font-family);
  color: var(--text-color);
  background-color: var(--bg-color);
}}

.card {{
  background: var(--card-bg);
  border-radius: var(--border-radius);
  box-shadow: var(--shadow);
  padding: 20px;
  margin: 10px;
}}

.button {{
  background: var(--primary-color);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: var(--border-radius);
  cursor: pointer;
}}

.button:hover {{
  opacity: 0.9;
}}
'''
    
    def generate_responsive_grid(self, columns: int = 3, gap: str = "20px") -> str:
        """生成响应式网格布局"""
        return f'''
.grid {{
  display: grid;
  grid-template-columns: repeat({columns}, 1fr);
  gap: {gap};
}}

@media (max-width: 768px) {{
  .grid {{
    grid-template-columns: 1fr;
  }}
}}

@media (max-width: 1024px) {{
  .grid {{
    grid-template-columns: repeat(2, 1fr);
  }}
}}
'''
    
    def generate_table_style(self) -> str:
        """生成表格样式"""
        return '''
.table {
  width: 100%;
  border-collapse: collapse;
  background: var(--card-bg);
  border-radius: var(--border-radius);
  overflow: hidden;
  box-shadow: var(--shadow);
}

.table th,
.table td {
  padding: 12px 15px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.table th {
  background: var(--primary-color);
  color: white;
  font-weight: 600;
}

.table tr:hover {
  background: #f9f9f9;
}
'''
```

### 2. Tailwind 样式生成器

```python
class TailwindGenerator:
    """Tailwind CSS 样式生成器"""
    
    def generate_dashboard_classes(self, config: Dict) -> Dict:
        """生成仪表盘的 Tailwind 类名"""
        return {
            "container": "p-6 max-w-7xl mx-auto",
            "statsGrid": "grid grid-cols-1 md:grid-cols-3 gap-6 mb-8",
            "statCard": "bg-white rounded-lg shadow-md p-6",
            "statValue": "text-3xl font-bold text-gray-900",
            "statLabel": "text-sm text-gray-500 mt-2",
            "chartCard": "bg-white rounded-lg shadow-md p-6 mb-6",
            "tableContainer": "bg-white rounded-lg shadow-md overflow-hidden",
            "table": "w-full",
            "tableHeader": "bg-gray-50 text-left text-sm font-semibold text-gray-700",
            "tableCell": "px-6 py-4 border-b border-gray-100",
            "button": "bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded",
            "input": "w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        }
    
    def generate_component_classes(self, component_type: str) -> Dict:
        """根据组件类型生成类名"""
        classes = {
            "card": {
                "wrapper": "bg-white rounded-lg shadow-md p-6",
                "title": "text-lg font-semibold mb-4",
                "content": "text-gray-600"
            },
            "form": {
                "wrapper": "space-y-4",
                "group": "flex flex-col",
                "label": "text-sm font-medium text-gray-700 mb-1",
                "input": "px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500",
                "button": "bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded"
            },
            "table": {
                "wrapper": "overflow-x-auto",
                "table": "min-w-full divide-y divide-gray-200",
                "header": "bg-gray-50 text-left text-sm font-semibold text-gray-700",
                "cell": "px-6 py-4 whitespace-nowrap text-sm text-gray-900"
            }
        }
        return classes.get(component_type, {})
```

## 使用示例

```python
# CSS 主题
css_gen = CSSGenerator()
theme_css = css_gen.generate_theme({
    "primaryColor": "#10b981",
    "borderRadius": "12px",
    "fontFamily": "Inter, sans-serif"
})

# Tailwind 类名
tailwind = TailwindGenerator()
classes = tailwind.generate_dashboard_classes({})
# 使用: <div className={classes.container}>...</div>
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 样式不生效 | 优先级问题 | 检查 CSS 选择器权重 |
| 响应式失效 | 断点错误 | 检查媒体查询 |
| Tailwind 类无效 | 未编译 | 检查 Tailwind 配置 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| Tailwind CSS | 3+ | 样式框架（用户项目） |
