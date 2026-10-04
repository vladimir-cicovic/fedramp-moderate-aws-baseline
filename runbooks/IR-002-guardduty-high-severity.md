# IR-002 GuardDuty High or Critical finding (EC2, S3, EKS, RDS, Lambda, runtime)

| Trigger | Severity | Owner | Controls |
|---|---|---|---|
| Any GuardDuty finding with severity >= 7 that is not an IAM credential finding (those go to IR-001) | High | On-call security engineer; Security Lead as incident commander | IR-4, IR-4(2), IR-4(4), IR-5, IR-6, SI-3, SI-4 |

## 0. What already happened automatically

For **EC2 instance** findings with severity >= 7 the containment function has:

1. created a forensic snapshot of every EBS volume (tagged with the finding ID),
2. replaced the instance's security groups with the VPC quarantine group (no ingress, no egress),
3. tagged the instance `ContainmentStatus=Isolated`,
4. reported to the alerts topic.

For S3, EKS, RDS, Lambda and runtime findings on other resource types there is
no automated containment yet; the alert carries the finding and this runbook.

## 1. Triage (T+15 min)

```bash
aws guardduty get-findings --detector-id <detector> --finding-ids <id> --region us-east-1 \
  --query 'Findings[0].{type:Type,sev:Severity,res:Resource,svc:Service.Action,count:Service.Count,first:Service.EventFirstSeen,last:Service.EventLastSeen}'
```

Classify by finding family and pick the branch:

| Family (examples) | Meaning | Branch |
|---|---|---|
| `Backdoor:EC2/*`, `CryptoCurrency:EC2/*`, `Trojan:EC2/*`, `Execution:Runtime/*`, `Impact:EC2/*` | instance or container is compromised | 2A |
| `Recon:EC2/Portscan`, `UnauthorizedAccess:EC2/SSHBruteForce` (outbound) | instance attacking others | 2A |
| `Exfiltration:S3/*`, `Policy:S3/BucketAnonymousAccessGranted`, `Impact:S3/*` | bucket exposure or data theft | 2B |
| `*:Kubernetes/*`, `Execution:Kubernetes/*`, `PrivilegeEscalation:Kubernetes/*` | EKS workload or API abuse | 2C |
| `CredentialAccess:RDS/*`, `Discovery:RDS/*` | database credential attack | 2D |
| `*:Lambda/*` | function talking to a malicious host | 2E |
| `Discovery:*`, `Recon:*` inbound from internet, severity < 7 | noise, no page | close with note |

Check Security Hub for other findings on the same resource (Inspector
vulnerability, Access Analyzer exposure, Config non-compliance): they often
explain the entry point.

## 2. Containment

**2A. EC2 instance / runtime.**

```bash
# confirm isolation and snapshots done by automation
aws ec2 describe-instances --instance-ids <id> --query 'Reservations[0].Instances[0].{sg:SecurityGroups,tags:Tags}'
aws ec2 describe-snapshots --filters Name=tag:ContainmentFinding,Values=<finding id>

# if not isolated (no quarantine SG known for the VPC): do it now
aws ec2 modify-instance-attribute --instance-id <id> --groups <quarantine sg>
aws ec2 create-snapshot --volume-id <vol> --description "forensics <finding id>"

# revoke the instance role's sessions issued before now
aws iam put-role-policy --role-name <instance role> --policy-name RevokeOlderSessions --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*","Condition":{"DateLessThan":{"aws:TokenIssueTime":"<now>"}}}]}'
```

Do not stop or terminate yet: memory and the running process list are
evidence. If the instance is in an Auto Scaling group, detach it first so it
is not replaced and lost (`aws autoscaling detach-instances --should-decrement-desired-capacity`).

**2B. S3.** Re-apply the bucket's Terraform policy (`terraform apply`
restores the deny-non-TLS and principal conditions), confirm the account
public access block is on (`aws s3control get-public-access-block`), enable
S3 data events if not already logged, and identify the principal from
CloudTrail S3 data events; then follow IR-001 for that principal.

**2C. EKS.** Apply a deny-all `NetworkPolicy` to the pod's namespace, cordon
the node (`kubectl cordon`), capture `kubectl logs` and `kubectl get events`,
rotate the IRSA role's sessions as in 2A, and treat the node as 2A.

**2D. RDS.** Rotate the master secret in Secrets Manager (RDS-managed:
`aws secretsmanager rotate-secret --secret-id <arn>`), review
`/aws/rds/cluster/<id>/audit` for the source, restrict the DB security group
to known sources, consider disabling the compromised database user.

**2E. Lambda.** Set reserved concurrency to 0 to stop invocations
(`aws lambda put-function-concurrency --function-name <fn> --reserved-concurrent-executions 0`),
capture the function code (`aws lambda get-function` download URL) and its
log group, rotate the execution role's sessions.

## 3. Investigation

- CloudTrail: all calls from the instance role / principal since first seen.
- VPC Flow Logs: `/aws/vpc/flow-logs/<prefix>` for the instance's ENI, look for the C2 destination and data volumes (CloudWatch Logs Insights query below).
- WAF logs if the entry point was the web tier.
- Snapshot analysis on an isolated forensic instance (never in the production VPC).

```
fields @timestamp, srcAddr, dstAddr, dstPort, bytes, action
| filter srcAddr = "<private ip>" or dstAddr = "<private ip>"
| stats sum(bytes) as bytes by dstAddr, dstPort, action
| sort bytes desc
```

## 4. Eradication and recovery

Never clean a compromised host in place. Terminate it after evidence is
preserved and let the pipeline rebuild it from the trusted image (Project 2:
signed image, Kyverno verification). Patch the vulnerability that was used
(Inspector finding), rotate every secret the host could read, re-run
`terraform plan` to confirm the baseline, and watch GuardDuty for 24 hours.

Mark the Security Hub finding `RESOLVED` with the ticket reference; keep the
snapshot until the post-mortem closes, then delete it (it is encrypted with
the data key and tagged).

## 5. Reporting (IR-6)

Same as IR-001: internal record at each phase; one-hour external reporting
clock if CUI may have been exposed.

## 6. Post-mortem

Use the template in IR-001. Typical outcomes: a new Inspector-driven patch
SLA item, an image hardening change, a new WAF rule, an additional
containment branch in the Lambda.

## Tabletop

Run this runbook quarterly with `containment_dry_run = true` in
`terraform.tfvars` and `aws guardduty create-sample-findings` for one finding
type per branch; record who did what and how long it took.
