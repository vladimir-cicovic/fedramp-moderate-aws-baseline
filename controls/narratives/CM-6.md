# CM-6 Configuration Settings

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Configuration Management | Moderate | Customer | Implemented |

## Control summary

Establish, document and implement configuration settings using common secure
configurations, identify and approve deviations, and monitor and control
changes to the settings.

## FedRAMP Rev 5 parameters

- Common secure configurations: CIS Benchmarks or equivalent (here: CIS AWS Foundations Benchmark through Security Hub, AWS Foundational Security Best Practices, the AWS NIST 800-53 Rev 5 conformance pack).

## Implementation

**Settings are code.** Every secure setting is a Terraform attribute and
therefore version-controlled, reviewed and reproducible. Highlights:

| Area | Setting | Where |
|---|---|---|
| S3 | public access block (account and bucket), BucketOwnerEnforced, SSE-KMS, versioning, deny non-TLS, lifecycle | `modules/logging/s3.tf`, `modules/edge/main.tf` |
| EC2 | EBS encryption by default with CMK; IMDSv2 required by SCP; empty default security group | `modules/crypto`, `modules/org`, `modules/network` |
| KMS | yearly rotation, 7/30-day deletion window, conditioned key policies | `modules/logging/kms.tf`, `modules/crypto` |
| IAM | password policy 14/60/24, no access keys for CI, permission boundaries | `modules/identity` |
| CloudTrail | multi-region, validation, KMS, CloudWatch integration | `modules/logging/cloudtrail.tf` |
| Network | deny-by-default NACLs, no NAT, FIPS endpoints, flow logs | `modules/network` |
| Edge | HTTPS redirect, HSTS preload, CSP, HTTP/2+3, managed WAF rules, rate limit | `modules/edge` |
| Database | `require_secure_transport=ON`, audit logging, IAM auth, CMK, no public access | `modules/data` |
| Lambda | FIPS endpoints, DLQ, X-Ray, KMS-encrypted environment | `modules/respond` |

**Verified three ways.**

1. *Before deployment:* checkov runs on every push and pull request (565
   checks pass). Deviations are suppressed inline next to the resource with a
   written justification; nothing is suppressed globally. The suppression
   list is the "approved deviations" record for part c.
2. *Continuously:* Security Hub evaluates FSBP, NIST 800-53 R5 and NIST
   800-171 R2 controls; the Config conformance pack evaluates 130 NIST-mapped
   rules with FedRAMP parameter values (password policy, 35-day inactivity,
   90-day key rotation).
3. *Drift:* `terraform plan` is run by CI and by the evidence workflow; any
   difference between code and the account is a finding.

**Change control (part d).** Only Terraform changes settings; Config records
every configuration change with the identity that made it; CloudWatch alarms
fire on security-relevant changes.

## Evidence

| Artifact | Collection |
|---|---|
| checkov report (pass/fail/skip with justifications) | CI run artifact `checkov.sarif`; `grep -r "checkov:skip" terraform` |
| Security Hub FSBP and NIST summaries | Security Hub export |
| Conformance pack compliance | `aws configservice get-conformance-pack-compliance-summary` |
| Drift check | `terraform plan -detailed-exitcode` (exit 0) |
| Resource inventory with settings | `docs/resource-inventory.md` |

## Terraform

All modules; `.checkov.yaml`; `.github/workflows/plan.yml`.

## Gaps and POA&M

- CloudFront minimum TLS is TLSv1 with the default certificate (SC-8(1)); custom certificate pending.
- Hardened machine images (Bottlerocket FIPS, AL2023 with FIPS mode and CIS Level 1) are part of Project 2; no hosts exist in this baseline.
