# Data sources
data "aws_ecr_repository" "app_repo" {
  name = var.ecr_repo_name
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Add a suffix to SG names to avoid duplicate name conflicts across runs/workspaces
resource "random_id" "sg_suffix" {
  byte_length = 2
}

resource "aws_security_group" "app_sg" {
  name_prefix = "multi-env-app-sg-${terraform.workspace}-"
  description = "Allow HTTP & SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana (we map to host 3001)
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # cAdvisor
  ingress {
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
    Name        = "multi-env-app-sg-${terraform.workspace}"
    Environment = terraform.workspace
  }

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role & Profile for EC2 to pull from ECR
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2-ecr-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_attach" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-${terraform.workspace}"
  role = aws_iam_role.ec2_ecr_role.name
}

# EC2 Instance
resource "aws_instance" "app_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  # only set key_name if user provided one (empty string means none)
  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = templatefile("${path.module}/userdata.sh", {
    ecr_repo   = data.aws_ecr_repository.app_repo.repository_url
    app_port   = tostring(var.app_port)
    workspace  = terraform.workspace
    aws_region = var.aws_region
    image_tag  = terraform.workspace
    MON_DIR    = "/opt/monitoring"
  })

  tags = {
    Name = "multi-env-app-${terraform.workspace}"
    Env  = terraform.workspace
  }

  # Wait until instance is reachable before attempting EIP association
  provisioner "local-exec" {
    command = "echo instance ${self.id} created"
    when    = create
  }
}

# EIP handling: either associate an existing allocation_id, or create one.
resource "aws_eip" "app_eip" {
  count = var.elastic_ip_allocation_id == "" ? 1 : 0

  instance = aws_instance.app_instance.id

  tags = {
    Name        = "multi-env-app-eip-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_eip_association" "eip_assoc_new" {
  count = var.elastic_ip_allocation_id == "" ? 1 : 0
  instance_id   = aws_instance.app_instance.id
  allocation_id = aws_eip.app_eip[0].allocation_id
}

# If user provided an allocation id, create an association with that allocation
resource "aws_eip_association" "eip_assoc_provided" {
  count = var.elastic_ip_allocation_id != "" ? 1 : 0
  instance_id   = aws_instance.app_instance.id
  allocation_id = var.elastic_ip_allocation_id
}

