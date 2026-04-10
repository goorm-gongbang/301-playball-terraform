#############################################
# Common Environment - Main Configuration
#############################################

locals {
  project_name = local.config.project_name
  aws_region   = local.config.aws_region
  account_id   = data.aws_caller_identity.current.account_id
}

#############################################
# S3 Buckets
#############################################

module "s3" {
  source = "../../modules/s3-common"

  project_name = local.project_name
  account_id   = local.account_id

  cloudtrail_source_arns = local.config.cloudtrail.enabled ? [
    module.cloudtrail.source_arn
  ] : []
}

#############################################
# Account IAM
#############################################

module "account_iam" {
  source = "../../modules/account-iam"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id

  cn_members = local.config.iam.cn_members

  s3_full_access_bucket_arns = concat(
    module.s3.all_bucket_arns,
    ["arn:aws:s3:::playball-tf-state"]
  )

  backup_bucket_name = module.s3.backup_bucket_id

  depends_on = [module.s3]
}

#############################################
# CloudTrail
#############################################

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name = local.project_name
  aws_region   = local.aws_region
  enabled      = local.config.cloudtrail.enabled

  audit_logs_bucket_id = module.s3.audit_logs_bucket_id
  s3_key_prefix        = local.config.cloudtrail.s3_key_prefix
  log_retention_days   = local.config.cloudtrail.log_retention_days

  tracked_s3_bucket_arns = module.s3.all_bucket_arns

  depends_on = [module.s3]
}

#############################################
# Security Events (EventBridge → Discord)
#############################################

module "security_events" {
  source = "../../modules/security-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = local.config.security_events.enabled

  discord_secret_name  = local.config.security_events.discord_secret_name
  discord_username     = local.config.security_events.discord_username
  critical_mention_text = local.config.security_events.critical_mention_text
}

#############################################
# Audit Events (EventBridge → Discord + S3)
#############################################

module "audit_events" {
  source = "../../modules/audit-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = local.config.audit_events.enabled

  audit_logs_bucket_id  = module.s3.audit_logs_bucket_id
  audit_logs_bucket_arn = module.s3.audit_logs_bucket_arn
  summary_prefix        = local.config.audit_events.summary_prefix

  monitored_bucket_names = local.config.audit_events.monitored_buckets

  discord_secret_name   = local.config.audit_events.discord_secret_name
  discord_username      = local.config.audit_events.discord_username
  critical_mention_text = local.config.audit_events.critical_mention_text

  depends_on = [module.s3]
}

#############################################
# Observability Storage Lifecycle
#############################################

module "observability_lifecycle" {
  source = "../../modules/observability-lifecycle"

  bucket_lifecycle = local.config.observability_lifecycle
}

#############################################
# ACM Certificate (Wildcard)
#############################################

data "aws_route53_zone" "main" {
  name         = local.config.domain_name
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.3"

  domain_name = local.config.domain_name
  zone_id     = data.aws_route53_zone.main.zone_id

  subject_alternative_names = ["*.${local.config.domain_name}"]
  wait_for_validation       = true

  tags = {
    Name        = "${local.project_name}-common-acm"
    Environment = "common"
  }
}
