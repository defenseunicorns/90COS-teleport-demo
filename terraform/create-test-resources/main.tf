# Add provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# Create key-pair for project instances
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "key-${var.project_name}"
  public_key = tls_private_key.key.public_key_openssh

#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "${tls_private_key.key.private_key_pem}" > ${var.project_name}-key.pem
#     EOT
#   }
}

# Create the VPC
resource "aws_vpc" "vpc" {
  cidr_block       = var.main_vpc_cidr # Defining the CIDR block use 10.0.0.0/24 for demo
  instance_tenancy = "default"

  tags = {
    Name = "vpc-${var.project_name}"
  }
}

# Create Internet Gateway and attach it to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Create a Public Subnet
resource "aws_subnet" "public_subnets" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public_subnets
}

# Create a Private Subnet
resource "aws_subnet" "private_subnets" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.private_subnets
}

# Route table for Public Subnets, add Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Create NAT Gateway
resource "aws_eip" "nateIP" {
   vpc   = true
 }

resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.public_subnets.id
 }

# Route table for Private Subnets, add NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATgw.id
  }
}

# Route table Association with Public Subnets
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnets.id
  route_table_id = aws_route_table.public_rt.id
}

# Route table Association with Private Subnets
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnets.id
  route_table_id = aws_route_table.private_rt.id
}

# Create security group for instance, can only access from public subnet
resource "aws_security_group" "security_group" {
  name = "sg-${var.project_name}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.public_subnets}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create instances, configure with tags available for Teleport role usage
resource "aws_instance" "box" {
  for_each = toset(var.private_instances)
  ami                  = "ami-026b57f3c383c2eec"
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.private_subnets.id
  key_name             = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [
    aws_security_group.security_group.id
  ]
  instance_metadata_tags = "enabled"

  user_data = <<EOF
#!/bin/bash
curl https://get.gravitational.com/teleport-v10.3.2-linux-amd64-bin.tar.gz.sha256
curl -O https://get.gravitational.com/teleport-v10.3.2-linux-amd64-bin.tar.gz
sudo yum install perl-Digest-SHA -y
shasum -a 256 teleport-v10.3.2-linux-amd64-bin.tar.gz
tar -xzf teleport-v10.3.2-linux-amd64-bin.tar.gz
cd teleport
sudo ./install
echo -e "teleport:
  join_params:
    token_name: ec2-token
    method: ec2
  auth_servers:
    - https://teleport.meganmind.com:443
ssh_service:
  enabled: yes
auth_service:
  enabled: no
proxy_service:
  enabled: no" > /etc/teleport.yaml
sudo /usr/local/bin/teleport start --roles=node
EOF

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}
