#!/bin/bash

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

usage() {
    echo "Usage: $0 --cluster <cluster-name> --image <image>"
    echo ""
    echo "Required Parameters:"
    echo "  --cluster <cluster-name>     Name of the target cluster."
    echo "  --image <image>              Image to be installed (e.g., registry/image:tag)"
    echo ""
    echo "  -h, --help                   Show this help message"
    exit 1
}

CLUSTER_NAME="$USER"
SOURCE_IMAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --image)
            SOURCE_IMAGE="$2"
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

if [[ -z "$SOURCE_IMAGE" ]]; then
    echo "Error: --image argument is required."
    usage
fi

load_cluster_config "$CLUSTER_NAME"

# === 1. Log in to the target cluster's image registry

source "$CLUSTER_DIR/image-registry-env"

if [[ -z "$IMAGE_REGISTRY_HOST" || -z "$IMAGE_REGISTRY_PASSWORD" ]]; then
  error_exit "Image registry is not properly configured in the target cluster."
else
  success "Image registry is available at $IMAGE_REGISTRY_HOST ."
fi

if ! docker login -u "$IMAGE_REGISTRY_USER" -p "$IMAGE_REGISTRY_PASSWORD" "$IMAGE_REGISTRY_HOST"; then
  error_exit "Docker login to image registry at $IMAGE_REGISTRY_HOST failed."
fi

# === Move to our work dir

pushd "$BASE_DIR/templates/registry-operator/catalog" > /dev/null || error_exit "Failed to enter directory."

# === 2. Split the SOURCE_IMAGE into its components

# Split SOURCE_IMAGE into HOST, PATH, and TAG
SOURCE_IMAGE_HOST=""
SOURCE_IMAGE_PATH=""
SOURCE_IMAGE_TAG=""
SOURCE_IMAGE_NO_PROTO="${SOURCE_IMAGE#*://}"
SOURCE_IMAGE_HOST="${SOURCE_IMAGE_NO_PROTO%%/*}"
SOURCE_IMAGE_PATH_AND_TAG="${SOURCE_IMAGE_NO_PROTO#*/}"
if [[ "$SOURCE_IMAGE_PATH_AND_TAG" == *:* ]]; then
  SOURCE_IMAGE_TAG="${SOURCE_IMAGE_PATH_AND_TAG##*:}"
  SOURCE_IMAGE_PATH="${SOURCE_IMAGE_PATH_AND_TAG%:*}"
else
  SOURCE_IMAGE_TAG="latest"
  SOURCE_IMAGE_PATH="$SOURCE_IMAGE_PATH_AND_TAG"
fi

if [[ "$SOURCE_IMAGE_HOST" == "registry-proxy.engineering.redhat.com" ]]; then
  SOURCE_IMAGE_HOST="brew.registry.redhat.io"
fi

# Remove protocol if present
SOURCE_IMAGE="$SOURCE_IMAGE_HOST/$SOURCE_IMAGE_PATH:$SOURCE_IMAGE_TAG"

#=== 3. We need to first modify the bundle image. We have to find out it's URI.

# Copy catalog.json from the source image
TEMP_CONTAINER=$(docker create "$SOURCE_IMAGE")
if [[ -z "$TEMP_CONTAINER" ]]; then
  error_exit "Failed to create temporary container from $SOURCE_IMAGE"
fi

if ! docker cp "$TEMP_CONTAINER:/configs/apicurio-registry-3/catalog.json" ./catalog.json; then
  docker rm "$TEMP_CONTAINER" > /dev/null 2>&1
  error_exit "Failed to copy /configs/apicurio-registry-3/catalog.json from $SOURCE_IMAGE"
fi

docker rm "$TEMP_CONTAINER" > /dev/null 2>&1

success "Copied catalog.json from $SOURCE_IMAGE"

SOURCE_BUNDLE_IMAGE=$(grep 'registry-proxy' catalog.json | sed 's/.*"\(registry-proxy.*-bundle.*\)".*/\1/' | uniq)

if [[ -z "$SOURCE_BUNDLE_IMAGE" ]]; then
  error_exit "Failed to determine bundle image from catalog.json"
else
  success "Determined bundle image: $SOURCE_BUNDLE_IMAGE"
fi

rm catalog.json

SOURCE_BUNDLE_IMAGE_HOST=""
SOURCE_BUNDLE_IMAGE_PATH=""
SOURCE_BUNDLE_IMAGE_TAG=""
SOURCE_BUNDLE_IMAGE_SHA_TAG=""
SOURCE_BUNDLE_IMAGE_SHA_HASH=""
SOURCE_BUNDLE_IMAGE_NO_PROTO="${SOURCE_BUNDLE_IMAGE#*://}"
SOURCE_BUNDLE_IMAGE_HOST="${SOURCE_BUNDLE_IMAGE_NO_PROTO%%/*}"
SOURCE_BUNDLE_IMAGE_PATH_AND_TAG="${SOURCE_BUNDLE_IMAGE_NO_PROTO#*/}"
if [[ "$SOURCE_BUNDLE_IMAGE_PATH_AND_TAG" == *@* ]]; then
  SOURCE_BUNDLE_IMAGE_SHA_TAG="${SOURCE_BUNDLE_IMAGE_PATH_AND_TAG##*@}"
  SOURCE_BUNDLE_IMAGE_SHA_HASH="${SOURCE_BUNDLE_IMAGE_SHA_TAG##*:}"
  SOURCE_BUNDLE_IMAGE_PATH="${SOURCE_BUNDLE_IMAGE_PATH_AND_TAG%@*}"
