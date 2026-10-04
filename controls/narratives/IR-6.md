# IR-6 Incident Reporting

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| Incident Response | Moderate | Customer | Implemented (technical); procedural reporting chain outside the repo |

Enhancements addressed: IR-6(1) automated reporting, IR-6(3) supply chain
coordination (procedural).

## Control summary

Require personnel to report suspected incidents within a defined time, and
report incident information to designated authorities.

## FedRAMP Rev 5 parameters

- Report suspected incidents to the organizational incident response capability within one hour of discovery.
- Report to FedRAMP PMO, the agency and US-CERT per the FedRAMP Incident Communications Procedures (within one hour of a confirmed incident affecting federal data).

## Implementation

**Automated internal reporting (IR-6(1)).** Three producers publish to one
KMS-encrypted SNS topic, `fedramp-baseline-lab-security-alerts`:

1. CloudWatch alarms on 14 CloudTrail patterns (root use, IAM changes, logging changes, unauthorized calls, network changes).
2. EventBridge rules for GuardDuty findings of severity 7 or higher and for Security Hub CRITICAL/HIGH findings from vulnerability and access products.
3. The containment Lambda's action report after every automated response.

Messages carry the finding type, severity, account, region, resource, and the
runbook path. In the lab the subscriber is a confirmed email address; in
production it is the on-call platform (SquadCast) webhook, which pages the
engineer on duty and opens the incident record. Delivery is observable
through SNS `NumberOfMessagesPublished` and `NumberOfNotificationsFailed`.

**Noise control.** Compliance (control) findings are excluded from the topic
and flow to the POA&M instead; only threats, vulnerabilities and containment
reports page a human.

**External reporting.** Procedural: the IR plan names the ISSO as the
reporter to the FedRAMP PMO and customer agencies, with the one-hour clock
starting at confirmation. Security Hub finding IDs, CloudTrail event IDs and
containment tags provide the identifiers the report requires.

**Supply chain (IR-6(3)).** Vendor contacts for GitHub, Datadog, Okta and
SentinelOne are maintained in the IR plan; the ISA for each interconnection
defines mutual notification.

## Evidence

| Artifact | Collection |
|---|---|
| Topic, subscriptions, policy, encryption | `aws sns get-topic-attributes`, `list-subscriptions-by-topic` |
| Publish and failure metrics | `aws cloudwatch get-metric-statistics --namespace AWS/SNS` |
| Sample alarm, finding and containment messages | alerts mailbox export |
| EventBridge rules | `aws events list-rules --name-prefix fedramp-baseline-lab` |
| IR plan with reporting chain and timelines | outside repo |

## Terraform

- `modules/logging/alarms.tf` (topic, policy, subscription, alarms)
- `modules/detection/alerts.tf`
- `modules/respond/main.tf`

## Gaps and POA&M

- On-call tool integration replaces the email subscriber in production.
- The one-hour external reporting procedure and contact list live in the IR plan (procedural, Day 5 runbooks reference it).
