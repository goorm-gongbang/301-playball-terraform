#############################################
# RDS Module - Main Resources
#############################################

#############################################
# Secrets Manager - DB Password
#############################################

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}/services/db"
  description             = "RDS PostgreSQL master password for ${local.name_prefix}"
  recovery_window_in_days = 0 # destroy 시 즉시 삭제 (재생성 충돌 방지)

  tags = {
    Name        = "${var.environment}/services/db"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode(merge(
    {
      username = var.db_username
      password = random_password.master.result
      host     = aws_db_instance.main.address
      port     = aws_db_instance.main.port
      dbname   = var.db_name
      engine   = "postgres"
    },
    var.additional_secrets
  ))

  depends_on = [aws_db_instance.main]
}

#############################################
# Subnet Group
#############################################

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_slug}-db-subnet-group"
  description = "Database subnet group"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

#############################################
# Security Group
#############################################

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # VPC CIDR 기반 규칙 (EKS 모듈 의존성 없음)
  dynamic "ingress" {
    for_each = var.vpc_cidr != "" ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "PostgreSQL from VPC (EKS pods)"
    }
  }

  dynamic "ingress" {
    for_each = var.bastion_security_group_id != "" ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
      description     = "PostgreSQL from Bastion"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

#############################################
# Parameter Group
#############################################

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_slug}-postgresql-params"
  family      = "postgres16"
  description = "PostgreSQL parameter group"

  parameter {
    name  = "timezone"
    value = "Asia/Seoul"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # SSL 강제 (non-SSL 접속 거부)
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Connection pool size (default ~83 for t4g.medium)
  parameter {
    name         = "max_connections"
    value        = var.max_connections
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${local.name_prefix}-postgresql-params"
  }
}

#############################################
# RDS Instance
#############################################

resource "aws_db_instance" "main" {
  identifier = "${local.name_slug}-postgresql"

  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  parameter_group_name = aws_db_parameter_group.main.name

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_slug}-final-snapshot" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Enhanced Monitoring (OS metrics)
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  # CloudWatch Logs 내보내기 (Grafana 연동용)
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["postgresql"] : []

  tags = {
    Name = "${local.name_prefix}-postgresql"
  }
}

#############################################
# Read Replica
#############################################

resource "aws_db_instance" "read_replica" {
  count = var.read_replica_enabled ? 1 : 0

  identifier          = "${local.name_slug}-postgresql-replica"
  replicate_source_db = aws_db_instance.main.identifier

  instance_class    = var.read_replica_instance_class != "" ? var.read_replica_instance_class : var.instance_class
  storage_encrypted = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  parameter_group_name = aws_db_parameter_group.main.name

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  skip_final_snapshot = true

  tags = {
    Name = "${local.name_prefix}-postgresql-replica"
  }
}

#############################################
# Enhanced Monitoring IAM Role
#############################################

resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${local.name_slug}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
