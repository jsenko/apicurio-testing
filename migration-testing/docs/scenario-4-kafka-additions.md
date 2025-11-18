# Scenario-4 Kafka Application Support - Implementation Summary

## Overview

Added Kafka Application (client) support to scenario-4 for testing Apicurio Registry with Kafka producers and consumers during migration from v2.6.x to v3.1.x. The implementation includes TLS and OAuth2 authentication support.

## Components Added

### 1. Infrastructure

#### Kafka Deployment
- **File**: `docker-compose-kafka.yml`
- **Features**:
  - Apache Kafka 3.9.1 with KRaft mode (no Zookeeper)
  - TLS/SSL support on port 9094
  - PLAINTEXT listener on port 9092
  - Configured with Kafka keystores and truststores
  - Network: `scenario4-kafka-network`

#### Certificate Generation
- **Modified**: `scripts/generate-certs.sh`
- **Additions**:
  - Kafka certificate generation (kafka-key.pem, kafka-cert.pem)
  - Kafka JKS keystore (kafka.keystore.jks)
  - Kafka JKS truststore (kafka.truststore.jks)
  - Combined client truststore (includes Registry, Keycloak, and Kafka certificates)

### 2. Client Applications

#### Kafka Producer v2
- **Location**: `clients/kafka-producer-v2/`
- **Features**:
  - Uses Apicurio Registry v2.6.13.Final SerDes
  - Supports TLS for Registry connections (HTTPS)
  - OAuth2 authentication with Keycloak
  - Auto-registers Avro schemas
  - Environment variable configuration

#### Kafka Consumer v2
- **Location**: `clients/kafka-consumer-v2/`
- **Features**:
  - Uses Apicurio Registry v2.6.13.Final SerDes
  - Supports TLS for Registry connections (HTTPS)
  - OAuth2 authentication with Keycloak
  - Reads Avro messages

#### Kafka Producer v3
- **Location**: `clients/kafka-producer-v3/`
- **Features**:
  - Uses Apicurio Registry 3.1.2 SerDes
  - Supports TLS for Registry connections (HTTPS)
  - OAuth2 authentication with Keycloak
  - Auto-registers Avro schemas
  - Environment variable configuration

#### Kafka Consumer v3
- **Location**: `clients/kafka-consumer-v3/`
- **Features**:
  - Uses Apicurio Registry 3.1.2 SerDes
  - Supports TLS for Registry connections (HTTPS)
  - OAuth2 authentication with Keycloak
  - Reads Avro messages from both v2 and v3 producers

### 3. Deployment and Execution Scripts

#### Kafka Deployment Script
- **File**: `scripts/step-M-deploy-kafka.sh`
- **Purpose**: Deploy Kafka cluster with TLS support
- **Actions**:
  1. Verifies and generates certificates if needed
  2. Copies Kafka keystores to secrets directory
  3. Starts Kafka using docker-compose
  4. Creates 'avro-messages' topic (3 partitions)
  5. Verifies deployment

#### Kafka Producer v2 Script
- **File**: `scripts/step-N-run-producer-v2.sh`
- **Purpose**: Run Kafka producer using v2 SerDes against Registry v2
- **Configuration**:
  - Kafka: localhost:9092 (PLAINTEXT)
  - Registry: https://localhost:2222/apis/registry/v2 (TLS)
  - OAuth2: Keycloak at https://localhost:9443
  - Topic: avro-messages
  - Messages: 10 (configurable)

#### Remaining Scripts to Create
- **`scripts/step-O-run-consumer-v2.sh`**: Run Kafka consumer v2
- **`scripts/step-P-run-producer-v3.sh`**: Run Kafka producer v3 (after migration)
- **`scripts/step-Q-run-consumer-v3.sh`**: Run Kafka consumer v3 (can read from both producers)

### 4. Cleanup Script Updates
- **Modified**: `scripts/cleanup.sh`
- **Additions**:
  - Collects Kafka container logs
  - Stops Kafka docker-compose services
  - Removes scenario4-kafka-network

## Configuration Details

### TLS/SSL Configuration
- **Registry**: HTTPS on ports 2222 (v2) and 3333 (v3)
- **Keycloak**: HTTPS on port 9443
- **Kafka**: SSL listener on port 9094 (PLAINTEXT on 9092)
- **Truststore**: `certs/client-truststore.jks` (password: registry123)

### OAuth2 Authentication
- **Token Endpoint**: `https://localhost:9443/realms/registry/protocol/openid-connect/token`
- **Client ID**: `registry-api`
- **Client Secret**: `**********` (from keycloak/realm.json)

