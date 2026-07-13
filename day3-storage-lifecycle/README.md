# Day 3 — Storage, Lifecycle & the OOM Killer

State and time: how pods are torn down, who the kernel kills under memory pressure, and
how data outlives the pod that wrote it.

## In this folder (`manifests/`)
- `stubborn-pod.yaml` — a pod that ignores SIGTERM
- `qos-pods.yaml` — Guaranteed / Burstable / BestEffort in one file
- `oom-victim.yaml` — asks for 300Mi under a 128Mi limit
- `pvc-data.yaml`, `writer-pod.yaml`, `reader-pod.yaml` — dynamic provisioning + persistence
- `statefulset-sts.yaml` — headless Service + StatefulSet with per-pod volumes
- `local-path-provisioner.md` — installing the storage "actor"

---

## Segment 1 — How a pod dies

Graceful shutdown sequence when you `kubectl delete` a pod:
1. Pod gets a `deletionTimestamp` → `Terminating`.
2. **In parallel:** removed from Service endpoints (stops new traffic) **and** shutdown begins.
3. `preStop` hook runs (if any).
4. Runtime sends **SIGTERM** to PID 1.
5. Kubelet waits up to **`terminationGracePeriodSeconds`** (default 30).
6. Still alive? **SIGKILL.**

```bash
kubectl apply -f manifests/stubborn-pod.yaml
kubectl wait --for=condition=Ready pod/stubborn
time kubectl delete pod stubborn        # ~30s — PID 1 ignored SIGTERM, waited out the grace period
```

Two ways SIGTERM gets ignored: an **explicit handler** that does nothing (`trap "" TERM`,
any PID), or **no handler + PID 1** (kernel suppresses default actions for PID 1 — even a
bare `sleep` as PID 1 hangs 30s). Symptom: slow rollouts, pods stuck `Terminating`.
Fixes: handle the signal · add an init shim (tini) · tune the grace period.

**The nastier cousin:** endpoint removal races the shutdown. A *fast-exiting* app can be
dead while some node's iptables still lists it → 502s mid-rollout. Fix: a `preStop` sleep
(~5–10s) so it keeps serving during the drain window.

## Segment 2 — QoS & the OOM killer

QoS class is **derived** from requests/limits and becomes an `oom_score_adj` the kernel reads:

| QoS | Rule | `oom_score_adj` | Killed |
|-----|------|-----------------|--------|
| Guaranteed | requests == limits (cpu+mem) | **-997** | last (near-immune) |
| Burstable | some requests/limits set | **2–999** (more mem requested → lower/safer) | middle |
| BestEffort | nothing set | **1000** | first |

```bash
kubectl apply -f manifests/qos-pods.yaml
kubectl get pods -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass'
kubectl exec qos-guaranteed -- cat /proc/1/oom_score_adj    # -997
kubectl exec qos-besteffort -- cat /proc/1/oom_score_adj    # 1000
```

Note: workloads created without resources (`web`, `netlab`) are **BestEffort** → first to die.

```bash
kubectl apply -f manifests/oom-victim.yaml
kubectl get pod oom-victim -w                                  # STATUS: OOMKilled
kubectl describe pod oom-victim | grep -A3 'Reason\|Exit Code'  # Reason OOMKilled, exit 137 (=128+9, SIGKILL)
limactl shell worker -- 'sudo dmesg | grep -i "killed process" | tail -5'   # the kernel's record
```

**Two different OOMs:**
- **Per-container (what this lab did):** exceeded your own `limits.memory` → deterministic
  cgroup kill, QoS-irrelevant. Fix: raise the limit or fix the leak.
- **Node-level:** node is full → kubelet **evicts** by QoS (BestEffort first) before the
  kernel OOM killer fires and kills by `oom_score_adj`.

## Segment 3 — Storage

Chain: `Pod → PVC (claim) → PV (volume) → StorageClass → provisioner`. A claim is inert
until an actor exists (same pattern as NetworkPolicy).

```bash
kubectl apply -f manifests/pvc-data.yaml
kubectl get pvc data                 # Pending — no provisioner / no StorageClass yet
kubectl get storageclass             # No resources found
```

Install the actor (see `manifests/local-path-provisioner.md`), then:

```bash
kubectl get storageclass             # local-path (WaitForFirstConsumer)
kubectl apply -f manifests/writer-pod.yaml    # a consumer → triggers binding on schedule
kubectl wait --for=condition=Ready pod/writer
kubectl get pvc data                 # now Bound
kubectl get pv                       # a PV that didn't exist before — dynamically provisioned
```

`WaitForFirstConsumer` delays PV creation until a pod schedules, so node-local volumes land
on the right node. **Persistence proof:**

```bash
kubectl delete pod writer
kubectl apply -f manifests/reader-pod.yaml     # a NEW pod, same PVC
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/reader --timeout=60s
kubectl logs reader                  # reads the note the deleted writer wrote — data survived
```

**Reclaim policy footgun:** `kubectl get pv` shows `Delete` (default for dynamic volumes) →
deleting the PVC destroys the data. For databases, use `Retain`.

## Segment 3b — StatefulSets

Deployments give anonymous cattle. Databases need stable identity: ordinal names, per-pod
private storage, ordered lifecycle, per-pod DNS (via a headless Service).

```bash
kubectl apply -f manifests/statefulset-sts.yaml
kubectl get pods -l app=sts -w       # sts-0 Ready BEFORE sts-1 starts (ordered)
kubectl get pvc                      # data-sts-0, data-sts-1 — one private volume per pod
# Identity + storage proof:
kubectl logs sts-0                   # one boot line
kubectl delete pod sts-0
kubectl wait --for=condition=Ready pod/sts-0 --timeout=60s
kubectl logs sts-0                   # TWO lines — same name, same volume reattached
# Stable per-pod DNS (FQDN — busybox musl won't walk search domains):
kubectl exec sts-1 -- nslookup sts-0.sts.default.svc.cluster.local
```

---

## Takeaways
- Termination is a negotiation with a deadline (SIGTERM → grace → SIGKILL); watch the endpoint-removal race.
- Two OOMs: per-container limit (deterministic) vs node-level (QoS-ordered). Set requests.
- A PVC is inert without a provisioner; `WaitForFirstConsumer` delays binding to a consumer.
- StatefulSets = stable identity + private PVCs + ordered lifecycle + per-pod DNS.
