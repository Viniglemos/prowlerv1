data "aws_iam_policy_document" "reports_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.reports.arn,
      "${aws_s3_bucket.reports.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowPipelineListReportsPrefix"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.pipeline_role_arn]
    }

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.reports.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.reports_prefix}/*"]
    }
  }

  statement {
    sid    = "AllowPipelineWriteFilteredReports"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.pipeline_role_arn]
    }

    actions = [
      "s3:AbortMultipartUpload",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]

    resources = ["${aws_s3_bucket.reports.arn}/${var.reports_prefix}/*"]
  }

  statement {
    sid    = "DenyReportWritesFromUnexpectedPrincipals"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:AbortMultipartUpload",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
    ]

    resources = ["${aws_s3_bucket.reports.arn}/${var.reports_prefix}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = [var.pipeline_role_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id
  policy = data.aws_iam_policy_document.reports_bucket.json
}
