# Nephio Networking KPT Packages

This repository contains clean, reusable KPT packages for setting up networking in your Nephio deployment with OAI RAN and Free5GC Core on bare-metal Kubernetes clusters.

## Package Structure

```
networking-packages/
├── multus-cni/                    # Base Multus CNI package
│   ├── Kptfile
│   └── multus-daemonset.yaml
│
├── whereabouts-ipam/              # Whereabouts IPAM package
│   ├── Kptfile
│   └── whereabouts.yaml
│
├── network-intents/               # High-level network definitions
│   ├── Kptfile
│   ├── control-plane.yaml
│   └── user-plane.yaml
│
└── network-attachment-renderer/   # Renders NADs from intents
    ├── Kptfile
    ├── nad-renderer-config.yaml
    └── examples/
        ├── ran-nads.yaml
        └── core-nads.yaml
```

## Package Hierarchy

1. **Foundation Layer**: `multus-cni` + `whereabouts-ipam`
   - Deploy these first on both clusters
   - Provides base CNI capabilities

2. **Intent Layer**: `network-intents`
   - Define your network topology once
   - Cluster-agnostic configuration

3. **Rendering Layer**: `network-attachment-renderer`
   - Generates cluster-specific NADs from intents
   - Customizes for RAN vs Core clusters

## Usage

### Step 1: Deploy Foundation (Both Clusters)

```bash
# Clone packages
kpt pkg get https://github.com/your-repo/networking-packages/multus-cni
kpt pkg get https://github.com/your-repo/networking-packages/whereabouts-ipam

# Deploy to my-ran cluster
kpt live init multus-cni --namespace kube-system
kpt live apply multus-cni --reconcile-timeout=5m

kpt live init whereabouts-ipam --namespace kube-system
kpt live apply whereabouts-ipam --reconcile-timeout=5m

# Repeat for my-core cluster
kubectl config use-context my-core
kpt live apply multus-cni --reconcile-timeout=5m
kpt live apply whereabouts-ipam --reconcile-timeout=5m
```

### Step 2: Customize Network Intents

```bash
# Get the network intents package
kpt pkg get https://github.com/your-repo/networking-packages/network-intents

# Customize for your LAN
cd network-intents
kpt fn eval --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  control-plane-range=192.168.10.0/24 \
  control-plane-gateway=192.168.10.1 \
  user-plane-range=192.168.20.0/24 \
  user-plane-gateway=192.168.20.1 \
  interface-name=ens33 \
  mtu=9000
```

### Step 3: Render NADs for Each Cluster

```bash
# Get renderer package
kpt pkg get https://github.com/your-repo/networking-packages/network-attachment-renderer

# Render for RAN cluster
cd network-attachment-renderer
kpt fn eval --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  target-cluster=my-ran \
  target-namespace=openairinterface

# The KRM function will generate ran-ctrl-net.yaml and ran-user-net.yaml
kpt fn eval --image gcr.io/nephio-project/nad-renderer:v1.0.0 \
  --fn-config nad-renderer-config.yaml

# Apply to RAN cluster
kubectl config use-context my-ran
kpt live init . --namespace openairinterface
kpt live apply . --reconcile-timeout=2m

# Repeat for Core cluster
kpt fn eval --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  target-cluster=my-core \
  target-namespace=free5gc

kpt fn eval --image gcr.io/nephio-project/nad-renderer:v1.0.0 \
  --fn-config nad-renderer-config.yaml

kubectl config use-context my-core
kpt live init . --namespace free5gc
kpt live apply . --reconcile-timeout=2m
```

## Customization Points

### For Your Environment

1. **Interface Names**: Update `interface-name` setter in `network-intents/Kptfile`
   - Default: `eth0`
   - Adjust for your actual interface (e.g., `ens33`, `enp1s0`)

2. **IP Ranges**: Modify in `network-intents/Kptfile`
   ```yaml
   control-plane-range: "10.0.1.0/24"  # Your control plane subnet
   user-plane-range: "10.0.2.0/24"     # Your user plane subnet
   ```

3. **VLAN Tags**: If you need VLANs (though unnecessary for simple LAN)
   ```yaml
   control-plane-vlan: "100"
   user-plane-vlan: "200"
   ```

4. **CNI Plugin**: In `nad-renderer-config.yaml`, change from `macvlan` to `bridge`
   ```yaml
   cniPlugin: "bridge"  # Simpler, but requires more host network config
   ```

### For Different Network Topologies

The beauty of this approach is you can add more network intents:

```yaml
# Add to network-intents/
apiVersion: v1
kind: ConfigMap
metadata:
  name: signaling-network-intent
  annotations:
    nephio.org/network-type: "signaling"
data:
  networkName: "signaling"
  ipRange: "192.168.30.0/24"
  interface: "eth1"
```

