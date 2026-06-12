data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowConfiguredPrincipalAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }

    dynamic "condition" {
      for_each = var.external_id == null || var.external_id == "" ? [] : [var.external_id]

      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "prowler_audit" {
  name                 = var.role_name
  description          = "Read-only cross-account role for Prowler Open Source AWS security audits."
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}
