variable "name" { type = string }
variable "tags" { type = map(string) }

variable "hub" {
  type = object({
    vpc_id     = string
    subnet_ids = list(string)
  })
}

variable "spokes" {
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
}

variable "spoke_cidrs" {
  type        = map(string)
  description = "Map of spoke key -> spoke VPC CIDR (used for TGW return routes)"
}
