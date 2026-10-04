# Amazon Inspector (RA-5, RA-5(2), SI-2, SI-2(2), SI-7)
# Continuous vulnerability scanning of EC2 instances (agentless via SSM and
# EBS snapshots), container images in ECR, and Lambda functions.

resource "aws_inspector2_enabler" "this" {
  account_ids    = [var.account_id]
  resource_types = var.inspector_resource_types
}
