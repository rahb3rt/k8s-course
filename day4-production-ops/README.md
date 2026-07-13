# Day 4 — Production Operations  ⏳ (upcoming)

The drills that separate people who *run* clusters from people who deploy to them. Labs
and manifests will be filled in here as we do them.

## Planned

### 4.1 — etcd backup & restore (the dark twin of Lab 1.4)
On Day 1 you stopped etcd's *process* and lost nothing. Here you **destroy its data** and
resurrect the entire cluster from a snapshot.
- `etcdctl snapshot save` → a point-in-time backup
- simulate disaster: wipe `/var/lib/etcd`
- `etcdctl snapshot restore` → new data dir → repoint etcd → cluster returns
- Lesson: this is why single-node etcd is a SPOF and prod runs 3/5 members.

### 4.2 — Certificate expiry & rotation
Deliberately expire an API server cert (from the PKI tree toured on Day 1), watch the
cluster lock *itself* out, then rotate certs back to health.
- `kubeadm certs check-expiration`
- `kubeadm certs renew all` + restart control-plane static pods
- update kubeconfigs.

### 4.3 — Upgrades, drain, cordon & PDBs
Move workloads off a node safely and roll a version bump.
- `kubectl cordon` / `drain` (respecting PodDisruptionBudgets)
- `kubeadm upgrade plan` / `apply`; upgrade kubelet per node
- why a PDB can *block* a drain (and how to reason about it).

### 4.4 — Capstone: multi-fault incident
Several failures injected at once. You drive the diagnosis (scaffolded), using the method
and the whole toolkit from Days 1–3.

## Optional side-quest (any time)
Install **Calico** policy enforcement so the Day-2 `deny-web` NetworkPolicy actually bites —
watch the same `wget` that succeeded under Flannel start timing out.
