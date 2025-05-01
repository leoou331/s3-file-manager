FROM python:3.9-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .
COPY templates/ templates/

# 设置环境变量 - 生产环境请通过环境变量注入或使用密钥管理服务
ENV SECRET_NAME="your-secret-name"
ENV S3_BUCKET_NAME="your-bucket-name"
# AWS认证信息，实际使用时建议使用IAM角色或挂载凭证文件
# ENV AWS_ACCESS_KEY_ID="your-access-key"
# ENV AWS_SECRET_ACCESS_KEY="your-secret-key"
ENV AWS_DEFAULT_REGION="your-region"
ENV AWS_REGION="your-region"

# 设置 Flask 的 secret key - 生产环境请使用随机生成的密钥
# ENV FLASK_SECRET_KEY="your-secret-key"

# 暴露端口
EXPOSE 5000

# 使用 Gunicorn 启动应用，4个工作进程
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
