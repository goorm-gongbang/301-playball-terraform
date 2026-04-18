#############################################
# S3 Audit & Security Stack
# - audit-logs S3 bucket (CloudTrail log storage)
# - CloudTrail (management + S3 data events)
# - Security Events (EventBridge → Lambda → Discord)
# - Audit Events (S3 delete detection → Lambda → Discord)
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket       = "playball-tfstate"
    key          = "common/s3-audit-security/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project   = "goormgb"
      ManagedBy = "terraform"
      Layer     = "audit-security"
    }
  }
}

data "aws_caller_identity" "current" {}
