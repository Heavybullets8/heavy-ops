#!/usr/bin/env bash

function op_signin() {
    if ! op user get --me &>/dev/null; then
        gum log --structured --level info "Please authenticate with 1Password CLI"
        if ! eval "$(op signin)"; then
            gum log --structured --level error "1Password authentication failed"
            exit 1
        fi
    fi
}

function check_env() {
    local envs=("$@")
    local exit_bool=false
    gum log --structured --level debug "Checking Environment Variables..."
    for env in "${envs[@]}"; do
        if [[ -z "${!env-}" ]]; then
            gum log --structured --level error "\"$env\" unset.."
            exit_bool=true
        else
            gum log --structured --level debug "\"$env\" set.."
        fi
    done
    $exit_bool && exit 1
}

function check_cli() {
    local deps=("$@")
    local exit_bool=false
    gum log --structured --level debug "Checking Dependencies..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            gum log --structured --level error "\"$dep\" not found.."
            exit_bool=true
        else
            gum log --structured --level debug "\"$dep\" found.."
        fi
    done
    $exit_bool && exit 1
}

function render_template() {
    local file="$1"
    local output
    gum log --structured --level debug "Rendering \"$file\""
    if [[ ! -f "$file" ]]; then
        gum log --structured --level error "File not found" "file" "$file"
        exit 1
    fi
    if ! output=$(minijinja-cli "$file" | op inject 2>/dev/null) || [[ -z "$output" ]]; then
        gum log --structured --level error "Failed to render" "file" "$file"
        exit 1
    fi
    echo "$output"
}

function fetch_kubeconfig() {
    gum log --structured --level info "Fetching kubeconfig"
    if ! output=$(talosctl kubeconfig --nodes "$NODE_IP" --force --force-context-name main "$(basename "${KUBECONFIG}")" 2>&1); then
        gum log --structured --level error "Failed to fetch kubeconfig" "output" "$output"
        exit 1
    fi
    gum log --structured --level info "Kubeconfig fetched successfully"
}
