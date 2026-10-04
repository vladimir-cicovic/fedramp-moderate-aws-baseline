# AU-9 Protection of Audit Information

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Audit and Accountability | Moderate | Shared (AWS provides Object Lock, KMS, CloudTrail validation; customer configures) | Implemented |

Enhancements addressed: AU-9(2) store on separate physical systems or
components, AU-9(4) access by subset of privileged users.

## Control summary

Protect audit information and audit logging tools from unauthorized access,
modification and deletion, and alert on detected attempts.

## Implementation

**Immutability.** The CloudTrail bucket has S3 Object Lock enabled with a
default retention rule. In production the mode is COMPLIANCE with a retention
of at least 365 days: no identity, including the account root, can delete or
overwrite a log object before the retention expires. The lab uses GOVERNANCE
mode with a 1-day retention so the environment can be torn down; the Terraform
variable `object_lock_mode` is the only difference.

**Integrity.** CloudTrail log file validation is enabled: every hour CloudTrail
writes a digest file containing SHA-256 hashes of the delivered log files,
signed with a CloudTrail private key. `aws cloudtrail validate-logs` proves
that no file was modified, deleted or inserted.

**Confidentiality.** All audit storage is encrypted with the customer managed
`logging` key: the two S3 buckets (SSE-KMS with bucket keys), every CloudWatch
Logs group, the Config delivery channel. The key policy grants CloudTrail
`GenerateDataKey` only under an encryption-context condition naming this
account's and the management account's trails, and `aws:SourceArn` naming the
exact trail ARNs.

**Access control.** Bucket policies deny any request without TLS and admit
only the CloudTrail and Config service principals for writes, each with
`aws:SourceArn` or `aws:SourceAccount` conditions. ACLs are disabled
(BucketOwnerEnforced). Versioning is on, so even an authorized overwrite keeps
the prior version. S3 server access logging records every request to the
audit buckets in a third bucket.

**Protection of the logging tools (AU-9 b).** The protect-security-services
SCP denies `cloudtrail:StopLogging`, `DeleteTrail`, `UpdateTrail`,
`PutEventSelectors`, `config:StopConfigurationRecorder`,
`DeleteDeliveryChannel`, `guardduty:DeleteDetector`,
`securityhub:DisableSecurityHub` and the KMS key deletion actions to every
principal in member accounts except the SecurityAdmin role. CloudWatch alarms
on CloudTrail configuration changes, Config changes and KMS key
disable/deletion alert the security team within five minutes.

**AU-9(2): separate system.** The organization trail, created in the
management account, delivers every account's logs to the WORM bucket owned by
the Security Tooling account. A compromise of a workload account cannot reach
its own historical logs; a compromise of the management account cannot delete
them either because the bucket and key belong to another account and the
Object Lock applies regardless.

**AU-9(4): privileged subset.** Only the SecurityAuditor and SecurityAdmin
permission sets include read access to the audit buckets and log groups; the
developer permission set denies the logging services.

## Evidence

| Artifact | Collection |
|---|---|
| Object Lock configuration | `aws s3api get-object-lock-configuration --bucket <trail bucket>` |
| Log file validation result | `aws cloudtrail validate-logs --trail-arn <arn> --start-time <date>` |
| Bucket encryption, versioning, policy, logging | `aws s3api get-bucket-encryption`, `get-bucket-versioning`, `get-bucket-policy`, `get-bucket-logging` |
| KMS key policy | `aws kms get-key-policy --key-id alias/fedramp-baseline-lab-logging --policy-name default` |
| SCP content and attachment | `aws organizations describe-policy` (management profile) |
| Security Hub CloudTrail.2, CloudTrail.4, CloudTrail.6, CloudTrail.7, S3.5, S3.9 | Security Hub export |

## Terraform

- `modules/logging/s3.tf`, `modules/logging/kms.tf`, `modules/logging/cloudtrail.tf`
- `terraform/management/main.tf` (organization trail)
- `modules/org/main.tf` (protect-security-services SCP)
- `modules/logging/alarms.tf`

## Gaps and POA&M

1. Lab Object Lock is GOVERNANCE / 1 day; production must set COMPLIANCE / 365+ (variable change only).
2. The protect-security-services SCP is code-only in the lab; the live organization's SCPs come from the AWS console setup.
3. Cross-region replication of the audit bucket (CP-9) is not configured.
