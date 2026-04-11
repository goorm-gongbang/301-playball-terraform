#############################################
# Bastion Module - Main Resources
#############################################

#############################################
# AMI Data Source
#############################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#############################################
# Security Group
#############################################

resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH 미사용 — SSM Session Manager 전용
  # ingress 없음 = 외부 접근 완전 차단
  # SSM은 egress 443만으로 동작 (AWS API 통신)

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for SSM and package updates"
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL (RDS)"
  }

  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis (ElastiCache)"
  }

  egress {
    from_port   = 8123
    to_port     = 8123
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "ClickHouse (HTTP)"
  }

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

#############################################
# IAM Role
#############################################

resource "aws_iam_role" "bastion" {
  name = "${local.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-bastion-role"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

#############################################
# EC2 Instance
#############################################

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true
  # SSH 미사용 (SSM 전용) — key_name 불필요

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -ex

# Serial Console 접속용 비밀번호 설정
echo 'ec2-user:Goormgb2026!' | chpasswd

# ec2-instance-connect 설치 (EC2 Instance Connect용)
yum install -y ec2-instance-connect

yum update -y

# DB 클라이언트 도구 (Developer용 RDS/Redis 접속)
yum install -y jq
yum install -y postgresql15 || yum install -y postgresql || true
yum install -y redis6 || yum install -y redis || true

# Prompt settings
cat >> /etc/profile.d/prompt.sh << 'PROMPTEOF'
PS1='\[\e[32m\]\u\[\e[0m\]@\[\e[36m\]${var.environment}\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias grep='grep --color=auto'
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups
PROMPTEOF
EOF

  tags = {
    Name      = "${local.name_prefix}-bastion"
    SSMAccess = "dba-developer" # IAM 정책에서 이 태그로 접근 제한
    Purpose   = "emergency-db-access"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}


#############################################
# SSM Session Logging
#############################################

resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = "/aws/ssm/${local.name_prefix}/session-logs"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-ssm-session-logs"
  }
}

resource "aws_ssm_document" "session_manager_prefs" {
  name            = "${local.name_prefix}-SSMSessionRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager settings"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.ssm_sessions.name
      cloudWatchEncryptionEnabled = false
      cloudWatchStreamingEnabled  = true
      idleSessionTimeout          = "30"
      shellProfile = {
        linux = "exec /bin/bash"
      }
    }
  })

  tags = {
    Name = "${local.name_prefix}-ssm-session-prefs"
  }
}

resource "aws_iam_role_policy" "bastion_ssm_logging" {
  name = "${local.name_prefix}-bastion-ssm-logging"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.ssm_sessions.arn,
          "${aws_cloudwatch_log_group.ssm_sessions.arn}:*"
        ]
      }
    ]
  })
}

#############################################
# Elastic IP
#############################################
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-bastion-eip"
  }
}