#!/bin/bash
set -xe

# -------------------------------
# 1. System Preparation
# -------------------------------
yum update -y
amazon-linux-extras enable docker
yum install -y docker jq unzip aws-cli

systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user || true

# Wait for docker
sleep 10
for i in {1..6}; do
  if docker info >/dev/null 2>&1; then
    break
  else
    sleep 5
  fi
done

# -------------------------------
# 2. Environment Variables (rendered by templatefile)
# -------------------------------
aws_region="${aws_region}"
ecr_repo="${ecr_repo}"
workspace="${workspace}"
app_port="${app_port}"
image_tag="${image_tag}"

# -------------------------------
# 3. Create systemd service for persistence
# -------------------------------
cat <<'EOF' > /etc/systemd/system/multi-env-app.service
[Unit]
Description=Multi-Environment Docker App
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
StandardOutput=append:/var/log/multi-env-app.log
StandardError=append:/var/log/multi-env-app.log

# login to ECR (use bash -c so the pipe works)
ExecStartPre=/bin/bash -c "/usr/bin/aws ecr get-login-password --region ${aws_region} | /usr/bin/docker login --username AWS --password-stdin ${ecr_repo}"
ExecStartPre=-/usr/bin/docker rm -f multi-env-app || true
# pull preferring workspace tag, fallback to dev
ExecStartPre=/bin/bash -c 'if ! /usr/bin/docker pull ${ecr_repo}:${image_tag}; then /usr/bin/docker pull ${ecr_repo}:dev; fi'

ExecStart=/bin/bash -c '/usr/bin/docker run --name multi-env-app -p ${app_port}:${app_port} -e APP_VERSION="${workspace}-deployed" -e ENVIRONMENT="${workspace}" ${ecr_repo}:${image_tag}'
ExecStop=/usr/bin/docker stop multi-env-app || true

[Install]
WantedBy=multi-user.target
EOF

# reload and enable service
systemctl daemon-reload
systemctl enable multi-env-app
systemctl restart multi-env-app

# small wait and health check
sleep 8
if /usr/bin/docker ps --format '{{.Names}}' | /bin/grep -q '^multi-env-app$'; then
  echo "Container started successfully for workspace ${workspace}" | tee -a /var/log/multi-env-app.log
else
  echo "Container failed to start. See docker logs or /var/log/multi-env-app.log" | tee -a /var/log/multi-env-app.log
  /usr/bin/docker logs multi-env-app || true
fi