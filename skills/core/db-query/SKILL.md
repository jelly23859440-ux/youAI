---
name: 数据库查询助手
layer: core
category: memory
status: unverified
description: >
  连接 SQLite/PostgreSQL 数据库，执行查询并格式化结果。
  当用户需要查询数据库、分析数据、执行 SQL、查看表结构时触发。
  关键词：数据库查询、SQL、SQLite、PostgreSQL、数据分析、查询数据。
---

# 数据库查询助手

连接 SQLite/PostgreSQL 数据库，执行安全查询并格式化输出结果。

## 能力概览

| 能力 | 说明 |
|------|------|
| 多数据库支持 | SQLite（内置）、PostgreSQL |
| 安全查询 | 参数化查询防 SQL 注入 |
| 结果格式化 | 表格、JSON、CSV 多种输出 |
| 表结构探索 | 查看表、列、索引信息 |
| 查询历史 | 记录并复用历史查询 |

## 前置条件

- Python 3.8+
- SQLite：Python 内置，无需额外安装
- PostgreSQL：需要 psycopg2

## 安装步骤

### SQLite（无需安装）

SQLite 是 Python 内置模块，直接使用。

### PostgreSQL 支持

```bash
pip install psycopg2-binary>=2.9.0
```

## 使用方法

### SQLite 基础操作

```python
import sqlite3
from contextlib import contextmanager
from typing import List, Dict, Any, Optional, Tuple


class DatabaseManager:
    """数据库管理器（SQLite）"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.conn = None
    
    def connect(self):
        """建立连接"""
        # 关闭旧连接
        if self.conn:
            self.conn.close()
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self
    
    def disconnect(self):
        """关闭连接"""
        if self.conn:
            self.conn.close()
            self.conn = None
    
    @contextmanager
    def cursor(self):
        """获取游标的上下文管理器"""
        if not self.conn:
            self.connect()
        cur = self.conn.cursor()
        try:
            yield cur
            # 对写操作 commit（rowcount >= 0 表示有影响行，SELECT 为 -1）
            if cur.rowcount == -1 and cur.description is not None:
                pass  # SELECT，不 commit
            else:
                self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise
        finally:
            cur.close()
    
    def execute(self, query: str, params: tuple = ()) -> List[Dict]:
        """执行查询并返回结果"""
        with self.cursor() as cur:
            cur.execute(query, params)
            if cur.description:
                columns = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                return [dict(zip(columns, row)) for row in rows]
            return []
    
    def execute_many(self, query: str, params_list: List[tuple]) -> int:
        """批量执行"""
        with self.cursor() as cur:
            cur.executemany(query, params_list)
            return cur.rowcount
    
    def get_tables(self) -> List[str]:
        """获取所有表名"""
        result = self.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        return [row['name'] for row in result]
    
    def get_table_info(self, table: str) -> List[Dict]:
        """获取表结构"""
        safe_table = table.replace('"', '""')
        return self.execute(f'PRAGMA table_info("{safe_table}")')
    
    def get_row_count(self, table: str) -> int:
        """获取表行数"""
        # 转义表名防止 SQL 注入
        safe_table = table.replace('"', '""')
        result = self.execute(f'SELECT COUNT(*) as count FROM "{safe_table}"')
        return result[0]['count'] if result else 0


class PostgreSQLManager:
    """PostgreSQL 数据库管理器"""
    
    def __init__(self, host: str, port: int, database: str, user: str, password: str):
        try:
            import psycopg2
            import psycopg2.extras
        except ImportError:
            raise ImportError("请安装 psycopg2: pip install psycopg2-binary")
        
        self.conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password
        )
        self.conn.cursor_factory = psycopg2.extras.RealDictCursor
    
    def connect(self):
        return self
    
    def disconnect(self):
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def execute(self, query: str, params: tuple = ()) -> List[Dict]:
        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                if cur.description:
                    return [dict(row) for row in cur.fetchall()]
                self.conn.commit()
                return []
        except Exception:
            self.conn.rollback()
            raise
    
    def get_tables(self) -> List[str]:
        """获取所有表名（PostgreSQL 专用）"""
        result = self.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
        )
        return [row['table_name'] for row in result]
    
    def get_table_info(self, table: str) -> List[Dict]:
        """获取表结构（PostgreSQL 专用）"""
        return self.execute(
            "SELECT column_name, data_type, is_nullable, column_default "
            "FROM information_schema.columns WHERE table_name = %s",
            (table,)
        )
    
    def get_row_count(self, table: str) -> int:
        """获取表行数（PostgreSQL 专用）"""
        safe_table = table.replace('"', '""')
        result = self.execute(f'SELECT COUNT(*) as count FROM "{safe_table}"')
        return result[0]['count'] if result else 0


# 使用示例
if __name__ == "__main__":
    db = DatabaseManager("example.db")
    
    with db.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cur.execute(
            "INSERT OR IGNORE INTO users (name, email) VALUES (?, ?)",
            ("张三", "zhangsan@example.com")
        )
        cur.execute(
            "INSERT OR IGNORE INTO users (name, email) VALUES (?, ?)",
            ("李四", "lisi@example.com")
        )
    
    print("表列表:", db.get_tables())
    print("users 表结构:")
    for col in db.get_table_info("users"):
        print(f"  {col['name']}: {col['type']}")
    
    print("\n用户列表:")
    users = db.execute("SELECT * FROM users")
    for user in users:
        print(f"  {user['name']} ({user['email']})")
    
    db.disconnect()
```

