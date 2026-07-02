# Prowler App - Referencia Tecnica

## Objetivo

Documentar a implantacao tecnica atual do Prowler App em Kubernetes para futuras manutencoes, evolucoes e onboard de novos profissionais.

Este documento deve ser tratado como referencia operacional detalhada do ambiente.

## Escopo atual

- Runtime em Kubernetes.
- UI, API, worker e worker-beat do Prowler App.
- Postgres externo corporativo como camada persistente principal.
- Valkey no cluster como broker/cache de execucao.
- Acesso privado por Gateway interno.
- Acesso AWS por IRSA + `ProwlerScanRole`.
- Escopo funcional V1: AWS IAM, S3 e CloudTrail.

## Leitura recomendada

Para entender o ambiente com menor risco de omissao, a ordem recomendada e:

1. Este documento.
2. [README.md](/Users/viniciusgulartelemos/PROWLERAUDIT/README.md:1)
3. [helm/prowler-app/values.yaml](/Users/viniciusgulartelemos/PROWLERAUDIT/helm/prowler-app/values.yaml:1)
4. [.gitlab-ci.yml](/Users/viniciusgulartelemos/PROWLERAUDIT/.gitlab-ci.yml:1)
5. Terraform de IRSA e StackSet.

## Arquitetura

```text
Usuario na VPN
  -> Gateway privado
  -> Prowler UI
  -> Prowler API
  -> Postgres corporativo

Prowler worker / worker-beat
  -> Valkey
  -> Prowler API
  -> IRSA role
  -> sts:AssumeRole
  -> ProwlerScanRole nas contas AWS
```

## Componentes implantados

- `prowler-app-ui`: interface web.
- `prowler-app-api`: backend da aplicacao.
- `prowler-app-worker`: execucao assicrona de tarefas e scans.
- `prowler-app-worker-beat`: scheduler do backend.
- `prowler-app-valkey`: broker/cache local do ambiente.
- `ServiceAccount prowler-app`: identidade Kubernetes usada pelos pods com acesso AWS via IRSA.
- `HTTPRoute` privado: exposicao interna do host `prowler.educacional.app`.

O chart tambem suporta MCP e CronJobs de scans, mas ambos permanecem opcionais na fase atual.

## Persistencia

A persistencia do ambiente depende do Postgres externo.

Dados persistidos no Postgres:

- usuarios e autenticacao;
- providers cadastrados;
- scans;
- findings;
- configuracoes operacionais do app;
- estados internos do backend.

O Valkey nao e a camada de persistencia principal. No estado atual:

```yaml
valkey:
  persistence:
    enabled: false
```

Ele atende fila/broker/cache operacional e pode ser recriado sem perda do historico persistido no Postgres.

Implicacao operacional:

- scans, findings e configuracoes permanecem no Postgres;
- filas e estados transitorios do broker podem ser descartados com a recriacao do pod do Valkey;
- limpeza de fila nao equivale a perda de historico funcional do Prowler App.

## Fonte da verdade de configuracao

Arquivos principais:

- [README.md](/Users/viniciusgulartelemos/PROWLERAUDIT/README.md:1)
- [helm/prowler-app/values.yaml](/Users/viniciusgulartelemos/PROWLERAUDIT/helm/prowler-app/values.yaml:1)
- [.gitlab-ci.yml](/Users/viniciusgulartelemos/PROWLERAUDIT/.gitlab-ci.yml:1)
- [terraform/prowler-app-irsa/main.tf](/Users/viniciusgulartelemos/PROWLERAUDIT/terraform/prowler-app-irsa/main.tf:1)
- [terraform/prowler-target-stackset/main.tf](/Users/viniciusgulartelemos/PROWLERAUDIT/terraform/prowler-target-stackset/main.tf:1)

Remotes do repositório:

- `origin`: GitLab para execucao e entrega.
- `github`: GitHub para espelhamento, leitura contextual e apoio de pesquisa/review.

## Parametros principais do ambiente

Valores definidos hoje no Helm:

- host da aplicacao: `https://prowler.educacional.app`
- ServiceAccount com IRSA: `arn:aws:iam::751178672067:role/prowler-app-irsa`
- Postgres:
  - host: `toolss-educacional.cgeugefwnixv.us-east-1.rds.amazonaws.com`
  - database: `prowler`
  - user: `prd_prowler_user`
  - secret: `prowler-enviado-pelo-db`
- Secret principal do app: `prowler-app-secret`
- Gateway privado:
  - name: `gateway-privado`
  - namespace: `nginx-gateway-private`

Parametros de comportamento relevantes:

- `nightlyScans.enabled=false`
- `mcp.enabled=false`
- `valkey.enabled=true`
- `valkey.persistence.enabled=false`
- `worker.resources.limits.memory=4Gi`
- `workerBeat.enabled=true`

