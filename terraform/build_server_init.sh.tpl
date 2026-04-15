#!/bin/bash
set -e
apt-get update -y

# ── Git (needed before clone) ────────────────────────────────────────────────
apt-get install -y git

# ── Docker ───────────────────────────────────────────────────────────────────
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu

# ── Jenkins (via custom Docker image) ────────────────────────────────────────
sleep 10

git clone https://github.com/${github_repo}.git /opt/app

docker volume create jenkins_home
docker build -t jenkins-custom /opt/app/jenkins/

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JENKINS_ADMIN_PASSWORD=${jenkins_admin_password} \
  -e JENKINS_URL=$PUBLIC_IP \
  jenkins-custom

# Give Jenkins Docker CLI access
sleep 10
docker exec -u root jenkins apt-get update -y
docker exec -u root jenkins apt-get install -y docker.io
