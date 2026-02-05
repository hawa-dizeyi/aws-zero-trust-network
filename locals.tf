locals {
  project = "aws-zero-trust-network"

  tags = {
    Project   = local.project
    Owner     = "hawa-dizeyi"
    ManagedBy = "Terraform"
  }
}
