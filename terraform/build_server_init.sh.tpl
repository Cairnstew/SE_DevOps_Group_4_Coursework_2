#!/bin/bash
set -e

# Write the actual init script and run it with bash explicitly
cat > /tmp/init.sh << 'ENDINIT'
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1
echo "=== Starting build server init: $(date) ==="

apt-get update -y

# ── Git ──────────────────────────────────────────────────────────────────────
apt-get install -y git

# ── Docker ───────────────────────────────────────────────────────────────────
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "=== Detected ARCH=$ARCH CODENAME=$CODENAME ==="
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu
echo "=== Docker installed: $(docker --version) ==="

# ── Clone repo ───────────────────────────────────────────────────────────────
sleep 10
git clone https://github.com/GITHUB_REPO.git /opt/app
echo "=== Repo cloned ==="

# ── Write JCasC secrets ───────────────────────────────────────────────────────
BUILD_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "=== Build IP: $BUILD_IP ==="

mkdir -p /opt/jenkins-secrets

cat > /opt/jenkins-secrets/secrets.env << ENV
GITHUB_USERNAME=GITHUB_USERNAME_VAL
GITHUB_TOKEN=GITHUB_TOKEN_VAL
DOCKERHUB_USERNAME=DOCKERHUB_USERNAME_VAL
DOCKERHUB_PASSWORD=DOCKERHUB_PASSWORD_VAL
PROD_SERVER_IP=PROD_SERVER_IP_VAL
JENKINS_ADMIN_PASSWORD=JENKINS_ADMIN_PASSWORD_VAL
JENKINS_URL=http://$BUILD_IP:8080/
ENV
chmod 600 /opt/jenkins-secrets/secrets.env
echo "=== Secrets written ==="
cat /opt/jenkins-secrets/secrets.env

# ── Write prod server SSH key (decode from base64) ────────────────────────────
echo "PROD_SSH_KEY_B64_VAL" | base64 -d > /opt/jenkins-secrets/prod_server_ssh_key
chown 1000:1000 /opt/jenkins-secrets/prod_server_ssh_key
chmod 600 /opt/jenkins-secrets/prod_server_ssh_key
echo "=== SSH key written ($(wc -c < /opt/jenkins-secrets/prod_server_ssh_key) bytes) ==="

# ── Build and run Jenkins ─────────────────────────────────────────────────────
docker volume create jenkins_home
docker build -t jenkins-custom /opt/app/jenkins/
echo "=== Jenkins image built ==="

DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $DOCKER_GID \
  -v /opt/jenkins-secrets/prod_server_ssh_key:/run/secrets/prod_server_ssh_key:ro \
  --env-file /opt/jenkins-secrets/secrets.env \
  jenkins-custom

echo "=== Jenkins container started ==="

sleep 10
docker exec -u root jenkins apt-get update -y
docker exec -u root jenkins apt-get install -y docker.io
docker exec -u root jenkins groupadd -g 999 docker || true
docker exec -u root jenkins usermod -aG docker jenkins

echo "=== Build server init complete: $(date) ==="
ENDINIT

# ── Substitute Terraform variables into the script ────────────────────────────
sed -i "s|GITHUB_REPO|${github_repo}|g"                           /tmp/init.sh
sed -i "s|GITHUB_USERNAME_VAL|${github_username}|g"               /tmp/init.sh
sed -i "s|GITHUB_TOKEN_VAL|${github_token}|g"                     /tmp/init.sh
sed -i "s|DOCKERHUB_USERNAME_VAL|${dockerhub_username}|g"         /tmp/init.sh
sed -i "s|DOCKERHUB_PASSWORD_VAL|${dockerhub_password}|g"         /tmp/init.sh
sed -i "s|PROD_SERVER_IP_VAL|${prod_server_ip}|g"                 /tmp/init.sh
sed -i "s|JENKINS_ADMIN_PASSWORD_VAL|${jenkins_admin_password}|g" /tmp/init.sh

# SSH key: base64 encode it first so it's a single line safe for sed
SSH_KEY_B64=$(printf '%s' '${prod_server_ssh_key}' | base64 -w 0)
sed -i "s|PROD_SSH_KEY_B64_VAL|$SSH_KEY_B64|g"                    /tmp/init.sh

chmod +x /tmp/init.sh
bash /tmp/init.sh