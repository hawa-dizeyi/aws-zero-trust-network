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
