---
name: Git Diff 分析器
layer: action
category: code
description: >
  读取 git diff 输出，分析代码变更，生成结构化的变更报告。
  当用户想要查看代码变更、分析提交历史、生成变更报告、
  按作者或时间筛选改动时触发。
  关键词：git diff、代码变更、变更报告、提交历史、代码审查、code review。
---

# Git Diff 分析器

解析 `git diff` 输出，生成结构化变更报告，支持多维度筛选。

## 能力概览

| 能力 | 说明 |
|------|------|
| 变更分析 | 解析 unified diff，提取文件级/行级变更 |
| 报告生成 | 输出 JSON/Markdown 格式的变更摘要 |
| 多维筛选 | 按文件名、作者、时间范围过滤 |
| 统计汇总 | 新增/删除/修改行数统计 |
| 重命名支持 | 正确识别重命名文件 |

## 前置条件

- Git 已安装并在 PATH 中
- Python 3.8+

## 安装步骤

无需额外安装，使用 Python 标准库即可。

## 使用方法

### 完整代码

```python
import subprocess
import re
import json
import argparse
from dataclasses import dataclass, field
from typing import List, Dict, Optional


@dataclass
class FileChange:
    """文件变更信息"""
    filename: str
    old_filename: Optional[str] = None  # 重命名时的旧文件名
    additions: int = 0
    deletions: int = 0
    status: str = "modified"  # added, deleted, modified, renamed


@dataclass
class DiffReport:
    """Diff 分析报告"""
    total_additions: int = 0
    total_deletions: int = 0
    files: List[FileChange] = field(default_factory=list)


def run_git(args: List[str], repo_path: str = ".") -> str:
    """
    统一的 Git 命令执行函数
    
    Args:
        args: git 命令参数列表
        repo_path: 仓库路径
        
    Returns:
        git 命令输出
        
    Raises:
        RuntimeError: git 命令执行失败
    """
    try:
        result = subprocess.run(
            ["git"] + args,
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"Git 命令失败: {' '.join(args)}\n{result.stderr}")
        
        return result.stdout
        
    except FileNotFoundError:
        raise RuntimeError("Git 未安装或不在 PATH 中")
    except Exception as e:
        raise RuntimeError(f"Git 命令执行错误: {e}")


def get_diff(repo_path: str = ".") -> str:
    """获取当前工作区的 diff 输出"""
    return run_git(["diff"], repo_path)


def get_staged_diff(repo_path: str = ".") -> str:
    """获取已暂存的 diff 输出"""
    return run_git(["diff", "--cached"], repo_path)


def get_diff_between(
    commit1: str, 
    commit2: str, 
    repo_path: str = "."
) -> str:
    """获取两个提交之间的 diff"""
    return run_git(["diff", commit1, commit2], repo_path)


def parse_diff(diff_text: str) -> DiffReport:
    """
    解析 unified diff 输出
    
    支持重命名文件检测：
    - diff --git a/old.py b/new.py
    - rename from old.py
    - rename to new.py
    """
    report = DiffReport()
    current_file = None
    is_rename = False
    
    for line in diff_text.split("\n"):
        if line.startswith("diff --git"):
            # 解析文件名：diff --git a/file.py b/file.py
            match = re.search(r"b/(.+)$", line)
            if match:
                current_file = FileChange(filename=match.group(1))
                report.files.append(current_file)
                is_rename = False
        
        elif line.startswith("rename from"):
            # 重命名检测
            if current_file:
                old_name = line[len("rename from "):].strip()
                current_file.old_filename = old_name
                is_rename = True
        
        elif line.startswith("rename to"):
            # 重命名检测
            if current_file and is_rename:
                current_file.status = "renamed"
        
        elif line.startswith("+") and not line.startswith("+++"):
            if current_file:
                current_file.additions += 1
                report.total_additions += 1
        
        elif line.startswith("-") and not line.startswith("---"):
            if current_file:
                current_file.deletions += 1
                report.total_deletions += 1
    
    return report


def get_file_status(filename: str, repo_path: str = ".") -> str:
    """
    获取文件状态（added/deleted/modified/renamed）
    
    解析 git status --porcelain 输出：
    - M  filename (modified)
    - A  filename (added)
    - D  filename (deleted)
    - R  old -> new (renamed)
    - ?? filename (untracked)
    """
    output = run_git(["status", "--porcelain", filename], repo_path)
    
    line = output.strip()
    if not line:
        return "modified"  # 默认回退
    
    # --porcelain 格式: XY filename 或 XY "old" -> "new"
    status_code = line[:2].strip()
    
    status_map = {
        "A": "added",
        "D": "deleted",
        "R": "renamed",
        "M": "modified",
        "??": "untracked",
    }
    
    return status_map.get(status_code[0], "modified")


def analyze(repo_path: str = ".") -> DiffReport:
    """分析当前工作区变更"""
    diff_text = get_diff(repo_path)
    if not diff_text:
        diff_text = get_staged_diff(repo_path)

    report = parse_diff(diff_text)

    for file_change in report.files:
        file_change.status = get_file_status(file_change.filename, repo_path)

    return report


def analyze_commit(commit_hash: str, repo_path: str = ".") -> DiffReport:
    """
    分析单个提交的变更
    
    Args:
        commit_hash: 提交哈希
        repo_path: 仓库路径
        
    Returns:
        DiffReport 对象
    """
    # 获取提交的 diff
    diff_text = run_git(
        ["diff", f"{commit_hash}~1", commit_hash], 
        repo_path
    )
    
    return parse_diff(diff_text)


def analyze_commits(
    author: str = None,
    since: str = None,
    until: str = None,
    repo_path: str = "."
) -> List[Dict]:
    """
    分析多个提交的变更
    
    Args:
        author: 按作者筛选
        since: 起始日期 (YYYY-MM-DD)
        until: 结束日期 (YYYY-MM-DD)
        repo_path: 仓库路径
        
    Returns:
        提交列表，每个提交包含 diff 统计
    """
    cmd = ["log", "--pretty=format:%H|%an|%ae|%ad|%s", "--date=iso"]
    
    if author:
        cmd.append(f"--author={author}")
    if since:
        cmd.append(f"--since={since}")
    if until:
        cmd.append(f"--until={until}")
    
    output = run_git(cmd, repo_path)
    
    commits = []
    for line in output.strip().split("\n"):
        if not line:
            continue
        parts = line.split("|")
        if len(parts) == 5:
            commit_hash = parts[0]
            
            # 获取每个提交的 diff 统计
            try:
                diff_report = analyze_commit(commit_hash, repo_path)
                commits.append({
                    "hash": commit_hash,
                    "author_name": parts[1],
                    "author_email": parts[2],
                    "date": parts[3],
                    "message": parts[4],
                    "files_changed": len(diff_report.files),
                    "additions": diff_report.total_additions,
                    "deletions": diff_report.total_deletions,
                })
            except Exception:
                # 如果获取 diff 失败，只记录基本信息
                commits.append({
                    "hash": commit_hash,
                    "author_name": parts[1],
                    "author_email": parts[2],
                    "date": parts[3],
                    "message": parts[4],
                    "files_changed": 0,
                    "additions": 0,
                    "deletions": 0,
                })
    
    return commits


def to_json(report: DiffReport) -> dict:
    """转换为 JSON 格式"""
    return {
        "summary": {
            "total_files": len(report.files),
            "total_additions": report.total_additions,
            "total_deletions": report.total_deletions,
        },
        "files": [
            {
                "filename": f.filename,
                "old_filename": f.old_filename,
                "additions": f.additions,
                "deletions": f.deletions,
                "status": f.status,
            }
            for f in report.files
        ],
    }


def to_markdown(report: DiffReport) -> str:
    """转换为 Markdown 报告"""
    lines = [
        "# Git Diff 变更报告\n",
        f"**文件数**: {len(report.files)}",
        f"**新增行数**: +{report.total_additions}",
        f"**删除行数**: -{report.total_deletions}\n",
        "## 文件变更明细\n",
        "| 文件 | 状态 | 新增 | 删除 |",
        "|------|------|------|------|",
    ]
    for f in report.files:
        if f.old_filename:
            lines.append(
                f"| `{f.old_filename}` → `{f.filename}` | {f.status} | +{f.additions} | -{f.deletions} |"
            )
        else:
            lines.append(
                f"| `{f.filename}` | {f.status} | +{f.additions} | -{f.deletions} |"
            )
    return "\n".join(lines)


def tool_call(params: dict) -> dict:
    """
    通用调用入口（可被任何 AI Agent 调用）
    
    params: {
        "repo_path": str,      # 仓库路径，默认"."
        "mode": str,           # "diff" | "commits" | "commit"
        "commit_hash": str,    # 提交哈希（mode=commit时）
        "author": str,         # 按作者筛选（mode=commits时）
        "since": str,          # 起始日期
        "until": str,          # 结束日期
        "format": str,         # "json" | "markdown"
    }
    """
    try:
        repo_path = params.get("repo_path", ".")
        mode = params.get("mode", "diff")
        fmt = params.get("format", "json")
        
        if mode == "commit":
            # 分析单个提交
            commit_hash = params.get("commit_hash")
            if not commit_hash:
                return {"status": "error", "error": "缺少 commit_hash 参数"}
            report = analyze_commit(commit_hash, repo_path)
            data = to_json(report) if fmt == "json" else to_markdown(report)
            return {"status": "success", "data": data}
            
        elif mode == "commits":
            # 分析多个提交
            commits = analyze_commits(
                author=params.get("author"),
                since=params.get("since"),
                until=params.get("until"),
                repo_path=repo_path
            )
            data = commits if fmt == "json" else _commits_to_markdown(commits)
            return {"status": "success", "data": data}
            
        else:
            # 分析当前 diff
            report = analyze(repo_path)
            data = to_json(report) if fmt == "json" else to_markdown(report)
            return {"status": "success", "data": data}
            
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _commits_to_markdown(commits: list) -> str:
    """将提交列表转为 Markdown"""
    if not commits:
        return "未找到匹配的提交"
    
    lines = [
        "# Git 提交历史\n",
        "| 日期 | 作者 | 提交信息 | 新增 | 删除 |",
        "|------|------|----------|------|------|",
    ]
    for c in commits:
        lines.append(
            f"| {c['date'][:10]} | {c['author_name']} | {c['message'][:50]} | +{c['additions']} | -{c['deletions']} |"
        )
    return "\n".join(lines)


# 命令行入口
def main():
    parser = argparse.ArgumentParser(description="Git Diff 分析器")
    parser.add_argument("--repo", default=".", help="Git 仓库路径")
    parser.add_argument("--author", help="按作者筛选")
    parser.add_argument("--since", help="起始日期 (YYYY-MM-DD)")
    parser.add_argument("--until", help="结束日期 (YYYY-MM-DD)")
    parser.add_argument("--commit", help="分析指定提交的 diff")
    parser.add_argument("--staged", action="store_true", help="分析已暂存变更")
    parser.add_argument("--format", choices=["json", "markdown"], default="markdown", help="输出格式")
    args = parser.parse_args()
    
    if args.commit:
        # 分析单个提交
        report = analyze_commit(args.commit, args.repo)
        if args.format == "json":
            print(json.dumps(to_json(report), ensure_ascii=False, indent=2))
        else:
            print(to_markdown(report))
    elif args.author:
        # 按作者筛选提交
        commits = analyze_commits(
            author=args.author,
            repo_path=args.repo,
            since=args.since,
            until=args.until
        )
        if args.format == "json":
            print(json.dumps(commits, ensure_ascii=False, indent=2))
        else:
            print(_commits_to_markdown(commits))
    else:
        # 分析当前 diff
        report = analyze(args.repo)
        if args.format == "json":
            print(json.dumps(to_json(report), ensure_ascii=False, indent=2))
        else:
            print(to_markdown(report))


if __name__ == "__main__":
    main()
```

## 命令行用法

```bash
# 分析当前变更
python git_diff_analyzer.py

# 分析特定仓库
python git_diff_analyzer.py --repo /path/to/repo

# 按作者筛选
python git_diff_analyzer.py --author "张三" --since 2025-01-01

# 分析指定提交
python git_diff_analyzer.py --commit abc123

# 输出 JSON
python git_diff_analyzer.py --format json

# 分析已暂存变更
python git_diff_analyzer.py --staged
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `git: command not found` | Git 未安装或未加入 PATH | 安装 Git |
| `fatal: not a git repository` | 当前目录不是 Git 仓库 | 用 `--repo` 参数指定路径 |
| 空 diff 输出 | 工作区没有未提交的变更 | 用 `--staged` 分析暂存区 |
| Git 命令失败 | 仓库路径错误 | 检查 `--repo` 参数 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| Git | 2.0+ | 版本控制 |
