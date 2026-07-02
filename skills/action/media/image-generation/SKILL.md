---
name: 图片生成
layer: action
category: media
status: unverified
description: >
  调用 ComfyUI API 生成图片，支持自定义工作流。
  当用户想要生成图片、AI 绘图、文生图、图生图时触发。
  关键词：图片生成、AI 绘图、文生图、ComfyUI、Stable Diffusion、Flux。
---

# 图片生成

通过 ComfyUI API 生成图片，支持多种模型和自定义工作流。

## 架构图

```
用户请求
    ↓
┌─────────────────┐
│ ImageGeneration │
│     Skill       │
└────────┬────────┘
         ↓
┌─────────────────┐
│  ComfyUI API    │
│  (HTTP Server)  │
└────────┬────────┘
         ↓
┌─────────────────┐
│  ComfyUI Core   │
│  (模型加载/执行) │
└────────┬────────┘
         ↓
┌─────────────────┐
│  GPU/模型       │
│  (Stable Diffusion) │
└─────────────────┘
```

## 完整代码

### 1. ComfyUI 客户端

```python
import json
import time
import requests
from typing import Dict, Any, Optional, List
from dataclasses import dataclass


@dataclass
class ComfyUIClient:
    """ComfyUI API 客户端"""
    
    server_url: str = "http://127.0.0.1:8188"
    timeout: int = 300
    
    def queue_prompt(self, prompt: Dict[str, Any]) -> str:
        """
        提交工作流到 ComfyUI
        
        Args:
            prompt: 工作流 JSON
        
        Returns:
            prompt_id
        """
        response = requests.post(
            f"{self.server_url}/prompt",
            json={"prompt": prompt},
            timeout=30
        )
        response.raise_for_status()
        return response.json()["prompt_id"]
    
    def get_history(self, prompt_id: str) -> Dict:
        """获取任务历史"""
        response = requests.get(
            f"{self.server_url}/history/{prompt_id}",
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    
    def get_image(
        self, 
        filename: str, 
        subfolder: str = "", 
        folder_type: str = "output"
    ) -> bytes:
        """获取生成的图片"""
        params = {
            "filename": filename,
            "subfolder": subfolder,
            "type": folder_type
        }
        response = requests.get(
            f"{self.server_url}/view",
            params=params,
            timeout=60
        )
        response.raise_for_status()
        return response.content
    
    def wait_for_completion(
        self, 
        prompt_id: str, 
        timeout: int = 300
    ) -> Dict:
        """等待任务完成"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            history = self.get_history(prompt_id)
            if prompt_id in history:
                return history[prompt_id]
            time.sleep(1)
        
        raise TimeoutError(f"任务超时: {prompt_id}")
```

### 2. 图片生成器

```python
class ImageGenerator:
    """图片生成器"""
    
    def __init__(self, client: Optional[ComfyUIClient] = None):
        self.client = client or ComfyUIClient()
    
    def generate(
        self,
        prompt: str,
        negative_prompt: str = "",
        model: str = "v1-5-pruned-emaonly.ckpt",
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg: float = 8.0,
        seed: int = -1
    ) -> bytes:
        """
        生成图片
        
        Args:
            prompt: 正向提示词
            negative_prompt: 负向提示词
            model: 模型名称
            width: 图片宽度
            height: 图片高度
            steps: 采样步数
            cfg: CFG 比例
            seed: 随机种子（-1 为随机）
        
        Returns:
            图片字节数据
        """
        # 构建工作流
        workflow = self._build_workflow(
            prompt=prompt,
            negative_prompt=negative_prompt,
            model=model,
            width=width,
            height=height,
            steps=steps,
            cfg=cfg,
            seed=seed
        )
        
        # 提交任务
        prompt_id = self.client.queue_prompt(workflow)
        
        # 等待完成
        result = self.client.wait_for_completion(prompt_id)
        
        # 获取图片
        outputs = result.get("outputs", {})
        for node_id, node_output in outputs.items():
            if "images" in node_output:
                image_info = node_output["images"][0]
                return self.client.get_image(
                    image_info["filename"],
                    image_info.get("subfolder", ""),
                    image_info.get("type", "output")
                )
        
        raise ValueError("未找到生成的图片")
    
    def _build_workflow(
        self,
        prompt: str,
        negative_prompt: str,
        model: str,
        width: int,
        height: int,
        steps: int,
        cfg: float,
        seed: int
    ) -> Dict[str, Any]:
        """构建标准工作流"""
        if seed == -1:
            seed = int(time.time() * 1000) % (2**32)
        
        return {
            "3": {
                "class_type": "KSampler",
                "inputs": {
                    "cfg": cfg,
                    "denoise": 1,
                    "latent_image": ["5", 0],
                    "model": ["4", 0],
                    "negative": ["7", 0],
                    "positive": ["6", 0],
                    "sampler_name": "euler",
                    "scheduler": "normal",
                    "seed": seed,
                    "steps": steps
                }
            },
            "4": {
                "class_type": "CheckpointLoaderSimple",
                "inputs": {
                    "ckpt_name": model
                }
            },
            "5": {
                "class_type": "EmptyLatentImage",
                "inputs": {
                    "batch_size": 1,
                    "height": height,
                    "width": width
                }
            },
            "6": {
                "class_type": "CLIPTextEncode",
                "inputs": {
                    "clip": ["4", 1],
                    "text": prompt
                }
            },
            "7": {
                "class_type": "CLIPTextEncode",
                "inputs": {
                    "clip": ["4", 1],
                    "text": negative_prompt
                }
            },
            "8": {
                "class_type": "VAEDecode",
                "inputs": {
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                }
            },
            "9": {
                "class_type": "SaveImage",
                "inputs": {
                    "filename_prefix": "ComfyUI",
                    "images": ["8", 0]
                }
            }
        }
    
    def generate_with_workflow(
        self, 
        workflow: Dict[str, Any]
    ) -> bytes:
        """使用自定义工作流生成图片"""
        prompt_id = self.client.queue_prompt(workflow)
        result = self.client.wait_for_completion(prompt_id)
        
        outputs = result.get("outputs", {})
        for node_id, node_output in outputs.items():
            if "images" in node_output:
                image_info = node_output["images"][0]
                return self.client.get_image(
                    image_info["filename"],
                    image_info.get("subfolder", ""),
                    image_info.get("type", "output")
                )
        
        raise ValueError("未找到生成的图片")
    
    def batch_generate(
        self,
        prompts: List[str],
        **kwargs
    ) -> List[bytes]:
        """批量生成图片"""
        results = []
        for prompt in prompts:
            image = self.generate(prompt, **kwargs)
            results.append(image)
        return results
```

## 使用示例

```python
# 基础用法
generator = ImageGenerator()
image = generator.generate(
    prompt="a beautiful sunset over the ocean",
    negative_prompt="blurry, low quality",
    width=1024,
    height=512
)

# 保存图片
with open("output.png", "wb") as f:
    f.write(image)

# 批量生成
images = generator.batch_generate(
    prompts=["cat", "dog", "bird"],
    width=512,
    height=512
)
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 连接失败 | ComfyUI 未启动 | 启动 ComfyUI 服务器 |
| 生成超时 | GPU 负载高 | 增加 timeout 参数 |
| 内存不足 | 模型太大 | 使用小模型或减少分辨率 |
| 图片损坏 | 生成过程中断 | 重试生成 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| requests | 2.28+ | HTTP 请求 |
| ComfyUI | - | 图片生成服务 |
