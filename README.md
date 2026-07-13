# Kubernetes from the Ground Up — SRE Field Manual

A four-day, hands-on Kubernetes internals course built on a real `kubeadm` cluster.
Every component gets **dissected, deliberately broken, and debugged**. No black boxes.

> Philosophy: don't learn `kubectl` commands — learn the machinery underneath, so that
> when something breaks you can reason from the packet, the process, and the byte on disk.

Each day follows the same loop: **concept → internals → hands-on lab → deliberate breakage → cold debug → ops takeaways.**

---

## The cluster

| Role | Name | IP | Notes |
|------|------|----|-------|
| control-plane | `cp` | `192.168.104.1` | tainted `NoSchedule` — no workloads land here |
| worker | `worker` | `192.168.104.3` | runs the workloads |
| sandbox | `sandbox` | — | throwaway VM for the namespace lab |

- **Host:** Apple Silicon Mac · **Hypervisor:** Lima (`--vm-type=vz`, Apple Virtualization.framework)
- **Guests:** Ubuntu 24.04 arm64 · **Kubernetes:** v1.31 · **Runtime:** containerd · **CNI:** Flannel (VXLAN)
- **Pod CIDR:** `10.244.0.0/16` (disjoint from the node network — no overlap)

The Mac only *hosts* the Linux VMs. Kubernetes is Linux (namespaces + cgroups are kernel
features that don't exist on macOS), so **all cluster internals run inside the VMs**.
macOS commands: `brew`, `limactl`, `kubectl`. VM commands (after `limactl shell <vm>`):
`kubeadm`, `crictl`, `etcdctl`, `ip`, `iptables`, `dmesg`.

---

## Layout

```
k8s-course/
├── README.md                       ← you are here
├── field-manual.html               ← the visual course tracker (open in a browser)
├── setup/                          ← build the cluster from scratch
│   ├── README.md
│   └── node-prep.sh
├── day1-substrate-control-plane/   ← containers by hand, the control plane, etcd
├── day2-networking/                ← the dataplane, VXLAN, Services, a debugging method
├── day3-storage-lifecycle/         ← termination, QoS/OOM, PV/PVC, StatefulSets
└── day4-production-ops/            ← etcd restore, cert rotation, upgrades (upcoming)
```

Each `dayN-*/` has its own `README.md` (the lesson) plus `manifests/` and/or `labs/`
containing every YAML and script used, split out so you can re-run any lab standalone.

---

## Index

| Day | Topic | Status | The "aha" |
|-----|-------|--------|-----------|
| [Setup](setup/README.md) | Bootstrap the cluster | — | Two VMs, one `kubeadm init` |
| [1](day1-substrate-control-plane/README.md) | Substrate & control plane | ✅ | A container is 3 Linux primitives; the apiserver is etcd's only client |
| [2](day2-networking/README.md) | Networking & the dataplane | ✅ | Services are iptables rules; here's a debugging *method* |
| [3](day3-storage-lifecycle/README.md) | Storage, lifecycle & OOM | ✅ | How pods die, who the kernel kills, how data survives |
| [4](day4-production-ops/README.md) | Production operations | ⏳ | Bring a dead cluster back from an etcd snapshot |

---

## The debugging method (works on any "X can't reach Y")

1. **Reproduce** — see the failure yourself before touching anything.
2. **Narrow** — change one variable to halve it (all traffic or one port? cross-node or same-node? one pod or all?).
3. **Walk the path** — follow the request/packet/process hop by hop; find where it stops.
4. **Inspect at the break** — routes, iptables, logs, cgroups — wherever step 3 pointed.
5. **Fix & verify the original symptom** — not a proxy metric; the thing the user reported.

## Quick start

```bash
# Resume a stopped lab
limactl start cp worker

# Point kubectl at the cluster (from inside cp)
limactl shell cp
kubectl get nodes
```

New cluster from zero → see [`setup/README.md`](setup/README.md).
