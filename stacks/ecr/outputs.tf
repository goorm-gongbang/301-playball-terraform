#############################################
# common/ecr - Outputs
#############################################

output "web_repository_urls" {
  description = "Web service ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.web : k => v.repository_url }
}

output "ai_repository_urls" {
  description = "AI service ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.ai : k => v.repository_url }
}

output "registry_url" {
  description = "ECR registry URL"
  value       = split("/", aws_ecr_repository.web[var.web_services[0]].repository_url)[0]
}
