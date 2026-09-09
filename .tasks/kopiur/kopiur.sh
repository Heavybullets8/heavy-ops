#!/usr/bin/env bash

function main() {
    local args=("$@")

    if [[ ${#args[@]} -eq 0 ]]; then
        args=(status -A)
    fi

    kubectl kopiur "${args[@]}"
}

main "$@"
