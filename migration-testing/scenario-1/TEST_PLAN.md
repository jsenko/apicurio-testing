# Migration Test Scenario 1: Basic PostgreSQL Migration

**Scenario**: Basic migration from Apicurio Registry 2.6.x to 3.1.x using PostgreSQL storage with load
balancer traffic switching.

**Complexity**: Low
**Duration**: ~15-20 minutes
**Focus**: Core migration process, data integrity, backward compatibility

## Objectives

1. Validate export/import process preserves all data
2. Verify v2 API backward compatibility in 3.1.x
3. Test new v3 API functionality after migration
4. Simulate production-like traffic switching with load balancer
5. Ensure artifact metadata, rules, and references survive migration

## Out of Scope for Scenario 1

- Authentication/Authorization (no Keycloak) - **Scenario 2**
- Kafka SerDes testing - **Scenario 3**
- KafkaSQL storage - **Scenario 4**
- Performance/load testing - **Scenario 5**
- Rollback procedures - **Scenario 6**

---

## Test Components

### 1. Apicurio Registry 2.6.x Deployment

**Implementation**: Docker Compose

**Services**:
- `apicurio-registry-v2`: Apicurio Registry 2.6.x
- `postgres-v2`: PostgreSQL 14

**Configuration**:
```yaml
# docker-compose-v2.yml
services:
  postgres-v2:
    image: postgres:14
    environment:
      POSTGRES_DB: registry
      POSTGRES_USER: apicurio
      POSTGRES_PASSWORD: apicurio123
    ports:
      - "5432:5432"
    volumes:
      - postgres-v2-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U apicurio"]
      interval: 10s
      timeout: 5s
      retries: 5

  apicurio-registry-v2:
    image: apicurio/apicurio-registry-sql:2.6.13.Final
    ports:
      - "8080:8080"
    environment:
      REGISTRY_DATASOURCE_URL: jdbc:postgresql://postgres-v2:5432/registry
      REGISTRY_DATASOURCE_USERNAME: apicurio
      REGISTRY_DATASOURCE_PASSWORD: apicurio123
      QUARKUS_DATASOURCE_DB_KIND: postgresql
      LOG_LEVEL: INFO
      REGISTRY_LOG_LEVEL: DEBUG
    depends_on:
      postgres-v2:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/live"]
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  postgres-v2-data:
```

**Validation**:
- Health check passes: `http://localhost:8080/health/live`
- System info accessible: `http://localhost:8080/apis/registry/v2/system/info`
- PostgreSQL connection verified

---

### 2. Java Client Applications (v2 API)

**Implementation**: Two Java applications using Apicurio Registry 2.6.x client libraries

#### 2.1 Artifact Creator Application

**Purpose**: Populate registry with diverse test data

**Maven Dependencies**:
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-client</artifactId>
    <version>2.6.13.Final</version>
</dependency>
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-utils-serde</artifactId>
    <version>2.6.13.Final</version>
