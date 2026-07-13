#!/bin/bash
# Timestamped, verified, self-pruning etcd snapshot. Run on the control-plane node.
# Cron example (hourly):  0 * * * * BACKUP_DIR=/var/backups/etcd /path/etcd-backup.sh
# Requires: kubectl (admin.conf) + etcdutl on the host for the verify step.
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/var/backups/etcd}
KEEP=${KEEP:-7}                       # how many snapshots to retain
TS=$(date +%Y%m%d-%H%M%S)
POD=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')

sudo mkdir -p "$BACKUP_DIR"

# Snapshot into the mounted data dir (only path the distroless etcd pod can write), then move out.
kubectl -n kube-system exec -i "$POD" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save "/var/lib/etcd/snap-$TS.db"
sudo mv "/var/lib/etcd/snap-$TS.db" "$BACKUP_DIR/"

# Verify — a backup you didn't verify is not a backup.
etcdutl snapshot status "$BACKUP_DIR/snap-$TS.db" -w table

# Prune everything older than the newest $KEEP.
ls -1t "$BACKUP_DIR"/snap-*.db 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r sudo rm -f

echo "etcd backup OK: $BACKUP_DIR/snap-$TS.db"
