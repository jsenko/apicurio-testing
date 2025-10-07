#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

usage() {
    echo "Check that all artifacts from an offline maven repo zip are present in the Red Hat Maven Repository (MRRC)."
    echo ""
    echo "Usage: $0 --file <path-to-zip> [--force]"
    echo ""
    echo "Required Parameters:"
    echo "  --file <path-to-zip>        Path to the offline repo zip file"
    echo ""
    echo "Optional Parameters:"
    echo "  --force                     Delete resources before running the tests to start fresh if an earlier attempt failed."
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --file apicurio-registry-3.1.0.GA-maven-repository.zip"
    echo "  $0 --file apicurio-registry-3.1.0.GA-maven-repository.zip --force"
    exit 1
}

FILE_PATH=""
FORCE_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
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

# Validate required arguments
if [[ -z "$FILE_PATH" ]]; then
    error_exit "Argument --file is required."
fi

# === Prepare repo
if [[ -f "$BASE_DIR/$FILE_PATH" ]]; then
    FILE_PATH="$BASE_DIR/$FILE_PATH"
fi
if [[ ! -f "$FILE_PATH" ]]; then
    error_exit "File not found: $FILE_PATH"
fi

WORK_DIR="$BASE_DIR/cache/tmp/$(basename "${BASH_SOURCE[0]%.*}")"
mkdir -p "$WORK_DIR"

if [[ $FORCE_CLEANUP == true ]]; then
    warning "Force cleanup is enabled. Temporary work directory will be cleaned up before running the tests."
    rm -rf "${WORK_DIR:?}/"*
fi

pushd "$WORK_DIR" 2>&1 > /dev/null || error_exit "Failed to change directory to $WORK_DIR"

unzip -q "$FILE_PATH" -d "$WORK_DIR" || error_exit "Failed to unzip $FILE_PATH"

RH_REPO_DIR=$(ls)

LOCAL_RH_REPO_PATH="$WORK_DIR/$RH_REPO_DIR/maven-repository"

important "Listing all files in the maven repository..."
if [[ -d "$LOCAL_RH_REPO_PATH" ]]; then
    pushd "$LOCAL_RH_REPO_PATH" > /dev/null 2>&1 || error_exit "Failed to change directory to $LOCAL_RH_REPO_PATH"

    # First, count total number of files
    important "Counting files in the maven repository..."
    total_file_count=$(find . -type f | wc -l)
    echo "Total files to check: $total_file_count"
    echo ""

    total_files=0
    found_files=0
    missing_files=0
    missing_files_list=()

    while IFS= read -r -d '' file; do
        ((total_files++))

        # Remove the leading "./" from the relative path
        clean_path="${file#./}"

        # Construct the URL
        url="https://maven.repository.redhat.com/ga/$clean_path"

        # Calculate percentage
        percentage=$((total_files * 100 / total_file_count))

        # Check if the file exists using curl (HTTP HEAD request) with retries
        found=false
        for attempt in {1..3}; do
            if curl -s -f -I "$url" > /dev/null 2>&1; then
                found=true
                break
            else
                # If not the last attempt, wait before retrying
                if [[ $attempt -lt 3 ]]; then
                    warning "[$total_files/$total_file_count - ${percentage}%] ✗ Missing: $clean_path (attempt $attempt, retrying...)"
                    sleep 5
                fi
            fi
        done

        if [[ "$found" == "true" ]]; then
            # For .md5 files, also check that the content matches
            if [[ "$clean_path" == *.md5 ]]; then
                local_md5_content=$(cat "$file" | tr -d '[:space:]')
                remote_md5_content=$(curl -s -f "$url" | tr -d '[:space:]')

                if [[ "$local_md5_content" == "$remote_md5_content" ]]; then
                    success "[$total_files/$total_file_count - ${percentage}%] ✓ Found: $clean_path (MD5 content matches)"
                    ((found_files++))
                else
                    error "[$total_files/$total_file_count - ${percentage}%] ✗ MD5 content mismatch: $clean_path"
                    error "  Local:  $local_md5_content"
                    error "  Remote: $remote_md5_content"
                    ((missing_files++))
                    missing_files_list+=("$clean_path (MD5 content mismatch)")
                fi
            else
                success "[$total_files/$total_file_count - ${percentage}%] ✓ Found: $clean_path"
                ((found_files++))
            fi
        else
            error "[$total_files/$total_file_count - ${percentage}%] ✗ Missing: $clean_path"
            ((missing_files++))
            missing_files_list+=("$clean_path")
        fi
    done < <(find . -type f -print0)

    popd > /dev/null 2>&1 || error_exit "Failed to return to previous directory"

    # Print summary
    echo ""
    important "Summary:"
    important "Total files checked: $total_files"
    important "Found in MRRC: $found_files"
    important "Missing from MRRC: $missing_files"

    if [[ $missing_files -gt 0 ]]; then
        echo ""
        error "List of missing files:"
        for missing_file in "${missing_files_list[@]}"; do
            echo "  - $missing_file"
        done
        error_exit "Some artifacts are missing from the Red Hat Maven repository."
    fi
else
    error_exit "Maven repository directory not found: $LOCAL_RH_REPO_PATH"
fi

success_exit "Tests passed! LGTM."
