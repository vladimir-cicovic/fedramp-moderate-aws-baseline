# Resource inventory (CM-8)

Generated 2026-10-04 from Terraform state. Account 111111111111, region us-east-1, 175 managed resources.

Regenerate with `python scripts/inventory.py` after every apply; commit the result as evidence.

## Summary by type

| Type | Count |
|---|---|
| `aws_cloudwatch_log_metric_filter` | 14 |
| `aws_cloudwatch_metric_alarm` | 14 |
| `aws_cloudwatch_log_group` | 8 |
| `aws_iam_role` | 7 |
| `aws_guardduty_detector_feature` | 6 |
| `aws_route_table_association` | 6 |
| `aws_subnet` | 6 |
| `aws_vpc_endpoint` | 6 |
| `aws_iam_role_policy_attachment` | 5 |
| `aws_iam_role_policy` | 4 |
| `aws_s3_bucket` | 4 |
| `aws_s3_bucket_lifecycle_configuration` | 4 |
| `aws_s3_bucket_ownership_controls` | 4 |
| `aws_s3_bucket_policy` | 4 |
| `aws_s3_bucket_public_access_block` | 4 |
| `aws_s3_bucket_server_side_encryption_configuration` | 4 |
| `aws_s3_bucket_versioning` | 4 |
| `aws_cloudwatch_event_rule` | 3 |
| `aws_cloudwatch_event_target` | 3 |
| `aws_kms_alias` | 3 |
| `aws_kms_key` | 3 |
| `aws_network_acl` | 3 |
| `aws_route_table` | 3 |
| `aws_security_group` | 3 |
| `aws_securityhub_standards_subscription` | 3 |
| `aws_accessanalyzer_analyzer` | 2 |
| `aws_iam_policy` | 2 |
| `aws_s3_bucket_logging` | 2 |
| `aws_cloudfront_distribution` | 1 |
| `aws_cloudfront_origin_access_control` | 1 |
| `aws_cloudfront_response_headers_policy` | 1 |
| `aws_cloudtrail` | 1 |
| `aws_cloudwatch_log_delivery` | 1 |
| `aws_cloudwatch_log_delivery_destination` | 1 |
| `aws_cloudwatch_log_delivery_source` | 1 |
| `aws_cloudwatch_log_resource_policy` | 1 |
| `aws_config_configuration_aggregator` | 1 |
| `aws_config_configuration_recorder` | 1 |
| `aws_config_configuration_recorder_status` | 1 |
| `aws_config_conformance_pack` | 1 |
| `aws_config_delivery_channel` | 1 |
| `aws_config_retention_configuration` | 1 |
| `aws_db_subnet_group` | 1 |
| `aws_default_security_group` | 1 |
| `aws_ebs_default_kms_key` | 1 |
| `aws_ebs_encryption_by_default` | 1 |
| `aws_flow_log` | 1 |
| `aws_guardduty_detector` | 1 |
| `aws_iam_account_password_policy` | 1 |
| `aws_iam_openid_connect_provider` | 1 |
| `aws_inspector2_enabler` | 1 |
| `aws_internet_gateway` | 1 |
| `aws_lambda_function` | 1 |
| `aws_lambda_permission` | 1 |
| `aws_rds_cluster` | 1 |
| `aws_rds_cluster_instance` | 1 |
| `aws_rds_cluster_parameter_group` | 1 |
| `aws_s3_account_public_access_block` | 1 |
| `aws_s3_bucket_object_lock_configuration` | 1 |
| `aws_s3_object` | 1 |
| `aws_securityhub_account` | 1 |
| `aws_sns_topic` | 1 |
| `aws_sns_topic_policy` | 1 |
| `aws_sns_topic_subscription` | 1 |
| `aws_sqs_queue` | 1 |
| `aws_sqs_queue_policy` | 1 |
| `aws_vpc` | 1 |
| `aws_wafv2_web_acl` | 1 |
| `aws_wafv2_web_acl_logging_configuration` | 1 |

