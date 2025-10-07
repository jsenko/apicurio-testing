#!/bin/bash

# TODO: Not finished yet - this will install the operator using OLM v0, replacing the install file method.

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

# Function to display usage
usage() {
    echo "Usage: $0 --cluster <cluster-name> [--namespace <namespace>]"
    echo ""
    echo "Required Parameters:"
    echo "  --cluster <cluster-name>     Name of the cluster to deploy the operator to"
    echo "                               Must contain only letters and numbers"
    echo ""
    echo "Optional Parameters:"
    echo "  --namespace <namespace>      Namespace to deploy the operator to (default: openshift-marketplace)"
    echo ""
    echo "  -h, --help                   Show this help message"
    exit 1
}

# Initialize variables
CLUSTER_NAME="$USER"
NAMESPACE=""

# Parse command line arguments
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
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

export PLACEHOLDER_CATALOG_NAMESPACE="openshift-marketplace"
export PLACEHOLDER_CATALOG_IMAGE="image-registry-infra.apps.art.apicurio-testing.org/rh-osbs/iib:1234567"

load_cluster_config "$CLUSTER_NAME"

RESOURCE_DIR="$BASE_DIR/templates/registry-operator/olmv0"

cat "$RESOURCE_DIR/catalog-source.yaml" | envsubst | kubectl apply -f -
