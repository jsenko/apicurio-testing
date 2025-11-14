# Migration Testing Scenario 1: Basic PostgreSQL Migration

## Overview

This scenario tests the migration path from Apicurio Registry 2.6.x to 3.1.x using Kafka for storage
with simulated production traffic switching via nginx load balancer.  The production traffic comes 
from Kafka applications that are producing and consuming messages.

**Status**: TBD
**Complexity**: Medium
**Prerequisites**: Docker, Java 11+, Maven 3.8+, jq, curl

## Objectives

1. Validate export/import process preserves all data
2. Verify v2 Serializers/Deserializers work after server is upgraded to v3
3. Test upgrade of Serializers/Deserializers to v3
4. Show differences between v2 and v3 apicurio-registry configurations when using Kafka for storage

## Test Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Step A: Deploy Kafka cluster                                   │
│  Step B: Deploy Registry 2.6.13.Final + KafkaSQL storage        │
│  Step C: Deploy nginx load balancer → v2                        │
│  Step D: Run Kafka producer application                         │
│  Step E: Run Kafka consumer application                         │
│  Step F: [PAUSE - Review results]                               │
│  Step G: Export data from v2                                    │
│  Step H: Deploy Registry 3.1.2 + KafkaSQL storage               │
│  Step I: Import data into v3                                    │
│  Step J: Switch nginx load balancer → v3                        │
│  Step K: Run v2 Kafka producer application                      │
│  Step L: Run v2 Kafka consumer application                      │
│  Step M: Upgrade Kafka producer application to v3 and run       │
│  Step N: Upgrade Kafka consumer application to v3 and run       │
│  Step O: Cleanup                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Infrastructure
- **apicurio-registry-v2**: Apicurio Registry 2.6.13.Final
- **Apache Kafka**: Apache Kafka 3.9.1
- **apicurio-registry-v3**: Apicurio Registry 3.1.0
- **nginx**: Nginx reverse proxy (load balancer)

Note: we will use the same Kafka cluster for both the Apicurio Registry storage topic(s) 
and ALSO the topics needed for our producer/consumer applications.

### Client Applications
- **producer-v2**: A simple Kafka application that uses the Apicurio Registry v2 Avro serializer when producing messages
- **consumer-v2**: A simple Kafka application that uses the Apicurio Registry v2 Avro deserializer to consume messages produced by "producer-v2"
- **producer-v3**: A simple Kafka application that uses the Apicurio Registry v3 Avro serializer when producing messages
- **consumer-v3**: A simple Kafka application that uses the Apicurio Registry v3 Avro deserializer to consume messages produced by "producer-v2" and "producer-v3"

## References
- Example of an Apicurio Registry v2 Kafka application (implements both a producer and consumer): /home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6/examples/avro-bean
- Example of an Apicurio Registry v3 Kafka application (implements both a producer and consumer): /home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-3.1/examples/avro-bean
- Documentation on configuring Kafka Applications when using Apicurio Registry v2 SerDe: /home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6/docs/modules/ROOT/partials/getting-started (search for files with "-serdes-" in the file name)
- Documentation on configuring Kafka Applications when using Apicurio Registry v3 SerDe: /home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-3.1/docs/modules/ROOT/pages/getting-started/assembly-configuring-kafka-client-serdes.adoc
