#############################################
# Staging Environment - Main Configuration
#############################################

locals {
  env              = local.config.environment
  owner            = local.config.owner_name
  region           = local.config.aws_region
  eks_cluster_name = "${local.owner}-${local.env}-eks"
}

#############################################
# VPC Module
#############################################

module "vpc" {
  source = "../../modules/vpc"

  owner_name       = local.owner
  environment      = local.env
  eks_cluster_name = local.eks_cluster_name

  vpc_cidr             = local.config.vpc.cidr
  availability_zones   = local.config.vpc.availability_zones
  public_subnet_cidrs  = local.config.vpc.public_subnets
  private_subnet_cidrs = local.config.vpc.private_subnets
  vpc_endpoints        = local.config.vpc_endpoints
}

#############################################
# EKS Module
#############################################

module "eks" {
  source = "../../modules/eks"

  owner_name  = local.owner
  environment = local.env
  aws_region  = local.region

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_cidr_blocks    = [local.config.vpc.cidr]

  cluster_version                      = local.config.eks.cluster_version
  cluster_endpoint_public_access       = local.config.eks.public_access
  cluster_endpoint_public_access_cidrs = local.config.eks.public_access_cidrs

  # SSO Access Entry
  enable_devops_role_access = local.config.eks.access_entries.devops_sso.enabled
  devops_role_arn           = local.config.eks.access_entries.devops_sso.role_arn

  # Node Group - Monitoring
  monitoring_instance_types = local.config.eks.node_groups.monitoring.instance_types
  monitoring_min_size       = local.config.eks.node_groups.monitoring.min_size
  monitoring_max_size       = local.config.eks.node_groups.monitoring.max_size
  monitoring_desired_size   = local.config.eks.node_groups.monitoring.desired_size

  # Node Group - Infra
  infra_instance_types = local.config.eks.node_groups.infra.instance_types
  infra_min_size       = local.config.eks.node_groups.infra.min_size
  infra_max_size       = local.config.eks.node_groups.infra.max_size
  infra_desired_size   = local.config.eks.node_groups.infra.desired_size

  # Node Group - Apps
  apps_instance_types = local.config.eks.node_groups.apps.instance_types
  apps_capacity_type  = lookup(local.config.eks.node_groups.apps, "capacity_type", "SPOT")
  apps_min_size       = local.config.eks.node_groups.apps.min_size
  apps_max_size       = local.config.eks.node_groups.apps.max_size
  apps_desired_size   = local.config.eks.node_groups.apps.desired_size

  # IRSA - External Secrets
  secrets_manager_arns = local.config.irsa.secrets_manager_arns

  depends_on = [module.vpc]
}

#############################################
# Bastion Module
#############################################

module "bastion" {
  source = "../../modules/bastion"

  owner_name  = local.owner
  environment = local.env

  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = local.config.vpc.cidr
  public_subnet_id = module.vpc.public_subnet_ids[0]
  instance_type    = local.config.bastion.instance_type

  depends_on = [module.vpc]
}

#############################################
# ElastiCache Module (Redis)
#############################################

module "elasticache" {
  source = "../../modules/elasticache"

  owner_name  = local.owner
  environment = local.env

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # VPC CIDR 기반 규칙 (독립적으로 배포 가능)
  vpc_cidr = local.config.vpc.cidr

  redis_engine_version       = local.config.elasticache.engine_version
  node_type                  = local.config.elasticache.node_type
  num_cache_clusters         = local.config.elasticache.num_cache_clusters
  transit_encryption_enabled = lookup(local.config.elasticache, "transit_encryption", false)

  depends_on = [module.vpc]
}

#############################################
# RDS Module (PostgreSQL)
#############################################

module "rds" {
  source = "../../modules/rds"

  owner_name  = local.owner
  environment = local.env

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # VPC CIDR 기반 규칙 (독립적으로 배포 가능)
  vpc_cidr = local.config.vpc.cidr

  engine_version        = local.config.rds.engine_version
  instance_class        = local.config.rds.instance_class
  allocated_storage     = local.config.rds.allocated_storage
  max_allocated_storage = local.config.rds.max_allocated_storage
  multi_az              = local.config.rds.multi_az
  deletion_protection   = local.config.rds.deletion_protection

  # CloudWatch Logs (Grafana 연동)
  enable_cloudwatch_logs = true

