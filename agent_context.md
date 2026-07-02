# AGENTS.md

This file mirrors the repository agent context and should stay aligned with `AGENTS.md`.

## Project context

This repository implements an open-source AWS security audit platform using Prowler App Community/Open Source.

The project is focused on AWS security posture visibility, initially for IAM, S3 and CloudTrail, with the Prowler App running inside Kubernetes from V1.

The project has one runtime execution model, one delivery model, and one analysis/context model:

1. GitLab CI/CD is used only for validation, Terraform plan/apply and Helm deployment.
2. Kubernetes/EKS is the runtime from V1: Prowler App API/UI/workers run as Deployments, Valkey runs in Helm, Postgres is external, and optional CronJobs can trigger scans through the Prowler App API.
3. GitHub is used as the richer analysis/documentation remote for AI review, architecture reading and future specialist-agent context.

Repository remote intent:

* `origin` -> GitLab for final operational delivery
* `github` -> GitHub for richer docs, external AI review and analysis-first workflow

The GitLab pipeline must not run Prowler scans as the normal operating model. Scans must be executed by the Prowler App in Kubernetes, either manually through the UI or automatically through the App API if the endpoint/body is validated.

The long-term goal is to provide controlled visibility of AWS security risks without generating noisy alerts or unnecessary anxiety for the team.

## Current architecture direction

The intended architecture is:

```text
GitLab CI/CD
  -> validate Terraform/Helm
  -> deploy infrastructure/configuration
  -> must not run regular Prowler scans

Terraform
  -> create IAM resources such as IRSA IAM role and target account scan role
  -> optionally deploy the Helm chart through helm_release

Helm
  -> create Kubernetes resources:
     - ServiceAccount with IRSA annotation
     - Prowler App API Deployment
     - Prowler App UI Deployment
     - Prowler App worker Deployment
     - Prowler App worker beat Deployment
     - Prowler MCP Deployment
     - Valkey Deployment and Service
     - Services
     - optional private Gateway API HTTPRoute
     - optional CronJobs that trigger scans through the Prowler App API
     - optional scheduled worker scaling CronJobs

EKS
  -> run Prowler App using IRSA
  -> keep API/UI/workers available internally
  -> optionally scale workers up during the scan window and down during the day

Postgres
  -> store Prowler App state and findings

Valkey
  -> support Prowler App async/background work

Prowler App
  -> provide internal UI/API for scans and findings
  -> optionally export to S3 through native App functionality if validated
```

## MVP scope

Provider:

* AWS

Services:

* IAM
* S3
* CloudTrail

Runtime:

* Prowler App runs in Kubernetes from the beginning.
* GitLab does not run scheduled or production scans.
* Scheduled automation should trigger Prowler App scans through the App API if validated.
* If scan API automation is not validated, scans may be started manually in the Prowler App.
* Kubernetes cluster scanning is not part of V1.

Persist only actionable findings:

* Status: `FAIL`
* Severity: `critical` and `high`

Storage:

* Company-managed Postgres is required for the Prowler App.
* Valkey is deployed by Helm because there is no company-managed Valkey service.
* S3 export is optional and should be configured through native Prowler App functionality if required.
* GitLab artifacts are not the long-term retention mechanism.

Visualization:

* Prowler App UI runs internally in EKS.
* The UI must not be publicly exposed.
* The App may be embedded later into Grafana using iframe/HTML panel only as visualization, without Grafana alerts.

## Out of scope for the current phase

Do not implement unless explicitly requested:

* Kubernetes cluster scanning
* Microsoft Teams alerts
* ClickUp automation
* Loki
* Grafana datasource dashboards
* Prometheus metrics
* Automatic remediation
* Full cloud resource inventory
* Multi-cloud implementation
* OpenAI/AI agent summarization
* Extra databases or queues beyond required Postgres and Valkey
* Kubernetes operators or CRDs
* Service mesh

## Security rules

