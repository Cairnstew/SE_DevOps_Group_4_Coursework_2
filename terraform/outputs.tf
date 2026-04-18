output "build_server_public_ip" {
  description = "Public IP of the Build Server (SSH + Jenkins)"
  value       = aws_eip.build_server_eip.public_ip
}

output "build_server_jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_eip.build_server_eip.public_ip}:8080"
}

output "prod_server_public_ip" {
  description = "Public IP of the Production Server"
  value       = aws_instance.prod_server.public_ip
}

output "ssh_build_server" {
  description = "SSH command for Build Server"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_eip.build_server_eip.public_ip}"
}

output "ssh_prod_server" {
  description = "SSH command for Production Server"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.prod_server.public_ip}"
}

output "prod_server_internal_dns" {
  value = aws_route53_record.prod_internal.fqdn
}