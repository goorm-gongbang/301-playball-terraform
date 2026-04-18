#############################################
# Route53 Root Zone - playball.one (ca account)
# 본계정 (497012402578) 에서 ca 계정으로 이관
#
# 레지스트라(Porkbun) NS 레코드를 이 stack 의 output (zone_name_servers)
# 으로 변경해야 실제 이관 완료됨.
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
    key          = "prod/route53/terraform.tfstate"
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

# ca staging zone 의 NS 를 참조 (staging.playball.one 서브도메인 위임용)
data "aws_route53_zone" "staging" {
  name         = "staging.${var.domain_name}"
  private_zone = false
}
