# Migration Testing Scenario 3: TLS/HTTPS Configuration with PostgreSQL Migration

## Overview

This scenario demonstrates how to configure **TLS/HTTPS** for Apicurio Registry v2.6.x and v3.1.x, including
server-side SSL configuration and client-side trust store setup. It also tests the complete migration path
using PostgreSQL storage with nginx reverse proxy performing TLS passthrough.

**Primary Focus**: TLS/HTTPS configuration for secure registry deployments
**Secondary Focus**: PostgreSQL-based migration with production-like traffic switching
**Complexity**: Medium
**Prerequisites**: Docker, Java 11+, Maven 3.8+, jq, curl, openssl, keytool

## Quick Start

Run the complete automated migration test:

```bash
# Run all migration steps automatically
./run-scenario-3.sh

# Or run individual steps manually
./scripts/generate-certs.sh    # Generate self-signed certificates
./scripts/build-clients.sh     # Build Java client applications
./scripts/step-A-deploy-v2.sh
./scripts/step-B-deploy-nginx.sh
# ... etc
```

Clean up after testing:

```bash
./scripts/cleanup.sh
```

## Objectives

### TLS/HTTPS Configuration
1. ✅ Generate self-signed SSL certificates for testing
2. ✅ Configure Apicurio Registry v2 to require HTTPS
3. ✅ Configure Apicurio Registry v3 to require HTTPS
4. ✅ Configure nginx for TLS passthrough to backend registries
5. ✅ Configure Java clients to trust self-signed certificates
6. ✅ Demonstrate different SSL configuration approaches for v2 vs v3 clients

### Migration Testing
1. ✅ Validate export/import process preserves all data over HTTPS
2. ✅ Verify v2 API backward compatibility in 3.1.x with TLS
3. ✅ Test new v3 API functionality after migration
4. ✅ Simulate production-like traffic switching with secure connections
5. ✅ Ensure metadata, rules, and references survive migration

## Test Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Step A: Deploy Registry 2.6.x + PostgreSQL                     │
│  Step B: Deploy nginx load balancer → v2                        │
│  Step C: Create test data (25 artifacts, ~75 versions)          │
│  Step D: Validate v2 registry content                           │
│  Step E: [PAUSE - Review results]                               │
│  Step F: Export data from v2                                    │
│  Step G: Deploy Registry 3.1.x + PostgreSQL                     │
│  Step H: Import data into v3                                    │
│  Step I: Switch nginx load balancer → v3                        │
│  Step J: Validate v2 API compatibility on v3                    │
│  Step K: Validate v3 API functionality                          │
│  Step L: Cleanup                                                │
└─────────────────────────────────────────────────────────────────┘
```

## TLS/HTTPS Configuration Details

### Certificate Generation
- **Self-signed certificates** created using OpenSSL
- **Formats generated**:
  - PEM format (private key + certificate)
  - PKCS12 keystore for Quarkus/Java servers
  - JKS truststore for Java clients
- **SAN entries**: localhost, scenario3-registry-v2, scenario3-registry-v3, 127.0.0.1
- **Password**: registry123 (for testing only)

### Server-Side TLS Configuration

**Apicurio Registry v2.6.x** (Quarkus-based):
```yaml
QUARKUS_HTTP_SSL_PORT: 8443
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_FILE: /certs/registry-keystore.p12
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_PASSWORD: registry123
QUARKUS_HTTP_INSECURE_REQUESTS: disabled
```

**Apicurio Registry v3.1.x** (Quarkus-based):
```yaml
QUARKUS_HTTP_SSL_PORT: 8443
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_FILE: /certs/registry-keystore.p12
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_PASSWORD: registry123
QUARKUS_HTTP_INSECURE_REQUESTS: disabled
```

**Nginx** (TLS Passthrough):
- Listens on port 8443 for HTTPS traffic
- Uses stream module for Layer 4 TCP/TLS passthrough
- Forwards encrypted traffic directly to backend without decryption
- Health check endpoint on port 8081 (HTTP)

### Client-Side TLS Configuration

**Java v2 Client** (System Properties):
```bash
-Djavax.net.ssl.trustStore=/path/to/registry-truststore.jks
-Djavax.net.ssl.trustStorePassword=registry123
```

**Java v3 Client** (RegistryClientOptions API):
```java
RegistryClientOptions.create(registryUrl)
    .trustStoreJks("certs/registry-truststore.jks", "registry123");
