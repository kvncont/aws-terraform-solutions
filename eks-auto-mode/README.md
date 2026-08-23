# EKS Auto Mode

Este directorio contiene una infraestructura Terraform para desplegar un clúster Amazon EKS usando **EKS Auto Mode**, junto con su red, roles IAM, addons operativos y el bootstrap opcional de Argo CD.

## Arquitectura

La infraestructura se organiza en estas capas:

1. **Red**
   - Usa una VPC y subnets existentes cuando se proporcionan `vpc_id` y `subnet_ids`.
   - Si no se proporcionan, crea una VPC, un Internet Gateway, dos subnets públicas y una tabla de rutas.
   - Configura security groups para el control plane y los nodos.

2. **Clúster EKS**
   - Crea un clúster llamado `eks-<project_name>`.
   - Habilita acceso público y privado al endpoint del API server.
   - Activa los componentes de Auto Mode para compute, balanceadores de carga y almacenamiento de bloques.
   - Habilita los logs de API, autenticador, auditoría, scheduler y controller manager durante 30 días.

3. **Almacenamiento**
   - Crea un sistema de archivos Amazon EFS cifrado.
   - Crea mount targets de EFS en las subnets efectivas y un access point en `/eks`.
   - Crea un bucket S3 privado, con versionado, cifrado y bloqueo de acceso público.
   - Crea un sistema de archivos S3 Files y sus mount targets para consumir el bucket desde EKS.

4. **IAM y acceso**
   - Crea el role de servicio de EKS y el role de nodos de Auto Mode.
   - Configura un proveedor OIDC para el clúster.
   - Crea roles y asociaciones de EKS Pod Identity para CloudWatch y el driver CSI de EFS.
   - Configura permisos S3, KMS y EventBridge para S3 Files.
   - El role de Argo CD recibe `AmazonEKSClusterAdminPolicy` mediante una asociación de acceso a nivel de clúster.

5. **Addons**
   - `metrics-server`
   - `amazon-cloudwatch-observability`
   - `aws-secrets-store-csi-driver-provider`
   - `aws-efs-csi-driver`

6. **Argo CD**
   - Se puede habilitar con `enable_argocd_bootstrap`.
   - Usa la capacidad administrada de Argo CD de EKS.
   - Configura autenticación administrativa mediante IAM Identity Center.
   - Registra repositorios de GitHub usando GitHub App.
   - Crea los proyectos `backends`, `controllers` y `core`.
   - Instala una aplicación `core` y un `ApplicationSet` que descubre aplicaciones desde `kvncont/k8s`.

## Archivos principales

| Archivo | Responsabilidad |
| --- | --- |
| `providers.tf` | Providers AWS, Kubernetes y Helm. |
| `variables.tf` | Variables de entrada y validaciones. |
| `locals.tf` | Nombres normalizados y decisión sobre VPC/subnets propias o existentes. |
| `vpc.tf` | VPC opcional, subnets, rutas y security groups. |
| `security-groups.tf` | Security groups y reglas para el control plane, nodos y EFS. |
| `eks.tf` | Clúster EKS Auto Mode y grupo de logs de CloudWatch. |
| `efs.tf` | Sistema de archivos EFS, mount targets y access point. |
| `s3.tf` | Bucket S3, configuración de seguridad y sistema de archivos S3 Files. |
| `iam.tf` | Roles IAM, policies, OIDC y asociaciones de Pod Identity. |
| `addons.tf` | Addons administrados de EKS. |
| `argocd.tf` | Capability de Argo CD, secretos de repositorio y recursos Helm. |
| `outputs.tf` | Nombre, endpoint, CA, roles, red y URL de Argo CD. |
| `argocd-setup/` | Plantillas YAML para proyectos, aplicaciones y ApplicationSets. |

## Requisitos

- Terraform `1.x`.
- AWS CLI configurado con permisos suficientes para crear EKS, IAM, VPC, CloudWatch, addons y recursos de Argo CD.
- Credenciales con acceso al repositorio privado de GitHub si se habilita el bootstrap de Argo CD.
- Dos Availability Zones disponibles cuando se crea la red automáticamente.

Los providers están fijados aproximadamente a:

- AWS `~> 6.0`
- Kubernetes `~> 3.0`
- Helm `~> 2.0`

