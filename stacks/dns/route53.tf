#############################################
# Route53 Hosted Zone - playball.one (루트)
#############################################

resource "aws_route53_zone" "root" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    Environment = "shared"
  }
}

#############################################
# NS Delegation - Subdomain Zones
#############################################

# staging.playball.one NS 위임
resource "aws_route53_record" "staging_ns" {
  count = length(var.staging_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "staging"
  type    = "NS"
  ttl     = 300
  records = var.staging_zone_name_servers
}

# prod.playball.one NS 위임 (나중에 사용)
resource "aws_route53_record" "prod_ns" {
  count = length(var.prod_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "prod"
  type    = "NS"
  ttl     = 300
  records = var.prod_zone_name_servers
}

# pentest.playball.one NS 위임 (pen-testing 계정으로 위임)
resource "aws_route53_record" "pentest_ns" {
  count = length(var.pentest_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "pentest"
  type    = "NS"
  ttl     = 300
  records = var.pentest_zone_name_servers
}

# loadtest.playball.one NS 위임 (k6-operators 계정으로 위임)
resource "aws_route53_record" "loadtest_ns" {
  count = length(var.loadtest_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "loadtest"
  type    = "NS"
  ttl     = 300
  records = var.loadtest_zone_name_servers
}

#############################################
# Vercel - playball.one (루트 도메인)
#############################################
resource "aws_route53_record" "vercel_root" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "" # @ (루트 도메인)
  type    = "A"
  ttl     = 300
  records = [var.vercel_ip]
}

#############################################
# Netlify - guide.playball.one (문서 사이트)
#############################################

resource "aws_route53_record" "guide" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "guide"
  type    = "CNAME"
  ttl     = 300
  records = [var.netlify_guide_cname]
}

#############################################
# Porkbun에 설정할 NS 레코드 출력
#############################################
# 이 NS 레코드들을 Porkbun DNS 설정에 추가해야 함
# Type: NS, Host: @, Answer: (각 name server)
