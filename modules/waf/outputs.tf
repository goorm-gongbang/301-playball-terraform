#############################################
# WAF Module - Outputs
#############################################

output "web_acl_id" {
  description = "WAF WebACL ID"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "WAF WebACL ARN"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "WAF WebACL Name"
  value       = aws_wafv2_web_acl.this.name
}
