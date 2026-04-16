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
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "=== Public IP: $PUBLIC_IP ==="

mkdir -p /opt/jenkins-secrets
cat > /opt/jenkins-secrets/secrets.env << ENV
GITHUB_USERNAME=GITHUB_USERNAME_VAL
GITHUB_TOKEN=GITHUB_TOKEN_VAL
DOCKERHUB_USERNAME=DOCKERHUB_USERNAME_VAL
DOCKERHUB_PASSWORD=DOCKERHUB_PASSWORD_VAL
PROD_SERVER_IP=$PUBLIC_IP
JENKINS_URL=http://$PUBLIC_IP:8080/
ENV
chmod 600 /opt/jenkins-secrets/secrets.env

# ── Write prod server SSH key as a proper file ────────────────────────────────
mkdir -p /opt/jenkins-secrets

# Write key directly - Terraform injects it, printf preserves newlines
printf '%s' '${prod_server_ssh_key}' > /opt/jenkins-secrets/prod_server_ssh_key

# Verify it looks correct (should show -----BEGIN ... -----)
head -1 /opt/jenkins-secrets/prod_server_ssh_key
chmod 600 /opt/jenkins-secrets/prod_server_ssh_key

# For JCasC: encode as base64 single line - JCasC will decode it
B64_KEY=$$(base64 -w 0 /opt/jenkins-secrets/prod_server_ssh_key)
printf 'PROD_SERVER_SSH_KEY_B64=%s\n' "$$B64_KEY" >> /opt/jenkins-secrets/secrets.env

echo "=== Secrets written ==="

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
  -e JENKINS_ADMIN_PASSWORD=JENKINS_ADMIN_PASSWORD_VAL \
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
sed -i "s|GITHUB_REPO|${github_repo}|g"                       /tmp/init.sh
sed -i "s|GITHUB_USERNAME_VAL|${github_username}|g"           /tmp/init.sh
sed -i "s|GITHUB_TOKEN_VAL|${github_token}|g"                 /tmp/init.sh
sed -i "s|DOCKERHUB_USERNAME_VAL|${dockerhub_username}|g"     /tmp/init.sh
sed -i "s|DOCKERHUB_PASSWORD_VAL|${dockerhub_password}|g"     /tmp/init.sh
sed -i "s|JENKINS_ADMIN_PASSWORD_VAL|${jenkins_admin_password}|g" /tmp/init.sh

# SSH key is multiline — use python to safely inject it
python3 - << PYEOF
import base64

raw = "${prod_server_ssh_key}"

print("Encoded length:", len(raw))

try:
    decoded = base64.b64decode(raw)
    print("Decoded bytes:", len(decoded))
except Exception as e:
    print("BASE64 DECODE FAILED:", e)
    raise

ssh_key = decoded.decode('utf-8')

print("Decoded first 30 chars:", ssh_key[:30])
print("Decoded last 30 chars:", ssh_key[-30:])
PYEOF

chmod +x /tmp/init.sh
bash /tmp/init.sh