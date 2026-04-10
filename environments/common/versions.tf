#############################################
# Common Environment - Terraform Configuration
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
    bucket       = "playball-tf-state"
    key          = "common/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

#############################################
# Load YAML Configuration
#############################################

locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

#############################################
# AWS Provider
#############################################

provider "aws" {
  region = local.config.aws_region

  default_tags {
    tags = {
      Project   = local.config.project_name
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
