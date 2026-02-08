resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name = var.name
  })
}

# Dedicated TGW route table (do NOT rely on default)
resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rtb"
  })
}

# ------------------------
# VPC attachments
# ------------------------

# Hub attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.hub.vpc_id
  subnet_ids         = var.hub.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-hub"
  })
}

# Spoke attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "spokes" {
  for_each = var.spokes

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
  })
}

# ------------------------
# Route table associations
# ------------------------

resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id

  replace_existing_association = true
}

resource "aws_ec2_transit_gateway_route_table_association" "spokes" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.spokes

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id

  replace_existing_association = true
}

# ------------------------
# Routes
# ------------------------

# Default route: all internet-bound traffic from spokes goes to the hub
resource "aws_ec2_transit_gateway_route" "default_to_hub" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# Return routes: hub sends traffic back to each spoke CIDR
resource "aws_ec2_transit_gateway_route" "to_spokes" {
  for_each = var.spoke_cidrs

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spokes[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}