The renderer will automatically create NADs for all intents.

## Key Design Decisions

### Why ConfigMaps for Intents?

- **Cluster-agnostic**: Same intent applies to RAN and Core
- **Version controlled**: Easy to track changes
- **Nephio-compatible**: Works with Nephio's reconciliation model
- **Human-readable**: Network architects can understand and modify

### Why Separate Renderer Package?

- **DRY principle**: Define networks once, render many times
- **Testability**: Can validate rendering logic independently
- **Flexibility**: Swap renderers for different CNI plugins
- **Traceability**: NADs reference source intents via annotations

### Why Macvlan Over Bridge?

For your simple 2-node LAN setup:
- **Macvlan**: Each pod gets L2 presence on physical network
  - Pros: Simple, no bridge config needed, pods directly on LAN
  - Cons: Cannot communicate with host via macvlan interface
  
- **Bridge**: Pods connect through Linux bridge
  - Pros: Pods can communicate with host
  - Cons: Requires bridge setup on each node

**Recommendation**: Start with macvlan. If you need pod-to-host communication on secondary networks, switch to bridge mode by changing one line in `nad-renderer-config.yaml`.

## Integration with Nephio Workload Clusters

### Register Clusters
```bash
# Create cluster context for my-ran
kubectl apply -f - <<EOF
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
metadata:
  name: my-ran
  namespace: default
spec:
  clusterName: my-ran
  cnis:
  - macvlan
  - calico
  masterInterface: eth0
EOF

# Repeat for my-core
```

### Link Packages to Clusters
```bash
# In your Nephio management cluster
kpt alpha rpkg init my-ran-networking \
  --repository nephio-my-ran \
  --workspace main \
  --directory networking

kpt alpha rpkg init my-core-networking \
  --repository nephio-my-core \
  --workspace main \
  --directory networking
```

## Verification

After deployment, verify on each cluster:

```bash
# Check Multus
kubectl get pods -n kube-system -l name=multus
kubectl logs -n kube-system -l name=multus --tail=50

# Check Whereabouts
kubectl get pods -n kube-system -l name=whereabouts
kubectl get ippools --all-namespaces

# Check NADs
kubectl get network-attachment-definitions -n openairinterface  # on my-ran
kubectl get network-attachment-definitions -n free5gc          # on my-core

# Test with a debug pod
kubectl run test-pod --image=nicolaka/netshoot --rm -it \
  --annotations="k8s.v1.cni.cncf.io/networks=ran-ctrl-net" \
  --namespace=openairinterface
```

## Troubleshooting

### Multus not attaching networks
```bash
# Check Multus config
kubectl exec -n kube-system ds/kube-multus-ds -- cat /host/etc/cni/net.d/00-multus.conf

# Verify Calico is primary CNI
ls -la /etc/cni/net.d/
```

### Whereabouts IP allocation issues
```bash
# Check IPAM
kubectl get ippools -A
kubectl describe ippool -n <namespace> <pool-name>

# Check for IP conflicts
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.annotations["k8s.v1.cni.cncf.io/networks-status"] != null) | .metadata.annotations["k8s.v1.cni.cncf.io/networks-status"]' | jq .
```

### Network connectivity between clusters
```bash
# From RAN node, ping Core network
ping 192.168.10.1  # Core cluster control plane GW

# Verify routes
ip route | grep 192.168
```

## Advanced Configurations

### Add jumbo frames
```yaml
# In network-intents/Kptfile
mtu: "9000"
```

### Add multiple interfaces per network type
```yaml
# In nad-renderer-config.yaml
interfaceMapping:
  control-plane:
    primary: "eth0"
    backup: "eth1"
```

### Enable network policy between NADs
```yaml
# Add NetworkPolicy resources to rendered/ folder
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-user-plane
spec:
  podSelector:
    matchLabels:
      plane: user
  policyTypes:
  - Ingress
  - Egress
```

## Next Steps

1. Deploy OAI RAN workload package referencing `ran-ctrl-net` and `ran-user-net`
2. Deploy Free5GC Core workload package referencing `core-ctrl-net` and `core-user-net`
3. Configure cross-cluster service discovery (CoreDNS or external DNS)
4. Set up monitoring for network performance (Prometheus + Grafana)

## Contributing

To add new network types or improve rendering logic:

1. Add new intent ConfigMap to `network-intents/`
2. Update `nad-renderer-config.yaml` rules
3. Test rendering with `kpt fn eval`
4. Submit PR with examples

## References

- [Nephio Networking Guide](https://nephio.org/docs/guides/networking)
- [Multus CNI Documentation](https://github.com/k8snetworkplumbingwg/multus-cni)
- [Whereabouts IPAM](https://github.com/k8snetworkplumbingwg/whereabouts)
- [KPT Functions](https://kpt.dev/book/04-using-functions/)