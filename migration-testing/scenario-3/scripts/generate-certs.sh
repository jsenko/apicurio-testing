#!/bin/bash

# Generate Self-Signed SSL Certificates for Apicurio Registry
#
# This script generates:
# 1. A private key
# 2. A self-signed certificate (valid for 365 days)
# 3. A PKCS12 keystore (for Quarkus/Java apps)
# 4. A JKS truststore (for Java clients)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/certs"

# Certificate configuration
CERT_VALIDITY_DAYS=365
KEYSTORE_PASSWORD="registry123"
KEY_ALIAS="registry"
CERT_CN="localhost"
CERT_SAN="DNS:localhost,DNS:scenario3-registry-v2,DNS:scenario3-registry-v3,IP:127.0.0.1"

echo "================================================================"
echo "  Generating SSL Certificates for Scenario 3"
echo "================================================================"
echo ""
echo "Certificate Details:"
echo "  Common Name: $CERT_CN"
echo "  Subject Alt Names: $CERT_SAN"
echo "  Validity: $CERT_VALIDITY_DAYS days"
echo "  Keystore Password: $KEYSTORE_PASSWORD"
echo ""

# Create certs directory
mkdir -p "$CERTS_DIR"

# Clean up old certificates
rm -f "$CERTS_DIR"/*

echo "[1/5] Generating private key..."
openssl genrsa -out "$CERTS_DIR/registry-key.pem" 2048
echo "  ✓ Private key generated: registry-key.pem"
echo ""

echo "[2/5] Generating self-signed certificate..."
openssl req -new -x509 -key "$CERTS_DIR/registry-key.pem" \
    -out "$CERTS_DIR/registry-cert.pem" \
    -days $CERT_VALIDITY_DAYS \
    -subj "/CN=$CERT_CN/O=Apicurio Testing/OU=Migration Testing/C=US" \
    -addext "subjectAltName=$CERT_SAN"
echo "  ✓ Certificate generated: registry-cert.pem"
echo ""

echo "[3/5] Creating PKCS12 keystore for Quarkus..."
openssl pkcs12 -export \
    -in "$CERTS_DIR/registry-cert.pem" \
    -inkey "$CERTS_DIR/registry-key.pem" \
    -out "$CERTS_DIR/registry-keystore.p12" \
    -name "$KEY_ALIAS" \
    -passout pass:$KEYSTORE_PASSWORD
echo "  ✓ PKCS12 keystore created: registry-keystore.p12"
echo ""

echo "[4/5] Creating JKS truststore for Java clients..."
# Import certificate into JKS truststore
keytool -import -trustcacerts -noprompt \
    -alias "$KEY_ALIAS" \
    -file "$CERTS_DIR/registry-cert.pem" \
    -keystore "$CERTS_DIR/registry-truststore.jks" \
    -storepass "$KEYSTORE_PASSWORD"
echo "  ✓ JKS truststore created: registry-truststore.jks"
echo ""

echo "[5/5] Verifying certificate..."
openssl x509 -in "$CERTS_DIR/registry-cert.pem" -noout -text | grep -A1 "Subject:"
openssl x509 -in "$CERTS_DIR/registry-cert.pem" -noout -text | grep -A1 "Subject Alternative Name"
echo ""

# Set appropriate permissions
chmod 644 "$CERTS_DIR"/*.pem
chmod 644 "$CERTS_DIR"/*.p12
chmod 644 "$CERTS_DIR"/*.jks

# Create a README
cat > "$CERTS_DIR/README.md" << 'EOF'
# SSL Certificates for Scenario 3

This directory contains self-signed SSL certificates for testing TLS/HTTPS with Apicurio Registry.

## Files

- `registry-key.pem` - Private key (PEM format)
- `registry-cert.pem` - Self-signed certificate (PEM format)
- `registry-keystore.p12` - PKCS12 keystore for Quarkus (contains private key + certificate)
- `registry-truststore.jks` - JKS truststore for Java clients (contains certificate only)

## Passwords

- Keystore password: `registry123`
- Truststore password: `registry123`

## Usage

### Registry Configuration (Quarkus)
```yaml
environment:
  QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_FILE: /certs/registry-keystore.p12
  QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_PASSWORD: registry123
  QUARKUS_HTTP_INSECURE_REQUESTS: disabled
```

### Java Client Configuration
```java
System.setProperty("javax.net.ssl.trustStore", "/path/to/registry-truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword", "registry123");
```

## Regenerating Certificates

Run: `./scripts/generate-certs.sh`
EOF

echo "================================================================"
echo "  ✅ SSL Certificates Generated Successfully"
echo "================================================================"
echo ""
echo "Location: $CERTS_DIR"
echo ""
echo "Files created:"
echo "  - registry-key.pem (private key)"
echo "  - registry-cert.pem (certificate)"
echo "  - registry-keystore.p12 (for Quarkus)"
echo "  - registry-truststore.jks (for Java clients)"
echo "  - README.md (documentation)"
echo ""
echo "Keystore/Truststore password: $KEYSTORE_PASSWORD"
echo ""
