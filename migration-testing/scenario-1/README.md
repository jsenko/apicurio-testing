# Migration Testing Scenario 1: Basic PostgreSQL Migration

## Overview

This scenario tests the core migration path from Apicurio Registry 2.6.x to 3.1.x using PostgreSQL storage
with simulated production traffic switching via nginx load balancer.

**Status**: ✅ Implemented & Tested
**Complexity**: Low
**Duration**: ~15-20 minutes
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

## Quick Links

- [**TEST_PLAN.md**](./TEST_PLAN.md) - Detailed test plan with all steps, components, and validation criteria
- [**EVALUATION.md**](./EVALUATION.md) - Analysis and recommendations for the test plan
- [**Implementation Guide**](#implementation-guide) - How to implement this scenario

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

## Success Criteria

The scenario passes if:
- ✅ All 25 artifacts migrate successfully
- ✅ All ~75 versions migrate successfully
- ✅ All metadata preserved (labels, properties, descriptions)
- ✅ Global rules migrated correctly
- ✅ Artifact references preserved
- ✅ v2 API works on v3 registry (backward compatibility)
- ✅ v3 API works correctly
- ✅ Content retrieval by globalId and contentHash works

## Directory Structure

```
scenario-1/
├── README.md                                # This file
├── TEST_PLAN.md                             # Detailed test plan
├── EVALUATION.md                            # Test plan evaluation
├── run-all-steps.sh                         # ⭐ Run complete automated test
├── cleanup.sh                               # Clean up containers and volumes
├── docker-compose-v2.yml                    # Registry 2.6.13 deployment
├── docker-compose-v3.yml                    # Registry 3.1.2 deployment
├── docker-compose-nginx.yml                 # Nginx load balancer
├── nginx/
│   └── conf.d/
│       ├── registry-v2.conf                 # Nginx config pointing to v2
│       └── registry-v3.conf                 # Nginx config pointing to v3
├── scripts/
│   ├── build-clients.sh                     # Build all Java clients
│   ├── step-A-deploy-v2.sh                  # Deploy v2 registry
│   ├── step-B-deploy-nginx.sh               # Deploy load balancer
│   ├── step-C-create-data.sh                # Create test data
│   ├── step-D-validate-pre-migration.sh     # Validate v2 data
│   ├── step-E-prepare-migration.sh          # Pause before migration
│   ├── step-F-export-v2-data.sh             # Export from v2
│   ├── step-G-deploy-v3.sh                  # Deploy v3 registry
│   ├── step-H-import-v3-data.sh             # Import to v3
│   ├── step-I-switch-nginx-to-v3.sh         # Switch load balancer to v3
│   ├── step-J-validate-post-migration.sh    # Validate v2 API on v3 (backward compat)
│   └── step-K-validate-v3-native.sh         # Validate v3 native API
├── clients/
│   ├── artifact-creator/                    # Java v2 client - creates data
│   │   ├── pom.xml
│   │   └── src/
│   ├── artifact-validator-v2/               # Java v2 client - validates
│   │   ├── pom.xml
│   │   └── src/
│   └── artifact-validator-v3/               # Java v3 client - validates
│       ├── pom.xml
│       └── src/
├── data/                                    # Generated during test
│   ├── creation-summary.txt
│   ├── registry-v2-export.zip
│   ├── validation-report-pre-migration.txt
│   ├── validation-report-post-migration.txt
│   └── validation-report-v3-native.txt
└── logs/                                    # Generated during test
    ├── run-all-steps.log                    # Master log
    ├── build-clients.log
    ├── step-A-deploy-v2.log
    ├── step-B-deploy-nginx.log
    ├── step-C-create-data.log
    ├── step-D-validate-pre-migration.log
    ├── step-E-prepare-migration.log
    ├── step-F-export-v2-data.log
    ├── step-G-deploy-v3.log
    ├── step-H-import-v3-data.log
    ├── step-I-switch-nginx-to-v3.log
    ├── step-J-validate-post-migration.log
    └── step-K-validate-v3-native.log
```

## Implementation Guide

### Phase 1: Infrastructure Setup (Week 1)

#### 1.1 Create Docker Compose Configurations

**Tasks**:
- [ ] Create `docker-compose-v2.yml`
- [ ] Create `docker-compose-v3.yml`
- [ ] Create `docker-compose-nginx.yml`
- [ ] Create nginx configuration files
- [ ] Test deployments independently

**Validation**:
```bash
# Test v2 deployment
docker compose -f docker-compose-v2.yml up -d
curl http://localhost:8080/health/live

# Test v3 deployment
docker compose -f docker-compose-v3.yml up -d
curl http://localhost:8081/health/live

# Test nginx
docker compose -f docker-compose-nginx.yml up -d
curl http://localhost:9090/nginx-health
```

#### 1.2 Create Helper Scripts

**Tasks**:
- [ ] Create `wait-for-health.sh`
- [ ] Create `cleanup.sh`
- [ ] Create `collect-logs.sh`
- [ ] Make all scripts executable

**Example: wait-for-health.sh**
```bash
#!/bin/bash
URL=$1
TIMEOUT=${2:-60}
ELAPSED=0

echo "Waiting for $URL to be healthy (timeout: ${TIMEOUT}s)..."

while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -f -s "$URL" > /dev/null 2>&1; then
        echo "✅ Healthy after ${ELAPSED}s"
        exit 0
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo ""
echo "❌ Timeout after ${TIMEOUT}s"
exit 1
```

### Phase 2: Java Clients (Week 1-2)

#### 2.1 Artifact Creator Client

**Directory**: `clients/artifact-creator/`

**Key Classes**:
- `ArtifactCreatorApp.java` - Main application
- `AvroSchemaGenerator.java` - Generate Avro schemas
- `ProtobufSchemaGenerator.java` - Generate Protobuf schemas
- `JsonSchemaGenerator.java` - Generate JSON schemas
- `OpenApiGenerator.java` - Generate OpenAPI specs
- `AsyncApiGenerator.java` - Generate AsyncAPI specs
- `CreationSummary.java` - Summary data model

**Implementation Steps**:
1. [ ] Set up Maven project with dependencies
2. [ ] Implement schema generators
3. [ ] Implement artifact creation logic
4. [ ] Implement global rule creation
5. [ ] Implement artifact rule creation
6. [ ] Implement metadata application
7. [ ] Implement summary generation
8. [ ] Add logging
9. [ ] Test locally

**Sample Schema Generation**:
```java
public class AvroSchemaGenerator {
    public String generateSimpleRecord(String name, int version) {
        return String.format("""
            {
              "type": "record",
              "name": "%s",
              "namespace": "com.example.avro",
              "fields": [
                {"name": "id", "type": "string"},
                {"name": "name", "type": "string"},
                {"name": "version", "type": "int", "default": %d}
              ]
            }
            """, name, version);
    }
}
```

#### 2.2 Artifact Validator (v2) Client

**Directory**: `clients/artifact-validator-v2/`

**Key Classes**:
- `ArtifactValidatorApp.java` - Main application
- `ArtifactCountValidator.java` - Validate artifact counts
- `MetadataValidator.java` - Validate metadata
- `RuleValidator.java` - Validate rules
- `ContentValidator.java` - Validate content retrieval
- `ReferenceValidator.java` - Validate references
- `ValidationReport.java` - Report data model

**Implementation Steps**:
1. [ ] Set up Maven project with dependencies
2. [ ] Implement validators
3. [ ] Implement report generation
4. [ ] Add detailed logging
5. [ ] Test locally

#### 2.3 Artifact Validator (v3) Client

**Directory**: `clients/artifact-validator-v3/`

**Key Classes**:
- Same as v2 validator, but using v3 SDK
- Additional v3-specific validators

**Implementation Steps**:
1. [ ] Copy v2 validator structure
2. [ ] Update to use v3 SDK
3. [ ] Add v3-specific validations
4. [ ] Test locally

### Phase 3: Automation Scripts (Week 2)

#### 3.1 Step Scripts

Create individual scripts for each step (A through L).

**Template**:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

# Log file
LOG_FILE="$PROJECT_DIR/logs/step-A-deploy-v2.log"

echo "Step A: Deploy Apicurio Registry 2.6.x" | tee "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# Deploy
cd "$PROJECT_DIR"
docker compose -f docker-compose-v2.yml up -d 2>&1 | tee -a "$LOG_FILE"

# Wait for health
./scripts/wait-for-health.sh http://localhost:8080/health/live 60 | tee -a "$LOG_FILE"

# Verify
echo "" | tee -a "$LOG_FILE"
echo "System Info:" | tee -a "$LOG_FILE"
curl -s http://localhost:8080/apis/registry/v2/system/info | jq . | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "✅ Step A completed successfully" | tee -a "$LOG_FILE"
```

**Tasks**:
- [ ] Create all 12 step scripts
- [ ] Test each script individually
- [ ] Test scripts in sequence
- [ ] Add error handling

#### 3.2 Master Orchestration Script

**File**: `scripts/run-scenario.sh`

**Tasks**:
- [ ] Create master script
- [ ] Call all step scripts in sequence
- [ ] Add pause at step E
- [ ] Capture overall timing
- [ ] Generate summary

**Implementation**:
```bash
#!/bin/bash
set -e

echo "================================================"
echo "  Apicurio Registry Migration Scenario 1"
echo "  Basic PostgreSQL Migration Test"
echo "================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_TIME=$(date +%s)

# Execute steps
./scripts/step-A-deploy-v2.sh
./scripts/step-B-deploy-nginx.sh
./scripts/step-C-create-data.sh
./scripts/step-D-validate-pre-migration.sh

echo ""
echo "========================================="
echo "  Step E: Manual Checkpoint"
echo "========================================="
echo ""
echo "Review the validation results in:"
echo "  - data/creation-summary.json"
echo "  - data/validation-pre-migration.json"
echo ""
read -p "Continue with migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration aborted"
    exit 1
fi

./scripts/step-F-export.sh
./scripts/step-G-deploy-v3.sh
./scripts/step-H-import.sh
./scripts/step-I-switch-nginx.sh
./scripts/step-J-validate-v2-api-on-v3.sh
./scripts/step-K-validate-v3-api.sh

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "================================================"
echo "  Migration Scenario 1 Complete!"
echo "  Total Duration: ${DURATION}s"
echo "================================================"
echo ""
echo "Results:"
echo "  - Pre-migration validation: data/validation-pre-migration.json"
echo "  - v2 API on v3 validation: data/validation-v2-api-on-v3.json"
echo "  - v3 API validation: data/validation-v3-api.json"
echo ""
echo "Generate report with: ./scripts/generate-report.sh"
```

#### 3.3 Report Generation Script

**File**: `scripts/generate-report.sh`

**Tasks**:
- [ ] Create HTML report generator
- [ ] Include all validation results
- [ ] Add charts/graphs
- [ ] Include log excerpts
- [ ] Add screenshots (if applicable)

### Phase 4: Testing & Refinement (Week 3)

#### 4.1 Initial Testing

**Tasks**:
- [ ] Run full scenario 3 times
- [ ] Document all issues found
- [ ] Fix bugs
- [ ] Improve error messages
- [ ] Optimize timing

#### 4.2 Edge Case Testing

**Tasks**:
- [ ] Test with no artifacts (empty export)
- [ ] Test with duplicate artifact creation attempts
- [ ] Test import to non-empty registry (should fail)
- [ ] Test with invalid export file
- [ ] Test with network interruptions

#### 4.3 Documentation

**Tasks**:
- [ ] Update README with lessons learned
- [ ] Document known issues
- [ ] Add troubleshooting section
- [ ] Create video walkthrough (optional)

## Usage

### Quick Start (Automated)

```bash
cd /home/ewittman/git/apicurio/apicurio-testing/migration-testing/scenario-1

# Build all clients
./scripts/build-clients.sh

# Run full scenario
./scripts/run-scenario.sh

# Generate report
./scripts/generate-report.sh

# View report
firefox reports/scenario-1-report.html
```

### Manual Step-by-Step

```bash
# Infrastructure
./scripts/step-A-deploy-v2.sh
./scripts/step-B-deploy-nginx.sh

# Create and validate
./scripts/step-C-create-data.sh
./scripts/step-D-validate-pre-migration.sh

# Review results
cat data/creation-summary.json
cat data/validation-pre-migration.json

# Migrate
./scripts/step-F-export.sh
./scripts/step-G-deploy-v3.sh
./scripts/step-H-import.sh
./scripts/step-I-switch-nginx.sh

# Validate post-migration
./scripts/step-J-validate-v2-api-on-v3.sh
./scripts/step-K-validate-v3-api.sh

# Cleanup
./scripts/step-L-cleanup.sh
```

## Troubleshooting

### Issue: Container fails to start

**Symptom**: Docker container exits immediately

**Solution**:
```bash
# Check logs
docker compose -f docker-compose-v2.yml logs apicurio-registry-v2

# Check PostgreSQL health
docker compose -f docker-compose-v2.yml ps
```

### Issue: Import fails with "registry not empty"

**Symptom**: Import returns 400 error

**Solution**:
```bash
# Verify registry is empty
curl http://localhost:8081/apis/registry/v3/search/artifacts?limit=1

# If not empty, redeploy
docker compose -f docker-compose-v3.yml down -v
docker compose -f docker-compose-v3.yml up -d
```

### Issue: Validation fails

**Symptom**: Artifact count mismatch

**Solution**:
```bash
# Check import logs
docker compose -f docker-compose-v3.yml logs apicurio-registry-v3 | grep -i import

# Compare counts
curl http://localhost:8080/apis/registry/v2/search/artifacts?limit=1  # v2
curl http://localhost:8081/apis/registry/v3/search/artifacts?limit=1  # v3
```

## Next Steps

After successfully completing Scenario 1:

1. **Document Lessons Learned**: Update this README with findings
2. **Plan Scenario 2**: Add Keycloak authentication testing
3. **Share Results**: Present findings to team
4. **Iterate**: Incorporate feedback into subsequent scenarios

## Resources

- [Apicurio Registry 2.6.x Documentation](https://www.apicur.io/registry/docs/apicurio-registry/2.6.x/)
- [Apicurio Registry 3.1.x Documentation](https://www.apicur.io/registry/docs/apicurio-registry/3.1.x/)
- [Migration Guide](../ANALYSIS.md)
- [Docker Documentation](https://docs.docker.com/)

---

**Status**: 📋 Ready for Implementation
**Last Updated**: 2025-11-12
