#############################################
# Apex (playball.one) - Vercel frontend + Google email
#############################################

resource "aws_route53_record" "apex_a" {
  zone_id = aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = var.default_ttl
  records = [var.vercel_apex_ip]
}

resource "aws_route53_record" "apex_mx" {
  zone_id = aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 60
  records = [
    "1 SMTP.GOOGLE.COM",
    "1 ASPMX.L.GOOGLE.COM",
    "5 ALT1.ASPMX.L.GOOGLE.COM",
    "5 ALT2.ASPMX.L.GOOGLE.COM",
    "10 ALT3.ASPMX.L.GOOGLE.COM",
    "10 ALT4.ASPMX.L.GOOGLE.COM",
  ]
}

resource "aws_route53_record" "apex_txt" {
  zone_id = aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 60
  records = [var.google_site_verification]
}

#############################################
# www.playball.one → Vercel
#############################################

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.default_ttl
  records = [var.vercel_cname_target]
}

#############################################
# docs.playball.one → Vercel
#############################################

resource "aws_route53_record" "docs" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "docs.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.default_ttl
  records = [var.vercel_cname_target]
}

#############################################
# guide.playball.one → Netlify
#############################################

resource "aws_route53_record" "guide" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "guide.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.default_ttl
  records = [var.netlify_guide_cname]
}

#############################################
# assets.playball.one → CloudFront (본계정 유지)
#############################################

resource "aws_route53_record" "assets" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "assets.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.assets_cloudfront_domain
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront global hosted zone
    evaluate_target_health = false
  }
}

#############################################
# staging.playball.one → 서브 zone 위임 (ca 계정 내)
#############################################

resource "aws_route53_record" "staging_ns" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "staging.${var.domain_name}"
  type    = "NS"
  ttl     = var.default_ttl
  records = data.aws_route53_zone.staging.name_servers
}

#############################################
# ACM validation CNAMEs (본계정 us-east-1 cert 유지용)
#############################################

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for r in var.acm_validation_records : r.name => r
  }

  zone_id = aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = 60
  records = [each.value.value]
}
