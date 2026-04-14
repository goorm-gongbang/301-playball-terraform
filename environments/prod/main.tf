#############################################
# Prod Environment - Main Configuration
#############################################

locals {
  env              = local.config.environment
  owner            = local.config.owner_name
  region           = local.config.aws_region
  eks_cluster_name = "${local.owner}-${local.env}-eks"
  account_id       = data.aws_caller_identity.current.account_id
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
  enable_multi_az_nat  = lookup(local.config.vpc, "enable_multi_az_nat", false)
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
  vpc_cidr           = local.config.vpc.cidr

  redis_engine_version       = local.config.elasticache.engine_version
  node_type                  = local.config.elasticache.node_type
  num_cache_clusters         = local.config.elasticache.num_cache_clusters
  transit_encryption_enabled = lookup(local.config.elasticache, "transit_encryption", false)
  transit_encryption_mode    = lookup(local.config.elasticache, "transit_encryption_mode", "preferred")

  # Bastion에서 Redis 접근 허용
  bastion_security_group_id = module.bastion.security_group_id

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
  vpc_cidr           = local.config.vpc.cidr

  engine_version        = local.config.rds.engine_version
  instance_class        = local.config.rds.instance_class
  allocated_storage     = local.config.rds.allocated_storage
  max_allocated_storage = local.config.rds.max_allocated_storage
  multi_az              = local.config.rds.multi_az
  deletion_protection   = local.config.rds.deletion_protection

  enable_cloudwatch_logs = true
  monitoring_interval    = lookup(local.config.rds, "monitoring_interval", 0)
  max_connections        = lookup(local.config.rds, "max_connections", 100)

  # Bastion에서 RDS 접근 허용
  bastion_security_group_id = module.bastion.security_group_id

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
# Ops Alerting (CloudWatch → Discord)
#############################################

module "ops_alerting" {
  source = "../../modules/ops-alerting"

  environment = local.env
  owner_name  = local.owner
  aws_region  = local.region
  account_id  = local.account_id

  discord_secret_name   = "${local.env}/monitoring/discord-webhook-alerts"
  critical_mention_text = "@개발팀 @admins"

  redis_cache_cluster_id = "${local.owner}-${local.env}-redis-001"
  alarms_enabled         = true

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
    "playball-prod-loki",
    "playball-prod-tempo",
    "playball-prod-thanos"
  ]

  depends_on = [module.eks]
}

# DNS + CDN은 메인 계정에서 관리 (cross-account)

#############################################
# Dynamic Secrets (인프라 엔드포인트 자동 주입)
# 고정 시크릿은 stacks/secrets/ 에서 관리
#############################################

locals {
  dynamic_secrets = {
    "prod/services/redis" = {
      description = "Redis connection credentials (prod)"
    }
  }
}

resource "aws_secretsmanager_secret" "dynamic" {
  for_each = local.dynamic_secrets

  name                    = each.key
  description             = each.value.description
  recovery_window_in_days = 0  # destroy 시 즉시 삭제 (재생성 충돌 방지)

  tags = {
    Name        = each.key
    Environment = "prod"
    Type        = "dynamic"
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.dynamic["prod/services/redis"].id
  secret_string = jsonencode({
    host = module.elasticache.redis_endpoint
    port = "6379"
  })

  lifecycle { ignore_changes = [secret_string] }
}

#############################################
# Static Secrets 엔드포인트 자동 주입
# services/db → RDS 모듈이 자동 생성/주입
# services/redis → dynamic_secrets에서 생성
#############################################

data "aws_secretsmanager_secret" "ai_service_common" {
  name = "prod/ai-service/common"
}

resource "aws_secretsmanager_secret_version" "ai_service_common" {
  secret_id = data.aws_secretsmanager_secret.ai_service_common.id
  secret_string = jsonencode({
    redis_host       = module.elasticache.redis_endpoint
    redis_port       = "6379"
    pg_host          = module.rds.address
    pg_port          = "5432"
    pg_username      = "ai_defense"
    pg_password      = "CHANGE_ME_IN_CONSOLE"
    pg_dbname        = "ai_defense"
    ch_user          = "default"
    ch_password      = ""
    AUTH_GUARD_URL   = "http://auth-guard.prod-webs.svc.cluster.local:8080/auth"
    INTERNAL_API_KEY = ""
    TM_ROLLOUT_SALT  = "CHANGE_ME_IN_CONSOLE"
  })

  lifecycle { ignore_changes = [secret_string] }
}
