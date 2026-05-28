#!/bin/bash
# =============================================================================
# User Data - EC2 Test Client para mTLS
# Se ejecuta una sola vez al lanzar la instancia.
# =============================================================================
set -euo pipefail

# Variables inyectadas por Terraform templatefile
DOMAIN="${custom_domain}"
REGION="${aws_region}"
PROJECT="${project_name}"

# ---------------------------------------------------------------------------
# Actualizar sistema e instalar herramientas
# ---------------------------------------------------------------------------
dnf update -y
dnf install -y curl openssl jq awscli

# ---------------------------------------------------------------------------
# Crear directorio de certificados
# ---------------------------------------------------------------------------
mkdir -p /etc/mtls
chmod 700 /etc/mtls

# ---------------------------------------------------------------------------
# Descargar certificados desde S3
# ---------------------------------------------------------------------------
BUCKET="${truststore_bucket}"

aws s3 cp "s3://$${BUCKET}/mtls/client.crt"     /etc/mtls/client.crt
aws s3 cp "s3://$${BUCKET}/mtls/client.key"     /etc/mtls/client.key
aws s3 cp "s3://$${BUCKET}/mtls/server-ca.crt"  /etc/mtls/server-ca.crt

chmod 600 /etc/mtls/client.key
chmod 644 /etc/mtls/client.crt /etc/mtls/server-ca.crt

# ---------------------------------------------------------------------------
# Script helper para realizar las pruebas
# ---------------------------------------------------------------------------
cat > /usr/local/bin/test-mtls <<SCRIPT
#!/bin/bash
# Helper para probar el API Gateway con mTLS
DOMAIN="$DOMAIN"
CERT_DIR="/etc/mtls"

echo "========================================"
echo " Test mTLS - API Gateway: \$DOMAIN"
echo "========================================"

check_certs() {
  for f in client.crt client.key server-ca.crt; do
    if [[ ! -f "\$CERT_DIR/\$f" ]]; then
      echo "[ERROR] Falta el archivo: \$CERT_DIR/\$f"
      echo "Ver /etc/mtls/README.txt para instrucciones."
      exit 1
    fi
  done
}

check_certs

echo ""
echo "1. GET /health"
curl -s --cert "\$CERT_DIR/client.crt" \
        --key "\$CERT_DIR/client.key" \
        --cacert "\$CERT_DIR/server-ca.crt" \
        "https://\$DOMAIN/health" | jq .

echo ""
echo "2. GET /hello"
curl -s --cert "\$CERT_DIR/client.crt" \
        --key "\$CERT_DIR/client.key" \
        --cacert "\$CERT_DIR/server-ca.crt" \
        "https://\$DOMAIN/hello" | jq .

echo ""
echo "3. POST /echo"
curl -s --cert "\$CERT_DIR/client.crt" \
        --key "\$CERT_DIR/client.key" \
        --cacert "\$CERT_DIR/server-ca.crt" \
        -H "Content-Type: application/json" \
        -d '{"test": "mTLS funcionando correctamente"}' \
        "https://\$DOMAIN/echo" | jq .

echo ""
echo "4. Test SIN certificado (debe retornar 403)"
curl -sv --cacert "\$CERT_DIR/server-ca.crt" \
         "https://\$DOMAIN/hello" 2>&1 | grep -E "< HTTP|error|403"

echo ""
echo "========================================"
SCRIPT

chmod +x /usr/local/bin/test-mtls

# ---------------------------------------------------------------------------
# Mostrar mensaje al conectarse via SSM
# ---------------------------------------------------------------------------
cat >> /etc/motd <<'MOTD'

=========================================================
  mTLS API Gateway - EC2 Test Client
=========================================================
  1. Copiar certificados a /etc/mtls/ (ver README.txt)
  2. Ejecutar: test-mtls
=========================================================

MOTD

echo "user_data completado exitosamente"
