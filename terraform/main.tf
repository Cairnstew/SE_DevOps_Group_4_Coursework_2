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
  user_data = templatefile("${path.module}/build_server_init.sh.tpl", {
    github_repo            = var.github_repo
    jenkins_admin_password = var.jenkins_admin_password
  })

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
  user_data = templatefile("${path.module}/prod_server_init.sh.tpl", {
    github_repo = var.github_repo
  })

  tags = {
    Name = "Production Server"
  }
}
