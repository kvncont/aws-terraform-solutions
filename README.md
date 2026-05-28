# AWS Terraform Solutions

Colección de labs de arquitecturas AWS implementados con Terraform. Cada directorio
es un lab independiente y desplegable, diseñado para explorar patrones de seguridad,
conectividad privada y buenas prácticas en AWS.

## Labs disponibles

| Lab | Descripción | Servicios principales |
|---|---|---|
| [`private-api-gateway`](./private-api-gateway/) | API Gateway REST PRIVATE accesible solo desde la VPC via VPC Endpoint y custom domain privado | API GW, VPC Endpoint, ACM, Route 53, Lambda, EC2, S3 |
| [`private-api-gateway-mtls`](./private-api-gateway-mtls/) | Igual que el anterior pero con un ALB interno que termina mTLS (verifica certificado del cliente) antes de llegar al VPC Endpoint | API GW, ALB, mTLS, VPC Endpoint, ACM, Route 53, Lambda, EC2, S3 |

## Estructura del repositorio

```
aws-terraform-solutions/
├── README.md                    ← este archivo
├── private-api-gateway/         ← Lab: API GW PRIVATE + custom domain
│   ├── *.tf
│   ├── certs/
│   ├── lambda/
│   └── templates/
└── private-api-gateway-mtls/    ← Lab: API GW PRIVATE + ALB con mTLS
    ├── *.tf
    ├── certs/
    ├── lambda/
    └── templates/
```

## Prerrequisitos comunes

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado con permisos suficientes
- `openssl` instalado localmente (para generación de certificados)

## Cómo usar un lab

Cada lab tiene su propio `README.md` con instrucciones detalladas. El flujo general es:

```bash
cd <nombre-del-lab>/

# 1. Generar certificados (si el lab los requiere)
cd certs/ && bash generate_certs.sh <dominio> && cd ..

# 2. Configurar variables
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars

# 3. Desplegar
terraform init
terraform plan
terraform apply
```

## Convenciones

- Todos los recursos son **completamente privados**: ningún componente tiene IP pública.
- Acceso a instancias EC2 exclusivamente via **SSM Session Manager**.
- Las claves privadas se generan localmente y se almacenan en S3 cifrado (nunca en el estado de Terraform).
- Cada lab incluye un EC2 de prueba para validar la conectividad desde dentro de la VPC.
