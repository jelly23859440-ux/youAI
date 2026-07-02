---
name: 代码搜索
layer: action
category: code
description: 使用 ripgrep 搜索代码库，支持正则表达式和文件类型过滤
version: 1.2
---

# 代码搜索

使用 ripgrep 在代码库中快速搜索文本、正则表达式模式，支持文件类型过滤。

## 功能特性

- 正则表达式搜索
- 文件类型过滤（按扩展名）
- 上下文行数控制（匹配行前后）
- 大小写敏感/不敏感
- 多文件批量搜索
- 支持多目录搜索

## 安装依赖

```bash
# Windows
winget install BurntSushi.ripgrep.MSVC

# macOS
brew install ripgrep

# Linux
sudo apt install ripgrep
```

## 使用方法

### 命令行直接使用

```bash
rg "pattern" /path/to/search
rg "\d{4}-\d{2}-\d{2}" --glob "*.py"
rg "TODO" -t py -t js
rg "error" -C 3
rg "pattern" -l
```

### Python 代码示例

```python
import subprocess
import re
import json
from typing import List, Dict, Optional
from dataclasses import dataclass, field


@dataclass
class SearchResult:
    """搜索结果"""
    file: str
    line: int
    column: int
    match: str
    context_before: List[str] = field(default_factory=list)
    context_after: List[str] = field(default_factory=list)


class CodeSearcher:
    """代码搜索器"""
    
    def __init__(self, ripgrep_path: str = "rg"):
        self.ripgrep_path = ripgrep_path
        self._verify_ripgrep()
    
    def _verify_ripgrep(self) -> None:
        """验证 ripgrep 是否可用"""
        try:
            subprocess.run(
                [self.ripgrep_path, "--version"],
                capture_output=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
        except FileNotFoundError:
            raise RuntimeError(
                "ripgrep 未安装。请运行: winget install BurntSushi.ripgrep.MSVC"
            )
    
    def search(
        self,
        pattern: str,
        path: str = ".",
        file_types: Optional[List[str]] = None,
        ignore_case: bool = False,
        context_lines: int = 0,
        max_results: int = 100
    ) -> List[SearchResult]:
        """
        搜索代码
        
        Args:
            pattern: 搜索模式（支持正则表达式）
            path: 搜索路径
            file_types: 文件类型过滤列表（如 ['py', 'js']）
            ignore_case: 是否忽略大小写
            context_lines: 上下文行数
            max_results: 最大结果数
            
        Returns:
            搜索结果列表
        """
        cmd = [self.ripgrep_path, pattern, path]
        
        if ignore_case:
            cmd.append("-i")
        
        if file_types:
            for ft in file_types:
                cmd.extend(["-t", ft])
        
        # 使用 --json 获取结构化输出，彻底解决上下文解析问题
        cmd.extend(["--json"])
        
        if context_lines > 0:
            cmd.extend(["-C", str(context_lines)])
        
        # 使用 -m 限制 ripgrep 输出数量，避免内存浪费
        cmd.extend(["-m", str(max_results)])
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                check=False
            )
        except Exception as e:
            raise RuntimeError(f"搜索失败: {e}")
        
        return self._parse_json_output(result.stdout)
    
    def _parse_json_output(self, output: str) -> List[SearchResult]:
        """
        解析 ripgrep --json 输出
        
        JSON 输出格式：
        {"type":"begin","data":{"path":{"text":"file.py"}}}
        {"type":"match","data":{"path":{"text":"file.py"},"lines":{"text":"..."},"line_number":10,"submatches":[...]}}
        {"type":"context","data":{"path":{"text":"file.py"},"lines":{"text":"..."},"line_number":9}}
        {"type":"end","data":{"path":{"text":"file.py"},"stats":{"elapsed":...}}}
        """
        results = []
        current_file = ""
        context_before = []
        
        for line in output.strip().split('\n'):
            if not line:
                continue
            
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            
            msg_type = data.get("type")
            msg_data = data.get("data", {})
            
            if msg_type == "begin":
                current_file = msg_data.get("path", {}).get("text", "")
                context_before = []
                
            elif msg_type == "match":
                file_path = msg_data.get("path", {}).get("text", current_file)
                line_num = msg_data.get("line_number", 0)
                content = msg_data.get("lines", {}).get("text", "").strip()
                
                # 获取列号
                submatches = msg_data.get("submatches", [])
                column = submatches[0].get("start", 0) if submatches else 0
                
                results.append(SearchResult(
                    file=file_path,
                    line=line_num,
                    column=column,
                    match=content,
                    context_before=context_before.copy(),
                    context_after=[]
                ))
                
                context_before = []
                
            elif msg_type == "context":
                file_path = msg_data.get("path", {}).get("text", current_file)
                line_num = msg_data.get("line_number", 0)
                content = msg_data.get("lines", {}).get("text", "").strip()
                
                # 收集上下文行
                context_before.append(content)
                # 保持上下文行数不超过限制
                if len(context_before) > 20:  # 假设最大上下文
                    context_before.pop(0)
        
        return results
    
    def search_files(
        self,
        pattern: str,
        file_types: Optional[List[str]] = None,
        directory: str = ".",
        ignore_case: bool = False
    ) -> Dict[str, List[int]]:
        """
        搜索文件并返回匹配行号
        
        Args:
            pattern: 搜索模式
            file_types: 文件类型过滤（如 ['py', 'js']）
            directory: 搜索目录
            ignore_case: 是否忽略大小写
            
        Returns:
            {文件路径: [匹配行号列表]}
        """
        try:
            cmd = [self.ripgrep_path, pattern, directory, "-n", "--no-heading"]
            
            if ignore_case:
                cmd.append("-i")
            
            if file_types:
                for ft in file_types:
                    cmd.extend(["-t", ft])
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            
            file_lines: Dict[str, List[int]] = {}
            
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue
                
                # 格式: file:line:content
                match = re.match(r'^(.+?):(\d+):(.+)$', line)
                if match:
                    file_path = match.group(1)
                    line_num = int(match.group(2))
                    
                    if file_path not in file_lines:
                        file_lines[file_path] = []
                    file_lines[file_path].append(line_num)
            
            return file_lines
            
        except FileNotFoundError:
            raise RuntimeError("ripgrep 未安装")
        except Exception as e:
            raise RuntimeError(f"搜索失败: {e}")
    
    def count_matches(
        self,
        pattern: str,
        path: str = ".",
        ignore_case: bool = False
    ) -> int:
        """
        统计匹配数量
        
        Args:
            pattern: 搜索模式
            path: 搜索路径
            ignore_case: 是否忽略大小写
            
        Returns:
            匹配总数
        """
        try:
            cmd = [self.ripgrep_path, pattern, path, "-c"]
            
            if ignore_case:
                cmd.append("-i")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            total = 0
            
            for line in result.stdout.strip().split('\n'):
                if ':' in line:
                    count_str = line.split(':')[-1]
                    try:
                        total += int(count_str)
                    except ValueError:
                        pass
            
            return total
            
        except FileNotFoundError:
            raise RuntimeError("ripgrep 未安装")
        except Exception as e:
            raise RuntimeError(f"搜索失败: {e}")


# 使用示例
if __name__ == "__main__":
    searcher = CodeSearcher()
    
    # 搜索所有 Python 文件中的 TODO
    results = searcher.search(
        pattern="TODO|FIXME|HACK",
        path="./src",
        file_types=["py"],
        ignore_case=True,
        context_lines=2
    )
    
    print(f"找到 {len(results)} 个匹配:")
    for r in results:
        print(f"  {r.file}:{r.line}:{r.column} - {r.match}")
        if r.context_before:
            print(f"    上下文: {r.context_before}")
```

## 使用示例

```python
from code_search import CodeSearcher

searcher = CodeSearcher()

# 搜索 Python 文件中的函数定义
results = searcher.search(
    pattern=r"def \w+\(",
    path="./my_project",
    file_types=["py"]
)

for r in results:
    print(f"{r.file}:{r.line}:{r.column} - {r.match}")

# 统计匹配数
count = searcher.count_matches(
    pattern="import",
    path="./src",
    ignore_case=True
)
print(f"总共找到 {count} 个 import 语句")
```

## 故障排除

| 问题 | 原因 | 解决 |
|------|------|------|
| ripgrep 未找到 | 未安装 | `winget install BurntSushi.ripgrep.MSVC` |
| 正则语法错误 | 正则写法错误 | 用在线工具验证正则 |
| 权限被拒绝 | 文件权限问题 | 检查文件权限或用管理员运行 |
| 编码错误 | 文件非 UTF-8 | 代码已使用 `errors='replace'` 处理 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| ripgrep | 14+ | 搜索引擎 |
| Python | 3.7+ | 运行环境 |
