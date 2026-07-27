#!/bin/bash
# =============================================================================
# Script para generar certificados del servidor
# - CA del Servidor (Server CA)
# =============================================================================
set -euo pipefail

CERTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="${1:-example.com}"

echo "=================================================="
echo " Generando certificados del servidor para: $DOMAIN"
echo "=================================================="

# ---------------------------------------------------------------
# 1. CA del Servidor
# ---------------------------------------------------------------
echo "[1/6] Generando CA del Servidor..."
openssl genrsa -out "$CERTS_DIR/server-ca.key" 2048

openssl req -new -x509 -days 3650 \
  -key "$CERTS_DIR/server-ca.key" \
  -out "$CERTS_DIR/server-ca.crt" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg Server CA/OU=PKI/CN=Server Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

# ---------------------------------------------------------------
# 2. Certificado del Servidor (firmado por Server CA)
# ---------------------------------------------------------------
echo "[2/6] Generando clave y CSR del servidor..."
openssl genrsa -out "$CERTS_DIR/server.key" 2048

openssl req -new \
  -key "$CERTS_DIR/server.key" \
  -out "$CERTS_DIR/server.csr" \
  -subj "/C=CR/ST=San Jose/L=San Jose/O=MyOrg/OU=API/CN=*.$DOMAIN"

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
# 3. Permisos seguros sobre claves privadas
# ---------------------------------------------------------------
chmod 600 "$CERTS_DIR"/*.key

# ---------------------------------------------------------------
# 4. Resumen
# ---------------------------------------------------------------
echo ""
echo "=================================================="
echo " Archivos generados en: $CERTS_DIR"
echo "--------------------------------------------------"
echo "  server-ca.key / server-ca.crt  → CA del Servidor"
echo "  server.key / server.crt        → Cert del Servidor"
echo "=================================================="
echo ""
echo "Verificacion del certificado del servidor:"
openssl verify -CAfile "$CERTS_DIR/server-ca.crt" "$CERTS_DIR/server.crt"
