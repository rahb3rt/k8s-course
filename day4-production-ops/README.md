# Day 4 — Production Operations  ⏳ (upcoming)

The drills that separate people who *run* clusters from people who deploy to them. Labs
and manifests will be filled in here as we do them.

## Planned

### 4.1 — etcd backup & restore ✅ (the dark twin of Lab 1.4)
Destroyed `/var/lib/etcd` and rebuilt the cluster from a verified snapshot (RTO ≈ 2 min).
Full runbook: [`labs/4.1-etcd-backup-restore.md`](labs/4.1-etcd-backup-restore.md) · cron-able
backup script: [`labs/etcd-backup.sh`](labs/etcd-backup.sh).
- Proved **RPO** with two canaries: the one created after the snapshot was gone on restore.
- Restore flags (`--name` / `--initial-cluster` / `--initial-advertise-peer-urls`) must match
  the running etcd, or the member won't rejoin.
- Single-node etcd is a SPOF (prod runs 3/5) — but quorum protects against node loss, not
  corruption, so you still need verified snapshots + a tested runbook.

### 4.2 — Certificate expiry & rotation ✅
Rotated all leaf certs with the CAs left untouched. Full runbook:
[`labs/4.2-cert-rotation.md`](labs/4.2-cert-rotation.md).
- Two tiers: leaf certs ~1yr, CAs ~10yr. Rotation re-signs leaves with the same CAs.
- Gotcha: `renew all` is a no-op until you **restart the static pods** (running apiserver
  holds the old cert in memory) and refresh `admin.conf` into `~/.kube/config`.
- `kubeadm upgrade` renews certs as a side effect → "upgrade yearly" *is* rotation.

### 4.3 — Upgrades, drain, cordon & PDBs ✅
Watched a `minAvailable: 2` PDB block a drain (2 replicas, 1 worker → nowhere to go). Runbook:
[`labs/4.3-drain-pdb-upgrades.md`](labs/4.3-drain-pdb-upgrades.md).
- cordon → drain → PDB honored; DaemonSet pods skipped.
- PDB + spare capacity + node spread = safe rolling upgrades; PDB without capacity = stuck drain.
- Upgrade: control plane first, one minor at a time; kubelet lags apiserver ≤3 minors.

### 4.4 — Capstone: multi-fault incident
Several failures injected at once. You drive the diagnosis (scaffolded), using the method
and the whole toolkit from Days 1–3.

## Optional side-quest (any time)
Install **Calico** policy enforcement so the Day-2 `deny-web` NetworkPolicy actually bites —
watch the same `wget` that succeeded under Flannel start timing out.
