variable "name" { type = string }
variable "vpc_id" { type = string }

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets to place interface endpoints in."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to reach the interface endpoints over 443."
}

variable "tags" { type = map(string) }
