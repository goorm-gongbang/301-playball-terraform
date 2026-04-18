output "zone_id" {
  description = "Route53 zone ID for playball.one (ca)"
  value       = aws_route53_zone.root.zone_id
}

output "zone_name_servers" {
  description = "⚠️  Porkbun 에 등록할 NS 레코드 (NS 변경 시 zone 이관 완료)"
  value       = aws_route53_zone.root.name_servers
}
