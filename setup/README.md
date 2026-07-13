# Setup — Bootstrap the cluster from zero

Builds a 2-node `kubeadm` cluster on an Apple Silicon Mac using Lima VMs.

## 0. Prerequisites (on the Mac)

```bash
brew install lima kubectl
```

## 1. Create the VMs

Two Ubuntu 24.04 arm64 VMs on Apple's hypervisor (`vz`), joined to Lima's `user-v2`
network so they can reach **each other**, not just the host.

```bash
limactl start --name=cp     --vm-type=vz --tty=false \
  --set '.cpus=2 | .memory="4GiB" | .disk="20GiB" | .networks=[{"lima":"user-v2"}]' \
  template://ubuntu-24.04

limactl start --name=worker --vm-type=vz --tty=false \
  --set '.cpus=2 | .memory="4GiB" | .disk="20GiB" | .networks=[{"lima":"user-v2"}]' \
  template://ubuntu-24.04

# Confirm they can talk (find each IP with: limactl shell cp -- ip -brief addr)
limactl shell cp -- ping -c3 192.168.104.3
```

## 2. Prepare both nodes

`node-prep.sh` disables swap, loads kernel modules, sets the bridge sysctls, installs
containerd (with the critical `SystemdCgroup = true`), and installs kube* 1.31.
Read it — two lines in it are the #1 causes of a broken kubelet and broken Services.

```bash
limactl shell cp     -- sudo bash < node-prep.sh
limactl shell worker -- sudo bash < node-prep.sh
```

## 3. Init the control plane (on cp)

```bash
limactl shell cp -- sudo kubeadm init \
  --apiserver-advertise-address=192.168.104.1 \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=stable-1.31
```

- `--apiserver-advertise-address` must be cp's `user-v2` IP — it's baked into the API
  server's serving cert (SAN). Wrong value → TLS handshake failures from the worker.
- `--pod-network-cidr=10.244.0.0/16` is Flannel's default **and** disjoint from the node
  net `192.168.104.0/24` (overlapping pod/node CIDRs is a nasty routing bug).

Save the `kubeadm join ...` line it prints.

## 4. Wire up kubectl (on cp)

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes    # NotReady until CNI is installed (expected!)
```

## 5. Install the CNI (Flannel)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl get nodes -w   # cp flips to Ready within ~30s; Ctrl-C when Ready
```

## 6. Join the worker

```bash
limactl shell worker -- sudo kubeadm join 192.168.104.1:6443 \
  --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

## Lifecycle

```bash
limactl stop  cp worker sandbox   # free RAM (state persists on disk)
limactl start cp worker           # resume with everything intact
```
