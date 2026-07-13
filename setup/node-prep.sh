#!/bin/bash
# Runs INSIDE each Linux VM as root. Prepares an Ubuntu 24.04 node for kubeadm.
# Idempotent-ish; safe to re-run.
set -euxo pipefail

### 1. Disable swap ----------------------------------------------------------
# The kubelet refuses to start with swap enabled (default). Its scheduling and
# OOM accounting assume no swap; a node that swaps hides memory pressure the
# scheduler needs to see. This is a hard kubeadm preflight failure if skipped.
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

### 2. Kernel modules --------------------------------------------------------
# overlay      -> the overlayfs snapshotter containerd uses for image layers
# br_netfilter -> makes bridged (pod) traffic traverse iptables so kube-proxy
#                 and NetworkPolicy rules actually apply to it
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

### 3. sysctls ---------------------------------------------------------------
# bridge-nf-call-iptables: without it, packets crossing the pod bridge bypass
#   iptables entirely -> Services silently don't work. Extremely common gotcha.
# ip_forward: the node must route between pod netns and the outside world.
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

### 4. containerd (the CRI runtime kubelet talks to) -------------------------
apt-get update
# conntrack: required by kube-proxy (iptables Service NAT tracks flows here) -
#   kubeadm treats it as a FATAL preflight error if missing.
# socat: used by 'kubectl port-forward'. ethtool: CNI/kube-proxy NIC tuning.
apt-get install -y containerd apt-transport-https ca-certificates curl gpg \
                   conntrack socat ethtool
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
# THE classic kubeadm failure: kubelet defaults to the 'systemd' cgroup driver,
# but containerd's default config uses 'cgroupfs'. A mismatch means the kubelet
# and runtime manage cgroups differently -> kubelet won't come up and you get
# a cryptic "failed to run Kubelet" loop. Force containerd to systemd too.
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

### 5. kube* packages (pinned to 1.31) ---------------------------------------
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
# Hold them so an unattended apt upgrade can't skew versions across nodes.
apt-mark hold kubelet kubeadm kubectl

echo "NODE PREP COMPLETE: $(hostname)"
