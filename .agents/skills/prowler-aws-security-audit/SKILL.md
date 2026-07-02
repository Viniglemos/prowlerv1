---

name: prowler-aws-security-audit
description: Use this skill for the Prowler AWS Security Audit project, including Prowler App on Kubernetes, GitLab CI/CD, GitHub-first architecture context, Terraform, IRSA, Helm, Valkey, external Postgres, optional Prowler App API scan triggers, documentation review, architecture review, overengineering review, and future roadmap planning. Do not use this skill for unrelated AWS tasks or generic Terraform projects.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Prowler AWS Security Audit Skill

## Purpose

Help build, review, document and evolve the Prowler AWS Security Audit project.

The skill must support:

* Implementation tasks
* Documentation tasks
* Architecture review
* Overengineering review
* Security review
* Future roadmap planning
* Local testing guidance
* Kubernetes/EKS deployment guidance

The project must remain focused on controlled AWS security visibility using Prowler App Community/Open Source running in Kubernetes.

The project also follows a dual-remote workflow:

* GitHub is used for richer technical context and external AI review
* GitLab is used for final delivery and operational repository history

## Project summary

This project implements AWS security auditing with Prowler App Community/Open Source.

The intended architecture is:

```text
GitLab CI/CD
  -> validates Helm/Terraform
  -> optionally deploys with Terraform/Helm
  -> must not run regular Prowler scans

Terraform
  -> creates IRSA IAM role/policy
  -> creates target account scan role/policy
  -> optionally installs the Helm chart through helm_release

Helm
  -> creates Kubernetes ServiceAccount with IRSA annotation
  -> creates Prowler App API/UI/worker/worker beat/MCP Deployments
  -> creates Valkey Deployment and Service
  -> creates internal Services
  -> creates optional private Gateway API HTTPRoute
  -> creates optional scan-trigger CronJobs through the Prowler App API
  -> creates optional scheduled worker scaling CronJobs

EKS
  -> runs Prowler App using IRSA
  -> keeps API/UI/workers available internally
  -> can scale workers up during the scan window and down during the day

Postgres
  -> stores Prowler App state and findings

Valkey
  -> supports Prowler App background work

Prowler App
  -> provides internal UI/API for scans and findings
  -> may export to S3 through native App functionality if validated
```

## Current MVP scope

Provider:

* AWS

Services:

* IAM
* S3
* CloudTrail

Runtime:

* Prowler App runs in Kubernetes from V1.
* GitLab CI/CD builds, validates and deploys only.
* GitLab CI/CD is not the production scan runner.
* Scans are started manually in Prowler App or automatically through the Prowler App API if validated.
* Kubernetes cluster scanning is V2 only.

Persist only:

* Status: `FAIL`
* Severity: `critical` and `high`

Reports:

* CSV
* JSON-OCSF
* HTML
* Markdown summary

Storage:

* Company-managed Postgres for Prowler App state and findings.
* Valkey deployed by Helm.
* Optional S3 export through native Prowler App functionality if required.

Visualization:

* Prowler App UI inside EKS.
* Internal-only access.
* Future Grafana iframe embedding supported by documentation/config.

## Out of scope unless explicitly requested

Do not implement:

* Kubernetes cluster scanning in V1
* Microsoft Teams alerts
* ClickUp automation
* Loki
* Grafana datasource dashboards
* Prometheus metrics
* Automatic remediation
* Full cloud resource inventory
* Multi-cloud implementation
* Extra databases or queues beyond required Postgres and Valkey
* Operators
* CRDs
* Service mesh
* AI summarization agent in GitLab delivery scope

## Core security rules

Always enforce these rules:

1. Do not commit credentials.
2. Do not print credentials.
3. Do not create static AWS keys.
4. Do not store AWS keys in Kubernetes Secrets.
5. EKS workloads must use IRSA.
6. GitLab should use OIDC or controlled temporary credentials where possible.
7. S3 buckets must be private and encrypted.
8. S3 permissions must be scoped to the reports bucket/prefix.
9. IRSA trust policy must be restricted to the expected namespace and ServiceAccount.
10. The scan role must assume `ProwlerAuditRole` in target accounts.
11. Security findings must not fail jobs by default.
12. Technical execution errors may fail jobs.
13. Do not persist unfiltered reports unless explicitly requested.
14. Do not expose the Prowler App UI publicly.
15. Keep least privilege as a default.