### 安全查询执行

```python
import re
from datetime import datetime


class SafeQueryExecutor:
    """安全查询执行器"""
    
    # 仅匹配独立关键字（不在字符串中的）
    DANGEROUS_PATTERN = re.compile(
        r'\b(DROP|DELETE|TRUNCATE|ALTER|CREATE|GRANT|REVOKE|EXEC|EXECUTE|UPDATE|INSERT)\b',
        re.IGNORECASE
    )
    
    def __init__(self, db_manager):
        self.db = db_manager
        self.history = []
        self.max_history = 100
    
    def is_select_query(self, query: str) -> bool:
        """检查是否为 SELECT 查询"""
        normalized = query.strip().upper()
        return normalized.startswith('SELECT') or normalized.startswith('WITH')
    
    def is_dangerous(self, query: str) -> bool:
        """检查是否为危险操作"""
        # 排除字符串内容，只检查关键字
        cleaned = re.sub(r"'[^']*'|\"[^\"]*\"", '', query)
        return bool(self.DANGEROUS_PATTERN.search(cleaned))
    
    def validate_query(self, query: str) -> Tuple[bool, str]:
        """验证查询安全性"""
        if self.is_dangerous(query):
            return False, "包含危险关键字，拒绝执行"
        
        if not self.is_select_query(query):
            return False, "仅支持 SELECT 查询"
        
        # 检查多语句（排除字符串内的分号，忽略末尾分号）
        cleaned = re.sub(r"'[^']*'|\"[^\"]*\"", '', query).rstrip().rstrip(';')
        if ';' in cleaned:
            return False, "不支持多语句执行"
        
        return True, "验证通过"
    
    def execute_safe(
        self, 
        query: str, 
        params: tuple = (),
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """
        安全执行查询
        
        Returns:
            {"success": bool, "data": List, "row_count": int, "message": str}
        """
        valid, msg = self.validate_query(query)
        if not valid:
            return {
                "success": False,
                "data": [],
                "row_count": 0,
                "message": msg,
                "query": query,
                "timestamp": datetime.now().isoformat()
            }
        
        try:
            # 仅在查询无 LIMIT 时追加（使用正则避免误匹配表名/字段名）
            if not re.search(r'\bLIMIT\b', query, re.IGNORECASE):
                limited_query = f"{query.rstrip().rstrip(';')} LIMIT {max_rows}"
            else:
                limited_query = query
            
            data = self.db.execute(limited_query, params)
            
            # 记录历史（限制大小）
            if len(self.history) >= self.max_history:
                self.history.pop(0)
            self.history.append({
                "query": query,
                "params": params,
                "row_count": len(data),
                "timestamp": datetime.now().isoformat()
            })
            
            return {
                "success": True,
                "data": data,
                "row_count": len(data),
                "message": f"查询成功，返回 {len(data)} 行",
                "query": query,
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "data": [],
                "row_count": 0,
                "message": f"查询错误: {str(e)}",
                "query": query,
                "timestamp": datetime.now().isoformat()
            }
    
    def get_history(self, limit: int = 10) -> List[Dict]:
        """获取查询历史"""
        return self.history[-limit:]


# 使用示例
if __name__ == "__main__":
    db = DatabaseManager("example.db")
    executor = SafeQueryExecutor(db)
    
    result = executor.execute_safe("SELECT * FROM users WHERE name = ?", ("张三",))
    if result["success"]:
        print(f"查询成功: {result['message']}")
    else:
        print(f"查询失败: {result['message']}")
```

### 结果格式化

