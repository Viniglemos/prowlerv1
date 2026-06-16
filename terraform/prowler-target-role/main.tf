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
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "view_only_access" {
  count      = var.attach_view_only_access ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}
