output "hub_vpc_id" {
  value = module.hub_vpc.vpc_id
}

output "spoke1_vpc_id" {
  value = module.spoke1_vpc.vpc_id
}

output "spoke2_vpc_id" {
  value = module.spoke2_vpc.vpc_id
}

output "hub_subnets" {
  value = module.hub_vpc.subnet_ids
}

output "tgw_id" {
  value = module.tgw.tgw_id
}

output "network_firewall_arn" {
  value = module.network_firewall.firewall_arn
}

output "hub_vpce_ids" {
  value = module.hub_endpoints.endpoint_ids
}

output "spoke1_ssm_instance_id" {
  value = module.spoke1_ssm_instance.instance_id
}

output "spoke1_vpce_ids" {
  value = module.spoke1_endpoints.endpoint_ids
}
