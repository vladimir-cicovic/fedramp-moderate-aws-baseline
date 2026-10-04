# AC-3 Access Enforcement

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Access Control | Moderate | Shared (AWS enforces IAM; customer defines policies) | Implemented |

## Control summary

Enforce approved authorizations for logical access to information and system
resources in accordance with applicable access control policies.

## Implementation

Authorizations are expressed as code and enforced by AWS at every layer:

1. **Identity layer.** IAM policies on roles and permission sets are the only
   way to obtain permissions. Policies are purpose-built per workload
   (evidence collector, flow logs, Config, containment Lambda) and scoped to
   the resources and actions each needs. The developer permission set carries
   a permissions boundary.
2. **Organization layer.** Service control policies (code in `modules/org`)
   cap what any principal in a member account can do, regardless of IAM:
   no leaving the organization, no root use, no disabling of security
   services, no activity outside approved regions.
3. **Resource layer.** Every S3 bucket policy denies requests without TLS and
   restricts service principals with `aws:SourceArn` or `aws:SourceAccount`;
   the account-wide public access block makes public buckets impossible. KMS
   key policies grant service principals only the operations they need, under
   encryption-context conditions. The SNS topic policy allows publishing only
   from CloudWatch and EventBridge in this account. The SQS dead-letter queue
   accepts messages only from EventBridge and Lambda.
4. **Network layer.** Security groups and NACLs enforce tier-to-tier flows
   (see SC-7); the database accepts connections only from private subnets.
5. **Data layer.** Aurora requires TLS and supports IAM database
   authentication, so database authorization is tied to IAM identity.

Deny statements are explicit where a mistake would be expensive: non-TLS
access to audit buckets, security-tool changes by developers, and IAM
principal creation without a boundary.

## Evidence

| Artifact | Collection |
|---|---|
| Bucket, key, topic and queue policies | `aws s3api get-bucket-policy`, `aws kms get-key-policy`, `aws sns get-topic-attributes`, captured in evidence/collect.py |
| Security Hub controls S3.1, S3.2, S3.3, KMS.1, EC2.2 | Security Hub findings export |
| Access Analyzer external-access findings (should be empty) | `aws accessanalyzer list-findings --analyzer-arn <external-access>` |
| Resource inventory with encryption and policy attributes | `docs/resource-inventory.md` |

## Terraform

- `modules/identity/*.tf`, `modules/org/main.tf` (SCPs)
- `modules/logging/s3.tf`, `modules/logging/kms.tf`, `modules/logging/alarms.tf` (topic policy)
- `modules/respond/main.tf` (DLQ policy, Lambda role)
- `modules/network/main.tf` (security groups, NACLs)

## Gaps and POA&M

- SCPs are code-only in the lab; the live organization uses AWS-generated policies managed through `scripts/management/`.
- Application-level authorization (who may see which customer's data) belongs to the application and is out of scope here.
