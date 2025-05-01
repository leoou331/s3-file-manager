# S3 文件管理系统

一个基于 Flask 的 web 应用，用于安全地管理、查看、上传和下载存储在 AWS S3 存储桶中的文件，与 AWS 服务深度集成，适用于 Kubernetes 部署环境。

> ⚠️ **重要提示**：使用前请确保替换所有配置文件中的占位符为实际值。

## 功能特点

- **安全认证**：使用 AWS Secrets Manager 管理用户凭证
- **文件管理**：浏览、预览、下载 S3 存储桶中的文件
- **批量下载**：支持多个文件打包成 ZIP 下载
- **上传功能**：支持将文件上传到指定目录
- **图片预览**：支持常见图片格式的在线预览
- **响应式设计**：基于 Bootstrap 5 的现代化界面
- **分页显示**：大量文件智能分页展示

## 系统架构

- **前端**：Bootstrap 5 + JavaScript
- **后端**：Flask (Python)
- **存储**：Amazon S3
- **认证**：AWS Secrets Manager
- **部署**：Docker + Kubernetes (EKS)

## 部署前提

- AWS 账户与相应权限
- 已配置的 AWS CLI 凭证
- 已安装 Docker 和 kubectl
- 已配置的 EKS 集群

## 快速开始

### 1. 克隆项目

```bash
git clone [项目URL]
cd s3-file-manager
```

### 2. 配置环境变量

```bash
# 复制环境变量示例文件
cp .env.sample .env

# 编辑 .env 文件，填入实际值
vi .env
```

### 3. 应用环境变量到配置文件

```bash
# 使脚本可执行
chmod +x apply_env.sh

# 运行脚本应用环境变量
./apply_env.sh
```

这个脚本会自动执行以下操作：
- 从 .env 文件读取环境变量
- 获取当前的 AWS 账户 ID
- 更新 Dockerfile 中的环境变量设置
- 更新 build_and_push.sh 脚本中的区域和仓库名称
- 更新 eks-app-permissions.json 中的资源 ARN
- 更新 s3-manager-deployment.yaml 中的配置和镜像地址
- 更新 deploy_service.sh 中的集群和区域设置

### 4. 配置 AWS 资源

创建所需的 AWS 资源：

```bash
# 创建 S3 存储桶
aws s3 mb s3://$S3_BUCKET_NAME --region $AWS_REGION

# 创建 Secrets Manager 密钥
aws secretsmanager create-secret --name $SECRET_NAME \
    --secret-string '{"admin":"admin123", "user1":"user123"}' \
    --region $AWS_REGION
```

### 5. 配置 IAM 权限

将 IAM 策略附加到 EKS 节点角色上：

```bash
# 创建 IAM 策略
aws iam create-policy \
    --policy-name s3-file-manager-policy \
    --policy-document file://eks-app-permissions.json \
    --region $AWS_REGION

# 获取节点角色 ARN
NODE_ROLE_ARN=$(aws eks describe-nodegroup \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name YourNodeGroupName \
    --query "nodegroup.nodeRole" \
    --output text \
    --region $AWS_REGION)

# 附加策略到节点角色
aws iam attach-role-policy \
    --role-name $(echo $NODE_ROLE_ARN | cut -d'/' -f2) \
    --policy-arn $(aws iam list-policies \
    --query "Policies[?PolicyName=='s3-file-manager-policy'].Arn" \
    --output text \
    --region $AWS_REGION)
```

### 6. 构建并推送 Docker 镜像

```bash
# 使用脚本构建并推送到 ECR
./build_and_push.sh
```

### 7. 部署到 Kubernetes

```bash
# 使用脚本部署到 EKS
./deploy_service.sh
```

## 环境变量配置

应用程序通过以下环境变量进行配置（.env 文件）：

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `AWS_REGION` | AWS 区域 | `your-region` |
| `AWS_DEFAULT_REGION` | AWS 默认区域 | 同 `AWS_REGION` |
| `S3_BUCKET_NAME` | S3 存储桶名称 | `your-bucket-name` |
| `SECRET_NAME` | Secrets Manager 密钥名 | `your-secret-name` |
| `FLASK_SECRET_KEY` | Flask 会话密钥 | `generate-a-secure-random-key` |
| `ECR_REPOSITORY_NAME` | ECR 仓库名 | `s3-file-manager` |
| `CLUSTER_NAME` | EKS 集群名称 | `your-eks-cluster` |

## 用户管理

用户凭证存储在 AWS Secrets Manager 中，格式为 JSON：

```json
{
  "username1": "password1",
  "username2": "password2"
}
```

可使用以下命令添加或更新用户：

```bash
# 更新用户凭证
SECRET_NAME=$SECRET_NAME ./create_user.sh
```

## 文件说明

- `app.py` - Flask 应用程序主文件
- `requirements.txt` - Python 依赖项
- `Dockerfile` - 容器构建配置
- `build_and_push.sh` - 构建并推送 Docker 镜像到 ECR
- `deploy_service.sh` - 部署应用到 EKS
- `create_user.sh` - 创建/更新用户凭证
- `eks-app-permissions.json` - 应用所需的 IAM 权限
- `s3-manager-deployment.yaml` - Kubernetes 部署配置
- `.env.sample` - 环境变量示例文件
- `apply_env.sh` - 环境变量应用脚本

### 模板文件

- `templates/base.html` - 基础模板
- `templates/login.html` - 登录页
- `templates/files.html` - 文件列表页
- `templates/preview.html` - 图片预览页
- `templates/error.html` - 错误页

## 项目开发

### 依赖安装

```bash
pip install -r requirements.txt
```

### 本地运行

```bash
# 导入环境变量
source .env

# 启动应用
python app.py
```

### Docker 本地构建

```bash
# 导入环境变量
source .env

# 构建并运行容器
docker build -t s3-file-manager:latest .
docker run -p 5000:5000 \
  -e S3_BUCKET_NAME=$S3_BUCKET_NAME \
  -e SECRET_NAME=$SECRET_NAME \
  -e AWS_REGION=$AWS_REGION \
  -e FLASK_SECRET_KEY=$FLASK_SECRET_KEY \
  s3-file-manager:latest
```

## 故障排除

### 常见问题

1. **访问被拒绝错误**
   - 检查 EKS 节点 IAM 角色是否有正确的 S3 和 Secrets Manager 权限

2. **无法显示文件列表**
   - 检查 S3 存储桶是否存在并且有内容
   - 检查 S3 权限是否正确

3. **无法登录**
   - 检查 Secrets Manager 密钥是否存在
   - 验证用户凭证是否正确

### 查看日志

```bash
# 查看应用日志
kubectl logs -l app=s3-file-manager
```

## 安全注意事项

- 生产环境中应使用强密码并定期轮换
- 考虑在 S3 存储桶上启用加密
- 在生产环境中，确保 `FLASK_SECRET_KEY` 是唯一且强壮的密钥

## 许可证

[MIT](LICENSE)

## 联系方式

项目维护者: Leo Ou

---

*本项目基于 MIT 许可证发布*

