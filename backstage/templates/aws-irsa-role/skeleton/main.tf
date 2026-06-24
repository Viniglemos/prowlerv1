locals {
  role_name = "${{ values.roleName }}"
  subject   = "system:serviceaccount:${{ values.namespace }}:${{ values.serviceAccountName }}"
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
        "${{ values.oidcProviderArn }}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${{ values.oidcProviderUrl }}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${{ values.oidcProviderUrl }}:sub"
      values   = [local.subject]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.role_name
  description          = "Role IRSA usada pelo ServiceAccount ${{ values.serviceAccountName }} no namespace ${{ values.namespace }}."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "workload_permissions" {
  statement {
    sid    = "ExampleReadOnly"
    effect = "Allow"

    actions = [
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "workload_permissions" {
  name        = "${local.role_name}-permissions"
  description = "Permissoes AWS do workload ${{ values.componentId }}. Ajustar antes do apply."
  policy      = data.aws_iam_policy_document.workload_permissions.json
}

resource "aws_iam_role_policy_attachment" "workload_permissions" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.workload_permissions.arn
}
