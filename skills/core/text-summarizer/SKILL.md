---
name: 文本摘要生成器
layer: core
category: reasoning
status: unverified
description: >
  对长文本生成摘要，支持抽取式和生成式两种摘要方式。
  当用户需要总结文章、提取要点、压缩文本、生成摘要时触发。
  关键词：摘要、总结、提取要点、压缩文本、文本总结、文章摘要。
requirements:
  - name: openai
    version: ">=1.0.0"
    optional: true
    description: "生成式摘要需要，抽取式无需"
---

# 文本摘要生成器

对长文本生成简洁准确的摘要，支持抽取式和生成式两种方式。

## 能力概览

| 能力 | 说明 |
|------|------|
| 抽取式摘要 | 从原文中抽取关键句子组成摘要 |
| 生成式摘要 | 基于 LLM 生成全新的摘要文本 |
| 多语言支持 | 中文、英文等多语言文本处理 |
| 关键词提取 | 自动提取文本核心关键词 |

## 前置条件

- Python 3.8+
- 抽取式摘要：无第三方依赖
- 生成式摘要：需要 LLM API（OpenAI/Anthropic/本地模型）

## 使用方法

### 抽取式摘要：基于 TextRank 算法

```python
import re
import math
from collections import Counter
from typing import List, Tuple

# 中英文停用词表
STOP_WORDS = {
    # 中文
    '的', '了', '是', '在', '我', '有', '和', '就', '不', '人', '都', '一', '一个',
    '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看', '好',
    '自己', '这', '他', '她', '它', '们', '那', '被', '让', '把', '从', '对',
    # 英文
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
    'before', 'after', 'and', 'but', 'or', 'nor', 'not', 'so', 'yet',
    'it', 'its', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she',
    'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his',
}

def extractive_summary(text: str, num_sentences: int = 3) -> str:
    """
    抽取式摘要：从原文中抽取最重要的句子
    
    Args:
        text: 输入文本
        num_sentences: 返回的句子数量
        
    Returns:
        摘要文本
    """
    # 输入验证
    if not text or not text.strip():
        return ""
    
    # 纯标点检查
    cleaned = re.sub(r'[\s\p{P}]', '', text)
    if not cleaned:
        return text
    
    sentences = split_sentences(text)
    if len(sentences) <= num_sentences:
        return text
    
    word_freq = get_word_frequencies(text)
    
    sentence_scores = {}
    for i, sentence in enumerate(sentences):
        score = calculate_sentence_score(sentence, word_freq, i, len(sentences))
        sentence_scores[i] = score
    
    top_indices = sorted(
        sorted(sentence_scores, key=sentence_scores.get, reverse=True)[:num_sentences]
    )
    
    return ' '.join(sentences[i] for i in top_indices)

def split_sentences(text: str) -> List[str]:
    """分割文本为句子"""
    pattern = r'[。！？.!?；;]+'
    sentences = re.split(pattern, text)
    return [s.strip() for s in sentences if len(s.strip()) > 2]

def get_word_frequencies(text: str) -> dict:
    """
    计算词频（基于字符 N-gram 的近似分词）
    
    注意：这是近似分词，不是真正的分词。
    中文按连续汉字分词，英文按空格分词。
    """
    # 中文连续汉字 + 英文单词
    words = re.findall(r'[\u4e00-\u9fff]+|[a-zA-Z]+', text.lower())
    # 过滤停用词
    filtered = [w for w in words if w not in STOP_WORDS and len(w) > 1]
    return dict(Counter(filtered))

def calculate_sentence_score(
    sentence: str, 
    word_freq: dict, 
    position: int, 
    total: int
) -> float:
    """计算句子重要性得分（首尾句权重更高）"""
    words = re.findall(r'[\u4e00-\u9fff]+|[a-zA-Z]+', sentence.lower())
    if not words:
        return 0.0
    
    freq_score = sum(word_freq.get(w, 0) for w in words) / len(words) if words else 0
    
    # 位置权重：首句和尾句得分更高
    if position < 2 or position > total - 3:
        position_score = 1.0
    else:
        position_score = 0.5
    
    return freq_score * 0.7 + position_score * 0.3

# 使用示例
if __name__ == "__main__":
    text = """
    人工智能正在改变我们的生活方式。从智能手机到自动驾驶汽车，AI技术已经渗透到各个领域。
    机器学习作为AI的核心技术，让计算机能够从数据中学习并做出决策。
    深度学习则进一步推动了图像识别、自然语言处理等领域的突破。
    然而，AI的发展也带来了隐私、就业等方面的挑战。
    我们需要在享受AI便利的同时，认真思考如何应对其带来的社会影响。
    """
    summary = extractive_summary(text, num_sentences=2)
    print("抽取式摘要：", summary)
```

### 生成式摘要：基于 LLM API

