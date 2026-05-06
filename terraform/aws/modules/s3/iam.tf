resource "aws_iam_user" "this" {
  name = "${var.project}_${var.purpose}"

  tags = {
    Name = "${var.project}_${var.purpose}"
  }
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowBucketLevelActions"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [aws_s3_bucket.this.arn]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = ["${var.allowed_ip}/32"]
    }
  }

  statement {
    sid    = "AllowObjectLevelActions"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = ["${var.allowed_ip}/32"]
    }
  }
}

resource "aws_iam_user_policy" "this" {
  name   = "${var.project}_${var.purpose}"
  user   = aws_iam_user.this.name
  policy = data.aws_iam_policy_document.this.json
}
