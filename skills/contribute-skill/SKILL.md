---
name: 贡献 Skill 到 youAI
description: >
  帮助用户向 youAI 仓库提交新的 Skill。
  当用户想要分享自己的 Skill、贡献代码、提交 PR 时触发。
  关键词：贡献、提交、PR、分享 skill、添加 skill、contribute。
---

# 向 youAI 贡献 Skill

帮用户把写好的 Skill 提交到 youAI 仓库。

## 执行流程

### Step 1：检查用户是否已 Fork

```bash
git remote -v
```

如果没有 Fork，先引导用户 Fork：
1. 打开 https://github.com/jelly23859440-ux/youAI
2. 点右上角 Fork
3. 克隆 Fork 后的仓库：`git clone https://github.com/<用户名>/youAI.git`

### Step 2：检查 SKILL.md 格式

读取用户写的 SKILL.md，检查以下内容：

**必须项**：
- [ ] YAML Frontmatter 存在（name + description）
- [ ] description 包含触发关键词
- [ ] 有功能说明
- [ ] 有安装步骤（带验证命令）
- [ ] 有代码示例（可直接复制）
- [ ] 有依赖版本号（不写"最新版"）

**禁止项**：
- [ ] 无个人路径（如 `D:\Users\xxx\...`）
- [ ] 无个人设备名（如 `Microphone (Shure MV51)`）
- [ ] 无密码、Token、密钥

如果不符合，告诉用户具体哪里要改。

### Step 3：放入正确目录

根据 Skill 的 category 放入对应目录：

```
skills/
├── audio/          # 语音、音频相关
├── code/           # 编程辅助
├── data/           # 数据处理
├── file/           # 文件操作
├── web/            # 网络请求
├── ui/             # 界面组件
├── other/          # 其他
└── contribute-skill/  # 本 Skill
```

如果没有对应目录，创建一个。

### Step 4：创建分支并提交

```bash
# 创建新分支
git checkout -b skill/<skill-name>

# 添加文件
git add skills/<category>/<skill-name>/SKILL.md

# 提交
git commit -m "feat: 添加 <skill-name> skill"

# 推送（如果报 SSL/连接错误，先执行：git config --global http.sslBackend schannel）
git push -u origin skill/<skill-name>
```

### Step 5：创建 PR

```bash
gh pr create \
  --title "feat: 添加 <skill-name> skill" \
  --body "$(cat <<'EOF'
## Skill 信息

- **名称**：<skill-name>
- **用途**：<一句话说明>
- **分类**：<category>
- **平台**：<electron / web / python / universal>
- **测试环境**：<操作系统、AI 工具>
- **依赖**：<需要安装什么>

## Checklist

- [ ] SKILL.md 格式符合 SKILL-FORMAT.md
- [ ] 代码示例可直接复制使用
- [ ] 无个人路径/密码/Token
- [ ] 已在至少一个 AI 工具中测试通过
EOF
)"
```

如果没有 `gh` 命令，告诉用户手动去 GitHub 创建 PR：
1. 打开 https://github.com/jelly23859440-ux/youAI
2. 点 "Compare & pull request"
3. 填写 PR 标题和描述

## 注意事项

- 分支名格式：`skill/<skill-name>`
- PR 标题格式：`feat: 添加 <skill-name> skill`
- 一个 PR 只提交一个 Skill
- 提交前先 `git pull origin main` 确保最新

## 常见问题

| 错误 | 原因 | 解决 |
|------|------|------|
| `Failed to connect to github.com port 443` | SSL 配置问题 | `git config --global http.sslBackend schannel` |
| `Permission denied` | 未登录 GitHub | `gh auth login` 或用浏览器授权 |
| `remote: Permission to denied` | 没有 Fork | 先 Fork 仓库再提交 |
| `CONFLICT` | 本地不是最新 | `git pull origin main` 后重试 |
