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
      for_each = var.external_id == "" ? {} : { external_id = var.external_id }

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
  description          = "Role de auditoria read-only assumida pelo Prowler App a partir da role IRSA da conta tools."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
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
