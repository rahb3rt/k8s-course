#!/bin/bash
# Lab 1.1 — Build a container by hand, no Docker.
# Run INSIDE the sandbox VM:   limactl shell sandbox   then   bash 1.1-container-by-hand.sh
# (or paste the unshare line directly)
#
# This drops you into a shell that is isolated by PID / net / uts / ipc / mount namespaces.
# It does NOT pivot the rootfs, so you still see the host filesystem — that missing third
# leg is exactly what an OCI image provides.

echo ">>> Entering a hand-rolled container (namespaced shell). Try these inside it:"
echo "      hostname isolated-box   # uts namespace — host hostname is unaffected"
echo "      ps aux                  # pid namespace — you are PID 1, you see almost nothing"
echo "      ip addr                 # net namespace — only 'lo', and it's DOWN"
echo "      ls /                    # NOT isolated — no pivot_root, so you see the whole VM"
echo "      exit                    # leave"
echo

sudo unshare --pid --fork --mount-proc --uts --net --ipc --mount bash
