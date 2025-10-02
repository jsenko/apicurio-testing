#!/bin/bash

_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CACHE_DIR="$_BASE_DIR/cache"

function load_cache_config() {

  if [[ ! -d "$CACHE_DIR" || ! -d "$CACHE_DIR/.git" ]]; then
    error_exit "Cache directory '$CACHE_DIR' does not exist or is not a git repository. Please run load-cache.sh first."
  fi

  # TIL: `declare -g` allows the variable to be global in the sourcing script, not just in this function. `export` does not work inside functions.
  # TIL: `declare -x` allows the variable to be passed to a subprocess e.g. kubectl, like `export`.
  declare -gx  CLUSTERS_DIR="$CACHE_DIR/clusters"
  mkdir -p "$CLUSTERS_DIR"

  declare -gx  BIN_DIR="$CACHE_DIR/bin"
  mkdir -p "$BIN_DIR"

  declare -gx  CERTS_DIR="$CACHE_DIR/certificates"
  mkdir -p "$CERTS_DIR"
}

function load_cluster_config() {

    load_cache_config

    local CLUSTER_NAME="$1"

    if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
        error_exit "Cluster name '$CLUSTER_NAME' is invalid. Cluster name must not be empty and must contain only letters and numbers."
    fi

    local CLUSTER_DIR="$CLUSTERS_DIR/$CLUSTER_NAME"

    if [[ ! -d "$CLUSTER_DIR" ]]; then
        error_exit "Cluster directory '$CLUSTER_DIR' does not exist. Make sure the cluster '$CLUSTER_NAME' has been created, or loaded from cache using load-cache.sh."
    fi

    if [[ ! -f "$CLUSTER_DIR/auth/kubeconfig" ]]; then
        error_exit "Kubeconfig file '$CLUSTER_DIR/auth/kubeconfig' does not exist. Make sure the cluster '$CLUSTER_NAME' has been properly configured."
    fi

    declare -gx CLUSTER_DIR="$CLUSTER_DIR"
    declare -gx KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"
    declare -gx CERT_DIR="$CERTS_DIR/$CLUSTER_NAME"
}

declare -rx GREEN='\033[0;32m'
declare -rx LIGHT_GREEN='\033[0;92m'
declare -rx CYAN='\033[0;36m'
declare -rx LIGHT_CYAN='\033[0;96m'
declare -rx PURPLE='\033[0;35m'
declare -rx LIGHT_PURPLE='\033[0;95m'
declare -rx YELLOW='\033[0;33m'
declare -rx LIGHT_YELLOW='\033[0;93m'
declare -rx RED='\033[0;31m'
declare -rx LIGHT_RED='\033[0;91m'
declare -rx NO_COLOR='\033[0m'

function success() {
    echo -e "${LIGHT_CYAN}[Success] $1${NO_COLOR}"
}

function success_exit() {
    echo -e "${LIGHT_GREEN}[Success] $1\nExiting.${NO_COLOR}"
    exit "${2:-0}"
}

function important() {
    echo -e "${LIGHT_PURPLE}$1${NO_COLOR}"
}

function warning() {
    echo -e "${LIGHT_YELLOW}[Warning] $1${NO_COLOR}"
}

function error() {
    echo -e "${LIGHT_RED}[Error] $1${NO_COLOR}" >&2
}

function error_exit() {
    echo -e "${LIGHT_RED}[Error] $1\nExiting.${NO_COLOR}" >&2
    exit "${2:-1}"
}
