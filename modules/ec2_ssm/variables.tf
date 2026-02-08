variable "name" { type = string }

variable "subnet_id" {
  type        = string
  description = "Private subnet for the instance."
}

variable "vpc_id" { type = string }

variable "allowed_egress_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed for outbound traffic (kept tight)."
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "tags" { type = map(string) }
