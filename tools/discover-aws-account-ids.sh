#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-generated/aws-organizations}"
INCLUDE_SUSPENDED="${INCLUDE_SUSPENDED:-false}"

mkdir -p "$OUTPUT_DIR"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 2
fi

tmp_accounts="$(mktemp)"
trap 'rm -f "$tmp_accounts"' EXIT

aws organizations list-accounts \
  --output json \
  --query 'Accounts[].{Id:Id,Name:Name,Email:Email,Status:Status}' > "$tmp_accounts"

if [ "$INCLUDE_SUSPENDED" = "true" ]; then
  jq -S '.' "$tmp_accounts" > "$OUTPUT_DIR/accounts.json"
else
  jq -S '[.[] | select(.Status == "ACTIVE")]' "$tmp_accounts" > "$OUTPUT_DIR/accounts.json"
fi

jq -r '.[].Id' "$OUTPUT_DIR/accounts.json" > "$OUTPUT_DIR/accounts.txt"

{
  printf 'target_account_ids = '
  jq -c '[.[].Id]' "$OUTPUT_DIR/accounts.json"
  printf '\n'
} > "$OUTPUT_DIR/target-account-ids.auto.tfvars.example"

echo "Generated:"
echo "  $OUTPUT_DIR/accounts.json"
echo "  $OUTPUT_DIR/accounts.txt"
echo "  $OUTPUT_DIR/target-account-ids.auto.tfvars.example"
