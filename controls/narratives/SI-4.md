# SI-4 System Monitoring

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| System and Information Integrity | Moderate | Customer (detection services operated by AWS) | Implemented |

Enhancements addressed: SI-4(2) automated tools for real-time analysis,
SI-4(4) inbound and outbound communications traffic, SI-4(5) system-generated
alerts.

## Control summary

Monitor the system to detect attacks, indicators of potential attacks and
unauthorized connections; identify unauthorized use; deploy monitoring at
strategic locations; protect monitoring information; obtain legal opinion as
required; provide monitoring information to designated personnel.

## FedRAMP Rev 5 parameters

- Monitoring objectives: unauthorized access, privilege misuse, malware, data exfiltration, configuration drift.
- Alerts delivered to the security team / on-call within 15 minutes of detection for High and Critical events.

## Implementation

**Where monitoring sits.**

| Location | Sensor | Covers |
|---|---|---|
| Account control plane | CloudTrail + 14 metric-filter alarms; GuardDuty CloudTrail analysis | privilege misuse, logging tampering, IAM changes, root use |
| Network | VPC Flow Logs; GuardDuty flow and DNS analysis | port scans, C2 beacons, exfiltration, unusual ports (SI-4(4)) |
| Storage | GuardDuty S3 protection; CloudTrail S3 data events | anomalous object access, policy changes |
| Compute | GuardDuty runtime monitoring (EC2, EKS, ECS), EBS malware protection; Inspector | malware, suspicious processes, vulnerabilities |
| Database | GuardDuty RDS protection; Aurora audit log | credential brute force, anomalous logins |
| Serverless | GuardDuty Lambda protection | functions talking to malicious hosts |
| Edge | WAF logs and metrics; CloudFront logs | web attacks, rate abuse |
| Configuration | Security Hub, Config conformance pack, Access Analyzer | drift, exposure, unused access |

**SI-4(2): real-time analysis.** GuardDuty publishes new findings within
minutes (15-minute publishing frequency for updates); CloudWatch alarms
evaluate every 5 minutes; EventBridge routes findings within seconds.

**SI-4(5): alerts.** High and Critical findings, all 14 alarm conditions and
every containment action reach the alerts topic (email in the lab, on-call
tool in production).

**Protection of monitoring information (SI-4 d).** Findings and logs are in
KMS-encrypted stores with restricted roles; the SCP prevents disabling the
sensors; Security Hub and GuardDuty are administered only by SecurityAdmin.

**Organization-wide.** The Security Tooling account is delegated
administrator for GuardDuty, Security Hub and Inspector, so member accounts
are monitored centrally and new accounts can be auto-enrolled.

**Target environment additions.** Datadog SIEM receives CloudTrail, flow,
WAF and application logs for cross-source detections and dashboards;
SentinelOne provides endpoint detection on corporate devices (outside this
boundary).

## Evidence

| Artifact | Collection |
|---|---|
| GuardDuty detector features | `aws guardduty get-detector --detector-id <id>` |
| Alarm list and history | `aws cloudwatch describe-alarms`, `describe-alarm-history` |
| EventBridge rules | `aws events list-rules` |
| Flow logs, WAF and CloudFront log groups | `aws ec2 describe-flow-logs`, `aws logs describe-log-groups` |
| Security Hub GuardDuty.1, EC2.6, CloudWatch.1 to .14 | Security Hub export |
| Sample-finding test (detection to alert latency) | Lambda and SNS metrics from the IR-4 test |

## Terraform

- `modules/detection/guardduty.tf`, `securityhub.tf`, `inspector.tf`, `access_analyzer.tf`, `alerts.tf`
- `modules/logging/alarms.tf`, `modules/network/flow_logs.tf`, `modules/edge/logging.tf`, `modules/edge/waf.tf`

## Gaps and POA&M

- SIEM integration (Datadog) is a production item; the lab relies on CloudWatch alarms and Security Hub.
- Alarm tuning for deployment noise (see AU-6).
