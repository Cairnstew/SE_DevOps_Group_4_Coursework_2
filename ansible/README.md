# Ansible Playbooks — Production Server Setup

Run these playbooks in order on the production server.

## Prerequisites
- Ansible installed
- Docker installed and ubuntu user in docker group

## Usage

```bash
# Run all playbooks in order
ansible-playbook -i inventory.ini 01-install-kubectl.yml
ansible-playbook -i inventory.ini 02-install-minikube.yml
ansible-playbook -i inventory.ini 03-deploy-to-kubernetes.yml
ansible-playbook -i inventory.ini 04-create-service.yml
ansible-playbook -i inventory.ini 05-scale-deployment.yml
```

## Before running 03-deploy-to-kubernetes.yml
Update the `dockerhub_username` variable with your DockerHub username.

## Playbook summary

| File | Task | Marks |
|---|---|---|
| 01-install-kubectl.yml | Install kubectl | 2a (4 marks) |
| 02-install-minikube.yml | Install and start Minikube | 2b (2 marks) |
| 03-deploy-to-kubernetes.yml | Deploy image from DockerHub | 2c (2 marks) |
| 04-create-service.yml | Create NodePort service | 2d (2 marks) |
| 05-scale-deployment.yml | Scale to 3 replicas + rolling update config | 2e (2 marks) |
