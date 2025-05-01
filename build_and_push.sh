#!/bin/bash
set -e

# ------------------------------------------------------------
# 重要: 使用此脚本前，请替换以下变量为您的实际值
# ------------------------------------------------------------

# 配置变量
AWS_REGION="your-region"  # 替换为您的 AWS 区域，例如 cn-northwest-1
ECR_REPOSITORY_NAME="s3-file-manager"  # ECR 存储库名称
IMAGE_TAG="latest"      # 镜像标签

# 显示脚本开始信息
echo "=== 开始构建和推送 S3 文件管理系统 Docker 镜像 ==="
echo "AWS 区域: $AWS_REGION"
echo "ECR 存储库: $ECR_REPOSITORY_NAME"
echo "镜像标签: $IMAGE_TAG"

# 检查 AWS CLI 是否已安装
if ! command -v aws &> /dev/null; then
    echo "错误: 未找到 AWS CLI。请先安装 AWS CLI。"
    exit 1
fi

# 检查 Docker 是否已安装并运行
if ! command -v docker &> /dev/null; then
    echo "错误: 未找到 Docker。请先安装 Docker。"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "错误: Docker 未运行。请启动 Docker 服务。"
    exit 1
fi

# 登录到 AWS ECR
echo -e "\n=== 登录到 AWS ECR ==="
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com.cn"

# 创建 ECR 存储库（如果不存在）
if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION &> /dev/null; then
    echo -e "\n=== 创建 ECR 存储库: $ECR_REPOSITORY_NAME ==="
    aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION
fi

# 获取 ECR 存储库 URI
ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION --query "repositories[0].repositoryUri" --output text)
echo -e "\n=== ECR 存储库 URI: $ECR_REPOSITORY_URI ==="

# 构建 Docker 镜像
echo -e "\n=== 构建 Docker 镜像 ==="
docker build -t $ECR_REPOSITORY_NAME:$IMAGE_TAG .

# 标记 Docker 镜像
echo -e "\n=== 标记 Docker 镜像 ==="
docker tag $ECR_REPOSITORY_NAME:$IMAGE_TAG $ECR_REPOSITORY_URI:$IMAGE_TAG

# 推送 Docker 镜像到 ECR
echo -e "\n=== 推送 Docker 镜像到 ECR ==="
docker push $ECR_REPOSITORY_URI:$IMAGE_TAG

echo -e "\n=== 完成！==="
echo "Docker 镜像已构建并推送到: $ECR_REPOSITORY_URI:$IMAGE_TAG"
echo "您可以使用以下命令从 ECR 拉取该镜像:"
echo "docker pull $ECR_REPOSITORY_URI:$IMAGE_TAG"
