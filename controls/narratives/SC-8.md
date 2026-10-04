# SC-8 Transmission Confidentiality and Integrity

| Family | Baseline | Responsibility | Status |
|---|---|---|---|
| System and Communications Protection | Moderate | Shared (AWS operates TLS endpoints; customer enforces their use) | Implemented (SC-8(1) partial at the edge) |

Enhancements addressed: SC-8(1) cryptographic protection.

## Control summary

Protect the confidentiality and integrity of transmitted information, using
cryptographic mechanisms to prevent unauthorized disclosure and detect
changes during transmission.

## FedRAMP Rev 5 parameters

- Cryptographic protection for all transmissions crossing the boundary and between components; FIPS 140 validated modules (SC-13); TLS 1.2 or higher.

## Implementation

Encryption in transit is enforced, not merely available:

| Path | Mechanism | Enforcement |
|---|---|---|
| Users to CloudFront | TLS; HTTP redirected to HTTPS; HSTS 2 years with preload | `viewer_protocol_policy = redirect-to-https`; response headers policy |
| CloudFront to S3 origin | TLS with SigV4 | S3 bucket policy denies `aws:SecureTransport = false` |
| Any client to audit, config and origin buckets | TLS | bucket policies deny non-TLS |
| Publishers to SNS | TLS | topic policy denies non-TLS publish |
| Application to Aurora | TLS enforced by the engine | parameter group `require_secure_transport = ON`; plaintext connections are refused |
| Workloads to AWS APIs | TLS to FIPS endpoints inside the VPC | interface endpoints `*-fips` with private DNS; `AWS_USE_FIPS_ENDPOINT` |
| Terraform and CI to AWS APIs | TLS to FIPS endpoints | `use_fips_endpoint = true`; OIDC over TLS |
| CloudTrail to S3 and CloudWatch Logs, Config to S3 | AWS internal TLS | service-side |

**Integrity.** TLS provides integrity for every path above; CloudTrail log
file validation adds signed digests for the audit record (SI-7).

**SC-8(1) at the edge.** With a custom domain and ACM certificate, the
distribution uses security policy `TLSv1.2_2021`, which permits only TLS 1.2
and 1.3 with ECDHE key exchange and AES-GCM or ChaCha20 ciphers (FIPS-approved
suites with a FIPS-validated TLS stack on the CloudFront side). The lab uses
the default `*.cloudfront.net` certificate, for which CloudFront pins the
minimum to TLSv1; the code switches to `TLSv1.2_2021` automatically when
`acm_certificate_arn` is provided.

**Inside the VPC.** Traffic between tiers is TLS where an application
protocol exists (3306 with TLS required). Nitro-based instance types encrypt
traffic between instances in the same VPC at the hardware level; Project 2
adds pod-level TLS or a mesh for the application tier.

## Evidence

| Artifact | Collection |
|---|---|
| CloudFront viewer configuration and headers | `aws cloudfront get-distribution-config`; `curl -sI https://<domain>/` showing HSTS; `curl -sI http://<domain>/` showing 301 |
| Bucket and topic deny-non-TLS statements | `aws s3api get-bucket-policy`, `aws sns get-topic-attributes` |
| Aurora parameter | `aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name <pg> --query "Parameters[?ParameterName=='require_secure_transport']"` |
| FIPS endpoint usage | CloudTrail `tlsDetails.clientProvidedHostHeader` showing `*-fips` hosts |
| Security Hub S3.5, CloudFront.3, CloudFront.10 | Security Hub export |

## Terraform

- `modules/edge/main.tf` (viewer certificate, headers policy, redirect)
- `modules/logging/s3.tf`, `modules/logging/alarms.tf` (deny non-TLS)
- `modules/data/main.tf` (parameter group)
- `modules/network/endpoints.tf`, `providers.tf`, `modules/respond/main.tf` (FIPS endpoints)

## Gaps and POA&M

1. Default CloudFront certificate in the lab (minimum TLSv1). Provision a domain and ACM certificate to enable `TLSv1.2_2021` (Security Hub CloudFront.10 will remain FAILED until then).
2. Pod-to-pod encryption for the application tier is a Project 2 item.
