#!/bin/bash
set -e
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

# ── Install Java for Jenkins Agent ──────────────────────────────────────────
# Required for the Jenkins controller to launch the remoting.jar
apt-get install -y openjdk-17-jre-headless

# ── Prepare Jenkins Directory ───────────────────────────────────────────────
mkdir -p /home/ubuntu/jenkins
chown ubuntu:ubuntu /home/ubuntu/jenkins

# ── Docker (required by Minikube --driver=docker) ────────────────────────────
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

sleep 10

# Note: Ensure the variable name matches your Terraform (e.g., ${github_repo})
git clone https://github.com/${github_repo}.git /opt/app

cd /opt/app/ansible

ansible-playbook -i inventory.ini 01-install-kubectl.yml
ansible-playbook -i inventory.ini 02-install-minikube.yml
ansible-playbook -i inventory.ini 03-deploy-to-kubernetes.yml
ansible-playbook -i inventory.ini 04-create-service.yml
ansible-playbook -i inventory.ini 05-scale-deployment.yml