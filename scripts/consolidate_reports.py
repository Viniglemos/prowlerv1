#!/usr/bin/env python3
"""Consolidate filtered Prowler account outputs into CSV and JSONL."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
from pathlib import Path
from typing import Any


FIELDNAMES = [
    "account_id",
    "service",
    "severity",
    "status",
    "check_id",
    "check_title",
    "region",
    "resource_id",
    "resource_arn",
    "finding_uid",
    "message",
    "remediation",
    "source_file",
]

STATUS_FILTER = {"fail"}
SEVERITY_FILTER = {"critical", "high"}


def default_pipeline_dir() -> Path:
    run_date = os.environ.get("RUN_DATE") or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    pipeline_id = os.environ.get("CI_PIPELINE_ID", "local")
    output_root = os.environ.get("OUTPUT_ROOT", "output")
    return Path(output_root) / run_date / f"pipeline-{pipeline_id}"


def normalized_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def flatten_json(value: Any, prefix: str = "") -> dict[str, Any]:
    flattened: dict[str, Any] = {}

    if isinstance(value, dict):
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else str(key)
            flattened.update(flatten_json(child, child_prefix))
    elif isinstance(value, list):
        if not value:
            flattened[prefix] = ""
        else:
            for index, child in enumerate(value):
                child_prefix = f"{prefix}.{index}" if prefix else str(index)
                flattened.update(flatten_json(child, child_prefix))
    else:
        flattened[prefix] = "" if value is None else value

    return flattened


def make_lookup(row: dict[str, Any]) -> dict[str, Any]:
    return {normalized_key(str(key)): value for key, value in row.items()}


def first_value(row: dict[str, Any], candidates: list[str]) -> str:
    lookup = make_lookup(row)
    for candidate in candidates:
        value = lookup.get(normalized_key(candidate))
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return ""


def infer_account_id(row: dict[str, Any], source_file: Path) -> str:
    account_id = first_value(
        row,
        [
            "account_id",
            "account uid",
            "account_uid",
            "accountid",
            "aws_account_id",
            "cloud.account.uid",
            "cloud.account_uid",
            "recipient_account_id",
        ],
    )
    if account_id:
        return account_id

    for part in source_file.parts:
        if re.fullmatch(r"[0-9]{12}", part):
            return part
    return ""


def normalize_record(row: dict[str, Any], source_file: Path) -> dict[str, str]:
    flattened = flatten_json(row)

    normalized = {
        "account_id": infer_account_id(flattened, source_file),
        "service": first_value(
            flattened,
            [
                "service",
                "service_name",
                "service name",
                "check_service",
                "check.service",
                "product.feature.name",
                "metadata.product.feature.name",
            ],
        ).lower(),
        "severity": first_value(flattened, ["severity", "severity_label", "severity label"]).lower(),
        "status": first_value(flattened, ["status", "status_code", "status code", "finding_status"]).upper(),
        "check_id": first_value(flattened, ["check_id", "check id", "rule_id", "finding_info.uid", "finding uid"]),
        "check_title": first_value(flattened, ["check_title", "check title", "finding_info.title", "title"]),
        "region": first_value(flattened, ["region", "region_name", "cloud.region"]),
        "resource_id": first_value(
            flattened,
            [
                "resource_id",
                "resource id",
                "resources.0.uid",
                "resources.0.name",
                "resource.uid",
                "resource.name",
            ],
        ),
        "resource_arn": first_value(
            flattened,
            [
                "resource_arn",
                "resource arn",
                "resources.0.arn",
                "resource.arn",
                "resource_uid",
            ],
        ),
        "finding_uid": first_value(flattened, ["finding_uid", "finding uid", "uid", "metadata.uid"]),
        "message": first_value(flattened, ["message", "status_extended", "status extended", "desc", "description"]),
        "remediation": first_value(
            flattened,
            [
                "remediation",
                "remediation_recommendation_text",
                "remediation recommendation text",
                "remediation.desc",
                "remediation.kb_article_list.0.title",
            ],
        ),
        "source_file": str(source_file),
    }

    return normalized


def is_in_scope(record: dict[str, str]) -> bool:
    return record["status"].lower() in STATUS_FILTER and record["severity"].lower() in SEVERITY_FILTER


def read_csv_records(path: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                record = normalize_record(dict(row), path)
                if is_in_scope(record):
                    records.append(record)
    except UnicodeDecodeError:
        with path.open("r", encoding="latin-1", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                record = normalize_record(dict(row), path)
                if is_in_scope(record):
                    records.append(record)
    return records


def iter_json_values(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    if isinstance(value, dict):
        for key in ("findings", "Findings", "items", "Items", "data", "Data", "records", "Records"):
            child = value.get(key)
            if isinstance(child, list):
                return [item for item in child if isinstance(item, dict)]
        return [value]
    return []


def read_json_records(path: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    text = path.read_text(encoding="utf-8-sig").strip()
    if not text:
        return records

    values: list[dict[str, Any]] = []
    try:
        values = iter_json_values(json.loads(text))
    except json.JSONDecodeError:
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            values.extend(iter_json_values(value))

    for value in values:
        record = normalize_record(value, path)
        if is_in_scope(record):
            records.append(record)
    return records


def discover_input_files(accounts_dir: Path) -> list[Path]:
    if not accounts_dir.exists():
        return []

    files: list[Path] = []
    for path in accounts_dir.rglob("*"):
        if not path.is_file():
            continue
        name = path.name.lower()
        if name.startswith("consolidated-"):
            continue
        if path.suffix.lower() in {".csv", ".json", ".jsonl"}:
            files.append(path)
    return sorted(files)


def dedupe_records(records: list[dict[str, str]]) -> list[dict[str, str]]:
    seen: set[tuple[str, ...]] = set()
    deduped: list[dict[str, str]] = []
    key_fields = ["account_id", "service", "severity", "status", "check_id", "region", "resource_id", "resource_arn"]

    for record in records:
        key = tuple(record.get(field, "") for field in key_fields)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(record)
    return deduped


def write_outputs(records: list[dict[str, str]], csv_path: Path, jsonl_path: Path) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    jsonl_path.parent.mkdir(parents=True, exist_ok=True)

    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(records)

    with jsonl_path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, sort_keys=True) + "\n")


def parse_args() -> argparse.Namespace:
    pipeline_dir = default_pipeline_dir()
    parser = argparse.ArgumentParser(description="Consolidate filtered Prowler outputs.")
    parser.add_argument("--pipeline-dir", default=str(pipeline_dir), help="Pipeline output directory.")
    parser.add_argument("--accounts-dir", default=None, help="Accounts output directory. Defaults to <pipeline-dir>/accounts.")
    parser.add_argument("--output-csv", default=None, help="Consolidated CSV path.")
    parser.add_argument("--output-jsonl", default=None, help="Consolidated JSONL path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pipeline_dir = Path(args.pipeline_dir)
    accounts_dir = Path(args.accounts_dir) if args.accounts_dir else pipeline_dir / "accounts"
    output_csv = Path(args.output_csv) if args.output_csv else pipeline_dir / "consolidated-critical-high.csv"
    output_jsonl = Path(args.output_jsonl) if args.output_jsonl else pipeline_dir / "consolidated-critical-high.jsonl"

    input_files = discover_input_files(accounts_dir)
    records: list[dict[str, str]] = []
    for path in input_files:
        if path.suffix.lower() == ".csv":
            records.extend(read_csv_records(path))
        elif path.suffix.lower() in {".json", ".jsonl"}:
            records.extend(read_json_records(path))

    records = dedupe_records(records)
    write_outputs(records, output_csv, output_jsonl)

    print(f"Input files scanned: {len(input_files)}")
    print(f"Consolidated findings: {len(records)}")
    print(f"Wrote CSV: {output_csv}")
    print(f"Wrote JSONL: {output_jsonl}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
