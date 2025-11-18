# Migration Testing Scenario 4: PostgreSQL Migration with TLS, Auth, and Kafka Applications

## Overview

This scenario tests the migration path from Apicurio Registry 2.6.x to 3.1.x using PostgreSQL storage with
production-like configuration including TLS, OAuth2 authentication, and Kafka application integration.
Tests both REST API and Kafka SerDes migration paths.

**Complexity**: Medium-High
**Prerequisites**: Docker, Java 11+, Maven 3.8+, jq, curl, openssl, keytool

## Quick Start

Run the complete automated migration test:

```bash
# Run all migration steps automatically
./run-scenario-4.sh

# Or run individual steps manually
./scripts/step-A-deploy-kafka.sh
./scripts/step-B-deploy-keycloak.sh
./scripts/step-C-deploy-v2.sh
# ... etc
```

Clean up after testing:

```bash
./scripts/cleanup.sh
```

## Objectives

1. ✅ Validate export/import process preserves all data
2. ✅ Verify v2 API backward compatibility in 3.1.x
3. ✅ Test new v3 API functionality after migration
4. ✅ Simulate production-like traffic switching with nginx
5. ✅ Ensure metadata, rules, and references survive migration
6. ✅ Test TLS/HTTPS for Registry and Keycloak
7. ✅ Test OAuth2 authentication with Keycloak
8. ✅ Test Kafka applications with v2 SerDes before migration
9. ✅ Test Kafka applications with v2 SerDes on v3 Registry (backward compatibility)
10. ✅ Test Kafka applications with v3 SerDes on v3 Registry (native functionality)

## Test Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: INITIAL SETUP                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  Step A: Deploy Kafka cluster (KRaft mode with TLS)                     │
│  Step B: Deploy Keycloak (OAuth2 provider with TLS)                     │
│  Step C: Deploy Registry 2.6.x + PostgreSQL (with TLS/OAuth2)           │
│  Step D: Deploy nginx load balancer → v2 (HTTPS)                        │
│  Step E: Create test data via REST API (25 artifacts, ~75 versions)     │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: KAFKA TESTING BEFORE MIGRATION                                │
├─────────────────────────────────────────────────────────────────────────┤
│  Step F: Run Kafka Producer v2 (produce messages + register schema)     │
│  Step G: Run Kafka Consumer v2 (consume messages from v2 producer)      │
│  Step H: Validate v2 registry content (REST API validation)             │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: MIGRATION                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│  Step I: [PAUSE - Review pre-migration results]                         │
│  Step J: Export data from v2                                            │
│  Step K: Deploy Registry 3.1.x + PostgreSQL (with TLS/OAuth2)           │
│  Step L: Import data into v3                                            │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: KAFKA TESTING AFTER MIGRATION (V2 SERDES ON V3)              │
├─────────────────────────────────────────────────────────────────────────┤
│  Step M: Switch nginx load balancer → v3                                │
│  Step N: Run Kafka Producer v2 on v3 (test backward compatibility)      │
│  Step O: Run Kafka Consumer v2 on v3 (read v2+v3 producer messages)     │
│  Step P: Validate v2 API compatibility on v3 (REST API validation)      │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 5: NATIVE V3 TESTING                                             │
├─────────────────────────────────────────────────────────────────────────┤
│  Step Q: Validate v3 API functionality (native v3 REST API)             │
│  Step R: Run Kafka Producer v3 (produce with v3 SerDes)                 │
│  Step S: Run Kafka Consumer v3 (consume all messages with v3 SerDes)    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Components

### Infrastructure
- **kafka**: Apache Kafka 3.9.1 (KRaft mode, PLAINTEXT:9092, SSL:9094)
- **keycloak**: Keycloak (OAuth2/OIDC provider, HTTPS:9443)
- **apicurio-registry-v2**: Apicurio Registry 2.6.13.Final (HTTPS:2222)
- **postgres-v2**: PostgreSQL 14 (storage for Registry v2)
- **apicurio-registry-v3**: Apicurio Registry 3.1.2 (HTTPS:3333)
- **postgres-v3**: PostgreSQL 14 (storage for Registry v3)
- **nginx**: Nginx reverse proxy (HTTPS:8443, load balancer)

### Security Components
- **TLS Certificates**: Self-signed certificates for Registry, Keycloak, and Kafka
- **OAuth2 Provider**: Keycloak realm "registry" with client "registry-api"
- **Truststores**: Combined JKS truststore for all services

### REST Client Applications
- **artifact-creator**: Creates diverse test data using v2 client
- **artifact-validator-v2**: Validates registry content using v2 API
- **artifact-validator-v3**: Validates registry content using v3 API

### Kafka Client Applications
- **kafka-producer-v2**: Produces Avro messages using Registry v2 SerDes
- **kafka-consumer-v2**: Consumes Avro messages using Registry v2 SerDes
- **kafka-producer-v3**: Produces Avro messages using Registry v3 SerDes
- **kafka-consumer-v3**: Consumes Avro messages using Registry v3 SerDes

All Kafka applications support:
- TLS/HTTPS for Registry connections
- OAuth2 authentication with Keycloak
- Auto-registration of Avro schemas
- Environment-based configuration

### Test Data

#### REST API Data (via artifact-creator)
- 10 Avro schemas (3-5 versions each)
- 5 Protobuf schemas (2-3 versions each)
- 5 JSON Schemas (2-3 versions each)
- 3 OpenAPI specs (2 versions each)
- 2 AsyncAPI specs (2 versions each)
- Global rules (VALIDITY, COMPATIBILITY)
- Artifact-specific rules
- Artifact references
- Metadata (labels, properties, descriptions)

#### Kafka Application Data
- Avro schema for `GreetingMessage` (auto-registered by Kafka producers)
- Kafka topic: `avro-messages` (3 partitions, replication factor 1)
- Messages from v2 producer (before migration)
- Messages from v2 producer on v3 registry (after migration)
- Messages from v3 producer (native v3)
