data "aws_iam_policy_document" "prowler_scan_permissions" {
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

resource "aws_iam_policy" "prowler_scan_permissions" {
  name        = "${var.role_name}-iam-s3-cloudtrail"
  description = "Read-only permissions for Prowler AWS scans limited to IAM, S3 and CloudTrail."
  policy      = data.aws_iam_policy_document.prowler_scan_permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "prowler_scan_permissions" {
  role       = aws_iam_role.prowler_audit.name
  policy_arn = aws_iam_policy.prowler_scan_permissions.arn
}
