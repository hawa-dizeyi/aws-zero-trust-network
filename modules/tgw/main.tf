resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, { Name = var.name })
}

# Hub attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.hub.vpc_id
  subnet_ids         = var.hub.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-hub" })
}

# Spoke attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "spokes" {
  for_each = var.spokes

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
