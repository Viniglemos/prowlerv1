# ${{ values.componentId }} - IRSA Role

Este template cria a base de uma role IRSA para um workload no EKS.

## O que revisar

- Permissoes AWS em `aws_iam_policy.workload_permissions`.
- Namespace e ServiceAccount.
- OIDC provider do cluster correto.
- Backend Terraform conforme padrao da empresa.

## Saida esperada

Use o output `service_account_annotation` no Helm chart:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "<role arn>"
```

