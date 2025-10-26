#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Set environment variables for app
export RDS_HOST="${rds_endpoint}"
export RDS_USER="${rds_user}"
export RDS_PASSWORD="${rds_password}"
export RDS_DB="${rds_db}"

# Pull and run Docker container (assuming you've pushed to ECR or Docker Hub)
# For this example, we'll build locally
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Create app files
cat > app.py <<'EOF'
from flask import Flask, jsonify
import os
import pymysql

app = Flask(__name__)

RDS_HOST = os.environ.get('RDS_HOST', 'localhost')
RDS_USER = os.environ.get('RDS_USER', 'admin')
RDS_PASSWORD = os.environ.get('RDS_PASSWORD', 'password')
RDS_DB = os.environ.get('RDS_DB', 'appdb')

@app.route('/')
def home():
    return jsonify({
        "message": "Welcome to 3-Tier HA Architecture",
        "status": "healthy"
    })

@app.route('/health')
def health():
    return jsonify({"status": "ok"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

cat > Dockerfile <<'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY app.py .
RUN pip install flask pymysql
EXPOSE 80
CMD ["python", "app.py"]
EOF

# Build and run container
docker build -t flask-app .
docker run -d -p 80:80 \
  -e RDS_HOST="${rds_endpoint}" \
  -e RDS_USER="${rds_user}" \
  -e RDS_PASSWORD="${rds_password}" \
  -e RDS_DB="${rds_db}" \
  --name flask-app \
  flask-app
