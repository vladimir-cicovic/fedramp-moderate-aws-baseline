# AU-2 Event Logging

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Audit and Accountability | Moderate | Shared (AWS generates records; customer enables and retains them) | Implemented |

## Control summary

Identify the event types the system is capable of logging, coordinate with
other entities, specify which event types are logged and how often, and
review the selection periodically.

## FedRAMP Rev 5 parameters

- Event types logged: successful and unsuccessful account logon events, account management events, object access, policy change, privilege functions, process tracking, system events; for web applications all administrator activity, authentication checks, authorization checks, data deletions, data access, data changes, permission changes.
- Review of logged event types: annually, and after any significant change.

## Implementation

Logging is on by default for every component Terraform creates; a component
without a log destination does not get merged.

| Source | What is logged | Destination | Control objective |
|---|---|---|---|
| CloudTrail account trail (`fedramp-baseline-lab-trail`) | All management events, S3 object-level data events (except the audit buckets themselves), multi-region, global services | WORM S3 bucket + CloudWatch Logs | account management, policy change, privileged functions, object access |
| CloudTrail organization trail (`fedramp-baseline-lab-org-trail`, management account) | Management events of every account in the organization | Same WORM bucket under `AWSLogs/<org-id>/` | organization-wide coverage, AU-9(2) |
| VPC Flow Logs | Accepted and rejected flows, 60-second aggregation | CloudWatch Logs (KMS) | network events, SI-4(4) |
| WAF | Every evaluated request with matched rules | CloudWatch Logs `aws-waf-logs-*` (KMS) | web attacks, SI-10 |
| CloudFront | Access logs (standard logging v2, JSON) | CloudWatch Logs (KMS) | web access |
| Aurora | `audit` (CONNECT, QUERY_DCL, QUERY_DDL), `error`, `slowquery` | CloudWatch Logs (KMS) | database authentication and privilege changes |
| Lambda containment | Decisions and actions per finding | CloudWatch Logs (KMS) | incident handling |
| AWS Config | Configuration history of every supported resource, daily snapshots | S3 (KMS) | CM-2, CM-8 |
| GuardDuty, Security Hub, Inspector, Access Analyzer | Findings | Security Hub, EventBridge | detection |

Every CloudTrail record contains the identity (including the Identity Center
user name in the session name), the time in UTC, the source address, the user
agent, the request parameters and the response (AU-3). Log file validation
produces signed SHA-256 digests hourly (AU-9, SI-7).

## Evidence

| Artifact | Collection |
|---|---|
| Trail configuration and status | `aws cloudtrail describe-trails`, `get-trail-status`, `get-event-selectors` |
| Flow log, WAF, CloudFront, Aurora log groups with KMS and retention | `aws logs describe-log-groups` |
| Security Hub CloudTrail.1, EC2.6, CloudFront.5, WAF.1, RDS.9 | Security Hub export |
| Sample events for each source | `aws cloudtrail lookup-events`, `aws logs filter-log-events` |

## Terraform

- `modules/logging/cloudtrail.tf`, `terraform/management/main.tf`
- `modules/network/flow_logs.tf`, `modules/edge/waf.tf`, `modules/edge/logging.tf`
- `modules/data/main.tf` (parameter group and export log groups)

## Gaps and POA&M

- Application logs (the PHP application in the target environment) are not represented in the lab; they must log authentication, authorization, data access and changes to CloudWatch Logs or the SIEM with the same retention.
- S3 data events for the organization trail are intentionally off (cost); the account trail covers the workload account.
