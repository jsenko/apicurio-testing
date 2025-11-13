#!/bin/bash

# Wait for a health endpoint to become healthy
# Usage: ./wait-for-health.sh <url> [timeout_seconds]
#
# Examples:
#   ./wait-for-health.sh http://localhost:8080/health/live
#   ./wait-for-health.sh http://localhost:8080/health/live 120

set -e

URL=$1
TIMEOUT=${2:-60}

if [ -z "$URL" ]; then
    echo "Usage: $0 <url> [timeout_seconds]"
    echo "Example: $0 http://localhost:8080/health/live 60"
    exit 1
fi

ELAPSED=0
INTERVAL=2

echo "Waiting for $URL to be healthy (timeout: ${TIMEOUT}s)..."

while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -f -s "$URL" > /dev/null 2>&1; then
        echo ""
        echo "✅ Health check passed after ${ELAPSED}s"
        exit 0
    fi

    echo -n "."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "❌ Health check failed - timeout after ${TIMEOUT}s"
echo "URL: $URL"
exit 1
