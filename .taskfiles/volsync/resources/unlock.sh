#!/bin/bash
# Find all secrets ending with "r2-secret" across all namespaces
mapfile -t secrets < <(kubectl get secrets --all-namespaces --no-headers -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name" | grep "r2-secret$")

if [ -z "${secrets[*]}" ]; then
    echo "No secrets found.."
fi

for secret in "${secrets[@]}"; do
    namespace=$(echo "$secret" | awk '{print $1}')
    secret_name=$(echo "$secret" | awk '{print $2}')
    echo "Processing secret: $namespace/$secret_name"

    AWS_ACCESS_KEY_ID=$(kubectl --namespace "$namespace" get secret "$secret_name" -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
    AWS_SECRET_ACCESS_KEY=$(kubectl --namespace "$namespace" get secret "$secret_name" -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
    RESTIC_PASSWORD=$(kubectl --namespace "$namespace" get secret "$secret_name" -o jsonpath='{.data.RESTIC_PASSWORD}' | base64 -d)
    RESTIC_REPOSITORY=$(kubectl --namespace "$namespace" get secret "$secret_name" -o jsonpath='{.data.RESTIC_REPOSITORY}' | base64 -d)

    bucket=$(echo "$RESTIC_REPOSITORY" | sed -E 's|s3:https://[^/]+/([^/]+)/.*|\1|')
    application=$(echo "$RESTIC_REPOSITORY" | sed -E 's|s3:https://[^/]+/[^/]+/(.*)|\1|')
    r2_endpoint="$(echo "$RESTIC_REPOSITORY" | sed -E 's|s3:(https://[^/]+).*|\1|')"

    # s3:<$r2_endpoint>/<$bucket>/<$application>
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] ||
        [ -z "$RESTIC_PASSWORD" ] || [ -z "$RESTIC_REPOSITORY" ] ||
        [ -z "$bucket" ] || [ -z "$application" ] || [ -z "$r2_endpoint" ]; then
        echo "Error: Invalid data found"
        echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-<empty>}"
        echo "  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-<empty>}"
        echo "  RESTIC_PASSWORD: ${RESTIC_PASSWORD:-<empty>}"
        echo "  RESTIC_REPOSITORY: ${RESTIC_REPOSITORY:-<empty>}"
        echo "  Bucket: ${bucket:-<empty>}"
        echo "  Application: ${application:-<empty>}"
        echo "  R2 Endpoint: ${r2_endpoint:-<empty>}"
        echo "Skipping this application..."
        echo
        continue
    fi

    if aws s3 ls --endpoint-url "$r2_endpoint" "s3://$bucket/$application/locks" >/dev/null 2>&1; then
        echo "Found lock files for $application, removing them..."
        aws s3 rm --endpoint-url "$r2_endpoint" "s3://$bucket/$application/locks" --recursive
    else
        echo "No lock files found for $application"
    fi
    echo
done
