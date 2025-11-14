# Scenario 2 Implementation Plan
## Kafka Storage Migration Testing

## Overview

This plan outlines the implementation of Scenario 2, which tests migration from Apicurio Registry 2.6.13 to 3.1.2 using **Kafka for storage** and includes testing of **Kafka SerDes** (Serializers/Deserializers) for backward compatibility.

**Key Differences from Scenario 1:**
- Uses Kafka (KafkaSQL) storage instead of PostgreSQL
- Includes Kafka producer/consumer applications
- Tests Apicurio Registry SerDes v2 and v3
- Validates backward compatibility of v2 SerDes after registry upgrade
- Demonstrates SerDes upgrade path (v2 → v3)

## CRITICAL CONSTRAINT ⚠️

**Apicurio Registry v3 CANNOT read v2's KafkaSQL journal topic.**

**Migration Strategy** (identical to PostgreSQL scenario):
1. v2 and v3 must use **separate Kafka topics**
   - v2: `kafkasql-journal-v2`
   - v3: `kafkasql-journal-v3`
2. Export data from v2 as **ZIP file**
3. Import ZIP into v3
4. Switch traffic from v2 → v3

The storage backend (Kafka vs PostgreSQL) does **not** change the migration methodology.

---

## Phase 1: Infrastructure Setup

### 1.1 Kafka Cluster Deployment

**File**: `docker-compose-kafka.yml`

**Tasks**:
- [ ] Deploy Kafka 3.9.1 (single broker for simplicity)
- [ ] Deploy Zookeeper (if using older Kafka) or use KRaft mode
- [ ] Configure Kafka to be accessible on `localhost:9092`
- [ ] Create health check for Kafka broker
- [ ] Create script to wait for Kafka readiness

**Configuration Notes**:
- Use KRaft mode (no Zookeeper) for Kafka 3.9.1
- Expose broker on `localhost:9092`
- Configure auto topic creation: `KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'`
- Set retention policy for registry storage topics

**Topics Created**:
- `kafkasql-journal-v2` - Apicurio Registry v2 storage (auto-created by v2 registry)
- `kafkasql-journal-v3` - Apicurio Registry v3 storage (auto-created by v3 registry)
- `avro-messages` - Application topic for producer/consumer

### 1.2 Apicurio Registry v2 with KafkaSQL

**File**: `docker-compose-v2-kafka.yml`

**Tasks**:
- [ ] Deploy Apicurio Registry 2.6.13.Final
- [ ] Configure KafkaSQL storage mode
- [ ] Point to Kafka broker at `kafka:9092` (internal) / `localhost:9092` (external)
- [ ] Expose registry on port `2222`
- [ ] Configure health checks
- [ ] Wait for registry readiness

**Configuration Example**:
```yaml
environment:
  REGISTRY_KAFKASQL_BOOTSTRAP_SERVERS: kafka:9092
  REGISTRY_KAFKASQL_TOPIC: kafkasql-journal-v2
  # Optional: specify consumer group
  REGISTRY_KAFKASQL_CONSUMER_GROUP_ID: registry-v2-consumer
```

**IMPORTANT**: Use v2-specific topic name (`kafkasql-journal-v2`) to avoid conflicts with v3

**Reference**:
- Check v2 docs for KafkaSQL configuration
- Example configs in: `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6/distro/docker-compose`

### 1.3 Apicurio Registry v3 with KafkaSQL

**File**: `docker-compose-v3-kafka.yml`

**Tasks**:
- [ ] Deploy Apicurio Registry 3.1.2
- [ ] Configure KafkaSQL storage mode
- [ ] Point to same Kafka broker
- [ ] Expose registry on port `3333`
- [ ] Configure health checks

**Configuration Example**:
```yaml
environment:
  APICURIO_STORAGE_KIND: kafkasql
  APICURIO_KAFKASQL_BOOTSTRAP_SERVERS: kafka:9092
  APICURIO_KAFKASQL_TOPIC: kafkasql-journal-v3
```

