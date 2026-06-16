# Prowler App on Kubernetes

This repository packages the open-source Prowler App for internal Kubernetes usage.

The current direction is intentionally simple:

- Run the Prowler App in Kubernetes.
- Use the company-managed Postgres service.
- Deploy Valkey with the Helm chart.
- Keep the application reachable only through internal/VPN network paths.
- Trigger scheduled AWS and Kubernetes scans through the Prowler App API.
- Send a weekly security posture summary to Teams through n8n.
- Avoid custom report processing, daily alert noise, Grafana dashboards, and remediation automation.

## Repository Layout

```text
.
|-- README.md
|-- .gitlab-ci.yml
|-- terraform/
|   |-- prowler-app-irsa/
|   `-- prowler-target-role/
`-- helm/
    `-- prowler-app/
        |-- Chart.yaml
        |-- values.yaml
        `-- templates/
```

## Helm Chart

The chart is in `helm/prowler-app`.

It creates:

- Prowler API Deployment and Service.
- Prowler UI Deployment and Service.
- Prowler worker Deployment.
- Prowler worker beat Deployment.
- Prowler MCP Deployment and Service.
- Valkey Deployment, Service, and optional PVC.
- ServiceAccount.
- Optional private Gateway API `HTTPRoute`.
- Optional CronJobs that trigger scans through the Prowler App API.

It does not create:

- Postgres.
- S3 buckets.
- Public ingress.
- Grafana dashboards or alerts.
- n8n workflows.
- Teams webhooks.
- Custom Prowler scan containers.

## Runtime Model

```text
User on VPN
  -> private Kubernetes route/service
  -> Prowler UI
  -> Prowler API
  -> Postgres provided by company
  -> Valkey deployed by this chart

CronJob
  -> Prowler App API
  -> scan provider IDs configured in the App

Weekly summary agent
  -> read-only findings source
  -> n8n webhook/workflow
  -> private Teams channel
```

## Network Access

The app must remain private.

Default chart behavior:

- Services are `ClusterIP`.
- Gateway is disabled.
- No public hostname is configured.

Enable `gateway.enabled=true` only when the target Gateway/route is internal and reachable through the approved VPN/private network path.

## Postgres

Postgres is external to this chart.

Set:

```yaml
postgres:
  host: "<company-postgres-host>"
  existingSecret: "prowler-postgres-secret"
```

The secret must contain:

```text
POSTGRES_ADMIN_PASSWORD
POSTGRES_PASSWORD
```

## Valkey

Valkey is deployed by this chart because there is no company-managed Valkey service.

Default:

```yaml
valkey:
  enabled: true
  persistence:
    enabled: true
    size: 2Gi
```

## Nightly Scans

Scheduled scan triggers are disabled by default.

When enabled, the default split is:

```text
01:30 - Kubernetes provider
02:00 - AWS provider group A
04:00 - AWS provider group B
Timezone: America/Sao_Paulo
```

Configure real Prowler App provider IDs:

```yaml
nightlyScans:
  enabled: true
  auth:
    existingSecret: "prowler-app-api-token"
  jobs:
    - name: kubernetes
      enabled: true
      schedule: "30 1 * * *"
      providerIds:
        - "<kubernetes-provider-id>"
    - name: aws-group-a
      enabled: true
      schedule: "0 2 * * *"
      providerIds:
        - "<aws-provider-id-a>"
    - name: aws-group-b
      enabled: true
      schedule: "0 4 * * *"
      providerIds:
        - "<aws-provider-id-b>"
```

The API endpoint and body template are configurable in `values.yaml` because they should be confirmed against the deployed Prowler App API version before production use.

## S3 Export

Prowler App has its own integration/export path for S3. This repository no longer keeps custom scripts for generating, filtering, consolidating, or uploading raw Prowler reports.

If S3 export is required, configure it through the Prowler App/provider integration and keep the bucket private, encrypted, and scoped to the required prefix.

## Weekly Teams Summary

Weekly summaries should be sent to Teams through n8n, not as daily alerts.

Recommended flow:

```text
Prowler App
  -> read-only summary agent
  -> n8n webhook/workflow
  -> Teams private channel
```

## AWS Access Roles

Prowler App needs AWS roles to scan accounts without static keys.

The intended model is:

