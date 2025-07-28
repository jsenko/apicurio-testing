#!/bin/bash

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ##################################################
# Function to display usage information
# ##################################################
show_usage() {
    echo "Usage: $0 --cluster <cluster_name> --namespace <namespace> --keycloakVersion <version> [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  --cluster <name>         Name of the OpenShift cluster where Keycloak will be installed"
    echo "  --namespace <namespace>  Kubernetes namespace to deploy Keycloak into"
    echo "  --keycloakVersion <ver>  Version of Keycloak to install (e.g., 26.3.1, 25.0.0)"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  --realmName <realm>      Name of the realm to create (default: 'registry')"
    echo "  -h, --help               Display this help message and exit"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic installation:"
    echo "  $0 --cluster okd419 --namespace keycloak-ns --keycloakVersion 26.3.1"
    echo ""
    echo "NOTES:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - The script will create a ConfigMap with a pre-configured realm"
    echo "  - Keycloak will be accessible via OpenShift Route with TLS termination"
}


# ##################################################
# Function to poll a Keycloak health endpoint until 
# it becomes ready.
# ##################################################
wait_for_keycloak_health() {
    local url="$1"
    local timeout="${2:-600}"  # Default timeout of 10 minutes (600 seconds)
    local interval="${3:-5}"   # Default polling interval of 5 seconds
    
    echo "Polling Keycloak health endpoint: $url"
    echo "Timeout: ${timeout}s, Polling interval: ${interval}s"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    # Initial wait period
    echo "Waiting 30 seconds before starting health endpoint polling..."
    sleep 30
    
    while [ $(date +%s) -lt $end_time ]; do
        # Use curl to get the response from the health endpoint
        local response=$(curl -sL --max-time 10 "$url" 2>/dev/null)
        local curl_exit_code=$?
        
        # Check if curl succeeded and we got a response
        if [ $curl_exit_code -eq 0 ] && [ -n "$response" ]; then
            # For Keycloak health endpoint, check if we get a 200 response with "UP" status
            local status=$(echo "$response" | jq -r '.status // empty' 2>/dev/null)
            
            if [ "$status" = "UP" ]; then
                echo "Keycloak health endpoint is ready! Status: UP"
                return 0
            else
                # If no JSON status, check if we get any successful response (some Keycloak versions return plain text)
                if echo "$response" | grep -q "UP\|ready\|healthy" 2>/dev/null; then
                    echo "Keycloak health endpoint is ready!"
                    return 0
                else
                    echo "Keycloak health endpoint responded but status is not ready, waiting ${interval}s..."
                fi
            fi
        else
            echo "Keycloak health endpoint not reachable yet, waiting ${interval}s..."
        fi
        
        sleep $interval
    done
    
    echo "ERROR: Keycloak health endpoint did not become ready within ${timeout} seconds"
    return 1
}


# ##################################################
# Function to output debugging information when 
# application fails to become ready
# ##################################################
output_debug_info() {
    local namespace="$1"
    
    echo ""
    echo "=========================================="
    echo "DEBUGGING INFORMATION"
    echo "=========================================="
    echo ""
    
    echo "==================== DEPLOYMENTS ===================="
    kubectl get deployments -n "$namespace" -o wide || echo "Failed to get deployments"
    echo ""
    kubectl describe deployments -n "$namespace" || echo "Failed to describe deployments"
    echo ""
    
    echo "==================== PODS ===================="
    kubectl get pods -n "$namespace" -o wide || echo "Failed to get pods"
    echo ""
    kubectl describe pods -n "$namespace" || echo "Failed to describe pods"
    echo ""
    
    echo "==================== SERVICES ===================="
    kubectl get services -n "$namespace" -o wide || echo "Failed to get services"
    echo ""
    kubectl describe services -n "$namespace" || echo "Failed to describe services"
    echo ""
    
    echo "==================== ROUTES ===================="
    kubectl get routes -n "$namespace" -o wide 2>/dev/null || echo "No routes found or routes not supported"
    echo ""
    kubectl describe routes -n "$namespace" 2>/dev/null || echo "No routes found or routes not supported"
    echo ""
    
    echo "==================== CONFIGMAPS ===================="
    kubectl get configmaps -n "$namespace" -o wide || echo "Failed to get configmaps"
    echo ""
    kubectl describe configmaps -n "$namespace" || echo "Failed to describe configmaps"
    echo ""
    
    echo "==================== EVENTS ===================="
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' || echo "Failed to get events"
    echo ""
    
    echo "==================== POD LOGS ===================="
    # Get logs from all pods in the namespace
    local pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$pods" ]; then
        for pod in $pods; do
            echo "--- Logs for pod: $pod ---"
            kubectl logs "$pod" -n "$namespace" --tail=50 2>/dev/null || echo "Failed to get logs for pod $pod"
            echo ""
        done
    else
        echo "No pods found in namespace $namespace"
    fi
    
    echo "=========================================="
    echo "END DEBUGGING INFORMATION"
    echo "=========================================="
    echo ""
}

