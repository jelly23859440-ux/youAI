---
name: Cron 表达式解析器
layer: core
category: reasoning
status: unverified
description: >
  解析标准 cron 表达式，计算下次执行时间。
  当用户想要设置定时任务、解析 cron 表达式、查看定时计划、
  或验证 cron 表达式是否正确时触发。
  关键词：cron、定时任务、定时执行、schedule、cron 表达式、下次执行时间。
---

# Cron 表达式解析器

解析标准 5 字段 cron 表达式，计算下次执行时间，支持通配符、步骤、范围、列表。

## 能力概览

| 能力 | 说明 |
|------|------|
| 表达式解析 | 分/时/日/月/周 五字段解析 |
| 下次执行 | 计算从给定时间起的下 N 次执行时间 |
| 通配符支持 | `*`、`,`、`-`、`/` 全支持 |
| 校验 | 检查表达式是否合法 |

## 前置条件

- Python 3.8+
- 无第三方依赖（纯标准库）

## 使用方法

### 完整代码

```python
from datetime import datetime, timedelta
from typing import List, Optional


class CronParser:
    """标准 cron 表达式解析器（5 字段格式：分 时 日 月 周）"""

    FIELD_RANGES = {
        "minute": (0, 59),
        "hour": (0, 23),
        "day": (1, 31),
        "month": (1, 12),
        "weekday": (0, 7),
    }

    def __init__(self, expression: str):
        self.expression = expression.strip()
        self.fields = self.expression.split()
        if len(self.fields) != 5:
            raise ValueError(f"需要 5 个字段，得到 {len(self.fields)} 个: {self.expression}")
        self.parsed = {}
        field_names = ["minute", "hour", "day", "month", "weekday"]
        for name, value in zip(field_names, self.fields):
            self.parsed[name] = self._parse_field(name, value)

    def _parse_field(self, name: str, value: str) -> set:
        lo, hi = self.FIELD_RANGES[name]
        result = set()

        for part in value.split(","):
            result |= self._parse_part(part, lo, hi)

        return result

    def _parse_part(self, part: str, lo: int, hi: int) -> set:
        if "/" in part:
            base, step = part.split("/", 1)
            step = int(step)
            if step <= 0:
                raise ValueError(f"步长必须大于 0: {part}")
            if base == "*":
                return set(range(lo, hi + 1, step))
            elif "-" in base:
                start, end = self._parse_range(base, lo, hi)
                return set(range(start, end + 1, step))
            else:
                # 支持 "1/2" 格式（从 1 开始步长 2）
                start = int(base)
                return set(range(start, hi + 1, step))
        elif "-" in part:
            start, end = self._parse_range(part, lo, hi)
            return set(range(start, end + 1))
        elif part == "*":
            return set(range(lo, hi + 1))
        else:
            val = int(part)
            # 支持 weekday=7 映射为 0（周日）
            if val == 7:
                val = 0
            if not (lo <= val <= hi):
                raise ValueError(f"值 {val} 超出范围 [{lo}-{hi}]")
            return {val}

    def _parse_range(self, part: str, lo: int, hi: int) -> tuple:
        start_str, end_str = part.split("-", 1)
        start, end = int(start_str), int(end_str)
        if not (lo <= start <= hi and lo <= end <= hi):
            raise ValueError(f"范围 {part} 超出有效范围 [{lo}-{hi}]")
        return start, end

    def matches(self, dt: datetime) -> bool:
        """检查给定时间是否匹配此 cron 表达式"""
        if dt.minute not in self.parsed["minute"]:
            return False
        if dt.hour not in self.parsed["hour"]:
            return False
        if dt.month not in self.parsed["month"]:
            return False

        # 星期映射：Python weekday() 0=周一..6=周日 → Cron 0=周日..6=周六
        weekday = dt.weekday()
        cron_weekday = 0 if weekday == 6 else weekday + 1

        # 检查 day 和 weekday 字段是否被指定
        day_specified = self.fields[2] != "*"
        weekday_specified = self.fields[4] != "*"

        if not day_specified and not weekday_specified:
            return True  # 都未指定，每天匹配
        elif day_specified and not weekday_specified:
            return dt.day in self.parsed["day"]
        elif weekday_specified and not day_specified:
            return cron_weekday in self.parsed["weekday"]
        else:
            # 标准 cron：day 和 weekday 都指定时为 OR 关系
            return dt.day in self.parsed["day"] or cron_weekday in self.parsed["weekday"]

    def next_run(self, after: Optional[datetime] = None, count: int = 1) -> List[datetime]:
        """计算从 after 时间起的下 N 次执行时间"""
        if after is None:
            after = datetime.now()

        results = []
        current = after.replace(second=0, microsecond=0) + timedelta(minutes=1)
        # 扩大到 4 年，支持闰年等稀疏表达式
        max_iterations = 4 * 366 * 24 * 60

        for _ in range(max_iterations):
            if self.matches(current):
                results.append(current)
                if len(results) >= count:
                    break
            current += timedelta(minutes=1)

        return results

    def describe(self) -> str:
        """生成人类可读的描述"""
        parts = []
        f = self.fields

        # 分钟
        if f[0] == "*":
            parts.append("每分钟")
        elif "/" in f[0]:
            step = f[0].split("/")[1]
            parts.append(f"每 {step} 分钟")
        else:
            parts.append(f"在第 {f[0]} 分钟")

        # 小时
        if f[1] == "*":
            parts.append("每小时")
        elif "/" in f[1]:
            step = f[1].split("/")[1]
            parts.append(f"每 {step} 小时")
        else:
            parts.append(f"在 {f[1]} 时")

        # 日/周
        weekday_names = {0: "日", 1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六"}

        if f[2] == "*" and f[4] == "*":
            parts.append("每天")
        elif f[4] != "*":
            if "," in f[4]:
                days = []
                for d in f[4].split(","):
                    if d.isdigit():
                        days.append(weekday_names.get(int(d) % 7, d))
                    else:
                        days.append(d)
                parts.append(f"每周 {'/'.join(days)}")
            elif f[4].isdigit():
                parts.append(f"周{weekday_names.get(int(f[4]) % 7, f[4])}")
            elif "-" in f[4]:
                start, end = f[4].split("-", 1)
                start_name = weekday_names.get(int(start) % 7, start)
                end_name = weekday_names.get(int(end) % 7, end)
                parts.append(f"周 {start_name} 到 {end_name}")
            else:
                parts.append(f"周 {f[4]}")
        elif f[2] != "*":
            parts.append(f"在每月 {f[2]} 日")

        # 月份
        if f[3] != "*":
            parts.append(f"在 {f[3]} 月")

        return "，".join(parts)


# 使用示例
if __name__ == "__main__":
    cron = CronParser("*/5 * * * *")
    print(f"表达式: {cron.expression}")
    print(f"描述: {cron.describe()}")
    print(f"\n下次执行:")
    for t in cron.next_run(count=5):
        print(f"  {t.strftime('%Y-%m-%d %H:%M')}")

    print(f"\n匹配测试:")
    test_time = datetime(2025, 7, 1, 10, 15)
    print(f"  {test_time}: {'匹配' if cron.matches(test_time) else '不匹配'}")


def validate_cron_expressions(expressions: List[str]) -> List[dict]:
    """批量验证 cron 表达式"""
    results = []
    for expr in expressions:
        try:
            cron = CronParser(expr)
            runs = cron.next_run(count=1)
            results.append({
                "expression": expr,
                "valid": True,
                "description": cron.describe(),
                "next_run": runs[0].isoformat() if runs else None,
            })
        except Exception as e:
            results.append({
                "expression": expr,
                "valid": False,
                "error": str(e),
            })
    return results
```

