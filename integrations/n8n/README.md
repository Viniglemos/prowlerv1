# n8n Weekly Summary Integration

This folder contains the optional n8n integration for the weekly Prowler App summary.

The integration is intentionally read-only:

```text
Prowler App API -> n8n filtering/normalization -> OpenAI summary agent -> Microsoft Teams
```

The workflow must run where it can reach:

- the internal Prowler App API through VPN/private network;
- the approved company OpenAI endpoint;
- the Microsoft Teams incoming webhook or Teams connector endpoint.

No secrets belong in this repository.

## Required n8n environment variables

```text
PROWLER_API_BASE_URL=https://<internal-prowler-host>/api/v1
PROWLER_API_TOKEN=<token-created-for-read-only-summary-access>
PROWLER_APP_URL=https://<internal-prowler-host>
OPENAI_API_KEY=<company-approved-openai-api-key>
OPENAI_MODEL=gpt-5.4-mini
OPENAI_API_BASE_URL=https://api.openai.com/v1
TEAMS_WEBHOOK_URL=<teams-webhook-url>
```

`OPENAI_API_BASE_URL` is optional when using the public OpenAI API. Set it when the company uses an internal OpenAI proxy or gateway.

Recommended starting model: `gpt-5.4-mini`.

Keep these values in n8n credentials/environment variables. Do not commit tokens, API keys or webhooks.

## Workflow

Import `weekly-summary.workflow.json` into n8n.

The default schedule is:

```text
Monday 08:00
Timezone: America/Sao_Paulo
```

The workflow also includes a manual trigger for validation before enabling the weekly schedule.

## Setup Step by Step

1. Create a read-only API token in Prowler App.

   Use a dedicated user or service user when possible. The token should only read findings and metadata needed for the weekly summary.

2. Configure the n8n environment variables.

   Required:

   ```text
   PROWLER_API_BASE_URL=https://prowler.educacional.app/api/v1
   PROWLER_API_TOKEN=<prowler-read-only-token>
   PROWLER_APP_URL=https://prowler.educacional.app
   OPENAI_API_KEY=<openai-project-api-key>
   OPENAI_MODEL=gpt-5.4-mini
   TEAMS_WEBHOOK_URL=<teams-or-power-automate-webhook>
   ```

   Optional:

   ```text
   OPENAI_API_BASE_URL=https://api.openai.com/v1
   ```

3. Restart n8n if the variables were added to the runtime environment.

4. Import `weekly-summary.workflow.json`.

5. Run `Manual Test`.

6. Confirm the output of each node:

   - `Get Prowler Findings` returns JSON from the Prowler App API.
   - `Build Agent Input` returns compact filtered data for IAM, S3 and CloudTrail.
   - `Generate OpenAI Summary` returns a short summary.
   - `Send Teams Message` posts to the expected Teams channel.

7. Enable the weekly schedule only after the manual test succeeds.

The workflow flow is:

1. Read filtered findings from the Prowler App API.
2. Build a compact agent input with counts, top affected providers, top checks, and representative findings.
3. Send that compact input to the approved OpenAI model.
4. Format the agent response for Teams and truncate it if needed.
5. Send the weekly message to the Teams channel.

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

The Prowler App may execute broader scans depending on current App capabilities. This workflow intentionally narrows the weekly summary to the V1 analysis scope after findings are available.

## Agent Contract

Use `weekly-summary-agent.prompt.md` as the specialist prompt and `agent-contract.json` as the input/output reference.

The OpenAI call receives only filtered and summarized data. It must not receive or publish raw evidence, credentials, tokens, account secrets, or large resource dumps.

The n8n workflow connects the agent through the OpenAI Responses API:

```text
POST ${OPENAI_API_BASE_URL}/responses
Authorization: Bearer ${OPENAI_API_KEY}
```

The `Generate OpenAI Summary` node sends:

- `model` from `OPENAI_MODEL`;
- `store: false`;
- a strict JSON schema requiring `summary`;
- the filtered finding payload from `Build Agent Input`.

Create the OpenAI API key in the approved company project/account, store it only in n8n credentials or runtime environment variables, and validate with `Manual Test` before enabling the weekly schedule.

Expected agent response:

```json
{
  "summary": "Teams-ready Markdown summary in Brazilian Portuguese"
}
```

If the agent returns plain text instead of JSON, the workflow will still send that text to Teams.

The workflow also accepts common response fields such as `message`, `text`, `output`, `output_text`, and `choices[0].message.content`.

## Specialist Behavior

The agent should:

- summarize the weekly critical/high posture for IAM, S3 and CloudTrail;
- group repeated findings by account/provider, service and check;
- recommend safe next actions for the week;
- avoid raw evidence dumps and sensitive values;
- mention when the input is incomplete or empty.

## Production Checks

Before enabling the schedule:

1. Confirm the final Prowler App API findings endpoint and filter syntax.
2. Confirm the token has read-only access.
3. Run the workflow manually with a small result set.
4. Confirm the Teams message size is below the connector limit.
5. Confirm the message does not include raw evidence or credentials.
6. Confirm Teams receives the message in the expected channel.
