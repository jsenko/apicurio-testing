#!/bin/bash

# Script to generate Let's Encrypt TLS certificates using certbot in OpenShift
# Usage: ./generate-tls-cert.sh [--cluster <cluster-name>] [OPTIONS]

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secrets.env if it exists
if [[ -f "$BASE_DIR/secrets.env" ]]; then
    echo "Sourcing environment variables from secrets.env..."
    source "$BASE_DIR/secrets.env"
fi

# Function to validate required environment variables
validate_env_vars() {
    local missing_vars=()
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
        missing_vars+=("AWS_ACCESS_KEY_ID")
    fi
    
    if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        missing_vars+=("AWS_SECRET_ACCESS_KEY")
    fi
    
    if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
        missing_vars+=("AWS_DEFAULT_REGION")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "Error: The following required environment variables are not set:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please set these environment variables before running the script."
        echo "These are needed for Route53 DNS challenge validation."
        exit 1
    fi
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 [--cluster <cluster_name>] [OPTIONS]"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  --cluster <name>         Name of the OpenShift cluster to use for certificate generation (default: \$USER)"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  --domain <domain>        Domain to generate certificate for (default: '*.apps.<cluster_name>.apicurio-testing.org')"
    echo "  --email <email>          Email address for Let's Encrypt registration (default: 'ewittman@ibm.com')"
    echo "  --outputDir <dir>        Local directory to save certificates (default: './certificates')"
    echo "  --namespace <namespace>  Kubernetes namespace to use for certbot pod (default: 'certbot')"
    echo "  -h, --help               Display this help message and exit"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic usage with defaults:"
    echo "  $0                        # Uses default cluster (\$USER)"
    echo "  $0 --cluster okd419       # Uses specific cluster"
    echo ""
    echo "  # Custom domain and email:"
    echo "  $0 --cluster okd419 --domain '*.apps.mycompany.org' --email 'admin@mycompany.org'"
    echo ""
    echo "  # Save to specific directory:"
    echo "  $0 --cluster okd419 --outputDir ./certificates"
    echo ""
    echo "NOTES:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - AWS credentials must be set for Route53 DNS challenge"
    echo "  - The domain must be managed by Route53 in your AWS account"
    echo "  - Generated certificates will be valid for 90 days (Let's Encrypt standard)"
}

# Function to cleanup resources
cleanup_resources() {
    local namespace="$1"
    
    echo "Cleaning up temporary resources..."
    
    # Delete the certbot pod if it exists
    kubectl delete pod certbot-pod -n "$namespace" --ignore-not-found=true
    
    # Delete the AWS credentials secret if it exists
    kubectl delete secret aws-credentials -n "$namespace" --ignore-not-found=true
    
    # Delete the namespace if we created it
    if [[ "$CREATED_NAMESPACE" == "true" ]]; then
        kubectl delete namespace "$namespace" --ignore-not-found=true
    fi
}

# Function to wait for pod to be ready
wait_for_pod_ready() {
    local pod_name="$1"
    local namespace="$2"
    local timeout="${3:-300}"  # Default timeout of 5 minutes
    
    echo "Waiting for pod $pod_name to be ready..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        local pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
        
        if [[ "$pod_status" == "Running" ]]; then
            # Check if container is ready
            local ready=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
            if [[ "$ready" == "true" ]]; then
                echo "Pod $pod_name is ready!"
                return 0
            fi
        elif [[ "$pod_status" == "Failed" ]] || [[ "$pod_status" == "Error" ]]; then
            echo "ERROR: Pod $pod_name failed to start"
            kubectl describe pod "$pod_name" -n "$namespace"
            return 1
        fi
        
        echo "Pod status: $pod_status, waiting..."
        sleep 5
    done
    
    echo "ERROR: Pod $pod_name did not become ready within ${timeout} seconds"
    kubectl describe pod "$pod_name" -n "$namespace"
    return 1
}

# Function to extract certificates from pod
extract_certificates() {
    local pod_name="$1"
    local namespace="$2"
    local domain="$3"
    local output_dir="$4"
    
    echo "Extracting certificates from pod..."
    
    # The domain path in letsencrypt is the domain without wildcards
    local domain_path=$(echo "$domain" | sed 's/\*\.//g')
    local cert_path="/etc/letsencrypt/live/$domain_path"
    
    # Try to copy files directly first
    echo "Certificate files located in: $cert_path"
    echo "Attempting to copy certificate files to $output_dir..."
    
    local success=true
    
    # Try to copy each file
    echo "Copying from $namespace/$pod_name:$cert_path/privkey.pem to $output_dir/privkey.pem"
    if ! kubectl exec -n "$namespace" "$pod_name" -- cat "$cert_path/privkey.pem" > "$output_dir/privkey.pem" 2>/dev/null; then
        echo "Failed to copy privkey.pem directly, trying alternative method..."
        success=false
    fi
    
    echo "Copying from $namespace/$pod_name:$cert_path/fullchain.pem to $output_dir/fullchain.pem"
    if ! kubectl exec -n "$namespace" "$pod_name" -- cat "$cert_path/fullchain.pem" > "$output_dir/fullchain.pem" 2>/dev/null; then
        echo "Failed to copy fullchain.pem directly, trying alternative method..."
        success=false
    fi
    
    if [[ "$success" == "true" ]]; then
        echo "Successfully copied certificate files to $output_dir"
        # Set appropriate permissions
        chmod 600 "$output_dir/privkey.pem"
        chmod 644 "$output_dir/fullchain.pem"
        return 0
    fi
    
    # Fallback: output as base64 encoded strings
    echo ""
    echo "File copying failed. Outputting certificates as base64 encoded strings:"
    echo ""
    return 1
}

