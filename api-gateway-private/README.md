# Lab: API Gateway Privado con Custom Domain — Terraform

Infraestructura completamente privada en AWS: API Gateway REST v1 de tipo **PRIVATE**
accesible únicamente a través de un VPC Endpoint, con custom domain privado, certificado
ACM importado y Lambda Python como backend. No requiere IP pública en ningún componente.

## Arquitectura

```
EC2 (test-client)
  │  SSM Session Manager (sin IP pública)
  │
  └──[HTTPS]──► Route 53 (Private Zone)
                      │  A alias
                      ▼
              VPC Endpoint (execute-api)
                      │
              API Gateway REST v1
               ├── Tipo: PRIVATE
               ├── execute-api deshabilitado
               ├── Resource Policy (solo VPCE)
               └── Custom Domain PRIVATE
                         │
                    Lambda (Python)
                  (dentro de la VPC)
```

## Componentes

| Archivo | Descripción |
|---|---|
| `main.tf` | Provider AWS y versión de Terraform |
| `variables.tf` | Variables del stack |
| `outputs.tf` | Outputs: IDs, URLs, comandos SSM |
| `vpc.tf` | VPC, subnets privadas, Security Groups, VPC Endpoints SSM/S3 |
| `vpc_endpoint.tf` | VPC Endpoint execute-api + resource policy (mínimos privilegios) |
| `acm.tf` | Certificado ACM importado (server cert) |
| `apigateway.tf` | REST API PRIVATE, resource policy, stage, custom domain, base path mapping |
| `route53.tf` | Private Hosted Zone + registro A alias → VPC Endpoint |
| `s3.tf` | Bucket S3 para almacenar certificados (acceso desde EC2 vía SSM) |
| `lambda.tf` | Función Lambda Python + CloudWatch Logs |
| `ec2.tf` | EC2 sin IP pública (acceso únicamente vía SSM Session Manager) |
| `iam.tf` | Roles IAM para Lambda, EC2 y API Gateway |
| `lambda/handler.py` | Código Python de la Lambda |
| `certs/generate_certs.sh` | Genera CA del servidor y certificado del servidor |
| `templates/ec2_userdata.sh.tpl` | User data de la EC2 |

## Prerrequisitos

- Terraform >= 1.5.0
- AWS CLI configurado con permisos suficientes
- `openssl` instalado localmente

## Paso a paso

### 1. Generar los certificados del servidor

```bash
cd certs/
chmod +x generate_certs.sh
./generate_certs.sh api.internal.example.com
```

Genera:
- `server-ca.key` / `server-ca.crt` — CA del servidor
- `server.key` / `server.crt` — Certificado del servidor (wildcard `*.<dominio>`)

### 2. Configurar variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con el dominio y hosted zone deseados
```

### 3. Desplegar

```bash
terraform init
terraform plan
terraform apply
```

> **Nota:** el primer `apply` puede requerir dos fases si los IDs del VPC Endpoint
> no son conocidos en tiempo de plan. En ese caso ejecutar primero:
> `terraform apply -target=aws_vpc_endpoint.apigw` y luego `terraform apply`.

### 4. Subir certificados a S3 y copiar a la EC2

```bash
# Subir el server-ca a S3 para que la EC2 lo descargue
aws s3 cp certs/server-ca.crt s3://<bucket>/mtls/server-ca.crt

# Conectar a la EC2 vía SSM
aws ssm start-session --target <instance-id> --region us-east-1

# Desde la EC2
aws s3 cp s3://<bucket>/mtls/server-ca.crt /etc/mtls/server-ca.crt
```

### 5. Probar

```bash
# Desde la EC2 — petición simple con verificación del cert del servidor
curl --cacert /etc/mtls/server-ca.crt \
     https://<prefix-custom-domain>.api.internal.example.com/hello | jq .
```

### Verificar que el endpoint público está bloqueado

```bash
# Debe retornar 403 Forbidden
curl -k https://<api-id>.execute-api.us-east-1.amazonaws.com/hello
```

## Consideraciones de seguridad

- API Gateway solo acepta tráfico que pase por el VPC Endpoint (resource policy con condición `aws:SourceVpce`)
- El endpoint `execute-api` por defecto está deshabilitado (`disable_execute_api_endpoint = true`)
- La EC2 no tiene IP pública — acceso exclusivo vía SSM Session Manager
- IMDSv2 obligatorio en la EC2
- Bucket S3 con cifrado SSE-S3, versionado habilitado y bloqueo de acceso público
- Lambda desplegada dentro de la VPC (subnets privadas)
- Claves privadas con permisos `600`
- Custom domain con política de dominio que refuerza la condición VPCE
