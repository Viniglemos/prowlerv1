# n8n Weekly Summary Integration

This folder contains the optional n8n integration for the weekly Prowler App summary.

The workflow must run where it can reach:

- the internal Prowler App API through VPN/private network;
- the selected summary agent endpoint;
- the Microsoft Teams incoming webhook or Teams connector endpoint.

No secrets belong in this repository.

## Required n8n environment variables

```text
PROWLER_API_BASE_URL=https://<internal-prowler-host>/api/v1
PROWLER_API_TOKEN=<token-created-for-read-only-summary-access>
PROWLER_APP_URL=https://<internal-prowler-host>
SUMMARY_AGENT_URL=<internal-or-approved-agent-endpoint>
SUMMARY_AGENT_TOKEN=<agent-token>
TEAMS_WEBHOOK_URL=<teams-webhook-url>
```

## Workflow

Import `weekly-summary.workflow.json` into n8n.

The default schedule is:

```text
Monday 08:00
Timezone: America/Sao_Paulo
```

## Data Source

Prefer the Prowler App API as the source of findings.

Use direct Postgres access only if the API cannot provide the required read-only data, and only with a dedicated read-only database user.

## V1 Scope

The workflow must summarize only:

- AWS IAM
- AWS S3
- AWS CloudTrail
- critical and high findings
- failed/open findings

Kubernetes findings belong to V2.

## Production Checks

Before enabling the schedule:

1. Confirm the final Prowler App API findings endpoint and filter syntax.
2. Confirm the token has read-only access.
3. Run the workflow manually with a small result set.
4. Confirm the Teams message size is below the connector limit.
5. Confirm the message does not include raw evidence or credentials.

