# Zero-trust baseline:
# allow only what we need, drop everything else.

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

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

# CloudWatch log group for Network Firewall logs (flow + alert).
resource "aws_cloudwatch_log_group" "nfw" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/network-firewall/${var.name}"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_resource_policy" "nfw" {
  count = var.enable_logging ? 1 : 0

  policy_name = "${var.name}-nfw-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowNetworkFirewallToWriteLogs",
        Effect = "Allow",
        Principal = {
          Service = "network-firewall.amazonaws.com"
        },
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn" = aws_networkfirewall_firewall.this.arn
          }
        }
      }
    ]
  })
}

resource "aws_networkfirewall_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.nfw[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.nfw[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }

  depends_on = [
  aws_cloudwatch_log_group.nfw,
  aws_cloudwatch_log_resource_policy.nfw
]
}
