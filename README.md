# CreateYouAI

Modular AI Skill repository. Build your own AI like stacking LEGO blocks.

模块化 AI Skill 仓库，像搭积木一样构建你自己的 AI。

---

## What is a Skill?

A Skill is a set of instructions for AI. When a user says "I want to do X", the AI reads the corresponding Skill and knows how to help.

Skill 是一份给 AI 看的说明书。用户说"我要做 X"，AI 读取对应的 Skill，就知道怎么帮用户实现。

---

## How it works / 工作原理

1. User describes what AI they want / 用户描述想做什么 AI
2. AI scans available Skills / AI 扫描可用的 Skill
3. AI picks the right combination / AI 挑选合适的组合
4. AI helps build it step by step / AI 帮用户逐步构建

---

## Available Skills

| Skill | Category | Description |
|-------|----------|-------------|
| [ai-builder](skills/ai-builder/) | 🧩 meta | Scan skills and help users build their AI / 扫描仓库，帮用户挑选组合 Skill |
| [voice-recognition](skills/audio/voice-recognition/) | 🎤 audio | Local speech recognition / 本地语音识别 |
| [contribute-skill](skills/contribute-skill/) | 🧩 meta | Submit new skills to the repository / 向仓库提交新 Skill |

---

## Quick Start / 快速开始

Tell your AI: "我想做一个 XX 的 AI" / 告诉你的 AI："我想做一个 XX 的 AI"

The AI will read the `ai-builder` Skill and automatically pick the right combination from this repository.

AI 会读取 `ai-builder` Skill，自动从仓库挑选合适的组合。

---

## Skill Categories / 分类

```
skills/
├── audio/       🎤 语音、音频
├── code/        💻 编程辅助
├── data/        📊 数据处理
├── file/        📁 文件操作
├── web/         🌐 网络请求
├── ui/          🖥️ 界面组件
├── memory/      🧠 记忆系统（短期/长期/上下文）
├── safety/      🛡️ 安全护栏（审核/过滤/对齐）
├── task/        📋 任务管理（规划/执行/跟踪）
├── learning/    📚 学习能力（知识获取/技能沉淀）
├── personality/ 🎭 人格/角色设定
├── tool/        🔧 工具调用（API/系统操作/外部服务）
├── conversation/💬 对话管理（多轮/上下文/压缩）
├── other/       📦 其他
└── ai-builder/  🧩 元能力：帮用户组合 Skill
```

---

## Contributing / 贡献

**Welcome to contribute! We need your skills. / 欢迎贡献！我们需要你的 Skill。**

Whether you have a working Skill, an idea for one, or want to improve existing ones — we'd love your help.

无论你有一个可用的 Skill、一个想法，还是想改进现有的 —— 我们都欢迎你的参与。

1. Fork this repository / Fork 本仓库
2. Write a Skill following [SKILL-FORMAT.md](SKILL-FORMAT.md) / 按 SKILL-FORMAT.md 写 Skill
3. Submit a PR / 提交 PR

Or tell your AI: "我想贡献一个 skill" / 或告诉你的 AI："我想贡献一个 skill"

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**What we need most / 我们最需要的**:

| Category | Skills needed / 需要的 Skill |
|----------|------------------------------|
| 🎤 audio | voice recognition, music generation, sound effects / 语音识别、音乐生成、音效 |
| 💻 code | code review, test generation, refactoring, documentation / 代码审查、测试生成、重构、文档 |
| 📊 data | CSV/JSON parsing, visualization, cleaning, analysis / 数据解析、可视化、清洗、分析 |
| 📁 file | file management, batch operations, format conversion / 文件管理、批量操作、格式转换 |
| 🌐 web | API calling, scraping, automation, monitoring / API 调用、爬虫、自动化、监控 |
| 🖥️ ui | component generation, layout, themes / 组件生成、布局、主题 |
| 🧠 memory | short-term/long-term memory, context management, summarization / 短期长期记忆、上下文管理、摘要 |
| 🛡️ safety | content filtering, output validation, alignment / 内容过滤、输出校验、对齐 |
| 📋 task | planning, scheduling, progress tracking / 规划、调度、进度跟踪 |
| 📚 learning | knowledge acquisition, skill extraction, adaptation / 知识获取、技能沉淀、自适应 |
| 🎭 personality | character design, tone control, role playing / 角色设计、语气控制、角色扮演 |
| 🔧 tool | API integration, system commands, external services / API 集成、系统命令、外部服务 |
| 💬 conversation | multi-turn, context compression, topic switching / 多轮对话、上下文压缩、话题切换 |

---

## License

MIT
