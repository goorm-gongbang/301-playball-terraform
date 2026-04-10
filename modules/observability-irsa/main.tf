#############################################
# Observability IRSA Module
# Loki / Tempo / Thanos → S3 object storage
#############################################

data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "ObservabilityBucketsList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [for b in var.s3_bucket_names : "arn:aws:s3:::${b}"]
  }

  statement {
    sid    = "ObservabilityBucketsObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts"
    ]
    resources = [for b in var.s3_bucket_names : "arn:aws:s3:::${b}/*"]
  }
}

resource "aws_iam_policy" "s3" {
  name        = "${var.owner_name}-${var.environment}-monitoring-s3"
  description = "IRSA policy for ${var.environment} Loki/Tempo/Thanos object storage"
  policy      = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "assume" {
  for_each = var.service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = var.service_accounts

  name               = "${var.owner_name}-${var.environment}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

  tags = {
    Name    = "${var.owner_name}-${var.environment}-${each.key}"
    Purpose = "observability-s3-irsa"
  }
}

resource "aws_iam_role_policy_attachment" "s3" {
  for_each = aws_iam_role.this

  role       = each.value.name
  policy_arn = aws_iam_policy.s3.arn
}
