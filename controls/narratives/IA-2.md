# IA-2 Identification and Authentication (Organizational Users)

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Identification and Authentication | Moderate | Customer | Partially implemented (MFA on lab bootstrap identities outstanding) |

Enhancements addressed: IA-2(1) MFA to privileged accounts, IA-2(2) MFA to
non-privileged accounts, IA-2(8) replay resistant, IA-2(12) PIV credentials
(not applicable to a commercial SaaS; documented).

## Control summary

Uniquely identify and authenticate organizational users and associate that
identity with processes acting on their behalf.

## FedRAMP Rev 5 parameters

- MFA for all network access to privileged and non-privileged accounts.
- Phishing-resistant MFA is the FedRAMP goal (FIDO2 / WebAuthn); TOTP is accepted for Moderate with a plan toward phishing-resistant.

## Implementation

**Unique identity.** Every human authenticates through IAM Identity Center.
In production Identity Center federates to the corporate IdP (Okta or Entra
ID) with SCIM provisioning, so the corporate identity is the AWS identity.
When a user assumes a permission set, STS sets the role session name to the
user's identity, and that name appears in every CloudTrail record. There are
no shared accounts; the root user is denied by SCP in member accounts and
alarmed on use.

**IA-2(1), IA-2(2): MFA.** Identity Center enforces MFA for every sign-in
(instance setting "Always-on", with FIDO2 security keys or authenticator
apps). Because all permission sets are reached through the same sign-in, MFA
covers privileged and non-privileged access alike. For any residual IAM user,
Security Hub IAM.5 and IAM.19 report MFA status and the CloudWatch alarm
`console-signin-without-mfa` pages on a non-MFA console login.

**IA-2(8): replay resistance.** Identity Center and STS issue short-lived,
signed session tokens; permission set sessions last 1 to 8 hours; OIDC
tokens from GitHub are single-use JWTs bound to a job.

**Non-human identities.** AWS services use roles with trust conditions; CI
uses OIDC federation; the Lambda uses its execution role. None of these hold
long-lived secrets (IA-5(7)).

**Database users.** Aurora IAM database authentication lets application
identities obtain short-lived tokens with their IAM role instead of passwords.

## Evidence

| Artifact | Collection |
|---|---|
| Identity Center MFA settings | Identity Center console (settings are not exposed through an API; screenshot in evidence) |
| Credential report showing MFA on any IAM user | `aws iam get-credential-report` |
| Security Hub IAM.5, IAM.19 | Security Hub export |
| Alarm `console-signin-without-mfa` definition and history | `aws cloudwatch describe-alarms` |
| CloudTrail record showing user identity in role session name | `aws cloudtrail lookup-events` sample |

## Terraform

- `modules/identity/identity_center.tf`
- `modules/identity/main.tf` (OIDC, password policy)
- `modules/logging/alarms.tf`
- `modules/data/main.tf` (`iam_database_authentication_enabled`)

## Gaps and POA&M

1. Bootstrap IAM users `bootstrap-lab` (workload account) and `bootstrap-mgmt` (management account) have no MFA; the account root users have no MFA. Enable MFA now, remove the users after Identity Center onboarding.
2. Identity Center MFA mode must be verified as "Always-on" in the identity account; it is not Terraform-manageable.
3. Phishing-resistant MFA (FIDO2) rollout is a program item.
