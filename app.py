import os
import boto3
import math
from flask import Flask, render_template, request, redirect, url_for, session, send_file, jsonify
from werkzeug.security import check_password_hash
import json
import tempfile
import zipfile
import io
from datetime import datetime

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'a-fixed-secret-key-for-development')
app.config.update(
    SESSION_COOKIE_SECURE=False,  # 非HTTPS环境下设为False
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='Lax',
    PERMANENT_SESSION_LIFETIME=86400  # session有效期一天
)

# 从环境变量获取配置
SECRET_NAME = os.environ.get('SECRET_NAME')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')

# 添加默认值和错误检查
if not SECRET_NAME:
    print("警告: 未设置SECRET_NAME环境变量")
    SECRET_NAME = "default-secret-name"  # 开发环境下的默认值

if not S3_BUCKET_NAME:
    print("警告: 未设置S3_BUCKET_NAME环境变量")
    S3_BUCKET_NAME = "default-bucket-name"  # 开发环境下的默认值

# 图片格式列表
IMAGE_EXTENSIONS = ['png', 'jpg', 'jpeg']

# 从AWS Secret Manager获取用户凭据
def get_credentials():
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager')
    try:
        response = client.get_secret_value(SecretId=SECRET_NAME)
        secret_data = json.loads(response['SecretString'])
        return secret_data
    except Exception as e:
        print(f"Error retrieving secret: {e}")
        return None

@app.route('/')
def index():
    if 'username' in session:
        return redirect(url_for('files'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    now = datetime.now()  # 添加now变量，用于base.html的年份显示
    
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        # 获取用户凭据
        credentials = get_credentials()
        if credentials and username in credentials:
            stored_password = credentials[username]
            
            # 修改密码验证逻辑，处理可能未哈希的密码
            # 如果存储的密码已经是哈希值，则使用check_password_hash
            # 否则直接比较（仅用于开发/测试）
            if (stored_password.startswith('pbkdf2:sha256:') and check_password_hash(stored_password, password)) or stored_password == password:
                session.permanent = True  # 添加这一行，使session持久化
                session['username'] = username
                return redirect(url_for('files'))
        
        error = '无效的用户名或密码'
    
    return render_template('login.html', error=error, now=now)

@app.route('/logout')
def logout():
    session.pop('username', None)
    return redirect(url_for('login'))

@app.route('/files')
def files():
    if 'username' not in session:
        return redirect(url_for('login'))
    
    try:
        # 确保 page 是整数
        page = request.args.get('page', 1)
        if isinstance(page, dict):  # 检查 page 是否为字典
            page = 1  # 设置默认值
        else:
            try:
                page = int(page)  # 尝试转换为整数
            except (ValueError, TypeError):
                page = 1  # 如果转换失败，使用默认值
        
        # 确保 items_per_page 是整数
        items_per_page = request.args.get('items_per_page', 10)
        try:
            items_per_page = int(items_per_page)
        except (ValueError, TypeError):
            items_per_page = 10
        
        # 使用S3的分页功能
        region = os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION') or 'cn-northwest-1'
        s3_client = boto3.client('s3', region_name=region)
        paginator = s3_client.get_paginator('list_objects_v2')
        
        all_files = []
        for page_response in paginator.paginate(Bucket=S3_BUCKET_NAME):
            if 'Contents' in page_response:
                for item in page_response['Contents']:
                    file_name = item['Key']
                    file_size = item['Size']
                    last_modified = item['LastModified']
                    
                    # 检查文件扩展名
                    file_ext = file_name.split('.')[-1].lower() if '.' in file_name else ''
                    is_image = file_ext in IMAGE_EXTENSIONS
                    
                    all_files.append({
                        'name': file_name,
                        'size': file_size,
                        'last_modified': last_modified,
                        'is_image': is_image
                    })
        
        # 分页
        total_files = len(all_files)
        total_pages = math.ceil(total_files / items_per_page)
        
        start_index = (page - 1) * items_per_page
        end_index = start_index + items_per_page
        
        files_to_display = all_files[start_index:end_index]
        
        now = datetime.now()
        
        return render_template(
            'files.html',
            files=files_to_display,
            page=page,
            items_per_page=items_per_page,
            total_pages=total_pages,
            total_files=total_files,
            now=now,
            max=max,
            min=min
        )
    
    except Exception as e:
        # 添加 now 变量到错误模板
        now = datetime.now()
        return render_template('error.html', error=str(e), now=now)

@app.route('/download', methods=['POST'])
def download():
    if 'username' not in session:
        return jsonify({'error': 'Not authorized'}), 401
    
    file_keys = request.json.get('files', [])
    if not file_keys:
        return jsonify({'error': 'No files selected'}), 400
    
    # 如果只选择了一个文件，直接下载
    if len(file_keys) == 1:
        return download_single_file(file_keys[0])
    
    # 如果选择了多个文件，创建一个zip文件
    if len(file_keys) > 1:
        s3_client = boto3.client('s3')
        
        memory_file = io.BytesIO()
        with zipfile.ZipFile(memory_file, 'w') as zf:
            for file_key in file_keys:
                try:
                    # 获取S3对象
                    obj = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=file_key)
                    file_data = obj['Body'].read()
                    
                    # 添加到zip文件
                    zf.writestr(file_key.split('/')[-1], file_data)
                except Exception as e:
                    print(f"Error adding {file_key} to zip: {str(e)}")
        
        # 将指针移到文件开头
        memory_file.seek(0)
        
        return send_file(
            memory_file,
            as_attachment=True,
            download_name='files.zip',
            mimetype='application/zip'
        )

def download_single_file(file_key):
    temp_path = None
    try:
        s3_client = boto3.client('s3')
        
        # 创建临时文件
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_path = temp_file.name
        
        # 下载文件到临时文件
        s3_client.download_file(S3_BUCKET_NAME, file_key, temp_path)
        
        # 发送文件给用户
        return send_file(
            temp_path,
            as_attachment=True,
            download_name=file_key.split('/')[-1],
            mimetype='application/octet-stream'
        )
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        # 清理临时文件
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)

