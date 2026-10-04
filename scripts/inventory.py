#!/usr/bin/env python3
"""Generate a resource inventory (CM-8) from Terraform state.

Reads `terraform show -json` (or a saved copy) and writes a Markdown inventory
grouped by module, with the attributes an assessor asks about: names, ARNs,
encryption, retention, regions. Usage:

    python scripts/inventory.py                     # runs terraform show -json in ./terraform
    python scripts/inventory.py show.json out.md    # from a saved file
"""
import json
import pathlib
import subprocess
import sys
from datetime import date

ROOT = pathlib.Path(__file__).resolve().parents[1]
TF_DIR = ROOT / "terraform"

# Attributes worth showing per resource type. Anything else is noise for an
# inventory.
INTERESTING = {
    "aws_cloudtrail": ["name", "is_multi_region_trail", "is_organization_trail", "enable_log_file_validation", "kms_key_id"],
    "aws_s3_bucket": ["bucket", "region", "object_lock_enabled"],
    "aws_s3_bucket_object_lock_configuration": ["bucket"],
    "aws_s3_bucket_lifecycle_configuration": ["bucket"],
    "aws_kms_key": ["description", "arn", "enable_key_rotation", "rotation_period_in_days", "deletion_window_in_days"],
    "aws_kms_alias": ["name", "target_key_arn"],
    "aws_cloudwatch_log_group": ["name", "retention_in_days", "kms_key_id"],
    "aws_cloudwatch_metric_alarm": ["alarm_name", "metric_name", "threshold"],
    "aws_cloudwatch_log_metric_filter": ["name"],
    "aws_sns_topic": ["name", "arn", "kms_master_key_id"],
    "aws_sns_topic_subscription": ["protocol", "endpoint"],
    "aws_config_configuration_recorder": ["name", "role_arn"],
    "aws_config_delivery_channel": ["s3_bucket_name", "s3_kms_key_arn"],
    "aws_config_retention_configuration": ["retention_period_in_days"],
    "aws_config_conformance_pack": ["name", "arn"],
    "aws_config_configuration_aggregator": ["name", "arn"],
    "aws_guardduty_detector": ["id", "finding_publishing_frequency"],
    "aws_guardduty_detector_feature": ["name", "status"],
    "aws_securityhub_account": ["arn", "control_finding_generator", "auto_enable_controls"],
    "aws_securityhub_standards_subscription": ["standards_arn"],
    "aws_inspector2_enabler": ["resource_types"],
    "aws_accessanalyzer_analyzer": ["analyzer_name", "type", "arn"],
    "aws_cloudwatch_event_rule": ["name", "description"],
    "aws_cloudwatch_event_target": ["rule", "arn"],
    "aws_iam_role": ["name", "arn", "max_session_duration"],
    "aws_iam_policy": ["name", "arn"],
    "aws_iam_role_policy_attachment": ["role", "policy_arn"],
    "aws_iam_role_policy": ["role", "name"],
    "aws_iam_openid_connect_provider": ["url", "arn"],
    "aws_iam_account_password_policy": ["minimum_password_length", "max_password_age", "password_reuse_prevention"],
    "aws_ebs_encryption_by_default": ["enabled"],
    "aws_ebs_default_kms_key": ["key_arn"],
    "aws_s3_account_public_access_block": ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"],
    "aws_organizations_organization": ["id", "feature_set"],
    "aws_organizations_organizational_unit": ["name", "id"],
    "aws_organizations_policy": ["name", "type"],
    "aws_ssoadmin_permission_set": ["name", "session_duration"],
    "aws_identitystore_group": ["display_name"],
}

MODULE_TITLES = {
    "": "Root",
    "module.org": "Organizations and SCPs",
    "module.identity": "Identity",
    "module.logging": "Logging",
    "module.crypto": "Cryptography",
    "module.detection": "Detection",
    "module.network": "Network",
    "module.edge": "Edge",
    "module.data": "Data",
    "module.respond": "Response",
}

def load_state(path: str | None) -> dict:
    if path:
        return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    out = subprocess.run(["terraform", "show", "-json"], cwd=TF_DIR, capture_output=True, text=True, check=True)
    return json.loads(out.stdout)

def walk(module: dict, prefix: str = ""):
    for r in module.get("resources", []):
        if r.get("mode") != "managed":
            continue
        yield prefix, r
    for child in module.get("child_modules", []):
        yield from walk(child, child.get("address", ""))

def fmt(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, tuple)):
        return ", ".join(fmt(v) for v in value)
    if isinstance(value, dict):
        return json.dumps(value, separators=(",", ":"))
    s = str(value)
    return s if len(s) <= 110 else s[:107] + "..."

def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else None
    dst = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "docs" / "resource-inventory.md"

    state = load_state(src)
    root = state.get("values", {}).get("root_module", {})
    rows_by_module: dict[str, list] = {}
    for module_addr, r in walk(root):
        rows_by_module.setdefault(module_addr, []).append(r)

    region = None
    account = None
    for _, r in walk(root):
        v = r.get("values", {})
        if r["type"] == "aws_s3_bucket" and v.get("region"):
            region = v["region"]
        if r["type"] == "aws_iam_role" and v.get("arn"):
            account = v["arn"].split(":")[4]
    total = sum(len(v) for v in rows_by_module.values())

    lines = [
        "# Resource inventory (CM-8)",
        "",
        f"Generated {date.today().isoformat()} from Terraform state. "
        f"Account {account or 'n/a'}, region {region or 'n/a'}, {total} managed resources.",
        "",
        "Regenerate with `python scripts/inventory.py` after every apply; commit the result as evidence.",
        "",
        "## Summary by type",
        "",
        "| Type | Count |",
        "|---|---|",
    ]
    counts: dict[str, int] = {}
    for rows in rows_by_module.values():
        for r in rows:
            counts[r["type"]] = counts.get(r["type"], 0) + 1
    for t, c in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        lines.append(f"| `{t}` | {c} |")

    for module_addr in sorted(rows_by_module, key=lambda m: list(MODULE_TITLES).index(m) if m in MODULE_TITLES else 99):
        title = MODULE_TITLES.get(module_addr, module_addr)
        lines += ["", f"## {title} (`{module_addr or 'root'}`)", "", "| Resource | Type | Key attributes |", "|---|---|---|"]
        for r in sorted(rows_by_module[module_addr], key=lambda r: (r["type"], r["address"])):
            v = r.get("values", {})
            keys = INTERESTING.get(r["type"], ["id"])
            attrs = "; ".join(f"{k}={fmt(v.get(k))}" for k in keys if v.get(k) not in (None, "", [], {}))
            short = r["address"].replace(module_addr + ".", "", 1) if module_addr else r["address"]
            lines.append(f"| `{short}` | `{r['type']}` | {attrs} |")

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {dst} ({total} resources)")

if __name__ == "__main__":
    main()
