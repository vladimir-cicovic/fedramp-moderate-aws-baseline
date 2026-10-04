# AC-6 Least Privilege

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Access Control | Moderate | Customer | Implemented (SCPs and permission sets code-only in the lab) |

Enhancements in the Moderate baseline addressed here: AC-6(1) authorize access
to security functions, AC-6(2) non-privileged access for non-security
functions, AC-6(5) privileged accounts, AC-6(9) log privileged functions,
AC-6(10) prohibit non-privileged users from executing privileged functions.

## Control summary

Employ the principle of least privilege, allowing only authorized accesses
necessary to accomplish assigned tasks.

## Implementation

**Roles are purpose-built.** No role carries `AdministratorAccess` except the
temporary bootstrap users. Examples of scoping:

| Principal | Allowed | Scoped to |
|---|---|---|
| `github-plan` role | `ReadOnlyAccess`, `SecurityAudit` | any branch of one repository (`sub` condition) |
| `github-evidence` role | ~90 explicit read actions | `main` branch of one repository |
| Containment Lambda role | `iam:UpdateAccessKey`, `iam:PutUserPolicy`, `iam:TagUser` | `user/*` only; `sns:Publish` to one topic; KMS on one key |
| Config recorder role | AWS managed `AWS_ConfigRole` plus PutObject | one bucket prefix, one key |
| Flow logs role | `logs:CreateLogStream`, `logs:PutLogEvents` | one log group |
| CloudTrail to CloudWatch role | `logs:CreateLogStream`, `logs:PutLogEvents` | one log group |

**AC-6(1), AC-6(10): security functions.** Only the SecurityAdmin permission
set can modify GuardDuty, Security Hub, Config, CloudTrail, Inspector, Access
Analyzer and KMS. The developer permission set explicitly denies those
services and the organization APIs. In member accounts the
protect-security-services SCP denies the same actions to everyone except the
SecurityAdmin role ARN pattern.

**AC-6(2): non-privileged access.** Engineers use ReadOnly or Developer
permission sets for daily work and switch to SecurityAdmin (1-hour session)
only for security changes.

**AC-6(5): privileged accounts.** Root is denied by SCP in member accounts
and alarmed on any use. The management account holds nothing but SCPs and the
organization trail. Bootstrap IAM users are temporary.

**AC-6(9): logging.** CloudTrail captures every privileged call with the
assumed-role session name, which Identity Center sets to the user's identity.

**Boundaries.** The developer permission set carries a permissions boundary
that (a) denies security tooling, (b) denies creating IAM roles or users
unless the same boundary is attached, (c) denies editing the boundary. This
closes the classic escalation path of creating a role with broader rights.

## Evidence

| Artifact | Collection |
|---|---|
| IAM policy documents | repository (`terraform/modules/*/`) and `aws iam get-role-policy` |
| Security Hub IAM.1, IAM.21, Lambda.1 | Security Hub export |
| Permission set definitions and boundary | `aws sso-admin describe-permission-set`, `aws iam get-policy-version` |
| SCP content | `aws organizations describe-policy` (management profile) |
| Access Analyzer unused-permissions findings | `aws accessanalyzer list-findings-v2` |

## Terraform

- `modules/identity/identity_center.tf` (SecurityAdmin inline policy, developer boundary)
- `modules/identity/main.tf` (OIDC roles)
- `modules/respond/main.tf`, `modules/logging/config.tf`, `modules/network/flow_logs.tf`
- `modules/org/main.tf` (protect-security-services SCP)

## Gaps and POA&M

1. Bootstrap IAM users with `AdministratorAccess` (`bootstrap-lab`, `bootstrap-mgmt`) must be removed after the lab is handed to Identity Center users.
2. `AWSManagedRulesCommonRuleSet`-style broad managed policies (`ReadOnlyAccess`) are used for the plan role; a production hardening step is to replace them with a generated least-privilege policy from CloudTrail usage (IAM Access Analyzer policy generation).