## Variables importantes

| Variable | Default | Descripción |
| --- | --- | --- |
| `deploy_region` | `us-east-1` | Región de AWS. |
| `project_name` | `auto-mode` | Prefijo usado en los nombres de recursos. |
| `cluster_version` | `null` | Versión de Kubernetes; si es `null`, usa la versión default disponible. |
| `admin_cidr` | `0.0.0.0/0` | CIDRs permitidos para acceder al API server. |
| `vpc_id` | `null` | VPC existente. Si está vacío, Terraform crea una VPC. |
| `subnet_ids` | `null` | Subnets existentes. Si está vacío, Terraform crea dos subnets. |
| `vpc_cidr` | `10.50.0.0/16` | CIDR de la VPC creada. |
| `cluster_subnet_cidrs` | `10.50.1.0/24`, `10.50.2.0/24` | CIDRs de las subnets creadas. |
| `node_pools` | `general-purpose`, `system` | Node pools administrados por EKS Auto Mode. |
| `enable_argocd_bootstrap` | `true` | Habilita la capacidad y configuración de Argo CD. |
| `idc_instance_arn` | `null` | ARN de la instancia de IAM Identity Center. |
| `argocd_admin_sso_group_id` | `null` | Grupo SSO con permisos de administrador de Argo CD. |
| `github_app_id` | `""` | ID de la GitHub App. |
| `github_app_installation_id` | `""` | ID de instalación de la GitHub App. |
| `github_app_private_key` | `""` | Clave privada de la GitHub App. Es sensible. |

## Uso

Ejecuta los comandos desde este directorio:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Para obtener la configuración de `kubectl`:

```bash
terraform output -raw eks_kubeconfig_command | sh
```

Para consultar las salidas principales:

```bash
terraform output cluster_name
terraform output cluster_endpoint
terraform output argocd_url
```

Para eliminar la infraestructura:

```bash
terraform destroy
```

## Flujo de Argo CD

El recurso `aws_eks_capability.argocd` crea la capacidad administrada en el namespace `argocd`. Después, Terraform usa el chart `argocd-apps` para crear:

- Los proyectos definidos en `argocd-setup/projects/projects.yml`.
- La aplicación `core` definida en `argocd-setup/application/core.yml`.
- El `ApplicationSet` definido en `argocd-setup/applicationset/apps.yml`.

Los archivos YAML usan `${cluster_server}` como placeholder. Terraform lo reemplaza mediante `templatefile` usando el ARN del clúster antes de entregarlo al chart Helm.

## Seguridad y operación

- `admin_cidr` controla el acceso al endpoint público de EKS. En producción debe limitarse a rangos administrativos confiables; `0.0.0.0/0` permite acceso desde cualquier dirección.
- Los secretos de GitHub App se escriben en recursos Kubernetes y en el estado de Terraform. El estado debe almacenarse en un backend remoto protegido y con cifrado.
- No se debe commitear una clave privada en `terraform.auto.tfvars`. Debe revocarse o rotarse cualquier clave que haya sido expuesta y reemplazarse por un mecanismo seguro de secretos.
- `force_destroy` y la exposición pública del endpoint son decisiones convenientes para pruebas, pero deben revisarse antes de usar este módulo en producción.
- Terraform y el provider de Kubernetes/Helm deben ejecutarse con conectividad y credenciales válidas contra el clúster una vez creado EKS.

## Outputs

El módulo publica, entre otros:

- Nombre, endpoint y versión del clúster.
- Certificado CA y proveedor OIDC.
- Roles IAM de nodos y Argo CD.
- VPC y subnets efectivas.
- ID del sistema de archivos EFS, access point y mount targets.
- Nombre y ARN del bucket S3, además del ID de S3 Files.
- Comando para configurar `kubectl`.
- URL de acceso a Argo CD.

## Consideraciones actuales

El módulo está orientado a un despliegue de laboratorio o desarrollo y contiene algunos valores deliberadamente amplios, como el acceso administrativo por defecto y el uso de subnets públicas. Antes de producción conviene revisar CIDRs, backend remoto de Terraform, cifrado del estado, retención de logs, políticas IAM y estrategia de acceso privado al API server.
