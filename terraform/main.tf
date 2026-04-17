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

# Fetch the default VPC for Route 53 association
data "aws_vpc" "default" {
  default = true
}

# ── DNS: Private Hosted Zone ────────────────────────────────────────────────
resource "aws_route53_zone" "internal" {
  name = "corp.internal"

  vpc {
    vpc_id = data.aws_vpc.default.id
  }
}

resource "aws_route53_record" "prod_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "prod.corp.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.prod_server.private_ip]
}

# ── Security Group: Build Server ────────────────────────────────────────────
resource "aws_security_group" "build_server_sg" {
  name        = "build-server-sg"
  description = "Build Server - SSH + Jenkins"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = { Name = "build-server-sg" }
}

# ── Security Group: Production Server ───────────────────────────────────────
resource "aws_security_group" "prod_server_sg" {
  name        = "prod-server-sg"
  description = "Production Server - SSH + NodePort range"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Allow SSH specifically from Build Server"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    # Using the Build SG ID allows communication via Private IP
    security_groups = [aws_security_group.build_server_sg.id]
  }

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

  tags = { Name = "prod-server-sg" }
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

  metadata_options {
    http_tokens   = "optional"
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/build_server_init.sh.tpl", {
    github_repo            = var.github_repo
    jenkins_admin_password = var.jenkins_admin_password
    github_username        = var.github_username
    github_token           = var.github_token
    dockerhub_username     = var.dockerhub_username
    dockerhub_password     = var.dockerhub_password
    prod_server_ssh_key    = var.prod_server_ssh_key
    # Now passing the DNS Name instead of a Public IP
    prod_server_ip         = aws_route53_record.prod_internal.fqdn
  })

  tags = { Name = "Build Server" }
}

# ── EC2: Production Server ───────────────────────────────────────────────────
resource "aws_instance" "prod_server" {
  ami                    = var.ami_id
  instance_type          = "t2.large"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.prod_server_sg.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "optional"
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/prod_server_init.sh.tpl", {
    github_repo = var.github_repo
  })

  tags = { Name = "Production Server" }
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

    Host prod-internal
        HostName ${aws_route53_record.prod_internal.fqdn}
        User ubuntu
        IdentityFile ${var.private_key_path}
        StrictHostKeyChecking no
  EOT
}
