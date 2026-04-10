#############################################
# CDN Module - Provider Configuration
# CloudFront + WAF는 us-east-1 필수
#############################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