**Important Notes**:
- v3 uses **different environment variable names** than v2
- v3 prefix: `APICURIO_` instead of `REGISTRY_`
- Storage kind: `APICURIO_STORAGE_KIND: kafkasql`
- **CRITICAL**: v3 **CANNOT** read v2's journal - must use separate topic (`kafkasql-journal-v3`)
- Migration requires export from v2 → import to v3 (same as PostgreSQL scenario)

**Reference**:
- Check v3 docs for KafkaSQL configuration
- Example configs in: `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-3.1/distro/docker-compose`

### 1.4 Nginx Load Balancer

**File**: `docker-compose-nginx.yml` (reuse from Scenario 1)

**Tasks**:
- [ ] Copy nginx setup from Scenario 1
- [ ] Ensure registry-v2.conf points to `scenario2-registry-v2:8080`
- [ ] Ensure registry-v3.conf points to `scenario2-registry-v3:8080`
- [ ] Initially mount registry-v2.conf

---

## Phase 2: Kafka Applications (v2 SerDes)

### 2.1 Producer Application (v2)

**Directory**: `clients/kafka-producer-v2/`

**Tasks**:
- [ ] Create Maven project
- [ ] Add dependency: `apicurio-registry-serdes-avro-serde:2.6.13.Final`
- [ ] Add dependency: `kafka-clients`
- [ ] Create Avro schema (GreetingMessage.avsc)
- [ ] Create producer application
- [ ] Configure producer with Apicurio Registry v2 SerDe
- [ ] Produce 10 messages with schema auto-registration
- [ ] Build JAR with dependencies

**Key Configuration Properties**:
```java
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroKafkaSerializer.class);

// Apicurio Registry v2 configuration
props.put(SerdeConfig.REGISTRY_URL, "http://localhost:8080/apis/registry/v2");
props.put(SerdeConfig.AUTO_REGISTER_ARTIFACT, "true");
props.put(AvroPataConfig.AVRO_DATUM_PROVIDER, ReflectAvroDatumProvider.class.getName());
```

**Schema Example** (`GreetingMessage.avsc`):
```json
{
  "type": "record",
  "name": "GreetingMessage",
  "namespace": "io.apicurio.testing.kafka",
  "fields": [
    {"name": "message", "type": "string"},
    {"name": "timestamp", "type": "long"}
  ]
}
```

**Reference**:
- `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6/examples/avro-bean`

### 2.2 Consumer Application (v2)

**Directory**: `clients/kafka-consumer-v2/`

**Tasks**:
- [ ] Create Maven project
- [ ] Add same dependencies as producer-v2
- [ ] Create consumer application
- [ ] Configure consumer with Apicurio Registry v2 SerDe
- [ ] Consume and validate messages
- [ ] Print message count and contents

**Key Configuration Properties**:
```java
props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.put(ConsumerConfig.GROUP_ID_CONFIG, "test-consumer-v2");
props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, AvroKafkaDeserializer.class);

// Apicurio Registry v2 configuration
props.put(SerdeConfig.REGISTRY_URL, "http://localhost:8080/apis/registry/v2");
props.put(AvroPataConfig.AVRO_DATUM_PROVIDER, ReflectAvroDatumProvider.class.getName());
```

---

## Phase 3: Kafka Applications (v3 SerDes)

### 3.1 Producer Application (v3)

**Directory**: `clients/kafka-producer-v3/`

**Tasks**:
- [ ] Create Maven project
- [ ] Add dependency: `apicurio-registry-avro-serde-kafka:3.1.2`
- [ ] Add dependency: `kafka-clients`
- [ ] Reuse same Avro schema
- [ ] Create producer application
- [ ] Configure producer with Apicurio Registry v3 SerDe
- [ ] Produce 10 messages
- [ ] Build JAR with dependencies

**Key Configuration Properties** (v3 differences):
```java
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroKafkaSerializer.class);

// Apicurio Registry v3 configuration - NOTE DIFFERENT PROPERTY NAMES
props.put("apicurio.registry.url", "http://localhost:8080/apis/registry/v3");
props.put("apicurio.registry.auto-register", "true");
props.put("apicurio.registry.avro.datum.provider",
    "io.apicurio.registry.serde.avro.ReflectAvroDatumProvider");
```

