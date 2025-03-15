#!/usr/bin/env bash

OPTIONS=("Unlock All Repositories" "Help" "Back")

function show_help() {
    echo "Usage: $0 [command]"
    echo "Commands:"
    echo "  unlock    Reconcile all helm releases"
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
    "Unlock All Repositories" | "unlock")
        # shellcheck disable=1091
        source "$TASK_DIR/volsync/resources/unlock.sh"
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
