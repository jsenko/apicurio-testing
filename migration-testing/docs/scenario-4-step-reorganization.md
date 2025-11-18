# Scenario-4 Step Reorganization Summary

## New Step Order

The migration test flow now includes Kafka application testing at strategic points:

### Phase 1: Initial Setup
- **Step A**: Deploy Kafka Cluster (NEW - moved from step-M)
- **Step B**: Deploy Keycloak (was step-A)
- **Step C**: Deploy Registry v2 (was step-B)
- **Step D**: Deploy nginx (was step-C)
- **Step E**: Create test data (was step-D)

### Phase 2: Kafka Testing Before Migration
- **Step F**: Run Kafka Producer v2 (NEW)
  - Produces messages to Kafka
  - Auto-registers schema in Registry v2
  - Tests with TLS and OAuth2

- **Step G**: Run Kafka Consumer v2 (NEW)
  - Consumes messages from Kafka
  - Deserializes using schema from Registry v2
  - Tests with TLS and OAuth2

- **Step H**: Validate pre-migration (was step-E)

### Phase 3: Migration
- **Step I**: Prepare migration (was step-F)
- **Step J**: Export v2 data (was step-G)
- **Step K**: Deploy Registry v3 (was step-H)
- **Step L**: Import v3 data (was step-I)

### Phase 4: Kafka Testing After Migration (v2 SerDes on v3 Registry)
- **Step M**: Run Kafka Producer v2 on Registry v3 (NEW)
  - Tests v2 SerDes backward compatibility
  - Produces messages using v2 client against v3 registry
  - Verifies auto-registration works

- **Step N**: Run Kafka Consumer v2 on Registry v3 (NEW)
  - Tests v2 SerDes backward compatibility
  - Consumes messages using v2 client against v3 registry
  - Can read messages from both v2 and v3 producers

- **Step O**: Switch nginx to v3 (was step-J)
- **Step P**: Validate post-migration (was step-K)

### Phase 5: Native v3 Testing
- **Step Q**: Validate v3 native (was step-L)

- **Step R**: Run Kafka Producer v3 (NEW)
  - Produces messages using v3 SerDes
  - Tests native v3 functionality
  - Auto-registers schema in Registry v3

- **Step S**: Run Kafka Consumer v3 (NEW)
  - Consumes messages using v3 SerDes
  - Can read messages from all producers (v2 and v3)
  - Tests complete forward compatibility

## Kafka Integration Points

### Before Migration (Steps F-G)
- Purpose: Establish baseline Kafka application behavior with Registry v2
- Verifies: Schema registration, serialization, deserialization with v2

### After Migration (Steps M-N)
- Purpose: Test backward compatibility of v2 SerDes with Registry v3
- Verifies: v2 applications continue to work with v3 registry

### After v3 Validation (Steps R-S)
- Purpose: Test native v3 SerDes functionality
- Verifies: v3 applications work correctly, can read v2 and v3 messages

## Configuration Summary

All Kafka client scripts use:
- **Kafka**: localhost:9092 (PLAINTEXT)
- **Registry v2**: https://localhost:2222/apis/registry/v2 (TLS)
- **Registry v3**: https://localhost:3333/apis/registry/v2 (TLS - v2 API for compatibility)
- **Keycloak**: https://localhost:9443 (TLS, OAuth2)
- **Truststore**: certs/client-truststore.jks (password: registry123)
- **OAuth Client**: registry-api / **********

## Files Modified/Created

### Modified
1. `scripts/build-clients.sh` - Added Kafka client builds (4 new clients)
2. `scripts/cleanup.sh` - Added Kafka and Keycloak cleanup
3. `scripts/generate-certs.sh` - Added Kafka certificate generation

### Renamed
- step-A → step-B (deploy-keycloak)
- step-B → step-C (deploy-v2)
- step-C → step-D (deploy-nginx)
- step-D → step-E (create-data)
- step-E → step-H (validate-pre-migration)
- step-F → step-I (prepare-migration)
- step-G → step-J (export-v2-data)
- step-H → step-K (deploy-v3)
- step-I → step-L (import-v3-data)
- step-J → step-O (switch-nginx-to-v3)
- step-K → step-P (validate-post-migration)
- step-L → step-Q (validate-v3-native)
- step-M → step-A (deploy-kafka)

### Created
- `step-A-deploy-kafka.sh` (was step-M)
- `step-F-run-producer-v2.sh`
- `step-G-run-consumer-v2.sh`
- `step-M-run-producer-v2-on-v3.sh`
- `step-N-run-consumer-v2-on-v3.sh`
- `step-R-run-producer-v3.sh`
- `step-S-run-consumer-v3.sh`

## Testing Flow Rationale

The step organization follows this testing strategy:

1. **Deploy Infrastructure First** (A-B)
   - Kafka must be available before Registry (for application topic)
   - Keycloak must be available for Registry authentication

2. **Deploy Registry v2** (C-D)
   - Registry with nginx proxy

3. **Create Baseline Data** (E-G)
   - Create artifacts via REST API
   - Test Kafka applications with v2
   - Validates initial state

4. **Migrate** (H-L)
   - Standard migration process
   - Export from v2, deploy v3, import to v3

5. **Test Backward Compatibility** (M-N)
   - v2 Kafka apps against v3 registry
   - Critical for zero-downtime migration

6. **Switch Traffic** (O-P)
   - Point nginx to v3
   - Validate via REST API

7. **Test Native v3** (Q-S)
   - Validate v3 features
   - Test v3 Kafka applications
   - Verify complete compatibility

This ensures comprehensive testing of both REST API and Kafka application migration paths.
