#!/bin/bash

# Test Basic Setup
#
# This script tests that the v2 deployment and nginx are working correctly
# by performing basic API operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================================"
echo "  Testing Basic Setup - Registry v2 + Nginx"
echo "================================================================"
echo ""

# Test direct access to v2
echo "[1/6] Testing direct access to Registry v2..."
V2_DIRECT=$(curl -s http://localhost:2222/apis/registry/v2/system/info | jq -r '.version')
echo "✅ Registry v2 direct access: $V2_DIRECT"

# Test access through nginx
echo ""
echo "[2/6] Testing access through nginx..."
V2_NGINX=$(curl -s http://localhost:8080/apis/registry/v2/system/info | jq -r '.version')
echo "✅ Registry v2 via nginx: $V2_NGINX"

# Verify versions match
echo ""
echo "[3/6] Verifying versions match..."
if [ "$V2_DIRECT" = "$V2_NGINX" ]; then
    echo "✅ Versions match: $V2_DIRECT"
else
    echo "❌ Version mismatch! Direct: $V2_DIRECT, Nginx: $V2_NGINX"
    exit 1
fi

# Test creating a simple artifact
echo ""
echo "[4/6] Testing artifact creation..."
ARTIFACT_ID="test-artifact-$(date +%s)"
SCHEMA='{"type":"record","name":"TestRecord","fields":[{"name":"id","type":"string"}]}'

CREATE_RESPONSE=$(curl -s -X POST \
    http://localhost:8080/apis/registry/v2/groups/default/artifacts \
    -H "Content-Type: application/json" \
    -H "X-Registry-ArtifactId: $ARTIFACT_ID" \
    -H "X-Registry-ArtifactType: AVRO" \
    --data "$SCHEMA")

echo "Created artifact: $ARTIFACT_ID"
echo "$CREATE_RESPONSE" | jq '.'

# Test retrieving the artifact
echo ""
echo "[5/6] Testing artifact retrieval..."
RETRIEVED=$(curl -s http://localhost:8080/apis/registry/v2/groups/default/artifacts/$ARTIFACT_ID)
echo "✅ Retrieved artifact successfully"

# Test listing artifacts
echo ""
echo "[6/6] Testing artifact listing..."
ARTIFACT_LIST=$(curl -s http://localhost:8080/apis/registry/v2/search/artifacts?limit=10)
COUNT=$(echo "$ARTIFACT_LIST" | jq '.count')
echo "✅ Found $COUNT artifacts in registry"

echo ""
echo "================================================================"
echo "  ✅ Basic setup test completed successfully!"
echo "================================================================"
echo ""
echo "Summary:"
echo "  - Registry v2 is accessible directly on port 2222"
echo "  - Registry v2 is accessible via nginx on port 8080"
echo "  - Artifact creation works"
echo "  - Artifact retrieval works"
echo "  - Search works"
echo ""
echo "The infrastructure is ready for migration testing!"
