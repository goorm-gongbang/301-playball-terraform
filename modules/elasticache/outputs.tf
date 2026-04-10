#############################################
# ElastiCache Module - Outputs
#############################################

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint (for read replicas)"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

# 앱에서 사용할 URL 형식
output "redis_url" {
  description = "Redis URL for applications"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379"
}

# DB별 URL (Cache=0, Queue=1, AI=2)
output "redis_cache_url" {
  description = "Redis URL for cache (DB 0)"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/0"
}

output "redis_queue_url" {
  description = "Redis URL for queue (DB 1)"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/1"
}

output "redis_ai_url" {
  description = "Redis URL for AI (DB 2)"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/2"
}
