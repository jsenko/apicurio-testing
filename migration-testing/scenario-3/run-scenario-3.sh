#!/bin/bash

# Automated Migration Testing - Scenario 3
#
# This script runs all migration steps in sequence:
# A. Deploy Apicurio Registry v2 with PostgreSQL
# B. Deploy nginx reverse proxy
# C. Create test data (25 artifacts, 76 versions)
# D. Validate pre-migration state
# E. Prepare for migration (pause)
# F. Export data from v2 registry
# G. Deploy Apicurio Registry v3 with PostgreSQL
# H. Import data into v3 registry
# I. Switch nginx routing from v2 to v3
# J. Validate post-migration state (v2 client - backward compatibility test)
# K. Validate v3 registry (v3 native client)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create logs directory
mkdir -p logs

MASTER_LOG="logs/run-scenario-3.log"
START_TIME=$(date +%s)

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    GREEN=''
    RED=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Step tracking
declare -a STEPS=(
    "A:Deploy Apicurio Registry v2"
    "B:Deploy nginx reverse proxy"
    "C:Create test data"
    "D:Validate pre-migration state"
    "E:Prepare for migration"
    "F:Export v2 data"
    "G:Deploy Apicurio Registry v3"
    "H:Import v3 data"
    "I:Switch nginx to v3"
    "J:Validate post-migration (v2 client)"
    "K:Validate v3 native (v3 client)"
)

declare -a STEP_RESULTS=()
declare -a STEP_TIMES=()

echo "================================================================" | tee "$MASTER_LOG"
echo "  Apicurio Registry Migration Testing - Scenario 3" | tee -a "$MASTER_LOG"
echo "================================================================" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"
echo "This script will run all migration steps automatically." | tee -a "$MASTER_LOG"
echo "Started at: $(date)" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# Function to run a step
run_step() {
    local step_letter="$1"
    local step_name="$2"
    local script_name="scripts/step-${step_letter}-*.sh"

    # Find the actual script file
    local script_file=$(ls $script_name 2>/dev/null | head -n 1)

    if [ -z "$script_file" ]; then
        echo -e "${RED}✗ Script not found: $script_name${NC}" | tee -a "$MASTER_LOG"
        STEP_RESULTS+=("FAILED")
        STEP_TIMES+=("0")
        return 1
    fi

    echo "" | tee -a "$MASTER_LOG"
    echo "================================================================" | tee -a "$MASTER_LOG"
    echo -e "${BLUE}Running Step $step_letter: $step_name${NC}" | tee -a "$MASTER_LOG"
    echo "================================================================" | tee -a "$MASTER_LOG"

    local step_start=$(date +%s)

    if bash "$script_file" 2>&1 | tee -a "$MASTER_LOG"; then
        local step_end=$(date +%s)
        local duration=$((step_end - step_start))
        echo -e "${GREEN}✓ Step $step_letter completed successfully (${duration}s)${NC}" | tee -a "$MASTER_LOG"
        STEP_RESULTS+=("PASSED")
        STEP_TIMES+=("$duration")
        return 0
    else
        local step_end=$(date +%s)
        local duration=$((step_end - step_start))
        echo -e "${RED}✗ Step $step_letter failed (${duration}s)${NC}" | tee -a "$MASTER_LOG"
        STEP_RESULTS+=("FAILED")
        STEP_TIMES+=("$duration")
        return 1
    fi
}

# Run all steps
FAILED_STEP=""
for step_info in "${STEPS[@]}"; do
    step_letter="${step_info%%:*}"
    step_name="${step_info#*:}"

    if ! run_step "$step_letter" "$step_name"; then
        FAILED_STEP="$step_letter"
        break
    fi
done

# Calculate total time
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

# Print summary
echo "" | tee -a "$MASTER_LOG"
echo "================================================================" | tee -a "$MASTER_LOG"
echo "  Migration Test Summary" | tee -a "$MASTER_LOG"
echo "================================================================" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# Print step results
for i in "${!STEPS[@]}"; do
    step_info="${STEPS[$i]}"
    step_letter="${step_info%%:*}"
    step_name="${step_info#*:}"
    result="${STEP_RESULTS[$i]}"
    duration="${STEP_TIMES[$i]}"

    if [ "$result" == "PASSED" ]; then
        echo -e "  ${GREEN}✓${NC} Step $step_letter: $step_name (${duration}s)" | tee -a "$MASTER_LOG"
    elif [ "$result" == "FAILED" ]; then
        echo -e "  ${RED}✗${NC} Step $step_letter: $step_name (${duration}s)" | tee -a "$MASTER_LOG"
    else
        echo -e "  ${YELLOW}-${NC} Step $step_letter: $step_name (not run)" | tee -a "$MASTER_LOG"
    fi
done

echo "" | tee -a "$MASTER_LOG"
echo "Total time: ${MINUTES}m ${SECONDS}s" | tee -a "$MASTER_LOG"
echo "Completed at: $(date)" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# Final status
if [ -z "$FAILED_STEP" ]; then
    echo "================================================================" | tee -a "$MASTER_LOG"
    echo -e "${GREEN}  ✓ ALL MIGRATION STEPS COMPLETED SUCCESSFULLY${NC}" | tee -a "$MASTER_LOG"
    echo "================================================================" | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    echo "Migration test completed successfully!" | tee -a "$MASTER_LOG"
    echo "All data has been migrated from v2 to v3 and validated." | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    echo "Key validation results:" | tee -a "$MASTER_LOG"
    echo "  - Pre-migration:  data/validation-report-pre-migration.txt" | tee -a "$MASTER_LOG"
    echo "  - Post-migration: data/validation-report-post-migration.txt" | tee -a "$MASTER_LOG"
    echo "  - V3 native:      data/validation-report-v3-native.txt" | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    echo "Master log: $MASTER_LOG" | tee -a "$MASTER_LOG"
    exit 0
else
    echo "================================================================" | tee -a "$MASTER_LOG"
    echo -e "${RED}  ✗ MIGRATION FAILED AT STEP $FAILED_STEP${NC}" | tee -a "$MASTER_LOG"
    echo "================================================================" | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    echo "Migration test failed. Check the logs for details." | tee -a "$MASTER_LOG"
    echo "Master log: $MASTER_LOG" | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    echo "To clean up and retry, you may need to:" | tee -a "$MASTER_LOG"
    echo "  1. Stop all containers: docker compose -f docker-compose-*.yml down" | tee -a "$MASTER_LOG"
    echo "  2. Remove volumes: docker volume prune" | tee -a "$MASTER_LOG"
    echo "  3. Run this script again" | tee -a "$MASTER_LOG"
    exit 1
fi