```text
Prowler App pod
  -> Kubernetes ServiceAccount
  -> IRSA role in the EKS account
  -> sts:AssumeRole
  -> ProwlerScanRole in each target AWS account
```

This repository includes Terraform for the two IAM layers:

- `terraform/prowler-app-irsa`: creates the IRSA role used by the Kubernetes ServiceAccount.
- `terraform/prowler-target-role`: creates the target account role assumed by the IRSA role.

The target role attaches AWS managed read-only policies:

- `SecurityAudit`
- `ViewOnlyAccess`

Do not create AWS access keys for the Prowler App. Use IRSA and assume-role only.

### Creation Order

1. Create the IRSA role in the EKS account.
2. Create `ProwlerScanRole` in each target account, trusting the IRSA role ARN.
3. Deploy the Helm chart with the IRSA annotation:

```yaml
serviceAccount:
  irsaRoleArn: "<prowler-app-irsa-role-arn>"
```

4. Configure AWS providers in the Prowler App using the target role ARNs:

```text
arn:aws:iam::<target-account-id>:role/ProwlerScanRole
```

The optional `external_id` variable can be enabled for the target role trust policy if required by the Prowler App provider configuration.

The summary should include:

- Critical and high finding counts.
- New or recurring critical risks.
- Most affected providers/accounts/services.
- Top recommended actions.
- Link to the internal Prowler App behind VPN.

The summary should not include:

- Raw findings.
- AWS credentials or temporary tokens.
- Full account inventory.
- Automatic remediation actions.
- Broad `@team` mentions by default.

The recommended cadence is weekly, after the nightly scan cycle has completed. Daily Teams messages should be avoided unless the project scope explicitly changes.

## Validation

Local validation:

```bash
helm lint helm/prowler-app

helm template prowler-app helm/prowler-app \
  --set app.authUrl=https://prowler-app.internal \
  --set postgres.host=postgres.company.internal \
  --set postgres.existingSecret=prowler-postgres-secret \
  --set app.secrets.authSecret=dummy-auth-secret \
  --set app.secrets.djangoTokenSigningKey=dummy-signing-key \
  --set app.secrets.djangoTokenVerifyingKey=dummy-verifying-key \
  --set app.secrets.djangoSecretsEncryptionKey=dummy-encryption-key
```

No AWS credentials are required for these validations.

Terraform validation:

```bash
terraform -chdir=terraform/prowler-app-irsa fmt
terraform -chdir=terraform/prowler-target-role fmt
terraform -chdir=terraform/prowler-app-irsa init -backend=false
terraform -chdir=terraform/prowler-app-irsa validate
terraform -chdir=terraform/prowler-target-role init -backend=false
terraform -chdir=terraform/prowler-target-role validate
```

## GitLab Variables

Helm deploy variables:

```text
KUBE_CONTEXT
KUBE_NAMESPACE
APP_AUTH_URL
POSTGRES_HOST
POSTGRES_EXISTING_SECRET
PROWLER_APP_SECRET_EXISTING_SECRET
PROWLER_APP_IRSA_ROLE_ARN
```

Terraform variables for the IRSA role:

```text
AWS_REGION
TF_INIT_ARGS
ALLOW_LOCAL_TF_STATE
TF_VAR_oidc_provider_arn
TF_VAR_oidc_provider_url
TF_VAR_target_account_ids
```

Example:

```text
TF_VAR_target_account_ids=["111111111111","222222222222"]
```

Terraform variables for the target account role:

```text
AWS_REGION
TF_INIT_ARGS
ALLOW_LOCAL_TF_STATE
TF_VAR_trusted_irsa_role_arn
TF_VAR_external_id
```

`TF_INIT_ARGS` defaults to `-backend=false` for validation. For real applies, configure the company-approved Terraform backend in GitLab before running manual apply jobs. The apply jobs block local state by default; use `ALLOW_LOCAL_TF_STATE=true` only for disposable tests.

## Security Notes

- Do not commit AWS credentials.
- Do not store AWS static keys in Kubernetes Secrets.
- Use IRSA for Prowler App pods.
- Scope target role trust to the Prowler App IRSA role.
- Keep the Prowler App private behind VPN/internal network controls.
- Keep Postgres credentials in Kubernetes Secrets or a company-approved secret system.
- Keep Gateway/Ingress disabled until the private route is approved.
- Do not enable alerts, remediation, or external integrations unless explicitly requested.