* Never commit AWS credentials.
* Never print temporary STS credentials.
* Never create static AWS keys.
* Never store `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` or `AWS_SESSION_TOKEN` in Kubernetes Secrets.
* EKS workloads must use IRSA.
* GitLab pipeline should use OIDC or controlled temporary credentials where possible.
* Use least privilege.
* Keep S3 buckets private and encrypted.
* Scope S3 permissions to the reports bucket/prefix.
* Scope `sts:AssumeRole` to the target `ProwlerAuditRole`.
* Trust policies must be explicit.
* IRSA trust policy must be restricted to the expected namespace and ServiceAccount.
* Security findings must not fail the pipeline or Kubernetes jobs by default.
* Technical execution errors may fail the pipeline or Kubernetes jobs.

## Default Prowler App scope

Default services:

```bash
iam s3 cloudtrail
```

Default filters:

```bash
--status FAIL --severity critical high
```

Default output formats:

```bash
csv json-ocsf html
```

Expected configuration:

* AWS providers/accounts are configured in the Prowler App.
* Each AWS provider uses the target `ProwlerScanRole` / `ProwlerAuditRole` as agreed for the environment.
* Scan scope must remain IAM, S3 and CloudTrail in V1.
* Scan automation should call the Prowler App API only after endpoint and request body are validated against the deployed version.

## V1 and V2 scope boundary

V1 must deliver the complete Kubernetes-based Prowler App runtime for AWS scans:

* Helm chart for Prowler App API, UI, workers, worker beat, MCP, Valkey, ServiceAccount, Services and optional private route.
* IRSA role in the tools/EKS account.
* Target account role assumed by the Prowler App AWS provider configuration.
* AWS scan scope limited to IAM, S3 and CloudTrail.
* Postgres external to the chart.
* Valkey deployed by the chart.
* Optional CronJobs that trigger scans through the Prowler App API.
* Optional scheduled worker scaling: keep App online, scale worker capacity up during the scan window and down during the day.
* Optional S3 export through native Prowler App functionality if required and validated.

V2 must add only the Kubernetes cluster scan capability on top of the V1 infrastructure:

* RBAC for direct Kubernetes API read access.
* Kubernetes provider/cluster configuration in the Prowler App.
* Clear separation between AWS account scans and Kubernetes cluster scans.

Do not move V1 scans back to GitLab CI/CD.

## Kubernetes schedule

If automated scan triggering through the Prowler App API is enabled, it must run outside business hours and on weekends.

Weekday schedule:

```cron
0 19,0,5 * * 1-5
```

Meaning:

* Monday to Friday
* 19:00
* 00:00
* 05:00

Weekend schedule:

```cron
0 */5 * * 0,6
```

Meaning:

* Saturday and Sunday
* Every 5 hours

Timezone:

```text
America/Sao_Paulo
```

CronJobs that trigger Prowler App scans must be disabled by default in Helm values until the API endpoint/body and provider IDs are validated.

Scheduled worker scaling may be enabled independently from scan triggering. The intended V1 pattern is:

```text
23:30 -> scale worker replicas up for the scan window
07:00 -> scale worker replicas down for daytime idle usage
```

## Optional S3 export

S3 export is optional in V1 and should be configured through the Prowler App native integration if required.

Do not reintroduce custom S3 upload scripts unless explicitly requested.

## Repository conventions

Expected folders:

```text
.
├── AGENTS.md
├── README.md
├── .gitlab-ci.yml
├── config/
├── terraform/
│   ├── prowler-app-irsa/
│   └── prowler-target-role/
├── helm/
│   └── prowler-app/
└── docs/
```

## Terraform conventions

Terraform responsibilities:

* IRSA IAM role and policy
* Target account scan role and policy
* Optional Kubernetes namespace
* Optional Helm release deployment through `helm_release`

Terraform must not create unless explicitly requested:

* EKS cluster
* VPC
* Node groups
* OIDC provider
* Application-level Kubernetes YAML using raw `kubernetes_*` resources when Helm is already available

Preferred pattern: Terraform creates AWS IAM resources. Terraform may install the Helm chart through `helm_release`. Helm defines the Kubernetes workloads.

## Helm conventions

Helm chart responsibilities:

