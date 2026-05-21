#!/bin/bash
# =============================================================================
# Script para generar certificados mTLS
# - CA del Servidor (Server CA) → firma el certificado del API Gateway / dominio
# - CA del Cliente (Client CA)  → firma el certificado del cliente (truststore)
# =============================================================================
set -euo pipefail

CERTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="${1:-api.internal.example.com}"

echo "=================================================="
echo " Generando certificados mTLS para: $DOMAIN"
echo "=================================================="

# ---------------------------------------------------------------
# 1. CA del Servidor
# ---------------------------------------------------------------
echo "[1/6] Generando CA del Servidor..."
openssl genrsa -out "$CERTS_DIR/server-ca.key" 4096

openssl req -new -x509 -days 3650 \
  -key "$CERTS_DIR/server-ca.key" \
  -out "$CERTS_DIR/server-ca.crt" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg Server CA/OU=PKI/CN=Server Root CA"

# ---------------------------------------------------------------
# 2. Certificado del Servidor (firmado por Server CA)
# ---------------------------------------------------------------
echo "[2/6] Generando clave y CSR del servidor..."
openssl genrsa -out "$CERTS_DIR/server.key" 4096

openssl req -new \
  -key "$CERTS_DIR/server.key" \
  -out "$CERTS_DIR/server.csr" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg/OU=API/CN=$DOMAIN"

echo "[3/6] Firmando certificado del servidor con Server CA..."
cat > "$CERTS_DIR/server-ext.cnf" <<EOF
[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF

openssl x509 -req -days 825 \
  -in "$CERTS_DIR/server.csr" \
  -CA "$CERTS_DIR/server-ca.crt" \
  -CAkey "$CERTS_DIR/server-ca.key" \
  -CAcreateserial \
  -out "$CERTS_DIR/server.crt" \
  -extfile "$CERTS_DIR/server-ext.cnf" \
  -extensions v3_req

# ---------------------------------------------------------------
# 3. CA del Cliente
# ---------------------------------------------------------------
echo "[4/6] Generando CA del Cliente..."
openssl genrsa -out "$CERTS_DIR/client-ca.key" 4096

openssl req -new -x509 -days 3650 \
  -key "$CERTS_DIR/client-ca.key" \
  -out "$CERTS_DIR/client-ca.crt" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg Client CA/OU=PKI/CN=Client Root CA"

# ---------------------------------------------------------------
# 4. Certificado del Cliente (firmado por Client CA)
# ---------------------------------------------------------------
echo "[5/6] Generando clave y certificado del cliente..."
openssl genrsa -out "$CERTS_DIR/client.key" 4096

openssl req -new \
  -key "$CERTS_DIR/client.key" \
  -out "$CERTS_DIR/client.csr" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg/OU=Client/CN=internal-client"

openssl x509 -req -days 825 \
  -in "$CERTS_DIR/client.csr" \
  -CA "$CERTS_DIR/client-ca.crt" \
  -CAkey "$CERTS_DIR/client-ca.key" \
  -CAcreateserial \
  -out "$CERTS_DIR/client.crt"

# ---------------------------------------------------------------
# 5. Truststore (PEM con la Client CA — usado por API Gateway mTLS)
# ---------------------------------------------------------------
echo "[6/6] Generando truststore.pem..."
cp "$CERTS_DIR/client-ca.crt" "$CERTS_DIR/truststore.pem"

# ---------------------------------------------------------------
# 6. Permisos seguros sobre claves privadas
# ---------------------------------------------------------------
chmod 600 "$CERTS_DIR"/*.key

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
echo ""
echo "=================================================="
echo " Archivos generados en: $CERTS_DIR"
echo "--------------------------------------------------"
echo "  server-ca.key / server-ca.crt  → CA del Servidor"
echo "  server.key / server.crt        → Cert del Servidor"
echo "  client-ca.key / client-ca.crt  → CA del Cliente"
echo "  client.key / client.crt        → Cert del Cliente"
echo "  truststore.pem                 → Truststore (subir a S3)"
echo "=================================================="
echo ""
echo "Verificacion del certificado del servidor:"
openssl verify -CAfile "$CERTS_DIR/server-ca.crt" "$CERTS_DIR/server.crt"

echo "Verificacion del certificado del cliente:"
openssl verify -CAfile "$CERTS_DIR/client-ca.crt" "$CERTS_DIR/client.crt"
