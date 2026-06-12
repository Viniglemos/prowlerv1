#!/usr/bin/env bash
set -euo pipefail

TARGET_ROLE_NAME="${TARGET_ROLE_NAME:-ProwlerAuditRole}"
ROLE_SESSION_NAME="${ROLE_SESSION_NAME:-prowler-audit}"
AWS_PARTITION="${AWS_PARTITION:-aws}"
EXTERNAL_ID="${EXTERNAL_ID:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/assume_role.sh <account-id> -- <command> [args...]

Assumes the configured target-account audit role and runs a command with temporary
credentials in the child process environment. Temporary STS credentials are not printed.

Environment variables:
  TARGET_ROLE_NAME   Role name to assume. Default: ProwlerAuditRole
  ROLE_SESSION_NAME  STS session name. Default: prowler-audit
  AWS_PARTITION      AWS partition. Default: aws
  EXTERNAL_ID        Optional ExternalId passed to STS.

Examples:
  scripts/assume_role.sh 123456789012 -- aws sts get-caller-identity
  TARGET_ROLE_NAME=ProwlerAuditRole scripts/assume_role.sh 123456789012 -- aws s3 ls
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 3 || "${2:-}" != "--" ]]; then
  usage >&2
  exit 2
fi

ACCOUNT_ID="$1"
shift 2

if [[ ! "${ACCOUNT_ID}" =~ ^[0-9]{12}$ ]]; then
  echo "Account ID must be a 12-digit AWS account ID." >&2
  exit 2
fi

for command_name in aws python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

# Prevent shell tracing from exposing temporary STS credentials in logs.
set +x

ROLE_ARN="arn:${AWS_PARTITION}:iam::${ACCOUNT_ID}:role/${TARGET_ROLE_NAME}"
ASSUME_ROLE_ARGS=(
  sts assume-role
  --role-arn "${ROLE_ARN}"
  --role-session-name "${ROLE_SESSION_NAME}-${ACCOUNT_ID}"
  --query Credentials
  --output json
)

if [[ -n "${EXTERNAL_ID}" ]]; then
  ASSUME_ROLE_ARGS+=(--external-id "${EXTERNAL_ID}")
fi

CREDENTIALS_JSON="$(aws "${ASSUME_ROLE_ARGS[@]}")"

AWS_ACCESS_KEY_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["AccessKeyId"])' <<<"${CREDENTIALS_JSON}")"
AWS_SECRET_ACCESS_KEY="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["SecretAccessKey"])' <<<"${CREDENTIALS_JSON}")"
AWS_SESSION_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["SessionToken"])' <<<"${CREDENTIALS_JSON}")"

unset CREDENTIALS_JSON

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
export AWS_SECURITY_TOKEN="${AWS_SESSION_TOKEN}"

exec "$@"
