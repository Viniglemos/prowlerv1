#!/usr/bin/env bash
set -euo pipefail

REPORTS_BUCKET="${REPORTS_BUCKET:-}"
REPORTS_PREFIX="${REPORTS_PREFIX:-aws}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
CI_PIPELINE_ID="${CI_PIPELINE_ID:-local}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
PIPELINE_DIR="${PIPELINE_DIR:-${OUTPUT_ROOT}/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}}"
SSE_ALGORITHM="${SSE_ALGORITHM:-AES256}"
UPLOAD_TO_S3="${UPLOAD_TO_S3:-true}"

usage() {
  cat <<'USAGE'
Usage: scripts/upload_reports_s3.sh

Uploads only filtered MVP Prowler report outputs to S3.

Required environment variables:
  REPORTS_BUCKET   S3 bucket name for report retention.

Optional environment variables:
  REPORTS_PREFIX   Top-level reports prefix. Default: aws
  RUN_DATE         Run date in YYYY-MM-DD format. Default: current UTC date
  CI_PIPELINE_ID   Pipeline ID. Default: local
  OUTPUT_ROOT      Local output root. Default: output
  PIPELINE_DIR     Local pipeline output directory. Default: output/${RUN_DATE}/pipeline-${CI_PIPELINE_ID}
  SSE_ALGORITHM    Server-side encryption algorithm. Default: AES256
  UPLOAD_TO_S3     Set to false to skip upload. Default: true

Uploaded layout:
  s3://${REPORTS_BUCKET}/${REPORTS_PREFIX}/YYYY/MM/DD/pipeline-${CI_PIPELINE_ID}/
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${UPLOAD_TO_S3}" != "true" ]]; then
  echo "UPLOAD_TO_S3 is not true; skipping S3 upload."
  exit 0
fi

if [[ -z "${REPORTS_BUCKET}" ]]; then
  echo "REPORTS_BUCKET is required." >&2
  exit 2
fi

if [[ ! "${REPORTS_BUCKET}" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
  echo "REPORTS_BUCKET must be a valid S3 bucket name." >&2
  exit 2
fi

if [[ ! "${REPORTS_PREFIX}" =~ ^[A-Za-z0-9][A-Za-z0-9/_-]*[A-Za-z0-9]$|^[A-Za-z0-9]$ ]]; then
  echo "REPORTS_PREFIX must be a relative prefix without leading or trailing slashes." >&2
  exit 2
fi

if [[ ! "${RUN_DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "RUN_DATE must use YYYY-MM-DD format." >&2
  exit 2
fi

if [[ ! -d "${PIPELINE_DIR}" ]]; then
  echo "Pipeline output directory not found: ${PIPELINE_DIR}" >&2
  exit 1
fi

for command_name in aws find tr; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

YEAR="${RUN_DATE:0:4}"
MONTH="${RUN_DATE:5:2}"
DAY="${RUN_DATE:8:2}"
S3_BASE_URI="s3://${REPORTS_BUCKET}/${REPORTS_PREFIX}/${YEAR}/${MONTH}/${DAY}/pipeline-${CI_PIPELINE_ID}"

is_allowed_file() {
  local relative_path="$1"
  local lower_path
  lower_path="$(printf '%s' "${relative_path}" | tr '[:upper:]' '[:lower:]')"

  case "${lower_path}" in
    *raw*|*unfiltered*)
      return 1
      ;;
    summary.md|consolidated-critical-high.csv|consolidated-critical-high.jsonl)
      return 0
      ;;
    accounts/*/*.csv|accounts/*/*.json|accounts/*/*.jsonl|accounts/*/*.html)
      return 0
      ;;
    logs/*.txt|logs/*.log)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

uploaded_count=0
skipped_count=0

echo "Uploading filtered Prowler report outputs to ${S3_BASE_URI}/"

while IFS= read -r -d '' file_path; do
  relative_path="${file_path#${PIPELINE_DIR}/}"

  if ! is_allowed_file "${relative_path}"; then
    skipped_count=$((skipped_count + 1))
    continue
  fi

  aws s3 cp \
    "${file_path}" \
    "${S3_BASE_URI}/${relative_path}" \
    --sse "${SSE_ALGORITHM}" \
    --only-show-errors

  uploaded_count=$((uploaded_count + 1))
done < <(find "${PIPELINE_DIR}" -type f -print0)

if [[ "${uploaded_count}" -eq 0 ]]; then
  echo "No filtered report files were uploaded from ${PIPELINE_DIR}." >&2
  exit 1
fi

echo "Uploaded filtered report files: ${uploaded_count}"
echo "Skipped non-uploadable files: ${skipped_count}"
echo "Final S3 path: ${S3_BASE_URI}/"
