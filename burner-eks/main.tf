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

resource "aws_vpc" "burner_eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "burner_eks_vpc"
  }
}

resource "aws_subnet" "burner_eks_public_subnet_1" {
  vpc_id                  = aws_vpc.burner_eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "burner_eks_public_subnet_1"
  }
}

resource "aws_subnet" "burner_eks_public_subnet_2" {
  vpc_id                  = aws_vpc.burner_eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "burner_eks_public_subnet_2"
  }
}

resource "aws_internet_gateway" "burner_eks_internet_gateway" {
  vpc_id = aws_vpc.burner_eks_vpc.id

  tags = {
    Name = "burner_eks_internet_gateway"
  }
}

resource "aws_route_table" "burner_eks_public_subnet_route_table" {
  vpc_id = aws_vpc.burner_eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.burner_eks_internet_gateway.id
  }

  tags = {
    Name = "burner_eks_public_subnet_route_table"
  }
}

resource "aws_route_table_association" "burner_eks_public_subnet_and_route_table_1" {
  subnet_id      = aws_subnet.burner_eks_public_subnet_1.id
  route_table_id = aws_route_table.burner_eks_public_subnet_route_table.id
}

resource "aws_route_table_association" "burner_eks_public_subnet_and_route_table_2" {
  subnet_id      = aws_subnet.burner_eks_public_subnet_2.id
  route_table_id = aws_route_table.burner_eks_public_subnet_route_table.id
}

resource "aws_network_acl" "burner_eks_public_subnet_nacl" {
  vpc_id = aws_vpc.burner_eks_vpc.id
  subnet_ids = [
    aws_subnet.burner_eks_public_subnet_1.id,
    aws_subnet.burner_eks_public_subnet_2.id
  ]

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

resource "aws_network_acl_association" "burner_eks_public_subnet_and_nacl_1" {
  network_acl_id = aws_network_acl.burner_eks_public_subnet_nacl.id
  subnet_id      = aws_subnet.burner_eks_public_subnet_1.id
}

resource "aws_network_acl_association" "burner_eks_public_subnet_and_nacl_2" {
  network_acl_id = aws_network_acl.burner_eks_public_subnet_nacl.id
  subnet_id      = aws_subnet.burner_eks_public_subnet_2.id
}

resource "aws_iam_role" "burner_eks_cluster_iam_role" {
  name = "burner_eks_cluster_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "burner_eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.burner_eks_cluster_iam_role.name
}

resource "aws_iam_role" "burner_eks_nodegroup_iam_role" {
  name = "burner_eks_nodegroup_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "burner_eks_nodegroup_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.burner_eks_nodegroup_iam_role.name
}

resource "aws_iam_role_policy_attachment" "burner_eks_nodegroup_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.burner_eks_nodegroup_iam_role.name
}

resource "aws_iam_role_policy_attachment" "burner_eks_nodegroup_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.burner_eks_nodegroup_iam_role.name
}

resource "aws_eks_cluster" "burner_eks_cluster" {
  name = "burner_eks_cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.burner_eks_cluster_iam_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      aws_subnet.burner_eks_public_subnet_1.id,
      aws_subnet.burner_eks_public_subnet_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.burner_eks_cluster_AmazonEKSClusterPolicy,
  ]
}

resource "aws_eks_node_group" "burner_eks_nodegroup" {
  cluster_name    = aws_eks_cluster.burner_eks_cluster.name
  node_group_name = "burner_eks_nodegroup"
  node_role_arn   = aws_iam_role.burner_eks_nodegroup_iam_role.arn
  subnet_ids = [
    aws_subnet.burner_eks_public_subnet_1.id,
    aws_subnet.burner_eks_public_subnet_2.id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.burner_eks_nodegroup_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.burner_eks_nodegroup_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.burner_eks_nodegroup_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_access_entry" "burner_eks_cluster_access" {
  cluster_name  = aws_eks_cluster.burner_eks_cluster.name
  principal_arn = "arn:aws:iam::986080617761:user/terraform"
}

resource "aws_eks_access_policy_association" "burner_eks_cluster_access_terraform_user" {
  cluster_name  = aws_eks_cluster.burner_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = "arn:aws:iam::986080617761:user/terraform"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.burner_eks_cluster_access]
}
