variable "aws_region" { type = string }
variable "env" { type = string }
variable "name_prefix" { type = string }

variable "azs" {
  type        = list(string)
  description = "AZs used (e.g. [eu-west-1a, eu-west-1b])"
}

variable "hub_vpc_cidr" { type = string }
variable "spoke1_vpc_cidr" { type = string }
variable "spoke2_vpc_cidr" { type = string }
