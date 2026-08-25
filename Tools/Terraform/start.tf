terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    tls = {
      source = "hashicorp/tls"
    }
  }
}

# ============================================================
# AWS PROVIDER
# ============================================================

provider "aws" {
  region     = "eu-north-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# ============================================================
# SSH KEY
# Jenkins Master -> Jenkins Agent
# ============================================================

resource "tls_private_key" "jenkins_agent" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tiktok-clone-vpc"
  }
}

# ============================================================
# SUBNET
# ============================================================

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.a_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "tiktok-clone-subnet"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tiktok-clone-igw"
  }
}

# ============================================================
# ROUTE TABLE
# ============================================================

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "tiktok-clone-route-table"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# ============================================================
# SECURITY GROUP
# JENKINS MASTER
# ============================================================

resource "aws_security_group" "jenkins_master_sg" {
  name        = "tiktok-clone-jenkins-master-sg"
  description = "Security group for TikTok Clone Jenkins Master"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "TikTokClone-Jenkins-Master-SG"
  }
}

# SSH from user's IP
resource "aws_security_group_rule" "master_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_master_sg.id

  description = "SSH access to Jenkins Master"
}

# Jenkins Web UI
resource "aws_security_group_rule" "master_jenkins_ui" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_master_sg.id

  description = "Jenkins Web UI"
}

# SSH from Jenkins Agent
# Не є обов'язковим для SSH-launcher, але залишаємо
# для можливості адміністрування Master з Agent.
resource "aws_security_group_rule" "master_ssh_from_agent" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_agent_sg.id
  security_group_id        = aws_security_group.jenkins_master_sg.id

  description = "SSH from Jenkins Agent"
}

# Outbound traffic
resource "aws_security_group_rule" "master_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_master_sg.id

  description = "Allow all outbound traffic"
}

# ============================================================
# SECURITY GROUP
# JENKINS AGENT
# ============================================================

resource "aws_security_group" "jenkins_agent_sg" {
  name        = "tiktok-clone-jenkins-agent-sg"
  description = "Security group for TikTok Clone Jenkins Agent"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "TikTokClone-Jenkins-Agent-SG"
  }
}

# SSH from user's IP
resource "aws_security_group_rule" "agent_ssh_from_user" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "SSH access to Jenkins Agent"
}

# SSH from Jenkins Master
# Це головне правило для Jenkins SSH launcher.
resource "aws_security_group_rule" "agent_ssh_from_master" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_master_sg.id
  security_group_id        = aws_security_group.jenkins_agent_sg.id

  description = "Jenkins Master SSH access"
}

# ============================================================
# TIKTOK CLONE FRONTEND
# ============================================================

resource "aws_security_group_rule" "agent_frontend" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "TikTok Clone Frontend"
}

# ============================================================
# TIKTOK CLONE BACKEND
# ============================================================

resource "aws_security_group_rule" "agent_backend" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "TikTok Clone Backend API"
}

# ============================================================
# RABBITMQ MANAGEMENT
# Optional, but useful for debugging
# ============================================================

resource "aws_security_group_rule" "agent_rabbitmq_management" {
  type              = "ingress"
  from_port         = 15672
  to_port           = 15672
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "RabbitMQ Management UI"
}

# ============================================================
# POSTGRESQL
# Optional external access
# ============================================================

resource "aws_security_group_rule" "agent_postgres" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "PostgreSQL access"
}

# ============================================================
# REDIS
# Optional external access
# ============================================================

resource "aws_security_group_rule" "agent_redis" {
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "Redis access"
}

# ============================================================
# ICMP
# Useful for diagnostics
# ============================================================

resource "aws_security_group_rule" "agent_icmp" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "Ping Jenkins Agent"
}

resource "aws_security_group_rule" "master_icmp" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_master_sg.id

  description = "Ping Jenkins Master"
}

# ============================================================
# AGENT OUTBOUND
# ============================================================

resource "aws_security_group_rule" "agent_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_agent_sg.id

  description = "Allow all outbound traffic"
}

# ============================================================
# JENKINS AGENT EC2
# Створюємо першим, тому що Master використовує його private IP
# ============================================================

resource "aws_instance" "jenkins_agent" {
  subnet_id              = aws_subnet.main.id
  availability_zone      = var.a_zone
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 20
    volume_type = "gp3"

    tags = {
      Name = "tiktok-clone-jenkins-agent-disk"
    }
  }

  tags = {
    Name = "TikTok-Clone-Jenkins-Agent"
  }

  # Without this, EC2 never re-runs user_data on an existing instance -
  # fixes to install_jenkins_agent.sh would silently not apply unless the
  # instance is replaced for some other reason.
  user_data_replace_on_change = true

  user_data = templatefile(
    "files/install_jenkins_agent.sh",
    {
      public_key = tls_private_key.jenkins_agent.public_key_openssh
    }
  )
}

# ============================================================
# JENKINS MASTER EC2
# ============================================================

resource "aws_instance" "jenkins_master" {
  subnet_id              = aws_subnet.main.id
  availability_zone      = var.a_zone
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 15
    volume_type = "gp3"

    tags = {
      Name = "tiktok-clone-jenkins-master-disk"
    }
  }

  tags = {
    Name = "TikTok-Clone-Jenkins-Master"
  }

  user_data_replace_on_change = true

  user_data = templatefile(
    "files/install_jenkins_master.sh",
    {
      agent_ip             = aws_instance.jenkins_agent.private_ip
      private_key_pem      = tls_private_key.jenkins_agent.private_key_pem
      admin_password       = var.jenkins_admin_password
      jwt_key              = var.jwt_key
      google_client_id     = var.google_client_id
      google_client_secret = var.google_client_secret
      smtp_password        = var.smtp_password
    }
  )
}

# Stable public IP for the master: without this, every instance
# replacement (e.g. from user_data_replace_on_change) hands out a new
# random public IP and the Jenkins UI URL changes each time.
resource "aws_eip" "jenkins_master" {
  domain   = "vpc"
  instance = aws_instance.jenkins_master.id

  tags = {
    Name = "tiktok-clone-jenkins-master-eip"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "jenkins_master_public_ip" {
  value       = aws_eip.jenkins_master.public_ip
  description = "Public IP address of Jenkins Master (stable Elastic IP)"
}

output "jenkins_master_private_ip" {
  value       = aws_instance.jenkins_master.private_ip
  description = "Private IP address of Jenkins Master"
}

output "jenkins_agent_public_ip" {
  value       = aws_instance.jenkins_agent.public_ip
  description = "Public IP address of Jenkins Agent"
}

output "jenkins_agent_private_ip" {
  value       = aws_instance.jenkins_agent.private_ip
  description = "Private IP address of Jenkins Agent"
}

output "jenkins_url" {
  value       = "http://${aws_eip.jenkins_master.public_ip}:8080"
  description = "Jenkins Web UI"
}