## Documentation split

The repository intentionally separates documentation by audience:

GitHub-facing documentation may include:

* detailed architecture context
* richer implementation notes
* future-agent reading material
* anti-overengineering guidance

GitLab-facing documentation should remain:

* practical
* low-noise
* deployment-focused
* operationally relevant

When updating docs, choose whether the change belongs to GitHub-only context, GitLab delivery context, or both.

## Default Prowler App scan scope

Default services:

```text
iam s3 cloudtrail
```

Default filters:

```text
status: FAIL
severity: critical high
```

Expected behavior:

* AWS providers/accounts are configured in Prowler App.
* Target AWS accounts use the agreed target scan role.
* V1 scan scope remains IAM, S3 and CloudTrail.
* Automated scans should use Prowler App API only after endpoint and request body are validated against the deployed version.

## Kubernetes execution model

The Kubernetes model is the only runtime model for V1. Prowler App stays online in Kubernetes, and GitLab does not run production scans.

### 1. Prowler App Deployments

Purpose:

* Keep Prowler App API, UI, workers, worker beat and MCP available internally.
* Use external company-managed Postgres.
* Use Valkey deployed by Helm.
* Use IRSA for AWS access from the App.
* Keep services private and reachable only through approved internal/VPN routes.

### 2. Optional Scan Trigger CronJobs

Purpose:

* Trigger Prowler App scans through the App API if the endpoint/body is validated.
* Run outside business hours.
* Avoid making GitLab the scan runner.
* Remain disabled by default until provider IDs and API token are configured.

Expected schedules:

Weekdays:

```cron
0 19,0,5 * * 1-5
```

Weekends:

```cron
0 */5 * * 0,6
```

Timezone:

```text
America/Sao_Paulo
```

Requirements:

* Call the Prowler App API.
* Use `concurrencyPolicy: Forbid`.
* Have low job history limits.
* Be disabled by default.
* Do not send alerts yet.

### 3. Scheduled Worker Scaling

Purpose:

* Keep the App online 24x7.
* Increase worker replicas before the nightly scan window.
* Reduce worker replicas during daytime idle usage.
* Avoid introducing KEDA/operators for V1.

Requirements:

* Use minimal Kubernetes RBAC for `deployments/scale` only on the Prowler worker Deployment.
* Be disabled by default.
* Default pattern: scale up around 23:30 and scale down around 07:00 in `America/Sao_Paulo`.

### V2. Kubernetes Cluster Scan

Purpose:

* Add direct Kubernetes cluster scanning after V1 is already running.
* Reuse the V1 App/Helm/IRSA/Postgres/Valkey foundation where possible.

Requirements:

* Do not include cluster scan in V1.
* Add explicit Kubernetes RBAC only when V2 starts.
* Separate AWS account scan outputs from Kubernetes cluster scan outputs.
* Keep AWS scope as IAM, S3 and CloudTrail unless the project scope changes explicitly.

## IRSA model

IRSA must be created through Terraform.

Terraform module:

