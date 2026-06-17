#!/usr/bin/env bash
set -euo pipefail

INCLUDED_ACCOUNTS_FILE="${INCLUDED_ACCOUNTS_FILE:-config/included_accounts.txt}"
EXCLUDED_ACCOUNTS_FILE="${EXCLUDED_ACCOUNTS_FILE:-config/excluded_accounts.txt}"
OUTPUT_DIR="${OUTPUT_DIR:-output/accounts}"
ACCOUNTS_TXT="${ACCOUNTS_TXT:-${OUTPUT_DIR}/accounts.txt}"
ACCOUNTS_JSON="${ACCOUNTS_JSON:-${OUTPUT_DIR}/accounts.json}"

usage() {
  cat <<'USAGE'
Usage: scripts/discover_aws_accounts.sh

Discovers ACTIVE AWS accounts through AWS Organizations and writes:
  output/accounts/accounts.txt
  output/accounts/accounts.json

Environment variables:
  INCLUDED_ACCOUNTS_FILE  Optional allowlist file. Default: config/included_accounts.txt
  EXCLUDED_ACCOUNTS_FILE  Optional denylist file. Default: config/excluded_accounts.txt
  OUTPUT_DIR              Output directory. Default: output/accounts
  ACCOUNTS_TXT            Accounts text output. Default: ${OUTPUT_DIR}/accounts.txt
  ACCOUNTS_JSON           Accounts JSON output. Default: ${OUTPUT_DIR}/accounts.json

AWS CLI credential selection follows standard AWS environment behavior, including AWS_PROFILE.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

for command_name in aws python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

mkdir -p "${OUTPUT_DIR}"

RAW_ACCOUNTS_JSON="$(mktemp)"
trap 'rm -f "${RAW_ACCOUNTS_JSON}"' EXIT

echo "Discovering ACTIVE AWS accounts with AWS Organizations..."
aws organizations list-accounts --output json >"${RAW_ACCOUNTS_JSON}"

python3 - "$RAW_ACCOUNTS_JSON" "$INCLUDED_ACCOUNTS_FILE" "$EXCLUDED_ACCOUNTS_FILE" "$ACCOUNTS_TXT" "$ACCOUNTS_JSON" <<'PY'
import json
import pathlib
import sys

raw_path = pathlib.Path(sys.argv[1])
included_path = pathlib.Path(sys.argv[2])
excluded_path = pathlib.Path(sys.argv[3])
accounts_txt_path = pathlib.Path(sys.argv[4])
accounts_json_path = pathlib.Path(sys.argv[5])


def load_account_ids(path):
    if not path.exists():
        return set()

    account_ids = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        account_ids.add(value)
    return account_ids


payload = json.loads(raw_path.read_text(encoding="utf-8"))
all_accounts = payload.get("Accounts", [])
active_accounts = [account for account in all_accounts if account.get("Status") == "ACTIVE"]

included_ids = load_account_ids(included_path)
excluded_ids = load_account_ids(excluded_path)

selected_accounts = []
for account in active_accounts:
    account_id = account.get("Id", "")
    if included_ids and account_id not in included_ids:
        continue
    if account_id in excluded_ids:
        continue
    selected_accounts.append(
        {
            "id": account_id,
            "name": account.get("Name", ""),
            "email": account.get("Email", ""),
            "status": account.get("Status", ""),
        }
    )

selected_accounts.sort(key=lambda item: item["id"])

accounts_txt_path.parent.mkdir(parents=True, exist_ok=True)
accounts_json_path.parent.mkdir(parents=True, exist_ok=True)

accounts_txt_path.write_text(
    "".join(f"{account['id']}\n" for account in selected_accounts),
    encoding="utf-8",
)
accounts_json_path.write_text(
    json.dumps(selected_accounts, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

active_ids = {account.get("Id", "") for account in active_accounts}
missing_included_ids = sorted(included_ids - active_ids)

if missing_included_ids:
    print(
        "Warning: included account IDs were not discovered as ACTIVE: "
        + ", ".join(missing_included_ids),
        file=sys.stderr,
    )

print(f"Discovered ACTIVE accounts: {len(active_accounts)}")
print(f"Selected accounts: {len(selected_accounts)}")
print(f"Wrote account IDs: {accounts_txt_path}")
print(f"Wrote account metadata: {accounts_json_path}")
PY
