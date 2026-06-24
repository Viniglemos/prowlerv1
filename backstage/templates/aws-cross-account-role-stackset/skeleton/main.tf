data "aws_organizations_organization" "current" {}

locals {
  managed_policy_arns = [
    {% for policy_arn in values.managedPolicyArns %}
    "${{ policy_arn }}",
    {% endfor %}
  ]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Cria role cross-account padronizada para ${{ values.componentId }}."
    Resources = {
      CrossAccountRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName           = "${{ values.roleName }}"
          Description        = "Role cross-account usada por ${{ values.componentId }}."
          MaxSessionDuration = 3600
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "AllowTrustedPrincipalAssumeRole"
                Effect = "Allow"
                Principal = {
                  AWS = "${{ values.trustedPrincipalArn }}"
                }
                Action = "sts:AssumeRole"
              },
            ]
          }
          ManagedPolicyArns = local.managed_policy_arns
        }
      }
    }
    Outputs = {
      RoleArn = {
        Description = "ARN da role criada."
        Value       = { "Fn::GetAtt" = ["CrossAccountRole", "Arn"] }
      }
    }
  })
}

resource "aws_cloudformation_stack_set" "this" {
  name             = "${{ values.roleName }}"
  description      = "StackSet para criar role cross-account do componente ${{ values.componentId }}."
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = local.template_body

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
  stack_set_name = aws_cloudformation_stack_set.this.name
  region         = "${{ values.awsRegion }}"

  deployment_targets {
    organizational_unit_ids = [
      data.aws_organizations_organization.current.roots[0].id,
    ]
  }

  operation_preferences {
    failure_tolerance_percentage = 10
    max_concurrent_percentage    = 25
    region_concurrency_type      = "PARALLEL"
  }
}
