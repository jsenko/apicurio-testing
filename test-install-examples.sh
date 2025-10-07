#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

update_install_file_images() {
    local work_dir="$1"
    local install_file="$work_dir/install/install.yaml"

    if [[ ! -f "$install_file" ]]; then
        error_exit "Install file not found: $install_file"
    fi

    echo "Updating image references in install file to use brew registry..."
    sed -i 's|registry.redhat.io/apicurio/|brew.registry.redhat.io/rh-osbs/apicurio-|g' "$install_file"
}

# Function to check if licenses/licenses.xml exists, is not empty, and contains valid XML
check_licenses_file() {
    local work_dir="$1"
    local licenses_file="$work_dir/licenses/licenses.xml"

    # Check if licenses/licenses.xml exists
    if [[ ! -f "$licenses_file" ]]; then
        error_exit "Licenses file not found: $licenses_file"
    fi

    echo "Found licenses file: $licenses_file"

    # Check if licenses.xml is not empty
    if [[ ! -s "$licenses_file" ]]; then
        error_exit "Licenses file is empty: $licenses_file"
    fi

    echo "Licenses file is not empty."

    # Validate that licenses.xml contains valid XML
    if ! xmllint --noout "$licenses_file" 2>/dev/null; then
        error_exit "Licenses file does not contain valid XML: $licenses_file"
    fi

    echo "Licenses file contains valid XML."
}

wait_on_pods() {
      local labels="$1"

      # First, wait for the pods to appear (up to 5 minutes)
      local timeout=300
      local elapsed=0
      local interval=5

      while [[ $elapsed -lt $timeout ]]; do
          local pod_count=$(kubectl get pods -l "$labels" -n apicurio-registry --no-headers 2>/dev/null | wc -l)

          if [[ $pod_count -ge 2 ]]; then
              success "Found $pod_count pod(s) with label '$labels'."
              break
          fi

          echo "Waiting for pods to appear... ($elapsed/$timeout seconds elapsed, found $pod_count/2 pods)"
          sleep $interval
          elapsed=$((elapsed + interval))
      done

      if [[ $elapsed -ge $timeout ]]; then
          error_exit "Timeout waiting for 2 pods with label '$labels' to appear."
      fi

      # Now wait for the pods to be ready
      important "Waiting for pods to become ready..."
      if ! kubectl wait --for=condition=Ready pod -l "$labels" --timeout=300s -n apicurio-registry 2>&1; then
          # Fallback: check the actual ready status
          local ready_pods=$(kubectl get pods -l "$labels" -n apicurio-registry -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")

          if [[ $ready_pods -ge 2 ]]; then
              success "Found $ready_pods ready pod(s) with label '$labels'."
          else
              echo "Current pod status:"
              kubectl get pods -l "$labels" -n apicurio-registry
              error_exit "Expected 2 ready pods with label '$labels', but found only $ready_pods ready."
          fi
      else
          success "All pods with label '$labels' are ready."
      fi
}

# Function to check README.adoc exists and extract/execute bash code snippets
check_readme_and_execute_snippets() {
    local work_dir="$1"

    pushd "$work_dir" || error_exit "Failed to change directory to $work_dir"

    local readme_file="README.adoc"

    # Check if README.adoc exists
    if [[ ! -f "$readme_file" ]]; then
        error_exit "README file not found: $readme_file"
    fi

    echo "Found README file: $readme_file"

    # Extract bash code snippets between [source,bash] and ----
    echo "Extracting and validating bash code snippets from README..."

    if [[ $FORCE_CLEANUP ]]; then
        warning "Deleting namespace 'apicurio-registry'."
        # Delete any CRs to avoid blocking the namespace deletion
        kubectl delete apicurioregistries3.registry.apicur.io --all -n apicurio-registry --timeout=60s >/dev/null 2>&1 || true
        kubectl delete namespace apicurio-registry >/dev/null 2>&1 || true
    fi

    local in_bash_block=0
    local snippet=""
    local snippet_count=0

    while IFS= read -r line; do
        # Check if we're entering a bash code block
        if [[ "$line" =~ ^\[source,bash\] ]]; then
            in_bash_block=1
            continue
        fi

        # Check if we're at the start or end delimiter of code block
        if [[ "$line" =~ ^----$ ]]; then
            if [[ $in_bash_block -eq 1 ]]; then
                # We're entering the code block content
                in_bash_block=2
                continue
            elif [[ $in_bash_block -eq 2 ]]; then
                # We're exiting the code block, process the snippet
                if [[ -n "$snippet" ]]; then
                    ((snippet_count++))
                    important "Executing bash snippet #$snippet_count..."
                    echo "$snippet..."

                    # We have to do this here because we cannot set the variable from isnide the snippet bash subprocess
                    export NAMESPACE=apicurio-registry
                    # Execute the snippet and check for errors
                    if ! echo "$snippet" | bash; then
                        error_exit "Bash snippet #$snippet_count has errors."
                    fi

                    success "Bash snippet #$snippet_count executed successfully, waiting 10s..."
                    sleep 10
                fi

                # Reset for next snippet
                snippet=""
                in_bash_block=0
                continue
            fi
        fi

        # Collect lines when inside code block content
        if [[ $in_bash_block -eq 2 ]]; then
            if [[ -n "$snippet" ]]; then
                snippet="$snippet"$'\n'"$line"
            else
                snippet="$line"
            fi
        fi
    done < "$readme_file"

    if [[ $snippet_count -eq 0 ]]; then
        error_exit "No bash code snippets found in README"
    fi

    important "Waiting for 2 pods with label 'app=simple' to be ready..."

    wait_on_pods "app=simple"

    echo "Successfully validated $snippet_count bash code snippet(s) from README."

    popd || error_exit "Failed to return to previous directory."
}

usage() {
    echo "Usage: $0 [--cluster <cluster-name>] [--file <path-to-zip>] [--force]"
    echo ""
    echo "Optional Parameters:"
    echo "  --cluster <cluster-name>    Name of the cluster to configure (default: $USER)"
    echo "  --file <path-to-zip>        Path to the install examples zip file"
    echo "  --force                     Delete OCP project resources if tests fail"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Uses default cluster ($USER) and Docker config"
    echo "  $0 --cluster okd419       # Uses specific cluster"
    echo "  $0 --file /path/to/examples.zip  # Uses specific install examples file"
    echo "  $0 --force                # Clean up resources on test failure"
    exit 1
}

CLUSTER_NAME="$USER"
FILE_PATH=""
FORCE_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --file)
            FILE_PATH="$2"
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

load_cluster_config "$CLUSTER_NAME"

# If FILE_PATH is provided, check it exists and unpack it
if [[ -n "$FILE_PATH" ]]; then

    if [[ ! -f "$FILE_PATH" ]]; then
        error_exit "File not found: $FILE_PATH"
    fi

    WORK_DIR="$BASE_DIR/cache/tmp"
    mkdir -p "$WORK_DIR"

    rm -rf "${WORK_DIR:?}/"*

    unzip -q "$FILE_PATH" -d "$WORK_DIR"

    WORK_DIR="$WORK_DIR/apicurio-registry-install-examples"
    echo "Successfully unpacked to $WORK_DIR."

    # Check install file and licenses file
    export FORCE_CLEANUP
    update_install_file_images "$WORK_DIR"
    check_readme_and_execute_snippets "$WORK_DIR"
    check_licenses_file "$WORK_DIR"

    success_exit "Tests passed! LGTM."
else
    error_exit "Argument --file is required."
fi
