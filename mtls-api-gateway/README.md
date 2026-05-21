# API Gateway Privado con mTLS — Terraform

Infraestructura completamente privada en AWS: API Gateway HTTP v2 con autenticación
mutua TLS (mTLS), acceso exclusivo desde la VPC vía VPC Endpoint, y una Lambda
Python como backend.

## Arquitectura

```
EC2 (test-client)
  │  SSM Session Manager (sin IP pública)
  │
  ├──[HTTPS + cert cliente]──► VPC Endpoint (execute-api)
  │                                    │
  │                         API Gateway HTTP v2
  │                          ├── mTLS (truststore en S3)
  │                          ├── Resource Policy (solo VPCE)
  │                          └── Custom Domain (ACM + Route 53)
  │                                    │
  │                              Lambda (Python)
  │                           (dentro de la VPC)
```

## Archivos

| Archivo | Descripción |
|---|---|
| `main.tf` | Provider y versión de Terraform |
| `variables.tf` | Definición de variables |
| `outputs.tf` | Outputs del stack |
| `vpc.tf` | VPC, subnets, SGs, VPC Endpoints SSM/S3 |
| `vpc_endpoint.tf` | VPC Endpoint execute-api + resource policy |
| `s3.tf` | Bucket S3 para el truststore de mTLS |
| `acm.tf` | Certificado ACM + validación DNS |
| `apigateway.tf` | HTTP API v2 con mTLS, rutas, stage, custom domain |
| `lambda.tf` | Lambda Python + CloudWatch Logs |
| `ec2.tf` | EC2 sin IP pública (acceso via SSM) |
| `iam.tf` | Roles IAM para Lambda, EC2, API Gateway |
| `route53.tf` | Alias record para el custom domain |
| `lambda/handler.py` | Código Python de la Lambda |
| `certs/generate_certs.sh` | Script para generar los certificados localmente |
| `templates/ec2_userdata.sh.tpl` | User data de la EC2 |

## Paso a paso

### 1. Generar los certificados

```bash
cd certs/
chmod +x generate_certs.sh
./generate_certs.sh api.internal.example.com
```

Esto genera:
- `server-ca.crt` / `server-ca.key` → CA del servidor
- `server.crt` / `server.key` → Certificado del servidor
- `client-ca.crt` / `client-ca.key` → CA del cliente
- `client.crt` / `client.key` → Certificado del cliente
- `truststore.pem` → Truststore para API Gateway (= `client-ca.crt`)

### 2. Configurar variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con el hosted_zone_id real y el dominio
```

### 3. Desplegar

```bash
terraform init
terraform plan
terraform apply
```

> El certificado ACM puede tardar hasta 5 minutos en validarse.

### 4. Copiar certificados a la EC2

Conectarse vía SSM Session Manager:

```bash
aws ssm start-session --target <instance-id> --region us-east-1
```

Desde la EC2, copiar los certificados desde S3 (o subirlos antes al bucket):

```bash
aws s3 cp s3://<bucket>/mtls/client.crt  /etc/mtls/client.crt
aws s3 cp s3://<bucket>/mtls/client.key  /etc/mtls/client.key
aws s3 cp s3://<bucket>/mtls/server-ca.crt /etc/mtls/server-ca.crt
chmod 600 /etc/mtls/*.key
```

### 5. Probar

```bash
# Desde la EC2
test-mtls

# O manualmente
curl --cert /etc/mtls/client.crt \
     --key  /etc/mtls/client.key \
     --cacert /etc/mtls/server-ca.crt \
     https://api.internal.example.com/hello | jq .
```

### Verificar que el acceso público está bloqueado

```bash
# Desde fuera de la VPC — debe retornar 403
curl -k https://<api-id>.execute-api.us-east-1.amazonaws.com/hello
```

## Seguridad

- El API Gateway solo acepta conexiones que pasen por el VPC Endpoint (resource policy)
- mTLS valida el certificado del cliente contra el truststore (Client CA)
- La EC2 no tiene IP pública — acceso solo vía SSM Session Manager
- IMDSv2 obligatorio en la EC2
- Bucket S3 con cifrado KMS, versionado y acceso público bloqueado
- Lambda dentro de la VPC (subnets privadas)
- Claves privadas con permisos `600`
