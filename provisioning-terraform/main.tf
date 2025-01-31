terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}

provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
}

locals {
  cluster_name = "eks-cluster-cis"
}

# Fetch AWS account details
data "aws_caller_identity" "current" {}

# Define VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k8s-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet("10.0.4.0/22", 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                         = "k8s-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet("10.0.1.0/22", 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                         = "k8s-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "k8s-igw"
  }
}

# Route Table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "k8s-public-rt"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public_rt_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "k8s-nat-gateway"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "k8s-private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = 3
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = local.cluster_name
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  version  = "1.25"

  vpc_config {
    subnet_ids         = aws_subnet.private_subnet[*].id
  }

  tags = {
    Name = local.cluster_name
  }
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${local.cluster_name}-node-group"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  subnet_ids = aws_subnet.private_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  ami_type        = "AL2_x86_64"
  instance_types  = ["t3.medium"]

  tags = {
    Name = "${local.cluster_name}-node-group"
  }
}

# AWS Availability Zones for dynamic subnet placement
data "aws_availability_zones" "available" {}
