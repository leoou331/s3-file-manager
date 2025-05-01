#!/bin/bash
set -e

# ------------------------------------------------------------
# 重要: 使用此脚本前，请替换以下变量为您的实际值
# ------------------------------------------------------------

CLUSTER_NAME="your-cluster-name"    # 替换为您的 EKS 集群名称
REGION="your-region"                # 替换为您的 AWS 区域，例如 cn-northwest-1
ECR_REPO_NAME="s3-file-manager"     # ECR 存储库名称，如有不同请修改

echo "=== 准备部署 S3 文件管理应用到 EKS ==="

# 获取 ECR 存储库 URI
ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${REGION} --query "repositories[0].repositoryUri" --output text)

# 如果没有找到 ECR 仓库，显示错误
if [ -z "$ECR_REPOSITORY_URI" ]; then
    echo "错误: 无法找到 ECR 仓库 '${ECR_REPO_NAME}'。请先创建仓库并推送镜像。"
    exit 1
fi

echo "使用镜像: ${ECR_REPOSITORY_URI}:latest"

# 创建 Kubernetes 配置文件
cat <<EOF > s3-manager-deployment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: s3-manager-config
data:
  # 请替换以下值为您的实际配置
  S3_BUCKET_NAME: "your-bucket-name"  # 替换为实际的 S3 桶名
  SECRET_NAME: "your-secret-name"     # 替换为实际的 Secret Manager 密钥名
  AWS_REGION: "${REGION}"             # 使用脚本变量中的区域
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-file-manager
spec:
  replicas: 2
  selector:
    matchLabels:
      app: s3-file-manager
  template:
    metadata:
      labels:
        app: s3-file-manager
    spec:
      containers:
      - name: s3-file-manager
        image: ${ECR_REPOSITORY_URI}:latest
        ports:
        - containerPort: 5000
        envFrom:
        - configMapRef:
            name: s3-manager-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: s3-file-manager-service
spec:
  selector:
    app: s3-file-manager
  ports:
  - port: 80
    targetPort: 5000
  type: LoadBalancer
EOF

echo "已创建 Kubernetes 部署配置文件: s3-manager-deployment.yaml"
echo "请确认配置文件内容，特别是 S3 桶和 Secret Manager 的配置"
echo "准备部署应用"

# 应用 Kubernetes 配置
kubectl apply -f s3-manager-deployment.yaml

echo "等待部署完成..."
kubectl rollout status deployment/s3-file-manager

# 获取服务地址
echo "获取服务访问地址..."
kubectl get service s3-file-manager-service

echo -e "\n=== 部署完成 ==="
echo "您可以使用上面显示的 EXTERNAL-IP 地址访问应用"
echo "注意: LoadBalancer 可能需要几分钟才能分配外部 IP 地址"