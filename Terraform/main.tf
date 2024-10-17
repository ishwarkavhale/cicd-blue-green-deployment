provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "srihari_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "srihari-vpc"
  }
}

resource "aws_subnet" "srihari_subnet" {
  count = 2
  vpc_id                  = aws_vpc.srihari_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.srihari_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "srihari-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "srihari_igw" {
  vpc_id = aws_vpc.srihari_vpc.id

  tags = {
    Name = "srihari-igw"
  }
}

resource "aws_route_table" "srihari_route_table" {
  vpc_id = aws_vpc.srihari_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.srihari_igw.id
  }

  tags = {
    Name = "srihari-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.srihari_subnet[count.index].id
  route_table_id = aws_route_table.srihari_route_table.id
}

resource "aws_security_group" "srihari_cluster_sg" {
  vpc_id = aws_vpc.srihari_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "srihari-cluster-sg"
  }
}

resource "aws_security_group" "srihari_node_sg" {
  vpc_id = aws_vpc.srihari_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "srihari-node-sg"
  }
}

resource "aws_eks_cluster" "srihari" {
  name     = "srihari-cluster"
  role_arn = aws_iam_role.srihari_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.srihari_subnet[*].id
    security_group_ids = [aws_security_group.srihari_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "srihari" {
  cluster_name    = aws_eks_cluster.srihari.name
  node_group_name = "srihari-node-group"
  node_role_arn   = aws_iam_role.srihari_node_group_role.arn
  subnet_ids      = aws_subnet.srihari_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.srihari_node_sg.id]
  }
}

resource "aws_iam_role" "srihari_cluster_role" {
  name = "srihari-cluster-role"

  assume_role_policy = jsonencode({
  Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
})
}

resource "aws_iam_role_policy_attachment" "srihari_cluster_role_policy" { 
  role       = aws_iam_role.srihari_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "srihari_node_group_role" {
  name = "srihari-node-group-role"

assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "srihari_node_group_role_policy" {
  role       = aws_iam_role.srihari_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "srihari_node_group_cni_policy" {
  role       = aws_iam_role.srihari_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "srihari_node_group_registry_policy" {
  role       = aws_iam_role.srihari_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}