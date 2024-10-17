output "cluster_id" {
  value = aws_eks_cluster.srihari.id
}

output "node_group_id" {
  value = aws_eks_node_group.srihari.id
}

output "vpc_id" {
  value = aws_vpc.srihari_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.srihari_subnet[*].id
}