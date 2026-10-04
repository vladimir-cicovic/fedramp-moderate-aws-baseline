# Resource inventory (CM-8)

Generated 2026-10-04 from Terraform state. Account n/a, region n/a, 1 managed resources.

Regenerate with `python scripts/inventory.py` after every apply; commit the result as evidence.

## Summary by type

| Type | Count |
|---|---|
| `aws_cloudtrail` | 1 |

## Root (`root`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudtrail.organization` | `aws_cloudtrail` | name=fedramp-baseline-lab-org-trail; is_multi_region_trail=true; is_organization_trail=true; enable_log_file_validation=true; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
