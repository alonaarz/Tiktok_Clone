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
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# ============================================================
# SSH KEY FOR JENKINS MASTER -> AGENT
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
  enable_dns_hostnames = true
  enable_dns_support   = true

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

# ============================================================
# ROUTE TABLE ASSOCIATION
# ============================================================

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}
# ============================================================
# NETWORK ACL — PUBLIC SUBNET
# ============================================================

resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tiktok-clone-public-nacl"
  }
}

resource "aws_network_acl_rule" "public_ingress" {
  network_acl_id = aws_network_acl.public.id

  rule_number = 100
  egress      = false
  protocol    = "-1"
  rule_action = "allow"
  cidr_block  = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "public_egress" {
  network_acl_id = aws_network_acl.public.id

  rule_number = 100
  egress      = true
  protocol    = "-1"
  rule_action = "allow"
  cidr_block  = "0.0.0.0/0"
}

resource "aws_network_acl_association" "public" {
  subnet_id      = aws_subnet.main.id
  network_acl_id = aws_network_acl.public.id
}
# ============================================================
# SECURITY GROUP — JENKINS MASTER
# ============================================================

resource "aws_security_group" "jenkins_master_sg" {
  name        = "TiktokJenkinsMasterSG"
  description = "Security group for Jenkins Master"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Tiktok-Jenkins-Master-SG"
  }
}

# SSH from administrator
resource "aws_vpc_security_group_ingress_rule" "master_ssh" {
  security_group_id = aws_security_group.jenkins_master_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from administrator"
}

# Jenkins Web UI
resource "aws_vpc_security_group_ingress_rule" "master_jenkins" {
  security_group_id = aws_security_group.jenkins_master_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  description       = "Jenkins Web UI"
}

# Jenkins Agent -> Master
resource "aws_vpc_security_group_ingress_rule" "master_from_agent" {
  security_group_id            = aws_security_group.jenkins_master_sg.id
  referenced_security_group_id = aws_security_group.jenkins_agent_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Jenkins Agent to Master"
}

# Master outbound traffic
resource "aws_vpc_security_group_egress_rule" "master_all" {
  security_group_id = aws_security_group.jenkins_master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

# ============================================================
# SECURITY GROUP — JENKINS AGENT
# ============================================================

resource "aws_security_group" "jenkins_agent_sg" {
  name        = "TiktokJenkinsAgentSG"
  description = "Security group for Jenkins Agent and TikTok Clone"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Tiktok-Jenkins-Agent-SG"
  }
}

# SSH from administrator
resource "aws_vpc_security_group_ingress_rule" "agent_ssh" {
  security_group_id = aws_security_group.jenkins_agent_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from administrator"
}

# TikTok Clone Frontend
resource "aws_vpc_security_group_ingress_rule" "agent_http" {
  security_group_id = aws_security_group.jenkins_agent_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "TikTok Clone Frontend"
}

# TikTok Clone API
resource "aws_vpc_security_group_ingress_rule" "agent_api" {
  security_group_id = aws_security_group.jenkins_agent_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  description       = "TikTok Clone API"
}

# Jenkins Master -> Agent
resource "aws_vpc_security_group_ingress_rule" "agent_from_master" {
  security_group_id            = aws_security_group.jenkins_agent_sg.id
  referenced_security_group_id = aws_security_group.jenkins_master_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Traffic from Jenkins Master"
}

# Agent outbound traffic
resource "aws_vpc_security_group_egress_rule" "agent_all" {
  security_group_id = aws_security_group.jenkins_agent_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

# ============================================================
# JENKINS MASTER EC2
# ============================================================

resource "aws_instance" "jenkins_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  availability_zone      = var.a_zone
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]

  associate_public_ip_address = true

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 15
    volume_type = "gp3"

    tags = {
      Name = "tiktok-jenkins-master-disk"
    }
  }

  user_data = templatefile("files/install_jenkins_master.sh", {
    agent_ip        = aws_instance.jenkins_agent.private_ip
    private_key_pem = tls_private_key.jenkins_agent.private_key_pem
    admin_password  = var.jenkins_admin_password
  })

  tags = {
    Name = "TikTok-Jenkins-Master"
    Role = "jenkins-master"
  }
}

# ============================================================
# JENKINS AGENT EC2
# ============================================================

resource "aws_instance" "jenkins_agent" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  availability_zone      = var.a_zone
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]

  associate_public_ip_address = true

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 15
    volume_type = "gp3"

    tags = {
      Name = "tiktok-jenkins-agent-disk"
    }
  }

  user_data = templatefile("files/install_jenkins_agent.sh", {
    public_key = tls_private_key.jenkins_agent.public_key_openssh
  })

  tags = {
    Name = "TikTok-Jenkins-Agent"
    Role = "jenkins-agent"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "jenkins_master_public_ip" {
  description = "Public IP address of Jenkins Master"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_master_private_ip" {
  description = "Private IP address of Jenkins Master"
  value       = aws_instance.jenkins_master.private_ip
}

output "jenkins_agent_public_ip" {
  description = "Public IP address of Jenkins Agent"
  value       = aws_instance.jenkins_agent.public_ip
}

output "jenkins_agent_private_ip" {
  description = "Private IP address of Jenkins Agent"
  value       = aws_instance.jenkins_agent.private_ip
}
