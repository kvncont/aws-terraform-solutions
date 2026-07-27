data "archive_file" "order" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/order.zip"
}

resource "aws_iam_role" "order" {
  name = "iam-lambda-producer-order-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaServiceAssumeRole"
        Action    = "sts:AssumeRole",
        Principal = { Service = "lambda.amazonaws.com" },
        Effect    = "Allow",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "order_basic_execution" {
  role       = aws_iam_role.order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "order_vpc_access" {
  role       = aws_iam_role.order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "order_service_lambda_sg" {
  name   = "producer-order-service-lambda-sg"
  vpc_id = aws_vpc.producer.id

  description = "SG for producer lambda"

  # Allow all outbound so the function can reach internet/resources if needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Restrictive ingress: none by default (Lambda doesn't need incoming connections)
}

resource "aws_lambda_function" "order" {
  function_name = "lambda-producer-order"
  role          = aws_iam_role.order.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.order.output_path
  source_code_hash = data.archive_file.order.output_base64sha256
  timeout          = 15

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_group_ids = [aws_security_group.order_service_lambda_sg.id]
  }

  tags = { Name = "lambda-producer-order-service" }
}
