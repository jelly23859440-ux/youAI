# Media Skills / 媒体处理层

AI 处理图片、视频、音频的能力。

## 多实现并列说明

同一功能可能有多个实现方案。这种情况下：

```
功能目录/
├── _index.md        # 方案对比表 + 选择建议
├── variant-a/
│   └── SKILL.md     # 方案 A
└── variant-b/
    └── SKILL.md     # 方案 B
```

AI 根据用户环境自动选择最佳方案。

## Skills

| Skill | 依赖 | 说明 |
|-------|------|------|
| [workflow-engine](workflow-engine/SKILL.md) | 无 | 节点式工作流引擎 |
| [image-generation](image-generation/SKILL.md) | requests + ComfyUI | 图片生成 |
| [video-generation](video-generation/SKILL.md) | requests + ComfyUI | 视频生成 |
| [model-manager](model-manager/SKILL.md) | 无 | 模型管理 |
| [workflow-serialization](workflow-serialization/SKILL.md) | 无 | 工作流序列化 |

## 快速安装

```bash
# 图片/视频生成需要 ComfyUI
# 安装 ComfyUI: https://github.com/comfyanonymous/ComfyUI

# Python 依赖
pip install requests
```

## 组合使用

媒体处理 Skill 可以组合使用：
- workflow-engine + image-generation = 自动化图片生成流水线
- workflow-engine + video-generation = 自动化视频生成流水线
- image-generation + model-manager = 多模型图片生成
