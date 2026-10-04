# FIPS 140 in this baseline (SC-13, SC-8(1), SC-12)

FedRAMP requires that cryptography protecting federal information uses modules
**validated** under FIPS 140-2 or 140-3 by the Cryptographic Module Validation
Program (CMVP). This document states what that means, where the baseline uses
validated cryptography, and what remains for the application layer.

## Validated versus compliant

| Term | Meaning | Acceptable for FedRAMP |
|---|---|---|
| **FIPS 140 validated** | The exact module (software or hardware, specific version) was tested by an accredited lab and has a CMVP certificate number. | Yes |
| **FIPS compliant / FIPS approved algorithms** | The product uses algorithms from the approved list (AES, SHA-2, RSA, ECDSA) but the implementation itself was not tested. | No, unless the underlying module is validated and operated in FIPS mode |
| **FIPS mode** | The validated module configured to refuse non-approved algorithms. A validated module running outside FIPS mode does not count. | Required for OS and library modules |

An assessor will ask for the certificate numbers. For AWS services the answer
is the AWS FedRAMP package; for the operating system and libraries it is the
vendor's CMVP certificate and proof that FIPS mode is enabled.

## Where validated cryptography is used here

| Layer | Mechanism | Validation | Evidence |
|---|---|---|---|
| Keys at rest | AWS KMS customer managed keys (logging, alerts, data) | KMS HSMs are FIPS 140-3 validated at Security Level 3; keys never leave the HSM | `kms describe-key`, AWS FedRAMP package |
| Data at rest | S3 SSE-KMS, EBS, Aurora storage, Secrets Manager, CloudWatch Logs, SNS, SQS all using KMS CMKs | Encryption performed by AWS services inside the FedRAMP boundary with KMS data keys | `docs/resource-inventory.md` encryption attributes |
| API calls from Terraform | `use_fips_endpoint = true` on the AWS provider | Every API call goes to `<service>-fips.us-east-1.amazonaws.com`, which terminates TLS on FIPS validated modules | `terraform/providers.tf`; CloudTrail `tlsDetails` shows the FIPS endpoint host |
| API calls from the containment Lambda | `AWS_USE_FIPS_ENDPOINT=true` | boto3 resolves FIPS endpoints for IAM, EC2, SNS | Lambda environment; X-Ray traces |
| API calls from inside the VPC | Interface endpoints for `kms-fips`, `secretsmanager-fips`, `sts-fips`, `logs-fips` with private DNS | FIPS hostnames resolve to private IPs; traffic stays in the VPC and terminates on FIPS endpoints | `ec2 describe-vpc-endpoints`; `dig kms-fips.us-east-1.amazonaws.com` from a private subnet |
| Log integrity | CloudTrail log file validation (SHA-256 digests, RSA signatures) | Computed by CloudTrail inside the AWS boundary | `cloudtrail validate-logs` |
| TLS to the database | Aurora `require_secure_transport = ON`; RDS endpoints and `rds-fips` endpoint for the control plane | Aurora TLS stack is part of the AWS FedRAMP boundary | `rds describe-db-cluster-parameters` |
| TLS at the edge | CloudFront viewer TLS | CloudFront is in the AWS FedRAMP boundary. With a custom certificate, security policy `TLSv1.2_2021` restricts ciphers to AES-GCM and ChaCha20 with ECDHE; with the default certificate the minimum is TLSv1 | `cloudfront get-distribution-config` viewer certificate |

### Why FIPS endpoints only exist in some regions

AWS publishes FIPS endpoints for almost every service in the US commercial
regions (us-east-1, us-east-2, us-west-1, us-west-2), the Canadian regions and
GovCloud. Elsewhere only a few services have them. Measured on 4 October 2026:
`describe-vpc-endpoint-services` lists 3 FIPS endpoint services in eu-north-1
(`kms-fips`, `wafv2-fips`, `elasticfilesystem-fips`) against 171 in us-east-1,
and the `sts-fips`, `cloudtrail-fips`, `secretsmanager-fips`, `logs-fips`,
`config-fips`, `sns-fips` and `rds-fips` hostnames do not resolve in eu-north-1.
A provider configured with `use_fips_endpoint = true` therefore fails on its
first STS call there. That is why the lab moved to us-east-1. The output
`fips_endpoints_available` encodes the documented region list; the commands
above are the live evidence and can be repeated for any region. FedRAMP Moderate Equivalency does not require
GovCloud; US commercial regions with FIPS endpoints are sufficient, and the
DoD memo of 21 December 2023 confirms commercial regions are acceptable when
the controls are met.

