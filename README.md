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
|   `-- prowler-target-stackset/
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
    existingSecret: "prowler-app-secret"
  groupA:
    name: aws-group-a
    enabled: true
    schedule: "0 18 * * 2,4"
    providerIds: "<aws-provider-id-a> <aws-provider-id-b>"
  groupB:
    name: aws-group-b
    enabled: true
    schedule: "0 20 * * 2,4"
    providerIds: "<aws-provider-id-c> <aws-provider-id-d>"
```

The API endpoint and body template are configurable in `values.yaml` because they should be confirmed against the deployed Prowler App API version before production use.

The default schedule runs twice a week, split into two nightly windows:

```text
Tuesday and Thursday, 18:00 - group A providers
Tuesday and Thursday, 20:00 - group B providers
Timezone: America/Sao_Paulo
activeDeadlineSeconds: 7200
```

`activeDeadlineSeconds` limits the Kubernetes trigger job to 2 hours. The actual Prowler scan duration is controlled by the Prowler App after the API request is accepted.

Only providers configured in `PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_A` and `PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_B` are triggered. The AWS roles can exist in every account, but the Prowler App will only scan the accounts/providers added to the app and included in these groups.

At deploy time, pass provider IDs as space-separated strings:

```text
PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_A=provider-id-1 provider-id-2
PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_B=provider-id-3 provider-id-4
```

The trigger token must exist in the configured secret as `PROWLER_APP_API_TOKEN`. The maintenance job stores it in `prowler-app-secret` when the GitLab variable `PROWLER_APP_API_TOKEN` is set.

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

This repository includes Terraform for the Prowler-specific IAM layers:

- `terraform/prowler-app-irsa`: creates the IRSA role used by the Kubernetes ServiceAccount.
- `terraform/prowler-target-stackset`: creates the target account scan role through AWS CloudFormation StackSets.

The preferred all-account deployment path does not require `OrgTerraformDeploymentRole` in each target account. It uses a service-managed CloudFormation StackSet from the AWS Organizations management account.

The target role attaches AWS managed audit/read-only policies to support V1 and the planned V2 expansion:

- `ReadOnlyAccess`
- `SecurityAudit`

The initial Prowler App scan configuration remains limited to AWS IAM, S3 and CloudTrail. Broader permissions are intentionally available so the team can expand coverage after V1 without replacing the cross-account role model.

Do not create AWS access keys for the Prowler App. Use IRSA and assume-role only.

Both the IRSA role and the target scan role default to a 4-hour maximum session duration:

```text
max_session_duration = 14400
```

This helps with longer scans. It does not bypass AWS role chaining limits, so the first Kubernetes test must confirm whether the Prowler App refreshes assumed-role credentials during long scans.

### Creation Order

1. Create the management Terraform state bucket if it does not exist.
2. Create the IRSA role in the EKS/tools account.
3. Create `ProwlerScanRole` in the target accounts through CloudFormation StackSets, trusting the IRSA role ARN.
4. Deploy the Helm chart with the IRSA annotation:

```yaml
serviceAccount:
  irsaRoleArn: "<prowler-app-irsa-role-arn>"
```

5. Configure AWS providers in the Prowler App using the target role ARNs:

```text
arn:aws:iam::<target-account-id>:role/ProwlerScanRole
```

The AWS Organizations management account must have service-managed CloudFormation StackSets enabled/trusted access available before `PIPELINE_MODE=target_all` can create roles across member accounts.

### Discover AWS Account IDs

Use the helper below from an authenticated AWS Organizations management/delegated-admin context:

```bash
bash tools/discover-aws-account-ids.sh
```

It generates local files under `generated/aws-organizations/`:

```text
accounts.json
accounts.txt
target-account-ids.auto.tfvars.example
```

`generated/` is ignored by Git. Do not commit account exports unless explicitly approved.

The helper only discovers account IDs for inventory and manual provider registration. It is not required by the `target_all` pipeline path. `TF_VAR_target_account_ids` is optional. When it is not set, the IRSA policy allows assuming `ProwlerScanRole` with the same role name in any AWS account, which matches the current requirement to onboard all accounts without exception.

