---
name: 邮件发送
layer: action
category: device
status: unverified
description: >
  发送文本和 HTML 邮件，支持附件功能。
  当用户需要发送邮件、通知、报告、自动化邮件、批量发送时触发。
  关键词：邮件发送、email、SMTP、发送通知、邮件附件、批量邮件。
---

# 邮件发送

发送文本和 HTML 邮件，支持单发、群发和附件功能。

## 能力概览

| 能力 | 说明 |
|------|------|
| 文本邮件 | 发送纯文本邮件 |
| HTML 邮件 | 发送富文本邮件 |
| 附件支持 | 支持单个/多个附件 |
| 批量发送 | 支持群发邮件 |
| SMTP 支持 | 支持主流邮件服务商（SSL/TLS） |

## 前置条件

- Python 3.8+
- 无第三方依赖（使用内置 smtplib + email）
- SMTP 服务器账号（如 Gmail、QQ邮箱、163邮箱等）

## 安装步骤

无额外安装。使用 Python 内置模块。

### SMTP 服务器配置

| 服务商 | SMTP 服务器 | 端口 | 连接方式 |
|--------|-------------|------|----------|
| Gmail | smtp.gmail.com | 587 | STARTTLS |
| QQ邮箱 | smtp.qq.com | 587 | STARTTLS |
| 163邮箱 | smtp.163.com | 465 | SSL |
| Outlook | smtp.office365.com | 587 | STARTTLS |

## 使用方法

### 完整代码

