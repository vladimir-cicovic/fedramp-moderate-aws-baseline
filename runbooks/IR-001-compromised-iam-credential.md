# IR-001 Compromised IAM credential

| Trigger | Severity | Owner | Controls |
|---|---|---|---|
| GuardDuty `UnauthorizedAccess:IAMUser/*`, `CredentialAccess:IAMUser/*`, `Exfiltration:IAMUser/*`, `Persistence:IAMUser/*`, `PrivilegeEscalation:IAMUser/*`, `Policy:IAMUser/RootCredentialUsage`; CloudWatch alarm `root-account-usage`; a developer reports a leaked key | High (page immediately) | On-call security engineer; Security Lead as incident commander | IR-4, IR-5, IR-6, AC-2, IA-5 |

Phases follow NIST SP 800-61. Times are targets from detection.

## 0. What already happened automatically (T+0 to T+1 min)

For findings with severity 7 or higher on an access key, the containment
function has already:

1. set the access key to **Inactive**,
2. attached the inline policy `GuardDutyContainmentDenyAll` to the user, which also kills any active STS session derived from that user,
3. tagged the user `ContainmentStatus=Isolated`, `ContainmentFinding=<id>`,
4. sent the report to the alerts topic with the finding ID.

Read that report first. If it says the user is **root** or the resource was
not real (sample finding), automation did nothing and step 3b applies.

## 1. Detection and triage (T+15 min)

```bash
# the finding
aws guardduty get-findings --detector-id <detector> --finding-ids <id> --region us-east-1

# what the key did in the last 24 hours (identity, source IPs, calls)
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<AKIA...> \
  --start-time "$(date -u -d '-24 hours' +%FT%TZ)" --max-results 200 --region us-east-1
```

Decide:

- **Confirmed compromise** (unknown source IP, calls the owner did not make, GuardDuty type is not a false positive): continue.
- **False positive** (owner confirms activity, e.g. new office IP): reverse containment (step 5), set the Security Hub finding workflow to `SUPPRESSED` with a note, add an IP trusted list if appropriate.

Open the incident record (ticket) with: finding ID, user, key ID, first seen, source IPs, actions observed.

## 2. Containment (T+30 min)

Automation covered the key. Finish the job:

```bash
# any other keys of the same user
aws iam list-access-keys --user-name <user>
aws iam update-access-key --user-name <user> --access-key-id <other-key> --status Inactive

# console password, if any
aws iam delete-login-profile --user-name <user>

# roles the user could assume: look for AssumeRole calls in CloudTrail and revoke active sessions
aws iam put-role-policy --role-name <role> --policy-name RevokeOlderSessions --policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*",
  "Condition":{"DateLessThan":{"aws:TokenIssueTime":"<now ISO-8601>"}}}]}'
```

If the credential belongs to an **Identity Center** user instead of an IAM
user: disable the user in Identity Center (or the IdP), then revoke sessions
with the same `aws:TokenIssueTime` deny on the permission set roles.

**3b. Root credentials.** Automation never touches root. Immediately:
sign in as root from a trusted device, rotate the root password, verify or
re-register hardware MFA, delete any root access keys
(`aws iam get-account-summary` shows `AccountAccessKeysPresent`), review
`aws iam list-virtual-mfa-devices`. Notify the Security Lead and the
management account owner.

## 3. Eradication (T+2 h)

Look for what the attacker left behind:

```bash
# new principals, policies, keys, roles created by the compromised identity
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=<user> \
  --start-time <first seen> --region us-east-1 \
  --query 'Events[?contains(EventName,`Create`) || contains(EventName,`Put`) || contains(EventName,`Attach`)].{t:EventTime,e:EventName,r:Resources}'

# public exposure created during the incident
aws accessanalyzer list-findings-v2 --analyzer-arn <external-access analyzer> --filter '{"status":{"eq":["ACTIVE"]}}'
```

Remove every artifact: delete created users/keys/roles, detach policies,
revert bucket and key policies (Terraform `plan` shows drift for managed
resources: run `terraform plan` and apply to restore the baseline), terminate
instances launched by the attacker (snapshot first if needed for forensics).

## 4. Recovery (T+4 h)

- Issue a new credential **only** through Identity Center (no new IAM keys).
- Remove the `GuardDutyContainmentDenyAll` inline policy and the containment tags once the user is cleaned or deleted.
- Confirm GuardDuty shows no new findings for the identity for 24 hours.
- Set the Security Hub finding workflow to `RESOLVED` with a note referencing the ticket.

## 5. Reversing containment (false positive)

```bash
aws iam delete-user-policy --user-name <user> --policy-name GuardDutyContainmentDenyAll
aws iam update-access-key --user-name <user> --access-key-id <key> --status Active
aws iam untag-user --user-name <user> --tag-keys ContainmentStatus ContainmentFinding ContainmentTime
```

## 6. Reporting (IR-6)

- Internal: incident record updated at each phase; Security Lead informed at detection.
- External: if CUI or customer data may have been accessed, the ISSO reports to the FedRAMP PMO and affected agencies **within one hour of confirmation** per the FedRAMP Incident Communications Procedures. Include finding IDs, CloudTrail event IDs, timeline, affected data, containment actions.

## 7. Post-incident (within 5 business days)

Post-mortem using the template below; feed changes into this runbook, the
containment function and the detection rules. Keep the GuardDuty finding
archived, the CloudTrail events are retained by the WORM bucket.

### Post-mortem template

| Field | Content |
|---|---|
| Incident ID / finding ID | |
| Timeline (detect, contain, eradicate, recover) | |
| Root cause (how was the credential obtained) | |
| Impact (data, systems, duration) | |
| What worked | |
| What did not | |
| Actions (owner, due date) | |
| Control gaps and POA&M items created | |

## Evidence to capture during the incident

GuardDuty finding JSON, containment SNS report, CloudTrail event export for
the identity, IAM state before and after, Access Analyzer findings, the
incident record. Store in the ticket and reference from the POA&M if a
control gap was found.
