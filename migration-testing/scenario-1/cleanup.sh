#!/bin/bash

# Cleanup Script for Migration Testing Scenario 1
#
# This script stops all containers and optionally removes volumes
# to prepare for a fresh test run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================"
echo "  Cleanup - Migration Testing Scenario 1"
echo "================================================================"
echo ""

# Stop and remove all containers
echo "[1/3] Stopping and removing containers..."

if [ -f docker-compose-v2.yml ]; then
    echo "  Stopping v2 deployment..."
    docker compose -f docker-compose-v2.yml down 2>/dev/null || true
fi

if [ -f docker-compose-v3.yml ]; then
    echo "  Stopping v3 deployment..."
    docker compose -f docker-compose-v3.yml down 2>/dev/null || true
fi

if [ -f docker-compose-nginx.yml ]; then
    echo "  Stopping nginx..."
    docker compose -f docker-compose-nginx.yml down 2>/dev/null || true
fi

echo "  ✓ All containers stopped"
echo ""

# Ask about volumes
echo "[2/3] Docker volumes:"
echo ""
docker volume ls | grep -E "scenario-1|postgres-v2|postgres-v3" || echo "  No scenario-1 volumes found"
echo ""

read -p "Remove all volumes? This will delete all data (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Removing volumes..."
    docker volume ls -q | grep -E "scenario-1|postgres-v2|postgres-v3" | xargs -r docker volume rm 2>/dev/null || true
    echo "  ✓ Volumes removed"
else
    echo "  Volumes preserved"
fi

echo ""

# Clean up generated files
echo "[3/3] Cleaning up generated files..."

read -p "Remove logs and data directories? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Removing logs..."
    rm -rf logs/
    echo "  Removing data files..."
    rm -rf data/
    echo "  ✓ Generated files removed"
else
    echo "  Logs and data preserved"
fi

echo ""
echo "================================================================"
echo "  ✓ Cleanup completed"
echo "================================================================"
echo ""
echo "You can now run: ./run-all-steps.sh"
echo ""
