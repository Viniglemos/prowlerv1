# Prowler App - Overview Objetivo para Infra

## Objetivo

Disponibilizar o Prowler App em Kubernetes com persistencia de dados, acesso privado e modelo padrao de manutencao para futuros ajustes de Infra.

## Resultado entregue

- Prowler App operacional em Kubernetes.
- Persistencia garantida pelo Postgres corporativo externo.
- Valkey implantado no cluster para fila/cache operacional.
- Exposicao apenas por rota interna `https://prowler.educacional.app`.
- Acesso AWS sem chaves estaticas, usando IRSA e `ProwlerScanRole`.
- Pipeline GitLab separada por validacao, infra, maintenance e deploy.
- Documentacao tecnica e operacional mantida no proprio repositório.

## O que roda

```text
UI
API
Worker
Worker Beat
Valkey
Gateway privado
```

Estado funcional atual:

- scans agendados pelo chart: desligados
- MCP: desligado
- Valkey: ligado
- persistencia do Valkey: desligada

## O que e persistente

- Persistente: Postgres externo.
- Nao persistente como base de historico: Valkey.

O historico de configuracoes, scans e findings fica no Postgres.

## Entradas de Infra que precisam existir

- Kubernetes com acesso ao namespace do app.
- Gateway privado interno.
- Postgres corporativo acessivel pelo cluster.
- Secret de Postgres no namespace do app.
- Secret principal do Prowler App no namespace do app.
- Role IRSA criada na conta tools.
- `ProwlerScanRole` criada nas contas AWS alvo.

## Segredos obrigatorios

```text
prowler-enviado-pelo-db
- POSTGRES_ADMIN_PASSWORD
- POSTGRES_PASSWORD

prowler-app-secret
- AUTH_SECRET
- DJANGO_TOKEN_SIGNING_KEY
- DJANGO_TOKEN_VERIFYING_KEY
- DJANGO_SECRETS_ENCRYPTION_KEY
```

Opcional no estado atual:

```text
- PROWLER_APP_API_TOKEN
- NEO4J_PASSWORD
```

## Operacao padrao

1. Atualizar secrets pela pipeline de maintenance quando necessario.
2. Executar deploy Helm pela pipeline.
3. Validar UI, API e workers.
4. Configurar ou revisar providers AWS pelo Prowler App.
5. Executar scans manualmente no App ou, no futuro, habilitar agendamento.

## Limites da fase atual

- Escopo funcional restrito a AWS IAM, S3 e CloudTrail.
- Sem exposicao publica.
- Sem scan de Kubernetes na V1.
- Sem MCP habilitado em producao.
- Sem remediacao automatica.

## Quando Infra provavelmente vai atuar de novo

- troca de host, gateway ou namespace;
- rotacao de secrets;
- ajuste de recursos do workload;
- upgrade de versao/imagens;
- liberacao de scans agendados;
- onboarding de novas contas AWS no modelo IRSA + StackSet;
- futura habilitacao de integracoes como n8n ou MCP privado.

## Regra de documentacao

Mudancas futuras de Infra devem atualizar a documentacao no mesmo ciclo da alteracao.

Arquivos minimos a revisar:

- [README.md](/Users/viniciusgulartelemos/PROWLERAUDIT/README.md:1)
- [docs/prowler-app-technical-reference.md](/Users/viniciusgulartelemos/PROWLERAUDIT/docs/prowler-app-technical-reference.md:1)
- [docs/prowler-app-infra-overview.md](/Users/viniciusgulartelemos/PROWLERAUDIT/docs/prowler-app-infra-overview.md:1)

## Links de referencia

- Prowler App overview: [docs.prowler.com/getting-started/products/prowler-app](https://docs.prowler.com/getting-started/products/prowler-app)
- Prowler App installation: [docs.prowler.com/getting-started/installation/prowler-app](https://docs.prowler.com/getting-started/installation/prowler-app)
- Amazon EKS IRSA: [docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- AWS CloudFormation StackSets: [docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html)
- Kubernetes Gateway API HTTPRoute: [gateway-api.sigs.k8s.io/api-types/httproute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
