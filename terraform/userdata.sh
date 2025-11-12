#!/bin/bash
set -xe

# -------------------------------
# 1. System Preparation
# -------------------------------
yum update -y
amazon-linux-extras enable docker
yum install -y docker jq unzip aws-cli

# install docker compose (v2 binary)
DOCKER_COMPOSE_BIN=/usr/local/bin/docker-compose
if [ ! -f "$DOCKER_COMPOSE_BIN" ]; then
  curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_BIN
  chmod +x $DOCKER_COMPOSE_BIN
fi

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
# 3. Create systemd service for the app (unchanged)
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

# login to ECR
ExecStartPre=/bin/bash -c "/usr/bin/aws ecr get-login-password --region ${aws_region} | /usr/bin/docker login --username AWS --password-stdin ${ecr_repo}"
ExecStartPre=-/usr/bin/docker rm -f multi-env-app || true
ExecStartPre=/bin/bash -c 'if ! /usr/bin/docker pull ${ecr_repo}:${image_tag}; then /usr/bin/docker pull ${ecr_repo}:dev; fi'

ExecStart=/bin/bash -c '/usr/bin/docker run --name multi-env-app -p ${app_port}:${app_port} -e APP_VERSION="${workspace}-deployed" -e ENVIRONMENT="${workspace}" ${ecr_repo}:${image_tag}'
ExecStop=/usr/bin/docker stop multi-env-app || true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable multi-env-app
systemctl restart multi-env-app

# -------------------------------
# 4. Write monitoring files into /opt/monitoring and start containers (Prometheus, Grafana, cAdvisor, node-exporter)
# -------------------------------
MON_DIR=${MON_DIR}
/bin/mkdir -p $$MON_DIR
cd $$MON_DIR


# write prometheus.yml
cat <<'PROM' > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'app'
    metrics_path: /metrics
    static_configs:
      - targets: ['localhost:${app_port}']
PROM

# write docker-compose.yml
cat <<'DC' > docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3001:3000"
    restart: unless-stopped
    depends_on:
      - prometheus

  cadvisor:
    image: gcr.io/google-containers/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
DC

# ensure right ownership
chown -R ec2-user:ec2-user ${MON_DIR}

# start monitoring
/usr/local/bin/docker-compose pull || true
/usr/local/bin/docker-compose up -d || true

# confirm containers are running
sleep 6
docker ps --format '{{.Names}}\t{{.Status}}' | tee /var/log/monitoring_containers.log

# small health check
if docker ps --format '{{.Names}}' | /bin/grep -q '^prometheus$'; then
  echo "Prometheus running"
else
  echo "Prometheus not running - check /var/log/monitoring_containers.log" >&2
fi

if docker ps --format '{{.Names}}' | /bin/grep -q '^grafana$'; then
  echo "Grafana running"
fi

if docker ps --format '{{.Names}}' | /bin/grep -q '^cadvisor$'; then
  echo "cAdvisor running"
fi

if docker ps --format '{{.Names}}' | /bin/grep -q '^node-exporter$'; then
  echo "node-exporter running"
fi

# done
