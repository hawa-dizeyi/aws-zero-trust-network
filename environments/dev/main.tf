terraform {
  backend "local" {}
}

locals {
  tags = {
    Environment = var.env
    NamePrefix  = var.name_prefix
  }
}

# HUB VPC (inspection + egress)
module "hub_vpc" {
  source     = "../../modules/vpc"
  name       = "${var.name_prefix}-${var.env}-hub"
  cidr_block = var.hub_vpc_cidr
  azs        = var.azs

  subnet_plan = {
    public = {
      newbits = 8
      netnums = [0, 1]
    }
    private = {
      newbits = 8
      netnums = [10, 11]
    }
    tgw = {
      newbits = 8
      netnums = [20, 21]
    }
    firewall = {
      newbits = 8
      netnums = [30, 31]
    }
  }

  enable_igw      = true
  enable_nat_gw   = true
  nat_route_tiers = ["private"] # do NOT auto-route TGW or firewall tiers to NAT
  tags            = merge(local.tags, { Role = "hub" })
}

# SPOKE 1 VPC (private only)
module "spoke1_vpc" {
  source     = "../../modules/vpc"
  name       = "${var.name_prefix}-${var.env}-spoke1"
  cidr_block = var.spoke1_vpc_cidr
  azs        = var.azs

  subnet_plan = {
    private = {
      newbits = 8
      netnums = [10, 11]
    }
    tgw = {
      newbits = 8
      netnums = [20, 21]
    }
  }

  enable_igw    = false
  enable_nat_gw = false
  tags          = merge(local.tags, { Role = "spoke1" })
}

# SPOKE 2 VPC (private only)
module "spoke2_vpc" {
  source     = "../../modules/vpc"
  name       = "${var.name_prefix}-${var.env}-spoke2"
  cidr_block = var.spoke2_vpc_cidr
  azs        = var.azs

  subnet_plan = {
    private = {
      newbits = 8
      netnums = [10, 11]
    }
    tgw = {
      newbits = 8
      netnums = [20, 21]
    }
  }

  enable_igw    = false
  enable_nat_gw = false
  tags          = merge(local.tags, { Role = "spoke2" })
}

# TGW
module "tgw" {
  source = "../../modules/tgw"
  name   = "${var.name_prefix}-${var.env}-tgw"

  hub = {
    vpc_id     = module.hub_vpc.vpc_id
    subnet_ids = module.hub_vpc.subnet_ids["tgw"]
  }

  spokes = {
    spoke1 = {
      vpc_id     = module.spoke1_vpc.vpc_id
      subnet_ids = module.spoke1_vpc.subnet_ids["tgw"]
    }
    spoke2 = {
      vpc_id     = module.spoke2_vpc.vpc_id
      subnet_ids = module.spoke2_vpc.subnet_ids["tgw"]
    }
  }

  spoke_cidrs = {
    spoke1 = var.spoke1_vpc_cidr
    spoke2 = var.spoke2_vpc_cidr
  }

  tags = local.tags
}

# Spoke traffic goes to the hub via TGW.
# No direct internet access from spokes.
resource "aws_route" "spoke1_default_to_tgw" {
  route_table_id         = module.spoke1_vpc.route_table_ids["private"]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

resource "aws_route" "spoke2_default_to_tgw" {
  route_table_id         = module.spoke2_vpc.route_table_ids["private"]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

module "network_firewall" {
  source = "../../modules/network_firewall"

  name                = "${var.name_prefix}-${var.env}-nfw"
  vpc_id              = module.hub_vpc.vpc_id
  firewall_subnet_ids = module.hub_vpc.subnet_ids["firewall"]
  enable_logging      = true

  tags = local.tags
}

# Hub TGW subnets share one route table in our setup.
# Default route from the TGW tier goes to the Network Firewall endpoint (in-path inspection).
resource "aws_route" "hub_tgw_default_to_firewall" {
  route_table_id         = module.hub_vpc.route_table_ids["tgw"]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall.firewall_endpoints_by_az[var.azs[0]]
}

# After inspection, send internet-bound traffic to NAT (hub egress).
resource "aws_route" "hub_firewall_to_nat" {
  route_table_id         = module.hub_vpc.route_table_ids["firewall"]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.hub_vpc.nat_gateway_ids[0]
}

# Return path: traffic destined to spokes goes back to TGW.
resource "aws_route" "hub_firewall_to_spoke1" {
  route_table_id         = module.hub_vpc.route_table_ids["firewall"]
  destination_cidr_block = var.spoke1_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

resource "aws_route" "hub_firewall_to_spoke2" {
  route_table_id         = module.hub_vpc.route_table_ids["firewall"]
  destination_cidr_block = var.spoke2_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

module "hub_endpoints" {
  source = "../../modules/vpc_endpoints"

  name       = "${var.name_prefix}-${var.env}-hub"
  vpc_id     = module.hub_vpc.vpc_id
  subnet_ids = module.hub_vpc.subnet_ids["private"]

  allowed_cidr_blocks = [
    var.hub_vpc_cidr,
    var.spoke1_vpc_cidr,
    var.spoke2_vpc_cidr,
  ]

  tags = local.tags
}

module "spoke1_endpoints" {
  source = "../../modules/vpc_endpoints"

  name       = "${var.name_prefix}-${var.env}-spoke1"
  vpc_id     = module.spoke1_vpc.vpc_id
  subnet_ids = module.spoke1_vpc.subnet_ids["private"]

  # Only Spoke1 needs to reach these endpoints (keep it tight)
  allowed_cidr_blocks = [var.spoke1_vpc_cidr]

  tags = local.tags
}

# Spoke 1 — private EC2 instance with SSM-only access (no inbound, no public IP)
module "spoke1_ssm_instance" {
  source = "../../modules/ec2_ssm"

  name      = "${var.name_prefix}-${var.env}-spoke1-ssm"
  vpc_id    = module.spoke1_vpc.vpc_id
  subnet_id = module.spoke1_vpc.subnet_ids["private"][0]

  # Allow egress only to known internal CIDRs (hub endpoints + DNS paths)
  allowed_egress_cidr_blocks = [
    var.hub_vpc_cidr,
    var.spoke1_vpc_cidr,
    var.spoke2_vpc_cidr,
  ]

  tags = local.tags
}