```

**curl Commands**:
```bash
curl -k https://localhost:8443/apis/registry/v3/system/info
```

## Components

### Infrastructure
- **apicurio-registry-v2**: Apicurio Registry 2.6.13.Final (HTTPS on port 2222)
- **postgres-v2**: PostgreSQL 14
- **apicurio-registry-v3**: Apicurio Registry 3.1.2 (HTTPS on port 3333)
- **postgres-v3**: PostgreSQL 14
- **nginx**: Nginx with TLS passthrough (HTTPS on port 8443, health on port 8081)

### Client Applications
- **artifact-creator**: Creates diverse test data using v2 client with SSL trust configuration
- **artifact-validator-v2**: Validates registry content using v2 API with system property SSL config
- **artifact-validator-v3**: Validates registry content using v3 API with RegistryClientOptions SSL config

### Test Data
- 10 Avro schemas (3-5 versions each)
- 5 Protobuf schemas (2-3 versions each)
- 5 JSON Schemas (2-3 versions each)
- 3 OpenAPI specs (2 versions each)
- 2 AsyncAPI specs (2 versions each)
- Global rules (VALIDITY, COMPATIBILITY)
- Artifact-specific rules
- Artifact references
- Metadata (labels, properties, descriptions)

## Key Learnings: v2 vs v3 SSL Configuration

### Server Configuration
Both v2 and v3 use **identical Quarkus SSL configuration**, since both are Quarkus-based applications:
- Same environment variables
- Same PKCS12 keystore format
- Same port configuration (8443)

### Client Configuration
The **client-side SSL configuration differs significantly** between v2 and v3:

| Aspect | v2 Client | v3 Client |
|--------|-----------|-----------|
| **Configuration Method** | JVM System Properties | RegistryClientOptions API |
| **Code Approach** | `System.setProperty()` | `.trustStoreJks()` method |
| **When Applied** | Before creating client | During client creation |
| **Example** | `-Djavax.net.ssl.trustStore=...` | `.trustStoreJks("path", "pass")` |

**v2 Client Example**:
```java
// Configure globally via system properties
System.setProperty("javax.net.ssl.trustStore", "certs/registry-truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword", "registry123");

// Client uses system SSL context automatically
RegistryClient client = RegistryClientFactory.create(registryUrl);
```

**v3 Client Example**:
```java
// Configure explicitly via RegistryClientOptions
RegistryClientOptions options = RegistryClientOptions.create(registryUrl)
    .trustStoreJks("certs/registry-truststore.jks", "registry123");

RegistryClient client = RegistryClientFactory.create(options);
```

### Why This Matters
When migrating from v2 to v3, you'll need to update your client applications to use the new
`RegistryClientOptions` API for SSL configuration. The v3 approach provides:
- More explicit configuration
- Better control over SSL settings per client instance
- Cleaner separation from global JVM settings
- Support for additional SSL options (trust all, custom certificates, mTLS)

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Clients                               │
│         (with JKS truststore for cert validation)           │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS (8443)
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                    Nginx (TLS Passthrough)                   │
│              Port 8443 (HTTPS) / Port 8081 (health)         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Stream Module: Forward encrypted traffic as-is      │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬─────────────────────────┬────────────────────┘
             │ HTTPS (8443)            │ HTTPS (8443)
             ↓                         ↓
┌────────────────────────┐   ┌────────────────────────┐
│  Registry v2           │   │  Registry v3           │
│  (PKCS12 keystore)     │   │  (PKCS12 keystore)     │
│  Port: 8443            │   │  Port: 8443            │
│  External: 2222        │   │  External: 3333        │
└────────────────────────┘   └────────────────────────┘
```
