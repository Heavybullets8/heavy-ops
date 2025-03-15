#!/usr/bin/env bash

OPTIONS=("Reconcile Kustomizations" "Reconcile Helm Releases" "Help" "Back")

function show_help() {
    echo "Usage: $0 [command]"
    echo "Commands:"
    echo "  rk    Reconcile all kustomizations"
    echo "  rh    Reconcile all helm releases"
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
    "Reconcile Kustomizations" | "rk")
        gum log --structured --level debug "Fetching kustomizations"
        if ! kustomizations=$(kubectl get kustomization --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{"\n"}{end}'); then
            gum log --structured --level error "Failed to fetch kustomizations"
            exit 1
        fi
        for k in $kustomizations; do
            namespace=$(echo "$k" | awk -F',' '{print $1}')
            name=$(echo "$k" | awk -F',' '{print $2}')
            if ! gum spin --spinner monkey --title "ns=$namespace name=$name" -- flux reconcile kustomization -n "$namespace" "$name"; then
                gum log --structured --level error "Failed to reconcile kustomization" "namespace" "$namespace" "name" "$name"
            else
                gum log --structured --level info "Successfully reconciled kustomization" "namespace" "$namespace" "name" "$name"
            fi
        done
        ;;

    "Reconcile Helm Releases" | "rh")
        gum log --structured --level debug "Fetching helm releases"
        if ! helmreleases=$(kubectl get helmrelease --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{"\n"}{end}'); then
            gum log --structured --level error "Failed to fetch helm releases"
            exit 1
        fi
        for h in $helmreleases; do
            namespace=$(echo "$h" | awk -F',' '{print $1}')
            name=$(echo "$h" | awk -F',' '{print $2}')
            if ! gum spin --spinner monkey --title "ns=$namespace name=$name" -- flux reconcile helmrelease -n "$namespace" "$name"; then
                gum log --structured --level error "Failed to reconcile helm release" "namespace" "$namespace" "name" "$name"
            else
                gum log --structured --level info "Successfully reconciled helm release" "namespace" "$namespace" "name" "$name"
            fi
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