## Identity (`module.identity`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_iam_account_password_policy.this` | `aws_iam_account_password_policy` | minimum_password_length=14; max_password_age=60; password_reuse_prevention=24 |
| `aws_iam_openid_connect_provider.github` | `aws_iam_openid_connect_provider` | url=token.actions.githubusercontent.com; arn=arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com |
| `aws_iam_policy.developer_boundary` | `aws_iam_policy` | name=fedramp-baseline-lab-developer-boundary; arn=arn:aws:iam::111111111111:policy/fedramp-baseline-lab-developer-boundary |
| `aws_iam_policy.evidence_collector` | `aws_iam_policy` | name=fedramp-baseline-lab-evidence-collector; arn=arn:aws:iam::111111111111:policy/fedramp-baseline-lab-evidence-collector |
| `aws_iam_role.github_evidence` | `aws_iam_role` | name=fedramp-baseline-lab-github-evidence; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-github-evidence; max_session_duration=3600 |
| `aws_iam_role.github_plan` | `aws_iam_role` | name=fedramp-baseline-lab-github-plan; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-github-plan; max_session_duration=3600 |
| `aws_iam_role_policy_attachment.github_evidence` | `aws_iam_role_policy_attachment` | role=fedramp-baseline-lab-github-evidence; policy_arn=arn:aws:iam::111111111111:policy/fedramp-baseline-lab-evidence-collector |
| `aws_iam_role_policy_attachment.github_plan_readonly` | `aws_iam_role_policy_attachment` | role=fedramp-baseline-lab-github-plan; policy_arn=arn:aws:iam::aws:policy/ReadOnlyAccess |
| `aws_iam_role_policy_attachment.github_plan_security_audit` | `aws_iam_role_policy_attachment` | role=fedramp-baseline-lab-github-plan; policy_arn=arn:aws:iam::aws:policy/SecurityAudit |