```text
terraform/prowler-app-irsa/
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

Terraform must create:

* IAM role for IRSA
* IAM policy for Prowler App Kubernetes workload
* Role policy attachment
* Trust policy for EKS OIDC provider
* Outputs for Helm/Terraform deployment

Trust policy must allow:

```text
sts:AssumeRoleWithWebIdentity
```

Trust policy must restrict subject to:

```text
system:serviceaccount:<namespace>:<service_account_name>
```

Trust policy must validate audience:

```text
sts.amazonaws.com
```

IRSA role permissions:

* `sts:AssumeRole` to target `ProwlerAuditRole`
* Optional AWS Organizations discovery permissions

Do not create the EKS cluster or OIDC provider unless explicitly requested.

## Terraform Kubernetes deployment model

Preferred pattern:

```text
Terraform uses helm_release to install the Helm chart.
Helm defines the Kubernetes workloads.
```

Optional Terraform module:

```text
terraform/kubernetes-prowler/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md
```

This module may:

* create Kubernetes namespace
* install/update Helm release
* pass IRSA role ARN to Helm
* pass image repository/tag to Helm
* enable/disable scan-trigger CronJobs
* enable/disable scheduled worker scaling
* configure optional private Gateway API route

Do not convert all Helm templates into raw Terraform `kubernetes_*` resources unless explicitly requested.

## Helm chart model

Helm chart path:

```text
helm/prowler-app/
```

Expected files:

```text
helm/prowler-app/Chart.yaml
helm/prowler-app/values.yaml
helm/prowler-app/templates/_helpers.tpl
helm/prowler-app/templates/serviceaccount.yaml
helm/prowler-app/templates/configmap.yaml
helm/prowler-app/templates/api.yaml
helm/prowler-app/templates/ui.yaml
helm/prowler-app/templates/worker.yaml
helm/prowler-app/templates/worker-beat.yaml
helm/prowler-app/templates/mcp.yaml
helm/prowler-app/templates/valkey.yaml
helm/prowler-app/templates/gateway.yaml
helm/prowler-app/templates/cronjob-trigger.yaml
helm/prowler-app/templates/scheduled-scaling.yaml
```

Safe defaults:

```yaml
nightlyScans:
  enabled: false

scheduledScaling:
  enabled: false

gateway:
  enabled: false
```

Must support:

* Prowler App image repository/tag for API, UI, MCP and Valkey
* ServiceAccount annotations
* IRSA role ARN
* external Postgres host and secret
* Valkey in Helm
* optional Prowler App scan-trigger CronJobs
* optional scheduled worker scaling
* private Gateway API HTTPRoute
* allowed frame ancestor for future Grafana iframe
* future V2 Kubernetes cluster scan enablement without changing the V1 foundation

## Documentation review mode

Use this mode when the user asks to review docs, create docs, find documentation gaps, or prepare documentation for future project phases.

Check for:

* Missing architecture explanation
* Missing responsibilities between GitLab, Terraform, Helm and EKS
* Missing IRSA explanation
* Missing AWS permission explanation
* Missing Postgres/Valkey explanation
* Missing optional Prowler App S3 export explanation
* Missing Prowler App UI/API/worker explanation
* Missing Grafana iframe explanation
* Missing local testing commands
* Missing Kubernetes testing commands
* Missing Terraform validation commands
* Missing Helm validation commands
* Missing troubleshooting
* Missing security warnings
* Stale references to old architecture
* References to disabled/out-of-scope features
* Hardcoded real values
* Overengineering

Documentation should be practical and copy-paste friendly.

## Overengineering review mode

Use this mode when the user asks if something is too complex.

Flag as overengineering unless explicitly justified:

* Kubernetes cluster scanning in V1
* Teams alerts in MVP
* ClickUp creation in MVP
* Loki/Grafana datasource in MVP
* AI summarization in MVP
* Extra databases or queues beyond required Postgres and Valkey
* Operators
* CRDs
* Full resource inventory
* Multi-cloud expansion
* Automatic remediation
* Service mesh
* Complex event-driven workflows

Acceptable for the current scope:

* Docker image
* GitLab CI/CD
* Terraform IRSA role
* Terraform helm_release deployment
* Helm chart
* Prowler App Deployments
* Valkey in Helm
* External Postgres
* Optional scan-trigger CronJobs through Prowler App API
* Optional scheduled worker scaling
* Internal Services/private Gateway route
* Optional S3 export through Prowler App
* Documentation for future Grafana iframe

## Implementation phases

When implementing, work in phases.

### Phase 0 — Repository baseline

Create/update:

* `AGENTS.md`
* `README.md`
* `.gitignore`
* `config/prowler_services.yml`
* basic docs

Do not implement runtime yet.

### Phase 1 — Prowler App Kubernetes foundation

Create/update:

* Helm chart for Prowler App
* Terraform for IRSA
* Terraform for target account role
* Postgres/Valkey configuration

Validate:

* Helm lint/template
* Terraform fmt/validate
* No GitLab scan jobs

### Phase 2 — GitLab CI/CD baseline

Create/update:

* `.gitlab-ci.yml`

Support:

* validate
* helm lint
* optional manual deploy
* Terraform validation/plan/apply

Do not add regular scan jobs to the pipeline. Scans run through Prowler App.

### Phase 3 — Terraform target account role

Create/update:

* `terraform/prowler-target-role/`

Create:

* target role trusted by the Prowler App IRSA role
* custom read-only policy limited to IAM, S3 and CloudTrail
* 4-hour max session duration

### Phase 4 — Terraform IRSA

Create/update:

* `terraform/prowler-app-irsa/`

Create:

* IRSA role
* IRSA policy
* trust policy
* outputs

### Phase 5 — Helm chart

Create/update:

* `helm/prowler-app/`

Create:

* ServiceAccount
* Prowler App API/UI/worker/worker beat/MCP Deployments
* Valkey Deployment/Service/PVC
* Services
* optional private Gateway API HTTPRoute
* optional scan-trigger CronJobs through App API
* optional scheduled worker scaling CronJobs

### Phase 6 — Prowler App scan automation

Create/update:

* `helm/prowler-app/templates/cronjob-trigger.yaml`
* values for provider IDs/API token secret

Only enable after validating the Prowler App scan endpoint/body against the deployed version. If this is not validated, scans remain manual in the App.

### Phase 7 — Terraform Kubernetes deployment

Create/update only if explicitly requested:

* `terraform/kubernetes-prowler/`

Use:

* `helm_release`

Do not create raw Kubernetes resources unless needed.

### Phase 8 — Documentation finalization

Create/update:

* `docs/kubernetes-architecture.md`
* `docs/aws-permissions.md`
* `docs/grafana-embed.md`
* `docs/remediation-workflow.md`
* `docs/future-roadmap.md`

## Required validation commands

Use or provide relevant commands:

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

## Kubernetes manual test commands

Provide examples when relevant:

```bash
kubectl create namespace security-audit

