#!/usr/bin/env bash
set -euo pipefail

ACCOUNTS_FILE="${ACCOUNTS_FILE:-output/accounts/accounts.txt}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
CI_PIPELINE_ID="${CI_PIPELINE_ID:-local}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
RUN_PROWLER_SCRIPT="${RUN_PROWLER_SCRIPT:-scripts/run_prowler_aws.sh}"

export RUN_DATE
export CI_PIPELINE_ID
export OUTPUT_ROOT

usage() {
  cat <<'USAGE'
Usage: scripts/run_prowler_all_accounts.sh

Reads account IDs from output/accounts/accounts.txt and runs filtered Prowler
checks across each account. Scanning continues if an account fails, and the
script exits non-zero at the end if any technical account scan failed.

Environment variables:
  ACCOUNTS_FILE       Default: output/accounts/accounts.txt
  RUN_DATE            Default: current UTC date, YYYY-MM-DD
  CI_PIPELINE_ID      Default: local
  OUTPUT_ROOT         Default: output
  RUN_PROWLER_SCRIPT  Default: scripts/run_prowler_aws.sh

Example:
  scripts/run_prowler_all_accounts.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "${ACCOUNTS_FILE}" ]]; then
  echo "Accounts file not found: ${ACCOUNTS_FILE}" >&2
  echo "Run scripts/discover_aws_accounts.sh first." >&2
  exit 1
fi

if [[ ! -f "${RUN_PROWLER_SCRIPT}" ]]; then
  echo "Run Prowler script not found: ${RUN_PROWLER_SCRIPT}" >&2
  exit 1
fi

PIPELINE_OUTPUT_DIR="${OUTPUT_ROOT}/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}"
LOG_DIR="${PIPELINE_OUTPUT_DIR}/logs"
FAILED_ACCOUNTS_FILE="${LOG_DIR}/failed_accounts.txt"
SCANNED_ACCOUNTS_FILE="${LOG_DIR}/scanned_accounts.txt"

mkdir -p "${LOG_DIR}"
: >"${FAILED_ACCOUNTS_FILE}"
: >"${SCANNED_ACCOUNTS_FILE}"

total_accounts=0
scanned_accounts=0
failed_accounts=0

while IFS= read -r account_id || [[ -n "${account_id}" ]]; do
  account_id="${account_id%%#*}"
  account_id="$(printf '%s' "${account_id}" | tr -d '[:space:]')"

  if [[ -z "${account_id}" ]]; then
    continue
  fi

  if [[ ! "${account_id}" =~ ^[0-9]{12}$ ]]; then
    echo "Skipping invalid account ID from ${ACCOUNTS_FILE}: ${account_id}" >&2
    printf '%s\t%s\n' "${account_id}" "invalid-account-id" >>"${FAILED_ACCOUNTS_FILE}"
    failed_accounts=$((failed_accounts + 1))
    continue
  fi

  total_accounts=$((total_accounts + 1))
  echo "Starting Prowler scan for account ${account_id}"

  if bash "${RUN_PROWLER_SCRIPT}" "${account_id}"; then
    scanned_accounts=$((scanned_accounts + 1))
    printf '%s\n' "${account_id}" >>"${SCANNED_ACCOUNTS_FILE}"
    echo "Completed Prowler scan for account ${account_id}"
  else
    failed_accounts=$((failed_accounts + 1))
    printf '%s\t%s\n' "${account_id}" "technical-scan-failure" >>"${FAILED_ACCOUNTS_FILE}"
    echo "Prowler scan failed for account ${account_id}; continuing." >&2
  fi
done <"${ACCOUNTS_FILE}"

echo "Prowler account scan summary"
echo "Accounts requested: ${total_accounts}"
echo "Accounts scanned successfully: ${scanned_accounts}"
echo "Accounts failed technically: ${failed_accounts}"
echo "Scanned accounts log: ${SCANNED_ACCOUNTS_FILE}"
echo "Failed accounts log: ${FAILED_ACCOUNTS_FILE}"

if [[ "${failed_accounts}" -gt 0 ]]; then
  exit 1
fi
