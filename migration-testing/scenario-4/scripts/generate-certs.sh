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
REGISTRY_KEY_ALIAS="registry"
KEYCLOAK_KEY_ALIAS="keycloak"
REGISTRY_CERT_CN="localhost"
KEYCLOAK_CERT_CN="localhost"
REGISTRY_CERT_SAN="DNS:localhost,DNS:scenario4-registry-v2,DNS:scenario4-registry-v3,IP:127.0.0.1"
KEYCLOAK_CERT_SAN="DNS:localhost,DNS:scenario4-keycloak,IP:127.0.0.1"

echo "================================================================"
echo "  Generating SSL Certificates for Scenario 4"
echo "================================================================"
echo ""
echo "Registry Certificate Details:"
echo "  Common Name: $REGISTRY_CERT_CN"
echo "  Subject Alt Names: $REGISTRY_CERT_SAN"
echo "  Validity: $CERT_VALIDITY_DAYS days"
echo ""
echo "Keycloak Certificate Details:"
echo "  Common Name: $KEYCLOAK_CERT_CN"
echo "  Subject Alt Names: $KEYCLOAK_CERT_SAN"
echo "  Validity: $CERT_VALIDITY_DAYS days"
echo ""
echo "Keystore Password: $KEYSTORE_PASSWORD"
echo ""

# Create certs directory
mkdir -p "$CERTS_DIR"

