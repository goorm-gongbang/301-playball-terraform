#############################################
# Realtime Stats Module
# CloudFront RT Logs → Kinesis → Lambda → Redis HyperLogLog → CloudWatch
#
# enable = false 로 1주 후 전체 끌 수 있음
#############################################

locals {
  name_prefix = "${var.owner_name}-${var.environment}"
  function_name = "${local.name_prefix}-realtime-stats"
}

#############################################
# 1. Kinesis Data Stream (On-Demand)
#############################################

resource "aws_kinesis_stream" "cloudfront_logs" {
  name = "${local.name_prefix}-cf-realtime-logs"

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  retention_period = 24  # 최소 (비용 절감)

  tags = {
    Name        = "${local.name_prefix}-cf-realtime-logs"
    Environment = var.environment
  }
}

#############################################
# 2. CloudFront Real-time Log Config
#############################################

resource "aws_cloudfront_realtime_log_config" "main" {
  name          = "${local.name_prefix}-realtime-log"
  sampling_rate = var.sampling_rate  # 100 = 100%

  fields = [
    "timestamp",
    "c-ip",
    "cs-method",
    "cs-uri-stem",
    "cs-protocol",
    "sc-status",
    "sc-bytes",
    "time-taken",
    "cs-user-agent",
  ]

  endpoint {
    stream_type = "Kinesis"

    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_realtime.arn
      stream_arn = aws_kinesis_stream.cloudfront_logs.arn
    }
  }
}

#############################################
# 3. Lambda Function
#############################################

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda Layer (redis-py)
resource "aws_lambda_layer_version" "redis" {
  filename            = "${path.module}/layers/redis-layer.zip"
  layer_name          = "${local.name_prefix}-redis-py"
  compatible_runtimes       = ["python3.12"]
  compatible_architectures = ["arm64"]
  description         = "redis-py library for Lambda"
}

resource "aws_lambda_function" "realtime_stats" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  layers = [aws_lambda_layer_version.redis.arn]

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      REDIS_HOST       = var.redis_host
      REDIS_PORT       = tostring(var.redis_port)
      REDIS_DB         = "3"
      REDIS_TLS        = tostring(var.redis_tls)
      ENVIRONMENT      = var.environment
      METRIC_NAMESPACE = "PlayBall/RealtimeStats"
      # 봇 탐지 임계치
      BOT_REQ_THRESHOLD    = tostring(var.bot_req_threshold)
      BOT_BLOCKLIST_TTL    = tostring(var.bot_blocklist_ttl)
      RATIO_SINGLE_IP_ATTACK = tostring(var.ratio_single_ip_attack)
      RATIO_BOTNET_ATTACK    = tostring(var.ratio_botnet_attack)
      MIN_REQUESTS_FOR_RATIO = tostring(var.min_requests_for_ratio)
    }
  }

  tags = {
    Name        = local.function_name
    Environment = var.environment
  }
}

# Kinesis → Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "kinesis" {
  event_source_arn  = aws_kinesis_stream.cloudfront_logs.arn
  function_name     = aws_lambda_function.realtime_stats.arn
  starting_position = "LATEST"
  batch_size        = 100

  # 최대 10초 대기 후 배치 처리 (비용 vs 실시간 트레이드오프)
  maximum_batching_window_in_seconds = 10
}

#############################################
# 4. Security Group (Lambda → Redis)
#############################################

resource "aws_security_group" "lambda" {
  name_prefix = "${local.name_prefix}-realtime-stats-"
  description = "Lambda realtime-stats → Redis"
  vpc_id      = var.vpc_id

  egress {
    description = "Redis"
    from_port   = var.redis_port
    to_port     = var.redis_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS (CloudWatch API)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-realtime-stats-lambda"
    Environment = var.environment
  }
}

# Redis SG에 Lambda 접근 허용
resource "aws_vpc_security_group_ingress_rule" "redis_from_lambda" {
  security_group_id            = var.redis_security_group_id
  description                  = "Lambda realtime-stats"
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.lambda.id
}

#############################################
# 5. IAM Roles
#############################################

# CloudFront → Kinesis
resource "aws_iam_role" "cloudfront_realtime" {
  name = "${local.name_prefix}-cf-realtime-log"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudfront_kinesis" {
  name = "kinesis-put"
  role = aws_iam_role.cloudfront_realtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:DescribeStream",
        "kinesis:DescribeStreamSummary",
      ]
      Resource = aws_kinesis_stream.cloudfront_logs.arn
    }]
  })
}

# Lambda execution role
resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-realtime-stats-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "realtime-stats"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards",
          "kinesis:ListStreams",
        ]
        Resource = aws_kinesis_stream.cloudfront_logs.arn
      },
      {
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "PlayBall/RealtimeStats"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ]
        Resource = "*"
      },
    ]
  })
}
