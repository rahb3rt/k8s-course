# Installing the storage provisioner (the "actor")

A `kubeadm` cluster ships **no** default StorageClass or provisioner, so PVCs stay
`Pending`. Rancher's `local-path-provisioner` gives you a working dynamic provisioner that
carves PVs out of a directory on each node — perfect for a lab.

## Install

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl -n local-path-storage rollout status deploy/local-path-provisioner
kubectl get storageclass          # local-path  (VOLUMEBINDINGMODE: WaitForFirstConsumer)
```

This creates:
- namespace `local-path-storage` + the provisioner Deployment (the actor watching PVCs)
- a StorageClass named `local-path`, binding mode **WaitForFirstConsumer**

## Binding modes

- **Immediate** — provision the PV as soon as the PVC is created.
- **WaitForFirstConsumer** (local-path default) — wait until a **pod using the PVC is
  scheduled**, then provision the PV on that pod's node. Correct for node-local storage.
  Consequence: a PVC with no consumer sits `Pending` with
  `waiting for first consumer to be created before binding` — not an error.

## Optional: make it the default StorageClass

```bash
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
Note: PVCs created *before* a default existed keep an empty `storageClassName` and won't
retroactively use it — recreate them, or set `storageClassName: local-path` explicitly.