**Important**: v3 SerDe uses different property names!
- v2: `apicurio.registry.url` (under SerdeConfig)
- v3: `apicurio.registry.url` (direct property)
- v2: `apicurio.registry.auto-register`
- v3: `apicurio.registry.auto-register`

**Reference**:
- `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-3.1/examples/avro-bean`

### 3.2 Consumer Application (v3)

**Directory**: `clients/kafka-consumer-v3/`

**Tasks**:
- [ ] Create Maven project
- [ ] Add same dependencies as producer-v3
- [ ] Create consumer application
- [ ] Configure consumer with Apicurio Registry v3 SerDe
- [ ] Consume messages from BOTH v2 and v3 producers
- [ ] Validate schema compatibility

**Key Test**: v3 consumer should be able to read messages produced by v2 producer (backward compatibility)

---

## Phase 4: Migration Scripts

### 4.1 Step A: Deploy Kafka Cluster

**File**: `scripts/step-A-deploy-kafka.sh`

**Tasks**:
- [ ] Start Kafka using docker-compose-kafka.yml
- [ ] Wait for Kafka broker to be ready
- [ ] List available brokers
- [ ] Create application topic `avro-messages`
- [ ] Verify topic creation

### 4.2 Step B: Deploy Registry v2 with KafkaSQL

**File**: `scripts/step-B-deploy-v2-kafka.sh`

**Tasks**:
- [ ] Start Registry v2 using docker-compose-v2-kafka.yml
- [ ] Wait for registry health check
- [ ] Verify KafkaSQL topic created (`kafkasql-journal`)
- [ ] Check registry system info
- [ ] Verify Kafka consumer group created

### 4.3 Step C: Deploy Nginx

**File**: `scripts/step-C-deploy-nginx.sh`

**Tasks**:
- [ ] Start nginx with registry-v2.conf
- [ ] Verify nginx routing to v2
- [ ] Test registry access through nginx

### 4.4 Step D: Run v2 Producer

**File**: `scripts/step-D-run-producer-v2.sh`

**Tasks**:
- [ ] Build kafka-producer-v2 if needed
- [ ] Run producer to send 10 messages
- [ ] Verify schema auto-registered in registry
- [ ] Verify messages in Kafka topic
- [ ] Save message count/offsets

### 4.5 Step E: Run v2 Consumer

**File**: `scripts/step-E-run-consumer-v2.sh`

**Tasks**:
- [ ] Build kafka-consumer-v2 if needed
- [ ] Run consumer to read messages
- [ ] Verify all 10 messages consumed
- [ ] Validate message contents
- [ ] Save consumption report

### 4.6 Step F: Pause/Review

**File**: `scripts/step-F-prepare-migration.sh`

**Tasks**:
- [ ] Display current state summary
- [ ] Show Kafka topics and offsets
- [ ] Show registered schemas
- [ ] Countdown 10 seconds

### 4.7 Step G: Export v2 Data

**File**: `scripts/step-G-export-v2-data.sh`

**Tasks**:
- [ ] Export registry data from v2
- [ ] Save to `data/registry-v2-export.zip`
- [ ] Validate ZIP contents

### 4.8 Step H: Deploy Registry v3

**File**: `scripts/step-H-deploy-v3-kafka.sh`

**Tasks**:
- [ ] Start Registry v3 using docker-compose-v3-kafka.yml
- [ ] Wait for registry health check
- [ ] Verify v3 using **SEPARATE** KafkaSQL topic (`kafkasql-journal-v3`)
- [ ] Check system info

**CRITICAL**: v3 **CANNOT** read v2's KafkaSQL journal. Must use separate topic!

### 4.9 Step I: Import v3 Data

**File**: `scripts/step-I-import-v3-data.sh`

**Tasks**:
- [ ] Import data into v3 registry
- [ ] Verify artifact count
- [ ] Check schema is available

### 4.10 Step J: Switch Nginx to v3

**File**: `scripts/step-J-switch-nginx-to-v3.sh`

