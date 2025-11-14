# Migration Testing Scenario 1: Basic PostgreSQL Migration

## Overview

This scenario tests the core migration path from Apicurio Registry 2.6.x to 3.1.x using PostgreSQL storage
with simulated production traffic switching via nginx load balancer.

**Complexity**: Low
**Prerequisites**: Docker, Java 11+, Maven 3.8+, jq, curl

## Quick Start

Run the complete automated migration test:

```bash
# Run all migration steps automatically
./run-all-steps.sh

# Or run individual steps manually
./scripts/step-A-deploy-v2.sh
./scripts/step-B-deploy-nginx.sh
# ... etc
```

Clean up after testing:

```bash
./cleanup.sh
```

## Objectives

1. ✅ Validate export/import process preserves all data
2. ✅ Verify v2 API backward compatibility in 3.1.x
3. ✅ Test new v3 API functionality after migration
4. ✅ Simulate production-like traffic switching
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

## Components

### Infrastructure
- **apicurio-registry-v2**: Apicurio Registry 2.6.13.Final
- **postgres-v2**: PostgreSQL 14
- **apicurio-registry-v3**: Apicurio Registry 3.1.0
- **postgres-v3**: PostgreSQL 14
- **nginx**: Nginx reverse proxy (load balancer)

### Client Applications
- **artifact-creator**: Creates diverse test data using v2 client
- **artifact-validator-v2**: Validates registry content using v2 API
- **artifact-validator-v3**: Validates registry content using v3 API

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
