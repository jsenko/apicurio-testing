# Scenario 1 Scripts

This directory contains automation scripts for executing the migration test scenario.

## Available Scripts

### Utility Scripts

#### `wait-for-health.sh`
Waits for a health endpoint to become healthy.

**Usage:**
```bash
./wait-for-health.sh <url> [timeout_seconds]
```

**Examples:**
```bash
./wait-for-health.sh http://localhost:8080/health/live
./wait-for-health.sh http://localhost:8080/health/live 120
```

#### `cleanup.sh`
Stops and removes all containers. Optionally removes volumes.

**Usage:**
```bash
./cleanup.sh              # Keep volumes (data preserved)
./cleanup.sh --volumes    # Remove volumes (data lost)
```

#### `test-basic-setup.sh`
Tests that v2 deployment and nginx are working correctly.

**Usage:**
```bash
./test-basic-setup.sh
```

**What it tests:**
- Direct access to Registry v2
- Access through nginx
- Artifact creation
- Artifact retrieval
- Search functionality

---

## Migration Step Scripts

### Step A: Deploy Registry v2

#### `step-A-deploy-v2.sh`
Deploys Apicurio Registry 2.6.x with PostgreSQL.

**What it does:**
1. Starts PostgreSQL container
2. Starts Registry v2 container
3. Waits for health checks
4. Verifies system info
5. Collects initial logs

**Usage:**
```bash
./step-A-deploy-v2.sh
```

**Output:**
- Log: `logs/step-A-deploy-v2.log`
- Container logs: `logs/containers/postgres-v2-initial.log`, `logs/containers/registry-v2-initial.log`

**Verify:**
```bash
curl http://localhost:8080/apis/registry/v2/system/info | jq .
```

---

### Step B: Deploy Nginx

#### `step-B-deploy-nginx.sh`
Deploys nginx load balancer configured to route to Registry v2.

**What it does:**
1. Verifies Registry v2 is running
2. Starts nginx container
3. Waits for nginx health check
4. Verifies registry is accessible through nginx

**Usage:**
```bash
./step-B-deploy-nginx.sh
```

**Prerequisites:**
- Step A must be completed first

**Output:**
- Log: `logs/step-B-deploy-nginx.log`
- Container logs: `logs/containers/nginx-initial.log`

**Verify:**
```bash
curl http://localhost:9090/nginx-health
curl http://localhost:9090/apis/registry/v2/system/info | jq .
```

---

## Typical Workflow

### Quick Test (Infrastructure Only)

```bash
# Clean start
./cleanup.sh --volumes

# Deploy v2 and nginx
./step-A-deploy-v2.sh
./step-B-deploy-nginx.sh

# Test setup
./test-basic-setup.sh

# Cleanup when done
./cleanup.sh
```

### View Logs

```bash
# Step logs
cat ../logs/step-A-deploy-v2.log
cat ../logs/step-B-deploy-nginx.log

# Container logs
docker logs scenario1-postgres-v2
docker logs scenario1-registry-v2
docker logs scenario1-nginx

# Or collected logs
cat ../logs/containers/registry-v2-initial.log
```

### Check Container Status

```bash
# List all scenario1 containers
docker ps -a | grep scenario1

# Check health
docker ps --format "table {{.Names}}\t{{.Status}}"

# Detailed inspect
docker inspect scenario1-registry-v2 | jq '.[0].State'
```

## Script Development Guidelines

When creating new step scripts:

1. **Follow the naming convention**: `step-X-description.sh` where X is A-L
2. **Use consistent logging**: All output to both console and log file
3. **Create log directory**: `mkdir -p "$PROJECT_DIR/logs"`
4. **Use absolute paths**: Use `$SCRIPT_DIR` and `$PROJECT_DIR` variables
5. **Check prerequisites**: Verify previous steps completed
6. **Collect logs**: Save container logs at key points
7. **Provide clear output**: Use echo statements to show progress
8. **Exit on error**: Use `set -e` at the start
9. **Return success/failure**: Use proper exit codes

**Template:**
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/step-X-description.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step X: Description" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"

# Your script logic here

echo "✅ Step X completed successfully" | tee -a "$LOG_FILE"
```

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 8080
lsof -i :8080
# Or
netstat -tulpn | grep 8080

# Kill the process or change ports in docker-compose-v2.yml
```

### Container Won't Start

```bash
# Check logs
docker logs scenario1-registry-v2

# Check if previous container is still running
docker ps -a | grep scenario1

# Force cleanup
./cleanup.sh --volumes
```

### Permission Denied

```bash
# Make scripts executable
chmod +x *.sh

# Check Docker permissions
docker ps  # Should work without sudo
```

### Network Issues

```bash
# List networks
docker network ls | grep scenario1

# Inspect network
docker network inspect scenario1-v2-network

# Recreate network
docker network rm scenario1-v2-network
docker network create scenario1-v2-network
```

## Next Steps

To continue implementation:
1. ✅ v2 deployment and nginx are complete
2. ⏭️ Next: Implement v3 deployment (docker-compose-v3.yml)
3. ⏭️ Next: Implement Java client applications
4. ⏭️ Next: Implement remaining step scripts (C through L)