```python
import smtplib
import argparse
import os
import mimetypes
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from typing import List, Optional, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed


class EmailSender:
    """邮件发送器"""
    
    def __init__(
        self,
        smtp_server: str,
        smtp_port: int,
        username: str,
        password: str,
        use_tls: bool = True
    ):
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
        self.use_tls = use_tls
    
    def send_text(
        self,
        to: str | List[str],
        subject: str,
        body: str,
        cc: Optional[str | List[str]] = None,
        bcc: Optional[str | List[str]] = None
    ) -> Dict:
        """发送文本邮件"""
        if isinstance(to, str):
            to = [to]
        
        msg = MIMEText(body, 'plain', 'utf-8')
        msg['From'] = self.username
        msg['To'] = ', '.join(to)
        msg['Subject'] = subject
        
        if cc:
            if isinstance(cc, str):
                cc = [cc]
            msg['Cc'] = ', '.join(cc)
        
        # BCC 收件人不写入邮件头
        all_recipients = to + (cc or []) + (bcc or [])
        return self._send(msg, all_recipients)
    
    def send_html(
        self,
        to: str | List[str],
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        cc: Optional[str | List[str]] = None,
        bcc: Optional[str | List[str]] = None
    ) -> Dict:
        """发送 HTML 邮件"""
        if isinstance(to, str):
            to = [to]
        
        msg = MIMEMultipart('alternative')
        msg['From'] = self.username
        msg['To'] = ', '.join(to)
        msg['Subject'] = subject
        
        if cc:
            if isinstance(cc, str):
                cc = [cc]
            msg['Cc'] = ', '.join(cc)
        
        if text_body:
            msg.attach(MIMEText(text_body, 'plain', 'utf-8'))
        
        msg.attach(MIMEText(html_body, 'html', 'utf-8'))
        
        all_recipients = to + (cc or []) + (bcc or [])
        return self._send(msg, all_recipients)
    
    def send_with_attachments(
        self,
        to: str | List[str],
        subject: str,
        body: str,
        attachments: List[str],
        is_html: bool = False,
        cc: Optional[str | List[str]] = None,
        bcc: Optional[str | List[str]] = None
    ) -> Dict:
        """
        发送带附件的邮件
        
        Args:
            to: 收件人
            subject: 主题
            body: 邮件正文
            attachments: 附件文件路径列表
            is_html: 正文是否为 HTML
            cc: 抄送（可选）
            bcc: 密送（可选，不写入邮件头）
        """
        if isinstance(to, str):
            to = [to]
        
        msg = MIMEMultipart()
        msg['From'] = self.username
        msg['To'] = ', '.join(to)
        msg['Subject'] = subject
        
        if cc:
            if isinstance(cc, str):
                cc = [cc]
            msg['Cc'] = ', '.join(cc)
        
        content_type = 'html' if is_html else 'plain'
        msg.attach(MIMEText(body, content_type, 'utf-8'))
        
        missing_attachments = []
        
        for file_path in attachments:
            if os.path.exists(file_path):
                with open(file_path, 'rb') as f:
                    # 根据扩展名设置正确的 MIME 类型
                    mime_type, _ = mimetypes.guess_type(file_path)
                    subtype = mime_type.split('/')[-1] if mime_type else 'octet-stream'
                    part = MIMEApplication(f.read(), _subtype=subtype)
                    filename = os.path.basename(file_path)
                    part.add_header(
                        'Content-Disposition', 
                        f'attachment; filename="{filename}"'
                    )
                    msg.attach(part)
            else:
                missing_attachments.append(file_path)
        
        result = self._send(msg, to + (cc or []) + (bcc or []))
        result["missing_attachments"] = missing_attachments
        return result
    
    def _send(self, msg: MIMEMultipart, recipients: List[str]) -> Dict:
        """
        实际发送邮件
        
        支持 SSL（465端口）和 STARTTLS（587端口）两种方式
        """
        try:
            # 465 端口使用 SSL 直连，其他端口使用 STARTTLS
            if self.smtp_port == 465:
                server = smtplib.SMTP_SSL(self.smtp_server, self.smtp_port, timeout=30)
            else:
                server = smtplib.SMTP(self.smtp_server, self.smtp_port, timeout=30)
                if self.use_tls:
                    server.starttls()
            
            with server:
                server.login(self.username, self.password)
                server.send_message(msg, self.username, recipients)
                
                return {
                    "success": True,
                    "message": f"邮件已发送至: {', '.join(recipients)}"
                }
        except smtplib.SMTPAuthenticationError:
            return {
                "success": False,
                "message": "SMTP 认证失败，请检查用户名和密码"
            }
        except smtplib.SMTPException as e:
            return {
                "success": False,
                "message": f"SMTP 错误: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "message": f"发送失败: {str(e)}"
            }


class BulkEmailSender:
    """批量邮件发送器"""
    
    def __init__(self, sender: EmailSender, max_workers: int = 5):
        self.sender = sender
        self.max_workers = max_workers
    
    def send_bulk(
        self,
        recipients: List[str],
        subject: str,
        body: str,
        is_html: bool = False
    ) -> List[Dict]:
        """
        批量发送邮件
        
        Returns:
            [{"email": str, "success": bool, "message": str}, ...]
        """
        results = []
        
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {}
            for email in recipients:
                future = executor.submit(
                    self._send_one, email, subject, body, is_html
                )
                futures[future] = email
            
            for future in as_completed(futures):
                email = futures[future]
                try:
                    result = future.result()
                except Exception as e:
                    result = {"success": False, "message": str(e)}
                results.append({"email": email, **result})
        
        return results
    
    def _send_one(
        self, 
        email: str, 
        subject: str, 
        body: str, 
        is_html: bool
    ) -> Dict:
        """发送单封邮件"""
        if is_html:
            return self.sender.send_html(email, subject, body)
        else:
            return self.sender.send_text(email, subject, body)


class EmailProviders:
    """邮件服务商预设配置"""
    
    PROVIDERS = {
        "qq": {
            "smtp_server": "smtp.qq.com",
            "smtp_port": 587,
            "use_tls": True
        },
        "163": {
            "smtp_server": "smtp.163.com",
            "smtp_port": 465,
            "use_tls": False
        },
        "gmail": {
            "smtp_server": "smtp.gmail.com",
            "smtp_port": 587,
            "use_tls": True
        },
        "outlook": {
            "smtp_server": "smtp.office365.com",
            "smtp_port": 587,
            "use_tls": True
        }
    }
    
    @classmethod
    def get_sender(
        cls, 
        provider: str, 
        username: str, 
        password: str
    ) -> EmailSender:
        """获取预配置的发送器"""
        if provider not in cls.PROVIDERS:
            raise ValueError(f"不支持的服务商: {provider}，可选: {list(cls.PROVIDERS.keys())}")
        
        config = cls.PROVIDERS[provider]
        return EmailSender(
            smtp_server=config["smtp_server"],
            smtp_port=config["smtp_port"],
            username=username,
            password=password,
            use_tls=config["use_tls"]
        )


# 命令行入口
def main():
    parser = argparse.ArgumentParser(description="邮件发送工具")
    
    # 服务器配置
    parser.add_argument("--provider", choices=["qq", "163", "gmail", "outlook"], help="邮件服务商")
    parser.add_argument("--smtp-server", help="SMTP 服务器地址")
    parser.add_argument("--smtp-port", type=int, help="SMTP 端口")
    parser.add_argument("--username", required=True, help="发件人邮箱")
    parser.add_argument("--password", required=True, help="SMTP 密码/授权码")
    parser.add_argument("--no-tls", action="store_true", help="禁用 STARTTLS")
    
    # 收件人
    parser.add_argument("--to", help="收件人（逗号分隔）")
    parser.add_argument("--cc", help="抄送（逗号分隔）")
    parser.add_argument("--recipients", help="收件人列表文件（每行一个）")
    
    # 邮件内容
    parser.add_argument("--subject", required=True, help="邮件主题")
    parser.add_argument("--body", help="邮件正文")
    parser.add_argument("--html", help="HTML 正文")
    parser.add_argument("--attach", action="append", help="附件路径（可多次使用）")
    
    args = parser.parse_args()
    
    # 创建发送器
    if args.provider:
        sender = EmailProviders.get_sender(args.provider, args.username, args.password)
    else:
        if not args.smtp_server:
            parser.error("需要 --smtp-server 或 --provider")
        sender = EmailSender(
            smtp_server=args.smtp_server,
            smtp_port=args.smtp_port or 587,
            username=args.username,
            password=args.password,
            use_tls=not args.no_tls
        )
    
    # 获取收件人
    if args.recipients:
        with open(args.recipients, 'r') as f:
            recipients = [line.strip() for line in f if line.strip()]
    elif args.to:
        recipients = [email.strip() for email in args.to.split(',')]
    else:
        parser.error("需要 --to 或 --recipients")
    
    # 发送邮件
    if args.attach:
        result = sender.send_with_attachments(
            to=recipients,
            subject=args.subject,
            body=args.body or "",
            attachments=args.attach,
            is_html=bool(args.html),
            cc=args.cc
        )
    elif args.html:
        result = sender.send_html(
            to=recipients,
            subject=args.subject,
            html_body=args.html,
            text_body=args.body,
            cc=args.cc
        )
    else:
        result = sender.send_text(
            to=recipients,
            subject=args.subject,
            body=args.body or "",
            cc=args.cc
        )
    
    print(result["message"])
    if result.get("missing_attachments"):
        print(f"警告: 以下附件不存在: {result['missing_attachments']}")


if __name__ == "__main__":
    main()
```

