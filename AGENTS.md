# AGENTS.md

## Project context

This repository implements the internal Prowler App platform for AWS security visibility on Kubernetes.

Current V1 scope:

- AWS only
- IAM
- S3
- CloudTrail
- internal-only runtime
- external Postgres
- Valkey in Kubernetes
- IRSA for AWS access

Kubernetes is the runtime model. GitLab is the delivery model. GitHub is the analysis and context-sharing model.

## Repository remote strategy

This project intentionally uses two git remotes with different purposes:

- `origin`: GitLab remote for delivery, operational changes, CI/CD, Terraform/Helm execution, and production-oriented repository history
- `github`: GitHub remote for rich documentation, architecture context, external review, ChatGPT analysis, and future agent-specialist reading

Expected working flow:

1. Keep detailed architecture and context updated for GitHub reading.
2. Use GitHub as the preferred remote for external AI review and broader analysis.
3. Bring suggested changes back into the local workspace.
4. Execute the actual implementation in this repository.
5. Push the final operationally relevant result to GitLab.

## Documentation policy

Documentation is split by audience:

- GitHub side:
  - detailed technical context
  - architecture rationale
  - agent-reading material
  - implementation reference
  - future roadmap context
- GitLab side:
  - only practical, low-noise, operationally relevant documentation

Do not treat all documentation equally.

When a change is made, decide whether it belongs to:

- detailed GitHub-facing documentation
- concise GitLab-facing operational documentation
- both

## Current architecture direction

```text
GitLab CI/CD
  -> validate Terraform/Helm
  -> run maintenance jobs
  -> deploy infrastructure/configuration
  -> must not be the normal scan runner

GitHub
  -> source of detailed docs
  -> architecture reading
  -> external review and AI analysis context

Terraform
  -> IRSA role
  -> target account scan role via StackSet model

Helm
  -> Prowler App API/UI/worker/worker beat
  -> optional MCP
  -> Valkey
  -> Services
  -> optional internal Gateway route
  -> optional API-trigger scan CronJobs

EKS/Kubernetes
  -> runtime for Prowler App

Postgres
  -> persistence for findings, providers, scans, application state

Valkey
  -> queue/cache/broker only
  -> not the primary persistence layer
```

## Runtime rules

- Prowler App runs in Kubernetes.
- GitLab must not run regular production scans.
- Scans are executed by the Prowler App manually or through validated API automation.
- Kubernetes cluster scanning is out of V1.
- Prowler UI must stay private.
- MCP stays optional and private-only.

## Current functional state

Expected current defaults:

- `nightlyScans.enabled=false`
- `mcp.enabled=false`
- `valkey.enabled=true`
- `valkey.persistence.enabled=false`

This means:

- no chart-driven scan schedule by default
- no MCP in production by default
- Valkey is active
- Valkey queue state is disposable if the pod is recreated

## Security rules

- Never commit credentials.
- Never print STS credentials.
- Never create static AWS keys for the app.
- EKS workloads must use IRSA.
- Trust policies must stay explicit.
- Keep least privilege as default.
- Do not expose the UI publicly.
- Do not expose MCP publicly.
- Do not add remediation automation unless explicitly requested.

## Scope boundaries

In V1:

- AWS IAM, S3 and CloudTrail only
- internal UI/API
- Postgres external
- Valkey in-cluster
- optional Teams/n8n integration

Not part of V1 unless explicitly requested:

- Kubernetes scanning
- public ingress
- multi-cloud
- remediation
- broad observability stack
- complex event-driven automations

## Documentation files that matter

GitHub-facing detailed context:

- `README.md`
- `docs/prowler-app-technical-reference.md`
- `docs/prowler-app-implementation.md`

Operational/Infra overview:

- `docs/prowler-app-infra-overview.md`

When changing architecture, pipeline, persistence, scans, remotes, or integration flow, update the relevant documentation in the same work cycle.

## Agent-specialist guidance

Future specialists working from GitHub context should understand:

- the repository has separate GitHub and GitLab purposes
- detailed docs are intentionally richer on the GitHub side
- GitLab delivery should stay low-noise
- V1 prioritizes controlled AWS visibility over feature breadth
- overengineering must be actively resisted
- worker memory pressure should be solved first by workload shaping and sizing, not by autoscaling alone

## Review expectations

When reviewing or proposing changes:

- prefer simple, operationally stable changes
- avoid introducing new platforms or control planes too early
- favor scan grouping and scheduling discipline over complex automation
- treat Postgres as persistence and Valkey as disposable broker state
- keep GitLab delivery clean and focused
- keep GitHub context rich enough for external analysis
