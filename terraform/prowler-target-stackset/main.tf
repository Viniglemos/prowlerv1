data "aws_organizations_organization" "current" {}

data "aws_iam_policy_document" "management_trust" {
  statement {
    sid    = "AllowProwlerAppIrsaAssumeRole"
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

locals {
  deployment_organizational_unit_ids = length(var.organizational_unit_ids) > 0 ? var.organizational_unit_ids : [
    data.aws_organizations_organization.current.roots[0].id,
  ]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Cria a role de auditoria read-only usada pelo Prowler App nas contas AWS alvo."
    Resources = {
      ProwlerScanRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName           = var.role_name
          Description        = "Role de auditoria read-only assumida pela IRSA do Prowler App na conta tools para executar scans AWS."
          MaxSessionDuration = var.max_session_duration
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "AllowProwlerAppIrsaAssumeRole"
                Effect = "Allow"
                Principal = {
                  AWS = var.trusted_irsa_role_arn
                }
                Action = "sts:AssumeRole"
              },
            ]
          }
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/ReadOnlyAccess",
            "arn:aws:iam::aws:policy/SecurityAudit",
          ]
        }
      }
    }
    Outputs = {
      RoleArn = {
        Description = "ARN da role de auditoria usada pelo Prowler App."
        Value = {
          "Fn::GetAtt" = [
            "ProwlerScanRole",
            "Arn",
          ]
        }
      }
    }
  })
}

resource "aws_iam_role" "management_account" {
  count = var.create_management_account_role ? 1 : 0

  name                 = var.role_name
  description          = "Role de auditoria read-only assumida pela IRSA do Prowler App na conta tools para executar scans AWS na management account."
  assume_role_policy   = data.aws_iam_policy_document.management_trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "management_account_readonly" {
  count = var.create_management_account_role ? 1 : 0

  role       = aws_iam_role.management_account[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "management_account_securityaudit" {
  count = var.create_management_account_role ? 1 : 0

  role       = aws_iam_role.management_account[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_cloudformation_stack_set" "this" {
  name             = var.stack_set_name
  description      = "StackSet corporativo para criar a ProwlerScanRole nas contas AWS alvo."
  permission_model = "SERVICE_MANAGED"
  capabilities = [
    "CAPABILITY_NAMED_IAM",
  ]
  template_body = local.template_body

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  managed_execution {
    active = true
  }

  operation_preferences {
    failure_tolerance_percentage = 10
    max_concurrent_percentage    = 25
    region_concurrency_type      = "PARALLEL"
  }
}

resource "aws_cloudformation_stack_set_instance" "organization" {
  stack_set_name            = aws_cloudformation_stack_set.this.name
  stack_set_instance_region = var.aws_region

  deployment_targets {
    organizational_unit_ids = local.deployment_organizational_unit_ids
  }

  operation_preferences {
    failure_tolerance_percentage = 10
    max_concurrent_percentage    = 25
    region_concurrency_type      = "PARALLEL"
  }
}
