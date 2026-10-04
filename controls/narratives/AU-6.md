# AU-6 Audit Record Review, Analysis, and Reporting

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Audit and Accountability | Moderate | Customer | Implemented |

Enhancements addressed: AU-6(1) automated process integration, AU-6(3)
correlate audit record repositories.

## Control summary

Review and analyze audit records for indications of inappropriate or unusual
activity, report findings, and adjust the level of review based on risk.

## FedRAMP Rev 5 parameters

- Review frequency: at least weekly, with automated analysis continuously.
- Report to: the security team / ISSO; incident reporting per IR-6.

## Implementation

**Continuous automated analysis.**

1. Fourteen CloudWatch metric filters on the CloudTrail log group raise an
   alarm within five minutes on: unauthorized API calls, console sign-in
   without MFA, root usage, IAM policy changes, CloudTrail changes, console
   authentication failures, KMS key disable or deletion, S3 bucket policy
   changes, Config changes, security group changes, NACL changes, gateway
   changes, route table changes and VPC changes. Each alarm notifies the
   KMS-encrypted alerts topic.
2. GuardDuty analyses CloudTrail, DNS, flow, S3, EKS, RDS, Lambda and runtime
   telemetry with threat intelligence and anomaly models; findings publish
   every 15 minutes.
3. Security Hub evaluates configuration controls continuously against three
   standards and ingests GuardDuty, Inspector and Access Analyzer findings.

**AU-6(1): integration.** EventBridge routes GuardDuty findings of severity 7
and above to the alerts topic and, for IAM-key and EC2 findings, to the
containment Lambda; Security Hub CRITICAL and HIGH findings from vulnerability
and access products go to the alerts topic. Compliance findings are
deliberately excluded from paging and handled through the POA&M.

**AU-6(3): correlation.** The organization trail and the organization Config
aggregator bring every account's audit and configuration records into the
Security Tooling account. Security Hub correlates findings per resource. In
the target environment Datadog receives copies of the logs for cross-source
correlation and dashboards.

**Weekly human review.** The Day 5 evidence workflow exports alarm history,
new findings and the Security Hub summary every week; the on-call engineer
reviews it and records the review in the ticketing system (procedural).

## Evidence

| Artifact | Collection |
|---|---|
| Alarm definitions and history | `aws cloudwatch describe-alarms`, `describe-alarm-history` |
| EventBridge rules and targets | `aws events list-rules`, `list-targets-by-rule` |
| Security Hub CloudWatch.1 to CloudWatch.14 | Security Hub export |
| Aggregator and organization trail configuration | `aws configservice describe-configuration-aggregators`; management-account `describe-trails` |
| SNS delivery metrics | `aws cloudwatch get-metric-statistics --namespace AWS/SNS` |

## Terraform

- `modules/logging/alarms.tf`
- `modules/detection/alerts.tf`, `modules/detection/config_aggregator.tf`
- `modules/respond/main.tf`

## Gaps and POA&M

- Alarms fire on legitimate Terraform changes (observed during the Day 3 apply). Production tuning: exclude the deployment role's session from the IAM, SG and VPC change filters, or suppress alarms during approved change windows.
- The weekly review record is procedural until the evidence workflow (Day 5) exists.