else
  if [[ "$SOURCE_BUNDLE_IMAGE_PATH_AND_TAG" == *:* ]]; then
    SOURCE_BUNDLE_IMAGE_TAG="${SOURCE_BUNDLE_IMAGE_PATH_AND_TAG##*:}"
    SOURCE_BUNDLE_IMAGE_PATH="${SOURCE_BUNDLE_IMAGE_PATH_AND_TAG%:*}"
  else
    SOURCE_BUNDLE_IMAGE_TAG="latest"
    SOURCE_BUNDLE_IMAGE_PATH="$SOURCE_BUNDLE_IMAGE_PATH_AND_TAG"
  fi
fi
echo "host $SOURCE_BUNDLE_IMAGE_HOST"
echo "path $SOURCE_BUNDLE_IMAGE_PATH"
echo "tag $SOURCE_BUNDLE_IMAGE_TAG"
echo "sha $SOURCE_BUNDLE_IMAGE_SHA_TAG"
echo "sha hash $SOURCE_BUNDLE_IMAGE_SHA_HASH"

if [[ "$SOURCE_BUNDLE_IMAGE_HOST" == "registry-proxy.engineering.redhat.com" ]]; then
  SOURCE_BUNDLE_IMAGE_HOST="brew.registry.redhat.io"
fi

if [[ -n "$SOURCE_BUNDLE_IMAGE_TAG" ]]; then
  error_exit "Expecting the bundle image to be specified with a sha256 digest, but got a tag ($SOURCE_BUNDLE_IMAGE_TAG) instead."
fi

SOURCE_BUNDLE_IMAGE="$SOURCE_BUNDLE_IMAGE_HOST/$SOURCE_BUNDLE_IMAGE_PATH@$SOURCE_BUNDLE_IMAGE_SHA_TAG"

#=== 4. Now build the modified bundle image

TARGET_BUNDLE_IMAGE="$IMAGE_REGISTRY_HOST/$SOURCE_BUNDLE_IMAGE_PATH:sha256-$SOURCE_BUNDLE_IMAGE_SHA_HASH"

export PLACEHOLDER_SOURCE_BUNDLE_IMAGE="$SOURCE_BUNDLE_IMAGE"

envsubst < Dockerfile.bundlehack.template > Dockerfile.tmp

if ! docker build -f Dockerfile.tmp -t "$TARGET_BUNDLE_IMAGE" . ; then
  error_exit "Failed to build modified bundle image $TARGET_BUNDLE_IMAGE from the original $SOURCE_BUNDLE_IMAGE ."
else
  success "Modified bundle image $TARGET_BUNDLE_IMAGE has been built from the original $SOURCE_BUNDLE_IMAGE ."
  rm Dockerfile.tmp
fi

if ! docker push "$TARGET_BUNDLE_IMAGE"; then
  error_exit "Failed to push image $TARGET_BUNDLE_IMAGE to the registry at $IMAGE_REGISTRY_HOST ."
else
  success "Image $TARGET_BUNDLE_IMAGE has been pushed to the registry."
fi

# === 5. Now build the modified index image

TARGET_IMAGE="$IMAGE_REGISTRY_HOST/$SOURCE_IMAGE_PATH:$SOURCE_IMAGE_TAG"

export PLACEHOLDER_SOURCE_IMAGE="$SOURCE_IMAGE"
export PLACEHOLDER_TARGET_HOST="$IMAGE_REGISTRY_HOST"
export PLACEHOLDER_SOURCE_BUNDLE_IMAGE_SHA_HASH="$SOURCE_BUNDLE_IMAGE_SHA_HASH"

envsubst < Dockerfile.indexhack.template > Dockerfile.tmp

if ! docker build -f Dockerfile.tmp -t "$TARGET_IMAGE" . ; then
  error_exit "Failed to build modified image $TARGET_IMAGE from the original $SOURCE_IMAGE ."
else
  success "Modified image $TARGET_IMAGE has been built from the original $SOURCE_IMAGE ."
  rm Dockerfile.tmp
fi

if ! docker push "$TARGET_IMAGE"; then
  error_exit "Failed to push image $TARGET_IMAGE to the registry at $IMAGE_REGISTRY_HOST ."
else
  success_exit "Image $TARGET_IMAGE has been pushed to the registry."
fi

popd > /dev/null || error_exit "Failed to return to the previous directory."