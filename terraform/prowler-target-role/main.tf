data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "AWS"
      identifiers = [
        var.trusted_irsa_role_arn,
      ]
    }

    dynamic "condition" {
      for_each = var.external_id == "" ? [] : [var.external_id]

      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values = [
          condition.value,
        ]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

data "aws_iam_policy_document" "scan_permissions" {
  statement {
    sid    = "StsIdentity"
    effect = "Allow"

    actions = [
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "IamReadOnly"
    effect = "Allow"

    actions = [
      "iam:GenerateCredentialReport",
      "iam:GenerateServiceLastAccessedDetails",
      "iam:Get*",
      "iam:List*",
      "iam:SimulateCustomPolicy",
      "iam:SimulatePrincipalPolicy",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "S3ReadOnly"
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CloudTrailReadOnly"
    effect = "Allow"

    actions = [
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "scan_permissions" {
  name        = "${var.role_name}-iam-s3-cloudtrail"
  description = "Read-only permissions for Prowler AWS scans limited to IAM, S3 and CloudTrail."
  policy      = data.aws_iam_policy_document.scan_permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "scan_permissions" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.scan_permissions.arn
}