## Secrets requeridos

Secret de Postgres:

```text
Secret: prowler-enviado-pelo-db
Chaves:
- POSTGRES_ADMIN_PASSWORD
- POSTGRES_PASSWORD
```

Secret do app:

```text
Secret: prowler-app-secret
Chaves:
- AUTH_SECRET
- DJANGO_TOKEN_SIGNING_KEY
- DJANGO_TOKEN_VERIFYING_KEY
- DJANGO_SECRETS_ENCRYPTION_KEY
- NEO4J_PASSWORD (opcional no estado atual)
- PROWLER_APP_API_TOKEN (necessario apenas para scans via API/CronJob)
```

## Pipeline operacional

Modos principais da pipeline:

- `validate`: validacao Helm/Terraform.
- `irsa`: plano/aplicacao da role IRSA.
- `target_all`: StackSet para `ProwlerScanRole` nas contas AWS.
- `maintenance`: criacao/atualizacao de secrets Kubernetes.
- `deploy`: deploy/upgrade Helm do app.

Fluxo recomendado de manutencao:

1. Validar chart e Terraform.
2. Atualizar secrets via jobs de maintenance, se necessario.
3. Executar deploy Helm.
4. Validar UI, API e workers.
5. Validar scans no Prowler App.

Jobs mais relevantes:

- `update_postgres_secret`
- `update_prowler_app_secret`
- `deploy_app`
- `terraform_plan_irsa` / `terraform_apply_irsa`
- `terraform_plan_all_target_roles` / `terraform_apply_all_target_roles`

## Acesso AWS

Modelo adotado:

```text
Pod do Prowler
  -> ServiceAccount prowler-app
  -> IRSA na conta tools
  -> AssumeRole
  -> ProwlerScanRole nas contas alvo
```

Premissas:

- nao usar access keys estaticas;
- `ProwlerScanRole` distribuida via StackSet;
- sessao configurada para scans longos;
- onboarding de contas pelo proprio Prowler App apos a role existir.

## Limites do ambiente atual

- Escopo V1 restrito a AWS IAM, S3 e CloudTrail.
- `nightlyScans.enabled=false` por padrao.
- `mcp.enabled=false` por padrao.
- Neo4j desabilitado.
- Sem exposicao publica do app.
- Sem automacao de remediacao.

Observacoes de capacidade:

- o worker executa tarefas assicronas e pode sofrer pressao de memoria em scans grandes;
- autoscaling nao substitui o ajuste de memoria por pod quando um scan individual excede o limite;
- para cargas amplas, e preferivel quebrar scans por grupos de contas e janelas distintas.

## Mudancas futuras mais provaveis

Mudancas de infraestrutura:

- ajuste de `values.yaml` para recursos, gateway, host e toggles operacionais;
- rotacao de secrets via jobs de maintenance;
- upgrade de imagem `stable` para tag controlada;
- habilitacao de scans agendados;
- habilitacao futura de MCP privado;
- expansao de escopo para Kubernetes.

Mudancas de integracao:

- workflow n8n para resumo semanal;
- Teams canal privado;
- futuramente, agente conversacional privado via MCP.

## Checklist minimo para futuras alteracoes

Antes da mudanca:

1. Confirmar se a alteracao impacta Helm, secrets, Terraform ou integracoes.
2. Confirmar se ha mudanca de host, namespace, ServiceAccount ou segredo.
3. Validar se a alteracao mexe em persistencia de dados.

Durante a mudanca:

1. Rodar `validate`.
2. Atualizar secret via maintenance quando necessario.
3. Executar `deploy`.

Depois da mudanca:

1. Acessar UI em `https://prowler.educacional.app`.
2. Validar health da API.
3. Confirmar worker e worker-beat em execucao.
4. Executar scan manual de teste no escopo V1.

Obrigacao documental:

1. Atualizar este documento quando houver mudanca de arquitetura, persistencia, segredos, pipeline, remotes ou fluxo operacional.
2. Atualizar o `README.md` quando a mudanca alterar o entendimento geral do ambiente.
3. Atualizar o overview de Infra quando a mudanca impactar operacao, segredos, runtime ou dependencias externas.

## Referencias oficiais

- Prowler App overview: [docs.prowler.com/getting-started/products/prowler-app](https://docs.prowler.com/getting-started/products/prowler-app)
- Prowler App installation: [docs.prowler.com/getting-started/installation/prowler-app](https://docs.prowler.com/getting-started/installation/prowler-app)
- Prowler documentation index: [docs.prowler.com/introduction](https://docs.prowler.com/introduction)
- Amazon EKS IRSA: [docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- AWS CloudFormation StackSets with service-managed permissions: [docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html)
- Kubernetes Gateway API HTTPRoute: [gateway-api.sigs.k8s.io/api-types/httproute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
