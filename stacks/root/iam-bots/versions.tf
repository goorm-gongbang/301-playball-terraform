#############################################
# IAM Bots Stack - Terraform Configuration
# CICD 봇 사용자 및 환경별 접근 정책
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "goormgb-tf-state"
    key          = "root/iam-bots/terraform.tfstate"
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
      Layer     = "iam-bots"
    }
  }
}

data "aws_caller_identity" "current" {}
