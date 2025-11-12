output "instance_public_ip" {
  value = aws_eip_association.eip_assoc_provided[0].public_ip
}

output "instance_public_dns" {
  value = aws_instance.app_instance.public_dns
}

output "ecr_repo_url" {
  value = data.aws_ecr_repository.app_repo.repository_url
}
