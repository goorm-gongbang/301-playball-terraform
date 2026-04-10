output "state_bucket_name" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_arn" {
  description = "Terraform state S3 bucket ARN"
  value       = aws_s3_bucket.tf_state.arn
}

output "next_steps" {
  description = "다음 단계 안내"
  value       = <<-EOT

    Bootstrap 완료!

    생성된 리소스:
    - S3 State: ${aws_s3_bucket.tf_state.id}

    State Locking: S3 네이티브 락킹 사용 (use_lockfile = true)

    다음 단계:
    1. cd ../stacks/s3
    2. terraform init && terraform apply
    3. cd ../environments/common
    4. terraform init && terraform apply

  EOT
}
