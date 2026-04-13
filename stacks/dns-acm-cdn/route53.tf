#############################################
# Hosted Zone: staging.playball.one (ca account)
# 본계정 playball.one zone 에 이 zone 의 NS 를 등록하면 위임 완료
#############################################

resource "aws_route53_zone" "staging" {
  name = "${var.environment}.${var.domain_name}"

  tags = {
    Name        = "${var.environment}.${var.domain_name}"
    Environment = var.environment
  }
}
