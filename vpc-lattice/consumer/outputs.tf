output "payment_service_lambda_name" {
  value       = aws_lambda_function.payment.function_name
  description = "Nombre de la lambda consumer-payment"
}