output "managed_buckets" {
  description = "List of buckets with managed lifecycle policies"
  value       = keys(var.bucket_lifecycle)
}
