---
name: Git 自动备份
layer: action
category: tool
status: verified
description: >
  为项目添加 git 自动备份功能，文件变化时自动提交，防止代码丢失。
  当用户想要保护代码、防止误操作、需要回滚能力时触发。
  关键词：git、备份、回滚、版本控制、自动提交。
---

# Git 自动备份

为项目添加 git 自动备份能力，像 Trae 一样自动保存代码版本。

## 能力概览

| 能力 | 说明 |
|------|------|
| 自动提交 | 文件变化时自动 git commit |
| 被动检测 | 文件变动触发，不轮询 |
| 版本保留 | 保留最近 N 个版本，自动清理旧的 |
| 一键恢复 | git checkout 恢复到任意版本 |

## 使用方法

### Step 1：初始化 git 仓库

```bash
cd 你的项目目录
git init
git config user.email "your@email.com"
git config user.name "YourName"
```

### Step 2：创建 .gitignore

```gitignore
# 排除不需要备份的
__pycache__/
node_modules/
*.pyc
*.tmp
memory_data/
workspace/
```

### Step 3：首次提交

```bash
git add -A
git commit -m "初始提交"
```

### Step 4：运行自动备份脚本

```powershell
# Windows PowerShell
powershell -File auto_commit.ps1
```

> 脚本文件见 `auto_commit.ps1`，修改 `$repoPath` 为你的项目路径即可使用。

## 自动备份脚本

完整脚本见 [auto_commit.ps1](auto_commit.ps1)。

**核心功能：**
- 被动检测：文件变化时自动触发，不轮询
- 自动提交：变化后自动 `git add -A && git commit`
- 版本保留：保留最近 50 个版本，自动清理旧的

## 恢复方法

```bash
# 查看历史版本
git log --oneline

# 恢复到指定版本
git checkout <commit-id>

# 撤销所有修改（回到最后一次提交）
git checkout .
```

## 注意事项

- 使用前确保项目已初始化 git 仓库
- 首次使用前建议手动 `git commit` 一次
- `.gitignore` 排除大文件（node_modules、models 等）
- 建议保留最近 50 个版本，避免占用过多磁盘空间
