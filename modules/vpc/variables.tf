variable "name" { type = string }
variable "cidr_block" { type = string }
variable "azs" { type = list(string) }

variable "subnet_plan" {
  description = "Map of subnet tiers to cidr plan. netnums length should match azs length for HA."
  type = map(object({
    newbits = number
    netnums = list(number)
  }))
}

variable "enable_igw" { type = bool }
variable "enable_nat_gw" { type = bool }

variable "nat_route_tiers" {
  description = "Which tiers should get 0.0.0.0/0 -> NAT route when NAT is enabled"
  type        = list(string)
  default     = ["private"]
}

variable "tags" { type = map(string) }