  # Enhanced Monitoring (OS metrics)
  monitoring_interval = lookup(local.config.rds, "monitoring_interval", 0)

  # Connection pool size
  max_connections = lookup(local.config.rds, "max_connections", 100)

  depends_on = [module.vpc]
}

#############################################
# Karpenter Module
#############################################

module "karpenter" {
  source = "../../modules/karpenter"

  owner_name  = local.owner
  environment = local.env

  eks_cluster_name      = module.eks.cluster_name
  eks_oidc_provider_arn = module.eks.oidc_provider_arn

  depends_on = [module.eks]
}

#############################################
# DNS Module (Route53 + ACM)
#############################################

module "dns" {
  source = "../../modules/dns"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment  = local.env
  domain_name  = "playball.one"
  vercel_ip    = "76.76.21.21"
  vercel_cname = "912cfcafdeccf2b2.vercel-dns-017.com"
}

#############################################
# CDN Module (CloudFront + WAF + ALB SG)
#############################################

module "cdn" {
  source = "../../modules/cdn"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment = local.env
  domain      = "api.${local.env}.playball.one"

  # CloudFront origin
  alb_dns             = local.config.cdn.alb_dns
  acm_certificate_arn = module.dns.acm_cloudfront_arn

  # Route53
  route53_zone_id     = module.dns.zone_id
  route53_record_name = "api"

  # ALB SG (태그 기반 자동 발견)
  eks_cluster_name  = module.eks.cluster_name
  alb_ingress_stack = "${local.env}-alb"
  admin_allowed_ips = local.config.cdn.admin_allowed_ips

  # WAF (코드 준비됨, 필요 시 true로 변경)
  enable_waf            = false
  waf_geo_allow_only    = ["KR"]
  waf_rate_limit_global = 1500
  waf_rate_limit_auth   = 50
  waf_max_body_size     = 8192
  waf_exclude_paths     = ["/load-test/"]
  waf_enable_bot_control = false
  waf_enable_atp         = false

  depends_on = [module.dns, module.eks]
}

# #############################################
# # Realtime Stats (1주 한정)
# # Lambda Layer 빌드 후 주석 해제: modules/realtime-stats/layers/build.sh
# #############################################
#
# module "realtime_stats" {
#   count  = local.config.realtime_stats.enabled ? 1 : 0
#   source = "../../modules/realtime-stats"
#
#   environment = local.env
#   owner_name  = local.owner
#
#   vpc_id             = module.vpc.vpc_id
#   vpc_cidr           = local.config.vpc.cidr
#   private_subnet_ids = module.vpc.private_subnet_ids
#
#   redis_host              = module.elasticache.redis_endpoint
#   redis_port              = 6379
#   redis_tls               = lookup(local.config.elasticache, "transit_encryption", false)
#   redis_security_group_id = module.elasticache.security_group_id
#
#   cloudfront_distribution_id = module.cdn.cloudfront_id
#   sampling_rate              = local.config.realtime_stats.sampling_rate
#
#   # 봇 탐지 / ratio 분석 임계치
#   bot_req_threshold      = lookup(local.config.realtime_stats, "bot_req_threshold", 200)
#   bot_blocklist_ttl      = lookup(local.config.realtime_stats, "bot_blocklist_ttl", 3600)
#   ratio_single_ip_attack = lookup(local.config.realtime_stats, "ratio_single_ip_attack", 50)
#   ratio_botnet_attack    = lookup(local.config.realtime_stats, "ratio_botnet_attack", 1.2)
#   min_requests_for_ratio = lookup(local.config.realtime_stats, "min_requests_for_ratio", 500)
#
#   depends_on = [module.cdn, module.elasticache]
# }

#############################################
# Ops Alerting (CloudWatch → Discord)
#############################################

module "ops_alerting" {
  source = "../../modules/ops-alerting"

  environment = local.env
  owner_name  = local.owner
  aws_region  = local.region
  account_id  = data.aws_caller_identity.current.account_id

  discord_secret_name   = "${local.env}/monitoring/discord-webhook-alerts"
  critical_mention_text = "@개발팀 @admins"

  redis_cache_cluster_id = "${local.owner}-${local.env}-redis-001"
  alarms_enabled         = lookup(local.config, "ops_alerting_enabled", true)

  rds_instance_identifier = module.rds.identifier
  backup_s3_bucket        = "goormgb-backup"

  depends_on = [module.elasticache, module.rds]
}
