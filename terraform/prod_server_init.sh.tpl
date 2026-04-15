#!/bin/bash
set -e

apt-get update -y
apt-get upgrade -y

# Install Ansible
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

# Install Docker
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

# Clone repo
git clone https://github.com/${github_repo}.git /opt/app
cd /opt/app

# Run Ansible locally
ansible-playbook -i "localhost," -c local 01-install-kubectl.yml
ansible-playbook -i "localhost," -c local 02-install-minikube.yml
ansible-playbook -i "localhost," -c local 03-deploy-to-kubernetes.yml
ansible-playbook -i "localhost," -c local 04-create-service.yml
ansible-playbook -i "localhost," -c local 05-scale-deployment.yml