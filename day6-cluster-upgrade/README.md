# Day 6 — Cluster Upgrades

The hands-on version of Day 4.3: take this cluster from one minor version to the next —
control plane first, then each node — without dropping workloads. Browsable:
[`docs/day6.html`](../docs/day6.html).

## Rules (version skew)
- **One minor at a time** (1.31 → 1.32, never 1.31 → 1.33).
- **Control plane leads, nodes follow.**
- **kubelet may lag the API server by ≤ 3 minors, never lead it.**
- **Drain before upgrading a node** — the Day-4.3 drill is step one of every node upgrade.

## Flow (filled in as we run it)
1. **Plan** — repoint the kube apt repo to the new minor, `kubeadm upgrade plan`.
2. **Control plane** — `kubeadm upgrade apply v1.32.x` on cp (upgrades static-pod components, renews certs).
3. **cp node** — drain cp, `apt install` new kubelet/kubectl, restart kubelet, uncordon.
4. **worker** — `kubeadm upgrade node`, drain, upgrade kubelet, uncordon (repeat per worker in a fleet).
5. **Verify** — `kubectl get nodes` shows the new version on every node.
