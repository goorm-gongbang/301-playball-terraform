#############################################
# Dev Environment - Terraform Configuration
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "playball-tfstate"
    key          = "dev/terraform.tfstate"
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
      Environment = local.config.environment
      ManagedBy   = "terraform"
      Owner       = local.config.owner_name
      Project     = "goormgb-${local.config.environment}"
    }
  }
}

data "aws_caller_identity" "current" {}
