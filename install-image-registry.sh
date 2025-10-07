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

export PASSWORD=$(tr -cd [:alnum:] < /dev/urandom | head -c10)

export PASSWORD_ENCODED=$(htpasswd -Bbn admin "$PASSWORD" | base64 -w 0)

kubectl get namespace infra >/dev/null 2>&1 || kubectl create namespace infra

if wait_for "infra namespace" 30 kubectl get namespace infra; then
  success "Infra namespace is ready."
else
  error_exit "Failed to create the infra namespace."
fi

oc create serviceaccount infra-privileged -n infra || true
oc adm policy add-scc-to-user privileged -z infra-privileged -n infra || true

# Allow the default service account to use the privileged SCC
# kubectl create rolebinding privileged-scc-default --clusterrole=system:openshift:scc:privileged --serviceaccount=default:default -n infra

cat "$BASE_DIR/templates/image-registry/install.yaml" | envsubst | kubectl apply -n infra -f -

kubectl delete pod -l app=image-registry -n infra >/dev/null 2>&1 || true

export DOCKER_CONFIG="$CLUSTER_DIR/.docker"

REGISTRY_HOST=$(kubectl -n infra get route image-registry -o jsonpath='{.spec.host}')

echo "docker login -u \"admin\" -p \"$PASSWORD\" \"$REGISTRY_HOST\"" > "$CLUSTER_DIR/image-registry-login"

rm "$CLUSTER_DIR/image-registry-env" || true
echo "export IMAGE_REGISTRY_HOST=\"$REGISTRY_HOST\"" >> "$CLUSTER_DIR/image-registry-env"
echo "export IMAGE_REGISTRY_USER=\"admin\"" >> "$CLUSTER_DIR/image-registry-env"
echo "export IMAGE_REGISTRY_PASSWORD=\"$PASSWORD\"" >> "$CLUSTER_DIR/image-registry-env"

if wait_for "docker login" 180 docker login -u admin -p "$PASSWORD" "$REGISTRY_HOST"; then
  ./update-pull-secret.sh --cluster "$CLUSTER_NAME" --docker-config "$DOCKER_CONFIG"
  cleanup
  success_exit "Pull secret has been updated to use the image registry at $REGISTRY_HOST ."
else
  cleanup
  error_exit "Failed to login to the image registry at $REGISTRY_HOST."
fi
