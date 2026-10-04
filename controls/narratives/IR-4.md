# IR-4 Incident Handling

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Incident Response | Moderate | Customer | Implemented (runbooks pending Day 5) |

Enhancements addressed: IR-4(1) automated incident handling processes, IR-4(4)
information correlation; IR-4(2) dynamic reconfiguration (quarantine security
group).

## Control summary

Implement an incident handling capability covering preparation, detection and
analysis, containment, eradication and recovery; coordinate with contingency
planning; incorporate lessons learned.

## FedRAMP Rev 5 parameters

- Incident handling capability aligned with NIST SP 800-61.
- Lessons learned incorporated into procedures after every incident and at least annually (tabletop).

## Implementation

Mapped to the NIST 800-61 phases:

**Preparation.** Logging and detection are on everywhere (AU-2, SI-4). The
quarantine security group exists in every VPC in advance. Runbooks (Day 5)
define roles, decision points and commands. The containment function can run
in dry-run mode for tabletop exercises without touching resources.

**Detection and analysis.** GuardDuty produces findings with severity, type,
resource and threat intelligence context within minutes; Security Hub
correlates them with Inspector vulnerabilities, Access Analyzer exposure and
Config compliance on the same resource (IR-4(4)). CloudTrail, flow logs, WAF
logs and database audit logs provide the investigative record.

**Containment (IR-4(1), IR-4(2)).** For High and Critical GuardDuty findings
on IAM access keys or EC2 instances, EventBridge invokes the containment
Lambda within seconds:

| Resource | Automated action | Reversal |
|---|---|---|
| IAM access key | key set Inactive; inline `GuardDutyContainmentDenyAll` policy attached to the user (revokes active sessions); user tagged | delete inline policy, reactivate or rotate key |
| EC2 instance | EBS volumes snapshotted for forensics; security groups replaced with the VPC quarantine group (no ingress, no egress); instance tagged | restore original security groups from the CloudTrail record |
| Root credentials | no automated action; immediate page | n/a |

Every action, success or failure, is reported to the alerts topic with the
finding ID and the runbook to follow. Failures retry three times and then
land in a KMS-encrypted dead-letter queue.

**Eradication and recovery.** Human-driven per runbook: rotate credentials,
rebuild the instance from the pipeline (never patch a compromised host in
place), restore data from Aurora point-in-time recovery if needed, verify
with GuardDuty that no new findings appear.

**Post-incident.** Findings are archived in Security Hub with workflow
status RESOLVED and a note; the runbook includes a post-mortem template
(Day 5); lessons feed the next tabletop.

**Test record.** On 4 October 2026 two GuardDuty sample findings
(`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`,
`Backdoor:EC2/C&CActivity.B!DNS`, both severity 8) triggered the rule twice;
the function classified each, determined the sample resources were not real,
and reported to the topic with no errors. This is the evidence of the
detection-to-containment chain.

## Evidence

| Artifact | Collection |
|---|---|
| EventBridge rule and target configuration | `aws events describe-rule`, `list-targets-by-rule` |
| Lambda invocation metrics and logs for the test | `aws cloudwatch get-metric-statistics --namespace AWS/Lambda`, `aws logs filter-log-events` |
| SNS report messages | alerts mailbox / on-call tool |
| Quarantine security group (no rules) | `aws ec2 describe-security-groups --filters Name=tag:Purpose,Values=quarantine` |
| Security Hub GuardDuty.1 | Security Hub export |
| Runbooks IR-001, IR-002 | `runbooks/` |

## Terraform

- `modules/respond/main.tf`, `modules/respond/src/handler.py`
- `modules/detection/guardduty.tf`, `modules/detection/alerts.tf`
- `modules/network/main.tf` (quarantine security group)

## Gaps and POA&M

1. Runbooks IR-001 and IR-002 and the post-mortem template are Day 5 deliverables.
2. Containment covers IAM keys and EC2 instances; container (EKS) findings are handled in Project 2 (pod isolation via NetworkPolicy).
3. The on-call integration (SquadCast in the target environment) replaces email as the SNS subscriber.
