variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ecr_repo_name" {
  type    = string
  default = "multi-env-app"
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair to use for SSH access (leave blank to not set)."
  type        = string
  default     = "multi-dev-new"
}

variable "elastic_ip_allocation_id" {
  type        = string
  description = "If you already allocated an EIP and want to reuse it, pass its allocation id (eipalloc-xxxxx). Leave empty to create a new EIP."
  default     = ""
}