## What is not covered by the baseline, and how to cover it

### Operating systems

Any EC2 instance or container host inside the boundary must run a validated
module in FIPS mode:

| Platform | How | Verification |
|---|---|---|
| Amazon Linux 2023 | `dnf install crypto-policies-scripts && fips-mode-setup --enable`, reboot; kernel boots with `fips=1` | `fips-mode-setup --check`; `cat /proc/sys/crypto/fips_enabled` returns 1 |
| Bottlerocket (EKS nodes) | Use the FIPS variant AMI (`aws-k8s-<version>-fips`) | `apiclient get os` shows the FIPS variant; CMVP certificate for the Bottlerocket kernel crypto API |
| Windows Server | Group policy "System cryptography: Use FIPS compliant algorithms" | `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy` Enabled = 1 |
| Container images | Base images with OpenSSL 3 FIPS provider enabled (`openssl list -providers` shows fips), or distroless images that defer to the host kernel for TLS via a FIPS-validated sidecar | `openssl list -providers`; image SBOM |

### Application libraries

TLS clients and crypto in the application must call a validated module:

| Stack | Approach |
|---|---|
| PHP (the target environment) | PHP links to the system OpenSSL; with the OS in FIPS mode and OpenSSL's FIPS provider active, `openssl_*` and curl use validated crypto. Verify `php -i` shows the system OpenSSL version and no bundled alternative |
| Go | Build with `GOEXPERIMENT=boringcrypto` (BoringCrypto, FIPS 140-2 validated) or Go 1.24+ FIPS 140-3 module with `GODEBUG=fips140=on` |
| Java | Bouncy Castle FIPS provider or the JDK configured with a FIPS keystore and provider order; disable non-FIPS providers |
| Python | Uses system OpenSSL; `ssl.OPENSSL_VERSION` must match the FIPS-enabled OpenSSL; `hashlib.md5` fails in FIPS mode unless `usedforsecurity=False` |
| Node.js | Build or run with `--enable-fips` against a FIPS OpenSSL |

### TLS termination inside the cluster

For the question "what does FIPS 140 mean for TLS at CloudFront and in-cluster":

1. **CloudFront (edge):** inside AWS's boundary; set `TLSv1.2_2021` with a custom certificate so only FIPS-approved cipher suites are offered. Evidence: `openssl s_client -connect <domain>:443 -tls1_1` must fail, `-tls1_2` must succeed with an ECDHE-AES-GCM suite.
2. **ALB / NLB:** choose a FIPS security policy (`ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04` family) which uses AWS-LC FIPS validated modules.
3. **In-cluster (pod to pod, ingress to pod):** the TLS library in the pod or sidecar must be validated and in FIPS mode. Options: service mesh with a FIPS build (Istio FIPS builds, AWS App Mesh with Envoy FIPS), or application TLS from a FIPS OpenSSL. Plain Kubernetes NetworkPolicies do not encrypt; VPC CNI traffic between nodes is not encrypted by default, so either terminate TLS in the pod or enable Nitro-based encryption in transit (supported instance types encrypt traffic between instances in the same VPC automatically).
4. **Node to AWS APIs:** FIPS endpoints via the VPC interface endpoints above; set `AWS_USE_FIPS_ENDPOINT=true` in pod environments.

## Checklist for the assessor conversation

- Certificate numbers: KMS (AWS FedRAMP package), OS crypto module (vendor CMVP entry), OpenSSL FIPS provider.
- Configuration evidence: provider `use_fips_endpoint`, Lambda environment, VPC endpoint service names, CloudFront security policy, Aurora parameter.
- Runtime evidence: CloudTrail events showing `-fips` endpoint hosts; `fips_enabled = 1` on hosts; `openssl s_client` cipher negotiation.
- Known gaps: default CloudFront certificate in the lab (TLSv1 minimum); no hosts in the lab yet to demonstrate OS FIPS mode (Project 2 adds Bottlerocket FIPS nodes).
