#!/usr/bin/env python3
"""Generate a Markdown summary from consolidated Prowler findings."""

from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import json
import os
from pathlib import Path


MVP_SERVICES = ["iam", "s3", "cloudtrail", "lambda", "eks", "rds"]


def default_pipeline_dir() -> Path:
    run_date = os.environ.get("RUN_DATE") or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    pipeline_id = os.environ.get("CI_PIPELINE_ID", "local")
    output_root = os.environ.get("OUTPUT_ROOT", "output")
    return Path(output_root) / run_date / f"pipeline-{pipeline_id}"


def read_jsonl(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    records: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            records.append({str(key): "" if val is None else str(val) for key, val in value.items()})
    return records


def read_csv_records(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return [{key: value for key, value in row.items()} for row in csv.DictReader(handle)]


def load_findings(jsonl_path: Path, csv_path: Path) -> list[dict[str, str]]:
    records = read_jsonl(jsonl_path)
    if records:
        return records
    return read_csv_records(csv_path)


def load_account_ids(path: Path) -> list[str]:
    if not path.exists():
        return []
    account_ids: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.split("#", 1)[0].strip()
        if value:
            account_ids.append(value)
    return account_ids


def load_failed_accounts(path: Path) -> list[str]:
    if not path.exists():
        return []
    failed: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value:
            continue
        failed.append(value)
    return failed


def counter(records: list[dict[str, str]], field: str) -> collections.Counter[str]:
    values = [record.get(field, "").strip() or "unknown" for record in records]
    return collections.Counter(values)


def count_contains(records: list[dict[str, str]], service: str | None = None, terms: list[str] | None = None) -> int:
    total = 0
    terms = [term.lower() for term in (terms or [])]
    for record in records:
        if service and record.get("service", "").lower() != service:
            continue
        haystack = " ".join(
            [
                record.get("check_id", ""),
                record.get("check_title", ""),
                record.get("message", ""),
                record.get("resource_id", ""),
                record.get("resource_arn", ""),
            ]
        ).lower()
        if all(term in haystack for term in terms):
            total += 1
    return total


def count_service(records: list[dict[str, str]], service: str) -> int:
    return sum(1 for record in records if record.get("service", "").lower() == service)


def markdown_table(title: str, counts: collections.Counter[str], key_header: str) -> list[str]:
    lines = [f"## {title}", "", f"| {key_header} | Findings |", "| --- | ---: |"]
    if counts:
        for key, value in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
            lines.append(f"| {key} | {value} |")
    else:
        lines.append("| None | 0 |")
    lines.append("")
    return lines


def recommended_actions(findings: list[dict[str, str]], failed_accounts: list[str]) -> list[str]:
    actions = []
    if failed_accounts:
        actions.append("Review technical scan failures before using the summary for audit decisions.")
    if count_contains(findings, "iam", ["administratoraccess"]):
        actions.append("Review IAM AdministratorAccess assignments and remove unnecessary admin access.")
    if count_contains(findings, "iam", ["fullaccess"]):
        actions.append("Review IAM FullAccess policies and replace broad permissions with least privilege.")
    if count_contains(findings, "s3", ["public"]):
        actions.append("Review public S3 findings and confirm Block Public Access, bucket policies, and ACLs.")
    if count_service(findings, "cloudtrail"):
        actions.append("Prioritize CloudTrail critical/high findings to protect audit logging.")
    if count_service(findings, "lambda"):
        actions.append("Review Lambda execution roles, public exposure, and sensitive configuration findings.")
    if count_service(findings, "eks"):
        actions.append("Review EKS endpoint exposure, access control, and control plane logging findings.")
    if count_service(findings, "rds"):
        actions.append("Review RDS public exposure, encryption, backup, snapshot, and deletion protection findings.")
    if not actions:
        actions.append("No critical/high failed findings were consolidated; confirm scan coverage and failed account logs.")
    return actions


def parse_args() -> argparse.Namespace:
    pipeline_dir = default_pipeline_dir()
    parser = argparse.ArgumentParser(description="Generate a Markdown Prowler summary.")
    parser.add_argument("--pipeline-dir", default=str(pipeline_dir), help="Pipeline output directory.")
    parser.add_argument("--accounts-file", default="output/accounts/accounts.txt", help="Discovered accounts file.")
    parser.add_argument("--output", default=None, help="Summary Markdown path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pipeline_dir = Path(args.pipeline_dir)
    summary_path = Path(args.output) if args.output else pipeline_dir / "summary.md"
    jsonl_path = pipeline_dir / "consolidated-critical-high.jsonl"
    csv_path = pipeline_dir / "consolidated-critical-high.csv"
    failed_accounts_path = pipeline_dir / "logs" / "failed_accounts.txt"
    scanned_accounts_path = pipeline_dir / "logs" / "scanned_accounts.txt"

    findings = load_findings(jsonl_path, csv_path)
    discovered_accounts = load_account_ids(Path(args.accounts_file))
    scanned_accounts = load_account_ids(scanned_accounts_path)
    failed_accounts = load_failed_accounts(failed_accounts_path)

    if not scanned_accounts:
        scanned_accounts = sorted(
            {
                finding.get("account_id", "").strip()
                for finding in findings
                if finding.get("account_id", "").strip()
            }
        )

    if not discovered_accounts:
        discovered_accounts = scanned_accounts[:]

    service_counts = counter(findings, "service")
    severity_counts = counter(findings, "severity")
    account_counts = counter(findings, "account_id")

    scan_date = os.environ.get("RUN_DATE") or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    lines = [
        "# Prowler Critical/High Findings Summary",
        "",
        f"- Scan date: {scan_date}",
        f"- Pipeline output: `{pipeline_dir}`",
        f"- Total accounts discovered: {len(discovered_accounts)}",
        f"- Total accounts scanned: {len(scanned_accounts)}",
        f"- Failed accounts: {len(failed_accounts)}",
        f"- Consolidated findings: {len(findings)}",
        "",
    ]

    if failed_accounts:
        lines.extend(["## Failed Accounts", ""])
        for item in failed_accounts:
            lines.append(f"- {item}")
        lines.append("")

    lines.extend(markdown_table("Findings by Account", account_counts, "Account"))
    lines.extend(markdown_table("Findings by Service", service_counts, "Service"))
    lines.extend(markdown_table("Findings by Severity", severity_counts, "Severity"))

    lines.extend(
        [
            "## Focus Areas",
            "",
            f"- IAM AdministratorAccess findings: {count_contains(findings, 'iam', ['administratoraccess'])}",
            f"- IAM FullAccess findings: {count_contains(findings, 'iam', ['fullaccess'])}",
            f"- Public S3 findings: {count_contains(findings, 's3', ['public'])}",
            f"- CloudTrail critical/high findings: {count_service(findings, 'cloudtrail')}",
            f"- Lambda critical/high findings: {count_service(findings, 'lambda')}",
            f"- EKS critical/high findings: {count_service(findings, 'eks')}",
            f"- RDS critical/high findings: {count_service(findings, 'rds')}",
            "",
            "## Recommended Next Actions",
            "",
        ]
    )

    for action in recommended_actions(findings, failed_accounts):
        lines.append(f"- {action}")

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- This summary is based only on persisted filtered findings: status `FAIL`, severity `critical` or `high`.",
            "- Full unfiltered Prowler outputs are not persisted by the MVP.",
            "- Security findings do not mean the pipeline had a technical execution failure.",
            "",
        ]
    )

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote summary: {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
