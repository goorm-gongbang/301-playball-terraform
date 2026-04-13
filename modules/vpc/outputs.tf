#############################################
# VPC Module - Outputs
#############################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (first one if multi-AZ)"
  value       = var.enable_multi_az_nat ? aws_nat_gateway.per_az[0].id : aws_nat_gateway.main[0].id
}

output "nat_gateway_ids" {
  description = "All NAT Gateway IDs"
  value       = var.enable_multi_az_nat ? aws_nat_gateway.per_az[*].id : [aws_nat_gateway.main[0].id]
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "name_prefix" {
  description = "Name prefix used for resources"
  value       = local.name_prefix
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID (first one if multi-AZ)"
  value       = var.enable_multi_az_nat ? aws_route_table.private_per_az[0].id : aws_route_table.private[0].id
}

output "private_route_table_ids" {
  description = "All private route table IDs"
  value       = var.enable_multi_az_nat ? aws_route_table.private_per_az[*].id : [aws_route_table.private[0].id]
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP (first one if multi-AZ)"
  value       = var.enable_multi_az_nat ? aws_eip.nat_per_az[0].public_ip : aws_eip.nat[0].public_ip
}

output "nat_gateway_public_ips" {
  description = "All NAT Gateway public IPs"
  value       = var.enable_multi_az_nat ? aws_eip.nat_per_az[*].public_ip : [aws_eip.nat[0].public_ip]
}
