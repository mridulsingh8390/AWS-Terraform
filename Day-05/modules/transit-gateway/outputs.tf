output "transit_gateway_id" { value = aws_ec2_transit_gateway.main.id }
output "vpc_attachment_id" { value = aws_ec2_transit_gateway_vpc_attachment.vpc.id }
output "peering_attachment_id" { value = try(aws_ec2_transit_gateway_peering_attachment.peer[0].id, null) }
