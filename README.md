# youAI

Modular AI Skill repository. Build your own AI like stacking LEGO blocks.

模块化 AI Skill 仓库，像搭积木一样构建你自己的 AI。

---

## What is a Skill?

A Skill is a set of instructions for AI. When a user says "I want to do X", the AI reads the corresponding Skill and knows how to help.

Skill 是一份给 AI 看的说明书。用户说"我要做 X"，AI 读取对应的 Skill，就知道怎么帮用户实现。

**Example / 举例**：用户说"我想给应用加语音识别"，AI 读取 `voice-recognition` Skill，就知道要安装什么、改哪些代码、怎么排查问题。

---

## Available Skills

| Skill | Status | Description |
|-------|--------|-------------|
| [voice-recognition](skills/voice-recognition/) | ✅ Ready | Local speech recognition (4 recording solutions + funasr local model) / 本地语音识别（4 种录音方案 + funasr 本地模型） |

---

## Quick Start / 快速开始

1. Find the Skill you need / 找到你需要的 Skill
2. Give `SKILL.md` to your AI tool (paste, reference, or put in project directory) / 把 `SKILL.md` 给你的 AI 工具
3. AI reads it and follows the instructions / AI 读取后按指引执行

---

## Contributing / 贡献

1. Fork this repository / Fork 本仓库
2. Write a new Skill following [SKILL-FORMAT.md](SKILL-FORMAT.md) / 按照 SKILL-FORMAT.md 写一个新 Skill
3. Submit a PR / 提交 PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for details. / 详见 CONTRIBUTING.md。

---

## Skill Format / Skill 格式

See [SKILL-FORMAT.md](SKILL-FORMAT.md).

```
skills/<skill-name>/
├── SKILL.md              # Required: instructions for AI / 必须：给 AI 的指令文档
└── scripts/              # Optional: executable scripts / 可选：可执行脚本
```

---

## License

MIT
