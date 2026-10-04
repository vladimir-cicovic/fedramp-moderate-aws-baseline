# CM-7 Least Functionality

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Configuration Management | Moderate | Customer | Implemented (region SCP applied through the management script; module code-only) |

Enhancements addressed: CM-7(1) periodic review, CM-7(2) prevent program
execution (partially, through WAF and SCP), CM-7(5) authorized software
(deferred to Project 2 image signing).

## Control summary

Configure the system to provide only mission-essential capabilities; prohibit
or restrict the use of unnecessary functions, ports, protocols, software and
services.

## FedRAMP Rev 5 parameters

- Prohibited or restricted functions, ports, protocols: per the PPS table in `docs/authorization-boundary.md`; review at least annually and on significant change.

## Implementation

**Regions.** A service control policy allows regional API calls only in
us-east-1 (and the regions listed in `allowed_regions`); everything else is
denied with a `NotAction` exemption for global services. In the live
organization the equivalent AWS-generated policy was edited by
`scripts/management/Configure-MemberAccount.ps1` to the same effect.

**Network functions.**

- No NAT gateway and no default route in private or data route tables: nothing inside the boundary can open connections to the internet.
- NACLs admit only enumerated flows per tier; the ephemeral return range is split so 3389 is never admitted from the internet; 22 is never admitted anywhere.
- The default security group has no rules; the quarantine group has no rules.
- Only four interface endpoint services exist (KMS, Secrets Manager, STS, Logs) plus S3 and DynamoDB gateways; adding a service is a reviewed code change.

**Edge functions.** CloudFront allows only GET, HEAD and OPTIONS; HTTP is
redirected to HTTPS; the origin accepts requests only from the distribution.
WAF blocks known-bad inputs, SQL injection patterns and abusive request rates.

**Account functions.** The protect-security-services SCP removes the ability
to disable logging and detection; the deny-root SCP removes root use; the
developer permission boundary removes security tooling and IAM escalation
from daily accounts.

**Service functions.** Aurora exposes no public endpoint and refuses
plaintext connections; Lambda has a single trigger (one EventBridge rule) and
a dead-letter queue; S3 buckets have ACLs disabled.

**CM-7(1) review.** The PPS table and the NACL/SG inventory are regenerated
from state by `scripts/inventory.py`; the annual review compares them with the
boundary document.

## Evidence

| Artifact | Collection |
|---|---|
| SCP content | `aws organizations describe-policy` (management profile) |
| NACLs, route tables, security groups | `aws ec2 describe-network-acls`, `describe-route-tables`, `describe-security-groups`; `docs/resource-inventory.md` |
| NAT gateways (expected none) | `aws ec2 describe-nat-gateways` |
| CloudFront allowed methods, WAF rules | `aws cloudfront get-distribution-config`, `aws wafv2 get-web-acl` |
| Security Hub EC2.2, EC2.19, EC2.21 | Security Hub export |

## Terraform

- `modules/org/main.tf` (deny-regions, protect-security-services, deny-root, require-imdsv2)
- `modules/network/main.tf`, `modules/network/endpoints.tf`
- `modules/edge/main.tf`, `modules/edge/waf.tf`
- `modules/data/main.tf`

## Gaps and POA&M

- `modules/org` SCPs are code-only in the lab; the live policies are the AWS-generated ones plus the script's edit.
- CM-7(5) authorized software (allow-listing) is addressed by image signing and Kyverno admission control in Project 2.
