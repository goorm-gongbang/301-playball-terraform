#############################################
# SSO Terraform Providers
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
    key          = "root/sso/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
    profile      = "wonny"
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "wonny"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "global"
    }
  }
}
