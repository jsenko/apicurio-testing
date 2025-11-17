#!/bin/bash

# Run All Steps - Scenario 2
#
# This script runs all migration steps in sequence from A to N.
# It demonstrates the complete migration process from v2 to v3.
#
# Usage:
#   ./run-scenario-2.sh                 # Run all steps without pauses
#   ./run-scenario-2.sh --interactive   # Run all steps with pauses

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Create log directory
mkdir -p "$LOG_DIR"

MASTER_LOG="$LOG_DIR/run-scenario-2.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$MASTER_LOG"
}

# Parse arguments
PAUSE_BETWEEN_STEPS=false
if [[ "$1" == "--interactive" ]]; then
    PAUSE_BETWEEN_STEPS=true
fi

# Function to pause between steps
pause_step() {
    if [ "$PAUSE_BETWEEN_STEPS" = true ]; then
        log ""
        log "Press Enter to continue to next step..."
        read -r
    else
        sleep 2
    fi
}

log "================================================================"
log "  Scenario 2: Apicurio Registry Migration Testing"
log "  Kafka-based Migration (v2 → v3)"
log "================================================================"
log ""
log "This script will run all migration steps:"
log "  A. Deploy Kafka"
log "  B. Deploy Registry v2"
log "  C. Deploy Nginx"
log "  D. Run Producer v2"
log "  E. Run Consumer v2"
log "  F. Prepare Migration"
log "  G. Export v2 Data"
log "  H. Deploy Registry v3"
log "  I. Import v3 Data"
log "  J. Switch Nginx to v3"
log "  K. Run Producer v2 on v3 (backward compatibility)"
log "  L. Run Consumer v2 on v3 (backward compatibility)"
log "  M. Run Producer v3"
log "  N. Run Consumer v3"
log ""
log "Master log: $MASTER_LOG"
log ""

if [ "$PAUSE_BETWEEN_STEPS" = true ]; then
    log "Press Enter to start..."
    read -r
else
    log "Running in automatic mode"
    sleep 2
fi

# Step A: Deploy Kafka
log ""
log "================================================================"
log "  STEP A: Deploy Kafka"
log "================================================================"
"$SCRIPTS_DIR/step-A-deploy-kafka.sh"
pause_step

# Step B: Deploy Registry v2
log ""
log "================================================================"
log "  STEP B: Deploy Registry v2"
log "================================================================"
"$SCRIPTS_DIR/step-B-deploy-v2-kafka.sh"
pause_step

# Step C: Deploy Nginx
log ""
log "================================================================"
log "  STEP C: Deploy Nginx"
log "================================================================"
"$SCRIPTS_DIR/step-C-deploy-nginx.sh"
pause_step

# Build clients before running them
log ""
log "================================================================"
log "  Building Kafka Clients"
log "================================================================"
"$SCRIPTS_DIR/build-clients.sh"
pause_step

# Step D: Run Producer v2
log ""
log "================================================================"
log "  STEP D: Run Producer v2"
log "================================================================"
"$SCRIPTS_DIR/step-D-run-producer-v2.sh"
pause_step

# Step E: Run Consumer v2
log ""
log "================================================================"
log "  STEP E: Run Consumer v2"
log "================================================================"
"$SCRIPTS_DIR/step-E-run-consumer-v2.sh"
pause_step

# Step F: Prepare Migration
log ""
log "================================================================"
log "  STEP F: Prepare Migration"
log "================================================================"
"$SCRIPTS_DIR/step-F-prepare-migration.sh"
pause_step

# Step G: Export v2 Data
log ""
log "================================================================"
log "  STEP G: Export v2 Data"
log "================================================================"
"$SCRIPTS_DIR/step-G-export-v2-data.sh"
pause_step

# Step H: Deploy Registry v3
log ""
log "================================================================"
log "  STEP H: Deploy Registry v3"
log "================================================================"
"$SCRIPTS_DIR/step-H-deploy-v3-kafka.sh"
pause_step

# Step I: Import v3 Data
log ""
log "================================================================"
log "  STEP I: Import v3 Data"
log "================================================================"
"$SCRIPTS_DIR/step-I-import-v3-data.sh"
pause_step

# Step J: Switch Nginx to v3
log ""
log "================================================================"
log "  STEP J: Switch Nginx to v3"
log "================================================================"
"$SCRIPTS_DIR/step-J-switch-nginx-to-v3.sh"
pause_step

# Step K: Run Producer v2 on v3
log ""
log "================================================================"
log "  STEP K: Run Producer v2 on v3"
log "================================================================"
"$SCRIPTS_DIR/step-K-run-producer-v2-on-v3.sh"
pause_step

# Step L: Run Consumer v2 on v3
log ""
log "================================================================"
log "  STEP L: Run Consumer v2 on v3"
log "================================================================"
"$SCRIPTS_DIR/step-L-run-consumer-v2-on-v3.sh"
pause_step

# Step M: Run Producer v3
log ""
log "================================================================"
log "  STEP M: Run Producer v3"
log "================================================================"
"$SCRIPTS_DIR/step-M-run-producer-v3.sh"
pause_step

# Step N: Run Consumer v3
log ""
log "================================================================"
log "  STEP N: Run Consumer v3"
log "================================================================"
"$SCRIPTS_DIR/step-N-run-consumer-v3.sh"

# Final summary
log ""
log "================================================================"
log "  ✅ ALL STEPS COMPLETED SUCCESSFULLY"
log "================================================================"
log ""
log "Migration Summary:"
log "  ✓ Kafka cluster deployed"
log "  ✓ Registry v2 deployed and tested"
log "  ✓ Data exported from v2"
log "  ✓ Registry v3 deployed"
log "  ✓ Data imported to v3"
log "  ✓ Nginx switched to v3"
log "  ✓ Backward compatibility verified (v2 clients with v3 registry)"
log "  ✓ Forward compatibility verified (v3 clients with v3 registry)"
log ""
log "Total messages in topic: 30"
log "  - 10 from step D (v2 producer → v2 registry)"
log "  - 10 from step K (v2 producer → v3 registry)"
log "  - 10 from step M (v3 producer → v3 registry)"
log ""
log "All logs saved to: $LOG_DIR"
log "Master log: $MASTER_LOG"
log ""
log "To clean up:"
log "  ./scripts/step-O-cleanup.sh"
log "  ./scripts/step-O-cleanup.sh --remove-volumes --remove-data"
log ""
