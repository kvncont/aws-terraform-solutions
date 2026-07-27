Lambda producer

Instrucciones rápidas para empaquetar el handler y aplicar Terraform:

1. Empaquetar el handler en zip (desde la raíz del repositorio):

```bash
cd vpc-lattice/producer
zip -j lambda/handler.zip lambda/handler.py
```

2. Ejecutar `terraform init` y `terraform apply` en el módulo donde incluyas `lambda.tf`.

Notas:
- `lambda.tf` asume que existen `aws_vpc.producer` y `aws_subnet.producer_private_a|b`.
- Si prefieres que Terraform genere el zip automáticamente, puedo añadir un `data "archive_file"` para crear `handler.zip` durante la ejecución.
