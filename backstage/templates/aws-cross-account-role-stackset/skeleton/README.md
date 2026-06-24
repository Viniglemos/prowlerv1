# ${{ values.componentId }} - Cross-Account Role

Este template cria uma role igual em varias contas AWS usando CloudFormation StackSet service-managed.

## Quando usar

- Ferramentas centrais que precisam ler ou operar multiplas contas.
- Padroes de auditoria, inventario ou FinOps.
- Cenarios em que novas contas devem receber a role automaticamente.

## O que revisar

- Principal confiavel em `trustedPrincipalArn`.
- Lista de policies em `managedPolicyArns`.
- OUs alvo no recurso `aws_cloudformation_stack_set_instance`.
- Se a management account tambem precisa de role local.

