---
name: 日志分析器
layer: action
category: file
status: unverified
description: 日志分析工具，支持多种日志格式解析、错误统计、趋势分析
version: 1.1
---

# 日志分析器

解析各种格式的日志文件，提取错误、警告信息，生成统计报告。

## 功能特性

- 支持多种日志格式（Apache, Nginx, syslog, JSON, 标准格式）
- 提取 ERROR、WARNING、INFO 级别日志
- 时间范围过滤
- 关键词搜索
- 统计分析（每小时/每天错误数）
- 输出格式化报告

## 安装依赖

基础功能使用 Python 标准库。JSON 日志解析无需额外依赖。

## 使用方法

### 命令行使用

```bash
# 基本分析
python log_analyzer.py analyze access.log

# 只显示错误
python log_analyzer.py errors app.log

# 时间范围过滤
python log_analyzer.py analyze app.log --start "2024-01-01" --end "2024-01-31"

# 搜索关键词
python log_analyzer.py search app.log --keyword "timeout"

# 输出统计报告
python log_analyzer.py stats app.log
```

### Python 代码示例

```python
import re
import json
from datetime import datetime
from typing import List, Dict, Any, Optional
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class LogEntry:
    """日志条目"""
    timestamp: Optional[datetime]
    level: str
    message: str
    source: str = ""
    line_number: int = 0
    extra: Dict[str, Any] = field(default_factory=dict)


class LogAnalyzer:
    """日志分析器"""
    
    # 常见日志格式的正则表达式
    PATTERNS = {
        # Apache/Nginx 访问日志
        "apache": r'(?P<ip>[\d\.]+) - - \[(?P<timestamp>[^\]]+)\] "(?P<method>\w+) (?P<path>[^\s]+) [^"]*" (?P<status>\d+) (?P<size>\d+)',
        # 通用日志格式 [YYYY-MM-DD HH:MM:SS] LEVEL: message
        "standard": r'\[(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]\s+(?P<level>\w+):\s+(?P<message>.+)',
        # syslog 格式
        "syslog": r'(?P<timestamp>\w+\s+\d+\s+\d{2}:\d{2}:\d{2})\s+(?P<host>\S+)\s+(?P<program>\S+?)(\[(?P<pid>\d+)\])?:\s+(?P<message>.+)',
        # 简单格式: LEVEL message
        "simple": r'^(?P<level>ERROR|WARNING|INFO|DEBUG|CRITICAL)\s+(?P<message>.+)',
    }
    
    # 日志级别优先级
    LEVEL_PRIORITY = {
        "DEBUG": 0,
        "INFO": 1,
        "WARNING": 2,
        "WARN": 2,
        "ERROR": 3,
        "CRITICAL": 4,
        "FATAL": 4,
    }
    
    def __init__(self, format: str = "auto"):
        """
        初始化分析器
        
        Args:
            format: 日志格式 ("auto", "apache", "standard", "syslog", "simple", "json")
        """
        self.format = format
        self.entries: List[LogEntry] = []
    
    def parse_log(
        self,
        file_path: str,
        encoding: str = "utf-8",
        max_lines: Optional[int] = None
    ) -> List[LogEntry]:
        """
        解析日志文件
        
        Args:
            file_path: 日志文件路径
            encoding: 文件编码
            max_lines: 最大读取行数
            
        Returns:
            解析后的日志条目列表
        """
        self.entries = []
        path = Path(file_path)
        
        if not path.exists():
            raise FileNotFoundError(f"日志文件不存在: {file_path}")
        
        with open(path, 'r', encoding=encoding, errors='replace') as f:
            for i, line in enumerate(f, 1):
                if max_lines and i > max_lines:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                entry = self._parse_line(line, i)
                if entry:
                    self.entries.append(entry)
        
        return self.entries
    
    def _parse_line(self, line: str, line_number: int) -> Optional[LogEntry]:
        """解析单行日志"""
        if self.format == "auto":
            # 优先尝试 JSON 解析（行首是 { 就尝试）
            if line.startswith('{'):
                entry = self._parse_json_line(line, line_number)
                if entry:
                    return entry
            
            # 然后尝试其他正则模式
            for fmt_name, pattern in self.PATTERNS.items():
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    return self._create_entry(match, fmt_name, line, line_number)
        elif self.format == "json":
            return self._parse_json_line(line, line_number)
        else:
            pattern = self.PATTERNS.get(self.format)
            if pattern:
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    return self._create_entry(match, self.format, line, line_number)
        
        # 如果没有匹配，尝试简单解析
        return LogEntry(
            timestamp=None,
            level="UNKNOWN",
            message=line,
            line_number=line_number
        )
    
    def _parse_json_line(self, line: str, line_number: int) -> Optional[LogEntry]:
        """使用 json.loads 解析 JSON 日志"""
        try:
            data = json.loads(line.strip())
            if not isinstance(data, dict):
                return None
            
            level = data.get("level", data.get("severity", "INFO"))
            message = data.get("message", data.get("msg", str(data)))
            
            # 尝试从常见字段提取时间戳
            ts = data.get("timestamp") or data.get("time") or data.get("ts") or data.get("@timestamp")
            timestamp = self._parse_timestamp(str(ts)) if ts else None
            
            return LogEntry(
                timestamp=timestamp,
                level=str(level).upper(),
                message=str(message),
                line_number=line_number,
                extra={k: v for k, v in data.items() 
                       if k not in ("level", "severity", "message", "msg", "timestamp", "time", "ts", "@timestamp")}
            )
        except (json.JSONDecodeError, ValueError):
            return None
    
    def _create_entry(
        self,
        match: re.Match,
        format: str,
        raw_line: str,
        line_number: int
    ) -> LogEntry:
        """创建日志条目"""
        groups = match.groupdict()
        
        # 解析时间戳
        timestamp = None
        ts_str = groups.get("timestamp")
        if ts_str:
            timestamp = self._parse_timestamp(ts_str)
        
        # 获取级别
        level = groups.get("level", "INFO").upper()
        
        # 获取消息
        message = groups.get("message", raw_line)
        
        return LogEntry(
            timestamp=timestamp,
            level=level,
            message=message,
            source=groups.get("program", groups.get("ip", "")),
            line_number=line_number,
            extra={k: v for k, v in groups.items() 
                   if k not in ("timestamp", "level", "message")}
        )
    
    def _parse_timestamp(self, ts_str: str) -> Optional[datetime]:
        """解析时间戳"""
        formats = [
            "%Y-%m-%d %H:%M:%S.%f",      # 带毫秒
            "%Y-%m-%d %H:%M:%S%z",        # 带时区
            "%Y-%m-%dT%H:%M:%S.%f%z",     # ISO 8601 带毫秒和时区
            "%Y-%m-%dT%H:%M:%S%z",        # ISO 8601 带时区
            "%Y-%m-%dT%H:%M:%S.%f",       # ISO 8601 带毫秒
            "%Y-%m-%dT%H:%M:%S",          # ISO 8601
            "%Y-%m-%d %H:%M:%S",          # 标准格式
            "%d/%b/%Y:%H:%M:%S %z",       # Apache 格式
            "%b %d %H:%M:%S",             # syslog 格式
        ]
        
        ts_str = ts_str.strip()
        
        for fmt in formats:
            try:
                return datetime.strptime(ts_str, fmt)
            except ValueError:
                continue
        
        return None
    
    def filter_by_level(
        self,
        min_level: str = "WARNING"
    ) -> List[LogEntry]:
        """按级别过滤"""
        min_priority = self.LEVEL_PRIORITY.get(min_level.upper(), 0)
        
        return [
            entry for entry in self.entries
            if self.LEVEL_PRIORITY.get(entry.level, 0) >= min_priority
        ]
    
    def filter_by_time(
        self,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None
    ) -> List[LogEntry]:
        """按时间范围过滤"""
        result = []
        
        for entry in self.entries:
            if entry.timestamp is None:
                continue
            
            if start and entry.timestamp < start:
                continue
            
            if end and entry.timestamp > end:
                continue
            
            result.append(entry)
        
        return result
    
    def search_keyword(
        self,
        keyword: str,
        case_sensitive: bool = False
    ) -> List[LogEntry]:
        """搜索关键词"""
        flags = 0 if case_sensitive else re.IGNORECASE
        pattern = re.compile(re.escape(keyword), flags)
        
        return [
            entry for entry in self.entries
            if pattern.search(entry.message)
        ]
    
    def get_statistics(self) -> Dict[str, Any]:
        """获取统计信息"""
        if not self.entries:
            return {"total": 0}
        
        level_counts = Counter(entry.level for entry in self.entries)
        
        # 按小时统计
        hourly_counts = defaultdict(int)
        for entry in self.entries:
            if entry.timestamp:
                hourly_counts[entry.timestamp.hour] += 1
        
        # 按天统计
        daily_counts = defaultdict(int)
        for entry in self.entries:
            if entry.timestamp:
                daily_counts[entry.timestamp.date().isoformat()] += 1
        
        # 时间范围
        timestamps = [e.timestamp for e in self.entries if e.timestamp]
        time_range = {
            "start": min(timestamps).isoformat() if timestamps else None,
            "end": max(timestamps).isoformat() if timestamps else None,
        }
        
        return {
            "total": len(self.entries),
            "by_level": dict(level_counts),
            "by_hour": dict(hourly_counts),
            "by_day": dict(daily_counts),
            "time_range": time_range,
            "error_rate": level_counts.get("ERROR", 0) / len(self.entries) * 100,
        }
    
    def generate_report(
        self,
        output_file: Optional[str] = None
    ) -> str:
        """生成分析报告"""
        stats = self.get_statistics()
        
        report_lines = [
            "=" * 60,
            "日志分析报告",
            "=" * 60,
            "",
            f"总条目数: {stats['total']}",
            f"错误率: {stats['error_rate']:.2f}%",
            "",
            "--- 按级别统计 ---",
        ]
        
        for level, count in sorted(stats.get("by_level", {}).items()):
            report_lines.append(f"  {level}: {count}")
        
        report_lines.extend(["", "--- 时间范围 ---"])
        time_range = stats.get("time_range", {})
        report_lines.append(f"  开始: {time_range.get('start', 'N/A')}")
        report_lines.append(f"  结束: {time_range.get('end', 'N/A')}")
        
        # 错误日志摘要
        errors = self.filter_by_level("ERROR")
        if errors:
            report_lines.extend(["", "--- 最近错误 (最多10条) ---"])
            for entry in errors[:10]:
                ts = entry.timestamp.strftime("%Y-%m-%d %H:%M:%S") if entry.timestamp else "N/A"
                report_lines.append(f"  [{ts}] {entry.message[:100]}")
        
        report = "\n".join(report_lines)
        
        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(report)
        
        return report


# 命令行入口
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="日志分析工具")
    parser.add_argument("action", choices=["analyze", "errors", "search", "stats"])
    parser.add_argument("logfile", help="日志文件路径")
    parser.add_argument("--level", default="WARNING", help="最低日志级别（仅 analyze）")
    parser.add_argument("--keyword", help="搜索关键词（仅 search）")
    parser.add_argument("--start", help="开始时间 (YYYY-MM-DD)")
    parser.add_argument("--end", help="结束时间 (YYYY-MM-DD)")
    parser.add_argument("--format", default="auto", help="日志格式")
    parser.add_argument("--report", action="store_true", help="输出详细报告")
    
    args = parser.parse_args()
    
    analyzer = LogAnalyzer(format=args.format)
    analyzer.parse_log(args.logfile)
    
    # 解析时间参数
    start_dt = datetime.strptime(args.start, "%Y-%m-%d") if args.start else None
    end_dt = datetime.strptime(args.end, "%Y-%m-%d") if args.end else None
    if end_dt:
        end_dt = end_dt.replace(hour=23, minute=59, second=59)
    
    # 按时间过滤
    if start_dt or end_dt:
        analyzer.entries = analyzer.filter_by_time(start_dt, end_dt)
    
    if args.action == "analyze":
        entries = analyzer.filter_by_level(args.level)
        print(f"找到 {len(entries)} 条 {args.level} 及以上级别的日志:")
        for entry in entries[:20]:
            print(f"  [{entry.level}] {entry.message[:80]}")
    
    elif args.action == "errors":
        # errors 固定过滤 ERROR 级别
        entries = analyzer.filter_by_level("ERROR")
        print(f"找到 {len(entries)} 条 ERROR 级别的日志:")
        for entry in entries[:20]:
            print(f"  [{entry.level}] {entry.message[:80]}")
    
    elif args.action == "search":
        if not args.keyword:
            print("错误: --keyword 参数必需")
        else:
            entries = analyzer.search_keyword(args.keyword)
            print(f"找到 {len(entries)} 条包含 '{args.keyword}' 的日志:")
            for entry in entries[:20]:
                print(f"  [{entry.level}] {entry.message[:80]}")
    
    elif args.action == "stats":
        print(analyzer.generate_report())
    
    if args.report:
        print("\n" + analyzer.generate_report())
```

## 使用示例

```python
from log_analyzer import LogAnalyzer
from datetime import datetime

analyzer = LogAnalyzer(format="auto")

# 解析日志文件
entries = analyzer.parse_log("app.log")
print(f"解析了 {len(entries)} 条日志")

# 获取错误日志
errors = analyzer.filter_by_level("ERROR")
print(f"错误数量: {len(errors)}")

# 按时间过滤
recent = analyzer.filter_by_time(
    start=datetime(2024, 1, 1),
    end=datetime(2024, 1, 31)
)

# 搜索关键词
timeout_logs = analyzer.search_keyword("timeout")

# 生成报告
report = analyzer.generate_report("report.txt")
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 编码错误 | 文件非 UTF-8 | 指定编码：`parse_log("app.log", encoding="gbk")` |
| 内存不足 | 大文件全量加载 | 使用 `max_lines` 限制行数 |
| JSON 日志解析失败 | 非标准 JSON | 确保每行是合法 JSON 对象 |
| 时间过滤无效 | 日期格式错误 | 使用 `YYYY-MM-DD` 格式 |
| 日志格式无法识别 | 未知格式 | 使用 `format="simple"` 或 `format="json"` |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
