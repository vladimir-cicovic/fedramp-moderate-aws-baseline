# Evidence and POA&M automation

Continuous monitoring (ConMon) produces two artifacts an assessor and a
customer agency ask for every month: proof that the controls are operating,
and a Plan of Action and Milestones for everything that is not. Both are
generated here, read-only, through FIPS endpoints.

| Script | Produces | Controls |
|---|---|---|
| `collect.py` | `output/<date>/` with one JSON file per source (named by control family), the IAM credential report, and `summary.md` / `summary.json` | CA-7, AU-6, CM-8 and the evidence column of `controls/control-matrix.csv` |
| `poam.py` | `output/<date>/POAM.csv` in the FedRAMP template layout and `POAM.md` with open, overdue and accepted items | CA-5, RA-5, SI-2 |
| `poam-exceptions.csv` | Accepted deviations (operational requirement or false positive) with rationale and reference; matched by Security Hub control ID, generator ID or title | CA-5 deviation process |

## Run locally

```bash
pip install boto3
python evidence/collect.py --profile default --region us-east-1 --drift
python evidence/poam.py --profile default --region us-east-1
```

`--drift` runs `terraform plan -detailed-exitcode` and records whether the
account matches the code (CM-2, CM-3). It needs state access, so it is
local-only until the state moves to an S3 backend.

## Run in CI

`.github/workflows/evidence.yml` runs every Monday 06:00 UTC and on demand.
It assumes the `github-evidence` role through OIDC (main branch only), runs
both scripts, and uploads `evidence/output/<date>/` as a workflow artifact kept
for 90 days. Production sends the same files to an evidence bucket with Object
Lock; the output directory is not committed because it contains account details.

Required repository variables: `AWS_EVIDENCE_ROLE_ARN` (output
`identity.github_evidence_role_arn`), `AWS_REGION`.

## Reading the output

- `summary.md`: one table, one row per source, with the controls it supports and the headline numbers (pass rate, open failed controls, users without MFA, trails logging, keys rotating, alarms in ALARM, drift).
- `CA-7_securityhub_findings.json`: every active compliance finding with control ID, status, workflow state, resource and the NIST requirements it maps to. This is the raw material for control narratives' evidence tables.
- `AC-2_iam_credential_report.csv`: the credential report as AWS produces it.
- `POAM.csv`: import into the FedRAMP POA&M template or a GRC tool. `Scheduled Completion Date` is first observed plus 30/90/180 days by risk rating; `Status` is Open, Overdue, Risk accepted or False positive.

## Deviation process

A finding that will not be fixed needs a row in `poam-exceptions.csv` with
the type, the adjusted risk, the rationale and a reference to the narrative or
code that documents the compensating controls. The POA&M then reports it as an
accepted deviation instead of an open item. Pull-request review of that file
is the approval record.
