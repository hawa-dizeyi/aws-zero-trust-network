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
