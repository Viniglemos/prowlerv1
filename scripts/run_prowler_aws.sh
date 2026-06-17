#!/usr/bin/env bash
set -euo pipefail

PROWLER_SERVICES="${PROWLER_SERVICES:-iam s3 cloudtrail}"
PROWLER_STATUS_FILTER="${PROWLER_STATUS_FILTER:-FAIL}"
PROWLER_SEVERITY_FILTER="${PROWLER_SEVERITY_FILTER:-critical high}"
PROWLER_OUTPUT_FORMATS="${PROWLER_OUTPUT_FORMATS:-csv json-ocsf html}"
PROWLER_IGNORE_EXIT_CODE="${PROWLER_IGNORE_EXIT_CODE:-true}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
CI_PIPELINE_ID="${CI_PIPELINE_ID:-local}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
ASSUME_ROLE_SCRIPT="${ASSUME_ROLE_SCRIPT:-scripts/assume_role.sh}"

usage() {
  cat <<'USAGE'
Usage: scripts/run_prowler_aws.sh <account-id>

Runs Prowler Open Source against one AWS account by assuming ProwlerAuditRole.
Only critical/high FAIL findings are written.

Environment variables:
  PROWLER_SERVICES          Default: iam s3 cloudtrail
  PROWLER_STATUS_FILTER     Default: FAIL
  PROWLER_SEVERITY_FILTER   Default: critical high
  PROWLER_OUTPUT_FORMATS    Default: csv json-ocsf html
  PROWLER_IGNORE_EXIT_CODE  Default: true
  RUN_DATE                  Default: current UTC date, YYYY-MM-DD
  CI_PIPELINE_ID            Default: local
  OUTPUT_ROOT               Default: output
  ASSUME_ROLE_SCRIPT        Default: scripts/assume_role.sh

Example:
  scripts/run_prowler_aws.sh 123456789012
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

ACCOUNT_ID="$1"

if [[ ! "${ACCOUNT_ID}" =~ ^[0-9]{12}$ ]]; then
  echo "Account ID must be a 12-digit AWS account ID." >&2
  exit 2
fi

for command_name in prowler date; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${ASSUME_ROLE_SCRIPT}" ]]; then
  echo "Assume-role script not found: ${ASSUME_ROLE_SCRIPT}" >&2
  exit 1
fi

read -r -a SERVICES <<<"${PROWLER_SERVICES}"
read -r -a STATUSES <<<"${PROWLER_STATUS_FILTER}"
read -r -a SEVERITIES <<<"${PROWLER_SEVERITY_FILTER}"
read -r -a OUTPUT_FORMATS <<<"${PROWLER_OUTPUT_FORMATS}"
EXTRA_PROWLER_ARGS=()

if [[ ${#SERVICES[@]} -eq 0 || ${#STATUSES[@]} -eq 0 || ${#SEVERITIES[@]} -eq 0 || ${#OUTPUT_FORMATS[@]} -eq 0 ]]; then
  echo "Prowler services, status, severity, and output formats must not be empty." >&2
  exit 1
fi

if [[ "${PROWLER_IGNORE_EXIT_CODE}" == "true" ]]; then
  EXTRA_PROWLER_ARGS+=(--ignore-exit-code)
fi

OUTPUT_DIR="${OUTPUT_ROOT}/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}/accounts/${ACCOUNT_ID}"
mkdir -p "${OUTPUT_DIR}"

echo "Running Prowler for account ${ACCOUNT_ID}"
echo "Output directory: ${OUTPUT_DIR}"
echo "Services: ${PROWLER_SERVICES}"
echo "Status filter: ${PROWLER_STATUS_FILTER}"
echo "Severity filter: ${PROWLER_SEVERITY_FILTER}"

bash "${ASSUME_ROLE_SCRIPT}" "${ACCOUNT_ID}" -- \
  prowler aws \
    --services "${SERVICES[@]}" \
    --status "${STATUSES[@]}" \
    --severity "${SEVERITIES[@]}" \
    -M "${OUTPUT_FORMATS[@]}" \
    "${EXTRA_PROWLER_ARGS[@]}" \
    -o "${OUTPUT_DIR}"

echo "Prowler completed for account ${ACCOUNT_ID}"
