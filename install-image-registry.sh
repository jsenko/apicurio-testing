#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

usage() {
    echo "Usage: $0 [--cluster <cluster-name>]"
    echo ""
    echo "Optional Parameters:"
    echo "  --cluster <cluster-name>    Name of the cluster to configure (default: $USER)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Uses default cluster ($USER) and Docker config"
    echo "  $0 --cluster okd419       # Uses specific cluster"
    exit 1
}

cleanup() {
  rm -rf "$DOCKER_CONFIG"
}

CLUSTER_NAME="$USER"

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
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

load_cluster_config "$CLUSTER_NAME"

export PASSWORD=$(tr -cd [:graph:] < /dev/urandom | head -c10)
echo "$PASSWORD" > "$CLUSTER_DIR/image-registry-admin-password"
export PASSWORD_ENCODED=$(htpasswd -Bbn admin "$PASSWORD" | base64 -w 0)

kubectl get namespace infra >/dev/null 2>&1 || kubectl create namespace infra
cat "$BASE_DIR/templates/image-registry/install.yaml" | envsubst | kubectl apply -n infra -f -
success "Image registry has been installed in the 'infra' namespace. Admin password stored in $CLUSTER_DIR/image-registry-admin-password ."
kubectl delete pod -l app=image-registry -n infra >/dev/null 2>&1 || true

export DOCKER_CONFIG="$CLUSTER_DIR/.docker"
REGISTRY_HOST=$(kubectl -n infra get route image-registry -o jsonpath='{.spec.host}')
if wait_for "docker login" 180 docker login -u admin -p "$PASSWORD" "$REGISTRY_HOST"; then
  ./update-pull-secret.sh --cluster "$CLUSTER_NAME" --docker-config "$DOCKER_CONFIG"
  cleanup
  success_exit "Pull secret has been updated to use the image registry at $REGISTRY_HOST ."
else
  cleanup
  error_exit "Failed to login to the image registry at $REGISTRY_HOST."
fi
