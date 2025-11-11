output "instance_public_ip" {
  description = "Public IP of the instance (or the EIP allocation ID when created via Terraform)"
  value       = var.elastic_ip_allocation_id != "" ? var.elastic_ip_allocation_id : aws_eip.app_eip[0].public_ip
  # note: if using provided allocation id we return the id you passed; you can call aws ec2 describe-addresses to map
}

output "instance_public_dns" {
  description = "Public DNS of the instance"
  value       = aws_instance.app_instance.public_dns
}

output "ecr_repo_url" {
  value = data.aws_ecr_repository.app_repo.repository_url
}

