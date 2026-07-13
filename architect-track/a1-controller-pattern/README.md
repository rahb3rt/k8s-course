# A1 — The Controller Pattern ✅

The operator → architect crossing. Build a **CRD + controller** in Go with kubebuilder that
pins a Deployment's replica count and self-heals drift — the same loop the ReplicaSet
controller and every operator (incl. the Day-5 Prometheus Operator) runs.

Browsable: [`docs/architect.html#a1`](../../docs/architect.html#a1).

## The idea
A controller is a loop: **observe desired → observe actual → act to close the gap → repeat.**
**Level-triggered** (reconcile to current truth), not edge-triggered (react to events) — so it
heals even after a crash. Desired state = a spec you declare; the controller drives reality to it.

## A1.1 — Feel the loop (no framework)
`shell-reconciler.sh` is the whole pattern in 15 lines of bash: keep `deployment/web` at the
replica count in a ConfigMap. Run it, then `kubectl scale deploy web --replicas=1` and watch it
self-heal. That "nothing told it — it just observed and corrected" is level-triggering.

## A1.2 — Scaffold a real operator (Go + kubebuilder)
Toolchain (on cp; work in the writable guest home `~`, NOT the read-only `/Users/...` mount):
```bash
GOVER=$(curl -sL https://go.dev/VERSION?m=text | head -1)
curl -sL https://go.dev/dl/${GOVER}.linux-arm64.tar.gz | sudo tar -C /usr/local -xzf -
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc && source ~/.bashrc
cd ~ && curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/linux/arm64
chmod +x kubebuilder && sudo mv kubebuilder /usr/local/bin/
sudo apt-get install -y make build-essential          # kubebuilder projects are Makefile-driven

mkdir -p ~/replicapin-operator && cd ~/replicapin-operator
kubebuilder init --domain quarx.co --repo quarx.co/replicapin
kubebuilder create api --group ops --version v1 --kind ReplicaPin --resource --controller
# (group is 'ops', NOT 'apps' — 'apps' is a built-in group and collides)
```

## A1.3 — Design the Spec + write Reconcile
- Replace the placeholder `Foo` in `api/v1/replicapin_types.go` with the fields in
  `replicapin-types-spec.go.txt` (`DeploymentName`, `Replicas` + a `Minimum=0` validation marker).
- Replace `internal/controller/replicapin_controller.go` with `replicapin_controller.go` here.
- `make generate && make manifests` — the markers become CRD OpenAPI validation + an RBAC Role.

## A1.4 — Install, run, test
```bash
make install                       # register the CRD in the cluster
make run                           # start the controller (terminal 1; runs vs ~/.kube/config)
kubectl apply -f pin-web.yaml      # create a ReplicaPin (terminal 2)
kubectl get deploy web             # driven to the pinned count

# drift test — healed by the RequeueAfter timer (~10s), because we only WATCH the ReplicaPin:
kubectl scale deploy web --replicas=1

# desired-change test — healed INSTANTLY (a watch event on the ReplicaPin):
kubectl patch replicapin pin-web --type=merge -p '{"spec":{"replicas":5}}'
```

## Takeaways
- A **CRD** adds a validated API type; a **controller** reconciles it — same as any built-in.
- controller-runtime gives you **informers** (watches), a **work queue** (dedup/retry), and generated **RBAC** for free.
- **Watched object changes = instant; drift elsewhere = caught by resync.** Add `.Owns(&appsv1.Deployment{})` to watch the Deployment too.
- kubebuilder **markers** generate the CRD schema and RBAC — declare intent, code is generated.

## Decision framework — controller vs alternatives
- **Operator/controller** when you need ongoing reconciliation of custom state (self-healing, drift correction, lifecycle). 
- **Helm/Kustomize** for one-shot templated installs (no ongoing loop).
- **Job/CronJob** for finite tasks.
- Rule: if it needs to *keep being true*, it's a controller.
