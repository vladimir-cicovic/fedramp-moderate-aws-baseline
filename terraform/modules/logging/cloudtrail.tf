# CloudTrail (AU-2, AU-3, AU-8, AU-12, AU-9, AC-2(4))
# One multi-region organization trail.

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = aws_kms_key.logging.arn
}

data "aws_iam_policy_document" "cloudtrail_to_cwl_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = local.trail_source_arns
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_to_cwl" {
  statement {
    sid    = "WriteCloudTrailEventsToLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_iam_role" "cloudtrail_to_cwl" {
  name               = "${var.name_prefix}-cloudtrail-to-cwl"
  description        = "Lets CloudTrail deliver events to CloudWatch Logs."
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_to_cwl_trust.json
}

resource "aws_iam_role_policy" "cloudtrail_to_cwl" {
  name   = "write-log-events"
  role   = aws_iam_role.cloudtrail_to_cwl.id
  policy = data.aws_iam_policy_document.cloudtrail_to_cwl.json
}

resource "aws_cloudtrail" "this" {
  #checkov:skip=CKV_AWS_252:Per-file delivery notifications would flood the security alerts topic; integrity is covered by log file validation digests
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true
  is_organization_trail         = var.is_organization_trail
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.logging.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cwl.arn

  advanced_event_selector {
    name = "All management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  dynamic "advanced_event_selector" {
    for_each = var.enable_s3_data_events ? [1] : []

    content {
      name = "S3 object-level events, excluding audit log buckets"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = ["AWS::S3::Object"]
      }

      field_selector {
        field = "resources.ARN"
        not_starts_with = [
          "${aws_s3_bucket.cloudtrail.arn}/",
          "${aws_s3_bucket.config.arn}/",
          "${aws_s3_bucket.access_logs.arn}/",
        ]
      }
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_to_cwl,
  ]
}
