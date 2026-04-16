variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = <<-EOT
    Ubuntu 22.04 LTS AMI ID for your region.
    Find it in EC2 console → Launch Instance → search 'Ubuntu 22.04'.
    Example for us-east-1: ami-0c7217cdde317cfec
  EOT
  type        = string
  default     = "ami-0ec10929233384c7f"
}

variable "key_pair_name" {
  description = "Name of the existing key pair in AWS Academy (usually 'vockey')"
  type        = string
  default     = "vockey"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.large"
}

variable "private_key_path" {
  description = "Path to the private key for SSH access"
  type        = string
  default     = "~/.ssh/labsuser.pem"
}

variable "github_repo" {
  description = "GitHub repo in format username/repo-name"
  type        = string
  default     = "your-username/your-repo"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "GitHub username for Jenkins credential"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for Jenkins credential"
  type        = string
  sensitive   = true
}

variable "dockerhub_username" {
  description = "Docker Hub username for Jenkins credential"
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Docker Hub password/token for Jenkins credential"
  type        = string
  sensitive   = true
}

variable "prod_server_ssh_key" {
  description = "Private SSH key for connecting to the production server (PEM, multiline)"
  type        = string
  sensitive   = true
}