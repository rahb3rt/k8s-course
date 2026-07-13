#!/bin/bash
# Day 2 recovery — undo the fault injected by break-day2.sh.
set -euo pipefail
# Remove the rule (ignore error if already gone), then confirm.
iptables -D INPUT -p udp --dport 8472 -j DROP 2>/dev/null || true
echo "fault cleared on $(hostname) at $(date '+%H:%M:%S')"
