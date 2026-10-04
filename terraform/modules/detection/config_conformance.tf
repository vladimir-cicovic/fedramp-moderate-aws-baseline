# AWS Config conformance pack: Operational Best Practices for NIST 800-53 Rev
# 5
# (CA-2, CA-7, CM-2, CM-6, CM-8, RA-5, SI-4)

resource "aws_config_conformance_pack" "nist_800_53_rev5" {
  count = var.enable_conformance_pack ? 1 : 0

  name          = "nist-800-53-rev-5"
  template_body = file("${path.module}/templates/nist-800-53-rev-5.yaml")

  # IA-5(1): password policy must match what the identity module enforces.
  input_parameter {
    parameter_name  = "IamPasswordPolicyParamMaxPasswordAge"
    parameter_value = tostring(var.password_policy.max_password_age)
  }

  input_parameter {
    parameter_name  = "IamPasswordPolicyParamMinimumPasswordLength"
    parameter_value = tostring(var.password_policy.minimum_password_length)
  }

  input_parameter {
    parameter_name  = "IamPasswordPolicyParamPasswordReusePrevention"
    parameter_value = tostring(var.password_policy.password_reuse_prevention)
  }

  # AC-2(3): FedRAMP Moderate Rev 5 assignment is 35 days of inactivity.
  input_parameter {
    parameter_name  = "IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge"
    parameter_value = "35"
  }

  # IA-5: access keys, if any exist, rotate within 90 days.
  input_parameter {
    parameter_name  = "AccessKeysRotatedParamMaxAccessKeyAge"
    parameter_value = "90"
  }

  # AU-6: alarms must have an ALARM action (they do). The baseline alarms use
  # treat_missing_data = notBreaching, so an INSUFFICIENT_DATA action would
  # only add noise; the rule is told not to require one.
  input_parameter {
    parameter_name  = "CloudwatchAlarmActionCheckParamInsufficientDataActionRequired"
    parameter_value = "false"
  }
}
