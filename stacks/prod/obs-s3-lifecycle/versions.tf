#############################################
# Observability S3 & Lifecycle Stack
# - Loki / Tempo / Thanos S3 buckets (staging + prod)
# - S3 lifecycle policies (expiration, GLACIER transition)
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
    bucket       = "playball-prod-tfstate"
    key          = "prod/obs-s3-lifecycle/terraform.tfstate"
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
      Layer     = "observability"
    }
  }
}
