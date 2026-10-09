################################################################################
# Amazon MQ for RabbitMQ - event backbone (SOW Stage 2)
#
# Creates the BROKER only: private, CMK-encrypted, admin credentials generated and
# stored in Secrets Manager. The queue topology (DLQ / retry / replay exchanges,
# policies) is configured over the RabbitMQ management API and has to run from
# inside the VPC (self-hosted runner or an in-cluster job); it is not created here.
#
# DECISION PENDING WITH SECURUS: Amazon MQ (this module) vs RabbitMQ self-managed
# on EKS. Off by default (enable_rabbitmq = false).
################################################################################

resource "random_password" "admin" {
  length  = 28
  special = true
  # Amazon MQ forbids commas, colons and equals signs in passwords.
  override_special = "!#$%&*()-_+[]{}<>?"
}

resource "aws_security_group" "mq" {
  name        = "${var.name}-sg"
  description = "Amazon MQ RabbitMQ: AMQPS and management UI from approved CIDRs"
  vpc_id      = var.vpc_id

  ingress {
    description = "AMQPS"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "RabbitMQ management (HTTPS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

resource "aws_mq_broker" "this" {
  broker_name = var.name

  engine_type                = "RabbitMQ"
  engine_version             = var.engine_version
  host_instance_type         = var.instance_type
  deployment_mode            = var.deployment_mode
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  # SINGLE_INSTANCE takes one subnet. For CLUSTER_MULTI_AZ check the current Amazon MQ
  # documentation for the subnet requirement before enabling it.
  subnet_ids      = var.deployment_mode == "SINGLE_INSTANCE" ? [var.subnet_ids[0]] : var.subnet_ids
  security_groups = [aws_security_group.mq.id]

  encryption_options {
    use_aws_owned_key = false
    kms_key_id        = var.kms_key_arn
  }

  logs {
    general = var.enable_general_logs
  }

  user {
    username = var.admin_username
    password = random_password.admin.result
  }

  tags = var.tags
}

# Admin credentials + endpoint for applications (read via IAM; encrypted with the CMK).
resource "aws_secretsmanager_secret" "admin" {
  name                    = "${var.name}/admin"
  description             = "RabbitMQ admin credentials and AMQPS endpoint"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id = aws_secretsmanager_secret.admin.id

  secret_string = jsonencode({
    username = var.admin_username
    password = random_password.admin.result
    endpoint = aws_mq_broker.this.instances[0].endpoints[0]
    console  = aws_mq_broker.this.instances[0].console_url
  })
}