wait_for_keycloak_cr_ready() {
    local namespace="$1"
    local elapsed=0
    local interval=10
    local timeout="${3:-600}"  # 10 minutes default
    
    while [ $elapsed -lt $timeout ]; do
        # Check if Keycloak CR exists
        if ! kubectl get keycloak keycloak-instance -n "$namespace" &>/dev/null; then
            echo "Keycloak instance not found in namespace '$namespace'"
            return 1
        fi
        
        # Get the status conditions
        local ready_status=$(kubectl get keycloak keycloak-instance -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        local ready_reason=$(kubectl get keycloak keycloak-instance -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$ready_status" = "True" ]; then
            echo "Keycloak instance is ready!"
            
            # Display connection info
            local keycloak_url=$(kubectl get keycloak keycloak-instance -n "$namespace" -o jsonpath='{.status.hostname}' 2>/dev/null || echo "Not available")
            echo "Keycloak URL: https://$keycloak_url"
            
            return 0
        elif [ "$ready_status" = "False" ]; then
            echo "Keycloak not ready yet. Reason: $ready_reason (${elapsed}s/${timeout}s)"
        else
            echo "Keycloak status unknown, still initializing... (${elapsed}s/${timeout}s)"
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo "Timeout waiting for Keycloak to be ready"
    return 1
}

# Parse command line arguments
APPLICATION_NAME="keycloak"
CLUSTER_NAME=""
NAMESPACE=""
KEYCLOAK_VERSION=""
REALM_NAME=""

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
        --keycloakVersion)
            KEYCLOAK_VERSION="$2"
            shift 2
            ;;
        --realmName)
            REALM_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done


if [ -z "$REALM_NAME" ]; then
    REALM_NAME="registry"
    echo "No realm name specified, using default: $REALM_NAME"
fi

# Check if required arguments are provided
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --cluster argument is required"
    show_usage
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    show_usage
    exit 1
fi

if [ -z "$KEYCLOAK_VERSION" ]; then
    echo "Error: --keycloakVersion argument is required"
    show_usage
    exit 1
fi

# Validate namespace contains only letters and numbers
if [[ ! "$NAMESPACE" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Namespace '$NAMESPACE' is invalid. It must contain only letters and numbers."
    show_usage
    exit 1
fi

# Export environment variables
export APPLICATION_NAME
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export CERT_DIR="$BASE_DIR/certificates"
export NAMESPACE
export KEYCLOAK_VERSION
export REALM_NAME
export BASE_DOMAIN="apicurio-testing.org"
export APPS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/apps"
export APP_DIR="$APPS_DIR/$APPLICATION_NAME"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export KEYCLOAK_INGRESS_URL="keycloak-$NAMESPACE.$APPS_URL"
export KEYCLOAK_HEALTH_URL="keycloak-health-$NAMESPACE.$APPS_URL"

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

mkdir -p $APP_DIR

cd $CLUSTER_DIR

# Set up kubectl auth
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig

# Create the namespace if it doesn't exist
echo "Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace '$NAMESPACE' already exists, skipping creation"
else
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Check if version-specific templates exist
KEYCLOAK_TEMPLATE_DIR="$BASE_DIR/templates/keycloak/$KEYCLOAK_VERSION"
if [ ! -d "$KEYCLOAK_TEMPLATE_DIR" ]; then
    echo "Error: Templates for Keycloak version '$KEYCLOAK_VERSION' not found at '$KEYCLOAK_TEMPLATE_DIR'"
    echo "Available versions:"
    ls -1 "$BASE_DIR/templates/keycloak" 2>/dev/null || echo "No Keycloak templates found"
    exit 1
fi

# Install all YAML files from the Keycloak template directory
echo "Installing all Keycloak YAML files from template directory..."
for template_file in "$KEYCLOAK_TEMPLATE_DIR"/*.yaml; do
    if [ -f "$template_file" ]; then
        # Get the filename without the path
        filename=$(basename "$template_file")
        echo "Processing template: $filename"
        
        # Create the processed file in the app directory
        processed_file="$APP_DIR/$filename"
        envsubst < "$template_file" > "$processed_file"
        kubectl apply -f "$processed_file" -n $NAMESPACE
    fi
done

# Wait for the Keycloak health endpoint to be ready
wait_for_keycloak_cr_ready $NAMESPACE

# Get Admin Username/password for Keycloak
KC_ADMIN_USER=$(kubectl get secret keycloak-instance-initial-admin -n $NAMESPACE -o jsonpath='{.data.username}' | base64 --decode)
KC_ADMIN_PASS=$(kubectl get secret keycloak-instance-initial-admin -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)

# Keycloak is up!
echo "Keycloak is up and running!"
echo ""
echo "You can access Keycloak here:"
echo "    Keycloak Console:   https://$KEYCLOAK_INGRESS_URL"
echo ""
echo "Admin Credentials:"
echo "    Admin User:         $KC_ADMIN_USER"
echo "    Admin Password:     $KC_ADMIN_PASS"
echo ""
echo "Realm: $REALM_NAME"
echo ""
