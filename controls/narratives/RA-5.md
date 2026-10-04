# RA-5 Vulnerability Monitoring and Scanning

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Risk Assessment | Moderate | Customer (scanner operated by AWS) | Implemented (POA&M automation Day 5) |

Enhancements addressed: RA-5(2) update vulnerabilities to be scanned, RA-5(5)
privileged access, RA-5(11) public disclosure program (procedural).

## Control summary

Monitor and scan for vulnerabilities in the system and hosted applications,
analyze reports, remediate within defined timeframes, and share information.

## FedRAMP Rev 5 parameters

- Scan frequency: monthly for OS, database and web application; continuously where tooling allows; after new vulnerabilities are announced.
- Remediation timeframes: High (CVSS 7.0 to 10.0) within 30 days, Moderate (4.0 to 6.9) within 90 days, Low within 180 days of discovery.
- Scans must be authenticated (credentialed) or equivalent.

## Implementation

**Infrastructure and workloads (continuous).** Amazon Inspector is enabled
for EC2 (agentless through SSM and EBS snapshot scanning, which satisfies the
credentialed-scan requirement), ECR container images (on push and
continuously as the database updates) and Lambda functions and layers.
Findings carry CVSS, EPSS probability and the CISA KEV flag.

**Configuration (continuous).** Security Hub (FSBP, NIST 800-53 R5, NIST
800-171 R2) and the Config conformance pack report misconfigurations as
findings with severity.

**Infrastructure code (pre-deployment).** checkov runs on every push; a
failing check blocks the merge unless suppressed with a written reason.

**Web application (target environment).** The pipeline adds Semgrep (SAST)
and PHPStan for the PHP application, Dependabot for dependencies, and
periodic DAST and annual penetration testing with retest; WAF managed rules
provide virtual patching in front of the application.

**RA-5(2).** Inspector's vulnerability database and WAF managed rule groups
are updated by AWS; no customer action.

**RA-5(5).** Inspector does not use scanning credentials; it reads EBS
snapshots and SSM inventory with its service-linked role.

**Prioritization and SLA.** Findings are ordered by: CISA KEV (exploited in
the wild) first, then EPSS above 0.1, then CVSS, then exposure (public
subnet, internet-facing). The POA&M generator (Day 5) assigns the FedRAMP due
date (30/90/180 days from first observed) and owner; the VM runbook defines
the weekly triage, exception handling and risk acceptance path.

**Reporting.** Inspector and Security Hub findings are exported weekly by the
evidence workflow and become the monthly ConMon vulnerability deliverable
(scan results, POA&M, inventory).

## Evidence

| Artifact | Collection |
|---|---|
| Inspector coverage and status | `aws inspector2 batch-get-account-status`, `list-coverage` |
| Findings with CVSS/EPSS/KEV | `aws inspector2 list-findings` |
| Security Hub Inspector.1 to Inspector.4 | Security Hub export |
| checkov results | CI artifact |
| POA&M with due dates | `evidence/poam.py` output (Day 5) |

## Terraform

- `modules/detection/inspector.tf`, `modules/detection/securityhub.tf`, `modules/detection/config_conformance.tf`
- `.github/workflows/plan.yml`

## Gaps and POA&M

1. POA&M generator and VM runbook are Day 5.
2. No EC2, ECR or Lambda application workloads exist in the lab yet, so Inspector has nothing to report; Project 2 adds images and nodes.
3. Application SAST/DAST and penetration testing are program activities outside this repository.
