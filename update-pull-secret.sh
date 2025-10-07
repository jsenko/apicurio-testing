#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

warning "This script will add *ALL* authenticated registries from the Docker config to the OpenShift global pull secret."

usage() {
    echo "Usage: $0 [--cluster <cluster-name>] [--docker-config <path>] [--keep-config]"
    echo ""
    echo "Optional Parameters:"
    echo "  --cluster <cluster-name>    Name of the cluster to configure (default: $USER)"
    echo "  --docker-config <path>      Path to Docker config directory (default: $HOME/.docker)"
    echo "  --keep-config               Keep intermediate configuration files for debugging"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Uses default cluster ($USER) and Docker config"
    echo "  $0 --cluster okd419       # Uses specific cluster"
    echo "  $0 --docker-config /path/to/.docker  # Uses specific Docker config"
    echo "  $0 --keep-config          # Keep intermediate files for debugging"
    echo ""
    echo "Notes:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    exit 1
}

cleanup() {
  if [[ "$KEEP_CONFIG" = true ]]; then
    important "Configuration files are kept in $CLUSTER_DIR:\n- $PULL_SECRET\n- $PULL_SECRET_DOCKER_CONFIG\n- $PULL_SECRET_DOCKER_CONFIG_UPDATED\n- $PULL_SECRET_UPDATED"
  else
    rm -f "$PULL_SECRET" "$PULL_SECRET_DOCKER_CONFIG" "$PULL_SECRET_DOCKER_CONFIG_UPDATED" "$PULL_SECRET_UPDATED"
  fi
}

CLUSTER_NAME="$USER"
SOURCE_DOCKER_CONFIG="$HOME/.docker"
KEEP_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --docker-config)
            SOURCE_DOCKER_CONFIG="$2"
            shift 2
            ;;
        --keep-config)
            KEEP_CONFIG=true
            shift
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

load_cluster_config "$CLUSTER_NAME"

PULL_SECRET="$CLUSTER_DIR/pull-secret.json"
PULL_SECRET_DOCKER_CONFIG="$CLUSTER_DIR/pull-secret-docker-config.json"
PULL_SECRET_DOCKER_CONFIG_UPDATED="$CLUSTER_DIR/pull-secret-docker-config-updated.json"
PULL_SECRET_UPDATED="$CLUSTER_DIR/pull-secret-updated.json"

kubectl get secret pull-secret -n openshift-config -o json > "$PULL_SECRET"

jq -r '.data[".dockerconfigjson"]' < "$PULL_SECRET" | base64 -d > "$PULL_SECRET_DOCKER_CONFIG"

jq -s 'reduce .[] as $item ({}; .auths += ($item.auths // {}))' "$PULL_SECRET_DOCKER_CONFIG" "$SOURCE_DOCKER_CONFIG/config.json" > "$PULL_SECRET_DOCKER_CONFIG_UPDATED"

jq --arg config_updated "$(base64 -w0 "$PULL_SECRET_DOCKER_CONFIG_UPDATED")" \
  '.data.".dockerconfigjson" = $config_updated' \
  "$PULL_SECRET" > "$PULL_SECRET_UPDATED"

if kubectl replace -f "$PULL_SECRET_UPDATED"; then
    cleanup
    success "Global pull secret updated successfully."
else
    cleanup
    error_exit "Failed to update global pull secret."
fi
