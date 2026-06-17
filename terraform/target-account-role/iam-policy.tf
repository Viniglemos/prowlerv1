locals {
  managed_policy_arns = toset([
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess",
  ])
}

resource "aws_iam_role_policy_attachment" "managed_read_only" {
  for_each = local.managed_policy_arns

  role       = aws_iam_role.prowler_audit.name
  policy_arn = each.value
}
