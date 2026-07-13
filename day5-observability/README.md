# Day 5 — Observability: Prometheus & Grafana

Deploy the **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager + node-exporter +
kube-state-metrics) with Helm, and learn the pull-based metrics pipeline. Browsable:
[`docs/day5.html`](../docs/day5.html).

## The metrics pipeline
Prometheus is **pull-based**: it scrapes HTTP `/metrics` endpoints on a schedule and stores
time series. The pieces:

| Component | Job |
|-----------|-----|
| **node-exporter** | Per-node DaemonSet — host metrics (CPU, mem, disk, net) |
| **kube-state-metrics** | Turns API objects into metrics (pod phase, restarts, replicas, PVC status) |
| **Prometheus** | Scrapes targets, stores TSDB, evaluates alert rules (query with PromQL) |
| **ServiceMonitor / PodMonitor** | CRDs telling Prometheus *what* to scrape (a Phase-2 preview: the API extended with CRDs) |
| **Alertmanager** | Dedups/groups/routes fired alerts (Slack, PagerDuty…) |
| **Grafana** | Dashboards over Prometheus data |

## Segments (filled in as we run them)
- **5.1** Install Helm + `kube-prometheus-stack`
- **5.2** Reach Grafana (port-forward, login, tour dashboards)
- **5.3** PromQL over your own Day-3 history (restarts, OOMKills, QoS)
- **5.4** Scrape a workload with a ServiceMonitor + a firing alert
