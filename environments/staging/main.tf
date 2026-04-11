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
  monitoring_capacity_type  = lookup(local.config.eks.node_groups.monitoring, "capacity_type", "SPOT")
  monitoring_min_size       = local.config.eks.node_groups.monitoring.min_size
  monitoring_max_size       = local.config.eks.node_groups.monitoring.max_size
  monitoring_desired_size   = local.config.eks.node_groups.monitoring.desired_size

  # Node Group - Infra
  infra_instance_types = local.config.eks.node_groups.infra.instance_types
  infra_capacity_type  = lookup(local.config.eks.node_groups.infra, "capacity_type", "SPOT")
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

# Bastion 미사용 (staging은 SSM으로 직접 접근)

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

# DNS + CDN은 메인 계정에서 관리 (cross-account)
# Phase 2에서 메인 계정 CloudFront → kj 계정 ALB로 연결

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
  backup_s3_bucket        = "playball-web-backup"

  depends_on = [module.elasticache, module.rds]
}

#############################################
# Observability IRSA (Loki/Tempo/Thanos → S3)
#############################################

module "observability_irsa" {
  source = "../../modules/observability-irsa"

  owner_name  = local.owner
  environment = local.env

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider

  s3_bucket_names = [
    "playball-staging-loki",
    "playball-staging-tempo",
    "playball-staging-thanos"
  ]

  depends_on = [module.eks]
}

#############################################
# Dynamic Secrets (인프라 엔드포인트 자동 주입)
# 고정 시크릿은 stacks/secrets/ 에서 관리
#############################################

locals {
  dynamic_secrets = {
    "staging/ai-service/redis" = {
      description = "Redis connection for AI Defense session storage"
    }
    "staging/ai-service/postgres" = {
      description = "PostgreSQL connection for AI Defense policy control-plane"
    }
  }
}

resource "aws_secretsmanager_secret" "dynamic" {
  for_each = local.dynamic_secrets

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = "staging"
    Type        = "dynamic"
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_secretsmanager_secret_version" "ai_redis" {
  secret_id = aws_secretsmanager_secret.dynamic["staging/ai-service/redis"].id
  secret_string = jsonencode({
    host = module.elasticache.redis_endpoint
    port = "6379"
  })

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret_version" "ai_postgres" {
  secret_id = aws_secretsmanager_secret.dynamic["staging/ai-service/postgres"].id
  secret_string = jsonencode({
    host     = module.rds.address
    port     = "5432"
    username = "ai_defense"
    password = "CHANGE_ME_IN_CONSOLE"
    dbname   = "ai_defense"
  })

  lifecycle { ignore_changes = [secret_string] }
}
