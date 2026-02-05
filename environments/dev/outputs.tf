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
