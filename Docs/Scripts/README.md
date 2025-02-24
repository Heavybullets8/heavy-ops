# Random Scripts I Occasionally Use

All of these likely need some work. If you did find this, use these at your own
risk, read through them prior to applying them in your own system.

## ZFS Tools

I use this for checking out information about my pool

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: zfs-tools
  namespace: kube-system
spec:
  containers:
    - name: zfs-tools
      image: ubuntu:22.04
      command: [
        "/bin/sh",
        "-c",
        "apt update && apt install -y zfsutils-linux smartmontools nvme-cli && sleep infinity",
      ]
      securityContext:
        privileged: true
      volumeMounts:
        - name: host-dev
          mountPath: /dev
  volumes:
    - name: host-dev
      hostPath:
        path: /dev
  hostNetwork: true
  hostPID: true
  restartPolicy: Never
```

## ZFS SQLite Edit Pod and Script

I used these two, to mount a PVC for an application, such as plex, then change
the page size to 64k for the database. This is useful because SQLite uses 4k
page sizes by default, which massively slows down database operations if your
recordsize is larger than 4k. I set the page size to 64k for SQLite, and the
recordsize for that application to be 64k.

### The Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sqlite-modifier
  namespace: media # Replace with your actual target namespace
spec:
  restartPolicy: Never
  containers:
    - name: sqlite-tools
      image: nouchka/sqlite3:latest
      command: ["/bin/bash", "-c", "sleep infinity"]
      volumeMounts:
        - name: target-pvc
          mountPath: /mnt
        - name: script-volume
          mountPath: /scripts
      env:
        - name: PATH
          value: "/scripts:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  volumes:
    - name: target-pvc
      persistentVolumeClaim:
        claimName: plex # Replace with your actual PVC name
    - name: script-volume
      configMap:
        name: sqlite-modifier-script
        defaultMode: 0755
```

### The Script

```sh
#!/bin/bash
set -euo pipefail

# Function to log messages with timestamps
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Check if the database path is provided
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/database.db"
  exit 1
fi

DB_PATH="$1"
NEW_PAGE_SIZE=65536       # 64KB
NEW_CACHE_SIZE=-131072    # 128MB (adjust as needed)

log "Starting SQLite page size modification for: $DB_PATH"

# Verify the database file exists
if [[ ! -f "$DB_PATH" ]]; then
  log "Error: Database file does not exist at $DB_PATH"
  exit 1
fi

# Check the current page size
current_page_size=$(sqlite3 "$DB_PATH" 'PRAGMA page_size;')
log "Current page size: $current_page_size bytes"

if [[ "$current_page_size" -eq "$NEW_PAGE_SIZE" ]]; then
  log "Page size is already set to $NEW_PAGE_SIZE bytes. No changes needed."
  exit 0
fi

log "Changing page size to $NEW_PAGE_SIZE bytes..."

# Define new database path
NEW_DB_PATH="${DB_PATH}.new"

# Backup the original database
cp "$DB_PATH" "${DB_PATH}.bak"
log "Backup created at ${DB_PATH}.bak"

# Capture current permissions and ownership
owner=$(stat -c '%u' "$DB_PATH")
group=$(stat -c '%g' "$DB_PATH")
perms=$(stat -c '%a' "$DB_PATH")

# Create a new database with the desired page size
sqlite3 "$NEW_DB_PATH" "PRAGMA page_size = $NEW_PAGE_SIZE; VACUUM;"
log "New database created with page size $NEW_PAGE_SIZE bytes."

# Dump data from the old database and import into the new one
sqlite3 "$DB_PATH" .dump | sqlite3 "$NEW_DB_PATH"
log "Data migrated to the new database."

# Replace the old database with the new one
mv "$NEW_DB_PATH" "$DB_PATH"
log "Replaced old database with the new one."

# Restore original permissions and ownership
chown "$owner":"$group" "$DB_PATH"
chmod "$perms" "$DB_PATH"
log "Restored original permissions and ownership."

# Set the new cache size
sqlite3 "$DB_PATH" "PRAGMA cache_size = $NEW_CACHE_SIZE;"
log "Set cache size to $NEW_CACHE_SIZE."

# Optimize the new database
sqlite3 "$DB_PATH" 'VACUUM;'
log "Vacuumed the new database to optimize it."

log "SQLite page size modification completed successfully for $DB_PATH."
```

### Usage

1. Scale down the deployment of the target application, and any other
   applications that use that apps PVC

```sh
kubectl scale deployment <DEPLOYMENT NAME> -n <NAMESPACE> --replicas=0
```

2. Create a configmap of the script in that target namespace

```sh
kubectl create configmap sqlite-modifier-script -n <NAMESPACE> --from-file=<SCRIPT FILENAME>
```

3. Create the pod

```sh
kubectl apply -f <POD FILENAME>
```

4. Find the database

```sh
find /mnt -type f \( -iname "*.db" -o -iname "*.sqlite" -o -iname "*.sqlite3" \)
```

5. Run the script on the database(s)

```sh
bash /scripts/sqlite-modifier-script.sh <DATABASE PATH>
```

6. Delete pod

```sh
kubectl delete pod -n <NAMESPACE> sqlite-modifier
```

7. Delete configmap

```sh
kubectl delete configmap -n <NAMESPACE> <CONFIGMAP NAME>
```

8. Scale the app back up

```sh
kubectl scale deployment <DEPLOYMENT NAME> -n <NAMESPACE> --replicas=1
```
