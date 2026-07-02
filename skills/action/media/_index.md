# 媒体处理 / Media

AI 处理图片、视频、音频的能力。

## 方案对比

| Skill | 依赖 | 适用场景 |
|-------|------|----------|
| [workflow-engine](workflow-engine/) | 无 | 构建可视化工作流、数据处理管道 |
| [image-generation](image-generation/) | requests + ComfyUI | 文生图、图生图 |
| [video-generation](video-generation/) | requests + ComfyUI | 视频生成 |
| [model-manager](model-manager/) | 无 | 管理和切换 AI 模型 |
| [workflow-serialization](workflow-serialization/) | 无 | 保存/加载工作流 |

## 选择建议

| 场景 | 推荐 Skill |
|------|-----------|
| 我想生成图片 | image-generation |
| 我想设计处理流程 | workflow-engine |
| 我想管理多个模型 | model-manager |
| 我想保存工作流 | workflow-serialization |
| 我想做复杂 pipeline | workflow-engine + image-generation |

## 组合使用

```
workflow-engine（设计流程）
    +
image-generation（生成图片）
    +
model-manager（管理模型）
    ↓
完整的 AI 图片处理系统
```
