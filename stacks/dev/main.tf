locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

module "secrets" {
  source = "../_modules/secrets"

  environment = local.config.environment
  secrets     = local.config.secrets
}

module "s3" {
  source = "../_modules/s3"

  environment               = local.config.environment
  enable_monitoring_buckets  = local.config.s3.enable_monitoring
  enable_ai_audit_bucket    = local.config.s3.enable_ai_audit
  enable_archive_bucket     = local.config.s3.enable_archive
  backup_lifecycle_rules    = local.config.s3.backup_lifecycle
}
