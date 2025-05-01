#!/bin/bash

# -----------------------------------------------------
# S3 文件管理系统 - 环境变量应用脚本
# 用途: 将 .env 文件中的环境变量应用到项目配置文件
# 使用: ./apply_env.sh
# -----------------------------------------------------

set -e

ENV_FILE=".env"
DOCKER_FILE="Dockerfile"
DEPLOY_SCRIPT="deploy_service.sh"
BUILD_SCRIPT="build_and_push.sh" 
APP_PERMISSIONS="eks-app-permissions.json"
K8S_DEPLOYMENT="s3-manager-deployment.yaml"

echo "=== S3 文件管理系统 - 环境变量应用程序 ==="

# 检查 .env 文件是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "错误: .env 文件不存在。请复制 .env.sample 为 .env 并填写实际值。"
    exit 1
fi

echo "正在从 $ENV_FILE 读取环境变量..."

# 读取环境变量
source "$ENV_FILE"

# 验证必要的环境变量
REQUIRED_VARS=("AWS_REGION" "AWS_DEFAULT_REGION" "S3_BUCKET_NAME" "SECRET_NAME" "FLASK_SECRET_KEY" "ECR_REPOSITORY_NAME" "CLUSTER_NAME")
MISSING_VARS=0

for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        echo "错误: 缺少必要的环境变量 $VAR。请在 .env 文件中设置。"
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    exit 1
fi

echo "所有必要的环境变量已设置。"

# 获取当前的 AWS 账户 ID
echo "正在获取 AWS 账户 ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "警告: 无法获取 AWS 账户 ID。请确保您的 AWS CLI 配置正确。"
    echo "您可以手动将 AWS 账户 ID 添加到相关文件中。"
    AWS_ACCOUNT_ID="your-account-id"
fi

echo "AWS 账户 ID: $AWS_ACCOUNT_ID"

# 更新 Dockerfile
echo "正在更新 $DOCKER_FILE..."
sed -i.bak \
    -e "s|ENV SECRET_NAME=\"your-secret-name\"|ENV SECRET_NAME=\"$SECRET_NAME\"|g" \
    -e "s|ENV S3_BUCKET_NAME=\"your-bucket-name\"|ENV S3_BUCKET_NAME=\"$S3_BUCKET_NAME\"|g" \
    -e "s|ENV AWS_DEFAULT_REGION=\"your-region\"|ENV AWS_DEFAULT_REGION=\"$AWS_REGION\"|g" \
    -e "s|ENV AWS_REGION=\"your-region\"|ENV AWS_REGION=\"$AWS_REGION\"|g" \
    -e "s|# ENV FLASK_SECRET_KEY=\"your-secret-key\"|ENV FLASK_SECRET_KEY=\"$FLASK_SECRET_KEY\"|g" \
    "$DOCKER_FILE"

# 更新 build_and_push.sh
echo "正在更新 $BUILD_SCRIPT..."
sed -i.bak \
    -e "s|AWS_REGION=\"your-region\"|AWS_REGION=\"$AWS_REGION\"|g" \
    -e "s|ECR_REPOSITORY_NAME=\"s3-file-manager\"|ECR_REPOSITORY_NAME=\"$ECR_REPOSITORY_NAME\"|g" \
    "$BUILD_SCRIPT"

# 更新 eks-app-permissions.json
echo "正在更新 $APP_PERMISSIONS..."
sed -i.bak \
    -e "s|\"arn:aws-cn:secretsmanager:your-region:your-account-id:secret:your-secret-name\\*\"|\"arn:aws-cn:secretsmanager:$AWS_REGION:$AWS_ACCOUNT_ID:secret:$SECRET_NAME*\"|g" \
    -e "s|\"arn:aws-cn:s3:::your-bucket-name\"|\"arn:aws-cn:s3:::$S3_BUCKET_NAME\"|g" \
    -e "s|\"arn:aws-cn:s3:::your-bucket-name/\\*\"|\"arn:aws-cn:s3:::$S3_BUCKET_NAME/*\"|g" \
    "$APP_PERMISSIONS"

# 更新 s3-manager-deployment.yaml
echo "正在更新 $K8S_DEPLOYMENT..."
sed -i.bak \
    -e "s|AWS_REGION: \"your-region\"|AWS_REGION: \"$AWS_REGION\"|g" \
    -e "s|S3_BUCKET_NAME: \"your-bucket-name\"|S3_BUCKET_NAME: \"$S3_BUCKET_NAME\"|g" \
    -e "s|SECRET_NAME: \"your-secret-name\"|SECRET_NAME: \"$SECRET_NAME\"|g" \
    -e "s|image: your-account-id.dkr.ecr.your-region.amazonaws.com.cn/s3-file-manager:latest|image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com.cn/$ECR_REPOSITORY_NAME:latest|g" \
    "$K8S_DEPLOYMENT"

# 更新 deploy_service.sh
echo "正在更新 $DEPLOY_SCRIPT..."
sed -i.bak \
    -e "s|CLUSTER_NAME=\"your-cluster-name\"|CLUSTER_NAME=\"$CLUSTER_NAME\"|g" \
    -e "s|REGION=\"your-region\"|REGION=\"$AWS_REGION\"|g" \
    -e "s|ECR_REPO_NAME=\"s3-file-manager\"|ECR_REPO_NAME=\"$ECR_REPOSITORY_NAME\"|g" \
    -e "s|S3_BUCKET_NAME: \"your-bucket-name\"|S3_BUCKET_NAME: \"$S3_BUCKET_NAME\"|g" \
    -e "s|SECRET_NAME: \"your-secret-name\"|SECRET_NAME: \"$SECRET_NAME\"|g" \
    "$DEPLOY_SCRIPT"

# 更新 create_user.sh
echo "正在更新 create_user.sh..."
sed -i.bak \
    -e "s|# SECRET_NAME=\"your-secret-name\"|# SECRET_NAME=\"$SECRET_NAME\"|g" \
    "create_user.sh"

# 更新 app.py
echo "正在更新 app.py..."
sed -i.bak \
    -e "s|app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'a-fixed-secret-key-for-development')|app.secret_key = os.environ.get('FLASK_SECRET_KEY', '$FLASK_SECRET_KEY')|g" \
    "app.py"

# 清理备份文件
rm -f "$DOCKER_FILE.bak" "$BUILD_SCRIPT.bak" "$APP_PERMISSIONS.bak" "$K8S_DEPLOYMENT.bak" "$DEPLOY_SCRIPT.bak"

echo "环境变量已成功应用到配置文件中。"
echo ""
echo "下一步操作:"
echo "1. 构建并推送 Docker 镜像: ./build_and_push.sh"
echo "2. 部署应用到 Kubernetes: ./deploy_service.sh"
echo ""
echo "完成！"

LOG_FILE="env_apply.log"
echo "操作开始时间: $(date)" > $LOG_FILE
# 在每个操作后添加日志
echo "更新了 $DOCKER_FILE: $(date)" >> $LOG_FILE
