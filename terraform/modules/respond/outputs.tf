output "function_arn" {
  value = aws_lambda_function.containment.arn
}

output "function_name" {
  value = aws_lambda_function.containment.function_name
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.guardduty_containment.arn
}

output "dead_letter_queue_arn" {
  value = aws_sqs_queue.dlq.arn
}
