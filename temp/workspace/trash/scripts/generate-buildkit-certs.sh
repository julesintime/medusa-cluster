#!/bin/bash

# BuildKit Certificate Generation Script
# Generates CA, server, and client certificates for BuildKit daemon TLS communication

set -e

CERT_DIR="/tmp/buildkit-certs"
DOMAIN=${1:-"buildkitd.gitea.svc.cluster.local"}

echo "Creating certificate directory..."
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "Generating CA private key..."
openssl genrsa -out ca-key.pem 4096

echo "Generating CA certificate..."
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/C=US/ST=CA/L=San Francisco/O=BuildKit/OU=CA/CN=BuildKit CA"

echo "Generating server private key..."
openssl genrsa -out server-key.pem 4096

echo "Generating server certificate signing request..."
openssl req -subj "/C=US/ST=CA/L=San Francisco/O=BuildKit/OU=Server/CN=$DOMAIN" -sha256 -new -key server-key.pem -out server.csr

echo "Creating server certificate extensions..."
cat > server-extfile.cnf <<EOF
subjectAltName = DNS:$DOMAIN,DNS:buildkitd,DNS:localhost,IP:127.0.0.1,IP:0.0.0.0
extendedKeyUsage = serverAuth
EOF

echo "Generating server certificate..."
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca-key.pem -out cert.pem -extfile server-extfile.cnf -CAcreateserial

echo "Generating client private key..."
openssl genrsa -out client-key.pem 4096

echo "Generating client certificate signing request..."
openssl req -subj "/C=US/ST=CA/L=San Francisco/O=BuildKit/OU=Client/CN=buildkit-client" -new -key client-key.pem -out client.csr

echo "Creating client certificate extensions..."
cat > client-extfile.cnf <<EOF
extendedKeyUsage = clientAuth
EOF

echo "Generating client certificate..."
openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca-key.pem -out client-cert.pem -extfile client-extfile.cnf -CAcreateserial

echo "Setting appropriate permissions..."
chmod 400 ca-key.pem server-key.pem client-key.pem
chmod 444 ca.pem cert.pem client-cert.pem

echo "Certificate generation completed!"
echo "Files generated in $CERT_DIR:"
ls -la "$CERT_DIR"

echo ""
echo "Server certificates:"
echo "  - CA: ca.pem"
echo "  - Certificate: cert.pem" 
echo "  - Private Key: server-key.pem (renamed to key.pem)"

echo ""
echo "Client certificates:"
echo "  - CA: ca.pem"
echo "  - Certificate: client-cert.pem"
echo "  - Private Key: client-key.pem"

# Rename server key to match BuildKit expectations
mv server-key.pem key.pem

echo ""
echo "Certificates are ready for BuildKit daemon and client configuration."
