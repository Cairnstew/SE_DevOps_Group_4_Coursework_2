terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# ── NOTE FOR AWS ACADEMY USERS ──────────────────────────────────────────────
# The voclabs role cannot call DescribeImages or manage key pairs.
# Set var.ami_id to the Ubuntu 22.04 AMI shown in your region's EC2 console.
# The key pair is pre-created by AWS Academy — set var.key_pair_name to match
# (it is usually "vockey").

# ── Security Group: Build Server ────────────────────────────────────────────
resource "aws_security_group" "build_server_sg" {
  name        = "build-server-sg"
  description = "Build Server - SSH + Jenkins"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "build-server-sg"
  }
}

# ── Security Group: Production Server ───────────────────────────────────────
resource "aws_security_group" "prod_server_sg" {
  name        = "prod-server-sg"
  description = "Production Server - SSH + NodePort range"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range
  ingress {
    description = "Kubernetes NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-server-sg"
  }
}

# ── EC2: Build Server ────────────────────────────────────────────────────────
resource "aws_instance" "build_server" {
  ami                    = var.ami_id
  instance_type          = "t2.large"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.build_server_sg.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  # Install Docker and Jenkins on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y

    # ── Git (needed before clone) ────────────────────────────────────────────
    apt-get install -y git

    # ── Docker ──────────────────────────────────────────────────────────────
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Allow ubuntu user to run Docker without sudo
    usermod -aG docker ubuntu

    # ── Jenkins (via custom Docker image) ───────────────────────────────────
    sleep 10

    git clone https://github.com/${var.github_repo}.git /opt/app

    docker volume create jenkins_home

    docker build -t jenkins-custom /opt/app/jenkins/

    PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

    docker run -d \
      --name jenkins \
      --restart unless-stopped \
      -p 8080:8080 \
      -p 50000:50000 \
      -v jenkins_home:/var/jenkins_home \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -e JENKINS_ADMIN_PASSWORD=${var.jenkins_admin_password} \
      -e JENKINS_URL=$$PUBLIC_IP \
      jenkins-custom

    # Give Jenkins Docker CLI access
    sleep 10
    docker exec -u root jenkins apt-get update -y
    docker exec -u root jenkins apt-get install -y docker.io
  EOF

  tags = {
    Name = "Build Server"
  }
}

# ── Generate SSH config ──────────────────────────────────────────────────────
resource "local_file" "ssh_config" {
  filename        = "${path.module}/.ssh-config"
  file_permission = "0600"
  content         = <<-EOT
    Host build-server
        HostName ${aws_instance.build_server.public_ip}
        User ubuntu
        IdentityFile ${var.private_key_path}
        StrictHostKeyChecking no

    Host prod-server
        HostName ${aws_instance.prod_server.public_ip}
        User ubuntu
        IdentityFile ${var.private_key_path}
        StrictHostKeyChecking no
  EOT
}

resource "aws_instance" "prod_server" {
  ami                    = var.ami_id
  instance_type          = "t2.large"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.prod_server_sg.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  # Install Ansible and Docker (needed by Minikube) on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible

    # Docker (required by Minikube --driver=docker)
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "Production Server"
  }
}
