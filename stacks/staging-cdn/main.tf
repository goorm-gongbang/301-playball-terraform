#############################################
# Staging CDN Stack (ca account)
# - Route53 hosted zone: staging.playball.one (ca 위임)
# - ACM (us-east-1): api.staging.playball.one (CloudFront viewer cert)
# - CloudFront distribution: api.staging.playball.one → ALB
#
# 본계정 playball.one zone 에 NS 위임 레코드를 추가해야 동작함.
# (zone_name_servers output 을 본계정 Route53 레코드로 입력)
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
    bucket       = "playball-tfstate"
    key          = "cdn/staging/terraform.tfstate"
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
      Environment = "staging"
      Layer       = "cdn"
    }
  }
}

# CloudFront ACM 은 us-east-1 필수
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "staging"
      Layer       = "cdn"
    }
  }
}
