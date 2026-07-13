#!/bin/bash
# A1.1 — a reconciler in 15 lines. The whole controller pattern, no framework.
# Keeps deployment/web pinned to the replica count in configmap "desired-state".
# Run it, then in another terminal: kubectl scale deploy web --replicas=1  -> watch it self-heal.
#
# Setup:
#   kubectl create deployment web --image=nginx --replicas=2
#   kubectl create configmap desired-state --from-literal=web-replicas=3
while true; do
  desired=$(kubectl get cm desired-state -o jsonpath='{.data.web-replicas}' 2>/dev/null)
  actual=$(kubectl get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -n "$desired" ] && [ "$desired" != "$actual" ]; then
    echo "$(date +%T)  reconcile: web replicas $actual -> $desired"
    kubectl scale deployment web --replicas="$desired"
  fi
  sleep 5   # <-- the RequeueAfter of the shell world (level-triggered resync)
done
