#!/usr/bin/env bash
set -Eeuo pipefail

# Set global variables
export LOG_LEVEL
export ROOT_DIR

LOG_LEVEL="debug"
ROOT_DIR="$(git rev-parse --show-toplevel)"

# Log function (unchanged)
function log() {
    local level="${1:-info}"
    shift
    local -A level_priority=([debug]=1 [info]=2 [warn]=3 [error]=4)
    local current_priority=${level_priority[$level]:-2}
    local configured_level=${LOG_LEVEL:-info}
    local configured_priority=${level_priority[$configured_level]:-2}
    if ((current_priority < configured_priority)); then
        return
    fi
    local -A colors=([debug]="\033[1m\033[38;5;63m" [info]="\033[1m\033[38;5;87m" [warn]="\033[1m\033[38;5;192m" [error]="\033[1m\033[38;5;198m")
    local color="${colors[$level]:-${colors[info]}}"
    local msg="$1"
    shift
    local data=""
    if [[ $# -gt 0 ]]; then
        for item in "$@"; do
            if [[ "${item}" == *=* ]]; then
                data+="\033[1m\033[38;5;236m${item%%=*}=\033[0m\"${item#*=}\" "
            else
                data+="${item} "
            fi
        done
    fi
    local output_stream="/dev/stdout"
    [[ "$level" == "error" ]] && output_stream="/dev/stderr"
    printf "%s %b%s%b %s %b\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "${color}" "${level^^}" "\033[0m" "${msg}" "${data}" >"${output_stream}"
    [[ "$level" == "error" ]] && exit 1
}

# Check env and cli functions (unchanged)
function check_env() {
    local envs=("$@")
    local missing=()
    for env in "${envs[@]}"; do
        [[ -z "${!env-}" ]] && missing+=("${env}")
    done
    [[ ${#missing[@]} -ne 0 ]] && log error "Missing required env variables" "envs=${missing[*]}"
    log debug "Env variables are set" "envs=${envs[*]}"
}

function check_cli() {
    local deps=("$@")
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "${dep}" &>/dev/null || missing+=("${dep}")
    done
    [[ ${#missing[@]} -ne 0 ]] && log error "Missing required deps" "deps=${missing[*]}"
    log debug "Deps are installed" "deps=${deps[*]}"
}

# Render template function (unchanged)
function render_template() {
    local file="$1"
    [[ ! -f "$file" ]] && log error "File does not exist" "file=$file"
    local output
    if ! output=$(minijinja-cli "$file" | op inject 2>/dev/null) || [[ -z "$output" ]]; then
        log error "Failed to render config" "file=$file"
    fi
    echo "$output"
}

# Apply Talos config with improved path
function apply_talos_config() {
    local config_file="${ROOT_DIR}/talos/${node}.yaml.j2"
    log debug "Applying Talos configuration" "node=$node" "file=$config_file"
    [[ ! -f "$config_file" ]] && log error "No Talos config file found" "file=$config_file"
    local machine_config
    if ! machine_config=$(render_template "$config_file") || [[ -z "$machine_config" ]]; then
        log error "Failed to render Talos config" "file=$config_file"
    fi
    log info "Talos config rendered successfully" "node=$node"
    local output
    if ! output=$(echo "$machine_config" | talosctl --nodes "$node" apply-config --insecure --file /dev/stdin 2>&1); then
        if [[ "$output" == *"certificate required"* ]]; then
            log warn "Talos node already configured, skipping" "node=$node"
        else
            log error "Failed to apply Talos config" "node=$node" "output=$output"
        fi
    else
        log info "Talos config applied successfully" "node=$node"
    fi
}

# Remaining functions (unchanged except for using global $node)
function bootstrap_talos() {
    log debug "Bootstrapping Talos" "node=$node"
    local bootstrapped=true
    local output
    until output=$(talosctl --nodes "$node" bootstrap 2>&1); do
        if [[ "$bootstrapped" == true && "$output" == *"AlreadyExists"* ]]; then
            log info "Talos is bootstrapped" "node=$node"
            break
        fi
        bootstrapped=false
        log info "Talos bootstrap failed, retrying in 10s" "node=$node"
        sleep 10
    done
}

function fetch_kubeconfig() {
    log debug "Fetching kubeconfig" "node=$node"
    if ! talosctl kubeconfig --nodes "$node" --force --force-context-name main "$(basename "${KUBECONFIG}")" &>/dev/null; then
        log error "Failed to fetch kubeconfig" "node=$node"
    fi
    log info "Kubeconfig fetched successfully"
}

function wait_for_nodes() {
    log debug "Waiting for node to be available"
    if kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        log info "Node is ready, skipping wait"
        return
    fi
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
        log info "Node not available, retrying in 10s"
        sleep 10
    done
}

function apply_resources() {
    log debug "Applying resources"
    local resources_file="${ROOT_DIR}/bootstrap/resources.yaml.j2"
    [[ ! -f "$resources_file" ]] && {
        log warn "Resources file not found, skipping" "file=$resources_file"
        return
    }
    local output
    if ! output=$(render_template "$resources_file") || [[ -z "$output" ]]; then
        log error "Failed to render resources" "file=$resources_file"
    fi
    if echo "$output" | kubectl diff --filename - &>/dev/null; then
        log info "Resources are up-to-date"
        return
    fi
    if echo "$output" | kubectl apply --server-side --filename - &>/dev/null; then
        log info "Resources applied"
    else
        log error "Failed to apply resources"
    fi
}

function apply_helm_releases() {
    log debug "Applying Helm releases"
    local helmfile_file="${ROOT_DIR}/bootstrap/helmfile.yaml"
    [[ ! -f "$helmfile_file" ]] && {
        log warn "Helmfile not found, skipping" "file=$helmfile_file"
        return
    }
    if ! helmfile --file "$helmfile_file" apply --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets; then
        log error "Failed to apply Helm releases"
    fi
    log info "Helm releases applied successfully"
}

# Main function with global node
function main() {
    export node="$1"
    [[ -z "$node" ]] && log error "No node IP provided"
    check_env KUBECONFIG KUBERNETES_VERSION TALOS_VERSION
    check_cli helmfile jq kubectl kustomize minijinja-cli op talosctl yq
    if ! op user get --me &>/dev/null; then
        log error "Failed to authenticate with 1Password CLI"
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
