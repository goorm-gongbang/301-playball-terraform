#############################################
# Hosted Zone: playball.one (ca account)
#############################################

resource "aws_route53_zone" "root" {
  name = var.domain_name

  tags = {
    Name = var.domain_name
  }
}
