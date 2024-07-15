#!/bin/bash

# Set the context (replace 'your-cluster-context' with your actual cluster context)
CONTEXT="heavy-cluster"

# Get all destination VolumeSnapshots
SNAPSHOTS=$(kubectl --context $CONTEXT get volumesnapshot --all-namespaces --no-headers | grep "dst-dest" | awk '{print $1 "/" $2}')

echo "Patching and deleting destination VolumeSnapshots..."

for item in $SNAPSHOTS; do
    NAMESPACE=$(echo $item | cut -d '/' -f 1)
    SNAPSHOT_NAME=$(echo $item | cut -d '/' -f 2)

    echo "Patching VolumeSnapshot $SNAPSHOT_NAME in namespace $NAMESPACE..."
    kubectl --context $CONTEXT patch volumesnapshot -n $NAMESPACE $SNAPSHOT_NAME -p '{"metadata":{"finalizers":[]}}' --type=merge

    echo "Deleting VolumeSnapshot $SNAPSHOT_NAME in namespace $NAMESPACE..."
    kubectl --context $CONTEXT delete volumesnapshot -n $NAMESPACE $SNAPSHOT_NAME
done

echo "All destination VolumeSnapshots have been patched and deleted."
