# Quick Start Guide - Scenario 1 Infrastructure

This guide will help you quickly test the v2 deployment and nginx components that have been implemented.

## Prerequisites

- Docker and Docker Compose installed
- Ports available: 5432, 2222, 8080
- `curl` and `jq` installed

## Quick Test (5 minutes)

### 1. Deploy Registry v2 and Nginx

```bash
cd /home/ewittman/git/apicurio/apicurio-testing/migration-testing/scenario-1

# Deploy Registry v2
./scripts/step-A-deploy-v2.sh

# Deploy Nginx
./scripts/step-B-deploy-nginx.sh
```

Expected output:
```
✅ Step A completed successfully
Registry v2 is running at: http://localhost:2222

✅ Step B completed successfully
Nginx is running at: http://localhost:8080
Currently routing to: Registry v2 (2.6.x)
```

### 2. Verify Setup

```bash
# Test basic setup
./scripts/test-basic-setup.sh
```

Expected output:
```
✅ Basic setup test completed successfully!
```

### 3. Manual Verification

```bash
# Check registry directly
curl http://localhost:2222/apis/registry/v2/system/info | jq .

# Check registry through nginx
curl http://localhost:8080/apis/registry/v2/system/info | jq .

# Check nginx health
curl http://localhost:8080/nginx-health
```

### 4. Create a Test Artifact

```bash
# Create a simple Avro schema
curl -X POST http://localhost:8080/apis/registry/v2/groups/default/artifacts \
  -H "Content-Type: application/json" \
  -H "X-Registry-ArtifactId: my-test-schema" \
  -H "X-Registry-ArtifactType: AVRO" \
  -d '{
    "type": "record",
    "name": "Person",
    "fields": [
      {"name": "name", "type": "string"},
      {"name": "age", "type": "int"}
    ]
  }' | jq .
```

Expected output:
```json
{
  "id": "my-test-schema",
  "version": "1",
  "type": "AVRO",
  "globalId": 1,
  "state": "ENABLED",
  "createdOn": "2025-11-12T...",
  ...
}
```

### 5. Retrieve the Artifact

```bash
# Get artifact metadata
curl http://localhost:8080/apis/registry/v2/groups/default/artifacts/my-test-schema/meta | jq .

# Get artifact content
curl http://localhost:8080/apis/registry/v2/groups/default/artifacts/my-test-schema | jq .

# List all artifacts
curl http://localhost:8080/apis/registry/v2/search/artifacts | jq .
```

### 6. View Logs

```bash
# View deployment logs
cat logs/step-A-deploy-v2.log
cat logs/step-B-deploy-nginx.log

# View container logs
docker logs scenario1-registry-v2
docker logs scenario1-nginx
```

### 7. Cleanup

```bash
# Stop containers (keep data)
./scripts/cleanup.sh

# OR stop and remove all data
./scripts/cleanup.sh --volumes
```

## What's Working

✅ Components implemented:
- Apicurio Registry 2.6.13 deployment
- PostgreSQL 14 database
- Nginx reverse proxy/load balancer
- Helper scripts for deployment
- Health check utilities
- Basic testing script

✅ You can:
- Deploy Registry v2 with one command
- Access registry directly or through nginx
- Create, read, and search artifacts
- View logs and monitor containers
- Clean up easily

## What's Next

🔲 Still to implement:
- Registry v3 deployment (docker-compose-v3.yml)
- Java artifact creator client
- Java artifact validator clients (v2 and v3)
- Remaining step scripts (C through L)
- Full migration orchestration

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Client Applications                │
│                (curl, Java clients)                 │
└─────────────────────┬───────────────────────────────┘
                      │
                      │ Port 9090
                      ▼
             ┌────────────────┐
             │     Nginx      │
             │ Load Balancer  │
             └────────┬───────┘
                      │
                      │ Port 8080
                      ▼
          ┌──────────────────────┐
          │ Apicurio Registry    │
          │      v2.6.13         │
          └──────────┬───────────┘
                     │
                     │ Port 5432
                     ▼
            ┌────────────────┐
            │  PostgreSQL 14 │
            │   (registry db)│
            └────────────────┘
```

## Container Details

| Container | Port | Health Check | Purpose |
|-----------|------|--------------|---------|
| scenario1-postgres-v2 | 5432 | `pg_isready` | Database for v2 |
| scenario1-registry-v2 | 2222 | `/health/live` | Registry v2 |
| scenario1-nginx | 8080 | `/nginx-health` | Load balancer |

## Network Details

- **scenario1-v2-network**: Bridge network for v2 components
- All containers can communicate by name (e.g., `scenario1-registry-v2:8080`)

## Troubleshooting

### Registry won't start

```bash
# Check PostgreSQL is running
docker exec scenario1-postgres-v2 pg_isready -U apicurio

# Check registry logs
docker logs scenario1-registry-v2 --tail 50

# Restart registry
docker restart scenario1-registry-v2
```

### Can't access nginx

```bash
# Check nginx is running
docker ps | grep nginx

# Check nginx config
docker exec scenario1-nginx nginx -t

# View nginx logs
docker logs scenario1-nginx
```

### Port conflicts

```bash
# Check what's using ports
lsof -i :2222
lsof -i :8080

# Modify ports in docker-compose files if needed
```

### Reset everything

```bash
# Nuclear option - remove everything
./scripts/cleanup.sh --volumes
docker system prune -f
```

## Testing Tips

### Monitor in real-time

```bash
# Watch container logs
docker logs -f scenario1-registry-v2

# Watch all containers
docker compose -f docker-compose-v2.yml logs -f
```

### Check resource usage

```bash
# See container stats
docker stats scenario1-registry-v2 scenario1-nginx scenario1-postgres-v2
```

### Database access

```bash
# Connect to PostgreSQL
docker exec -it scenario1-postgres-v2 psql -U apicurio -d registry

# List tables
\dt

# Count artifacts
SELECT COUNT(*) FROM artifacts;

# Exit
\q
```

## Next Development Steps

1. **Implement v3 deployment**:
   - Create `docker-compose-v3.yml`
   - Create `scripts/step-G-deploy-v3.sh`
   - Test v3 deployment independently

2. **Implement export/import scripts**:
   - Create `scripts/step-F-export.sh`
   - Create `scripts/step-H-import.sh`
   - Test export/import cycle

3. **Implement nginx switching**:
   - Create `scripts/step-I-switch-nginx.sh`
   - Test switching from v2 to v3

4. **Implement Java clients**:
   - Artifact creator (v2 API)
   - Artifact validator (v2 API)
   - Artifact validator (v3 API)

## Questions?

- Check the main [README.md](./README.md) for full documentation
- Check the [TEST_PLAN.md](./TEST_PLAN.md) for detailed test procedures
- Check [scripts/README.md](./scripts/README.md) for script documentation
