data "aws_caller_identity" "current" {}

data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "${path.module}/../networking/terraform.tfstate"
  }
}

resource "aws_vpclattice_service" "order" {
  name               = "lattice-svc-order"
  auth_type          = "AWS_IAM"
  custom_domain_name = "order.example.com"
  certificate_arn    = aws_acm_certificate.producer.arn
}

resource "aws_vpclattice_listener" "order" {
  name               = "lattice-listener-order"
  protocol           = "HTTPS"
  service_identifier = aws_vpclattice_service.order.id
  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.order.id
      }
    }
  }
}

resource "aws_vpclattice_target_group" "order" {
  name = "lattice-tg-order"
  type = "LAMBDA"
}

resource "aws_vpclattice_target_group_attachment" "order" {
  target_group_identifier = aws_vpclattice_target_group.order.id

  target {
    id = aws_lambda_function.order.arn
  }
}

resource "aws_vpclattice_service_network_service_association" "order" {
  service_identifier         = aws_vpclattice_service.order.id
  service_network_identifier = data.terraform_remote_state.networking.outputs.vpc_lattice_service_network_id
}

resource "aws_vpclattice_auth_policy" "order" {
  resource_identifier = aws_vpclattice_service.order.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSVCOrderInvokeFromLambdaConsumerPayment"
        Effect = "Allow"
        Principal = "*"
        Action = "vpc-lattice-svcs:Invoke"
        Condition = {
          StringEquals = {
            "vpc-lattice-svcs:RequestMethod" = "GET"
          }
          StringLike = {
            "vpc-lattice-svcs:RequestPath" = "/*"
          }
          ArnEquals = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iam-lambda-consumer-payment-exec"
            ]
          }
        }
        Resource = "*"
      }
    ]
  })
}
