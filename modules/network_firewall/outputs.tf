output "firewall_arn" {
  value = aws_networkfirewall_firewall.this.arn
}

# Map AZ => endpoint_id (we'll use these in route tables)
output "firewall_endpoints_by_az" {
  value = {
    for s in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    s.availability_zone => s.attachment[0].endpoint_id
  }
}

output "log_group_name" {
  value       = try(aws_cloudwatch_log_group.nfw[0].name, null)
  description = "CloudWatch Log Group receiving NFW logs"
}
