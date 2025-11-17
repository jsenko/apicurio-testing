#!/bin/bash

# Step A: Deploy Keycloak with TLS
#
# This script:
# 1. Deploys Keycloak with pre-configured realm and TLS/HTTPS enabled
# 2. Imports users, roles, and client configurations
# 3. Verifies Keycloak is ready for OIDC authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/step-A-deploy-keycloak.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step A: Deploy Keycloak" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Change to project directory
cd "$PROJECT_DIR"

# Deploy Keycloak
echo "[1/4] Deploying Keycloak..." | tee -a "$LOG_FILE"
docker compose -f docker-compose-keycloak.yml up -d 2>&1 | tee -a "$LOG_FILE"

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Keycloak" | tee -a "$LOG_FILE"
    exit 1
fi

echo "  ✓ Keycloak container started" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Wait for Keycloak to be healthy
echo "[2/4] Waiting for Keycloak to be ready..." | tee -a "$LOG_FILE"

MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -k -f -s https://localhost:9443/health/ready > /dev/null 2>&1; then
        echo "  ✓ Keycloak is healthy" | tee -a "$LOG_FILE"
        break
    fi
    echo "  Waiting for Keycloak... (${ELAPSED}s/${MAX_WAIT}s)" | tee -a "$LOG_FILE"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "  ✗ Keycloak failed to become ready within ${MAX_WAIT}s" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Verify realm is imported
echo "[3/4] Verifying realm import..." | tee -a "$LOG_FILE"

REALM_CHECK=$(curl -k -s "https://localhost:9443/realms/registry" | grep -o "registry" || echo "")
if [ -z "$REALM_CHECK" ]; then
    echo "  ✗ Registry realm not found" | tee -a "$LOG_FILE"
    exit 1
fi

echo "  ✓ Registry realm imported successfully" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Display configuration
echo "[4/4] Keycloak configuration:" | tee -a "$LOG_FILE"
echo "  Keycloak URL:        https://localhost:9443" | tee -a "$LOG_FILE"
echo "  Admin Console:       https://localhost:9443/admin" | tee -a "$LOG_FILE"
echo "  Admin Username:      admin" | tee -a "$LOG_FILE"
echo "  Admin Password:      admin" | tee -a "$LOG_FILE"
echo "  Realm:               registry" | tee -a "$LOG_FILE"
echo "  Realm URL:           https://localhost:9443/realms/registry" | tee -a "$LOG_FILE"
echo "  TLS:                 Enabled (self-signed certificate)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "  Pre-configured users:" | tee -a "$LOG_FILE"
echo "    admin/admin       (sr-admin role)" | tee -a "$LOG_FILE"
echo "    developer/developer (sr-developer role)" | tee -a "$LOG_FILE"
echo "    user/user         (sr-readonly role)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ Step A completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Keycloak is running and ready for authentication" | tee -a "$LOG_FILE"
echo "Container: scenario4-keycloak" | tee -a "$LOG_FILE"
echo "Log:       $LOG_FILE" | tee -a "$LOG_FILE"
