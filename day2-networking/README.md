# Day 2 — Networking & the Dataplane

How a `10.244.x.x` pod packet crosses a `192.168.104.0/24` link the VMs don't route pod
IPs on — traced end to end, then broken and fixed by hand.

## In this folder
- [`manifests/netlab.yaml`](manifests/netlab.yaml) — a busybox pod with ping/wget/nslookup for testing
- [`manifests/deny-web.networkpolicy.yaml`](manifests/deny-web.networkpolicy.yaml) — the deny-all that does nothing under Flannel
- [`labs/break-day2.sh`](labs/break-day2.sh) / [`labs/break-day2-fix.sh`](labs/break-day2-fix.sh) — the overlay-drop breakage + recovery

---

## 1. The model: IP-per-pod flat network

Every CNI must satisfy: every pod gets a **real, unique, routable IP**; every pod reaches
every other pod **directly, no NAT**; nodes can reach all pods. Two implementations:

- **Same-node** pod↔pod: a Linux bridge (`cni0`) + a **veth pair** per pod (a virtual cable,
  one end in the bridge, other end is the pod's `eth0`). Pure L2, no encapsulation.
- **Cross-node** pod↔pod: a **VXLAN overlay** (`flannel.1`). The pod packet is wrapped in a
  node-to-node UDP packet.

**The routing table IS the decision:**
```
10.244.1.0/24 dev cni0                          # this node's pods → bridge (local)
10.244.0.0/24 via 10.244.0.0 dev flannel.1 ...  # other node's pods → VXLAN tunnel
```

## 2. Trace the packet (two layers, one ping)

```bash
kubectl apply -f manifests/netlab.yaml
# Worker terminal 1 — the WIRE (encapsulated):   sudo tcpdump -ni eth0 udp port 8472
# Worker terminal 2 — the TUNNEL exit (decap):   sudo tcpdump -ni flannel.1 icmp
kubectl exec netlab -- ping -c3 <a-coredns-pod-IP-on-cp>   # e.g. 10.244.0.x
```
`flannel.1` shows the inner `10.244→10.244` ICMP; `eth0` shows the **same** packet wrapped
as `192.168.104.3 → .1 : UDP/8472` (tcpdump mislabels 8472 as "OTV" — it's VXLAN).
Overhead = 50 bytes → **pod MTU is 1450**, not 1500. "Small requests work, big ones hang"
= suspect MTU.

## 3. A Service is just iptables rules

```bash
kubectl expose deployment web --port=80
kubectl get svc web                                # note the ClusterIP (10.96.x.x / 10.106.x.x)
sudo iptables-save -t nat | grep <clusterIP>       # KUBE-SERVICES → KUBE-SVC-xxxx
sudo iptables-save -t nat | grep KUBE-SVC-xxxx      # probability chain → KUBE-SEP-yyyy (DNAT)
```
The ClusterIP exists nowhere as an interface — it's only a match target. `KUBE-SVC`
load-balances by `statistic mode random probability` (a chain of biased coin flips that
sum to fair shares); each `KUBE-SEP` does the `DNAT` to a real pod. `KUBE-MARK-MASQ`
(`! -s 10.244.0.0/16`) SNATs off-pod-network sources so replies return. conntrack pins the pick.

## 4. Breakage (self-driven) — the vanishing replies

`labs/break-day2.sh` inserts `iptables -I INPUT 1 -p udp --dport 8472 -j DROP` on the worker.
Symptom: cross-node pod traffic (and DNS to CoreDNS on cp) dies; same-node is fine.

Diagnosis with the method:
- **Reproduce:** `kubectl exec netlab -- ping <cp-pod>` → 100% loss.
- **Narrow:** ping a same-node pod → works. So it's **cross-node** only.
- **Walk the path:** `tcpdump` on `eth0` vs `flannel.1`. The reply appears on `eth0` (the
  wire) but never on `flannel.1` (post-decap) → it's dropped **between** them. tcpdump taps
  *before* netfilter, so the gap = the `INPUT` chain.
- **Inspect:** `sudo iptables -L INPUT -n -v --line-numbers` → a `DROP udp dpt:8472` with a
  climbing packet counter. Root cause: firewall eating inbound VXLAN.
- **Fix & verify:** `labs/break-day2-fix.sh`, then re-test **DNS** (the reported symptom),
  not just ping.

**Real-world signature:** same-node OK + cross-node broken + DNS timeouts = a firewall /
security group blocking the overlay port (8472 Flannel VXLAN, 4789 std VXLAN, 179 Calico BGP).

## 5. NetworkPolicy does nothing (under Flannel)

```bash
kubectl apply -f manifests/deny-web.networkpolicy.yaml
kubectl get netpol                                  # exists, stored in etcd
kubectl exec netlab -- wget -qO- --timeout=3 http://<web-pod-IP>   # STILL works
kubectl delete networkpolicy deny-web
```
A NetworkPolicy is **intent**. Enforcement is delegated to the CNI; Flannel has no policy
engine, so it's accepted, stored, and **silently ignored — fails open**. Enforce with a
policy CNI (Calico/Cilium) and always test a deny to confirm traffic actually stops.

---

## Takeaways
- Flat pod IPs; same-node = bridge, cross-node = VXLAN; the routing table chooses.
- A Service is a NAT illusion (iptables DNAT + conntrack), not a process.
- DNS: a *response* (even `NXDOMAIN`) means the path works; a *timeout* means it's dead.
  `ndots:5` + search domains make short names cost 4–5 lookups — prefer FQDNs.
- The API stores intent; something must enforce it (NetworkPolicy ⇒ a policy CNI).
- **You have a debugging method now.** See the top-level README.
