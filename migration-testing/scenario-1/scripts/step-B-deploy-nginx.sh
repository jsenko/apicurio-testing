#!/bin/bash

# Step B: Deploy Nginx Load Balancer
#
# This script:
# 1. Deploys nginx reverse proxy
# 2. Configures nginx to route to Registry v2
# 3. Verifies nginx health
# 4. Verifies registry is accessible through nginx

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-B-deploy-nginx.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step B: Deploy Nginx Load Balancer" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Navigate to project directory
cd "$PROJECT_DIR"

# Verify v2 is running
echo "[0/4] Verifying Registry v2 is running..." | tee -a "$LOG_FILE"
if ! docker ps | grep -q scenario1-registry-v2; then
    echo "❌ Registry v2 container is not running" | tee -a "$LOG_FILE"
    echo "Please run step-A-deploy-v2.sh first" | tee -a "$LOG_FILE"
    exit 1
fi
echo "✅ Registry v2 is running" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[1/4] Starting nginx container..." | tee -a "$LOG_FILE"
docker compose -f docker-compose-nginx.yml up -d 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[2/4] Waiting for nginx to be healthy..." | tee -a "$LOG_FILE"
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:8080/nginx-health 30 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[3/4] Verifying nginx health endpoint..." | tee -a "$LOG_FILE"
NGINX_HEALTH=$(curl -s http://localhost:8080/nginx-health)
echo "Nginx health response: $NGINX_HEALTH" | tee -a "$LOG_FILE"

if [[ "$NGINX_HEALTH" != *"v2"* ]]; then
    echo "⚠️  Warning: nginx health doesn't indicate v2 routing" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "[4/4] Verifying registry is accessible through nginx..." | tee -a "$LOG_FILE"
SYSTEM_INFO=$(curl -s http://localhost:8080/apis/registry/v2/system/info)
echo "$SYSTEM_INFO" | jq '.' | tee -a "$LOG_FILE"

VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
echo "" | tee -a "$LOG_FILE"
echo "Registry Version (via nginx): $VERSION" | tee -a "$LOG_FILE"

# Validate version is 2.6.x
if [[ "$VERSION" != 2.6.* ]]; then
    echo "❌ Expected version 2.6.x via nginx but got $VERSION" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✅ Step B completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Nginx is running at: http://localhost:8080" | tee -a "$LOG_FILE"
echo "Currently routing to: Registry v2 (2.6.x)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Test endpoints through nginx:" | tee -a "$LOG_FILE"
echo "  curl http://localhost:8080/nginx-health" | tee -a "$LOG_FILE"
echo "  curl http://localhost:8080/apis/registry/v2/system/info" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Container logs:" | tee -a "$LOG_FILE"
echo "  docker logs scenario1-nginx" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Collect nginx logs
echo "Collecting nginx logs..." | tee -a "$LOG_FILE"
docker logs scenario1-nginx > "$PROJECT_DIR/logs/containers/nginx-initial.log" 2>&1

echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/nginx-initial.log" | tee -a "$LOG_FILE"
