# Prowler App on Kubernetes

This repository packages the open-source Prowler App for internal Kubernetes usage.

The current direction is intentionally simple:

- Run the Prowler App in Kubernetes.
- Use the company-managed Postgres service.
- Deploy Valkey with the Helm chart.
- Keep the application reachable only through internal/VPN network paths.
- Trigger scheduled AWS scans through the Prowler App API.
- Scan scope for this phase: AWS IAM, S3, and CloudTrail only.
- Send a weekly security posture summary to Teams through n8n.
- Avoid custom report processing, daily alert noise, Grafana dashboards, and remediation automation.

## Repository Layout

```text
.
|-- README.md
|-- .gitlab-ci.yml
|-- integrations/
|   `-- n8n/
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
  -> scan AWS provider IDs configured in the App

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
02:00 - AWS provider group A
04:00 - AWS provider group B
Timezone: America/Sao_Paulo
```

Configure real AWS provider IDs from Prowler App:

```yaml
nightlyScans:
  enabled: true
  auth:
    existingSecret: "prowler-app-api-token"
  jobs:
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

Kubernetes is the runtime platform for the Prowler App in this phase. Kubernetes resources are not part of the scan scope yet.

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

The optional workflow template is in `integrations/n8n`. It must be configured with n8n-side environment variables and must not store tokens or webhook URLs in Git.

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

The target role uses a custom read-only policy limited to the V1 scope:

- IAM
- S3
- CloudTrail
- STS caller identity

Do not create AWS access keys for the Prowler App. Use IRSA and assume-role only.

Both the IRSA role and the target scan role default to a 4-hour maximum session duration:

```text
max_session_duration = 14400
```

This helps with longer scans. It does not bypass AWS role chaining limits, so the first Kubernetes test must confirm whether the Prowler App refreshes assumed-role credentials during long scans.

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
  --set postgres.existingSecret=prowler-postgres-secret
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

The pipeline is intentionally not triggered by push or merge request events. Use **Run pipeline** or a controlled schedule.

Only this variable should be persisted in GitLab CI/CD variables for the Helm deploy:

```text
POSTGRES_EXISTING_SECRET
```

Other environment-specific values should be kept in Helm values, Terraform inputs, or provided only at pipeline execution time when needed.

Terraform variables for manual plan/apply jobs:

```text
AWS_REGION
TF_INIT_ARGS
ALLOW_LOCAL_TF_STATE
TF_VAR_oidc_provider_arn
TF_VAR_oidc_provider_url
TF_VAR_target_account_ids
TF_VAR_trusted_irsa_role_arn
TF_VAR_external_id
TF_VAR_max_session_duration
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
