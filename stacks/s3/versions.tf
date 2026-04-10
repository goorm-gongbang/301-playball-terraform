#############################################
# S3 Stack - Terraform Configuration
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
    bucket       = "playball-tf-state"
    key          = "common/s3/terraform.tfstate"
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
      Layer     = "common"
    }
  }
}

data "aws_caller_identity" "current" {}
