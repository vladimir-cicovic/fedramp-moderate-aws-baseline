# Access logs (AU-2, AU-3, AU-9)
# CloudFront standard logging v2 and WAF logging both deliver through the
# CloudWatch "vended logs" service into encrypted log groups.

resource "aws_cloudwatch_log_group" "cloudfront" {
  name              = "/aws/cloudfront/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logging_kms_key_arn
}

data "aws_iam_policy_document" "vended_logs" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.cloudfront.arn}:log-stream:*",
      "${aws_cloudwatch_log_group.waf.arn}:log-stream:*",
    ]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${var.partition}:logs:${var.region}:${var.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "vended_logs" {
  policy_name     = "${var.name_prefix}-vended-logs"
  policy_document = data.aws_iam_policy_document.vended_logs.json
}

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  name         = "${var.name_prefix}-cloudfront-access"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "cloudfront" {
  name          = "${var.name_prefix}-cloudfront-logs"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.cloudfront.arn
  }

  depends_on = [aws_cloudwatch_log_resource_policy.vended_logs]
}

resource "aws_cloudwatch_log_delivery" "cloudfront" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront.arn
}
