resource "aws_ec2_transit_gateway" "main" {
  description                     = var.name
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  dns_support        = "enable"
  ipv6_support       = "disable"

  tags = merge(var.tags, { Name = "${var.name}-vpc-attachment" })
}

resource "aws_ec2_transit_gateway_peering_attachment" "peer" {
  count = var.enable_peering ? 1 : 0

  transit_gateway_id      = aws_ec2_transit_gateway.main.id
  peer_transit_gateway_id = var.peer_tgw_id
  peer_region             = var.peer_region

  tags = merge(var.tags, { Name = "${var.name}-peer" })
}
