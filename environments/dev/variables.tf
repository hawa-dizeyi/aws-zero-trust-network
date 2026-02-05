variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming AWS resources"
}
