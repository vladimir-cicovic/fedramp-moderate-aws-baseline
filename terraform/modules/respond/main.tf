# Automated containment of high-severity GuardDuty findings
# (IR-4, IR-4(1), IR-4(4), IR-5, IR-6, AU-6(1), SI-4(5))

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

# Execution role: only the containment actions, nothing else (AC-6)

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

data "aws_iam_policy_document" "containment" {
  #checkov:skip=CKV_AWS_111:Snapshot, tag and security-group changes must target whichever volume or instance GuardDuty names; IAM actions are scoped to user/*
  #checkov:skip=CKV_AWS_356:The function must act on whichever IAM user, key, instance or volume GuardDuty names; the resource is only known at runtime
  statement {
    sid    = "ContainIamUserCredentials"
    effect = "Allow"
    actions = [
      "iam:UpdateAccessKey",
      "iam:PutUserPolicy",
      "iam:TagUser",
      "iam:GetUser",
      "iam:ListAccessKeys",
    ]
    resources = ["arn:${var.partition}:iam::${var.account_id}:user/*"]
  }

  statement {
    sid    = "ContainEc2Instance"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVolumes",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:ModifyInstanceAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReportToAlertsTopic"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.security_alerts_topic_arn]
  }

  statement {
    sid       = "EncryptAlertMessages"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.alerts_kms_key_arn]
  }

  statement {
    sid       = "DeadLetterQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]
  }

  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-guardduty-containment"
  description        = "Execution role for automated GuardDuty containment."
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy" "containment" {
  name   = "containment"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.containment.json
}

# Function, logs, dead-letter queue

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}-guardduty-containment"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logging_kms_key_arn
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-guardduty-containment-dlq"
  kms_master_key_id         = var.logging_kms_key_arn
  message_retention_seconds = 1209600
}

resource "aws_lambda_function" "containment" {
  #checkov:skip=CKV_AWS_117:The function calls IAM, which has no VPC endpoint; placing it in a VPC would require a NAT gateway and gain nothing (documented POA&M exception)
  #checkov:skip=CKV_AWS_272:Code signing is tracked for the production pipeline (SI-7); the lab deploys from the repository
  #checkov:skip=CKV_AWS_115:Reserved concurrency is not needed for a low-volume responder
  function_name = "${var.name_prefix}-guardduty-containment"
  description   = "Deactivates compromised IAM keys and isolates compromised EC2 instances reported by GuardDuty."
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "handler.handler"
  architectures = ["arm64"]
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256

  kms_key_arn = var.logging_kms_key_arn

  environment {
    variables = {
      SNS_TOPIC_ARN         = var.security_alerts_topic_arn
      DRY_RUN               = var.dry_run ? "true" : "false"
      QUARANTINE_SG_BY_VPC  = jsonencode(var.quarantine_security_group_ids)
      AWS_USE_FIPS_ENDPOINT = "true"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.containment,
  ]
}

# Trigger: GuardDuty findings on IAM keys or EC2 instances, High or Critical

resource "aws_cloudwatch_event_rule" "guardduty_containment" {
  name        = "${var.name_prefix}-guardduty-containment"
  description = "GuardDuty findings with severity >= ${var.minimum_severity} on IAM access keys or EC2 instances."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.minimum_severity] }]
      resource = {
        resourceType = ["AccessKey", "Instance"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_containment.name
  target_id = "containment-lambda"
  arn       = aws_lambda_function.containment.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 3
  }

  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.containment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_containment.arn
}

# EventBridge needs to be allowed to send to the DLQ.
data "aws_iam_policy_document" "dlq" {
  statement {
    sid       = "EventBridgeAndLambdaDeadLetters"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq.json
}
