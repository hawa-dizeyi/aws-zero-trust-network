variable "name" { type = string }
variable "vpc_id" { type = string }

variable "firewall_subnet_ids" {
  type        = list(string)
  description = "Subnets where Network Firewall endpoints will be created (one per AZ)."
}

variable "tags" { type = map(string) }
