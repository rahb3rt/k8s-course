# Phase 2 — The Architect Track

From *using* the Kubernetes API to *extending* it; from running one cluster to designing a
fleet. **Full-spectrum** coverage (platform + product + infra). Operator builds in
**Go + kubebuilder**. Browsable HTML: [`docs/architect.html`](../docs/architect.html).

> The bridge from Phase 1: *"the API stores intent; something must enforce it."* That
> "something" is a **controller**. An operator observes controllers; **an architect writes
> them.** Every module ends with a **decision framework** — architecture is judgment.

| # | Module | You'll build |
|---|--------|--------------|
| A1 | **The controller pattern** — reconciliation, level-triggered control | shell reconciler → CRD + kubebuilder controller |
| A2 | **Extending the API** — CRDs, admission webhooks, finalizers, policy-as-code | a validating webhook + a Kyverno/OPA policy |
| A3 | **Scaling & scheduling** — HPA/VPA/CA/Karpenter, affinity, priority, cost | an autoscaling design under load test |
| A4 | **Platform architecture** — CNI/ingress/Gateway API/mesh, multi-tenancy | a defended tenancy + network design |
| A5 | **Delivery & fleet** — GitOps (Argo/Flux), Helm/Kustomize, multi-cluster | a GitOps pipeline for the lab |
| A6 | **Reliability & security** — DR/Velero, RBAC/PSA, supply chain, secrets, SLOs | a security posture + DR runbook |
| A7 | **Capstone** — reference-architecture review | a full design, adversarially defended |

Each module lands here as `aN-*/` with lesson + labs as we complete it, mirrored into
`docs/` as styled HTML pages.
