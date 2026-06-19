locals {
  service_account_subject = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
  target_role_arns = length(var.target_account_ids) > 0 ? [
    for account_id in var.target_account_ids : "arn:aws:iam::${account_id}:role/${var.target_role_name}"
    ] : [
    "arn:aws:iam::*:role/${var.target_role_name}"
  ]
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        var.oidc_provider_arn,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values = [
        "sts.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values = [
        local.service_account_subject,
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = "Role IRSA usada pelo ServiceAccount do Prowler App no EKS da conta tools para assumir ProwlerScanRole nas contas alvo."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

data "aws_iam_policy_document" "assume_target_roles" {
  statement {
    sid    = "AssumeProwlerTargetRoles"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    resources = local.target_role_arns
  }
}

resource "aws_iam_policy" "assume_target_roles" {
  name        = "${var.role_name}-assume-target-roles"
  description = "Permite que a role IRSA do Prowler App assuma as roles ProwlerScanRole nas contas AWS alvo."
  policy      = data.aws_iam_policy_document.assume_target_roles.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "assume_target_roles" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.assume_target_roles.arn
}
