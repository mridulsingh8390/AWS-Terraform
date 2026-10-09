################################################################################
# Secrets Manager baseline: empty, CMK-encrypted secret containers.
# Values are set out-of-band (console / CLI / application); they never enter
# Terraform state.
################################################################################

resource "aws_secretsmanager_secret" "this" {
  for_each = toset(var.secret_names)

  name                    = "${var.name_prefix}/${each.key}"
  description             = "${each.key} (managed container; value set outside Terraform)"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}
