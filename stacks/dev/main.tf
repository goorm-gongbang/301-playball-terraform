locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

# ===========================================
# [DEPRECATED] AWS Secrets Manager
# ESO + SM 방식 → Sealed Secrets로 전환
# _secrets 모듈은 유지하되 비활성화
# ===========================================
# module "secrets" {
#   source      = "../_modules/_secrets"
#   environment = local.config.environment
#   secrets     = local.config.secrets
# }

# ===========================================
# Sealed Secrets Key Backup (SSM Parameter Store)
# Sealing key 분실 시 복호화 불가 → 백업 필수
# SSM Standard tier = 무료
# ===========================================
module "sealed_secrets_backup" {
  source = "../_modules/sealed-secrets-backup"
  count  = local.config.sealed_secrets.enabled ? 1 : 0

  environment      = local.config.environment
  parameter_prefix = local.config.sealed_secrets.key_backup.parameter_prefix
}

# ===========================================
# S3 Storage
# ===========================================
module "s3" {
  source = "../_modules/s3"

  environment              = local.config.environment
  enable_monitoring_buckets = local.config.s3.enable_monitoring
  enable_ai_audit_bucket   = local.config.s3.enable_ai_audit
  enable_archive_bucket    = local.config.s3.enable_archive
  backup_lifecycle_rules   = local.config.s3.backup_lifecycle
}
