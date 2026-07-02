# UI Skills / 前端实现

帮用户生成前端 UI 代码，与后端 Skill 打通。

## Skills

| Skill | 功能 | 和后端的关系 |
|-------|------|-------------|
| [ui-layout](ui-layout.md) | UI 布局生成（React/Vue） | 生成调用后端 API 的 UI |
| [ui-styling](ui-styling.md) | 样式生成（CSS/Tailwind） | 无直接关系 |
| [api-client](api-client.md) | 前端 API 客户端 | 打通前后端 |

## 使用时机

```
用户确定设计后
    ↓
加载 ui/ 下的 Skill
    ↓
生成前端代码
    ↓
前端调用后端 API
```

## 组合使用

- ui-layout + api-client = 完整的前端应用
- ui-styling + ui-layout = 美观的界面
- api-client + 后端 Skill = 前后端打通
