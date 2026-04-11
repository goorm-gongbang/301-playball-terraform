#!/bin/bash
#############################################
# ECR Cross-Account Policy 설정
# 본계정(497012402578) ECR → CA 계정(406223549139) 노드 pull 허용
# 사용: AWS_PROFILE=wonny bash scripts/ecr-cross-account.sh
#############################################

set +e  # 에러 무시하고 계속 진행

POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"AllowCrossAccountPull","Effect":"Allow","Principal":{"AWS":["arn:aws:iam::406223549139:role/goormgb-staging-apps-node-role","arn:aws:iam::406223549139:role/goormgb-staging-infra-node-role","arn:aws:iam::406223549139:role/goormgb-staging-monitoring-node-role"]},"Action":["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability"]}]}'

REPOS=(
  playball/web/api-gateway
  playball/web/auth-guard
  playball/web/order-core
  playball/web/queue
  playball/web/seat
  playball/ai/defense
  playball/ai/authz-adapter
  staging/playball/web/api-gateway
  staging/playball/web/auth-guard
  staging/playball/web/order-core
  staging/playball/web/queue
  staging/playball/web/seat
  staging/playball/ai/defense
  staging/playball/ai/authz-adapter
)

echo "=== ECR Cross-Account Policy 설정 ==="
echo "대상: ${#REPOS[@]}개 레포"
echo ""

for repo in "${REPOS[@]}"; do
  echo -n "$repo: "
  aws ecr set-repository-policy \
    --repository-name "$repo" \
    --policy-text "$POLICY" \
    --region ap-northeast-2 \
    --no-cli-pager \
    --query 'repositoryName' --output text 2>&1
done

echo ""
echo "=== 완료 ==="