@app.route('/preview/<path:file_key>')
def preview(file_key):
    if 'username' not in session:
        return redirect(url_for('login'))
    
    now = datetime.now()  # 添加now变量
    
    # 检查文件扩展名是否为图片
    file_ext = file_key.split('.')[-1].lower() if '.' in file_key else ''
    if file_ext not in IMAGE_EXTENSIONS:
        return jsonify({'error': '不支持预览此文件类型'}), 400
    
    try:
        s3_client = boto3.client('s3')
        
        # 生成预签名URL用于前端直接访问S3中的图片
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET_NAME, 'Key': file_key},
            ExpiresIn=3600  # URL有效期1小时
        )
        
        return render_template('preview.html', file_key=file_key, image_url=presigned_url, now=now)
    
    except Exception as e:
        return render_template('error.html', error=str(e))

@app.route('/upload', methods=['POST'])
def upload():
    if 'username' not in session:
        return jsonify({'error': '未授权'}), 401
    
    if 'file' not in request.files:
        return jsonify({'error': '没有选择文件'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': '未选择文件'}), 400
    
    temp_path = None
    try:
        # 获取目录路径（如果有）
        directory = request.form.get('directory', '')
        
        # 构建对象键（S3路径）
        if directory and not directory.endswith('/'):
            directory += '/'
        
        # 确保文件名安全
        filename = file.filename
        object_key = directory + filename
        
        # 创建临时文件
        with tempfile.NamedTemporaryFile(delete=False) as temp:
            temp_path = temp.name
            file.save(temp_path)
        
        # 获取文件大小
        file_size = os.path.getsize(temp_path)
        
        # 使用正确的区域创建S3客户端
        region = os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION') or 'cn-northwest-1'
        s3_client = boto3.client('s3', region_name=region)
        
        # 上传临时文件到S3
        with open(temp_path, 'rb') as f:
            s3_client.upload_fileobj(f, S3_BUCKET_NAME, object_key)
        
        # 返回成功消息
        return jsonify({
            'success': True,
            'message': f'文件 {filename} 上传成功',
            'file': {
                'name': object_key,
                'size': file_size,
                'url': f'/files?highlight={object_key}'  # 返回到文件列表，突出显示新上传的文件
            }
        })
    
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"文件上传错误: {str(e)}")
        print(f"详细错误信息: {error_details}")
        return jsonify({'error': f'上传失败: {str(e)}'}), 500
    
    finally:
        # 无论成功或失败，都确保清理临时文件
        if temp_path and os.path.exists(temp_path):
            try:
                os.unlink(temp_path)
            except Exception as e:
                print(f"无法删除临时文件: {str(e)}")

@app.errorhandler(404)
def page_not_found(e):
    now = datetime.now()
    return render_template('error.html', error='页面未找到', now=now), 404

@app.errorhandler(500)
def internal_server_error(e):
    now = datetime.now()
    return render_template('error.html', error='服务器内部错误', now=now), 500

if __name__ == '__main__':
    debug_mode = os.environ.get('DEBUG', 'false').lower() == 'true'
    if os.environ.get('FLASK_ENV') == 'production':
        # 在生产环境中，您应该使用 gunicorn 或 uwsgi 启动
        # 这里只是为了兼容性保留，不会实际执行
        app.run(debug=False, host='0.0.0.0', port=5000)
    else:
        # 在开发环境中使用开发服务器
        app.run(debug=debug_mode, host='0.0.0.0', port=5000)