* ServiceAccount with IRSA annotation
* Prowler App API/UI/worker/worker beat/MCP Deployments
* Valkey Deployment, Service and optional PVC
* Internal Services
* Optional private Gateway API HTTPRoute
* Optional CronJobs that trigger scans through Prowler App API
* Optional scheduled worker scaling CronJobs
* ConfigMap and Secrets wiring

Helm must not hardcode:

* AWS account IDs
* ARNs
* Bucket names
* Company domains
* Grafana URLs

These values must come from `values.yaml`, Terraform variables or GitLab variables.

## Documentation expectations

Documentation must remain practical and operational.

When adding or changing functionality, update relevant docs:

* `README.md`
* `docs/prowler-app-implementation.md`
* `docs/prowler-app-technical-reference.md`
* `docs/prowler-app-infra-overview.md`

Documentation is intentionally split by audience:

* GitHub should carry the richer, more detailed technical context used by external AI review and future specialist agents
* GitLab should receive only the lean, operationally relevant documentation that avoids noise in the delivery repository

Documentation should explain:

* What runs where
* How AWS authentication works
* How IRSA works
* How findings are stored in Postgres
* How optional S3 export is configured through Prowler App
* How remotes are used
* Which documentation is GitHub-facing versus GitLab-facing
* How to test locally
* How to validate Helm
* How to validate Terraform
* How to deploy manually
* What remains company-specific

## Documentation review mode

When asked to review documentation, check for:

* Missing setup steps
* Incorrect architecture diagrams
* Unclear ownership between Terraform, Helm and GitLab
* Missing security warnings
* Missing IRSA explanation
* Missing required variables
* Missing validation commands
* Stale references to old scope
* References to services outside the MVP
* Overengineering
* Hardcoded sensitive values
* Inconsistent terminology
* Missing operational split between GitHub and GitLab documentation

## Overengineering guardrails

Keep the project focused.

Do not introduce extra systems unless explicitly requested.

Avoid:

* Queues
* Databases
* Custom controllers
* Operators
* Service mesh
* External Secrets
* Cert-manager
* AI agents unless explicitly requested
* Loki/Grafana datasource
* Teams webhooks
* ClickUp creation
* Automatic remediation
* Multi-cloud logic

The minimum runtime components are:

* Prowler App API/UI/worker/worker beat/MCP Deployments
* Optional Prowler App scan-trigger CronJobs
* Optional scheduled worker scaling CronJobs
* ServiceAccount using IRSA
* Internal Services
* Optional private Gateway API HTTPRoute
* External Postgres
* Valkey
* IAM role/policy for IRSA
* Target account role/policy

The minimum delivery components are:

* Docker image build/publish
* Helm validation/deployment
* Terraform validation/plan/apply

GitLab scan jobs are not part of the target architecture.
GitHub analysis material is part of the target collaboration workflow.

## Validation commands

When applicable, run or provide:

```bash
helm lint helm/prowler-app

helm template prowler-app helm/prowler-app \
  --set app.authUrl=https://prowler-app.internal \
  --set postgres.host=postgres.example.internal \
  --set postgres.existingSecret=prowler-postgres-secret \
  --set serviceAccount.irsaRoleArn=arn:aws:iam::123456789012:role/dummy-irsa-role

helm template prowler-app helm/prowler-app \
  --set app.authUrl=https://prowler-app.internal \
  --set postgres.host=postgres.example.internal \
  --set postgres.existingSecret=prowler-postgres-secret \
  --set scheduledScaling.enabled=true \
  --show-only templates/scheduled-scaling.yaml

terraform -chdir=terraform/prowler-app-irsa fmt
terraform -chdir=terraform/prowler-app-irsa init -backend=false
terraform -chdir=terraform/prowler-app-irsa validate

terraform -chdir=terraform/prowler-target-role fmt
terraform -chdir=terraform/prowler-target-role init -backend=false
terraform -chdir=terraform/prowler-target-role validate
```

## Working style

* Make small, reviewable changes.
* Prefer simple Bash, Python, Terraform and Helm.
* Do not refactor the entire repository without being asked.
* Do not implement future phases early.
* Explain how to test each change.
* Keep default values safe.
* Keep scan-trigger CronJobs, scheduled scaling and Gateway disabled by default unless explicitly requested.
* Stop after completing the requested phase.
