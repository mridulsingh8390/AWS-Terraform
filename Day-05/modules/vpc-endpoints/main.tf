################################################################################
# Dragonfly private AWS service endpoints
# Keeps AWS control/data-plane traffic private. External image registries must
# be mirrored/approved separately; do not assume these endpoints remove all
# internet egress requirements.
################################################################################

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "Private endpoint access for Dragonfly AWS services"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from private VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Endpoint response traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce-sg" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
  tags              = merge(var.tags, { Name = "${var.name_prefix}-vpce-s3" })
}

locals {
  interface_services = toset(concat([
    "ecr.api",
    "ecr.dkr",
    "ec2",
    "kms-fips",
    "logs",
    "monitoring",
    "secretsmanager",
    "sts",
    "elasticloadbalancing"
  ], var.enable_ssm_endpoints ? ["ssm", "ssmmessages", "ec2messages"] : []))
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-${replace(each.value, ".", "-")}"
  })
}
