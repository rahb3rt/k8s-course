# Runbook — kubeadm minor-version upgrade (1.31 → 1.32)

Order is invariant: **kubeadm tool → components → kubelet**, **control plane first, then each
node**, **one minor at a time**. kubelet may trail the API server by ≤3 minors, never lead.

## 0. Before you start
```bash
# Snapshot etcd (Day 4.1) — always back up before an upgrade
kubectl -n kube-system exec -i etcd-lima-cp -- etcdctl \
  --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/pre-upgrade.db && sudo cp /var/lib/etcd/pre-upgrade.db /root/
```

## 1. Control plane (on cp)
```bash
sudo sed -i 's|/v1.31/|/v1.32/|' /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm | head          # find the 1.32 patch (e.g. 1.32.13-1.1)

sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm='1.32.*' && sudo apt-mark hold kubeadm
kubeadm version                            # confirm v1.32.x

sudo kubeadm upgrade plan                  # shows current vs target + what upgrades
sudo kubeadm upgrade apply v1.32.13 -y     # use the EXACT version (not a placeholder!)
```
`upgrade apply` swaps the static pods one at a time (backups in `/etc/kubernetes/tmp/`) and
renews all certs. Then upgrade cp's kubelet:
```bash
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet='1.32.*' kubectl='1.32.*' && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl get nodes            # lima-cp -> v1.32.13, worker still 1.31 (valid mixed state)
```

## 2. Each worker
```bash
# on the WORKER:
sudo sed -i 's|/v1.31/|/v1.32/|' /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm='1.32.*' && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node                  # upgrades local kubelet config + certs

# on CP:
kubectl drain lima-worker --ignore-daemonsets --delete-emptydir-data
#   (single-worker cluster -> pods go Pending until uncordon; multi-worker -> reschedule, zero downtime)

# on the WORKER:
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet='1.32.*' kubectl='1.32.*' && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# on CP:
kubectl uncordon lima-worker
kubectl get nodes            # ALL nodes v1.32.13
```

## Notes
- `kubeadm upgrade plan` will show newer minors (e.g. 1.36) but you target only the next one.
- If a drain stalls on a PodDisruptionBudget → Day 4.3: check `kubectl get pdb -A`, ensure spread/capacity.
- Rollback: the pre-upgrade static-pod manifests are in `/etc/kubernetes/tmp/kubeadm-backup-manifests-*`.
- Prometheus on emptyDir loses data on reschedule → give it a PVC in production.
