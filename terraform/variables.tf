variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1" # AWS Academy defaults to us-east-1
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
  description = "EC2 instance type. Spec requires t2.large. Use t2.micro only for testing (Minikube will likely crash)."
  type        = string
  default     = "t2.large"
}

variable "private_key_path" {
  description = "Path to the private key for SSH access"
  type        = string
  default     = "~/.ssh/labsuser.pem"
}
