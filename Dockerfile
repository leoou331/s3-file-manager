FROM python:3.9-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .
COPY templates/ templates/

# 设置环境变量
ENV SECRET_NAME="s3-file-manager-user"
ENV S3_BUCKET_NAME="s3-file-manager-bucket"
# AWS认证信息，实际使用时建议使用IAM角色或挂载凭证文件
# ENV AWS_ACCESS_KEY_ID="your-access-key"
# ENV AWS_SECRET_ACCESS_KEY="your-secret-key"
ENV AWS_DEFAULT_REGION="cn-northwest-1"
ENV AWS_REGION="cn-northwest-1"

# 设置 Flask 的 secret key
ENV FLASK_SECRET_KEY="7tdYKrRhOQ9auMsm0V75gynXf9YqiiLcTtvHkjRvgyw="

# 暴露端口
EXPOSE 5000

# 使用 Gunicorn 启动应用，4个工作进程
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
