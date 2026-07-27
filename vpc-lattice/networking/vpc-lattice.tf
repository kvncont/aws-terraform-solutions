data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_vpclattice_service_network" "hub" {
  name      = "lattice-sn-hub"
  auth_type = "AWS_IAM"
  tags      = { Name = "lattice-sn-hub" }
}

resource "aws_vpclattice_resource_policy" "hub" {
  resource_arn = aws_vpclattice_service_network.hub.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowOrgAccountsToAssociate"
      Effect = "Allow"
      Principal = {
        AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = [
        "vpc-lattice:CreateServiceNetworkVpcAssociation",
        "vpc-lattice:CreateServiceNetworkServiceAssociation",
        "vpc-lattice:GetServiceNetwork"
      ]
      # Condition = {
      #   StringEquals = {
      #     "aws:PrincipalOrgID" = data.aws_organizations_organization.current.id
      #   }
      #   StringNotEquals = {
      #     "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
      #   }
      # }
      Resource = aws_vpclattice_service_network.hub.arn
    }]
  })
}

resource "aws_vpclattice_auth_policy" "hub" {
  resource_identifier = aws_vpclattice_service_network.hub.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPaymentServiceInvoke"
      Effect    = "Allow"
      Principal = "*"
      # Principal = {
      #   AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/iam-lambda-consumer-payment-service-exec"
      # }
      Action   = "vpc-lattice-svcs:Invoke"
      Resource = "*"
    }]
  })
}