```python
import csv
import json
from io import StringIO
from typing import List, Dict


class ResultFormatter:
    """查询结果格式化器"""
    
    @staticmethod
    def to_table(data: List[Dict], max_col_width: int = 30) -> str:
        """格式化为 ASCII 表格"""
        if not data:
            return "(无数据)"
        
        columns = list(data[0].keys())
        col_widths = {}
        for col in columns:
            max_width = max(len(str(col)), max(len(str(row.get(col, ''))) for row in data))
            col_widths[col] = min(max_width, max_col_width)
        
        header = " | ".join(col.ljust(col_widths[col]) for col in columns)
        separator = "-+-".join("-" * col_widths[col] for col in columns)
        
        lines = [header, separator]
        for row in data:
            line = " | ".join(
                str(row.get(col, ''))[:max_col_width].ljust(col_widths[col])
                for col in columns
            )
            lines.append(line)
        
        return "\n".join(lines)
    
    @staticmethod
    def to_json(data: List[Dict], indent: int = 2) -> str:
        """格式化为 JSON"""
        return json.dumps(data, ensure_ascii=False, indent=indent, default=str)
    
    @staticmethod
    def to_csv_string(data: List[Dict]) -> str:
        """格式化为 CSV 字符串"""
        if not data:
            return ""
        
        output = StringIO()
        writer = csv.DictWriter(output, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)
        return output.getvalue()
    
    @staticmethod
    def to_markdown(data: List[Dict]) -> str:
        """格式化为 Markdown 表格（转义管道符）"""
        if not data:
            return "(无数据)"
        
        columns = list(data[0].keys())
        
        header = "| " + " | ".join(columns) + " |"
        separator = "| " + " | ".join("---" for _ in columns) + " |"
        
        rows = []
        for row in data:
            # 转义管道符，防止破坏表格
            row_str = "| " + " | ".join(
                str(row.get(col, '')).replace("|", "\\|") for col in columns
            ) + " |"
            rows.append(row_str)
        
        return "\n".join([header, separator] + rows)


# 使用示例
if __name__ == "__main__":
    data = [
        {"id": 1, "name": "张三", "age": 25},
        {"id": 2, "name": "李四", "age": 30},
    ]
    
    formatter = ResultFormatter()
    print(formatter.to_table(data))
    print(formatter.to_markdown(data))
```

## 命令行用法

```bash
# 查询 SQLite 数据库
python db_query.py --db mydb.sqlite "SELECT * FROM users"

# 查看表结构
python db_query.py --db mydb.sqlite --tables

# 导出为 CSV
python db_query.py --db mydb.sqlite --format csv "SELECT * FROM users" > users.csv

# PostgreSQL 查询
python db_query.py --db postgresql://user:pass@host:5432/mydb "SELECT COUNT(*) FROM orders"
```

### 命令行入口代码

```python
import argparse
import os

def main():
    parser = argparse.ArgumentParser(description="数据库查询工具")
    parser.add_argument("query", nargs="?", help="SQL 查询语句")
    parser.add_argument("--db", required=True, help="数据库路径或连接字符串")
    parser.add_argument("--tables", action="store_true", help="列出所有表")
    parser.add_argument("--format", choices=["table", "json", "csv", "markdown"], default="table")
    parser.add_argument("--max-rows", type=int, default=1000)
    
    args = parser.parse_args()
    
    # 创建数据库连接
    db = None
    if args.db.startswith("postgresql://") or args.db.startswith("postgres://"):
        from urllib.parse import urlparse
        parsed = urlparse(args.db)
        db = PostgreSQLManager(
            host=parsed.hostname,
            port=parsed.port or 5432,
            database=parsed.path.lstrip("/"),
            user=parsed.username,
            password=parsed.password or ""
        )
    else:
        db = DatabaseManager(args.db)
    
    try:
        if args.tables:
            tables = db.get_tables()
            print(f"共 {len(tables)} 个表:")
            for t in tables:
                print(f"  - {t}")
        elif args.query:
            executor = SafeQueryExecutor(db)
            result = executor.execute_safe(args.query, max_rows=args.max_rows)
            
            if result["success"]:
                formatter = ResultFormatter()
                if args.format == "json":
                    print(formatter.to_json(result["data"]))
                elif args.format == "csv":
                    print(formatter.to_csv_string(result["data"]))
                elif args.format == "markdown":
                    print(formatter.to_markdown(result["data"]))
                else:
                    print(formatter.to_table(result["data"]))
            else:
                print(f"错误: {result['message']}")
        else:
            parser.print_help()
    finally:
        if db:
            db.disconnect()

if __name__ == "__main__":
    main()
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| SQLite 数据库锁定 | 多进程同时写入 | 使用 WAL 模式：`sqlite3.connect("db.sqlite", timeout=10)` |
| PostgreSQL 连接失败 | 网络/认证错误 | 检查连接参数 |
| 查询结果为空 | 表不存在或条件不匹配 | 先执行 `--tables` 查看表 |
| LIMIT 重复报错 | 查询已包含 LIMIT | 代码自动检测，不重复追加 |
| tuple 语法错误 | Python 版本太低 | 需 Python 3.9+ 或使用 `Tuple` |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.9+ | 运行环境 |
| sqlite3 | 内置 | SQLite |
| psycopg2-binary | ≥2.9.0 | PostgreSQL（可选） |

## Agent 执行规范

- **仅执行 SELECT**：禁止执行修改数据的语句
- **参数化查询**：始终使用参数占位符，禁止字符串拼接
- **限制结果集**：默认限制 1000 行，防止内存溢出
- **记录查询历史**：便于审计和复用，最多保留 100 条
