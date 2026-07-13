#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────
#  CAPSTONE — multi-fault incident injector.  DO NOT READ (this is the key).
#  Run it blind:   bash 4.4-capstone-break.sh
#  Reset when done: bash 4.4-capstone-reset.sh
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Fault A — a freshly "deployed" app
kubectl delete deployment shop --ignore-not-found >/dev/null 2>&1
kubectl create deployment shop --image=nginx:1.27 --replicas=2 >/dev/null 2>&1
kubectl set resources deployment shop --requests=memory=100Gi,cpu=32 >/dev/null 2>&1

# Fault B — a cluster-wide gremlin
kubectl -n kube-system scale deployment coredns --replicas=0 >/dev/null 2>&1

echo "incident injected at $(date +%T). you are being paged."
