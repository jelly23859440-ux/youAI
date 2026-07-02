# Action Skills / 执行能力层

Agent 能"做事"的能力——代码、网络、文件、设备操作。

## 多实现并列说明

同一功能可能有多个实现方案（如语音识别有 funasr、whisper、google 三种）。这种情况下：

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

### Code / 代码操作

| Skill | 依赖 | 说明 |
|-------|------|------|
| [git-diff-analyzer](code/git-diff-analyzer/SKILL.md) | git CLI | Git Diff 分析器，生成结构化变更报告 |
| [code-search](code/code-search/SKILL.md) | ripgrep | 代码搜索工具，支持正则表达式 |
| [code-sandbox](code/code-sandbox/SKILL.md) | Docker/bwrap | 代码沙箱执行，安全运行用户代码 |

### Web / 网络操作

| Skill | 依赖 | 说明 |
|-------|------|------|
| [web-fetch](web/web-fetch/SKILL.md) | requests + beautifulsoup4 | Web 抓取 + Markdown 转换 |
| [api-tester](web/api-tester/SKILL.md) | requests | REST API 测试工具 |

### File / 文件操作

| Skill | 依赖 | 说明 |
|-------|------|------|
| [pdf-reader](file/pdf-reader/SKILL.md) | PyPDF2/pypdf | PDF 读取 + 页面提取 |
| [csv-json-converter](file/csv-json-converter/SKILL.md) | 无 | CSV/JSON 数据转换 |
| [image-processor](file/image-processor/SKILL.md) | Pillow | 图片裁剪、缩放、格式转换 |
| [log-analyzer](file/log-analyzer/SKILL.md) | 无 | 日志分析器，提取错误和统计 |

### Device / 设备交互

| Skill | 依赖 | 说明 |
|-------|------|------|
| [voice-recognition](device/voice-recognition/) | Python | 本地语音识别（多方案：funasr/whisper/google） |
| [ssh-remote](device/ssh-remote/SKILL.md) | paramiko | SSH 远程执行 + SFTP |
| [email-sender](device/email-sender/SKILL.md) | 无（内置） | 邮件发送（文本/HTML/附件） |

### Media / 媒体处理

| Skill | 依赖 | 说明 |
|-------|------|------|
| [workflow-engine](media/workflow-engine/SKILL.md) | 无 | 节点式工作流引擎 |
| [image-generation](media/image-generation/SKILL.md) | requests + ComfyUI | 图片生成 |
| [video-generation](media/video-generation/SKILL.md) | requests + ComfyUI | 视频生成 |
| [model-manager](media/model-manager/SKILL.md) | 无 | 模型管理 |
| [workflow-serialization](media/workflow-serialization/SKILL.md) | 无 | 工作流序列化 |

## 快速安装

```bash
# 代码操作
pip install requests beautifulsoup4  # web-fetch
# ripgrep 需要单独安装: https://github.com/BurntSushi/ripgrep

# 文件操作
pip install PyPDF2 Pillow  # pdf-reader + image-processor

# 设备交互
pip install paramiko  # ssh-remote
```

零依赖 Skill（直接可用）：
- csv-json-converter
- log-analyzer
- email-sender（Python 内置 smtplib）
