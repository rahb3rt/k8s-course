# Day 1 — Substrate & the Control Plane

Climb from below Kubernetes up: a container built by hand from Linux primitives, then a
control plane assembled from four files on disk, down to the protobuf bytes in etcd —
then kill it and watch what "the cluster is down" really means.

## Labs in this folder
- [`labs/1.1-container-by-hand.sh`](labs/1.1-container-by-hand.sh) — build a container with `unshare`, no Docker
- [`labs/1.4-etcd-breakage.md`](labs/1.4-etcd-breakage.md) — kill etcd, diagnose with kubectl dead, recover

---

## 1. A container is three Linux primitives

There is no "container" — only Linux lying to a process with:
1. **Namespaces** — what a process can *see* (pid, net, mnt, uts, ipc, user).
2. **cgroups v2** — what it can *use* (cpu, memory, io). The OOM killer consults these.
3. **A pivoted rootfs** — an unpacked OCI image it `pivot_root`s into.

Run `labs/1.1-container-by-hand.sh` inside the `sandbox` VM. Observations:
- `ps aux` shows only PID 1 + `ps` → the **PID namespace**. Being PID 1 matters: the
  kernel does **not** apply default signal actions to PID 1, so an app that doesn't
  explicitly handle SIGTERM ignores it → strands pods in `Terminating` (see Day 3).
- `ip addr` shows only `lo`, state DOWN → the **net namespace**. Every pod starts exactly
  like this; the CNI plugin wires it. No CNI → pod stuck `ContainerCreating` (see Day 2).
- `ls /` still shows the whole VM → you never pivoted the rootfs. That's the OCI image's job.

## 2. The bootstrap paradox → static pods

The apiserver, scheduler, controller-manager and etcd all run **as pods** — but pods are
scheduled by the control plane that doesn't exist yet. Resolution: **static pods**. The
kubelet (a plain systemd service, *not* a pod) watches `/etc/kubernetes/manifests/` and
runs any pod manifest there directly — no scheduler, no apiserver, no etcd.

```bash
ls /etc/kubernetes/manifests/     # etcd · kube-apiserver · kube-controller-manager · kube-scheduler
systemctl is-active kubelet       # active — the one thing that isn't a pod
```

The kubelet also creates a read-only **mirror pod** in the API so you can `kubectl get` them.
The **file is truth**, not the API: `kubectl delete pod etcd-cp` → it reappears instantly.

**Why they run before the CNI:** `hostNetwork: true`. They use the node's own network, so
they need no pod IP and no CNI. That's why a fresh node is `NotReady` (no CNI) yet the
control plane is `Running`, while CoreDNS (a normal pod) sits `Pending`.

## 3. The PKI tree (`/etc/kubernetes/pki/`)

```
ca.crt / ca.key ......... cluster ROOT CA — everything chains to it
apiserver.crt ........... API server serving cert; its SANs include the advertise address
apiserver-etcd-client.* . apiserver's client cert to etcd (signed by the SEPARATE etcd CA)
sa.key / sa.pub ......... signs ServiceAccount tokens — leak sa.key = forge any identity
etcd/ ................... etcd's own CA + certs — its own trust domain
```
Most security-critical file: `sa.key`. Most availability-critical: `etcd/` + `/var/lib/etcd`.

## 4. etcd is truth; the apiserver is its only interpreter

etcd requires mutual TLS (`--client-cert-auth=true`). Read it via the etcdctl binary
inside the (distroless — no shell!) etcd image:

```bash
ectl() { kubectl -n kube-system exec -i etcd-cp -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key "$@"; }

ectl member list -w table
ectl get /registry --prefix --keys-only | wc -l          # ~286 objects in an "empty" cluster
ectl get /registry/pods/kube-system/etcd-cp              # binary PROTOBUF, not JSON
```
Objects are stored as **protobuf**; only the apiserver encodes/decodes it. That's the
technical reason "everything goes through the apiserver" is architecture, not etiquette.
A 40-line manifest is stored as KB of status, QoS, digests and `managedFields` (SSA).

---

## Takeaways
- A container = namespaces + cgroups + rootfs. Every weird-pod bug bottoms out here.
- The control plane bootstraps from disk (static pods) and dodges the CNI via `hostNetwork`.
- etcd holds state (protobuf); the apiserver gives it meaning.
- **Control plane down ≠ workloads down** (proven in Lab 1.4).
- `refused` = process not listening; `timeout` = process stuck on a dependency.
- Data outlives process: `/var/lib/etcd` survives an etcd restart (→ Day 4 restore drill).
