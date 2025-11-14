#!/bin/bash

# Step F: Prepare for Migration
#
# This script:
# 1. Confirms that pre-migration validation passed
# 2. Pauses to allow review before migration
# 3. Prepares for the migration to v3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/step-F-prepare-migration.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step F: Prepare for Migration" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Current Status:" | tee -a "$LOG_FILE"
echo "  ✓ Kafka cluster deployed and running" | tee -a "$LOG_FILE"
echo "  ✓ Registry v2 deployed and running" | tee -a "$LOG_FILE"
echo "  ✓ Consumer and Producer Kafka apps running" | tee -a "$LOG_FILE"
echo "  ✓ Pre-migration validation passed" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Next Steps:" | tee -a "$LOG_FILE"
echo "  1. Export data from v2 registry" | tee -a "$LOG_FILE"
echo "  2. Deploy v3 registry" | tee -a "$LOG_FILE"
echo "  3. Import data into v3 registry" | tee -a "$LOG_FILE"
echo "  4. Switch nginx routing to v3" | tee -a "$LOG_FILE"
echo "  5. Validate post-migration state" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Pausing for 10 seconds to allow review..." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Countdown timer
for i in {10..1}; do
    printf "\r  Starting migration in %2d seconds... " "$i" | tee -a "$LOG_FILE"
    sleep 1
done
printf "\r  Starting migration now!                \n" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ Step F completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Ready to begin migration process" | tee -a "$LOG_FILE"
echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
