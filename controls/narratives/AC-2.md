# AC-2 Account Management

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Access Control | Moderate | Customer | Partially implemented (Identity Center resources code-only in the lab) |

## Control summary

Define account types, assign account managers, require approvals, create,
enable, modify, disable and remove accounts according to policy, monitor
account use, notify managers on personnel changes, authorize access based on
need, review accounts, and establish a shared-account credential process.

## FedRAMP Rev 5 parameters

- Account types: individual (human via Identity Center), service (IAM role assumed by AWS services), machine (OIDC-federated CI).
- Review frequency: at least every 90 days (AC-2 j), with automated input from the unused-access analyzer.
- Notification of account managers: within 24 hours of personnel change (procedural).

## Implementation

**Part a (account types).** Three types exist. Humans use IAM Identity Center
only; the design target is zero IAM users with passwords or access keys. AWS
services use IAM roles with trust policies conditioned on `aws:SourceAccount`
or `aws:SourceArn`. CI uses GitHub OIDC federation into two purpose-built
roles.

**Part b, c (managers, conditions).** Group ownership is assigned per Identity
Center group (ReadOnly, SecurityAuditors, SecurityAdmins, Developers). A new
engineer is added to exactly one group; membership requires the group owner's
approval in the ticketing system (procedural).

**Part d, e, f (attributes, approvals, lifecycle).** Access is granted to
groups, never to individuals, so joiner, mover and leaver are group membership
changes. Permission sets define privileges per group with session lengths from
1 hour (SecurityAdmin) to 8 hours (ReadOnly). The permission set for
developers carries a permissions boundary that prevents creating IAM principals
without the same boundary.

**Part g (monitoring).** CloudTrail records every Identity Center and IAM
change. A CloudWatch alarm on IAM policy changes and the root-usage alarm
notify the alerts topic within five minutes.

**Part h, i (notifications, authorization).** Procedural, tied to HR offboarding;
the technical action is removing the group membership, which revokes all
permission sets at once.

**Part j (review).** The IAM Access Analyzer unused-access analyzer reports
roles, users, access keys and permissions idle for 90 days. The NIST 800-53
conformance pack flags IAM user credentials unused for 35 days (FedRAMP
assignment for AC-2(3)). The weekly evidence export (Day 5) captures the
credential report and the group membership list for the quarterly review.

**Part k (shared accounts).** Not used. The AWS root user is the only shared
credential; it is denied by SCP in member accounts and alarmed on use.

## Evidence

| Artifact | Collection |
|---|---|
| IAM credential report showing no human users with keys | `aws iam generate-credential-report` then `get-credential-report` (evidence/collect.py) |
| Identity Center groups and account assignments | `aws sso-admin list-account-assignments`, `aws identitystore list-group-memberships` |
| Unused-access findings | `aws accessanalyzer list-findings-v2 --analyzer-arn <unused-access>` |
| Alarm history for `iam-policy-changes` and `root-account-usage` | `aws cloudwatch describe-alarm-history` |
| Terraform definitions of groups and permission sets | `terraform/modules/identity/identity_center.tf` |

## Terraform

- `modules/identity/identity_center.tf`: permission sets, groups, assignments, permissions boundary
- `modules/identity/main.tf`: OIDC provider and roles, password policy
- `modules/detection/access_analyzer.tf`: unused-access analyzer
- `modules/logging/alarms.tf`: IAM and root alarms

## Gaps and POA&M

1. Identity Center resources are code-only in the lab because Identity Center is delegated to a separate identity account. Apply from that account or register the Security Tooling account as the Identity Center delegated administrator.
2. Two IAM users with access keys exist for bootstrap (`bootstrap-lab`, `bootstrap-mgmt`). Replace with Identity Center users and delete the keys. Target: before the assessment.
3. The quarterly review record is a procedure; the evidence export produces the input but the sign-off is manual.