### Environment Variables for Kafka Clients
```bash
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
REGISTRY_URL=https://localhost:2222/apis/registry/v2  # or v3
TOPIC_NAME=avro-messages
MESSAGE_COUNT=10
OAUTH_CLIENT_ID=registry-api
OAUTH_CLIENT_SECRET=**********
OAUTH_TOKEN_URL=https://localhost:9443/realms/registry/protocol/openid-connect/token
TRUSTSTORE_PATH=/path/to/certs/client-truststore.jks
TRUSTSTORE_PASSWORD=registry123
```

## Integration with Existing Migration Flow

### Current Flow (Steps A-L)
A. Deploy Keycloak
B. Deploy Registry 2.6.x + PostgreSQL
C. Deploy nginx load balancer → v2
D. Create test data
E. Validate v2 registry content
F. [PAUSE - Review results]
G. Export data from v2
H. Deploy Registry 3.1.x + PostgreSQL
I. Import data into v3
J. Switch nginx load balancer → v3
K. Validate v2 API compatibility on v3
L. Validate v3 API functionality

### Proposed Flow with Kafka (Steps M-Q)
M. Deploy Kafka cluster
N. Run Kafka producer v2 (auto-register schema in Registry v2)
O. Run Kafka consumer v2 (verify can read messages)
... (continue with existing steps E-J) ...
P. Run Kafka producer v3 (test with Registry v3)
Q. Run Kafka consumer v3 (read from both v2 and v3 producers)

## What Still Needs to Be Done

### 1. Create Remaining Scripts
- [ ] `scripts/step-O-run-consumer-v2.sh` - Consumer for v2
- [ ] `scripts/step-P-run-producer-v3.sh` - Producer for v3 (post-migration)
- [ ] `scripts/step-Q-run-consumer-v3.sh` - Consumer for v3 (reads all messages)
- [ ] `scripts/build-clients.sh` - Update to build Kafka clients (if not already included)

### 2. Update Main Scenario Script
- [ ] Update `run-scenario-4.sh` to include Kafka deployment and execution steps
- [ ] Add Kafka steps at appropriate points in migration flow

### 3. Update Documentation
- [ ] Update `README.md` to document:
  - Kafka cluster deployment
  - Kafka client applications
  - Updated test flow with Kafka steps
  - New dependencies and prerequisites
  - OAuth2 and TLS configuration for Kafka clients

### 4. Testing
- [ ] Test Kafka deployment (step-M)
- [ ] Test producer v2 (step-N) against Registry v2
- [ ] Test consumer v2 (step-O)
- [ ] Test full migration flow with Kafka
- [ ] Test producer v3 (step-P) against Registry v3
- [ ] Test consumer v3 (step-Q) reading from both producers
- [ ] Verify schema registration and retrieval with TLS/Auth
- [ ] Test cleanup script

## Notes

1. **Kafka Persistence**: Apicurio Registry continues to use PostgreSQL for persistence. Kafka is only used for application message topics (avro-messages).

2. **Network Isolation**: Kafka runs on its own network (scenario4-kafka-network) but clients connect via localhost.

3. **TLS Configuration**: Kafka supports both PLAINTEXT (9092) and SSL (9094) listeners. Currently, clients use PLAINTEXT for Kafka and HTTPS for Registry/Keycloak.

4. **OAuth2 Tokens**: Clients automatically obtain OAuth2 tokens from Keycloak when OAUTH_* environment variables are set.

5. **Build Process**: Kafka clients need to be built with Maven before running. This should be included in the build-clients.sh script.

## File Manifest

### Created Files
- `docker-compose-kafka.yml` - Kafka deployment configuration
- `scripts/step-M-deploy-kafka.sh` - Kafka deployment script (executable)
- `scripts/step-N-run-producer-v2.sh` - Producer v2 execution script (executable)
- `clients/kafka-producer-v2/` - Copied and modified from scenario-2
- `clients/kafka-consumer-v2/` - Copied and modified from scenario-2
- `clients/kafka-producer-v3/` - Copied and modified from scenario-2
- `clients/kafka-consumer-v3/` - Copied and modified from scenario-2

### Modified Files
- `scripts/generate-certs.sh` - Added Kafka certificate generation
- `scripts/cleanup.sh` - Added Kafka cleanup steps
- `certs/README.md` - Updated to document Kafka certificates (auto-generated)
- All 4 Kafka client `*App.java` files - Added TLS and OAuth2 support

### Files to Create
- `scripts/step-O-run-consumer-v2.sh`
- `scripts/step-P-run-producer-v3.sh`
- `scripts/step-Q-run-consumer-v3.sh`

### Files to Modify
- `run-scenario-4.sh` - Add Kafka steps
- `README.md` - Document Kafka additions
- `scripts/build-clients.sh` - Include Kafka clients (if needed)
