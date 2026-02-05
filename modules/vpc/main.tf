resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

locals {
  tiers = keys(var.subnet_plan)

  # Create a flat map of subnets like: "private-0", "private-1", "tgw-0"...
  subnets = merge([
    for tier, plan in var.subnet_plan : {
      for idx, netnum in plan.netnums : "${tier}-${idx}" => {
        tier = tier
        az   = var.azs[idx % length(var.azs)]
        cidr = cidrsubnet(var.cidr_block, plan.newbits, netnum)
      }
    }
  ]...)
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  map_public_ip_on_launch = (each.value.tier == "public" && var.enable_igw)

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
    Tier = each.value.tier
  })
}

resource "aws_route_table" "tier" {
  for_each = toset(local.tiers)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-rt-${each.key}" })
}

resource "aws_route_table_association" "this" {
  for_each = aws_subnet.this

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tier[each.value.tags["Tier"]].id
}

# Public tier route to IGW (if enabled)
resource "aws_route" "public_igw" {
  count = (var.enable_igw && contains(local.tiers, "public")) ? 1 : 0

  route_table_id         = aws_route_table.tier["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# NAT gateways (one per AZ) in public tier
locals {
  public_subnet_ids = [
    for k, s in aws_subnet.this : s.id if local.subnets[k].tier == "public"
  ]
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gw ? min(length(var.azs), length(local.public_subnet_ids)) : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gw ? min(length(var.azs), length(local.public_subnet_ids)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = local.public_subnet_ids[count.index]
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# Add 0.0.0.0/0 -> NAT for selected tiers (usually private only)
resource "aws_route" "tier_to_nat" {
  for_each = (var.enable_nat_gw ? toset(var.nat_route_tiers) : toset([]))

  route_table_id         = aws_route_table.tier[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