## Logging (`module.logging`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudtrail.this` | `aws_cloudtrail` | name=fedramp-baseline-lab-trail; is_multi_region_trail=true; is_organization_trail=false; enable_log_file_validation=true; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_group.cloudtrail` | `aws_cloudwatch_log_group` | name=/aws/cloudtrail/fedramp-baseline-lab-trail; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_metric_filter.this["cloudtrail-configuration-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-cloudtrail-configuration-changes |
| `aws_cloudwatch_log_metric_filter.this["config-configuration-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-config-configuration-changes |
| `aws_cloudwatch_log_metric_filter.this["console-authentication-failures"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-console-authentication-failures |
| `aws_cloudwatch_log_metric_filter.this["console-signin-without-mfa"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-console-signin-without-mfa |
| `aws_cloudwatch_log_metric_filter.this["iam-policy-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-iam-policy-changes |
| `aws_cloudwatch_log_metric_filter.this["kms-key-disabled-or-scheduled-deletion"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-kms-key-disabled-or-scheduled-deletion |
| `aws_cloudwatch_log_metric_filter.this["network-acl-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-network-acl-changes |
| `aws_cloudwatch_log_metric_filter.this["network-gateway-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-network-gateway-changes |
| `aws_cloudwatch_log_metric_filter.this["root-account-usage"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-root-account-usage |
| `aws_cloudwatch_log_metric_filter.this["route-table-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-route-table-changes |
| `aws_cloudwatch_log_metric_filter.this["s3-bucket-policy-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-s3-bucket-policy-changes |
| `aws_cloudwatch_log_metric_filter.this["security-group-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-security-group-changes |
| `aws_cloudwatch_log_metric_filter.this["unauthorized-api-calls"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-unauthorized-api-calls |
| `aws_cloudwatch_log_metric_filter.this["vpc-changes"]` | `aws_cloudwatch_log_metric_filter` | name=fedramp-baseline-lab-vpc-changes |
| `aws_cloudwatch_metric_alarm.this["cloudtrail-configuration-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-cloudtrail-configuration-changes; metric_name=cloudtrail-configuration-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["config-configuration-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-config-configuration-changes; metric_name=config-configuration-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["console-authentication-failures"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-console-authentication-failures; metric_name=console-authentication-failures; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["console-signin-without-mfa"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-console-signin-without-mfa; metric_name=console-signin-without-mfa; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["iam-policy-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-iam-policy-changes; metric_name=iam-policy-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["kms-key-disabled-or-scheduled-deletion"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-kms-key-disabled-or-scheduled-deletion; metric_name=kms-key-disabled-or-scheduled-deletion; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["network-acl-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-network-acl-changes; metric_name=network-acl-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["network-gateway-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-network-gateway-changes; metric_name=network-gateway-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["root-account-usage"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-root-account-usage; metric_name=root-account-usage; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["route-table-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-route-table-changes; metric_name=route-table-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["s3-bucket-policy-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-s3-bucket-policy-changes; metric_name=s3-bucket-policy-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["security-group-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-security-group-changes; metric_name=security-group-changes; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["unauthorized-api-calls"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-unauthorized-api-calls; metric_name=unauthorized-api-calls; threshold=1 |
| `aws_cloudwatch_metric_alarm.this["vpc-changes"]` | `aws_cloudwatch_metric_alarm` | alarm_name=fedramp-baseline-lab-vpc-changes; metric_name=vpc-changes; threshold=1 |
| `aws_config_configuration_recorder.this` | `aws_config_configuration_recorder` | name=default; role_arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-config-recorder |
| `aws_config_configuration_recorder_status.this` | `aws_config_configuration_recorder_status` | id=default |
| `aws_config_delivery_channel.this` | `aws_config_delivery_channel` | s3_bucket_name=fedramp-baseline-lab-config-111111111111-us-east-1; s3_kms_key_arn=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_config_retention_configuration.this` | `aws_config_retention_configuration` | retention_period_in_days=2557 |
| `aws_iam_role.cloudtrail_to_cwl` | `aws_iam_role` | name=fedramp-baseline-lab-cloudtrail-to-cwl; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-cloudtrail-to-cwl; max_session_duration=3600 |
| `aws_iam_role.config` | `aws_iam_role` | name=fedramp-baseline-lab-config-recorder; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-config-recorder; max_session_duration=3600 |
| `aws_iam_role_policy.cloudtrail_to_cwl` | `aws_iam_role_policy` | role=fedramp-baseline-lab-cloudtrail-to-cwl; name=write-log-events |
| `aws_iam_role_policy.config_delivery` | `aws_iam_role_policy` | role=fedramp-baseline-lab-config-recorder; name=deliver-to-s3 |
| `aws_iam_role_policy_attachment.config` | `aws_iam_role_policy_attachment` | role=fedramp-baseline-lab-config-recorder; policy_arn=arn:aws:iam::aws:policy/service-role/AWS_ConfigRole |
| `aws_kms_alias.alerts` | `aws_kms_alias` | name=alias/fedramp-baseline-lab-alerts; target_key_arn=arn:aws:kms:us-east-1:111111111111:key/aeef18c6-fb81-44d1-aed4-7309f8a737d8 |
| `aws_kms_alias.logging` | `aws_kms_alias` | name=alias/fedramp-baseline-lab-logging; target_key_arn=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_kms_key.alerts` | `aws_kms_key` | description=Security alerts key: SNS topic encryption; arn=arn:aws:kms:us-east-1:111111111111:key/aeef18c6-fb81-44d1-aed4-7309f8a737d8; enable_key_rotation=true; rotation_period_in_days=365; deletion_window_in_days=7 |
| `aws_kms_key.logging` | `aws_kms_key` | description=Audit logging key: CloudTrail, CloudWatch Logs, AWS Config; arn=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d; enable_key_rotation=true; rotation_period_in_days=365; deletion_window_in_days=7 |
| `aws_s3_bucket.access_logs` | `aws_s3_bucket` | bucket=fedramp-baseline-lab-access-logs-111111111111-us-east-1; region=us-east-1; object_lock_enabled=false |
| `aws_s3_bucket.cloudtrail` | `aws_s3_bucket` | bucket=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1; region=us-east-1; object_lock_enabled=true |
| `aws_s3_bucket.config` | `aws_s3_bucket` | bucket=fedramp-baseline-lab-config-111111111111-us-east-1; region=us-east-1; object_lock_enabled=false |
| `aws_s3_bucket_lifecycle_configuration.access_logs` | `aws_s3_bucket_lifecycle_configuration` | bucket=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_lifecycle_configuration.cloudtrail` | `aws_s3_bucket_lifecycle_configuration` | bucket=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_lifecycle_configuration.config` | `aws_s3_bucket_lifecycle_configuration` | bucket=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_logging.cloudtrail` | `aws_s3_bucket_logging` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_logging.config` | `aws_s3_bucket_logging` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_object_lock_configuration.cloudtrail` | `aws_s3_bucket_object_lock_configuration` | bucket=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_ownership_controls.access_logs` | `aws_s3_bucket_ownership_controls` | id=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_ownership_controls.cloudtrail` | `aws_s3_bucket_ownership_controls` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_ownership_controls.config` | `aws_s3_bucket_ownership_controls` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_policy.access_logs` | `aws_s3_bucket_policy` | id=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_policy.cloudtrail` | `aws_s3_bucket_policy` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_policy.config` | `aws_s3_bucket_policy` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_public_access_block.access_logs` | `aws_s3_bucket_public_access_block` | id=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_public_access_block.cloudtrail` | `aws_s3_bucket_public_access_block` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_public_access_block.config` | `aws_s3_bucket_public_access_block` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_server_side_encryption_configuration.access_logs` | `aws_s3_bucket_server_side_encryption_configuration` | id=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_server_side_encryption_configuration.cloudtrail` | `aws_s3_bucket_server_side_encryption_configuration` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_server_side_encryption_configuration.config` | `aws_s3_bucket_server_side_encryption_configuration` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_s3_bucket_versioning.access_logs` | `aws_s3_bucket_versioning` | id=fedramp-baseline-lab-access-logs-111111111111-us-east-1 |
| `aws_s3_bucket_versioning.cloudtrail` | `aws_s3_bucket_versioning` | id=fedramp-baseline-lab-cloudtrail-111111111111-us-east-1 |
| `aws_s3_bucket_versioning.config` | `aws_s3_bucket_versioning` | id=fedramp-baseline-lab-config-111111111111-us-east-1 |
| `aws_sns_topic.security_alerts` | `aws_sns_topic` | name=fedramp-baseline-lab-security-alerts; arn=arn:aws:sns:us-east-1:111111111111:fedramp-baseline-lab-security-alerts; kms_master_key_id=aeef18c6-fb81-44d1-aed4-7309f8a737d8 |
| `aws_sns_topic_policy.security_alerts` | `aws_sns_topic_policy` | id=arn:aws:sns:us-east-1:111111111111:fedramp-baseline-lab-security-alerts |
| `aws_sns_topic_subscription.email[0]` | `aws_sns_topic_subscription` | protocol=email; endpoint=security@example.com |

## Cryptography (`module.crypto`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_ebs_default_kms_key.this` | `aws_ebs_default_kms_key` | key_arn=arn:aws:kms:us-east-1:111111111111:key/0bc06446-443c-4685-a2e1-a232bc15a649 |
| `aws_ebs_encryption_by_default.this` | `aws_ebs_encryption_by_default` | enabled=true |
| `aws_kms_alias.data` | `aws_kms_alias` | name=alias/fedramp-baseline-lab-data; target_key_arn=arn:aws:kms:us-east-1:111111111111:key/0bc06446-443c-4685-a2e1-a232bc15a649 |
| `aws_kms_key.data` | `aws_kms_key` | description=General purpose data-at-rest key: EBS default, S3, Aurora, Secrets Manager; arn=arn:aws:kms:us-east-1:111111111111:key/0bc06446-443c-4685-a2e1-a232bc15a649; enable_key_rotation=true; rotation_period_in_days=365; deletion_window_in_days=7 |
| `aws_s3_account_public_access_block.this` | `aws_s3_account_public_access_block` | block_public_acls=true; block_public_policy=true; ignore_public_acls=true; restrict_public_buckets=true |

## Detection (`module.detection`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_accessanalyzer_analyzer.external_access` | `aws_accessanalyzer_analyzer` | analyzer_name=fedramp-baseline-lab-external-access; type=ACCOUNT; arn=arn:aws:access-analyzer:us-east-1:111111111111:analyzer/fedramp-baseline-lab-external-access |
| `aws_accessanalyzer_analyzer.unused_access[0]` | `aws_accessanalyzer_analyzer` | analyzer_name=fedramp-baseline-lab-unused-access; type=ACCOUNT_UNUSED_ACCESS; arn=arn:aws:access-analyzer:us-east-1:111111111111:analyzer/fedramp-baseline-lab-unused-access |
| `aws_cloudwatch_event_rule.guardduty_high_severity` | `aws_cloudwatch_event_rule` | name=fedramp-baseline-lab-guardduty-high-severity; description=GuardDuty findings with severity 7.0 or higher. |
| `aws_cloudwatch_event_rule.securityhub_critical_high` | `aws_cloudwatch_event_rule` | name=fedramp-baseline-lab-securityhub-critical-high; description=New CRITICAL or HIGH Security Hub findings from vulnerability and access products. |
| `aws_cloudwatch_event_target.guardduty_high_severity_sns` | `aws_cloudwatch_event_target` | rule=fedramp-baseline-lab-guardduty-high-severity; arn=arn:aws:sns:us-east-1:111111111111:fedramp-baseline-lab-security-alerts |
| `aws_cloudwatch_event_target.securityhub_critical_high_sns` | `aws_cloudwatch_event_target` | rule=fedramp-baseline-lab-securityhub-critical-high; arn=arn:aws:sns:us-east-1:111111111111:fedramp-baseline-lab-security-alerts |
| `aws_config_configuration_aggregator.organization[0]` | `aws_config_configuration_aggregator` | name=fedramp-baseline-lab-organization; arn=arn:aws:config:us-east-1:111111111111:config-aggregator/config-aggregator-uz5gy9bv |
| `aws_config_conformance_pack.nist_800_53_rev5[0]` | `aws_config_conformance_pack` | name=nist-800-53-rev-5; arn=arn:aws:config:us-east-1:111111111111:conformance-pack/nist-800-53-rev-5/conformance-pack-tro0mulo7 |
| `aws_guardduty_detector.this` | `aws_guardduty_detector` | id=f933a60fbd064ca89530131d69be5b5c; finding_publishing_frequency=FIFTEEN_MINUTES |
| `aws_guardduty_detector_feature.ebs_malware_protection` | `aws_guardduty_detector_feature` | name=EBS_MALWARE_PROTECTION; status=ENABLED |
| `aws_guardduty_detector_feature.eks_audit_logs` | `aws_guardduty_detector_feature` | name=EKS_AUDIT_LOGS; status=ENABLED |
| `aws_guardduty_detector_feature.lambda_network_logs` | `aws_guardduty_detector_feature` | name=LAMBDA_NETWORK_LOGS; status=ENABLED |
| `aws_guardduty_detector_feature.rds_login_events` | `aws_guardduty_detector_feature` | name=RDS_LOGIN_EVENTS; status=ENABLED |
| `aws_guardduty_detector_feature.runtime_monitoring` | `aws_guardduty_detector_feature` | name=RUNTIME_MONITORING; status=ENABLED |
| `aws_guardduty_detector_feature.s3_data_events` | `aws_guardduty_detector_feature` | name=S3_DATA_EVENTS; status=ENABLED |
| `aws_iam_role.config_aggregator[0]` | `aws_iam_role` | name=fedramp-baseline-lab-config-aggregator; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-config-aggregator; max_session_duration=3600 |
| `aws_iam_role_policy_attachment.config_aggregator[0]` | `aws_iam_role_policy_attachment` | role=fedramp-baseline-lab-config-aggregator; policy_arn=arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations |
| `aws_inspector2_enabler.this` | `aws_inspector2_enabler` | resource_types=EC2, ECR, LAMBDA |
| `aws_securityhub_account.this` | `aws_securityhub_account` | arn=arn:aws:securityhub:us-east-1:111111111111:hub/default; control_finding_generator=SECURITY_CONTROL; auto_enable_controls=true |
| `aws_securityhub_standards_subscription.this["aws-foundational-security-best-practices/v/1.0.0"]` | `aws_securityhub_standards_subscription` | standards_arn=arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0 |
| `aws_securityhub_standards_subscription.this["nist-800-171/v/2.0.0"]` | `aws_securityhub_standards_subscription` | standards_arn=arn:aws:securityhub:us-east-1::standards/nist-800-171/v/2.0.0 |
| `aws_securityhub_standards_subscription.this["nist-800-53/v/5.0.0"]` | `aws_securityhub_standards_subscription` | standards_arn=arn:aws:securityhub:us-east-1::standards/nist-800-53/v/5.0.0 |

## module.data[0] (`module.data[0]`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudwatch_log_group.exports["audit"]` | `aws_cloudwatch_log_group` | name=/aws/rds/cluster/fedramp-baseline-lab-aurora/audit; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_group.exports["error"]` | `aws_cloudwatch_log_group` | name=/aws/rds/cluster/fedramp-baseline-lab-aurora/error; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_group.exports["slowquery"]` | `aws_cloudwatch_log_group` | name=/aws/rds/cluster/fedramp-baseline-lab-aurora/slowquery; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_db_subnet_group.this` | `aws_db_subnet_group` | id=fedramp-baseline-lab-data |
| `aws_rds_cluster.this` | `aws_rds_cluster` | id=fedramp-baseline-lab-aurora |
| `aws_rds_cluster_instance.writer` | `aws_rds_cluster_instance` | id=fedramp-baseline-lab-aurora-1 |
| `aws_rds_cluster_parameter_group.this` | `aws_rds_cluster_parameter_group` | id=fedramp-baseline-lab-aurora-mysql8 |
| `aws_security_group.db` | `aws_security_group` | id=sg-00fc15f2f7d1762f7 |

## module.edge[0] (`module.edge[0]`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudfront_distribution.this` | `aws_cloudfront_distribution` | id=EXAMPLEDISTID |
| `aws_cloudfront_origin_access_control.s3` | `aws_cloudfront_origin_access_control` | id=E3AKTX06048ML0 |
| `aws_cloudfront_response_headers_policy.security` | `aws_cloudfront_response_headers_policy` | id=86d4514f-de1f-4eb7-9fed-768aa5d6f9ff |
| `aws_cloudwatch_log_delivery.cloudfront` | `aws_cloudwatch_log_delivery` | id=6W5OaOgM7GFLENv8 |
| `aws_cloudwatch_log_delivery_destination.cloudfront` | `aws_cloudwatch_log_delivery_destination` |  |
| `aws_cloudwatch_log_delivery_source.cloudfront` | `aws_cloudwatch_log_delivery_source` |  |
| `aws_cloudwatch_log_group.cloudfront` | `aws_cloudwatch_log_group` | name=/aws/cloudfront/fedramp-baseline-lab; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_group.waf` | `aws_cloudwatch_log_group` | name=aws-waf-logs-fedramp-baseline-lab; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_cloudwatch_log_resource_policy.vended_logs` | `aws_cloudwatch_log_resource_policy` | id=fedramp-baseline-lab-vended-logs |
| `aws_s3_bucket.origin` | `aws_s3_bucket` | bucket=fedramp-baseline-lab-origin-111111111111-us-east-1; region=us-east-1; object_lock_enabled=false |
| `aws_s3_bucket_lifecycle_configuration.origin` | `aws_s3_bucket_lifecycle_configuration` | bucket=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_bucket_ownership_controls.origin` | `aws_s3_bucket_ownership_controls` | id=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_bucket_policy.origin` | `aws_s3_bucket_policy` | id=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_bucket_public_access_block.origin` | `aws_s3_bucket_public_access_block` | id=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_bucket_server_side_encryption_configuration.origin` | `aws_s3_bucket_server_side_encryption_configuration` | id=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_bucket_versioning.origin` | `aws_s3_bucket_versioning` | id=fedramp-baseline-lab-origin-111111111111-us-east-1 |
| `aws_s3_object.index` | `aws_s3_object` | id=fedramp-baseline-lab-origin-111111111111-us-east-1/index.html |
| `aws_wafv2_web_acl.this` | `aws_wafv2_web_acl` | id=7f78c79b-1256-47f1-8213-761b2dae1e52 |
| `aws_wafv2_web_acl_logging_configuration.this` | `aws_wafv2_web_acl_logging_configuration` | id=arn:aws:wafv2:us-east-1:111111111111:global/webacl/fedramp-baseline-lab-edge/7f78c79b-1256-47f1-8213-761b2d... |

## module.network[0] (`module.network[0]`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudwatch_log_group.flow_logs` | `aws_cloudwatch_log_group` | name=/aws/vpc/flow-logs/fedramp-baseline-lab; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_default_security_group.this` | `aws_default_security_group` | id=sg-05f10c0fb26125a2f |
| `aws_flow_log.this` | `aws_flow_log` | id=fl-0b42604f5c116fa0f |
| `aws_iam_role.flow_logs` | `aws_iam_role` | name=fedramp-baseline-lab-vpc-flow-logs; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-vpc-flow-logs; max_session_duration=3600 |
| `aws_iam_role_policy.flow_logs` | `aws_iam_role_policy` | role=fedramp-baseline-lab-vpc-flow-logs; name=write-flow-logs |
| `aws_internet_gateway.this` | `aws_internet_gateway` | id=igw-035b919c55adafa6e |
| `aws_network_acl.data` | `aws_network_acl` | id=acl-0b23be2950b4e8fa8 |
| `aws_network_acl.private` | `aws_network_acl` | id=acl-0fbceb4728b1ffe41 |
| `aws_network_acl.public` | `aws_network_acl` | id=acl-07a4c922f03688cf0 |
| `aws_route_table.data` | `aws_route_table` | id=rtb-07e965a43159061c6 |
| `aws_route_table.private` | `aws_route_table` | id=rtb-0d47de4b565dc49d3 |
| `aws_route_table.public` | `aws_route_table` | id=rtb-0507c79b618c83993 |
| `aws_route_table_association.data[0]` | `aws_route_table_association` | id=rtbassoc-02538531969d09136 |
| `aws_route_table_association.data[1]` | `aws_route_table_association` | id=rtbassoc-0236db44b26355c8e |
| `aws_route_table_association.private[0]` | `aws_route_table_association` | id=rtbassoc-0ed75844c8249eb4c |
| `aws_route_table_association.private[1]` | `aws_route_table_association` | id=rtbassoc-0b82da3a18d00b569 |
| `aws_route_table_association.public[0]` | `aws_route_table_association` | id=rtbassoc-0a7953d4ff5bca7d1 |
| `aws_route_table_association.public[1]` | `aws_route_table_association` | id=rtbassoc-03ebb7ab16ba123e5 |
| `aws_security_group.endpoints[0]` | `aws_security_group` | id=sg-0a463c0244184c863 |
| `aws_security_group.quarantine` | `aws_security_group` | id=sg-09129c8bb3efcec83 |
| `aws_subnet.data[0]` | `aws_subnet` | id=subnet-0b3f37f173293fedc |
| `aws_subnet.data[1]` | `aws_subnet` | id=subnet-06bf4517af5d5fc0a |
| `aws_subnet.private[0]` | `aws_subnet` | id=subnet-0aaf11b78bf0fa07b |
| `aws_subnet.private[1]` | `aws_subnet` | id=subnet-052d6030b8ee2b09a |
| `aws_subnet.public[0]` | `aws_subnet` | id=subnet-0144c01dcc7fe29ad |
| `aws_subnet.public[1]` | `aws_subnet` | id=subnet-0e2c03f9eaaf7be5f |
| `aws_vpc.this` | `aws_vpc` | id=vpc-0975229b475c72a4b |
| `aws_vpc_endpoint.dynamodb` | `aws_vpc_endpoint` | id=vpce-005842a9a1fec3052 |
| `aws_vpc_endpoint.interface["kms-fips"]` | `aws_vpc_endpoint` | id=vpce-04d4379a7443be0ab |
| `aws_vpc_endpoint.interface["logs-fips"]` | `aws_vpc_endpoint` | id=vpce-0da047f2acf922550 |
| `aws_vpc_endpoint.interface["secretsmanager-fips"]` | `aws_vpc_endpoint` | id=vpce-0066763ae61ff6532 |
| `aws_vpc_endpoint.interface["sts-fips"]` | `aws_vpc_endpoint` | id=vpce-0b27aa815def4ee68 |
| `aws_vpc_endpoint.s3` | `aws_vpc_endpoint` | id=vpce-0c339e77b1ca4ecb9 |

## module.respond[0] (`module.respond[0]`)

| Resource | Type | Key attributes |
|---|---|---|
| `aws_cloudwatch_event_rule.guardduty_containment` | `aws_cloudwatch_event_rule` | name=fedramp-baseline-lab-guardduty-containment; description=GuardDuty findings with severity >= 7 on IAM access keys or EC2 instances. |
| `aws_cloudwatch_event_target.lambda` | `aws_cloudwatch_event_target` | rule=fedramp-baseline-lab-guardduty-containment; arn=arn:aws:lambda:us-east-1:111111111111:function:fedramp-baseline-lab-guardduty-containment |
| `aws_cloudwatch_log_group.lambda` | `aws_cloudwatch_log_group` | name=/aws/lambda/fedramp-baseline-lab-guardduty-containment; retention_in_days=400; kms_key_id=arn:aws:kms:us-east-1:111111111111:key/9a7db679-5bc6-435f-9b79-559ff1618f1d |
| `aws_iam_role.lambda` | `aws_iam_role` | name=fedramp-baseline-lab-guardduty-containment; arn=arn:aws:iam::111111111111:role/fedramp-baseline-lab-guardduty-containment; max_session_duration=3600 |
| `aws_iam_role_policy.containment` | `aws_iam_role_policy` | role=fedramp-baseline-lab-guardduty-containment; name=containment |
| `aws_lambda_function.containment` | `aws_lambda_function` | id=fedramp-baseline-lab-guardduty-containment |
| `aws_lambda_permission.eventbridge` | `aws_lambda_permission` | id=AllowEventBridgeInvoke |
| `aws_sqs_queue.dlq` | `aws_sqs_queue` | id=https://sqs-fips.us-east-1.amazonaws.com/111111111111/fedramp-baseline-lab-guardduty-containment-dlq |
| `aws_sqs_queue_policy.dlq` | `aws_sqs_queue_policy` | id=https://sqs-fips.us-east-1.amazonaws.com/111111111111/fedramp-baseline-lab-guardduty-containment-dlq |
