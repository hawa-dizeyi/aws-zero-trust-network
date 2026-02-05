output "tgw_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "hub_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.hub.id
}

output "spoke_attachment_ids" {
  value = {
    for k, v in aws_ec2_transit_gateway_vpc_attachment.spokes :
    k => v.id
  }
}