</dependency>
```

**Test Data to Create**:

1. **Avro Schemas** (10 artifacts, 3-5 versions each)
   - Simple record schemas
   - Schemas with backward compatible changes
   - Schemas with forward compatible changes
   - Artifacts with labels: `type:avro`, `env:test`
   - Artifacts with properties: `owner:test-suite`, `version:1.0`

2. **Protobuf Schemas** (5 artifacts, 2-3 versions each)
   - Simple message definitions
   - Messages with imports (artifact references)
   - Artifacts with labels: `type:protobuf`, `env:test`

3. **JSON Schemas** (5 artifacts, 2-3 versions each)
   - Simple object schemas
   - Schemas with $ref to other schemas (artifact references)
   - Artifacts with labels: `type:json`, `env:test`

4. **OpenAPI Specifications** (3 artifacts, 2 versions each)
   - REST API definitions
   - Artifacts with labels: `type:openapi`, `env:test`

5. **AsyncAPI Specifications** (2 artifacts, 2 versions each)
   - Event-driven API definitions
   - Artifacts with labels: `type:asyncapi`, `env:test`

**Global Rules to Create**:
- VALIDITY: FULL
- COMPATIBILITY: BACKWARD

**Artifact-Specific Rules**:
- Create COMPATIBILITY: FORWARD rule on one Avro artifact
- Create COMPATIBILITY: NONE rule on one JSON Schema artifact

**Version Metadata**:
- Add descriptions to all artifacts
- Add version comments on selected versions
- Add custom properties to various versions

**Expected Totals**:
- Total Artifacts: 25
- Total Versions: ~75
- Total Artifact References: ~5
- Global Rules: 2
- Artifact Rules: 2

**Exit Criteria**:
- All artifacts created successfully
- All versions created successfully
- All metadata applied
- All rules configured
- Return summary statistics

#### 2.2 Artifact Validator Application

**Purpose**: Validate registry content matches expected state

**Validations**:

1. **Artifact Count Validation**
   - Total artifacts: 25
   - Avro artifacts: 10
   - Protobuf artifacts: 5
   - JSON Schema artifacts: 5
   - OpenAPI artifacts: 3
   - AsyncAPI artifacts: 2

2. **Version Count Validation**
   - Total versions: ~75 (exact count from creator output)
   - Verify each artifact has expected version count

3. **Metadata Validation**
   - Verify labels on all artifacts
   - Verify properties on all artifacts
   - Verify descriptions present
   - Verify version comments present

4. **Global Rules Validation**
   - VALIDITY rule exists with FULL config
   - COMPATIBILITY rule exists with BACKWARD config

5. **Artifact Rules Validation**
   - Verify artifact-specific COMPATIBILITY rules

6. **Content Retrieval Validation**
   - Retrieve content by globalId for 10 random versions
   - Retrieve content by contentHash for 5 random versions
   - Verify content matches expected

7. **Reference Validation**
   - Verify artifacts with references have them preserved
   - Verify reference targets exist

**Exit Criteria**:
- All validations pass
- Report validation results (pass/fail for each check)
- Return detailed statistics

---

### 3. Apicurio Registry 3.1.x Deployment

**Implementation**: Docker Compose

**Services**:
- `apicurio-registry-v3`: Apicurio Registry 3.1.x
- `postgres-v3`: PostgreSQL 14

**Configuration**:
```yaml
# docker-compose-v3.yml
services:
  postgres-v3:
    image: postgres:14
    environment:
      POSTGRES_DB: registry
      POSTGRES_USER: apicurio
      POSTGRES_PASSWORD: apicurio123
    ports:
      - "5433:5432"  # Different host port to avoid conflict
    volumes:
      - postgres-v3-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U apicurio"]
      interval: 10s
      timeout: 5s
      retries: 5

  apicurio-registry-v3:
    image: apicurio/apicurio-registry:3.1.0
    ports:
      - "8081:8080"  # Different host port to avoid conflict
    environment:
      APICURIO_STORAGE_KIND: sql
      APICURIO_STORAGE_SQL_KIND: postgresql
      APICURIO_DATASOURCE_URL: jdbc:postgresql://postgres-v3:5432/registry
      APICURIO_DATASOURCE_USERNAME: apicurio
      APICURIO_DATASOURCE_PASSWORD: apicurio123
      APICURIO_LOG_LEVEL: DEBUG
      APICURIO_IMPORT_PRESERVE_GLOBAL_ID: "true"
      APICURIO_IMPORT_PRESERVE_CONTENT_ID: "true"
    depends_on:
      postgres-v3:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/live"]
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  postgres-v3-data:
```

**Key Configuration Differences from v2**:
- `APICURIO_STORAGE_KIND` instead of implicit SQL
- `APICURIO_STORAGE_SQL_KIND` instead of `QUARKUS_DATASOURCE_DB_KIND`
- `APICURIO_DATASOURCE_URL` instead of `REGISTRY_DATASOURCE_URL`
- `APICURIO_LOG_LEVEL` instead of `REGISTRY_LOG_LEVEL`
- Import preservation flags

**Validation**:
- Health check passes: `http://localhost:8081/health/live`
- System info accessible: `http://localhost:8081/apis/registry/v3/system/info`
- PostgreSQL connection verified