For all-account onboarding, use `PIPELINE_MODE=target_all`. It applies `terraform/prowler-target-stackset` from the AWS Organizations management account and creates `ProwlerScanRole` through a service-managed CloudFormation StackSet. Because service-managed StackSets do not deploy into the management account itself, the same module also creates `ProwlerScanRole` locally in the management account by default.

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
terraform -chdir=terraform/prowler-target-stackset fmt
terraform -chdir=terraform/prowler-app-irsa init -backend=false
terraform -chdir=terraform/prowler-app-irsa validate
terraform -chdir=terraform/prowler-target-stackset init -backend=false
terraform -chdir=terraform/prowler-target-stackset validate
```

## GitLab Variables

The pipeline is intentionally not triggered by push or merge request events. Use **Run pipeline** or a controlled schedule.

Use `PIPELINE_MODE` to choose which part of the pipeline appears/runs:

```text
validate     Helm and Terraform validation only
create_management_state_bucket Create the management S3 backend bucket once
irsa         IRSA Terraform plan/apply jobs
target_all   Apply ProwlerScanRole to AWS Organizations accounts through CloudFormation StackSets
maintenance  Kubernetes Secret maintenance jobs
deploy       Helm deploy job
all          Show all jobs
```

Default:

```text
PIPELINE_MODE=validate
```

Variables for Kubernetes access and Helm deploy:

```text
PIPELINE_MODE
AGENT_CONTEXT
KUBE_NAMESPACE
POSTGRES_HOST
POSTGRES_PORT
POSTGRES_DATABASE
POSTGRES_USER
POSTGRES_EXISTING_SECRET
PROWLER_APP_EXISTING_SECRET
PROWLER_APP_IRSA_ROLE_ARN
PROWLER_APP_AUTH_URL
PROWLER_APP_GATEWAY_ENABLED
PROWLER_APP_GATEWAY_HOST
```

Variables for the manual `update_postgres_secret` maintenance job:

```text
POSTGRES_ADMIN_PASSWORD
POSTGRES_PASSWORD
```

Configure `POSTGRES_ADMIN_PASSWORD` and `POSTGRES_PASSWORD` as masked/protected GitLab variables. The job creates or updates the Kubernetes Secret named by `POSTGRES_EXISTING_SECRET`.

Variables for the manual `update_prowler_app_secret` maintenance job:

```text
AUTH_SECRET
DJANGO_TOKEN_SIGNING_KEY
DJANGO_TOKEN_VERIFYING_KEY
DJANGO_SECRETS_ENCRYPTION_KEY
VALKEY_PASSWORD
PROWLER_APP_API_TOKEN
```

Configure these variables as masked/protected GitLab variables. The job creates or updates the Kubernetes Secret named by `PROWLER_APP_EXISTING_SECRET`.

Do not put Postgres passwords in Helm values or committed files. Other environment-specific values should be kept in Helm values, Terraform inputs, or provided only at pipeline execution time when needed.

Terraform variables for manual plan/apply jobs:

```text
AWS_REGION
TF_INIT_ARGS
TF_VAR_oidc_provider_arn
TF_VAR_oidc_provider_url
TF_VAR_trusted_irsa_role_arn
MANAGEMENT_STATE_BUCKET
TF_VAR_max_session_duration
```

Variables for nightly scan trigger jobs:

```text
PROWLER_NIGHTLY_SCANS_ENABLED
PROWLER_NIGHTLY_SCANS_AUTH_SECRET
PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_A
PROWLER_NIGHTLY_PROVIDER_IDS_GROUP_B
```

For `PIPELINE_MODE=target_all`, the pipeline applies a service-managed CloudFormation StackSet from the AWS Organizations management account. The StackSet creates `ProwlerScanRole` in the organization scope, with no exclusion list because every active account must be scanned.

Run `PIPELINE_MODE=create_management_state_bucket` once with management account credentials if the management backend bucket does not exist yet. It creates the bucket defined by `MANAGEMENT_STATE_BUCKET`. Use a globally unique name, for example `state-management-prowler-<management-account-id>`. This job uses local Terraform state temporarily because a Terraform backend bucket must exist before it can be used as a backend.

Terraform state uses the company S3 backends configured in each module:

```text
terraform/prowler-app-irsa:
  bucket: state-tools
  region: us-east-1

terraform/prowler-target-stackset:
  bucket: MANAGEMENT_STATE_BUCKET
  region: us-east-1
```

State keys:

```text
terraform/prowler-app-irsa: prowler-app-irsa.tfstate
terraform/prowler-target-stackset: prowler-target-stackset.tfstate
```

`TF_INIT_ARGS` is optional and should only be used for company-approved extra `terraform init` arguments.

## Security Notes

- Do not commit AWS credentials.
- Do not store AWS static keys in Kubernetes Secrets.
- Use IRSA for Prowler App pods.
- Scope target role trust to the Prowler App IRSA role.
- Keep the Prowler App private behind VPN/internal network controls.
- Keep Postgres credentials in Kubernetes Secrets or a company-approved secret system.
- Keep Gateway/Ingress disabled until the private route is approved.
- Do not enable alerts, remediation, or external integrations unless explicitly requested.
