# SC-7 Boundary Protection

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| System and Communications Protection | Moderate | Customer | Implemented |

Enhancements addressed: SC-7(3) access points, SC-7(4) external
telecommunications services, SC-7(5) deny by default, SC-7(7) split
tunneling (n/a), SC-7(8) route traffic to authenticated proxy servers,
SC-7(21) isolation of components.

## Control summary

Monitor and control communications at the external boundary and key internal
boundaries; implement subnetworks for publicly accessible components; connect
to external networks only through managed interfaces.

## Implementation

**External boundary (SC-7(3), SC-7(4)).** There is exactly one managed entry
point: CloudFront with WAFv2 attached. CloudFront terminates TLS, redirects
HTTP, applies security headers, and reaches the private S3 origin with
SigV4-signed requests that the bucket policy accepts only from this
distribution. No resource in the VPC has a public IP, and no inbound rule
anywhere admits SSH or RDP.

**Egress.** There is no NAT gateway and no default route in private or data
route tables. Workloads reach AWS APIs only through VPC endpoints (SC-7(8)):
gateway endpoints for S3 and DynamoDB, interface endpoints for KMS, Secrets
Manager, STS and CloudWatch Logs using the FIPS service variants with private
DNS. Any future internet egress requires an explicit, reviewed design
(Network Firewall or NAT with domain allow-list).

**Internal boundaries (SC-7(21)).** Three tiers across two availability
zones. Each tier has its own network ACL (stateless, deny by default):

| Tier | Inbound | Outbound |
|---|---|---|
| public | 443 from anywhere; ephemeral 1024-3388 and 3390-65535 from anywhere; all from VPC | all |
| private | all from VPC; ephemeral (split around 3389) from anywhere for gateway-endpoint responses | all to VPC; 443 to anywhere (gateway endpoints) |
| data | 3306 from each private subnet; ephemeral from VPC | ephemeral and 3306 to VPC |

Security groups add stateful, resource-level rules: the database group
accepts 3306 only from the private subnets, the endpoint group accepts 443
only from the VPC CIDR, the default group has no rules, and the quarantine
group has no rules.

**Organization boundary.** Service control policies restrict API activity to
approved regions and prevent member accounts from leaving the organization or
disabling the security services (code in `modules/org`, applied through the
management script in the live organization).

**Monitoring.** VPC Flow Logs capture accepted and rejected traffic; GuardDuty
analyses flow and DNS logs for command-and-control, port scanning and
exfiltration patterns; CloudWatch alarms fire on changes to security groups,
NACLs, route tables, gateways and VPCs; WAF logs every evaluated request.

**Dynamic isolation (SC-7(21), IR-4(2)).** The containment Lambda moves a
compromised instance into the quarantine security group, cutting all traffic
while preserving the instance for forensics.

## Evidence

| Artifact | Collection |
|---|---|
| Boundary and data-flow diagram, PPS table | `docs/authorization-boundary.md` |
| NACLs, route tables, security groups, endpoints | `aws ec2 describe-network-acls`, `describe-route-tables`, `describe-security-groups`, `describe-vpc-endpoints`; `docs/resource-inventory.md` |
| No NAT gateways, no public instances | `aws ec2 describe-nat-gateways`, `describe-instances` |
| CloudFront and WAF configuration | `aws cloudfront get-distribution-config`, `aws wafv2 get-web-acl` |
| Flow logs active | `aws ec2 describe-flow-logs` |
| Security Hub EC2.2, EC2.6, EC2.19, EC2.21, S3.1, CloudFront.1 | Security Hub export |

## Terraform

- `modules/network/main.tf`, `modules/network/endpoints.tf`, `modules/network/flow_logs.tf`
- `modules/edge/main.tf`, `modules/edge/waf.tf`
- `modules/org/main.tf`
- `modules/respond/src/handler.py` (quarantine)

## Gaps and POA&M

- The application tier (EKS) and its ingress are Project 2; the public subnets are reserved for its load balancer.
- No Network Firewall or egress proxy exists because there is no egress; add one before any workload needs internet access.
