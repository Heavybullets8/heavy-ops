#!/usr/bin/env bash
set -Eeuo pipefail

export LOG_LEVEL LOG_LEVELS ROOT_DIR NODE_IP
NODE_IP=$1

LOG_LEVEL="debug"
LOG_LEVELS=([ERROR]=1 [WARNING]=2 [INFO]=3 [DEBUG]=4)
ROOT_DIR="$(git rev-parse --show-toplevel)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level="$1"
    shift

    level=$(echo "$level" | tr '[:lower:]' '[:upper:]')

    if [[ -z "${LOG_LEVELS[$level]}" ]]; then
        echo "Invalid log level: $level" >&2
        return 1
    fi

    local level_num=${LOG_LEVELS[$level]}
    local threshold_num=${LOG_LEVELS[$LOG_LEVEL]}

    if ((level_num <= threshold_num)); then
        local color

        case "$level" in
        ERROR) color="$RED" ;;
        WARNING) color="$YELLOW" ;;
        INFO) color="$GREEN" ;;
        DEBUG) color="$BLUE" ;;
        *) color="$NC" ;;
        esac

        printf "${color}[%s] [%s] %s${NC}\n" "$level" "$*"
    fi
}

function check_env() {
    local envs=("$@")
    local exit_bool=false

    log debug "Checking Enivironment Variables..."

    for env in "${envs[@]}"; do
        if [[ -z "${!env-}" ]]; then
            log error \""$env\" unset.."
            exit_bool=true
        else
            log debug "\"$env\" set.."
        fi
    done

    $exit_bool && exit 1
}

function check_cli() {
    local deps=("$@")
    local exit_bool=false

    log debug "Checking Dependencies..."

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log error "\"$dep\" not found.."
            exit_bool=true
        else
            log debug "\"$dep\" found.."
        fi
    done

    $exit_bool && exit 1
}

function render_template() {
    local file="$1"
    local output

    log debug "Rendering \"$file\""

    if [[ ! -f "$file" ]]; then
        log error "File not found file=\"$file\""
        exit 1
    fi

    if ! output=$(minijinja-cli "$file" | op inject 2>/dev/null) || [[ -z "$output" ]]; then
        log error "Failed to render file=\"$file\""
        exit 1
    fi

    echo "$output"
}

function apply_talos_config() {
    local config_file="${ROOT_DIR}/talos/${NODE_IP}.yaml.j2"
    local machine_config

    log info "\nApplying Talos configuration"

    machine_config=$(render_template "$config_file")
    log info "Talos config rendered successfully"

    local output
    if ! output=$(echo "$machine_config" | talosctl --nodes "$NODE_IP" apply-config --insecure --file /dev/stdin 2>&1); then
        if [[ "$output" == *"certificate required"* ]]; then
            log warn "Looks like talos is already bootstrapped..."
            log warn "Will still attempt to bootstrap applications..."
        else
            log error "Failed to apply Talos config output=\"$output\""
            exit 1
        fi
    else
        log info "Talos config applied successfully"
    fi
}

function bootstrap_talos() {
    local bootstrapped=true
    local output

    log info "\nBootstrapping Talos"

    until output=$(talosctl --nodes "$NODE_IP" bootstrap 2>&1); do

        if [[ "$bootstrapped" == true && "$output" == *"AlreadyExists"* ]]; then
            log info "Talos is bootstrapped"
            break
        fi

        bootstrapped=false
        log info "Talos bootstrap failed, retrying in 10s"
        sleep 10
    done
}

function fetch_kubeconfig() {
    log info "\nFetching kubeconfig"

    if ! output=$(talosctl kubeconfig --nodes "$NODE_IP" --force --force-context-name main "$(basename "${KUBECONFIG}")" 2>&1); then
        log error "Failed to fetch kubeconfig: $output"
        exit 1
    fi

    log info "Kubeconfig fetched successfully"
}

function wait_for_nodes() {
    log info "\nWaiting for node to be available"

    if kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        log info "Node is ready, skipping wait"
        return
    fi

    # HACK: Hmm. this is from onedr0p, confused about the Ready=False. We'll see on next bootstrap.
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
        log info "Node not ready, retrying in 10s"
        sleep 10
    done
}

function apply_resources() {
    local resources_file="${ROOT_DIR}/bootstrap/resources.yaml.j2"

    log info "\nApplying resources"

    if [[ ! -f "$resources_file" ]]; then
        log error "Resources file not found..."
        exit 1
    fi

    local output
    output=$(render_template "$resources_file")

    if echo "$output" | kubectl diff --filename - &>/dev/null; then
        log warn "Resources are up-to-date"
        return 0
    fi

    if echo "$output" | kubectl apply --server-side --filename - &>/dev/null; then
        log info "Resources applied"
    else
        log error "Failed to apply resources"
        exit 1
    fi
}

function apply_helm_releases() {
    local helmfile_file="${ROOT_DIR}/bootstrap/helmfile.yaml"

    log info "\nApplying Helm releases"

    if [[ ! -f "$helmfile_file" ]]; then
        log error "Helmfile not found..."
        exit 1
    fi

    if ! helmfile --file "$helmfile_file" apply --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets; then
        log error "Failed to apply Helm releases"
        exit 1
    fi

    log info "Helm releases applied successfully"
}

function main() {
    check_env KUBECONFIG KUBERNETES_VERSION TALOS_VERSION NODE_IP
    check_cli helmfile jq kubectl kustomize minijinja-cli op talosctl yq
    if ! op user get --me &>/dev/null; then
        echo "Please authenticate with 1Password CLI"
        if ! eval "$(op signin)"; then
            log error "1Password authentication failed"
            exit 1
        fi
    fi
    apply_talos_config
    bootstrap_talos
    fetch_kubeconfig
    wait_for_nodes
    apply_resources
    apply_helm_releases
    log info "Cluster bootstrapped successfully!"
}

main "$@"
