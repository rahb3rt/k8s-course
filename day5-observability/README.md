# Day 5 — Observability: Prometheus & Grafana ✅

Deployed the **kube-prometheus-stack** with Helm and learned the pull-based metrics pipeline.
Browsable: [`docs/day5.html`](../docs/day5.html).

## The metrics pipeline
Prometheus is **pull-based**: it scrapes HTTP `/metrics` endpoints on a schedule.

| Component | Job |
|-----------|-----|
| **node-exporter** | DaemonSet — one per node — host metrics (CPU, mem, disk, net) |
| **kube-state-metrics** | API objects → metrics (pod phase, restarts, replicas, PVC status) |
| **Prometheus** | Scrapes targets, stores TSDB, evaluates rules (query: PromQL) |
| **ServiceMonitor / PrometheusRule** | CRDs telling the operator *what to scrape* / *what to alert on* |
| **Alertmanager** | Dedups/groups/routes fired alerts |
| **Grafana** | Dashboards over Prometheus |

## 5.1 — Install with Helm
```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.retention=3h \
  --set prometheus.prometheusSpec.resources.requests.memory=300Mi
kubectl -n monitoring get pods
```
`node-exporter` is a DaemonSet (one per node); `kube-state-metrics` is a single Deployment.
The `2/2` / `3/3` READY counts are operator-injected config-reloader / dashboard sidecars.

## 5.2 — Reach Grafana
```bash
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80   # open http://localhost:3000 (Lima forwards it)
```
Log in as `admin`. Pre-built `Kubernetes / …` and `Node Exporter / Nodes` dashboards are
already populated.

## 5.3 — Query with PromQL (Grafana → Explore)
```promql
sort_desc(kube_pod_container_status_restarts_total)     # kube-apiserver's restart scars from Days 1 & 4
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```
**Observability is not retroactive:** Prometheus only knows what it scraped since it started.
Deploy monitoring *before* the incident.

Generate a live event to observe: `kubectl apply -f manifests/oom-live.yaml`, then watch
`kube_pod_container_status_restarts_total{pod="oom-live"}` climb.

## 5.4 — ServiceMonitors, PrometheusRules & a firing alert
```bash
kubectl get servicemonitor -A                 # ~a dozen — one per component
kubectl apply -f manifests/oom-live-alert.prometheusrule.yaml
# Grafana Explore, ~1-2 min later:  ALERTS{alertname="OomLiveCrashLooping"}  -> pending -> firing
```
The **Prometheus Operator** watches `ServiceMonitor`/`PrometheusRule` CRDs and reconciles them
into running config — **the controller pattern you build in Phase 2 A1**. You've been using
an operator all along.

## Cleanup (keep the stack for Day 6)
```bash
kubectl delete pod oom-live
kubectl -n monitoring delete prometheusrule oom-live-alert
```

## Takeaways
- Pull-based pipeline: scrape → exporters → TSDB → Grafana → Alertmanager.
- Operators reconcile CRDs (ServiceMonitor/PrometheusRule) — a live preview of the controller pattern.
- Monitor **before** the incident; there's no history for what you weren't scraping.
- Helm = platform delivery: six components, one chart, dozens of objects.
