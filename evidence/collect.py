#!/usr/bin/env python3
"""Continuous-monitoring evidence collector (CA-7, AU-6, CM-8).

Reads the account through FIPS endpoints with read-only permissions (the
`github-evidence` role in CI, any read-only profile locally) and writes one
JSON file per source plus a human-readable summary into
evidence/output/<YYYY-MM-DD>/. Each file is named after the control family it
supports so an assessor can find the artifact from the control matrix.

    python evidence/collect.py                 # default profile / role from the environment
    python evidence/collect.py --profile mgmt  # named profile
    python evidence/collect.py --drift         # also run terraform plan -detailed-exitcode

Every section is independent: a permission error in one source is recorded
in the summary and the rest still runs.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import os
import pathlib
import subprocess
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIPS_REGIONS = {"us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "ca-west-1"}

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def default_json(o):
    if isinstance(o, datetime):
        return o.isoformat()
    return str(o)

class Collector:
    def __init__(self, session: boto3.Session, region: str, out_dir: pathlib.Path):
        self.session = session
        self.region = region
        self.out = out_dir
        self.summary: dict[str, dict] = {}
        self.errors: dict[str, str] = {}
        self.notes: dict[str, str] = {}
        cfg = Config(retries={"max_attempts": 8, "mode": "standard"}, use_fips_endpoint=region in FIPS_REGIONS)
        self.cfg = cfg
        self.account_id = session.client("sts", config=cfg).get_caller_identity()["Account"]

    def client(self, name: str, region: str | None = None, fips: bool | None = None):
        cfg = self.cfg if fips is None else Config(retries={"max_attempts": 8, "mode": "standard"}, use_fips_endpoint=fips)
        return self.session.client(name, region_name=region or self.region, config=cfg)

    def s3_client(self):
        # S3 FIPS endpoints are not reachable from every network path;
        # evidence of
        # bucket settings is the same either way, so fall back and note it.
        from botocore.exceptions import EndpointConnectionError
        c = self.client("s3")
        try:
            c.list_buckets()
            return c
        except EndpointConnectionError:
            self.notes["s3_endpoint"] = "FIPS endpoint unreachable from this network; bucket settings read via the standard endpoint"
            return self.client("s3", fips=False)

    def write(self, name: str, data) -> None:
        path = self.out / f"{name}.json"
        path.write_text(json.dumps(data, indent=2, default=default_json), encoding="utf-8")

    def run(self, name: str, fn) -> None:
        started = time.time()
        try:
            result = fn()
            self.summary[name] = result
            print(f"  ok    {name} ({time.time() - started:.1f}s)")
        except (ClientError, BotoCoreError, subprocess.SubprocessError, OSError) as exc:
            self.errors[name] = str(exc)
            print(f"  FAIL  {name}: {exc}")

    # ------------------------------------------------------------------
    # sources

    def security_hub(self) -> dict:
        sh = self.client("securityhub")
        standards = sh.get_enabled_standards().get("StandardsSubscriptions", [])

        # Control-level status per enabled standard.
        controls: list[dict] = []
        for std in standards:
            paginator = sh.get_paginator("describe_standards_controls")
            for page in paginator.paginate(StandardsSubscriptionArn=std["StandardsSubscriptionArn"]):
                for c in page.get("Controls", []):
                    controls.append({
                        "standard": std["StandardsArn"].split("standards/")[-1],
                        "control_id": c.get("ControlId"),
                        "title": c.get("Title"),
                        "status": c.get("ControlStatus"),
                        "severity": c.get("SeverityRating"),
                        "related_requirements": c.get("RelatedRequirements", []),
                    })

        # Compliance findings: one per control per resource, current state
        # only.
        findings: list[dict] = []
        paginator = sh.get_paginator("get_findings")
        filters = {
            "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
            "ComplianceStatus": [{"Value": s, "Comparison": "EQUALS"} for s in ("PASSED", "FAILED", "WARNING", "NOT_AVAILABLE")],
        }
        for page in paginator.paginate(Filters=filters, PaginationConfig={"PageSize": 100}):
            for f in page.get("Findings", []):
                findings.append({
                    "id": f["Id"],
                    "control": (f.get("Compliance", {}).get("SecurityControlId")
                                or f.get("ProductFields", {}).get("ControlId")
                                or (f.get("ProductFields", {}).get("aws/config/ConfigRuleName") or f.get("ProductFields", {}).get("ConfigRuleName") or "").split("-conformance-pack-")[0]
                                or f.get("GeneratorId")),
                    "title": f.get("Title"),
                    "severity": f.get("Severity", {}).get("Label"),
                    "compliance": f.get("Compliance", {}).get("Status"),
                    "workflow": f.get("Workflow", {}).get("Status"),
                    "resource": (f.get("Resources") or [{}])[0].get("Id"),
                    "first_observed": f.get("FirstObservedAt"),
                    "updated": f.get("UpdatedAt"),
                    "requirements": f.get("Compliance", {}).get("RelatedRequirements", []),
                    "product": f.get("ProductName"),
                })

        by_status = Counter(f["compliance"] for f in findings)
        failed_by_control: dict[str, int] = defaultdict(int)
        for f in findings:
            if f["compliance"] == "FAILED" and f["workflow"] in ("NEW", "NOTIFIED"):
                failed_by_control[f["control"] or "unknown"] += 1

        self.write("CA-7_securityhub_standards", standards)
        self.write("CA-7_securityhub_controls", controls)
        self.write("CA-7_securityhub_findings", findings)
        total = by_status.get("PASSED", 0) + by_status.get("FAILED", 0)
        return {
            "standards": [s["StandardsArn"].split("standards/")[-1] + " " + s["StandardsStatus"] for s in standards],
            "controls_enabled": sum(1 for c in controls if c["status"] == "ENABLED"),
            "findings_by_compliance": dict(by_status),
            "pass_rate_percent": round(100 * by_status.get("PASSED", 0) / total, 1) if total else None,
            "open_failed_controls": dict(sorted(failed_by_control.items(), key=lambda kv: -kv[1])[:15]),
        }

    def config(self) -> dict:
        cfg = self.client("config")
        recorders = cfg.describe_configuration_recorder_status().get("ConfigurationRecordersStatus", [])
        packs = cfg.describe_conformance_packs().get("ConformancePackDetails", [])
        pack_summary = []
        rules = []
        for p in packs:
            name = p["ConformancePackName"]
            s = cfg.get_conformance_pack_compliance_summary(ConformancePackNames=[name]).get("ConformancePackComplianceSummaryList", [])
            pack_summary += s
            token = None
            while True:
                kwargs = {"ConformancePackName": name, "Limit": 100}
                if token:
                    kwargs["NextToken"] = token
                r = cfg.describe_conformance_pack_compliance(**kwargs)
                rules += [{"pack": name, **x} for x in r.get("ConformancePackRuleComplianceList", [])]
                token = r.get("NextToken")
                if not token:
                    break
        aggregators = cfg.describe_configuration_aggregators().get("ConfigurationAggregators", [])
        retention = cfg.describe_retention_configurations().get("RetentionConfigurations", [])

        self.write("CM-6_config_conformance_rules", rules)
        self.write("CM-8_config_recorder_and_aggregators", {"recorders": recorders, "aggregators": aggregators, "retention": retention})
        by = Counter(r["ComplianceType"] for r in rules)
        return {
            "recorder_recording": [r.get("recording") for r in recorders],
            "conformance_packs": [f'{s["ConformancePackName"]} {s["ConformancePackComplianceStatus"]}' for s in pack_summary],
            "rules_by_compliance": dict(by),
            "non_compliant_rules": sorted(r["ConfigRuleName"] for r in rules if r["ComplianceType"] == "NON_COMPLIANT")[:40],
            "aggregators": [a["ConfigurationAggregatorName"] for a in aggregators],
            "retention_days": [r.get("RetentionPeriodInDays") for r in retention],
        }

    def iam(self) -> dict:
        iam = self.client("iam")
        # Credential report: generate, wait, parse.
        for _ in range(12):
            state = iam.generate_credential_report()["State"]
            if state == "COMPLETE":
                break
            time.sleep(5)
        report_csv = iam.get_credential_report()["Content"].decode("utf-8")
        rows = list(csv.DictReader(io.StringIO(report_csv)))
        (self.out / "AC-2_iam_credential_report.csv").write_text(report_csv, encoding="utf-8")

        summary = iam.get_account_summary()["SummaryMap"]
        try:
            password_policy = iam.get_account_password_policy()["PasswordPolicy"]
        except ClientError:
            password_policy = None
        roles = [r["RoleName"] for r in iam.get_paginator("list_roles").paginate().build_full_result()["Roles"]]
        oidc = iam.list_open_id_connect_providers().get("OpenIDConnectProviderList", [])

        users = [r for r in rows if r["user"] != "<root_account>"]
        root = next((r for r in rows if r["user"] == "<root_account>"), {})
        users_with_keys = [r["user"] for r in users if r.get("access_key_1_active") == "true" or r.get("access_key_2_active") == "true"]
        users_without_mfa = [r["user"] for r in users if r.get("password_enabled") == "true" and r.get("mfa_active") != "true"]

        self.write("IA-5_iam_password_policy_and_summary", {"password_policy": password_policy, "summary": summary, "oidc_providers": oidc, "roles": roles})
        return {
            "iam_users": len(users),
            "users_with_active_access_keys": users_with_keys,
            "console_users_without_mfa": users_without_mfa,
            "root_mfa_active": root.get("mfa_active"),
            "root_access_keys": root.get("access_key_1_active") == "true" or root.get("access_key_2_active") == "true",
            "roles": len(roles),
            "oidc_providers": [p["Arn"].split("/")[-1] for p in oidc],
            "password_min_length": (password_policy or {}).get("MinimumPasswordLength"),
        }

    def guardduty(self) -> dict:
        gd = self.client("guardduty")
        detectors = gd.list_detectors().get("DetectorIds", [])
        result = {"detectors": []}
        for d in detectors:
            det = gd.get_detector(DetectorId=d)
            since = int((datetime.now(timezone.utc) - timedelta(days=30)).timestamp() * 1000)
            ids = gd.list_findings(DetectorId=d, FindingCriteria={"Criterion": {"updatedAt": {"Gte": since}}}).get("FindingIds", [])
            sev = Counter()
            findings = []
            for i in range(0, len(ids), 50):
                batch = gd.get_findings(DetectorId=d, FindingIds=ids[i:i + 50]).get("Findings", [])
                for f in batch:
                    label = "HIGH" if f["Severity"] >= 7 else "MEDIUM" if f["Severity"] >= 4 else "LOW"
                    sev[label] += 1
                    findings.append({"id": f["Id"], "type": f["Type"], "severity": f["Severity"], "resource": f["Resource"]["ResourceType"], "updated": f["UpdatedAt"], "title": f["Title"]})
            result["detectors"].append({
                "id": d,
                "status": det["Status"],
                "features_enabled": [x["Name"] for x in det.get("Features", []) if x["Status"] == "ENABLED"],
                "findings_last_30d_by_severity": dict(sev),
            })
            self.write("SI-4_guardduty_findings_30d", findings)
        self.write("SI-4_guardduty_detector", result)
        return result

    def inspector(self) -> dict:
        insp = self.client("inspector2")
        status = insp.batch_get_account_status(accountIds=[self.account_id]).get("accounts", [])
        sev = Counter()
        findings = []
        paginator = insp.get_paginator("list_findings")
        for page in paginator.paginate(filterCriteria={"findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}]}):
            for f in page.get("findings", []):
                sev[f["severity"]] += 1
                findings.append({
                    "arn": f["findingArn"], "severity": f["severity"], "title": f["title"], "type": f["type"],
                    "resource": f["resources"][0]["id"] if f.get("resources") else None,
                    "first_observed": f.get("firstObservedAt"),
                    "cvss": (f.get("inspectorScoreDetails") or {}).get("adjustedCvss", {}).get("score"),
                    "epss": (f.get("epss") or {}).get("score"),
                    "kev": bool((f.get("exploitAvailable") or "") == "YES"),
                    "fix_available": f.get("fixAvailable"),
                })
        self.write("RA-5_inspector_findings", {"status": status, "findings": findings})
        return {"resource_state": {k: v.get("status") for k, v in (status[0].get("resourceState", {}) if status else {}).items()}, "active_findings_by_severity": dict(sev)}

    def access_analyzer(self) -> dict:
        aa = self.client("accessanalyzer")
        analyzers = aa.list_analyzers().get("analyzers", [])
        out = []
        for a in analyzers:
            findings = []
            paginator = aa.get_paginator("list_findings_v2")
            for page in paginator.paginate(analyzerArn=a["arn"], filter={"status": {"eq": ["ACTIVE"]}}):
                findings += page.get("findings", [])
            out.append({"name": a["name"], "type": a["type"], "status": a["status"], "active_findings": len(findings), "sample": findings[:20]})
        self.write("AC-6_access_analyzer", out)
        return {a["name"]: {"type": a["type"], "active_findings": a["active_findings"]} for a in out}

    def cloudtrail(self) -> dict:
        ct = self.client("cloudtrail")
        trails = ct.describe_trails(includeShadowTrails=True).get("trailList", [])
        out = []
        for t in trails:
            try:
                st = ct.get_trail_status(Name=t["TrailARN"])
            except ClientError as exc:
                st = {"error": str(exc)}
            out.append({
                "name": t["Name"], "arn": t["TrailARN"], "organization": t.get("IsOrganizationTrail"), "multi_region": t.get("IsMultiRegionTrail"),
                "validation": t.get("LogFileValidationEnabled"), "kms": bool(t.get("KmsKeyId")), "cloudwatch_logs": bool(t.get("CloudWatchLogsLogGroupArn")),
                "is_logging": st.get("IsLogging"), "latest_delivery": st.get("LatestDeliveryTime"), "latest_delivery_error": st.get("LatestDeliveryError"),
            })
        self.write("AU-2_cloudtrail_trails", out)
        return {t["name"]: {"logging": t["is_logging"], "org": t["organization"], "validation": t["validation"], "error": t["latest_delivery_error"]} for t in out}

    def encryption(self) -> dict:
        kms = self.client("kms")
        ec2 = self.client("ec2")
        s3 = self.s3_client()
        s3control = self.client("s3control")

        keys = []
        for alias in kms.get_paginator("list_aliases").paginate().build_full_result().get("Aliases", []):
            if alias["AliasName"].startswith("alias/aws/") or "TargetKeyId" not in alias:
                continue
            meta = kms.describe_key(KeyId=alias["TargetKeyId"])["KeyMetadata"]
            rot = kms.get_key_rotation_status(KeyId=alias["TargetKeyId"])
            keys.append({"alias": alias["AliasName"], "arn": meta["Arn"], "state": meta["KeyState"], "rotation_enabled": rot.get("KeyRotationEnabled"), "rotation_days": rot.get("RotationPeriodInDays")})

        ebs_default = ec2.get_ebs_encryption_by_default()["EbsEncryptionByDefault"]
        try:
            account_pab = s3control.get_public_access_block(AccountId=self.account_id)["PublicAccessBlockConfiguration"]
        except ClientError:
            account_pab = None

        buckets = []
        for b in s3.list_buckets().get("Buckets", []):
            name = b["Name"]
            if "fedramp" not in name:
                continue
            item = {"bucket": name}
            try:
                item["sse"] = s3.get_bucket_encryption(Bucket=name)["ServerSideEncryptionConfiguration"]["Rules"][0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"]
            except ClientError:
                item["sse"] = None
            try:
                item["versioning"] = s3.get_bucket_versioning(Bucket=name).get("Status")
            except ClientError:
                item["versioning"] = None
            try:
                item["object_lock"] = s3.get_object_lock_configuration(Bucket=name)["ObjectLockConfiguration"].get("Rule", {}).get("DefaultRetention")
            except ClientError:
                item["object_lock"] = None
            try:
                pab = s3.get_public_access_block(Bucket=name)["PublicAccessBlockConfiguration"]
                item["public_access_block"] = all(pab.values())
            except ClientError:
                item["public_access_block"] = None
            buckets.append(item)

        self.write("SC-28_encryption_at_rest", {"kms_keys": keys, "ebs_encryption_by_default": ebs_default, "account_public_access_block": account_pab, "buckets": buckets})
        return {
            "kms_keys_rotating": sum(1 for k in keys if k["rotation_enabled"]), "kms_keys": len(keys),
            "ebs_encryption_by_default": ebs_default,
            "account_public_access_block": bool(account_pab and all(account_pab.values())),
            "buckets_sse": {b["bucket"]: b["sse"] for b in buckets},
        }

    def alarms(self) -> dict:
        cw = self.client("cloudwatch")
        alarms = cw.get_paginator("describe_alarms").paginate(AlarmNamePrefix="fedramp").build_full_result().get("MetricAlarms", [])
        history = cw.describe_alarm_history(StartDate=datetime.now(timezone.utc) - timedelta(days=7), HistoryItemType="StateUpdate", MaxRecords=100).get("AlarmHistoryItems", [])
        self.write("AU-6_cloudwatch_alarms", {"alarms": [{"name": a["AlarmName"], "state": a["StateValue"], "actions": a.get("AlarmActions")} for a in alarms], "state_changes_7d": history})
        return {"alarms": len(alarms), "in_alarm": [a["AlarmName"] for a in alarms if a["StateValue"] == "ALARM"], "state_changes_last_7d": len(history)}

    def drift(self) -> dict:
        tf_dir = ROOT / "terraform"
        proc = subprocess.run(["terraform", "plan", "-detailed-exitcode", "-input=false", "-no-color", "-lock=false"], cwd=tf_dir, capture_output=True, text=True, timeout=900)
        status = {0: "no drift", 1: "error", 2: "DRIFT"}.get(proc.returncode, str(proc.returncode))
        (self.out / "CM-2_terraform_drift.txt").write_text(proc.stdout[-20000:] + proc.stderr[-5000:], encoding="utf-8")
        return {"exit_code": proc.returncode, "status": status}

    # ------------------------------------------------------------------
    # summary

    def write_summary(self, extra: dict) -> None:
        lines = [
            "# Continuous monitoring evidence",
            "",
            f"Collected {utc_now()} from account {self.account_id}, region {self.region}, FIPS endpoints: {self.cfg.use_fips_endpoint}.",
            "",
            "| Source | Control(s) | Result |",
            "|---|---|---|",
        ]
        mapping = {
            "security_hub": "CA-2, CA-7, CM-6", "config": "CM-2, CM-6, CM-8", "iam": "AC-2, IA-2, IA-5", "guardduty": "SI-3, SI-4",
            "inspector": "RA-5, SI-2", "access_analyzer": "AC-2(3), AC-6", "cloudtrail": "AU-2, AU-9, AU-12", "encryption": "SC-12, SC-28",
            "alarms": "AU-6, SI-4(5)", "drift": "CM-2, CM-3",
        }
        for name, controls in mapping.items():
            if name in self.summary:
                lines.append(f"| {name} | {controls} | `{json.dumps(self.summary[name], default=default_json)[:400]}` |")
            elif name in self.errors:
                lines.append(f"| {name} | {controls} | ERROR: {self.errors[name][:200]} |")
        lines += ["", "## Files", ""]
        for p in sorted(self.out.iterdir()):
            if p.name != "summary.md":
                lines.append(f"- `{p.name}` ({p.stat().st_size} bytes)")
        if extra:
            lines += ["", "## Notes", ""] + [f"- {k}: {v}" for k, v in extra.items()]
        (self.out / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (self.out / "summary.json").write_text(json.dumps({"collected": utc_now(), "account": self.account_id, "region": self.region, "summary": self.summary, "errors": self.errors}, indent=2, default=default_json), encoding="utf-8")

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--profile", default=os.environ.get("AWS_PROFILE"))
    ap.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    ap.add_argument("--out", default=None, help="output directory (default evidence/output/<date>)")
    ap.add_argument("--drift", action="store_true", help="run terraform plan -detailed-exitcode (needs state access)")
    args = ap.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    out_dir = pathlib.Path(args.out) if args.out else ROOT / "evidence" / "output" / datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out_dir.mkdir(parents=True, exist_ok=True)

    c = Collector(session, args.region, out_dir)
    print(f"Collecting evidence for account {c.account_id} in {args.region} -> {out_dir}")
    for name, fn in [
        ("cloudtrail", c.cloudtrail), ("iam", c.iam), ("encryption", c.encryption), ("alarms", c.alarms),
        ("config", c.config), ("security_hub", c.security_hub), ("guardduty", c.guardduty),
        ("inspector", c.inspector), ("access_analyzer", c.access_analyzer),
    ]:
        c.run(name, fn)
    if args.drift:
        c.run("drift", c.drift)
    c.write_summary(c.notes)
    print(f"Done. {len(c.summary)} sources collected, {len(c.errors)} errors. Summary: {out_dir / 'summary.md'}")
    return 1 if c.errors else 0

if __name__ == "__main__":
    sys.exit(main())
