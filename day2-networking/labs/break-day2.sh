#!/bin/bash
# ── Day 2 fault injection ──────────────────────────────────────────────
# STOP. Reading this file is reading the answer key. Close it and run it
# blind if you want the real on-call experience. Recovery is handed to you
# by your mentor once you've found root cause (or run break-day2-fix.sh).
# ───────────────────────────────────────────────────────────────────────
set -euo pipefail
iptables -I INPUT 1 -p udp --dport 8472 -j DROP
echo "fault injected on $(hostname) at $(date '+%H:%M:%S')"
