---
name: UI 布局生成
layer: meta
category: ai-builder
status: unverified
description: >
  根据用户需求生成前端 UI 布局代码，支持多种框架。
  当用户想要设计界面布局、创建页面结构、生成 UI 组件时触发。
  关键词：UI 布局、页面设计、界面结构、组件生成、前端布局。
---

# UI 布局生成

根据用户需求生成前端 UI 布局代码，支持 React、Vue、HTML 等多种框架。

## 核心理念

用户告诉 AI 想要什么界面，AI 生成对应的布局代码。用户只需要描述"我要什么"，AI 负责"怎么实现"。

## 前端与后端的打通

```
用户：我要一个仪表盘
    ↓
AI 生成 UI 布局代码
    ↓
UI 代码调用后端 API
    ↓
后端执行功能，返回数据
    ↓
UI 显示结果
```

## 完整代码

### 1. React 布局生成器

```python
from typing import Dict, List, Optional
from dataclasses import dataclass


@dataclass
class UIComponent:
    """UI 组件"""
    name: str
    component_type: str  # "container", "text", "button", "table", "chart", "form"
    props: Dict = None
    children: List['UIComponent'] = None
    
    def __post_init__(self):
        if self.props is None:
            self.props = {}
        if self.children is None:
            self.children = []


class ReactLayoutGenerator:
    """React 布局生成器"""
    
    def generate_dashboard(self, config: Dict) -> str:
        """
        生成仪表盘布局
        
        config 示例:
        {
            "title": "数据分析仪表盘",
            "stats": ["用户数", "订单数", "收入"],
            "charts": ["折线图", "饼图"],
            "tables": ["最近订单"]
        }
        """
        stats_html = ""
        for stat in config.get("stats", []):
            stats_html += f'''
            <div className="stat-card">
              <h3>{stat}</h3>
              <p className="stat-value">--</p>
            </div>'''
        
        charts_html = ""
        for chart in config.get("charts", []):
            charts_html += f'''
            <div className="chart-card">
              <h3>{chart}</h3>
              <div className="chart-placeholder">[{chart} 占位]</div>
            </div>'''
        
        tables_html = ""
        for table in config.get("tables", []):
            tables_html += f'''
            <div className="table-card">
              <h3>{table}</h3>
              <table>
                <thead><tr><th>列1</th><th>列2</th><th>列3</th></tr></thead>
                <tbody><tr><td>--</td><td>--</td><td>--</td></tr></tbody>
              </table>
            </div>'''
        
        return f'''
import React from 'react';

export default function Dashboard() {{
  return (
    <div className="dashboard">
      <h1>{config.get("title", "仪表盘")}</h1>
      
      <div className="stats-grid">
        {stats_html}
      </div>
      
      <div className="charts-grid">
        {charts_html}
      </div>
      
      <div className="tables-grid">
        {tables_html}
      </div>
    </div>
  );
}}
'''
    
    def generate_form(self, config: Dict) -> str:
        """
        生成表单布局
        
        config 示例:
        {
            "title": "用户注册",
            "fields": [
                {"name": "username", "type": "text", "label": "用户名", "required": true},
                {"name": "email", "type": "email", "label": "邮箱", "required": true},
                {"name": "password", "type": "password", "label": "密码", "required": true}
            ],
            "submitText": "注册"
        }
        """
        fields_html = ""
        for field in config.get("fields", []):
            required = "required" if field.get("required") else ""
            fields_html += f'''
            <div className="form-group">
              <label>{field.get("label", field["name"])}</label>
              <input type="{field.get("type", "text")}" name="{field["name"]}" {required} />
            </div>'''
        
        return f'''
import React, {{ useState }} from 'react';

export default function Form() {{
  const handleSubmit = (e) => {{
    e.preventDefault();
    // TODO: 调用后端 API
    console.log('提交表单');
  }};
  
  return (
    <form onSubmit={{handleSubmit}}>
      <h2>{config.get("title", "表单")}</h2>
      {fields_html}
      <button type="submit">{config.get("submitText", "提交")}</button>
    </form>
  );
}}
'''
    
    def generate_list(self, config: Dict) -> str:
        """
        生成列表布局
        
        config 示例:
        {
            "title": "项目列表",
            "columns": ["名称", "状态", "操作"],
            "actions": ["编辑", "删除"]
        }
        """
        columns_html = "".join(f"<th>{col}</th>" for col in config.get("columns", []))
        actions_html = "".join(f"<button>{act}</button>" for act in config.get("actions", []))
        
        return f'''
import React from 'react';

export default function List() {{
  const [items, setItems] = React.useState([]);
  
  return (
    <div className="list-container">
      <h2>{config.get("title", "列表")}</h2>
      <table>
        <thead>
          <tr>
            {columns_html}
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          {{items.map(item => (
            <tr key={{item.id}}>
              <td>{{item.name}}</td>
              <td>{{item.status}}</td>
              <td>{actions_html}</td>
            </tr>
          ))}}
        </tbody>
      </table>
    </div>
  );
}}
'''
```

### 2. Vue 布局生成器

```python
class VueLayoutGenerator:
    """Vue 布局生成器"""
    
    def generate_component(self, name: str, template: str, style: str = "") -> str:
        """生成 Vue 组件"""
        return f'''
<template>
{template}
</template>

<script setup>
import {{ ref }} from 'vue';

// 组件逻辑
</script>

{chr(10)}<style scoped>
{style}
</style>
'''
    
    def generate_dashboard(self, config: Dict) -> str:
        """生成 Vue 仪表盘"""
        return self.generate_component(
            "Dashboard",
            f'''<div class="dashboard">
  <h1>{config.get("title", "仪表盘")}</h1>
  <div class="stats">
    <!-- 统计卡片 -->
  </div>
  <div class="charts">
    <!-- 图表 -->
  </div>
</div>''',
            '''
.dashboard { padding: 20px; }
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
'''
        )
```

## 使用示例

```python
# React 布局
generator = ReactLayoutGenerator()

# 生成仪表盘
dashboard_code = generator.generate_dashboard({
    "title": "销售数据仪表盘",
    "stats": ["总销售额", "订单数", "客户数"],
    "charts": ["月度趋势", "产品分布"],
    "tables": ["最近订单"]
})

# 生成表单
form_code = generator.generate_form({
    "title": "创建项目",
    "fields": [
        {"name": "name", "type": "text", "label": "项目名称", "required": True},
        {"name": "description", "type": "textarea", "label": "项目描述"}
    ],
    "submitText": "创建"
})

# Vue 布局
vue_gen = VueLayoutGenerator()
vue_code = vue_gen.generate_dashboard({"title": "管理后台"})
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 组件不渲染 | 缺少依赖 | 检查 import 语句 |
| 样式不生效 | CSS 类名错误 | 检查 className |
| 数据不更新 | 状态未管理 | 添加 useState/useReducer |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| React | 18+ | 前端框架（用户项目） |
| Vue | 3+ | 前端框架（用户项目） |
