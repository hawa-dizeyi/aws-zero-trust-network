data "aws_region" "current" {}

locals {
  services = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "logs",
  ])
}

# SG for interface endpoints: allow HTTPS from known CIDRs only.
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-vpce-sg"
  description = "Interface endpoint SG (443 only from approved CIDRs)"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from hub/spokes"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Endpoint responses"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-vpce-sg" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.services

  vpc_id              = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.id}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.endpoints.id]

  tags = merge(var.tags, { Name = "${var.name}-vpce-${each.value}" })
}
