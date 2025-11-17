#!/bin/bash

# Cleanup Script - Stop and remove all containers
#
# This script:
# 1. Stops and removes all scenario 1 containers
# 2. Optionally removes volumes (data will be lost)
# 3. Removes networks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

REMOVE_VOLUMES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove volumes (data will be lost)"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "================================================================"
echo "  Cleanup: Stopping and removing all containers"
echo "================================================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/4] Collecting final container logs..."
mkdir -p logs/containers
if docker ps -a | grep -q scenario3-postgres-v2; then
    docker logs scenario3-postgres-v2 > logs/containers/postgres-v2-final.log 2>&1 || true
fi
if docker ps -a | grep -q scenario3-registry-v2; then
    docker logs scenario3-registry-v2 > logs/containers/registry-v2-final.log 2>&1 || true
fi
if docker ps -a | grep -q scenario3-postgres-v3; then
    docker logs scenario3-postgres-v3 > logs/containers/postgres-v3-final.log 2>&1 || true
fi
if docker ps -a | grep -q scenario3-registry-v3; then
    docker logs scenario3-registry-v3 > logs/containers/registry-v3-final.log 2>&1 || true
fi
if docker ps -a | grep -q scenario3-nginx; then
    docker logs scenario3-nginx > logs/containers/nginx-final.log 2>&1 || true
fi

echo "[2/4] Stopping containers..."

# Stop nginx first
if [ -f docker-compose-nginx-v2.yml ]; then
    docker compose -f docker-compose-nginx-v2.yml down 2>/dev/null || true
fi
if [ -f docker-compose-nginx-v3.yml ]; then
    docker compose -f docker-compose-nginx-v3.yml down 2>/dev/null || true
fi

# Stop v3 (if exists)
if [ -f docker-compose-v3.yml ]; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        docker compose -f docker-compose-v3.yml down -v
    else
        docker compose -f docker-compose-v3.yml down
    fi
fi

# Stop v2
if [ -f docker-compose-v2.yml ]; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        docker compose -f docker-compose-v2.yml down -v
    else
        docker compose -f docker-compose-v2.yml down
    fi
fi

echo "[3/4] Removing any orphaned containers..."
docker ps -a | grep scenario3- | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

echo "[4/4] Cleaning up networks..."
docker network rm scenario3-v2-network 2>/dev/null || true
docker network rm scenario3-v3-network 2>/dev/null || true

echo ""
if [ "$REMOVE_VOLUMES" = true ]; then
    echo "✅ Cleanup complete (volumes removed - data lost)"
    echo ""
    echo "Volumes removed:"
    echo "  - scenario3-postgres-v2-data"
    echo "  - scenario3-postgres-v3-data"
else
    echo "✅ Cleanup complete (volumes preserved)"
    echo ""
    echo "Volumes preserved (to remove, run: $0 --volumes):"
    docker volume ls | grep scenario3 || echo "  (no volumes found)"
fi

echo ""
echo "Logs preserved in:"
echo "  - logs/"
echo "  - logs/containers/"
echo ""
echo "To completely reset, run:"
echo "  $0 --volumes"
echo "  rm -rf logs/ data/"