**Tasks**:
- [ ] Update nginx to use registry-v3.conf
- [ ] Restart nginx
- [ ] Verify routing to v3

### 4.11 Step K: Run v2 Producer (Against v3)

**File**: `scripts/step-K-run-producer-v2-on-v3.sh`

**Tasks**:
- [ ] Run kafka-producer-v2 (unchanged)
- [ ] Producer should work with v3 registry (backward compat)
- [ ] Produce 10 more messages
- [ ] Verify schema lookup works
- [ ] Save results

**Expected**: v2 SerDes should work with v3 registry

### 4.12 Step L: Run v2 Consumer (Against v3)

**File**: `scripts/step-L-run-consumer-v2-on-v3.sh`

**Tasks**:
- [ ] Run kafka-consumer-v2 (unchanged)
- [ ] Consumer should work with v3 registry
- [ ] Consume all 20 messages (10 from step D + 10 from step K)
- [ ] Verify all consumed correctly

**Expected**: v2 SerDes should work with v3 registry

### 4.13 Step M: Run v3 Producer

**File**: `scripts/step-M-run-producer-v3.sh`

**Tasks**:
- [ ] Run kafka-producer-v3
- [ ] Produce 10 messages using v3 SerDes
- [ ] Verify schema registration with v3 API
- [ ] Save results

### 4.14 Step N: Run v3 Consumer

**File**: `scripts/step-N-run-consumer-v3.sh`

**Tasks**:
- [ ] Run kafka-consumer-v3
- [ ] Consume ALL messages:
  - 10 from v2 producer (step D)
  - 10 from v2 producer on v3 registry (step K)
  - 10 from v3 producer (step M)
- [ ] Total: 30 messages
- [ ] Verify v3 consumer can read v2-produced messages

**Expected**: v3 consumer should handle all messages regardless of which producer created them

---

## Phase 5: Build and Automation

### 5.1 Build Script

**File**: `scripts/build-clients.sh`

**Tasks**:
- [ ] Build kafka-producer-v2
- [ ] Build kafka-consumer-v2
- [ ] Build kafka-producer-v3
- [ ] Build kafka-consumer-v3
- [ ] Verify all JARs created

### 5.2 Master Automation Script

**File**: `run-all-steps.sh`

**Tasks**:
- [ ] Run steps A through N automatically
- [ ] Track timing for each step
- [ ] Collect all logs
- [ ] Generate summary report

### 5.3 Cleanup Script

**File**: `cleanup.sh`

**Tasks**:
- [ ] Stop all containers (Kafka, Registry v2, Registry v3, nginx)
- [ ] Optionally remove volumes
- [ ] Optionally remove logs/data

---

## Phase 6: Validation and Testing

### 6.1 Validation Criteria

**Pre-Migration (Steps D-E)**:
- ✅ 10 messages produced successfully
- ✅ 10 messages consumed successfully
- ✅ Schema auto-registered in v2 registry
- ✅ Messages readable with v2 SerDes

**Post-Migration (Steps K-L)**:
- ✅ v2 producer works with v3 registry (backward compatibility)
- ✅ v2 consumer works with v3 registry (backward compatibility)
- ✅ 20 total messages (10 pre + 10 post migration)
- ✅ All messages consumed successfully

**v3 SerDes Testing (Steps M-N)**:
- ✅ v3 producer works with v3 registry
- ✅ v3 consumer works with v3 registry
- ✅ v3 consumer can read v2-produced messages
- ✅ 30 total messages consumed

### 6.2 Success Metrics

- [ ] All Kafka applications run without errors
- [ ] v2 SerDes work before and after registry upgrade
- [ ] v3 SerDes work correctly
- [ ] Schema compatibility maintained throughout
- [ ] No message loss during migration
- [ ] No consumer lag issues

---

## Implementation Notes

### Key Differences: v2 vs v3 Registry Configuration

**v2 (KafkaSQL)**:
```yaml
REGISTRY_KAFKASQL_BOOTSTRAP_SERVERS: kafka:9092
REGISTRY_KAFKASQL_TOPIC: kafkasql-journal
```