---

### 4. Java Client Application (v3 API)

**Implementation**: Java application using Apicurio Registry 3.1.x Java SDK

**Maven Dependencies**:
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-java-sdk</artifactId>
    <version>3.1.0</version>
</dependency>
```

**Client Initialization**:
```java
VertXRequestAdapter adapter = new VertXRequestAdapter(vertx);
adapter.setBaseUrl("http://nginx:8080/apis/registry/v3");
RegistryClient client = new RegistryClient(adapter);
```

**Validations** (same as v2 validator plus v3-specific):

1. **All validations from v2 validator**
2. **v3-Specific API Tests**:
   - List groups with pagination
   - Retrieve group metadata
   - Search artifacts with new filters
   - Test branches API (if applicable)

**Exit Criteria**:
- All validations pass using v3 API
- Report validation results
- Confirm parity with v2 API results

---

### 5. Nginx Reverse Proxy (Load Balancer)

**Implementation**: Nginx in Docker container

**Configuration**:
```nginx
# nginx.conf
upstream registry_backend {
    server apicurio-registry-v2:8080;  # Initially points to v2
}

server {
    listen 8080;
    server_name localhost;

    location / {
        proxy_pass http://registry_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

**Docker Compose Integration**:
```yaml
# docker-compose-nginx.yml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "9090:8080"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx-v2.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - apicurio-registry-v2
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/nginx-health"]
      interval: 10s
      timeout: 5s
      retries: 3
```

**Configuration Files**:
- `nginx-v2.conf`: Points to apicurio-registry-v2
- `nginx-v3.conf`: Points to apicurio-registry-v3

**Switching Mechanism**:
```bash
# Switch to v3
docker cp nginx-v3.conf nginx:/etc/nginx/conf.d/default.conf
docker exec nginx nginx -s reload
```

---

## Test Execution Plan

### Step A: Deploy Apicurio Registry 2.6.x

**Command**:
```bash
cd scenario-1
docker compose -f docker-compose-v2.yml up -d
```

**Validation**:
```bash
# Wait for health check
./scripts/wait-for-health.sh http://localhost:8080/health/live 60

# Verify system info
curl http://localhost:8080/apis/registry/v2/system/info | jq .

# Expected: version 2.6.x
```

**Exit Criteria**:
- ✅ PostgreSQL container running
- ✅ Registry container running
- ✅ Health check returns 200
- ✅ System info shows version 2.6.x

**Logs Location**: `./logs/step-A-deploy-v2.log`

---

### Step B: Deploy Load Balancer

**Command**:
```bash
docker compose -f docker-compose-nginx.yml up -d
```

**Validation**:
```bash
# Verify nginx health
curl http://localhost:9090/nginx-health

# Verify registry accessible through nginx
curl http://localhost:9090/apis/registry/v2/system/info | jq .

# Expected: version 2.6.x (proxied through nginx)
```

**Exit Criteria**:
- ✅ Nginx container running
- ✅ Can access registry through nginx
- ✅ System info accessible via nginx

**Logs Location**: `./logs/step-B-deploy-nginx.log`

---

### Step C: Create Test Data

**Command**:
```bash
cd clients/artifact-creator
mvn clean package
java -jar target/artifact-creator.jar \
  --registry-url=http://localhost:9090/apis/registry/v2 \
  --output=../../data/creation-summary.json
```

**Output**:
```json
{
  "timestamp": "2025-11-12T10:00:00Z",
  "totalArtifacts": 25,
  "totalVersions": 75,
  "artifactsByType": {
    "AVRO": 10,
    "PROTOBUF": 5,
    "JSON": 5,
    "OPENAPI": 3,
    "ASYNCAPI": 2
  },
  "globalRules": 2,
  "artifactRules": 2,
  "artifactsWithReferences": 5,
  "artifacts": [
    {
      "groupId": "default",
      "artifactId": "avro-schema-001",
      "versions": 3,
      "labels": ["type:avro", "env:test"],
      "properties": {"owner": "test-suite"}
    }
    // ... more artifacts
  ]
}
```

**Exit Criteria**:
- ✅ All 25 artifacts created
- ✅ All ~75 versions created
- ✅ Global rules configured
- ✅ Artifact rules configured
- ✅ Summary file generated

**Logs Location**: `./logs/step-C-create-data.log`

---

### Step D: Validate v2 Registry Content

**Command**:
```bash
cd clients/artifact-validator-v2
mvn clean package
java -jar target/artifact-validator-v2.jar \
  --registry-url=http://localhost:9090/apis/registry/v2 \
  --expected=../../data/creation-summary.json \
  --output=../../data/validation-pre-migration.json
```

**Output**:
```json
{
  "timestamp": "2025-11-12T10:05:00Z",
  "status": "PASS",
  "checks": {
    "artifactCount": {
      "status": "PASS",
      "expected": 25,
      "actual": 25
    },
    "versionCount": {
      "status": "PASS",
      "expected": 75,
      "actual": 75
    },
    "globalRules": {
      "status": "PASS",
      "expected": 2,
      "actual": 2
    },
    "contentRetrieval": {
      "status": "PASS",
      "samplesChecked": 10,
      "passed": 10
    },
    "references": {
      "status": "PASS",
      "artifactsWithRefs": 5,
      "referencesValidated": 5
    }
  },
  "failures": []
}
```

**Exit Criteria**:
- ✅ Overall status: PASS
- ✅ All artifact counts match
- ✅ All version counts match
- ✅ All rules present
- ✅ Content retrieval successful
- ✅ References validated

**Logs Location**: `./logs/step-D-validate-pre-migration.log`

---

### Step E: Pause (Manual Checkpoint)

**Actions**:
- Review creation summary
- Review validation results
- Verify no errors in logs
- Confirm ready to proceed with migration

**Decision Point**: GO / NO-GO for migration

---

### Step F: Export Data from v2

**Command**:
```bash
curl -X GET http://localhost:8080/apis/registry/v2/admin/export \
  -H "Accept: application/zip" \
  -o ./data/registry-export.zip

# Validate export file
ls -lh ./data/registry-export.zip
unzip -l ./data/registry-export.zip > ./data/export-contents.txt
```

**Validation**:
```bash
# Check file size (should be > 0)
FILE_SIZE=$(stat -f%z ./data/registry-export.zip 2>/dev/null || stat -c%s ./data/registry-export.zip)
if [ "$FILE_SIZE" -gt 1024 ]; then
  echo "✅ Export file size: $FILE_SIZE bytes"
else
  echo "❌ Export file too small: $FILE_SIZE bytes"
  exit 1
fi

# Verify it's a valid ZIP
unzip -t ./data/registry-export.zip
```

**Exit Criteria**:
- ✅ Export file created
- ✅ File size > 1KB
- ✅ Valid ZIP file
- ✅ Contents list generated

**Logs Location**: `./logs/step-F-export.log`

---

### Step G: Deploy Apicurio Registry 3.1.x

**Command**:
```bash
docker compose -f docker-compose-v3.yml up -d
```

**Validation**:
```bash
# Wait for health check
./scripts/wait-for-health.sh http://localhost:8081/health/live 60

# Verify system info
curl http://localhost:8081/apis/registry/v3/system/info | jq .

# Expected: version 3.1.x
```

**Exit Criteria**:
- ✅ PostgreSQL container running
- ✅ Registry container running
- ✅ Health check returns 200
- ✅ System info shows version 3.1.x
- ✅ Registry is empty (artifact count = 0)

**Logs Location**: `./logs/step-G-deploy-v3.log`

---

### Step H: Import Data into v3

**Command**:
```bash
curl -X POST http://localhost:8081/apis/registry/v3/admin/import \
  -H "Content-Type: application/zip" \
  --data-binary @./data/registry-export.zip \
  -o ./data/import-response.json

# Check import response
cat ./data/import-response.json | jq .
```

**Validation**:
```bash
# Verify artifact count matches
EXPECTED_COUNT=25
ACTUAL_COUNT=$(curl -s http://localhost:8081/apis/registry/v3/search/artifacts?limit=1 | jq .count)

if [ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]; then
  echo "✅ Artifact count matches: $ACTUAL_COUNT"
else
  echo "❌ Artifact count mismatch. Expected: $EXPECTED_COUNT, Actual: $ACTUAL_COUNT"
  exit 1
fi
```

**Exit Criteria**:
- ✅ Import completes successfully (HTTP 200/201/204)
- ✅ Artifact count matches expected (25)
- ✅ No errors in import response
- ✅ Global rules imported

**Logs Location**: `./logs/step-H-import.log`

---

### Step I: Switch Load Balancer to v3

**Command**:
```bash
# Copy v3 config to nginx
docker cp ./nginx-v3.conf nginx:/etc/nginx/conf.d/default.conf

# Reload nginx
docker exec nginx nginx -s reload

# Wait for reload
sleep 2
```

**Validation**:
```bash
# Verify nginx now points to v3
VERSION=$(curl -s http://localhost:9090/apis/registry/v3/system/info | jq -r .version)

if [[ "$VERSION" == 3.1.* ]]; then
  echo "✅ Nginx now pointing to v3: $VERSION"
else
  echo "❌ Nginx not pointing to v3. Version: $VERSION"
  exit 1
fi

# Verify v2 API still accessible through v3
curl -s http://localhost:9090/apis/registry/v2/system/info | jq .
```

**Exit Criteria**:
- ✅ Nginx reload successful
- ✅ v3 API accessible through nginx
- ✅ v2 API accessible through nginx (backward compatibility)
- ✅ System info shows version 3.1.x

**Logs Location**: `./logs/step-I-switch-nginx.log`

---

### Step J: Validate v2 API Compatibility in v3

**Command**:
```bash
cd clients/artifact-validator-v2
java -jar target/artifact-validator-v2.jar \
  --registry-url=http://localhost:9090/apis/registry/v2 \
  --expected=../../data/creation-summary.json \
  --output=../../data/validation-v2-api-on-v3.json
```

**Output**:
```json
{
  "timestamp": "2025-11-12T10:15:00Z",
  "status": "PASS",
  "apiVersion": "v2",
  "registryVersion": "3.1.x",
  "checks": {
    "artifactCount": { "status": "PASS", "expected": 25, "actual": 25 },
    "versionCount": { "status": "PASS", "expected": 75, "actual": 75 },
    "globalRules": { "status": "PASS", "expected": 2, "actual": 2 },
    "metadata": { "status": "PASS", "labelsChecked": 25, "propertiesChecked": 25 },
    "contentRetrieval": { "status": "PASS", "samplesChecked": 10, "passed": 10 },
    "contentHash": { "status": "PASS", "samplesChecked": 5, "passed": 5 },
    "references": { "status": "PASS", "artifactsWithRefs": 5, "referencesValidated": 5 }
  },
  "failures": []
}
```

**Exit Criteria**:
- ✅ Overall status: PASS
- ✅ All validations pass using v2 API against v3 registry
- ✅ Backward compatibility confirmed
- ✅ All metadata preserved
- ✅ All references preserved

**Logs Location**: `./logs/step-J-validate-v2-api-on-v3.log`

---

### Step K: Validate v3 API Functionality

**Command**:
```bash
cd clients/artifact-validator-v3
mvn clean package
java -jar target/artifact-validator-v3.jar \
  --registry-url=http://localhost:9090/apis/registry/v3 \
  --expected=../../data/creation-summary.json \
  --output=../../data/validation-v3-api.json
```

**Output**:
```json
{
  "timestamp": "2025-11-12T10:20:00Z",
  "status": "PASS",
  "apiVersion": "v3",
  "registryVersion": "3.1.x",
  "checks": {
    "artifactCount": { "status": "PASS", "expected": 25, "actual": 25 },
    "versionCount": { "status": "PASS", "expected": 75, "actual": 75 },
    "globalRules": { "status": "PASS", "expected": 2, "actual": 2 },
    "metadata": { "status": "PASS", "labelsChecked": 25, "propertiesChecked": 25 },
    "contentRetrieval": { "status": "PASS", "samplesChecked": 10, "passed": 10 },
    "references": { "status": "PASS", "artifactsWithRefs": 5, "referencesValidated": 5 },
    "v3Features": {
      "groupList": { "status": "PASS", "groupsFound": 1 },
      "groupMetadata": { "status": "PASS" },
      "enhancedSearch": { "status": "PASS" }
    }
  },
  "failures": []
}
```

**Exit Criteria**:
- ✅ Overall status: PASS
- ✅ All validations pass using v3 API
- ✅ v3-specific features work
- ✅ Data parity with v2 API results

**Logs Location**: `./logs/step-K-validate-v3-api.log`

---

### Step L: Cleanup

**Command**:
```bash
./scripts/cleanup.sh
```

**Actions**:
```bash
# Stop and remove all containers
docker compose -f docker-compose-v2.yml down -v
docker compose -f docker-compose-v3.yml down -v
docker compose -f docker-compose-nginx.yml down

# Optional: Keep data for analysis
# docker volume rm scenario-1_postgres-v2-data
# docker volume rm scenario-1_postgres-v3-data
```

**Exit Criteria**:
- ✅ All containers stopped
- ✅ Networks removed
- ✅ Logs preserved

---

## Success Criteria

### Overall Test Success

The scenario is considered **PASSED** if:

1. ✅ All deployment steps complete without errors
2. ✅ Export file created successfully
3. ✅ Import completes without errors
4. ✅ Artifact count matches (25 artifacts)
5. ✅ Version count matches (~75 versions)
6. ✅ All metadata preserved (labels, properties, descriptions)
7. ✅ Global rules migrated correctly
8. ✅ Artifact-specific rules migrated correctly
9. ✅ Artifact references preserved
10. ✅ v2 API validation passes on v3 registry (backward compatibility)
11. ✅ v3 API validation passes
12. ✅ Content retrieval by globalId works
13. ✅ Content retrieval by contentHash works

### Failure Scenarios

The scenario is considered **FAILED** if:

- ❌ Any deployment fails to start
- ❌ Export file is empty or corrupted
- ❌ Import fails or reports errors
- ❌ Artifact count mismatch after import
- ❌ Metadata lost during migration
- ❌ Rules not migrated
- ❌ References broken after migration
- ❌ v2 API compatibility broken
- ❌ v3 API not functional

---

## Test Artifacts

### Generated Files

1. **Data Files**:
   - `data/creation-summary.json` - Summary of created test data
   - `data/registry-export.zip` - Export file from v2
   - `data/export-contents.txt` - Listing of export contents
   - `data/import-response.json` - Import response from v3
   - `data/validation-pre-migration.json` - Pre-migration validation results
   - `data/validation-v2-api-on-v3.json` - v2 API compatibility validation
   - `data/validation-v3-api.json` - v3 API validation results

2. **Log Files**:
   - `logs/step-A-deploy-v2.log`
   - `logs/step-B-deploy-nginx.log`
   - `logs/step-C-create-data.log`
   - `logs/step-D-validate-pre-migration.log`
   - `logs/step-F-export.log`
   - `logs/step-G-deploy-v3.log`
   - `logs/step-H-import.log`
   - `logs/step-I-switch-nginx.log`
   - `logs/step-J-validate-v2-api-on-v3.log`
   - `logs/step-K-validate-v3-api.log`

3. **Container Logs**:
   - `logs/containers/postgres-v2.log`
   - `logs/containers/apicurio-registry-v2.log`
   - `logs/containers/postgres-v3.log`
   - `logs/containers/apicurio-registry-v3.log`
   - `logs/containers/nginx.log`

### Test Report

**Location**: `reports/scenario-1-report.html`

**Contents**:
- Executive summary
- Step-by-step results
- Validation comparisons
- Performance metrics (timing)
- Artifact inventory before/after
- Screenshots of key validations
- Error logs (if any)

---

## Execution

### Prerequisites

1. Docker and Docker Compose installed
2. Java 17+ installed
3. Maven 3.8+ installed
4. curl, jq, unzip utilities available
5. At least 4GB free RAM
6. At least 2GB free disk space

### Quick Start

```bash
# Clone repository
cd /home/ewittman/git/apicurio/apicurio-testing/migration-testing/scenario-1

# Build all clients
./scripts/build-clients.sh

# Run full scenario
./scripts/run-scenario.sh

# View results
./scripts/generate-report.sh
open reports/scenario-1-report.html
```

### Manual Execution

```bash
# Step by step
./scripts/step-A-deploy-v2.sh
./scripts/step-B-deploy-nginx.sh
./scripts/step-C-create-data.sh
./scripts/step-D-validate-pre-migration.sh
# ... manual pause/review ...
./scripts/step-F-export.sh
./scripts/step-G-deploy-v3.sh
./scripts/step-H-import.sh
./scripts/step-I-switch-nginx.sh
./scripts/step-J-validate-v2-api-on-v3.sh
./scripts/step-K-validate-v3-api.sh
./scripts/step-L-cleanup.sh
```

---

## Timing Estimates

| Step | Estimated Duration | Notes |
|------|-------------------|-------|
| A. Deploy v2 | 30s | Includes PostgreSQL init |
| B. Deploy nginx | 10s | Quick startup |
| C. Create data | 2-3 min | 25 artifacts, 75 versions |
| D. Validate pre-migration | 30s | Read-only operations |
| E. Pause | Variable | Manual review |
| F. Export | 10s | Small dataset |
| G. Deploy v3 | 30s | Includes PostgreSQL init |
| H. Import | 30s | Small dataset |
| I. Switch nginx | 5s | Config reload |
| J. Validate v2 API | 30s | Read-only operations |
| K. Validate v3 API | 30s | Read-only operations |
| L. Cleanup | 20s | Stop containers |
| **Total** | **~10-15 min** | Excluding manual pause |

---

## Next Steps

After successful completion of Scenario 1:

1. **Scenario 2**: Add Keycloak authentication testing
2. **Scenario 3**: Add Kafka SerDes testing
3. **Scenario 4**: Test with KafkaSQL storage
4. **Scenario 5**: Performance/load testing during migration
5. **Scenario 6**: Rollback procedures and failure recovery

---

## Appendix: Configuration Changes Summary

### Environment Variable Mapping (v2 → v3)

| 2.6.x Environment Variable | 3.1.x Environment Variable | Notes |
|---------------------------|---------------------------|-------|
| `REGISTRY_DATASOURCE_URL` | `APICURIO_DATASOURCE_URL` | Namespace change |
| `REGISTRY_DATASOURCE_USERNAME` | `APICURIO_DATASOURCE_USERNAME` | Namespace change |
| `REGISTRY_DATASOURCE_PASSWORD` | `APICURIO_DATASOURCE_PASSWORD` | Namespace change |
| `QUARKUS_DATASOURCE_DB_KIND` | `APICURIO_STORAGE_SQL_KIND` | Property renamed |
| `REGISTRY_LOG_LEVEL` | `APICURIO_LOG_LEVEL` | Namespace change |
| N/A | `APICURIO_STORAGE_KIND` | New in v3 |
| N/A | `APICURIO_IMPORT_PRESERVE_GLOBAL_ID` | New in v3 |
| N/A | `APICURIO_IMPORT_PRESERVE_CONTENT_ID` | New in v3 |

---

**Document Version**: 1.0
**Last Updated**: 2025-11-12
**Author**: Migration Testing Team