## 使用示例

### 命令行用法

```bash
# 发送文本邮件（QQ邮箱）
python email_sender.py --provider qq --username user@qq.com --password xxx \
  --to recipient@example.com --subject "测试" --body "邮件内容"

# 发送 HTML 邮件（163邮箱，SSL）
python email_sender.py --provider 163 --username user@163.com --password xxx \
  --to recipient@example.com --subject "报告" --html "<h1>报告</h1>"

# 发送带附件邮件
python email_sender.py --provider qq --username user@qq.com --password xxx \
  --to recipient@example.com --subject "文件" --body "请查收附件" \
  --attach file1.pdf --attach file2.docx

# 批量发送
python email_sender.py --provider qq --username user@qq.com --password xxx \
  --recipients list.txt --subject "通知" --body "系统通知"

# 指定 SMTP 服务器
python email_sender.py --smtp-server smtp.example.com --smtp-port 465 \
  --username user@example.com --password xxx \
  --to recipient@example.com --subject "测试" --body "邮件内容" --no-tls
```

### Python 代码调用

```python
# 使用预设服务商
sender = EmailProviders.get_sender("163", "user@163.com", "password")
result = sender.send_text("recipient@example.com", "测试", "内容")

# 使用自定义 SMTP
sender = EmailSender("smtp.example.com", 465, "user@example.com", "password")
result = sender.send_with_attachments(
    to="recipient@example.com",
    subject="文件",
    body="请查收",
    attachments=["file.pdf"]
)

# 批量发送
bulk = BulkEmailSender(sender, max_workers=10)
results = bulk.send_bulk(["a@x.com", "b@x.com"], "通知", "内容")
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| SMTP 认证失败 | 密码错误或需要授权码 | 开启 SMTP 服务，获取授权码 |
| 连接超时 | 网络问题或端口错误 | 检查端口：587用STARTTLS，465用SSL |
| 邮件被拦截 | 发送频率过高 | 降低频率，设置 SPF/DKIM |
| 附件过大 | 超过服务商限制 | 压缩文件或分卷发送 |

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | 3.8+ | 运行环境 |
| smtplib | 内置 | SMTP 客户端 |
| email | 内置 | 邮件构造 |

## Agent 执行规范

- **密码安全**：使用环境变量存储密码，不要硬编码
- **发送确认**：批量发送前先测试单封
- **错误记录**：记录所有发送失败的邮件
- **频率限制**：遵守邮件服务商的发送限制
