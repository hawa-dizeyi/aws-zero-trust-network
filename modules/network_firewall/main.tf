# Zero-trust baseline:
# allow only what we need, drop everything else.
# We'll expand this later when workloads are added.

resource "aws_networkfirewall_rule_group" "stateful_zero_trust" {
  capacity = 100
  name     = "${var.name}-stateful-zero-trust"
  type     = "STATEFUL"

  lifecycle {
    create_before_destroy = true
  }

  rule_group {
    rules_source {
      rules_string = <<-EOT
        # DNS
        pass udp any any -> any 53 (msg:"allow dns udp"; sid:1001; rev:1;)
        pass tcp any any -> any 53 (msg:"allow dns tcp"; sid:1002; rev:1;)

        # HTTPS outbound
        pass tcp any any -> any 443 (msg:"allow https outbound"; sid:1003; rev:1;)

        # NTP
        pass udp any any -> any 123 (msg:"allow ntp"; sid:1004; rev:1;)

        # Default deny
        drop ip any any -> any any (msg:"default deny"; sid:1999; rev:1;)
      EOT
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-policy"

  lifecycle {
    create_before_destroy = true
  }

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_zero_trust.arn
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = toset(var.firewall_subnet_ids)
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, { Name = var.name })
}
