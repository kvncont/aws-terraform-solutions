# Lab: API Gateway Privado con mTLS en ALB — Terraform

Infraestructura completamente privada en AWS: API Gateway REST v1 de tipo **PRIVATE**
protegido por un ALB interno que termina **mTLS** (verifica el certificado del cliente
contra un truststore). El ALB reenvía el tráfico al VPC Endpoint de execute-api.
Ningún componente tiene IP pública.

## Arquitectura

```
EC2 (test-client)
  │  SSM Session Manager (sin IP pública)
  │
  └──[HTTPS + cert cliente]──► Route 53 (Private Zone)
                                      │  A alias
                                      ▼
                              ALB Interno (HTTPS/443)
                               ├── mTLS: verifica cert cliente
                               ├── Truststore: Client CA (S3)
                               └── TLS: cert servidor (ACM)
                                      │  forward
                                      ▼
                          Target Group → ENIs del VPC Endpoint
                                      │
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
| `alb.tf` | ALB interno, listener HTTPS con mTLS, trust store, target group → VPC Endpoint ENIs |
| `acm.tf` | Certificado ACM importado (server cert) |
| `apigateway.tf` | REST API PRIVATE, resource policy, stage, custom domain, base path mapping |
| `route53.tf` | Private Hosted Zone + registro A alias → ALB interno |
| `s3.tf` | Bucket S3 para truststore (Client CA) y certificados de la EC2 |
| `lambda.tf` | Función Lambda Python + CloudWatch Logs |
| `ec2.tf` | EC2 sin IP pública (acceso únicamente vía SSM Session Manager) |
| `iam.tf` | Roles IAM para Lambda, EC2 y API Gateway |
| `lambda/handler.py` | Código Python de la Lambda |
| `certs/generate_certs.sh` | Genera CA servidor, cert servidor, CA cliente, cert cliente y truststore |
| `templates/ec2_userdata.sh.tpl` | User data de la EC2 |

## Prerrequisitos

- Terraform >= 1.5.0
- AWS CLI configurado con permisos suficientes
- `openssl` instalado localmente

## Paso a paso

### 1. Generar los certificados

```bash
cd certs/
chmod +x generate_certs.sh
./generate_certs.sh api.internal.example.com
```

Genera:
- `server-ca.key` / `server-ca.crt` — CA del servidor
- `server.key` / `server.crt` — Certificado del servidor (wildcard `*.<dominio>`)
- `client-ca.key` / `client-ca.crt` — CA del cliente
- `client.key` / `client.crt` — Certificado del cliente
- `truststore.pem` — Truststore para el ALB (= `client-ca.crt`)

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

> **Nota:** el primer `apply` puede requerir dos fases. Si los IDs del VPC Endpoint
> no son conocidos en tiempo de plan, ejecutar primero:
> `terraform apply -target=aws_vpc_endpoint.apigw` y luego `terraform apply`.

### 4. Copiar certificados a la EC2

```bash
# Conectar a la EC2 vía SSM
aws ssm start-session --target <instance-id> --region us-east-1

# Desde la EC2
aws s3 cp s3://<bucket>/mtls/client.crt    /etc/mtls/client.crt
aws s3 cp s3://<bucket>/mtls/client.key    /etc/mtls/client.key
aws s3 cp s3://<bucket>/mtls/server-ca.crt /etc/mtls/server-ca.crt
chmod 600 /etc/mtls/*.key
```

### 5. Probar

```bash
# Desde la EC2 — mTLS: presenta cert cliente, verifica cert servidor
curl --cert    /etc/mtls/client.crt \
     --key     /etc/mtls/client.key \
     --cacert  /etc/mtls/server-ca.crt \
     https://<prefix-custom-domain>.api.internal.example.com/hello | jq .

# Sin cert cliente — el ALB debe rechazar con 400 (mTLS fallido)
curl --cacert /etc/mtls/server-ca.crt \
     https://<prefix-custom-domain>.api.internal.example.com/hello
```

### Verificar que el endpoint público está bloqueado

```bash
# Debe retornar 403 Forbidden
curl -k https://<api-id>.execute-api.us-east-1.amazonaws.com/hello
```

## Diferencia con `private-api-gateway`

| Aspecto | private-api-gateway | private-api-gateway-mtls |
|---|---|---|
| mTLS | No | Sí (ALB verifica cert cliente) |
| ALB interno | No | Sí |
| Punto de entrada DNS | VPC Endpoint | ALB |
| Truststore | No aplica | Client CA en S3 |
| Complejidad | Menor | Mayor |
| Casos de uso | API interna sin auth de cert | API interna con autenticación mutua |

## Consideraciones de seguridad

- El ALB verifica el certificado del cliente contra el truststore (Client CA) en modo `verify`
- API Gateway solo acepta tráfico que pase por el VPC Endpoint (resource policy con condición `aws:SourceVpce`)
- El endpoint `execute-api` por defecto está deshabilitado (`disable_execute_api_endpoint = true`)
- La EC2 no tiene IP pública — acceso exclusivo vía SSM Session Manager
- IMDSv2 obligatorio en la EC2
- Bucket S3 con cifrado SSE-S3, versionado habilitado y bloqueo de acceso público
- Lambda desplegada dentro de la VPC (subnets privadas)
- Claves privadas con permisos `600`
- TLS 1.3 en el listener del ALB (`ELBSecurityPolicy-TLS13-1-2-2021-06`)
