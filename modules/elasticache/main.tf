#############################################
# ElastiCache Module - Main Resources
# 단일 Redis Replication Group (DB별 용도 분리)
#############################################

#############################################
# Subnet Group
#############################################

resource "aws_elasticache_subnet_group" "main" {
  name        = "${local.name_slug}-redis-subnet-group"
  description = "Redis subnet group"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-redis-subnet-group"
  }
}

#############################################
# Security Group
#############################################

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  # VPC CIDR 기반 규칙 (EKS 모듈 의존성 없음)
  dynamic "ingress" {
    for_each = var.vpc_cidr != "" ? [1] : []
    content {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Redis from VPC (EKS pods)"
    }
  }

  dynamic "ingress" {
    for_each = var.bastion_security_group_id != "" ? [1] : []
    content {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
      description     = "Redis from Bastion"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-redis-sg"
  }
}

#############################################
# Parameter Group
#############################################

resource "aws_elasticache_parameter_group" "main" {
  name        = "${local.name_slug}-redis-params"
  family      = var.redis_family
  description = "Redis parameter group"

  # LRU for cache DBs, noeviction handled at app level
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = {
    Name = "${local.name_prefix}-redis-params"
  }
}

#############################################
# Redis Replication Group (Primary + Replica)
#############################################

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_slug}-redis"
  description          = "Redis for ${local.name_prefix} (Cache/Queue/AI)"

  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Replication 설정
  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? true : false

  # Network
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Maintenance
  maintenance_window       = "Mon:05:00-Mon:06:00"
  snapshot_retention_limit = var.snapshot_retention
  snapshot_window          = var.snapshot_retention > 0 ? "02:00-03:00" : null

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_enabled ? var.transit_encryption_mode : null
  apply_immediately          = true

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}
