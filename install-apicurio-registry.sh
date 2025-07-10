#!/bin/bash

# Parse command line arguments
APPLICATION_NAME=""
CLUSTER_NAME=""
NAMESPACE=""
APICURIO_REGISTRY_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --appName)
            APPLICATION_NAME="$2"
            shift 2
            ;;
        --clusterName)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --version)
            APICURIO_REGISTRY_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
            echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$APPLICATION_NAME" ]; then
    echo "Error: --appName argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --clusterName argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$APICURIO_REGISTRY_VERSION" ]; then
    echo "Error: --version argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi


# Function to poll a Microprofile Health readiness endpoint
wait_for_health_endpoint() {
    local url="$1"
    local timeout="${2:-600}"  # Default timeout of 10 minutes (600 seconds)
    local interval="${3:-5}"   # Default polling interval of 5 seconds
    
    echo "Polling health endpoint: $url"
    echo "Timeout: ${timeout}s, Polling interval: ${interval}s"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Use curl to get the JSON response from the health endpoint
        local response=$(curl -s --max-time 10 "$url" 2>/dev/null)
        local curl_exit_code=$?
        
        # Check if curl succeeded and we got a response
        if [ $curl_exit_code -eq 0 ] && [ -n "$response" ]; then
            # Parse JSON to check if status is "UP" using jq
            local status=$(echo "$response" | jq -r '.status // empty' 2>/dev/null)
            
            if [ "$status" = "UP" ]; then
                echo "Health endpoint is ready! Status: UP"
                return 0
            else
                echo "Health endpoint responded but status is not UP (status: $status), waiting ${interval}s..."
            fi
        else
            echo "Health endpoint not reachable yet, waiting ${interval}s..."
        fi
        
        sleep $interval
    done
    
    echo "ERROR: Health endpoint did not become ready within ${timeout} seconds"
    return 1
}

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export APPLICATION_NAME
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export APICURIO_REGISTRY_VERSION
export NAMESPACE
export BASE_DOMAIN="apicurio-testing.org"
export APPS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/apps"
export APP_DIR="$APPS_DIR/$APPLICATION_NAME"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export APP_INGRESS_URL="registry-app.$NAMESPACE.$APPS_URL"
export UI_INGRESS_URL="registry-ui.$NAMESPACE.$APPS_URL"
export APICURIO_OPERATOR_URL="https://raw.githubusercontent.com/Apicurio/apicurio-registry/refs/heads/main/operator/install/apicurio-registry-operator-$APICURIO_REGISTRY_VERSION.yaml"

mkdir -p $APP_DIR

cd $CLUSTER_DIR

# Set up kubectl auth
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig

# Create the test namespace
echo "Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE

# Deploy the operator to the namespace
echo "Downloading Apicurio Registry Operator YAML from: $APICURIO_OPERATOR_URL"
curl -sSL $APICURIO_OPERATOR_URL | sed "s/PLACEHOLDER_NAMESPACE/$NAMESPACE/g" > $APP_DIR/apicurio-registry-operator.yaml
echo "Installing Apicurio Registry Operator into namespace $NAMESPACE"
kubectl apply -f $APP_DIR/apicurio-registry-operator.yaml -n $NAMESPACE

# Create the application custom resource (deploys the Registry app)
echo "Creating the Apicurio Registry instance CR"
envsubst < $BASE_DIR/templates/apicurio-registry/in-memory.yaml > $APP_DIR/apicurio-registry.yaml
kubectl apply -f $APP_DIR/apicurio-registry.yaml -n $NAMESPACE

# Wait for the application to be available (max 10 mins)
# echo "Waiting for Apicurio Registry instance to start..."
# kubectl wait --for=condition=Ready apicurioregistry3/$APPLICATION_NAME --namespace $NAMESPACE --timeout=600s
# if [[ $? -ne 0 ]]; then
#   echo ""
#   echo "--"
#   echo "ERROR: Apicurio Registry instance did not become ready in time."
#   echo "--"
#   exit 1
# fi

# Wait for the health endpoint to be ready
echo "Waiting for Apicurio Registry health endpoint to be ready..."
HEALTH_URL="http://$APP_INGRESS_URL/health/ready"
wait_for_health_endpoint "$HEALTH_URL" 300 5
if [[ $? -ne 0 ]]; then
  echo ""
  echo "--"
  echo "ERROR: Apicurio Registry health endpoint did not become ready in time."
  echo "--"
  exit 1
fi

# Apicurio Registry is up!
echo "Apicurio Registry is up!"
echo ""
echo "You can access the application here:"
echo "    User Interface: http://$UI_INGRESS_URL"
echo "    REST API:       http://$APP_INGRESS_URL"
echo ""
