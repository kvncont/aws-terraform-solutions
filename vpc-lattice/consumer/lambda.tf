data "archive_file" "payment" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/payment.zip"
}

resource "aws_iam_role" "lambda_payment_exec" {
  name = "iam-lambda-consumer-payment-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaServiceAssumeRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "payment_basic_execution" {
  role       = aws_iam_role.lambda_payment_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "payment_vpc_access" {
  role       = aws_iam_role.lambda_payment_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "payment_lattice_invoke" {
  name = "iam-consumer-payment-lattice-invoke"
  role = aws_iam_role.lambda_payment_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["vpc-lattice-svcs:Invoke"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "payment_lambda_sg" {
  name        = "consumer-payment-lambda-sg"
  description = "Security group for payment lambda"
  vpc_id      = aws_vpc.consumer.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "consumer-payment-lambda-sg" }
}

resource "aws_lambda_function" "payment" {
  function_name = "lambda-consumer-payment"
  role          = aws_iam_role.lambda_payment_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.payment.output_path
  source_code_hash = data.archive_file.payment.output_base64sha256
  timeout          = 15

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
    ]
    security_group_ids = [aws_security_group.payment_lambda_sg.id]
  }

  environment {
    variables = {
      LATTICE_DOMAIN       = "order.example.com"
      LATTICE_SERVICE_NAME = "vpc-lattice-svcs"
      TARGET_METHOD        = "GET"
      TARGET_PATH          = "/"
      LATTICE_CA_CERT      = file("${path.module}/../producer/certs/server-ca.crt")
    }
  }

  tags = { Name = "lambda-consumer-payment" }
}
