resource "aws_s3_bucket" "media_bucket" {
  bucket = var.media_s3_bucket

  tags = merge(var.additional_tags, {
    Name = "hummingbird-media-bucket"
  })
}

resource "aws_s3_bucket_ownership_controls" "media_bucket_ownership_controls" {
  bucket = aws_s3_bucket.media_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "media_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.media_bucket_ownership_controls]

  bucket = aws_s3_bucket.media_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "media_bucket_public_access_block" {
  bucket = aws_s3_bucket.media_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "media_s3_access_policy" {
  name = "media-s3-access-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.media_bucket.arn,
          "${aws_s3_bucket.media_bucket.arn}/*",
        ],
      },
    ]
  })
}
