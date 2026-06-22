data "aws_organizations_organization" "current" {}

data "aws_iam_policy_document" "management_trust" {
  statement {
    sid    = "AllowTrustedTerraformPrincipals"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }
  }
}

locals {
  deployment_organizational_unit_ids = length(var.organizational_unit_ids) > 0 ? var.organizational_unit_ids : [
    data.aws_organizations_organization.current.roots[0].id,
  ]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Cria a role corporativa usada por pipelines Terraform para administrar recursos em contas da organizacao."
    Resources = {
      OrgTerraformDeploymentRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName           = var.role_name
          Description        = "Role corporativa assumida por pipelines Terraform autorizadas para criar e manter recursos nas contas AWS da organizacao."
          MaxSessionDuration = var.max_session_duration
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "AllowTrustedTerraformPrincipals"
                Effect = "Allow"
                Principal = {
                  AWS = var.trusted_principal_arns
                }
                Action = "sts:AssumeRole"
              },
            ]
          }
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/AdministratorAccess",
          ]
        }
      }
    }
    Outputs = {
      RoleArn = {
        Description = "ARN da role corporativa de execucao Terraform criada na conta."
        Value = {
          "Fn::GetAtt" = [
            "OrgTerraformDeploymentRole",
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
  description          = "Role corporativa assumida por pipelines Terraform autorizadas para criar e manter recursos na management account."
  assume_role_policy   = data.aws_iam_policy_document.management_trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "management_account_admin" {
  count = var.create_management_account_role ? 1 : 0

  role       = aws_iam_role.management_account[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_cloudformation_stack_set" "this" {
  name             = var.role_name
  description      = "StackSet corporativo para criar a role de execucao Terraform nas contas AWS da organizacao."
  permission_model = "SERVICE_MANAGED"
  capabilities = [
    "CAPABILITY_NAMED_IAM",
  ]
  template_body = local.template_body

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  operation_preferences {
    failure_tolerance_percentage = 10
    max_concurrent_percentage    = 25
    region_concurrency_type      = "PARALLEL"
  }
}

resource "aws_cloudformation_stack_set_instance" "organization" {
  stack_set_name = aws_cloudformation_stack_set.this.name
  region         = var.aws_region

  deployment_targets {
    organizational_unit_ids = local.deployment_organizational_unit_ids
  }

  operation_preferences {
    failure_tolerance_percentage = 10
    max_concurrent_percentage    = 25
    region_concurrency_type      = "PARALLEL"
  }
}
