#!/bin/bash

# Parse command line arguments
CLUSTER_NAME="$USER"
NAMESPACE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--cluster <cluster_name>] --namespace <namespace>"
            echo "Example: $0 --namespace testns1"
            echo "Example: $0 --cluster okd419 --namespace testns1"
            echo ""
            echo "This script downloads logs from all running pods in the specified namespace."
            echo "Logs are saved to a 'logs' directory organized by cluster and namespace."
            echo "  --cluster <cluster_name>     Name of the cluster (default: \$USER)"
            echo "  --namespace <namespace>      Required. The namespace to download logs from"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--cluster <cluster_name>] --namespace <namespace>"
            exit 1
            ;;
    esac
done

# Validate cluster name (should not be empty after defaulting to $USER)
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: cluster name is empty (default: \$USER)"
    echo "Usage: $0 [--cluster <cluster_name>] --namespace <namespace>"
    echo "Example: $0 --namespace testns1"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    echo "Usage: $0 [--cluster <cluster_name>] --namespace <namespace>"
    echo "Example: $0 --namespace testns1"
    exit 1
fi

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export NAMESPACE
export LOGS_DIR="$BASE_DIR/logs/$CLUSTER_NAME/$NAMESPACE"

# Check if cluster directory exists
if [ ! -d "$CLUSTER_DIR" ]; then
    echo "Error: Cluster directory '$CLUSTER_DIR' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been created"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$CLUSTER_DIR/auth/kubeconfig" ]; then
    echo "Error: Kubeconfig file '$CLUSTER_DIR/auth/kubeconfig' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been properly configured"
    exit 1
fi

# Create logs directory
mkdir -p "$LOGS_DIR"

cd "$CLUSTER_DIR"

# Set up kubectl auth
export KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"

echo "Downloading pod logs from namespace '$NAMESPACE' in cluster '$CLUSTER_NAME'"
echo "Logs will be saved to: $LOGS_DIR"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'"
    exit 1
fi

# Get all running pods in the namespace
echo "Getting list of running pods in namespace '$NAMESPACE'..."
PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')

if [ -z "$PODS" ]; then
    echo "No running pods found in namespace '$NAMESPACE'"
    exit 0
fi

echo "Found running pods: $PODS"
echo ""

# Download logs for each pod
for POD in $PODS; do
    echo "Downloading logs for pod: $POD"
    
    # Get containers in the pod
    CONTAINERS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
    
    if [ -z "$CONTAINERS" ]; then
        echo "  Warning: No containers found in pod $POD"
        continue
    fi
    
    # Download logs for each container
    for CONTAINER in $CONTAINERS; do
        LOG_FILE="$LOGS_DIR/${POD}_${CONTAINER}.log"
        echo "  Downloading logs for container '$CONTAINER' to: $LOG_FILE"
        
        # Download current logs
        kubectl logs "$POD" -c "$CONTAINER" -n "$NAMESPACE" > "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "    ✓ Successfully downloaded logs for $POD/$CONTAINER"
        else
            echo "    ✗ Failed to download logs for $POD/$CONTAINER"
        fi
        
        # Also download previous logs if they exist (useful for crashed containers)
        PREV_LOG_FILE="$LOGS_DIR/${POD}_${CONTAINER}_previous.log"
        kubectl logs "$POD" -c "$CONTAINER" -n "$NAMESPACE" --previous > "$PREV_LOG_FILE" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -s "$PREV_LOG_FILE" ]; then
            echo "    ✓ Successfully downloaded previous logs for $POD/$CONTAINER"
        else
            # Remove empty previous log file
            rm -f "$PREV_LOG_FILE"
        fi
    done
    echo ""
done

echo "Log download completed!"
echo ""
echo "Logs have been saved to: $LOGS_DIR"
echo ""
echo "Summary of downloaded files:"
ls -la "$LOGS_DIR"
