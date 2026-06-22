data "aws_iam_policy_document" "trust_without_external_id" {
  count = var.external_id == "" ? 1 : 0

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
  }
}

data "aws_iam_policy_document" "trust_with_external_id" {
  count = var.external_id == "" ? 0 : 1

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

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values = [
        var.external_id,
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = "Role de auditoria read-only assumida pelo Prowler App a partir da role IRSA da conta tools."
  assume_role_policy   = var.external_id == "" ? data.aws_iam_policy_document.trust_without_external_id[0].json : data.aws_iam_policy_document.trust_with_external_id[0].json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

locals {
  managed_policy_arns = {
    readonly      = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    securityaudit = "arn:aws:iam::aws:policy/SecurityAudit"
  }
}

resource "aws_iam_role_policy_attachment" "managed_audit_policies" {
  for_each = local.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
