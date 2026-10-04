# Control implementation

How every NIST SP 800-53 Rev 5 control this baseline touches is implemented,
where the implementation lives in Terraform, and what an assessor can collect
as evidence. This is the material that feeds the System Security Plan (SSP).

## Files

| File | Purpose |
|---|---|
| `control-matrix.csv` | One row per control (or enhancement): responsibility, implementation summary, Terraform resources, Security Hub / Config checks, evidence artifact, status. Import into the SSP tracker or GRC tool. |
| `narratives/<control>.md` | SSP-style control narratives for the controls an assessor spends the most time on: control text, FedRAMP parameter values, implementation by part (a, b, c), evidence, gaps. |

## Responsibility model

| Responsibility | Meaning | Example |
|---|---|---|
| `inherited` | Fully satisfied by the AWS FedRAMP authorization (us-east/us-west, FedRAMP High) and leveraged as-is. Evidence is the AWS FedRAMP package via AWS Artifact. | PE-3 physical access, MP-6 media sanitisation, KMS HSM FIPS validation |
| `shared` | AWS provides the mechanism, the customer must configure and operate it. | AU-9: S3 Object Lock exists, we must enable it; SC-28: KMS exists, we must encrypt with it |
| `customer` | Entirely the customer's implementation on top of AWS primitives. | AC-2 account lifecycle in Identity Center, IR-4 containment Lambda, runbooks |
| `organizational` | Policy, procedure, training or personnel controls. Not implementable in Terraform; referenced so the matrix is complete. | AC-1 policy, AT-2 awareness training (KnowBe4), PS-3 screening |

## Status values

| Status | Meaning |
|---|---|
| `implemented` | Applied in the lab and verifiable with the listed evidence. |
| `partial` | Mechanism in place, a documented gap remains (see POA&M). |
| `code-only` | Written and validated, not applied in the lab for an account-layout or cost reason (SCPs, Identity Center permission sets). |
| `planned` | Belongs to Day 5 or production (evidence automation, AWS Backup, custom domain). |
| `n/a-lab` | Organizational control or one with no lab representation. |

## How the evidence column works

Every `evidence` value is one of:

- a Security Hub control ID (`IAM.7`, `CloudTrail.1`): the finding history is the evidence, exported by `evidence/collect.py`
- a Config rule name from the NIST 800-53 Rev 5 conformance pack
- a CLI command whose output is captured by `evidence/collect.py`
- a file in this repository (`docs/resource-inventory.md`, a runbook, a workflow run)

The matrix is the contract between the engineer and the assessor: if a row says
"implemented", the evidence column says exactly how to prove it.

## Security Hub control IDs used

Security Hub's NIST SP 800-53 Rev 5 standard maps each of its controls to one
or more 800-53 controls. The IDs in the matrix are the ones enabled in this
account; the full mapping is in the Security Hub console under the standard,
and `evidence/collect.py` exports it.
