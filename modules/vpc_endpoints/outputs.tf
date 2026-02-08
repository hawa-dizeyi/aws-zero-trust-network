output "endpoint_ids" {
  value = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "endpoint_sg_id" {
  value = aws_security_group.endpoints.id
}