helm upgrade --install prowler-app helm/prowler-app \
  --namespace security-audit \
  --set app.authUrl=https://<internal-host> \
  --set postgres.host=<postgres-host> \
  --set postgres.existingSecret=prowler-postgres-secret \
  --set app.secrets.create=false \
  --set app.secrets.existingSecret=prowler-app-secret \
  --set serviceAccount.irsaRoleArn="<irsa-role-arn>"

kubectl create job \
  --from=cronjob/prowler-app-worker-scale-up \
  prowler-app-scale-up-test \
  -n security-audit

kubectl logs job/prowler-app-scale-up-test -n security-audit
```

IRSA test example:

```bash
kubectl run aws-identity-test \
  --rm -it \
  --restart=Never \
  --namespace security-audit \
  --image=amazon/aws-cli:latest \
  --serviceaccount=prowler-app \
  -- sts get-caller-identity
```

## Response format after work

Always end implementation or review tasks with:

```text
Phase completed: <phase or review name>

Files created:
- ...

Files modified:
- ...

What changed:
- ...

How to test:
- ...

Risks or gaps:
- ...

Next recommended step:
- ...
```

## Common commands from user

If the user says:

```text
Review the project
```

Inspect architecture, security, docs and overengineering risks.

If the user says:

```text
Find documentation gaps
```

Use Documentation Review Mode.

If the user says:

```text
Check overengineering
```

Use Overengineering Review Mode.

If the user says:

```text
Continue to next phase
```

Continue only one phase.

If the user says:

```text
Make Kubernetes via Terraform
```

Implement or update `terraform/kubernetes-prowler` using `helm_release` only if explicitly requested.

If the user says:

```text
Add IRSA via Terraform
```

Implement or update `terraform/prowler-app-irsa`.

## Do not do

Do not:

* Add real AWS credentials.
* Add real account IDs.
* Add real ARNs.
* Add real bucket names.
* Add real company domains.
* Add Teams alerts without approval.
* Add ClickUp without approval.
* Add Loki/Grafana datasource without approval.
* Add automatic remediation.
* Add resource inventory.
* Expose Prowler App UI publicly.
* Persist unfiltered reports.
* Replace Helm with raw Terraform Kubernetes resources unless explicitly requested.
* Implement all phases at once unless explicitly requested.
