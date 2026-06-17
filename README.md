# AWS Security Audit with Prowler Open Source

Open-source AWS security audit workflow using Prowler Community/Open Source.

Detailed project documentation, standards, and phase history should live in the internal GitLab/Backstage documentation space. This repository keeps only the executable project files and a minimal operating guide.

## MVP scope

Provider:

- AWS

Services:

- IAM
- S3
- CloudTrail

Persisted findings:

- Status: `FAIL`
- Severity: `critical` and `high`

Output formats:

- CSV
- JSON-OCSF / JSONL
- HTML

Out of scope for the MVP:

- Prowler Cloud
- Paid SaaS platforms
- Loki
- Grafana
- ClickUp automation
- Automatic remediation
- Full cloud resource inventory

## Repository layout

```text
.
|-- README.md
|-- .gitignore
|-- .gitlab-ci.yml
|-- config/
|   |-- excluded_accounts.txt
|   |-- included_accounts.txt
|   `-- prowler_services.yml
|-- scripts/
|   |-- assume_role.sh
|   |-- consolidate_reports.py
|   |-- discover_aws_accounts.sh
|   |-- generate_summary.py
|   |-- run_prowler_all_accounts.sh
|   |-- run_prowler_aws.sh
|   |-- start_prowler_dashboard.sh
|   `-- upload_reports_s3.sh
`-- terraform/
    |-- management-account/
    |   |-- main.tf
    |   |-- outputs.tf
    |   |-- s3-bucket.tf
    |   |-- s3-policy.tf
    |   |-- terraform.tfvars.example
    |   |-- variables.tf
    |   `-- versions.tf
    `-- target-account-role/
        |-- iam-policy.tf
        |-- iam-role.tf
        |-- main.tf
        |-- terraform.tfvars.example
        |-- variables.tf
        |-- outputs.tf
        `-- versions.tf
```

## Security rules

- Do not commit AWS credentials.
- Do not print temporary STS credentials.
- Do not create static AWS keys.
- Keep IAM permissions read-only unless explicitly approved.
- Keep S3 report buckets private and encrypted.
- Persist only filtered critical/high failed findings.
- Do not persist full unfiltered Prowler outputs in the MVP.
- Security findings should not fail the pipeline by themselves.
- Technical execution errors may fail the pipeline.

## Terraform

Target-account audit role:

```bash
cd terraform/target-account-role
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Management-account reports bucket:

```bash
cd terraform/management-account
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Do not commit real `terraform.tfvars` files.

## Local flow

Discover active AWS accounts:

```bash
scripts/discover_aws_accounts.sh
```

Run one account:

```bash
scripts/run_prowler_aws.sh 123456789012
```

Run all discovered accounts:

```bash
scripts/run_prowler_all_accounts.sh
```

Consolidate reports and generate summary:

```bash
python scripts/consolidate_reports.py
python scripts/generate_summary.py
```

Upload filtered reports to S3:

```bash
export REPORTS_BUCKET=security-audit-prowler-reports
scripts/upload_reports_s3.sh
```

Start local dashboard from filtered CSV outputs:

```bash
scripts/start_prowler_dashboard.sh
```

The dashboard binds to `127.0.0.1` by default and must not be exposed publicly without authentication.

## Output structure

Local outputs:

```text
output/<run-date>/pipeline-<pipeline-id>/
|-- summary.md
|-- consolidated-critical-high.csv
|-- consolidated-critical-high.jsonl
|-- accounts/
|   `-- <account-id>/
`-- logs/
```

S3 outputs:

```text
s3://security-audit-prowler-reports/
`-- aws/
    `-- YYYY/
        `-- MM/
            `-- DD/
                `-- pipeline-<pipeline-id>/
                    |-- summary.md
                    |-- consolidated-critical-high.csv
                    |-- consolidated-critical-high.jsonl
                    |-- accounts/
                    `-- logs/
```

## GitLab CI/CD

The pipeline follows the company pattern:

- `prepare`
- `validate`
- `plan`
- `apply`
- `destroy`

`DEPLOY_ENVIRONMENT` controls behavior:

- `VALIDATE`: validates Terraform/modules/scripts and discovers accounts.
- `IMPLEMENT`: validates, discovers accounts, then enables manual `apply` to scan, consolidate, summarize, and upload filtered reports.
- `destroy`: blocked guard job. Destruction is not supported for this MVP security audit pipeline.

Configure protected GitLab variables as needed:

- `DEPLOY_ENVIRONMENT`
- `AWS_REGION`
- `MANAGEMENT_ACCOUNT_ID`
- `MANAGEMENT_ROLE_ARN`
- `TARGET_ROLE_NAME`
- `REPORTS_BUCKET`
- `REPORTS_PREFIX`
- `UPLOAD_TO_S3`
- `PROWLER_STATUS_FILTER`
- `PROWLER_SEVERITY_FILTER`
- `MAX_PARALLEL_ACCOUNTS`

Defaults:

```text
TARGET_ROLE_NAME=ProwlerAuditRole
PROWLER_SERVICES="iam s3 cloudtrail"
PROWLER_STATUS_FILTER="FAIL"
PROWLER_SEVERITY_FILTER="critical high"
UPLOAD_TO_S3=true
REPORTS_PREFIX=aws
```

GitLab artifacts are used only to pass files between jobs and expire after one day. S3 remains the official long-term evidence repository.
