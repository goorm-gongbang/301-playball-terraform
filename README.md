# playball-terraform

Playball 프로젝트 AWS 인프라를 관리하는 Terraform 레포입니다.

## 구조

```
301-playball-terraform/
├── tf-backend/              # playball-tfstate S3 (bootstrap)
├── stacks/                  # 독립 state root (인프라와 무관하게 유지)
│   ├── s3/                  # backup, archive, ai-data, ai-backup
│   ├── audit-security/      # audit-logs S3 + CloudTrail + Security/Audit Events
│   ├── dns-acm-cdn/         # Route53 + ACM + CloudFront + assets S3
│   ├── obs-s3-lifecycle/    # Loki/Tempo/Thanos S3 + lifecycle
│   ├── secrets/             # 고정 시크릿 (dev/staging/prod)
│   ├── ecr/                 # ECR 레지스트리
│   ├── iam-bots/            # Account 설정 + CICD봇 + kubeadm 정책
│   └── sso/                 # SSO 사용자/그룹/권한
├── environments/            # 환경별 인프라 (생성/삭제 가능)
│   ├── dev/                 # Dev 동적 시크릿
│   ├── staging/             # Staging 풀 인프라 (VPC, EKS, RDS, Redis, CDN 등)
│   └── prod/                # Prod 풀 인프라
└── modules/                 # 재사용 모듈
    ├── vpc/                 # VPC, 서브넷, NAT, 엔드포인트
    ├── eks/                 # EKS 클러스터, 노드그룹, IRSA
    ├── bastion/             # Bastion (SSM)
    ├── elasticache/         # Redis
    ├── rds/                 # PostgreSQL
    ├── karpenter/           # 오토스케일링
    ├── dns/                 # Route53 + ACM (환경별)
    ├── cdn/                 # CloudFront + ALB SG
    ├── waf/                 # WAF WebACL
    ├── ops-alerting/        # CloudWatch → Discord
    ├── realtime-stats/      # HyperLogLog + 봇탐지
    ├── observability-irsa/  # Loki/Tempo/Thanos S3 IRSA
    ├── cloudtrail/          # CloudTrail + CloudWatch Logs
    ├── security-events/     # EventBridge → Lambda → Discord (보안)
    └── audit-events/        # EventBridge → Lambda → Discord (감사)
```

## stacks vs environments

| 구분 | 설명 | 예시 |
|------|------|------|
| **stacks/** | 인프라 생성/삭제와 무관하게 영구 유지되는 리소스 | S3 버킷, ECR, IAM, SSO, DNS, Secrets |
| **environments/** | 환경별로 생성/삭제 가능한 인프라 | VPC, EKS, RDS, Redis, Bastion |

## State 관리

모든 state는 `playball-tfstate` S3 버킷에 저장됩니다.

| State Key | 위치 |
|-----------|------|
| `common/s3/terraform.tfstate` | stacks/s3 |
| `common/s3-audit-security/terraform.tfstate` | stacks/audit-security |
| `dns/root/terraform.tfstate` | stacks/dns-acm-cdn |
| `common/obs-s3-lifecycle/terraform.tfstate` | stacks/obs-s3-lifecycle |
| `common/secrets/terraform.tfstate` | stacks/secrets |
| `common/ecr/terraform.tfstate` | stacks/ecr |
| `common/iam-bots/terraform.tfstate` | stacks/iam-bots |
| `common/sso/terraform.tfstate` | stacks/sso |
| `dev/terraform.tfstate` | environments/dev |
| `staging/terraform.tfstate` | environments/staging |
| `prod/terraform.tfstate` | environments/prod |

## S3 버킷

모든 S3 버킷은 `playball-` 프리픽스를 사용합니다.

| 버킷 | 관리 위치 | 용도 |
|------|-----------|------|
| `playball-tfstate` | tf-backend/ | Terraform state |
| `playball-web-backup` | stacks/s3 | 운영 백업 (DB, 로그) |
| `playball-retention-archive` | stacks/s3 | 장기 보관 (DEEP_ARCHIVE) |
| `playball-ai-data` | stacks/s3 | AI팀 데이터 |
| `playball-ai-backup` | stacks/s3 | AI팀 백업 |
| `playball-cloudtrail-audit` | stacks/audit-security | CloudTrail + 감사 로그 |
| `playball-assets` | stacks/dns-acm-cdn | 정적 에셋 (CloudFront CDN) |
| `playball-{env}-loki` | stacks/obs-s3-lifecycle | Loki 로그 저장소 |
| `playball-{env}-tempo` | stacks/obs-s3-lifecycle | Tempo 트레이스 저장소 |
| `playball-{env}-thanos` | stacks/obs-s3-lifecycle | Thanos 메트릭 저장소 |

## 배포 순서

처음 세팅할 때:

```bash
# 1. State 버킷 (이미 존재하면 skip)
cd tf-backend && terraform init && terraform apply

# 2. Stacks (순서 무관, 병렬 가능)
cd stacks/s3 && terraform init && terraform apply
cd stacks/audit-security && terraform init && terraform apply
cd stacks/dns-acm-cdn && terraform init && terraform apply
cd stacks/obs-s3-lifecycle && terraform init && terraform apply
cd stacks/secrets && terraform init && terraform apply
cd stacks/ecr && terraform init && terraform apply
cd stacks/iam-bots && terraform init && terraform apply
cd stacks/sso && terraform init && terraform apply

# 3. Environments
cd environments/dev && terraform init && terraform apply
cd environments/staging && terraform init && terraform apply
cd environments/prod && terraform init && terraform apply
```

## 환경별 차이

| 항목 | Staging | Prod |
|------|---------|------|
| EKS public access | 팀 IP 3개 | 팀 IP 3개 |
| Apps 노드 | SPOT | SPOT |
| Redis | cache.t4g.small | cache.t4g.micro |
| RDS | db.t4g.small | db.t4g.micro |
| RDS deletion_protection | true | true |
| DNS + CDN | O | 별도 관리 |
| Realtime Stats | O | X |
| Observability IRSA | O | O |
