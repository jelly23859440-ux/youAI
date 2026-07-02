---
name: 图片处理器
layer: action
category: file
status: unverified
description: 图片处理工具，支持格式转换、缩放、裁剪、水印、压缩、批量处理
version: 1.1
requirements:
  - name: Pillow
    version: ">=10.0"
    required: true
---

# 图片处理器

图片处理工具，支持裁剪、缩放、格式转换、水印和批量处理。

## 功能特性

- 图片缩放（保持宽高比）
- 图片裁剪
- 格式转换（PNG, JPG, WEBP, BMP 等）
- 批量处理（返回结构化结果）
- 添加水印（跨平台字体支持）
- 图片压缩
- 获取图片信息
- 缩略图生成

## 安装依赖

```bash
pip install Pillow
```

## 使用方法

### Python 代码示例

```python
import os
import platform
from PIL import Image, ImageDraw, ImageFont
from typing import Tuple, Optional, List, Dict, Any
from pathlib import Path


class ImageProcessor:
    """图片处理器"""
    
    SUPPORTED_FORMATS = {
        '.jpg', '.jpeg', '.png', '.gif', '.bmp', 
        '.webp', '.tiff', '.ico'
    }
    
    # 跨平台字体路径
    FONT_PATHS = [
        "arial.ttf",                                    # Windows
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",  # Linux
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",  # Linux
        "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",  # Linux 中文
        "/System/Library/Fonts/Helvetica.ttc",           # macOS
        "/System/Library/Fonts/PingFang.ttc",            # macOS 中文
    ]
    
    def _get_font(self, font_size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
        """跨平台获取字体"""
        for fp in self.FONT_PATHS:
            try:
                return ImageFont.truetype(fp, font_size)
            except IOError:
                continue
        return ImageFont.load_default()
    
    def resize(
        self,
        input_path: str,
        output_path: str,
        width: Optional[int] = None,
        height: Optional[int] = None,
        maintain_ratio: bool = True
    ) -> Image.Image:
        """缩放图片"""
        with Image.open(input_path) as img:
            original_width, original_height = img.size
            
            if width and height and not maintain_ratio:
                new_size = (width, height)
            elif width:
                ratio = width / original_width
                height = int(original_height * ratio)
                new_size = (width, height)
            elif height:
                ratio = height / original_height
                width = int(original_width * ratio)
                new_size = (width, height)
            else:
                new_size = img.size
            
            resized_img = img.resize(new_size, Image.Resampling.LANCZOS)
            resized_img.save(output_path)
            
            return resized_img
    
    def crop(
        self,
        input_path: str,
        output_path: str,
        box: Tuple[int, int, int, int]
    ) -> Image.Image:
        """裁剪图片"""
        with Image.open(input_path) as img:
            cropped_img = img.crop(box)
            cropped_img.save(output_path)
            return cropped_img
    
    def convert(
        self,
        input_path: str,
        output_path: str,
        quality: int = 95
    ) -> Image.Image:
        """格式转换"""
        with Image.open(input_path) as img:
            output_format = Path(output_path).suffix.lower()
            if output_format in ('.jpg', '.jpeg', '.bmp') and img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            save_kwargs = {}
            if output_format in ('.jpg', '.jpeg', '.webp'):
                save_kwargs['quality'] = quality
            
            img.save(output_path, **save_kwargs)
            return img
    
    def add_watermark(
        self,
        input_path: str,
        output_path: str,
        text: str,
        position: str = "bottom-right",
        opacity: int = 128,
        font_size: int = 24
    ) -> Image.Image:
        """添加文字水印（跨平台字体支持）"""
        with Image.open(input_path) as img:
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            txt_layer = Image.new('RGBA', img.size, (255, 255, 255, 0))
            draw = ImageDraw.Draw(txt_layer)
            
            # 跨平台字体探测
            font = self._get_font(font_size)
            
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            
            width, height = img.size
            padding = 20
            
            positions = {
                "top-left": (padding, padding),
                "top-right": (width - text_width - padding, padding),
                "bottom-left": (padding, height - text_height - padding),
                "bottom-right": (width - text_width - padding, height - text_height - padding),
                "center": ((width - text_width) // 2, (height - text_height) // 2),
            }
            
            x, y = positions.get(position, positions["bottom-right"])
            
            draw.text((x, y), text, fill=(255, 255, 255, opacity), font=font)
            
            watermarked = Image.alpha_composite(img, txt_layer)
            watermarked = watermarked.convert('RGB')
            watermarked.save(output_path)
            
            return watermarked
    
    def compress(
        self,
        input_path: str,
        output_path: str,
        quality: int = 85,
        optimize: bool = True
    ) -> Image.Image:
        """压缩图片"""
        with Image.open(input_path) as img:
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # 从输出路径推断格式
            output_format = Path(output_path).suffix.lower()
            format_map = {
                '.jpg': 'JPEG', '.jpeg': 'JPEG',
                '.png': 'PNG', '.webp': 'WEBP',
                '.bmp': 'BMP', '.gif': 'GIF'
            }
            fmt = format_map.get(output_format)
            
            save_kwargs = {'quality': quality, 'optimize': optimize}
            if fmt:
                save_kwargs['format'] = fmt
            
            img.save(output_path, **save_kwargs)
            return img
    
    def get_info(self, image_path: str) -> Dict[str, Any]:
        """获取图片信息"""
        with Image.open(image_path) as img:
            file_size = os.path.getsize(image_path)
            
            return {
                "format": img.format,
                "mode": img.mode,
                "size": img.size,
                "width": img.width,
                "height": img.height,
                "file_size": file_size,
                "file_size_kb": file_size / 1024,
                "file_size_mb": file_size / (1024 * 1024),
            }
    
    def batch_process(
        self,
        input_dir: str,
        output_dir: str,
        operation: str = "resize",
        **kwargs
    ) -> Dict[str, Any]:
        """
        批量处理目录中的图片
        
        Returns:
            {
                "success": [str],           # 成功的文件列表
                "failed": [{"file": str, "error": str}],  # 失败的文件列表
                "total": int,               # 总文件数
                "success_count": int,       # 成功数
                "failed_count": int         # 失败数
            }
        """
        os.makedirs(output_dir, exist_ok=True)
        success_files = []
        failed_files = []
        
        input_path = Path(input_dir)
        
        for img_file in input_path.iterdir():
            if img_file.suffix.lower() not in self.SUPPORTED_FORMATS:
                continue
            
            output_file = Path(output_dir) / img_file.name
            
            try:
                if operation == "resize":
                    self.resize(
                        str(img_file),
                        str(output_file),
                        width=kwargs.get('width'),
                        height=kwargs.get('height')
                    )
                elif operation == "convert":
                    target_format = kwargs.get('format', '.jpg')
                    output_file = output_file.with_suffix(target_format)
                    self.convert(str(img_file), str(output_file))
                elif operation == "compress":
                    self.compress(
                        str(img_file),
                        str(output_file),
                        quality=kwargs.get('quality', 85)
                    )
                
                success_files.append(str(output_file))
            
            except Exception as e:
                failed_files.append({"file": str(img_file), "error": str(e)})
        
        total = len(success_files) + len(failed_files)
        
        return {
            "success": success_files,
            "failed": failed_files,
            "total": total,
            "success_count": len(success_files),
            "failed_count": len(failed_files),
        }
    
    def resize_to_fit(
        self,
        input_path: str,
        output_path: str,
        max_width: int,
        max_height: int
    ) -> Image.Image:
        """缩放图片以适应指定尺寸"""
        with Image.open(input_path) as img:
            width, height = img.size
            ratio = min(max_width / width, max_height / height)
            
            if ratio < 1:
                new_width = int(width * ratio)
                new_height = int(height * ratio)
                img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            img.save(output_path)
            return img
    
    def create_thumbnail(
        self,
        input_path: str,
        output_path: str,
        size: Tuple[int, int] = (128, 128)
    ) -> Image.Image:
        """创建缩略图"""
        with Image.open(input_path) as img:
            img.thumbnail(size, Image.Resampling.LANCZOS)
            img.save(output_path)
            return img


# 命令行入口
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="图片处理工具")
    parser.add_argument("action", choices=["resize", "crop", "convert", "compress", "info", "batch", "watermark"])
    parser.add_argument("input", help="输入文件或目录")
    parser.add_argument("output", nargs="?", help="输出文件或目录")
    parser.add_argument("--width", type=int, help="目标宽度")
    parser.add_argument("--height", type=int, help="目标高度")
    parser.add_argument("--box", help="裁剪区域: left,top,right,bottom")
    parser.add_argument("--quality", type=int, default=85, help="输出质量")
    parser.add_argument("--text", help="水印文字")
    parser.add_argument("--format", help="目标格式")
    parser.add_argument("--operation", choices=["resize", "convert", "compress"], default="resize", help="批量操作类型")
    parser.add_argument("--position", default="bottom-right", choices=["top-left", "top-right", "bottom-left", "bottom-right", "center"], help="水印位置")
    parser.add_argument("--opacity", type=int, default=128, help="水印透明度 (0-255)")
    
    args = parser.parse_args()
    
    processor = ImageProcessor()
    
    if args.action == "info":
        info = processor.get_info(args.input)
        for key, value in info.items():
            print(f"{key}: {value}")
    
    elif args.action == "resize":
        processor.resize(args.input, args.output, width=args.width, height=args.height)
        print(f"缩放完成: {args.output}")
    
    elif args.action == "crop":
        box = tuple(map(int, args.box.split(',')))
        processor.crop(args.input, args.output, box)
        print(f"裁剪完成: {args.output}")
    
    elif args.action == "convert":
        processor.convert(args.input, args.output)
        print(f"转换完成: {args.output}")
    
    elif args.action == "compress":
        processor.compress(args.input, args.output, quality=args.quality)
        print(f"压缩完成: {args.output}")
    
    elif args.action == "watermark":
        processor.add_watermark(
            args.input, args.output, args.text,
            position=args.position, opacity=args.opacity
        )
        print(f"水印添加完成: {args.output}")
    
    elif args.action == "batch":
        result = processor.batch_process(
            args.input, args.output,
            operation=args.operation,
            width=args.width,
            height=args.height
        )
        print(f"批量处理完成: {result['success_count']} 成功, {result['failed_count']} 失败")
        for err in result['failed']:
            print(f"  失败: {err['file']} - {err['error']}")
```

## 使用示例

```python
from image_processor import ImageProcessor

processor = ImageProcessor()

# 获取图片信息
info = processor.get_info("photo.jpg")
print(f"尺寸: {info['width']}x{info['height']}")

# 批量处理（结构化结果）
result = processor.batch_process(
    "./photos",
    "./output",
    operation="resize",
    width=640
)
print(f"成功: {result['success_count']}, 失败: {result['failed_count']}")
for err in result['failed']:
    print(f"  {err['file']}: {err['error']}")

# 添加水印（跨平台）
processor.add_watermark("photo.jpg", "watermarked.jpg", "© 2024", position="center")
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| Pillow 未安装 | 未安装依赖 | `pip install Pillow` |
| 不支持的格式 | 文件格式不支持 | 检查 SUPPORTED_FORMATS |
| 内存不足 | 大图处理 | 使用 resize_to_fit 减小尺寸 |
| 水印字体太小 | 系统字体不存在 | 代码自动探测多平台字体 |
| 批量处理部分失败 | 文件损坏或权限问题 | 检查返回的 failed 列表 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| Pillow | 10.0+ | 图片处理 |