**v3 (KafkaSQL)**:
```yaml
APICURIO_STORAGE_KIND: kafkasql
APICURIO_KAFKASQL_BOOTSTRAP_SERVERS: kafka:9092
APICURIO_KAFKASQL_TOPIC: kafkasql-journal
```

### Key Differences: v2 vs v3 SerDes

**v2 SerDes**:
- Artifact: `apicurio-registry-serdes-avro-serde`
- Config prefix: `apicurio.registry.*` (via SerdeConfig constants)
- Serializer: `io.apicurio.registry.serde.avro.AvroKafkaSerializer`

**v3 SerDes**:
- Artifact: `apicurio-registry-avro-serde-kafka`
- Config prefix: `apicurio.registry.*`
- Serializer: `io.apicurio.registry.serde.avro.AvroKafkaSerializer` (same package?)

**Check**: Verify if v3 serializer class names changed or just the artifact ID

### Separate Kafka Topics for v2 and v3

**CRITICAL CONSTRAINT**: v3 **CANNOT** read v2's KafkaSQL journal topic.

**Migration Strategy** (same as Scenario 1):
1. v2 uses topic: `kafkasql-journal-v2`
2. v3 uses topic: `kafkasql-journal-v3`
3. Export data from v2 as ZIP file
4. Import ZIP into v3
5. Switch nginx routing from v2 to v3

This is identical to the PostgreSQL migration approach - the storage backend (Kafka vs PostgreSQL) doesn't change the migration methodology.

---

## Timeline Estimate

- **Phase 1**: 2-3 days (Infrastructure setup)
- **Phase 2**: 2 days (v2 Kafka apps)
- **Phase 3**: 2 days (v3 Kafka apps)
- **Phase 4**: 3-4 days (Migration scripts)
- **Phase 5**: 1 day (Build automation)
- **Phase 6**: 1-2 days (Testing and validation)

**Total**: 11-14 days

---

## Dependencies

### Reference Files to Review
- [ ] `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6/examples/avro-bean/`
- [ ] `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-3.1/examples/avro-bean/`
- [ ] v2 KafkaSQL docker-compose examples
- [ ] v3 KafkaSQL docker-compose examples
- [ ] v2 SerDes documentation
- [ ] v3 SerDes documentation

### External Dependencies
- Kafka 3.9.1 Docker image
- Apicurio Registry 2.6.13.Final
- Apicurio Registry 3.1.2
- Maven 3.8+
- Java 11+

---

## Risk Mitigation

### Potential Issues

1. **Kafka Startup Time**: Kafka can be slow to start
   - Mitigation: Implement robust wait-for-ready checks

2. **Topic Auto-Creation**: May not work as expected
   - Mitigation: Explicitly create topics in scripts

3. **SerDes Configuration Changes**: v2 vs v3 differences
   - Mitigation: Carefully review documentation and examples

4. **Schema Registry Topic Sharing**: v2 and v3 reading same topic
   - Mitigation: Test thoroughly; have rollback plan

5. **Consumer Group Management**: Conflicts between v2 and v3
   - Mitigation: Use different consumer group IDs

---

## Open Questions

1. ✅ **RESOLVED: Can v3 registry read v2's kafkasql-journal topic?**
   - **Answer**: NO - v3 cannot read v2's journal
   - **Solution**: Use separate topics + export/import (same as PostgreSQL scenario)

2. **Do v2 SerDes work with v3 registry's v2 API endpoint?**
   - Should work due to backward compatibility
   - Need to test (critical test case for Step K/L)

3. **What are the exact v3 SerDes property names?**
   - Review v3 documentation
   - Check v3 example code

4. **Can v3 consumer read messages produced by v2 producer?**
   - Should work if schema is compatible
   - Critical test case for Step N

---

## Next Steps

Once approved, start with:
1. Phase 1.1: Deploy Kafka cluster
2. Phase 1.2: Deploy Registry v2 with KafkaSQL
3. Phase 2.1: Create simple producer-v2
4. Test end-to-end before continuing
