#############################################
# Production CDN Stack (ca account)
# - ACM (us-east-1): api.playball.one (CloudFront viewer cert)
# - CloudFront distribution: api.playball.one → ALB
# - Route53 alias: api.playball.one → CloudFront (root zone)
#
# 우선 staging ALB 를 origin 으로 사용. prod ALB 가 생기면 alb_dns 변수만 교체.
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
    key          = "cdn/prod/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "prod"
      Layer       = "cdn"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "prod"
      Layer       = "cdn"
    }
  }
}

data "aws_route53_zone" "root" {
  name = "${var.domain_name}."
}