# Clean up old certificates
rm -f "$CERTS_DIR"/*

# ============================================================
# Generate Registry Certificates
# ============================================================
echo "================================================================"
echo "  Generating Registry Certificates"
echo "================================================================"
echo ""

echo "[1/5] Generating registry private key..."
openssl genrsa -out "$CERTS_DIR/registry-key.pem" 2048
echo "  ✓ Private key generated: registry-key.pem"
echo ""

echo "[2/5] Generating registry self-signed certificate..."
openssl req -new -x509 -key "$CERTS_DIR/registry-key.pem" \
    -out "$CERTS_DIR/registry-cert.pem" \
    -days $CERT_VALIDITY_DAYS \
    -subj "/CN=$REGISTRY_CERT_CN/O=Apicurio Testing/OU=Migration Testing/C=US" \
    -addext "subjectAltName=$REGISTRY_CERT_SAN"
echo "  ✓ Certificate generated: registry-cert.pem"
echo ""

echo "[3/5] Creating registry PKCS12 keystore for Quarkus..."
openssl pkcs12 -export \
    -in "$CERTS_DIR/registry-cert.pem" \
    -inkey "$CERTS_DIR/registry-key.pem" \
    -out "$CERTS_DIR/registry-keystore.p12" \
    -name "$REGISTRY_KEY_ALIAS" \
    -passout pass:$KEYSTORE_PASSWORD
echo "  ✓ PKCS12 keystore created: registry-keystore.p12"
echo ""

echo "[4/5] Creating registry JKS truststore for Java clients..."
# Import certificate into JKS truststore
keytool -import -trustcacerts -noprompt \
    -alias "$REGISTRY_KEY_ALIAS" \
    -file "$CERTS_DIR/registry-cert.pem" \
    -keystore "$CERTS_DIR/registry-truststore.jks" \
    -storepass "$KEYSTORE_PASSWORD"
echo "  ✓ JKS truststore created: registry-truststore.jks"
echo ""

echo "[5/5] Verifying registry certificate..."
openssl x509 -in "$CERTS_DIR/registry-cert.pem" -noout -text | grep -A1 "Subject:"
openssl x509 -in "$CERTS_DIR/registry-cert.pem" -noout -text | grep -A1 "Subject Alternative Name"
echo ""

# ============================================================
# Generate Keycloak Certificates
# ============================================================
echo "================================================================"
echo "  Generating Keycloak Certificates"
echo "================================================================"
echo ""

echo "[1/4] Generating keycloak private key..."
openssl genrsa -out "$CERTS_DIR/keycloak-key.pem" 2048
echo "  ✓ Private key generated: keycloak-key.pem"
echo ""

echo "[2/4] Generating keycloak self-signed certificate..."
openssl req -new -x509 -key "$CERTS_DIR/keycloak-key.pem" \
    -out "$CERTS_DIR/keycloak-cert.pem" \
    -days $CERT_VALIDITY_DAYS \
    -subj "/CN=$KEYCLOAK_CERT_CN/O=Apicurio Testing/OU=Migration Testing/C=US" \
    -addext "subjectAltName=$KEYCLOAK_CERT_SAN"
echo "  ✓ Certificate generated: keycloak-cert.pem"
echo ""

echo "[3/4] Creating keycloak PKCS12 keystore..."
openssl pkcs12 -export \
    -in "$CERTS_DIR/keycloak-cert.pem" \
    -inkey "$CERTS_DIR/keycloak-key.pem" \
    -out "$CERTS_DIR/keycloak-keystore.p12" \
    -name "$KEYCLOAK_KEY_ALIAS" \
    -passout pass:$KEYSTORE_PASSWORD
echo "  ✓ PKCS12 keystore created: keycloak-keystore.p12"
echo ""

echo "[4/4] Verifying keycloak certificate..."
openssl x509 -in "$CERTS_DIR/keycloak-cert.pem" -noout -text | grep -A1 "Subject:"
openssl x509 -in "$CERTS_DIR/keycloak-cert.pem" -noout -text | grep -A1 "Subject Alternative Name"
echo ""

# ============================================================
# Create Combined Truststore for Clients
# ============================================================
echo "================================================================"
echo "  Creating Combined Truststore (Registry + Keycloak)"
echo "================================================================"
echo ""

echo "[1/2] Creating combined truststore with registry certificate..."
keytool -import -trustcacerts -noprompt \
    -alias "$REGISTRY_KEY_ALIAS" \
    -file "$CERTS_DIR/registry-cert.pem" \
    -keystore "$CERTS_DIR/client-truststore.jks" \
    -storepass "$KEYSTORE_PASSWORD"
echo "  ✓ Registry certificate imported"
echo ""

echo "[2/2] Adding keycloak certificate to combined truststore..."
keytool -import -trustcacerts -noprompt \
    -alias "$KEYCLOAK_KEY_ALIAS" \
    -file "$CERTS_DIR/keycloak-cert.pem" \
    -keystore "$CERTS_DIR/client-truststore.jks" \
    -storepass "$KEYSTORE_PASSWORD"
echo "  ✓ Keycloak certificate imported"
echo ""

# Set appropriate permissions
chmod 644 "$CERTS_DIR"/*.pem
chmod 644 "$CERTS_DIR"/*.p12
chmod 644 "$CERTS_DIR"/*.jks

# Create a README
cat > "$CERTS_DIR/README.md" << 'EOF'
# SSL Certificates for Scenario 4

This directory contains self-signed SSL certificates for testing TLS/HTTPS with Apicurio Registry and Keycloak.

## Registry Certificate Files

- `registry-key.pem` - Private key (PEM format)
- `registry-cert.pem` - Self-signed certificate (PEM format)
- `registry-keystore.p12` - PKCS12 keystore for Quarkus (contains private key + certificate)
- `registry-truststore.jks` - JKS truststore for Java clients (contains registry certificate only)

## Keycloak Certificate Files

- `keycloak-key.pem` - Private key (PEM format)
- `keycloak-cert.pem` - Self-signed certificate (PEM format)
- `keycloak-keystore.p12` - PKCS12 keystore for Keycloak (contains private key + certificate)

## Combined Truststore for Client Applications

- `client-truststore.jks` - JKS truststore containing **both** registry and keycloak certificates

**Important**: Client applications need to trust both Keycloak (for OAuth token endpoint) and
Registry (for API calls), so they should use `client-truststore.jks` instead of `registry-truststore.jks`.

## Passwords

- All keystore passwords: `registry123`
- All truststore passwords: `registry123`

## Usage

### Registry Configuration (Quarkus)
```yaml
environment:
  QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_FILE: /certs/registry-keystore.p12
  QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_PASSWORD: registry123
  QUARKUS_HTTP_INSECURE_REQUESTS: disabled
```

### Keycloak Configuration
```yaml
environment:
  KC_HTTPS_CERTIFICATE_FILE: /certs/keycloak-cert.pem
  KC_HTTPS_CERTIFICATE_KEY_FILE: /certs/keycloak-key.pem
```

### Java Client Configuration (v2 API)
```java
// Use combined truststore for both Keycloak and Registry access
System.setProperty("javax.net.ssl.trustStore", "/path/to/client-truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword", "registry123");
```

### Java Client Configuration (v3 API)
```java
// Use combined truststore for both Keycloak and Registry access
RegistryClientOptions.create(registryUrl)
    .trustStoreJks("certs/client-truststore.jks", "registry123")
    .oauth2(tokenEndpoint, clientId, clientSecret);
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
echo "Registry certificate files:"
echo "  - registry-key.pem (private key)"
echo "  - registry-cert.pem (certificate)"
echo "  - registry-keystore.p12 (for Quarkus)"
echo "  - registry-truststore.jks (for Java clients - registry only)"
echo ""
echo "Keycloak certificate files:"
echo "  - keycloak-key.pem (private key)"
echo "  - keycloak-cert.pem (certificate)"
echo "  - keycloak-keystore.p12 (for Keycloak)"
echo ""
echo "Combined truststore for client applications:"
echo "  - client-truststore.jks (contains both registry and keycloak certificates)"
echo ""
echo "Additional files:"
echo "  - README.md (documentation)"
echo ""
echo "All keystore/truststore passwords: $KEYSTORE_PASSWORD"
echo ""
