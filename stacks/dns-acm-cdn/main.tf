#############################################
# DNS / ACM / CDN Stack
# - Route53 루트 도메인 (playball.one)
# - ACM 와일드카드 인증서 (us-east-1 + ap-northeast-2)
# - CloudFront CDN (assets.playball.one)
# - Assets S3 bucket (playball-assets)
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
    key          = "dns/root/terraform.tfstate"
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
      Layer     = "dns"
    }
  }
}

# CloudFront ACM은 us-east-1 필수
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "goormgb"
      ManagedBy = "terraform"
      Layer     = "dns"
    }
  }
}
