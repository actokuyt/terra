terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "burner_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "burner_vpc"
  }
}

resource "aws_subnet" "burner_public_subnet" {
  vpc_id     = aws_vpc.burner_vpc.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "burner_public_subnet"
  }
}

resource "aws_internet_gateway" "burner_internet_gateway" {
  vpc_id = aws_vpc.burner_vpc.id

  tags = {
    Name = "burner_internet_gateway"
  }
}

resource "aws_route_table" "burner_public_subnet_route_table" {
  vpc_id = aws_vpc.burner_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.burner_internet_gateway.id
  }

  tags = {
    Name = "burner_public_subnet_route_table"
  }
}

resource "aws_route_table_association" "burner_public_subnet_and_route_table" {
  subnet_id      = aws_subnet.burner_public_subnet.id
  route_table_id = aws_route_table.burner_public_subnet_route_table.id
}

resource "aws_network_acl" "burner_public_subnet_nacl" {
  vpc_id     = aws_vpc.burner_vpc.id
  subnet_ids = [aws_subnet.burner_public_subnet.id]

  ingress {
    from_port  = 0
    to_port    = 0
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  egress {
    from_port  = 0
    to_port    = 0
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "burner_public_subnet_nacl"
  }
}

resource "aws_network_acl_association" "burner_public_subnet_and_nacl" {
  network_acl_id = aws_network_acl.burner_public_subnet_nacl.id
  subnet_id      = aws_subnet.burner_public_subnet.id
}

resource "aws_security_group" "burner_public_instance_sg" {
  vpc_id = aws_vpc.burner_vpc.id

  tags = {
    Name = "burner_public_instance_sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "burner_public_instance_sg_egress" {
  security_group_id = aws_security_group.burner_public_instance_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "burner_public_instance_sg_ssh_ingress" {
  security_group_id = aws_security_group.burner_public_instance_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "burner_public_instance_sg_http_ingress" {
  security_group_id = aws_security_group.burner_public_instance_sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "burner_public_instance_sg_https_ingress" {
  security_group_id = aws_security_group.burner_public_instance_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "burner_public_instance" {
  ami                         = "ami-0d64bb532e0502c46"
  associate_public_ip_address = true
  instance_type               = "t2.medium"
  key_name                    = "rsa_kodehauz"
  subnet_id                   = aws_subnet.burner_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.burner_public_instance_sg.id]

  tags = {
    Name = "burner_public_instance"
  }
}

output "burner_public_instance_ip" {
  value = aws_instance.burner_public_instance.public_ip
}