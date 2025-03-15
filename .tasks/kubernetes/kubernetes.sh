#!/usr/bin/env bash

OPTIONS=("Sync Secrets" "Cleanse Pods" "Help" "Back")

function show_help() {
    echo "Usage: $0 [command]"
    echo "Commands:"
    echo "  ss    Sync all ExternalSecrets"
    echo "  cp    Cleanse pods with a Failed/Pending/Succeeded phase"
    echo "Options:"
    echo "  -h, --help, help    Display this help message"
    exit 0
}

function menu() {
    choice=$(gum choose "${OPTIONS[@]}")
    if [ -n "$choice" ]; then
        echo "$choice"
    fi
}

function main() {
    local args=("$@")

    if [[ ${#args[@]} -eq 0 || "${args[0]}" == "menu" ]]; then
        args[0]=$(menu)
        if [ -z "${args[0]}" ]; then
            gum log --structured --level error "No choice selected"
            exit 1
        fi
    fi

    case "${args[0]}" in
    "Sync Secrets" | "ss")
        check_cli kubectl
        gum log --structured --level info "Syncing all ExternalSecrets"
        SECRETS=$(kubectl get externalsecret --all-namespaces --no-headers --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}')
        if [ -z "${SECRETS}" ]; then
            gum log --structured --level warn "No ExternalSecrets found"
        else
            while IFS= read -r line; do
                namespace=$(echo "${line}" | cut -d',' -f1)
                name=$(echo "${line}" | cut -d',' -f2)
                gum log --structured --level info "Annotating ExternalSecret" "namespace" "${namespace}" "name" "${name}"
                kubectl --namespace "${namespace}" annotate externalsecret "${name}" force-sync="$(date +%s)" --overwrite
            done <<<"${SECRETS}"
        fi
        ;;

    "Cleanse Pods" | "cp")
        check_cli kubectl
        gum log --structured --level info "Cleansing pods with Failed/Pending/Succeeded phase"
        for phase in Failed Pending Succeeded; do
            gum log --structured --level info "Deleting pods in phase ${phase}"
            kubectl delete pods --all-namespaces --field-selector status.phase="${phase}" --ignore-not-found=true
        done
        ;;

    "-h" | "--help" | "Help")
        show_help
        ;;

    "Back")
        ops
        ;;

    *)
        gum log --structured --level error "Unknown command" "command" "${args[0]}"
        show_help
        ;;
    esac
}

main "$@"
