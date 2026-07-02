---
name: Token 估算器
layer: core
category: reasoning
status: unverified
description: >
  估算文本的 token 数量，支持多种 LLM 模型。
  当用户需要估算 API 费用、检查上下文长度、优化 prompt 长度时触发。
  关键词：token 估算、token 计数、API 费用、上下文长度、prompt 优化。
---

# Token 估算器

估算文本的 token 数量，支持多种 LLM 模型的近似计算。

## 能力概览

| 能力 | 说明 |
|------|------|
| Token 估算 | 中英文混合文本的 token 近似计数 |
| 多模型支持 | GPT-4、Claude、Llama、Qwen 等 |
| 费用计算 | 根据 token 数估算 API 调用费用 |
| 模型对比 | 对比同一文本在不同模型中的 token 数 |
| 批量处理 | 批量估算多段文本 |

## 前置条件

- Python 3.8+
- 无第三方依赖

## 使用方法

### Python 代码示例

```python
import re
import math
from typing import Dict, List, Optional
import argparse
import sys

# 不同模型的 token 比率（字符:token 的近似比）
MODEL_RATIOS = {
    "gpt-4": {"chars_per_token": 4.0, "name": "GPT-4"},
    "gpt-4o": {"chars_per_token": 4.0, "name": "GPT-4o"},
    "gpt-3.5-turbo": {"chars_per_token": 4.0, "name": "GPT-3.5 Turbo"},
    "claude-3-opus": {"chars_per_token": 3.5, "name": "Claude 3 Opus"},
    "claude-3-sonnet": {"chars_per_token": 3.5, "name": "Claude 3 Sonnet"},
    "claude-3-haiku": {"chars_per_token": 3.5, "name": "Claude 3 Haiku"},
    "llama-3": {"chars_per_token": 3.8, "name": "Llama 3"},
    "qwen": {"chars_per_token": 3.5, "name": "Qwen"},
    "default": {"chars_per_token": 4.0, "name": "Default"},
}

# API 费用（美元/1K tokens）
MODEL_PRICING = {
    "gpt-4": {"input": 0.03, "output": 0.06},
    "gpt-4o": {"input": 0.005, "output": 0.015},
    "gpt-3.5-turbo": {"input": 0.0005, "output": 0.0015},
    "claude-3-opus": {"input": 0.015, "output": 0.075},
    "claude-3-sonnet": {"input": 0.003, "output": 0.015},
    "claude-3-haiku": {"input": 0.00025, "output": 0.00125},
}

def estimate_tokens(text: str, model: str = "default") -> int:
    """
    估算文本的 token 数量
    
    Args:
        text: 输入文本
        model: 模型名称（见 MODEL_RATIOS）
    
    Returns:
        估算的 token 数量
    """
    if not text:
        return 0
    
    ratio = MODEL_RATIOS.get(model, MODEL_RATIOS["default"])["chars_per_token"]
    
    # 提取中文字符
    cn_chars = len(re.findall(r'[\u4e00-\u9fff\u3400-\u4dbf]', text))
    cn_tokens = cn_chars  # 中文字符通常 1 字符 = 1 token
    
    # 移除中文后处理英文
    en_text = re.sub(r'[\u4e00-\u9fff\u3400-\u4dbf]+', ' ', text).strip()
    en_words = en_text.split() if en_text else []
    en_tokens = len(en_words)
    
    # 其他字符（空格、标点等）
    en_length = len(en_text)
    en_words_length = sum(len(w) for w in en_words)
    other_chars = en_length - en_words_length
    other_tokens = max(0, math.ceil(other_chars / ratio))
    
    return cn_tokens + en_tokens + other_tokens

def estimate_with_detail(text: str, model: str = "default") -> dict:
    """
    详细的 token 估算，包含中英文字符数等
    
    Returns:
        {"model": str, "total_tokens": int, "cn_chars": int, "en_words": int, "other_chars": int, "char_count": int}
    """
    cn_chars = len(re.findall(r'[\u4e00-\u9fff\u3400-\u4dbf]', text))
    en_text = re.sub(r'[\u4e00-\u9fff\u3400-\u4dbf]+', ' ', text).strip()
    en_words = en_text.split() if en_text else []
    
    ratio = MODEL_RATIOS.get(model, MODEL_RATIOS["default"])["chars_per_token"]
    other_chars = len(en_text) - sum(len(w) for w in en_words)
    other_tokens = max(0, math.ceil(other_chars / ratio))
    total = cn_chars + len(en_words) + other_tokens
    
    return {
        "model": model,
        "total_tokens": total,
        "cn_chars": cn_chars,
        "en_words": len(en_words),
        "other_chars": other_chars,
        "char_count": len(text),
    }

def estimate_cost(
    input_tokens: int,
    output_tokens: int,
    model: str = "gpt-4"
) -> dict:
    """根据 token 数估算 API 调用费用"""
    pricing = MODEL_PRICING.get(model)
    if not pricing:
        return {"model": model, "error": f"未知模型定价: {model}"}
    
    input_cost = (input_tokens / 1000) * pricing["input"]
    output_cost = (output_tokens / 1000) * pricing["output"]
    
    return {
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "input_cost": round(input_cost, 6),
        "output_cost": round(output_cost, 6),
        "total_cost": round(input_cost + output_cost, 6),
        "currency": "USD",
    }

def batch_estimate(texts: List[str], model: str = "default") -> dict:
    """批量估算多段文本的 token 数"""
    details = []
    total_tokens = 0
    total_chars = 0
    
    for i, text in enumerate(texts):
        tokens = estimate_tokens(text, model)
        total_tokens += tokens
        total_chars += len(text)
        details.append({"index": i, "tokens": tokens, "chars": len(text)})
    
    return {
        "total_tokens": total_tokens,
        "total_chars": total_chars,
        "text_count": len(texts),
        "details": details,
    }

def compare_models(text: str) -> List[dict]:
    """对比同一文本在不同模型中的 token 数"""
    results = []
    for model_key in ["gpt-4", "claude-3-opus", "llama-3", "qwen"]:
        tokens = estimate_tokens(text, model_key)
        input_cost = MODEL_PRICING.get(model_key, {}).get("input", "N/A")
        results.append({
            "model": model_key,
            "name": MODEL_RATIOS[model_key]["name"],
            "tokens": tokens,
            "input_cost_per_1k": input_cost,
        })
    return sorted(results, key=lambda x: x["tokens"])

# 命令行入口
def main():
    parser = argparse.ArgumentParser(description="Token 估算器")
    parser.add_argument("text", nargs="?", help="输入文本（或使用 --batch）")
    parser.add_argument("--model", default="default", help="模型名称")
    parser.add_argument("--detail", action="store_true", help="显示详细信息")
    parser.add_argument("--cost", action="store_true", help="估算费用")
    parser.add_argument("--compare", action="store_true", help="对比多模型")
    parser.add_argument("--batch", nargs="+", help="批量估算文件")
    
    args = parser.parse_args()
    
    if args.batch:
        # 批量估算
        texts = []
        for file_path in args.batch:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    texts.append(f.read())
            except FileNotFoundError:
                print(f"错误: 文件不存在 - {file_path}")
                return
        
        result = batch_estimate(texts, args.model)
        print(f"总 Token 数: {result['total_tokens']}")
        print(f"总字符数: {result['total_chars']}")
        for d in result["details"]:
            print(f"  段落 {d['index']}: {d['tokens']} tokens")
    elif args.text:
        # 单文本估算
        if args.compare:
            comparison = compare_models(args.text)
            print(f"文本: {args.text}\n")
            print("模型对比:")
            for c in comparison:
                print(f"  {c['name']}: {c['tokens']} tokens")
        elif args.detail:
            detail = estimate_with_detail(args.text, model=args.model)
            print(f"模型: {detail['model']}")
            print(f"Token 数: {detail['total_tokens']}")
            print(f"中文字符: {detail['cn_chars']}")
            print(f"英文单词: {detail['en_words']}")
            print(f"总字符数: {detail['char_count']}")
        else:
            tokens = estimate_tokens(args.text, model=args.model)
            print(f"Token 数: {tokens}")
        
        if args.cost:
            tokens = estimate_tokens(args.text, model=args.model)
            cost = estimate_cost(tokens, 100, model=args.model)
            if "error" not in cost:
                print(f"费用估算 (输入 {tokens} + 输出 100):")
                print(f"  总费用: ${cost['total_cost']}")
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

## 使用示例

```bash
# 估算文本
python token_estimator.py "Hello, world! 你好世界"

# 指定模型
python token_estimator.py --model gpt-4 "你的文本"

# 显示详细信息
python token_estimator.py --detail "测试文本"

# 对比多模型
python token_estimator.py --compare "测试文本"

# 估算费用
python token_estimator.py --cost "测试文本"

# 批量估算
python token_estimator.py --batch file1.txt file2.txt
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 估算结果与实际不符 | 不同模型 tokenizer 实现不同 | 使用 tiktoken 或官方 SDK 精确计数 |
| 中文 token 数偏高 | 中文字符约 1 字符 = 1 token | 已优化，比简单字符/4 更准确 |
| 费用估算与账单差异 | 价格已更新或有折扣 | 查看模型提供方最新定价 |
| 文件批量估算失败 | 文件不存在或编码错误 | 检查文件路径和编码 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
