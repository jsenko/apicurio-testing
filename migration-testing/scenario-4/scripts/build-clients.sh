#!/bin/bash

# Build Java Client Applications
#
# This script builds all Java applications:
# 1. artifact-creator
# 2. artifact-validator-v2
# 3. artifact-validator-v3
# 4. kafka-producer-v2
# 5. kafka-consumer-v2
# 6. kafka-producer-v3
# 7. kafka-consumer-v3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="$PROJECT_DIR/clients"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/build-clients.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Building Java Client Applications" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check for Maven
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven is not installed or not in PATH" | tee -a "$LOG_FILE"
    echo "   Please install Maven: https://maven.apache.org/install.html" | tee -a "$LOG_FILE"
    exit 1
fi

MAVEN_VERSION=$(mvn -version | head -n 1)
echo "Maven: $MAVEN_VERSION" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Build artifact-creator
echo "[1/7] Building artifact-creator..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/artifact-creator"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ artifact-creator built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "artifact-creator-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ artifact-creator build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build artifact-validator-v2
echo "[2/7] Building artifact-validator-v2..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/artifact-validator-v2"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ artifact-validator-v2 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "artifact-validator-v2-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ artifact-validator-v2 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build artifact-validator-v3
echo "[3/7] Building artifact-validator-v3..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/artifact-validator-v3"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ artifact-validator-v3 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "artifact-validator-v3-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ artifact-validator-v3 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build kafka-producer-v2
echo "[4/7] Building kafka-producer-v2..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/kafka-producer-v2"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ kafka-producer-v2 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "kafka-producer-v2-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ kafka-producer-v2 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build kafka-consumer-v2
echo "[5/7] Building kafka-consumer-v2..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/kafka-consumer-v2"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ kafka-consumer-v2 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "kafka-consumer-v2-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ kafka-consumer-v2 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build kafka-producer-v3
echo "[6/7] Building kafka-producer-v3..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/kafka-producer-v3"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ kafka-producer-v3 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "kafka-producer-v3-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ kafka-producer-v3 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Build kafka-consumer-v3
echo "[7/7] Building kafka-consumer-v3..." | tee -a "$LOG_FILE"
cd "$CLIENTS_DIR/kafka-consumer-v3"
mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"
MVN_EXIT_CODE=${PIPESTATUS[0]}

if [ $MVN_EXIT_CODE -eq 0 ]; then
    echo "  ✓ kafka-consumer-v3 built successfully" | tee -a "$LOG_FILE"
    JAR_FILE=$(find target -name "kafka-consumer-v3-*.jar" -not -name "*sources.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "    JAR: $JAR_FILE ($JAR_SIZE)" | tee -a "$LOG_FILE"
    fi
else
    echo "  ✗ kafka-consumer-v3 build failed with exit code $MVN_EXIT_CODE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ All clients built successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry Clients:" | tee -a "$LOG_FILE"
echo "  - artifact-creator" | tee -a "$LOG_FILE"
echo "  - artifact-validator-v2" | tee -a "$LOG_FILE"
echo "  - artifact-validator-v3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Kafka Clients:" | tee -a "$LOG_FILE"
echo "  - kafka-producer-v2" | tee -a "$LOG_FILE"
echo "  - kafka-consumer-v2" | tee -a "$LOG_FILE"
echo "  - kafka-producer-v3" | tee -a "$LOG_FILE"
echo "  - kafka-consumer-v3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Build log: $LOG_FILE" | tee -a "$LOG_FILE"
