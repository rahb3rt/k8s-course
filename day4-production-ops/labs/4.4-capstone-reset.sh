#!/bin/bash
# Reset the capstone incident (safety net — ideally you fix each fault by hand as you find it).
set -uo pipefail
kubectl -n kube-system scale deployment coredns --replicas=2 >/dev/null 2>&1
kubectl delete deployment shop --ignore-not-found >/dev/null 2>&1
echo "capstone cleared at $(date +%T)"
