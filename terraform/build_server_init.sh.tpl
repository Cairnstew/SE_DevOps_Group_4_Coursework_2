#!/bin/bash
set -e
apt-get update -y

# ── Git ──────────────────────────────────────────────────────────────────────
apt-get install -y git

# ── Docker ───────────────────────────────────────────────────────────────────
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$$(dpkg --print-architecture)
CODENAME=$$(. /etc/os-release && echo "$$VERSION_CODENAME")
echo "deb [arch=$$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu

# ── Clone repo ───────────────────────────────────────────────────────────────
sleep 10
git clone https://github.com/${github_repo}.git /opt/app

# ── Write JCasC secrets file ──────────────────────────────────────────────────
PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

mkdir -p /opt/jenkins-secrets
cat > /opt/jenkins-secrets/secrets.env <<ENV
GITHUB_USERNAME=${github_username}
GITHUB_TOKEN=${github_token}
DOCKERHUB_USERNAME=${dockerhub_username}
DOCKERHUB_PASSWORD=${dockerhub_password}
PROD_SERVER_IP=$$PUBLIC_IP
JENKINS_URL=http://$$PUBLIC_IP:8080/
ENV
chmod 600 /opt/jenkins-secrets/secrets.env

# ── Write prod server SSH key ─────────────────────────────────────────────────
cat > /opt/jenkins-secrets/prod_server_ssh_key <<'SSHKEY'
${prod_server_ssh_key}
SSHKEY
chmod 600 /opt/jenkins-secrets/prod_server_ssh_key

ESCAPED_KEY=$$(awk '{printf "%s\\n", $$0}' /opt/jenkins-secrets/prod_server_ssh_key)
echo "PROD_SERVER_SSH_KEY=$$ESCAPED_KEY" >> /opt/jenkins-secrets/secrets.env

# ── Build and run Jenkins ─────────────────────────────────────────────────────
docker volume create jenkins_home
docker build -t jenkins-custom /opt/app/jenkins/

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/jenkins-secrets/prod_server_ssh_key:/run/secrets/prod_server_ssh_key:ro \
  --env-file /opt/jenkins-secrets/secrets.env \
  -e JENKINS_ADMIN_PASSWORD=${jenkins_admin_password} \
  jenkins-custom

# ── Give Jenkins Docker CLI access ───────────────────────────────────────────
sleep 10
docker exec -u root jenkins apt-get update -y
docker exec -u root jenkins apt-get install -y docker.io