## 常用 cron 表达式速查

| 表达式 | 含义 |
|--------|------|
| `* * * * *` | 每分钟 |
| `0 * * * *` | 每小时整点 |
| `0 0 * * *` | 每天午夜 |
| `0 9 * * 1-5` | 工作日上午 9 点 |
| `*/5 * * * *` | 每 5 分钟 |
| `0 0 1 * *` | 每月 1 日午夜 |
| `30 8 * * 1` | 每周一 8:30 |
| `0 */2 * * *` | 每 2 小时 |
| `0 0 * * 0` | 每周日午夜 |
| `0 0 15 * *` | 每月 15 日午夜 |

## 使用示例

```python
from cron_parser import CronParser, validate_cron_expressions

# 基础用法
cron = CronParser("*/5 * * * *")
print(cron.describe())  # "每 5 分钟"
print(cron.next_run(count=3))  # 下 3 次执行时间

# 每周一
cron = CronParser("0 9 * * 1")
print(cron.describe())  # "在 9 时，周 一"

# 每月 15 日
cron = CronParser("0 0 15 * *")
print(cron.describe())  # "在 0 时，在每月 15 日"

# 批量验证
results = validate_cron_expressions(["*/5 * * * *", "0 9 * * 1-5", "60 * * * *"])
for r in results:
    if r["valid"]:
        print(f"✓ {r['expression']}: {r['description']}")
    else:
        print(f"✗ {r['expression']}: {r['error']}")
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `ValueError: 需要 5 个字段` | 字段数不对 | 检查是否多写了秒字段 |
| 计算下次执行返回空列表 | 日期+星期矛盾 | 检查 day 和 weekday 是否冲突 |
| `ValueError: 值 XX 超出范围` | 字段值超范围 | 分(0-59)、时(0-23)、日(1-31)、月(1-12)、周(0-7) |
| 性能问题（计算太慢） | 表达式过于稀疏 | 稀疏表达式需遍历较长时间 |
| weekday=7 不生效 | 7 被映射为 0 | 使用 0 表示周日，7 会自动映射 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
