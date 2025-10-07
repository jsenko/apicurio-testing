#!/bin/bash

# TODO: Not working yet - this was intended to run the downstream Registry build locally against the offline repository,
# but there are some issues:
#
# [ERROR] Failed to execute goal on project apicurio-registry-app: Could not resolve dependencies for project io.apicurio:apicurio-registry-app:jar:3.1.0.redhat-00004: The following artifacts could not be resolved: io.confluent:kafka-avro-serializer:jar:8.0.0 (absent), io.confluent:kafka-protobuf-serializer:jar:8.0.0 (absent), io.confluent:kafka-json-schema-serializer:jar:8.0.0 (absent), io.confluent:kafka-connect-avro-converter:jar:8.0.0 (absent): Could not find artifact io.confluent:kafka-avro-serializer:jar:8.0.0 in repository (file:///home/jsenko/projects/work/repos/github.com/Apicurio/apicurio-testing.git/cache/tmp/test-maven-repo-build/apicurio-registry-3.1.0.null-maven-repository/maven-repository)
#
# We might not need this test anyway, but keeping it as a WIP for now.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

usage() {
    echo "Usage: $0 --file <path-to-zip> --registry-repo <git-uri> --tag <tag> [--force]"
    echo ""
    echo "Required Parameters:"
    echo "  --file <path-to-zip>        Path to the install examples zip file"
    echo "  --registry-repo <git-uri>   Git URI to the downstream registry repository"
    echo "  --tag <tag>                 Tag from which the release was built"
    echo ""
    echo "Optional Parameters:"
    echo "  --force                     Delete resources before running the tests to start fresh if an earlier attempt failed."
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --file /path/to/examples.zip --registry-repo https://github.com/Apicurio/apicurio-registry.git --tag v3.0.0"
    echo "  $0 --file /path/to/examples.zip --registry-repo git@github.com:Apicurio/apicurio-registry.git --tag v3.0.0 --force"
    exit 1
}

FILE_PATH=""
FORCE_CLEANUP=false
REGISTRY_REPO=""
REGISTRY_TAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --file)
            FILE_PATH="$2"
            shift 2
            ;;
        --registry-repo)
            REGISTRY_REPO="$2"
            shift 2
            ;;
        --tag)
            REGISTRY_TAG="$2"
            shift 2
            ;;
        --force)
            FORCE_CLEANUP=true
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

# Validate required arguments
if [[ -z "$FILE_PATH" ]]; then
    error_exit "Argument --file is required."
fi

if [[ -z "$REGISTRY_REPO" ]]; then
    error_exit "Argument --registry-repo is required."
fi

if [[ -z "$REGISTRY_TAG" ]]; then
    error_exit "Argument --tag is required."
fi

# === Prepare repo
if [[ -f "$BASE_DIR/$FILE_PATH" ]]; then
    FILE_PATH="$BASE_DIR/$FILE_PATH"
fi
if [[ ! -f "$FILE_PATH" ]]; then
    error_exit "File not found: $FILE_PATH"
fi

WORK_DIR="$BASE_DIR/cache/tmp/test-maven-repo-build"
mkdir -p "$WORK_DIR"

if [[ $FORCE_CLEANUP == true ]]; then
    warning "Force cleanup is enabled. Temporary work directory will be cleaned up before running the tests."
    rm -rf "${WORK_DIR:?}/"*
fi

pushd "$WORK_DIR" 2>&1 > /dev/null || error_exit "Failed to change directory to $WORK_DIR"

unzip -q "$FILE_PATH" -d "$WORK_DIR" || error_exit "Failed to unzip $FILE_PATH"

RH_REPO_PATH=$(ls)

# === Prepare settings.xml

export PLACEHOLDER_LOCAL_REPO_PATH="$WORK_DIR/maven-repository"
mkdir -p "$PLACEHOLDER_LOCAL_REPO_PATH"

export PLACEHOLDER_LOCAL_RH_REPO_PATH="$WORK_DIR/$RH_REPO_PATH/maven-repository"

SETTINGS_XML_PATH="$WORK_DIR/settings.xml"
envsubst < "$BASE_DIR/templates/maven/settings.xml" > "$SETTINGS_XML_PATH"

# === Checkout registry

REGISTRY_REPO_PATH="$WORK_DIR/registry"

if [[ -d "$REGISTRY_REPO_PATH" ]]; then
  if [[ $FORCE_CLEANUP == true ]]; then
      warning "Registry repo directory '$REGISTRY_REPO_PATH' already exists! Force cleanup is enabled. Removing existing registry repo directory..."
      rm -rf "$REGISTRY_REPO_PATH"
  else
      warning "Registry repo directory '$REGISTRY_REPO_PATH' already exists! Reusing it..."
  fi
else
  git clone --depth 1 --branch "$REGISTRY_TAG" "$REGISTRY_REPO" "$REGISTRY_REPO_PATH" || error_exit "Failed to clone registry repo."
fi

# === Build the code

pushd "$REGISTRY_REPO_PATH" || error_exit "Failed to change directory to $REGISTRY_REPO_PATH"

# Some adjustments needed to make the downstream build work
mvn -s "$SETTINGS_XML_PATH" clean install -DskipTests \
  -Dprotoc-artifact-common=com.google.protobuf:protoc:3.25.5:exe:linux-x86_64 \
  || error_exit "Maven build failed."

success_exit "Tests passed! LGTM."
