#!/usr/bin/env python3
"""Plan of Action and Milestones generator (CA-5, RA-5, SI-2).

Turns open Security Hub findings (failed controls, Inspector vulnerabilities,
Access Analyzer exposures, GuardDuty threats) into a POA&M in the FedRAMP
template column layout, with the FedRAMP remediation deadline computed from
the first-observed date:

    High (CRITICAL / HIGH)   30 days
    Moderate (MEDIUM)        90 days
    Low (LOW / INFO)        180 days

Known, accepted deviations are listed in evidence/poam-exceptions.csv and are
carried into the POA&M as "Operational Requirement" or "False Positive" rows
with their rationale, instead of being silently dropped.

    python evidence/poam.py                    # writes evidence/output/<date>/POAM.csv and POAM.md
    python evidence/poam.py --profile mgmt --region us-east-1
"""
from __future__ import annotations

import argparse
import csv
import os
import pathlib
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

import boto3
from botocore.config import Config

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIPS_REGIONS = {"us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "ca-west-1"}

RISK = {"CRITICAL": "High", "HIGH": "High", "MEDIUM": "Moderate", "LOW": "Low", "INFORMATIONAL": "Low"}
SLA_DAYS = {"High": 30, "Moderate": 90, "Low": 180}

COLUMNS = [
    "POAM ID", "Controls", "Weakness Name", "Weakness Description", "Weakness Detector Source",
    "Weakness Source Identifier", "Asset Identifier", "Point of Contact", "Resources Required",
    "Overall Remediation Plan", "Original Detection Date", "Scheduled Completion Date",
    "Planned Milestones", "Milestone Changes", "Status Date", "Vendor Dependency",
    "Last Vendor Check-in Date", "Vendor Dependent Product Name", "Original Risk Rating",
    "Adjusted Risk Rating", "Risk Adjustment", "False Positive", "Operational Requirement",
    "Deviation Rationale", "Supporting Documents", "Comments", "Status",
]

def load_exceptions(path: pathlib.Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as fh:
        return {row["match"]: row for row in csv.DictReader(fh)}

def controls_from(finding: dict) -> str:
    reqs = finding.get("Compliance", {}).get("RelatedRequirements", []) or []
    ids = sorted({m.group(1) for r in reqs for m in [re.search(r"NIST\.800-53\.r5 ([A-Z]{2}-\d+(?:\(\d+\))?)", r)] if m})
    if not ids:
        ids = sorted({r for r in reqs if r.startswith("NIST")})
    return "; ".join(ids)

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--profile", default=os.environ.get("AWS_PROFILE"))
    ap.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    ap.add_argument("--out", default=None)
    ap.add_argument("--exceptions", default=str(ROOT / "evidence" / "poam-exceptions.csv"))
    ap.add_argument("--poc", default="Security Lead", help="default point of contact")
    args = ap.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    cfg = Config(retries={"max_attempts": 8, "mode": "standard"}, use_fips_endpoint=args.region in FIPS_REGIONS)
    sh = session.client("securityhub", config=cfg)
    out_dir = pathlib.Path(args.out) if args.out else ROOT / "evidence" / "output" / datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out_dir.mkdir(parents=True, exist_ok=True)
    exceptions = load_exceptions(pathlib.Path(args.exceptions))

    filters = {
        "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
        "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}, {"Value": "NOTIFIED", "Comparison": "EQUALS"}],
    }
    findings = []
    for page in sh.get_paginator("get_findings").paginate(Filters=filters, PaginationConfig={"PageSize": 100}):
        for f in page.get("Findings", []):
            compliance = f.get("Compliance", {}).get("Status")
            if compliance == "PASSED":
                continue
            if f.get("ProductName") == "Security Hub" and compliance not in ("FAILED", "WARNING"):
                continue
            findings.append(f)

    today = datetime.now(timezone.utc).date()
    rows = []
    for n, f in enumerate(sorted(findings, key=lambda x: (RISK.get(x.get("Severity", {}).get("Label", "LOW"), "Low"), x.get("FirstObservedAt", ""))), start=1):
        sev = f.get("Severity", {}).get("Label", "LOW")
        risk = RISK.get(sev, "Low")
        first = (f.get("FirstObservedAt") or f.get("CreatedAt") or "")[:10]
        first_date = datetime.strptime(first, "%Y-%m-%d").date() if first else today
        due = first_date + timedelta(days=SLA_DAYS[risk])
        control_id = (f.get("Compliance", {}).get("SecurityControlId") or f.get("ProductFields", {}).get("ControlId")
                      or (f.get("ProductFields", {}).get("aws/config/ConfigRuleName") or f.get("ProductFields", {}).get("ConfigRuleName") or "").split("-conformance-pack-")[0] or "")
        generator = f.get("GeneratorId", "")
        product = f.get("ProductName", "")
        resource = (f.get("Resources") or [{}])[0].get("Id", "")
        key_candidates = [control_id, generator, f.get("Title", "")]
        exc = next((exceptions[k] for k in key_candidates if k and k in exceptions), None)

        status = "Open"
        if exc:
            status = "Risk accepted" if exc.get("type", "").lower().startswith("op") else "False positive"
        elif due < today:
            status = "Overdue"

        rows.append({
            "POAM ID": f"V-{today.strftime('%Y%m%d')}-{n:04d}",
            "Controls": controls_from(f),
            "Weakness Name": f.get("Title", "")[:120],
            "Weakness Description": (f.get("Description") or "")[:500],
            "Weakness Detector Source": product,
            "Weakness Source Identifier": control_id or generator,
            "Asset Identifier": resource,
            "Point of Contact": args.poc,
            "Resources Required": "Engineering time; no procurement",
            "Overall Remediation Plan": (f.get("Remediation", {}).get("Recommendation", {}).get("Text") or "See finding remediation guidance")[:300],
            "Original Detection Date": first,
            "Scheduled Completion Date": due.isoformat(),
            "Planned Milestones": f"Triage within 7 days; fix or exception before {due.isoformat()}",
            "Milestone Changes": "",
            "Status Date": today.isoformat(),
            "Vendor Dependency": "No",
            "Last Vendor Check-in Date": "",
            "Vendor Dependent Product Name": "",
            "Original Risk Rating": risk,
            "Adjusted Risk Rating": exc.get("adjusted_risk", risk) if exc else risk,
            "Risk Adjustment": "Yes" if exc and exc.get("adjusted_risk") and exc.get("adjusted_risk") != risk else "No",
            "False Positive": "Yes" if exc and exc.get("type", "").lower().startswith("false") else "No",
            "Operational Requirement": "Yes" if exc and exc.get("type", "").lower().startswith("op") else "No",
            "Deviation Rationale": exc.get("rationale", "") if exc else "",
            "Supporting Documents": exc.get("reference", "") if exc else "",
            "Comments": f"Security Hub finding {f['Id']}",
            "Status": status,
        })

    csv_path = out_dir / "POAM.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)

    by_status = Counter(r["Status"] for r in rows)
    by_risk = Counter(r["Original Risk Rating"] for r in rows if r["Status"] in ("Open", "Overdue"))
    md = [
        "# POA&M summary",
        "",
        f"Generated {today.isoformat()} from Security Hub ({args.region}). {len(rows)} items.",
        "",
        "| Status | Count |", "|---|---|",
        *[f"| {k} | {v} |" for k, v in sorted(by_status.items())],
        "",
        "| Open risk rating | Count | SLA |", "|---|---|---|",
        *[f"| {k} | {by_risk.get(k, 0)} | {SLA_DAYS[k]} days |" for k in ("High", "Moderate", "Low")],
        "",
        "## Overdue and High items",
        "",
        "| POAM ID | Risk | Control | Weakness | Asset | Due | Status |", "|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        if r["Status"] == "Overdue" or (r["Original Risk Rating"] == "High" and r["Status"] == "Open"):
            md.append(f"| {r['POAM ID']} | {r['Original Risk Rating']} | {r['Weakness Source Identifier']} | {r['Weakness Name'][:60]} | {r['Asset Identifier'][-50:]} | {r['Scheduled Completion Date']} | {r['Status']} |")
    md += ["", "## Accepted deviations", "", "| Source identifier | Type | Rationale |", "|---|---|---|"]
    for r in rows:
        if r["Status"] in ("Risk accepted", "False positive"):
            md.append(f"| {r['Weakness Source Identifier']} | {r['Status']} | {r['Deviation Rationale'][:120]} |")
    (out_dir / "POAM.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"POA&M: {len(rows)} items -> {csv_path}  ({dict(by_status)})")
    return 0

if __name__ == "__main__":
    sys.exit(main())
