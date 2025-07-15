#!/bin/bash

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAILABLE_PROFILES=$(ls -1 "$BASE_DIR/templates/profiles" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')

# ##################################################
# Function to display usage information
# ##################################################
show_usage() {
    echo "Usage: $0 --clusterName <cluster_name> --namespace <namespace> --version <registry_version> [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  --clusterName <name>     Name of the OpenShift cluster where Apicurio Registry will be installed"
    echo "  --namespace <namespace>  Kubernetes namespace to deploy Apicurio Registry into"
    echo "  --version <version>      Version of Apicurio Registry to install (e.g., 3.0.9)"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  --appName <name>         Name of the application deployment (default: 'registry')"
    echo "  --profile <profile>      Profile to use for Apicurio Registry (default: 'inmemory')"
    echo "                           Available profiles: $AVAILABLE_PROFILES"
    echo "  --strimziVersion <ver>   Version of Strimzi Kafka operator to install (optional)"
    echo "                           Only needed for profiles that require Kafka (e.g., kafkasql)"
    echo "  -h, --help               Display this help message and exit"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic installation with inmemory profile:"
    echo "  $0 --clusterName okd419 --namespace simplens1 --version 3.0.9"
    echo ""
    echo "  # Installation with custom app name and kafkasql profile:"
    echo "  $0 --appName my-registry --clusterName okd419 --namespace kafkans1 --version 3.0.9 --profile kafkasql --strimziVersion 0.43.0"
    echo ""
    echo "  # Installation with PostgreSQL profile:"
    echo "  $0 --clusterName okd419 --namespace pgns1 --version 3.0.9 --profile postgresql"
    echo ""
    echo "NOTES:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - Different profiles provide different storage backends and dependencies (e.g. Keycloak)"
    echo "  - Strimzi version is only required when using Kafka-based profiles"
}


# ##################################################
# Function to kubectl apply -f on every file in a
# particular folder.
# ##################################################
apply_all_yaml_files() {
  local yaml_dir="$1"
  local namespace="$2"

  if [[ -z "$yaml_dir" || ! -d "$yaml_dir" ]]; then
    echo "Error: '$yaml_dir' is not a valid directory"
    return 1
  fi

  if [[ -z "$namespace" ]]; then
    echo "Error: namespace parameter is required"
    return 1
  fi

  # Build a list of files sorted by filename only
  mapfile -t yaml_files < <(find "$yaml_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) \
    -exec bash -c 'for f; do echo "$(basename "$f")|$f"; done' _ {} + | \
    sort -t '|' -k1,1 | cut -d '|' -f2)

  for yaml_file in "${yaml_files[@]}"; do
    echo "Applying: $yaml_file (with namespace: $namespace)"
    kubectl apply -f <(sed "s/myproject/$namespace/g" "$yaml_file") -n $NAMESPACE
  done
}


# ##################################################
# Function to poll a Microprofile Health readiness 
# endpoint until it becomes UP.
# ##################################################
wait_for_health_endpoint() {
    local url="$1"
    local timeout="${2:-600}"  # Default timeout of 10 minutes (600 seconds)
    local interval="${3:-5}"   # Default polling interval of 5 seconds
    
    echo "Polling health endpoint: $url"
    echo "Timeout: ${timeout}s, Polling interval: ${interval}s"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    # Initial wait period
    echo "Waiting 60 seconds before starting health endpoint polling..."
    sleep 60
    
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



# Parse command line arguments
APPLICATION_NAME=""
CLUSTER_NAME=""
NAMESPACE=""
APICURIO_REGISTRY_VERSION=""
PROFILE=""
STRIMZI_VERSION=""

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
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --strimziVersion)
            STRIMZI_VERSION="$2"
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

# Set default application name if not provided
if [ -z "$APPLICATION_NAME" ]; then
    APPLICATION_NAME="registry"
    echo "No application name specified, using default: $APPLICATION_NAME"
fi

# Check if required arguments are provided
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --clusterName argument is required"
    show_usage
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    show_usage
    exit 1
fi

if [ -z "$APICURIO_REGISTRY_VERSION" ]; then
    echo "Error: --version argument is required"
    show_usage
    exit 1
fi

# Set default profile if not provided
if [ -z "$PROFILE" ]; then
    PROFILE="inmemory"
    echo "No profile specified, using default: $PROFILE"
fi

# Validate profile
if [ ! -d "$BASE_DIR/templates/profiles/$PROFILE" ]; then
    echo "Error: Invalid profile '$PROFILE'. Available profiles: $AVAILABLE_PROFILES"
    show_usage
    exit 1
fi


export APPLICATION_NAME
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export CERT_DIR="$BASE_DIR/certificates"
export APICURIO_REGISTRY_VERSION
export NAMESPACE
export PROFILE
export STRIMZI_VERSION
export BASE_DOMAIN="apicurio-testing.org"
export APPS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/apps"
export APP_DIR="$APPS_DIR/$APPLICATION_NAME"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export APP_INGRESS_URL="registry-app.$NAMESPACE.$APPS_URL"
export UI_INGRESS_URL="registry-ui.$NAMESPACE.$APPS_URL"
export APICURIO_OPERATOR_URL="https://raw.githubusercontent.com/Apicurio/apicurio-registry/refs/heads/main/operator/install/apicurio-registry-operator-$APICURIO_REGISTRY_VERSION.yaml"

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

# Load SSL certificates (may be needed by profile)
export CERT_PRIVKEY=$(sed 's/^/      /' $CERT_DIR/privkey.pem)
export CERT_FULL_CHAIN=$(sed 's/^/      /' $CERT_DIR/fullchain.pem)


mkdir -p $APP_DIR

cd $CLUSTER_DIR

# Set up kubectl auth
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig

# Create the test namespace
echo "Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE

# Deploy Strimzi operator if strimziVersion is specified
if [ -n "$STRIMZI_VERSION" ]; then
    echo "Installing Strimzi Operator version: $STRIMZI_VERSION"
    STRIMZI_OPERATOR_URL="https://github.com/strimzi/strimzi-kafka-operator/releases/download/$STRIMZI_VERSION/strimzi-$STRIMZI_VERSION.zip"
    echo "Downloading Strimzi Operator ZIP from: $STRIMZI_OPERATOR_URL"
    curl -sSL -o $APP_DIR/strimzi-$STRIMZI_VERSION.zip $STRIMZI_OPERATOR_URL
    echo "Unpacking Strimzi operator ZIP"
    unzip $APP_DIR/strimzi-$STRIMZI_VERSION.zip -d $APP_DIR
    echo "Installing Strimzi Operator into namespace $NAMESPACE"
    apply_all_yaml_files $APP_DIR/strimzi-$STRIMZI_VERSION/install/strimzi-admin $NAMESPACE
    apply_all_yaml_files $APP_DIR/strimzi-$STRIMZI_VERSION/install/cluster-operator $NAMESPACE
#    apply_all_yaml_files $APP_DIR/strimzi-$STRIMZI_VERSION/install/topic-operator $NAMESPACE
#    apply_all_yaml_files $APP_DIR/strimzi-$STRIMZI_VERSION/install/user-operator $NAMESPACE
else
    echo "No Strimzi version specified, skipping Strimzi operator installation"
fi

# Deploy the Apicurio Registry operator to the namespace
echo "Downloading Apicurio Registry Operator YAML from: $APICURIO_OPERATOR_URL"
curl -sSL $APICURIO_OPERATOR_URL | sed "s/PLACEHOLDER_NAMESPACE/$NAMESPACE/g" > $APP_DIR/apicurio-registry-operator.yaml
echo "Installing Apicurio Registry Operator into namespace $NAMESPACE"
kubectl apply -f $APP_DIR/apicurio-registry-operator.yaml -n $NAMESPACE

# Deploy profile-specific resources
echo "Using profile: $PROFILE"
PROFILE_DIR="$BASE_DIR/templates/profiles/$PROFILE"
YAML_FILES=$(find "$PROFILE_DIR" -name "*.yaml" -o -name "*.yml" | sort)
if [ -n "$YAML_FILES" ]; then
    echo "$YAML_FILES" | while read -r YAML_FILE; do
        YAML_FILE_NAME=$(basename "$YAML_FILE")
        FROM_TEMPLATE="$YAML_FILE"
        TO_CLUSTER=$APP_DIR/$YAML_FILE_NAME
        echo "Applying configuration from: $FROM_TEMPLATE"
        envsubst < $FROM_TEMPLATE > $TO_CLUSTER
        kubectl apply -f $TO_CLUSTER -n $NAMESPACE
    done
else
    echo "ERROR: No YAML files found in profile directory!"
    exit 1
fi

# Wait for the health endpoint to be ready
echo "Waiting for Apicurio Registry health endpoint to be ready..."
HEALTH_URL="http://$APP_INGRESS_URL/health/ready"
wait_for_health_endpoint "$HEALTH_URL"
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
