output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = {
    for tier in keys(var.subnet_plan) :
    tier => [
      for k, s in aws_subnet.this : s.id
      if local.subnets[k].tier == tier
    ]
  }
}

output "route_table_ids" {
  value = {
    for tier, rt in aws_route_table.tier :
    tier => rt.id
  }
}

output "route_table_ids_by_subnet" {
  value = {
    for k, s in aws_subnet.this :
    s.id => aws_route_table.tier[local.subnets[k].tier].id
  }
}

output "nat_gateway_ids" {
  value = [for ngw in aws_nat_gateway.this : ngw.id]
}
