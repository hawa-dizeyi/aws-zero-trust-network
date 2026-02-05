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
