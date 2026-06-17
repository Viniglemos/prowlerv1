#!/usr/bin/env bash
set -euo pipefail

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
CI_PIPELINE_ID="${CI_PIPELINE_ID:-local}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
PIPELINE_DIR="${PIPELINE_DIR:-${OUTPUT_ROOT}/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}}"
DASHBOARD_INPUT_DIR="${DASHBOARD_INPUT_DIR:-${PIPELINE_DIR}}"
DASHBOARD_S3_URI="${DASHBOARD_S3_URI:-}"
DASHBOARD_HOST="${DASHBOARD_HOST:-127.0.0.1}"
DASHBOARD_PORT="${DASHBOARD_PORT:-11666}"
PROWLER_DASHBOARD_ARGS="${PROWLER_DASHBOARD_ARGS:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/start_prowler_dashboard.sh

Starts the local Prowler Dashboard for internal visualization of filtered CSV outputs.

Environment variables:
  RUN_DATE                  Default: current UTC date, YYYY-MM-DD
  CI_PIPELINE_ID            Default: local
  OUTPUT_ROOT               Default: output
  PIPELINE_DIR              Default: output/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}
  DASHBOARD_INPUT_DIR       Directory containing filtered CSV files. Default: ${PIPELINE_DIR}
  DASHBOARD_S3_URI          Optional S3 URI to sync filtered CSV files from before starting.
  DASHBOARD_HOST            Default: 127.0.0.1
  DASHBOARD_PORT            Default: 11666
  PROWLER_DASHBOARD_ARGS    Optional extra arguments passed to `prowler dashboard`.

Examples:
  scripts/start_prowler_dashboard.sh
  DASHBOARD_S3_URI=s3://security-audit-prowler-reports/aws/2026/06/12/pipeline-123 scripts/start_prowler_dashboard.sh
  PROWLER_DASHBOARD_ARGS="--help" scripts/start_prowler_dashboard.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

for command_name in find date wc tr; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if ! command -v prowler >/dev/null 2>&1; then
  echo "Missing required command: prowler" >&2
  echo "Install Prowler Open Source before starting the dashboard." >&2
  exit 1
fi

if [[ -n "${DASHBOARD_S3_URI}" ]]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "Missing required command for S3 download: aws" >&2
    exit 1
  fi

  mkdir -p "${DASHBOARD_INPUT_DIR}"
  echo "Syncing filtered CSV files from ${DASHBOARD_S3_URI}/ to ${DASHBOARD_INPUT_DIR}/"
  aws s3 sync \
    "${DASHBOARD_S3_URI%/}/" \
    "${DASHBOARD_INPUT_DIR}/" \
    --exclude "*" \
    --include "consolidated-critical-high.csv" \
    --include "accounts/*/*.csv" \
    --only-show-errors
fi

if [[ ! -d "${DASHBOARD_INPUT_DIR}" ]]; then
  echo "Dashboard input directory not found: ${DASHBOARD_INPUT_DIR}" >&2
  echo "Run the scan/consolidation flow first or set DASHBOARD_S3_URI." >&2
  exit 1
fi

csv_count="$(find "${DASHBOARD_INPUT_DIR}" -type f -name "*.csv" | wc -l | tr -d '[:space:]')"

if [[ "${csv_count}" -eq 0 ]]; then
  echo "No CSV files found in ${DASHBOARD_INPUT_DIR}." >&2
  echo "The dashboard should be started only from filtered CSV outputs." >&2
  exit 1
fi

echo "Filtered CSV files found: ${csv_count}"
echo "Dashboard input directory: ${DASHBOARD_INPUT_DIR}"
echo "Starting Prowler Dashboard locally on http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"
echo "Do not expose this dashboard publicly without authentication."

read -r -a EXTRA_ARGS <<<"${PROWLER_DASHBOARD_ARGS}"

exec prowler dashboard \
  --host "${DASHBOARD_HOST}" \
  --port "${DASHBOARD_PORT}" \
  "${EXTRA_ARGS[@]}"
