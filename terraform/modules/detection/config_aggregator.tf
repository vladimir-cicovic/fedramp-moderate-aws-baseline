# Organization-wide AWS Config aggregator (CA-7, CM-8, AU-6(3))
# From the delegated administrator account, one view of every resource and
# every Config rule result across all accounts and regions in the

data "aws_iam_policy_document" "config_aggregator_trust" {
  count = var.enable_config_aggregator ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_iam_role" "config_aggregator" {
  count = var.enable_config_aggregator ? 1 : 0

  name               = "${var.name_prefix}-config-aggregator"
  description        = "Lets AWS Config read organization structure for the aggregator."
  assume_role_policy = data.aws_iam_policy_document.config_aggregator_trust[0].json
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  count = var.enable_config_aggregator ? 1 : 0

  role       = aws_iam_role.config_aggregator[0].name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "organization" {
  count = var.enable_config_aggregator ? 1 : 0

  name = "${var.name_prefix}-organization"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator[0].arn
  }

  depends_on = [aws_iam_role_policy_attachment.config_aggregator]
}
