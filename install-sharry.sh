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

export POSTGRESQL_PASSWORD=$(tr -cd [:alnum:] < /dev/urandom | head -c10)
export PASSWORD=$(tr -cd [:alnum:] < /dev/urandom | head -c10)

kubectl get namespace infra >/dev/null 2>&1 || kubectl create namespace infra

if wait_for "infra namespace" 30 kubectl get namespace infra; then
  success "Infra namespace is ready."
else
  error_exit "Failed to create the infra namespace."
fi

oc create serviceaccount infra-privileged -n infra || true
oc adm policy add-scc-to-user privileged -z infra-privileged -n infra || true

# Allow the default service account to use the privileged SCC
# kubectl create rolebinding privileged-scc-default --clusterrole=system:openshift:scc:privileged --serviceaccount=default:default -n infra || true

cat "$BASE_DIR/templates/sharry/install.yaml" | envsubst | kubectl apply -n infra -f -

echo "$PASSWORD" > "$CLUSTER_DIR/sharry-admin-password"
success "Sharry has been installed in the 'infra' namespace. Admin password is stored in $CLUSTER_DIR/sharry-admin-password ."

important "Waiting for Sharry to be ready (this may take a few minutes)..."
if kubectl wait --for=condition=ready pod -l app=sharry -n infra --timeout=180s; then
  success "Sharry is ready."
else
  error_exit "Failed to wait for Sharry to be ready."
fi

HOST=$(kubectl -n infra get route sharry -o jsonpath='{.spec.host}')

TOKEN=$(curl -s -d "{\"account\":\"admin\", \"password\":\"$PASSWORD\"}" "https://$HOST/api/v2/open/auth/login" | jq -r .token)
SHARE_ID=$(curl -s -X POST -H "Sharry-Auth: $TOKEN" -d '{"name":"default","validity":2592000000,"description":"Default","maxViews":999999999,"password":null}' "https://$HOST/api/v2/sec/upload/new" | jq -r .id)
# Publish
curl -s -X POST -H "Sharry-Auth: $TOKEN" -d '{"reuseId":true}' "https://$HOST/api/v2/sec/share/$SHARE_ID/publish" >/dev/null 2>&1
READ_ID=$(curl -s -H "Sharry-Auth: $TOKEN" "https://sharry-infra.apps.jsenko.apicurio-testing.org/api/v2/sec/share/$SHARE_ID" | jq -r .publishInfo.id)

rm "$CLUSTER_DIR/sharry-env" || true
echo "export SHARRY_ADMIN_PASSWORD=\"$PASSWORD\"" >> "$CLUSTER_DIR/sharry-env"
echo "export SHARRY_HOST=\"https://$HOST\"" >> "$CLUSTER_DIR/sharry-env"
echo "export SHARRY_SHARE_ID=\"$SHARE_ID\"" >> "$CLUSTER_DIR/sharry-env"
echo "export SHARRY_SHARE_URL=\"https://$HOST/app/upload/$SHARE_ID\"" >> "$CLUSTER_DIR/sharry-env"
echo "export SHARRY_READ_ID=\"$READ_ID" >> "$CLUSTER_DIR/sharry-env"
echo "export SHARRY_READ_URL=\"https://$HOST/app/open/$READ_ID\"" >> "$CLUSTER_DIR/sharry-env"
