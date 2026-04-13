#############################################
# ALB Security Group ingress rules
# - CloudFront origin-facing prefix list → 443
# - 팀원 IP (모니터링 도구 직접 접근) → 443
# - 0.0.0.0/0 (80, 443) 는 수동으로 revoke 필요 (state 에 없음)
#
# ALB 는 AWS LB Controller 가 생성 → data source 로 자동 발견
#############################################

variable "eks_cluster_name" {
  description = "EKS cluster name (ALB 태그 조회용)"
  type        = string
  default     = "goormgb-staging-eks"
}

variable "alb_ingress_stack" {
  description = "AWS LB Controller ingress stack tag"
  type        = string
  default     = "staging-alb"
}

variable "admin_allowed_ips" {
  description = "팀원 공인 IP (모니터링 도구 직접 접근용)"
  type        = list(string)
  default = [
    "39.119.192.15/32",
    "124.49.102.36/32",
    "122.34.166.131/32",
  ]
}

data "aws_lb" "istio_alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.eks_cluster_name
    "ingress.k8s.aws/stack" = var.alb_ingress_stack
  }
}

data "aws_security_group" "alb" {
  filter {
    name   = "group-id"
    values = data.aws_lb.istio_alb.security_groups
  }

  filter {
    name   = "group-name"
    values = ["k8s-${replace(var.alb_ingress_stack, "-", "")}-*"]
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront → ALB (API 트래픽)
resource "aws_vpc_security_group_ingress_rule" "alb_cloudfront" {
  security_group_id = data.aws_security_group.alb.id
  description       = "CloudFront origin-facing"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

# 팀원 IP → ALB (모니터링 도구 직접 접근)
resource "aws_vpc_security_group_ingress_rule" "alb_admin" {
  for_each = toset(var.admin_allowed_ips)

  security_group_id = data.aws_security_group.alb.id
  description       = "Admin access - ${each.value}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = data.aws_security_group.alb.id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = data.aws_lb.istio_alb.dns_name
}
