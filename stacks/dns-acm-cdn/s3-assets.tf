#############################################
# S3: Assets Bucket (playball-assets)
# CloudFront CDN origin
#############################################

resource "aws_s3_bucket" "assets" {
  bucket = "playball-assets"
  tags   = { Name = "playball-assets" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}