# Parse command line arguments
CLUSTER_NAME="$USER"
DOMAIN=""  # Will be set after CLUSTER_NAME is parsed
EMAIL="ewittman@ibm.com"
OUTPUT_DIR="./certificates"
NAMESPACE="certbot"

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --outputDir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
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

# Validate cluster name (should not be empty after defaulting to $USER)
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: cluster name is empty (default: \$USER)"
    show_usage
    exit 1
fi

# Set default domain if not provided
if [ -z "$DOMAIN" ]; then
    DOMAIN="*.apps.$CLUSTER_NAME.apicurio-testing.org"
fi

# Validate required environment variables
validate_env_vars

# Set up environment variables
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export DOMAIN
export EMAIL
export NAMESPACE
export CREATED_NAMESPACE="false"

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

# Resolve output directory to absolute path and include cluster subdirectory
CERT_DIR="$OUTPUT_DIR/$CLUSTER_NAME"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Convert CERT_DIR to absolute path
CERT_DIR=$(cd "$OUTPUT_DIR/$CLUSTER_NAME" && pwd)

# Check if certificate already exists and is still valid (less than 60 days old)
PRIVKEY_FILE="$CERT_DIR/privkey.pem"
if [ -f "$PRIVKEY_FILE" ]; then
    # Get the creation/modification time of the file in seconds since epoch
    if command -v stat >/dev/null 2>&1; then
        # Use stat command (works on most Linux systems)
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            FILE_TIME=$(stat -c %Y "$PRIVKEY_FILE" 2>/dev/null)
        else
            # BSD stat (macOS)
            FILE_TIME=$(stat -f %m "$PRIVKEY_FILE" 2>/dev/null)
        fi
    else
        FILE_TIME=""
    fi
    
    if [ -n "$FILE_TIME" ]; then
        CURRENT_TIME=$(date +%s)
        SIXTY_DAYS_IN_SECONDS=$((60 * 24 * 60 * 60))  # 60 days * 24 hours * 60 minutes * 60 seconds
        AGE_IN_SECONDS=$((CURRENT_TIME - FILE_TIME))
        
        if [ $AGE_IN_SECONDS -lt $SIXTY_DAYS_IN_SECONDS ]; then
            DAYS_OLD=$((AGE_IN_SECONDS / 86400))  # Convert seconds to days
            echo "Certificate already exists and is only $DAYS_OLD days old (less than 60 days)."
            echo "Certificate location: $PRIVKEY_FILE"
            echo "Skipping certificate generation. Use --domain flag to generate for a different domain."
            exit 0
        else
            DAYS_OLD=$((AGE_IN_SECONDS / 86400))
            echo "Existing certificate is $DAYS_OLD days old (more than 60 days). Generating new certificate..."
        fi
    else
        echo "Warning: Could not determine age of existing certificate. Proceeding with generation..."
    fi
fi

cd "$CLUSTER_DIR"

# Set up kubectl auth
export KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"

echo "Generating Let's Encrypt TLS certificate using certbot"
echo "Cluster: $CLUSTER_NAME"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Output Directory: $CERT_DIR"
echo "Namespace: $NAMESPACE"
echo ""

# Set up cleanup trap
trap 'cleanup_resources "$NAMESPACE"' EXIT

# Create or ensure namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    export CREATED_NAMESPACE="true"
else
    echo "Using existing namespace: $NAMESPACE"
fi

# Create AWS credentials secret
echo "Creating AWS credentials secret..."
kubectl create secret generic aws-credentials \
    --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    --from-literal=AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
    -n "$NAMESPACE"

# Create certbot pod
echo "Creating certbot pod..."
CERTBOT_POD_TEMPLATE="$BASE_DIR/templates/certbot-pod.yaml"
CERTBOT_POD_FILE="$CLUSTER_DIR/certbot-pod.yaml"
envsubst < "$CERTBOT_POD_TEMPLATE" > "$CERTBOT_POD_FILE"
kubectl apply -f "$CERTBOT_POD_FILE" -n "$NAMESPACE"

# Wait for pod to be ready
if ! wait_for_pod_ready "certbot-pod" "$NAMESPACE"; then
    echo "ERROR: Failed to start certbot pod"
    exit 1
fi

# Run certbot command
echo "Running certbot to generate certificate for domain: $DOMAIN"
CERTBOT_CMD="certbot certonly --dns-route53 -d \"$DOMAIN\" --agree-tos --email \"$EMAIL\" --non-interactive"
echo "Executing: $CERTBOT_CMD"

if kubectl exec certbot-pod -n "$NAMESPACE" -- sh -c "$CERTBOT_CMD"; then
    echo "Certbot completed successfully!"
    
    # Extract certificates
    if extract_certificates "certbot-pod" "$NAMESPACE" "$DOMAIN" "$CERT_DIR"; then
        echo ""
        echo "SUCCESS: TLS certificates have been generated and saved to: $CERT_DIR"
        echo ""
        echo "Generated files:"
        echo "  - cert.pem      (certificate)"
        echo "  - privkey.pem   (private key)"
        echo "  - fullchain.pem (certificate + intermediate chain)"
        echo ""
        echo "These certificates are valid for 90 days."
    else
        echo ""
        echo "Certificates were generated but could not be copied to local filesystem."
        exit 1
    fi
else
    echo "ERROR: Certbot failed to generate certificate"
    echo "Pod logs:"
    kubectl logs certbot-pod -n "$NAMESPACE"
    exit 1
fi
