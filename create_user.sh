#!/bin/bash

# ------------------------------------------------------------
# 重要: 使用此脚本前，请进行以下操作:
# 1. 设置 SECRET_NAME 环境变量为您的 AWS Secrets Manager 密钥名称
# 2. 替换下面的默认密码为强密码
# ------------------------------------------------------------

# SECRET_NAME="your-secret-name"  # 取消注释并替换为您的密钥名称

# 检查是否设置了 SECRET_NAME
if [ -z "$SECRET_NAME" ]; then
  echo "错误: 未设置 SECRET_NAME 环境变量"
  echo "使用方法: SECRET_NAME=your-secret-name ./create_user.sh"
  exit 1
fi

# 更新密钥
# 注意: 替换以下密码为安全的强密码
aws secretsmanager update-secret --secret-id $SECRET_NAME --secret-string '{"admin":"change-this-password", "user1":"change-this-password"}'

echo "用户凭证已更新。请确保您已记住所设置的密码。" 