```python
import os
from typing import Optional

def generate_summary(
    text: str,
    max_length: int = 200,
    language: str = "zh",
    api_key: Optional[str] = None,
    model: str = "gpt-4o-mini",
    base_url: Optional[str] = None
) -> str:
    """
    生成式摘要：使用 LLM 生成全新的摘要
    
    Args:
        text: 输入文本
        max_length: 摘要最大长度（字符数）
        language: 语言（zh/en）
        api_key: API Key（或设置 OPENAI_API_KEY 环境变量）
        model: 模型名称（支持 OpenAI 兼容 API）
        base_url: API 基础 URL（用于第三方代理或本地模型）
    
    Returns:
        生成的摘要文本
    """
    try:
        import openai
    except ImportError:
        raise ImportError("请安装 openai: pip install openai>=1.0.0")
    
    client_kwargs = {"api_key": api_key or os.environ.get("OPENAI_API_KEY")}
    if base_url:
        client_kwargs["base_url"] = base_url
    
    client = openai.OpenAI(**client_kwargs)
    
    lang_prompt = "用中文" if language == "zh" else "in English"
    prompt = f"""请对以下文本生成一段简洁的摘要，控制在{max_length}字以内。

文本内容：
{text[:4000]}

要求：
1. 保留核心观点和关键信息
2. 语言流畅自然
3. 不超过{max_length}字

请直接输出摘要内容，不要加前缀："""
    
    try:
        # 尝试使用 response_format，不支持时 fallback
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=500,
                response_format={"type": "json_object"}
            )
        except Exception:
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=500
            )
        
        return response.choices[0].message.content.strip()
    except Exception as e:
        # 降级：返回原文前 N 句作为摘要
        sentences = split_sentences(text)
        return ' '.join(sentences[:3]) if sentences else text[:200]

# 使用示例
if __name__ == "__main__":
    text = "你的长文本内容..."
    
    # OpenAI
    summary = generate_summary(text, max_length=150, model="gpt-4o-mini")
    
    # 第三方 API 代理
    summary = generate_summary(
        text, 
        model="gpt-4o",
        base_url="https://api.example.com/v1"
    )
    
    # 本地模型
    summary = generate_summary(
        text,
        model="local-model",
        base_url="http://localhost:11434/v1"
    )
```

### 关键词提取

```python
def extract_keywords(text: str, top_k: int = 5) -> List[Tuple[str, float]]:
    """提取文本关键词"""
    word_freq = get_word_frequencies(text)
    total = sum(word_freq.values())
    
    if total == 0:
        return []
    
    scored_words = [
        (word, count / total) 
        for word, count in word_freq.items()
        if len(word) > 1
    ]
    
    return sorted(scored_words, key=lambda x: x[1], reverse=True)[:top_k]
```

### 命令行入口

```python
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="文本摘要生成器")
    parser.add_argument("input", help="输入文件路径（或使用 - 从 stdin 读取）")
    parser.add_argument("--method", choices=["extractive", "generative"], default="extractive")
    parser.add_argument("--sentences", type=int, default=3, help="抽取式摘要句子数")
    parser.add_argument("--max-length", type=int, default=200, help="生成式摘要最大长度")
    parser.add_argument("--model", default="gpt-4o-mini", help="生成式摘要模型")
    parser.add_argument("--api-key", help="API Key")
    parser.add_argument("--keywords", action="store_true", help="提取关键词")
    parser.add_argument("--top-k", type=int, default=5, help="关键词数量")
    
    args = parser.parse_args()
    
    # 读取输入
    if args.input == "-":
        text = sys.stdin.read()
    else:
        with open(args.input, 'r', encoding='utf-8') as f:
            text = f.read()
    
    if args.keywords:
        keywords = extract_keywords(text, args.top_k)
        print("关键词：")
        for word, score in keywords:
            print(f"  {word}: {score:.3f}")
    elif args.method == "generative":
        summary = generate_summary(text, max_length=args.max_length, model=args.model, api_key=args.api_key)
        print("生成式摘要：", summary)
    else:
        summary = extractive_summary(text, num_sentences=args.sentences)
        print("抽取式摘要：", summary)

if __name__ == "__main__":
    main()
```

## 使用示例

```bash
# 抽取式摘要
python text_summarizer.py --method extractive --sentences 3 input.txt

# 生成式摘要
python text_summarizer.py --method generative --max-length 200 input.txt

# 提取关键词
python text_summarizer.py --keywords --top-k 5 input.txt

# 从 stdin 读取
cat article.txt | python text_summarizer.py -
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 抽取式摘要质量不佳 | 文本过短或停用词干扰 | 确保文本至少 5 个句子 |
| 生成式 API 失败 | API Key 未设置 | 设置环境变量或传 --api-key |
| 生成式 API 失败 | 模型不支持 | 使用 --model 指定支持的模型 |
| 中文分句不准确 | 正则未覆盖所有标点 | 已内置常见标点，可扩展 split_sentences |
| 输出截断 | 文本过长 | 抽取式自动处理，生成式限制 4000 字 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| openai | ≥1.0.0 | 生成式摘要（可选） |

## Agent 执行规范

- **先判断文本长度**：短文本直接返回，无需摘要
- **选择合适方法**：无 API 时使用抽取式，有 API 时可选生成式
- **验证输出**：摘要应保留原文核心信息
- **输入验证**：空文本或纯标点直接返回原文
