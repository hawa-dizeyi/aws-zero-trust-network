terraform {
  backend "local" {}
}

resource "aws_resourcegroups_group" "this" {
  name = "${var.name_prefix}-${var.env}-rg"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        { Key = "Project", Values = ["aws-zero-trust-network"] }
      ]
    })
  }
}
