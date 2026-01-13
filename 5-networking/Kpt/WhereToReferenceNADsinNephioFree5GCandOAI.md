# Where to Reference NADs in Nephio Free5GC and OAI Packages

Based on the Nephio catalog structure, here's exactly where you need to make changes to reference your custom NADs.

## Understanding the Flow

Nephio uses a multi-layer approach:
1. **Interface CRs** - High-level network intent (which network this NF needs)
2. **KRM Functions** - Process interfaces and inject NAD references
3. **NFDeployment CRs** - Final deployment spec that operators consume

Your NADs (`ran-ctrl-net`, `ran-user-net`, `core-ctrl-net`, `core-user-net`) need to be referenced in the **Interface** resources.

## Package Structure in Catalog

```
catalog/workloads/
├── free5gc/
│   ├── pkg-example-amf-bp/      # AMF blueprint
│   │   ├── Kptfile
│   │   ├── amfdeployment.yaml
│   │   ├── interface-n2.yaml    ← MODIFY THIS
│   │   └── package-context.yaml
│   ├── pkg-example-smf-bp/      # SMF blueprint  
│   │   ├── interface-n4.yaml    ← MODIFY THIS
│   │   └── ...
│   └── pkg-example-upf-bp/      # UPF blueprint
│       ├── interface-n3.yaml    ← MODIFY THIS
│       ├── interface-n4.yaml    ← MODIFY THIS
│       ├── interface-n6.yaml    ← MODIFY THIS
│       └── ...
└── oai/
    ├── pkg-example-cucp-bp/     # CU-CP blueprint
    │   ├── interface-e1.yaml    ← MODIFY THIS
    │   ├── interface-f1c.yaml   ← MODIFY THIS
    │   ├── interface-n2.yaml    ← MODIFY THIS
    │   └── ...
    ├── pkg-example-cuup-bp/     # CU-UP blueprint
    │   ├── interface-e1.yaml    ← MODIFY THIS
    │   ├── interface-f1u.yaml   ← MODIFY THIS
    │   ├── interface-n3.yaml    ← MODIFY THIS
    │   └── ...
    └── pkg-example-du-bp/       # DU blueprint
        ├── interface-f1c.yaml   ← MODIFY THIS
        ├── interface-f1u.yaml   ← MODIFY THIS
        └── ...
```

## The Interface Resource Structure

Here's what a typical Interface resource looks like (before modification):

```yaml
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: workload.nephio.org/v1alpha1.NFDeployment.amf-regional
    specializer.nephio.org/namespace: free5gc-cp
    nephio.org/network-name: n2  # High-level network name
spec:
  networkInstance:
    name: vpc-ran  # This gets resolved to actual NAD
  cniType: macvlan
  attachmentType: vlan
```

## Changes You Need to Make

### Option 1: Modify Network Names (Recommended)

The cleanest approach is to ensure your NADs match the expected network names that Nephio's KRM functions look for:

**For RAN Cluster (my-ran):**
```bash
# Rename your NADs to match Nephio conventions
kubectl label nad ran-ctrl-net nephio.org/network-name=n2 -n openairinterface
kubectl label nad ran-user-net nephio.org/network-name=n3 -n openairinterface
```

**For Core Cluster (my-core):**
```bash
kubectl label nad core-ctrl-net nephio.org/network-name=n2 -n free5gc
kubectl label nad core-ctrl-net nephio.org/network-name=n4 -n free5gc  # for SMF
kubectl label nad core-user-net nephio.org/network-name=n3 -n free5gc  # for UPF
kubectl label nad core-user-net nephio.org/network-name=n6 -n free5gc  # for UPF internet
```

### Option 2: Direct NAD Reference (More Control)

Modify the Interface resources in your forked packages to directly reference your NAD names:

#### Example: Free5GC AMF Interface

**File:** `catalog/workloads/free5gc/pkg-example-amf-bp/interface-n2.yaml`

**Original:**
```yaml
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    config.kubernetes.io/local-config: "true"
    nephio.org/network-name: n2
spec:
  networkInstance:
    name: vpc-ran
  cniType: macvlan
  attachmentType: vlan
```

**Modified for your setup:**
```yaml
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    config.kubernetes.io/local-config: "true"
    nephio.org/network-name: n2
    # Add direct NAD reference
    k8s.v1.cni.cncf.io/networks: core-ctrl-net  # Your NAD name
spec:
  networkInstance:
    name: vpc-ran  # Can keep for documentation
  cniType: macvlan
  attachmentType: vlan
```

## Network Interface Mappings

### Free5GC Core Functions

| Network Function | Interface | 3GPP Network | Your NAD (my-core) |
|-----------------|-----------|--------------|-------------------|
| AMF | n2 | N2 (Control) | `core-ctrl-net` |
| SMF | n4 | N4 (Control) | `core-ctrl-net` |
| UPF | n3 | N3 (User) | `core-user-net` |
| UPF | n4 | N4 (Control) | `core-ctrl-net` |
| UPF | n6 | N6 (Data Network) | `core-user-net` |

### OAI RAN Functions

| Network Function | Interface | 3GPP Network | Your NAD (my-ran) |
|-----------------|-----------|--------------|-------------------|
| CU-CP | n2 | N2 (to AMF) | `ran-ctrl-net` |
| CU-CP | f1c | F1-C (Control) | `ran-ctrl-net` |
| CU-CP | e1 | E1 (Control) | `ran-ctrl-net` |
| CU-UP | e1 | E1 (Control) | `ran-ctrl-net` |
| CU-UP | f1u | F1-U (User) | `ran-user-net` |
| CU-UP | n3 | N3 (User) | `ran-user-net` |
| DU | f1c | F1-C (Control) | `ran-ctrl-net` |
| DU | f1u | F1-U (User) | `ran-user-net` |

## Practical Modification Steps

### Step 1: Fork the Catalog

```bash
# Clone Nephio catalog
git clone https://github.com/nephio-project/catalog.git
cd catalog

# Create your branch
git checkout -b custom-nads
```

### Step 2: Modify Free5GC Packages

```bash
cd workloads/free5gc

# AMF - N2 interface
cat > pkg-example-amf-bp/interface-n2.yaml <<EOF
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: workload.nephio.org/v1alpha1.NFDeployment.amf-regional
    specializer.nephio.org/namespace: free5gc-cp
    nephio.org/network-name: n2
spec:
  networkInstance:
    name: my-core-control-plane  # Your network name
  cniType: macvlan
  attachmentType: none  # No VLAN for simple LAN
EOF

# SMF - N4 interface
cat > pkg-example-smf-bp/interface-n4.yaml <<EOF
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n4
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: workload.nephio.org/v1alpha1.NFDeployment.smf-regional
    specializer.nephio.org/namespace: free5gc-cp
    nephio.org/network-name: n4
spec:
  networkInstance:
    name: my-core-control-plane
  cniType: macvlan
  attachmentType: none
EOF

# UPF - N3, N4, N6 interfaces (similar pattern)
# Repeat for each interface file in pkg-example-upf-bp/
```

### Step 3: Modify OAI RAN Packages

```bash
cd ../oai

# CU-CP interfaces
cat > pkg-example-cucp-bp/interface-n2.yaml <<EOF
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: workload.nephio.org/v1alpha1.NFDeployment.cucp-regional
    specializer.nephio.org/namespace: oai-ran-cucp
    nephio.org/network-name: n2
spec:
  networkInstance:
    name: my-ran-control-plane
  cniType: macvlan
  attachmentType: none
EOF

# Repeat for f1c, e1 interfaces
# Then do CU-UP and DU packages
```

### Step 4: Update Kptfiles

In each modified package, update the `Kptfile` to reference your changes:

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: pkg-example-amf-bp
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: AMF blueprint for my-core cluster
pipeline:
  mutators:
    - image: docker.io/nephio/interface-fn:v3.0.0
      configMap:
        # Map to your NAD names
        nad-name-override: "core-ctrl-net"
    - image: docker.io/nephio/nad-fn:v3.0.0
    - image: docker.io/nephio/nfdeploy-fn:v3.0.0
```

### Step 5: Push to Your Git Repository

```bash
# Commit changes
git add .
git commit -m "Adapt packages for bare-metal clusters with custom NADs"
git push origin custom-nads
```

### Step 6: Register Your Custom Catalog

In your Nephio management cluster:

```bash
# Create repository for your custom catalog
cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: custom-catalog-workloads
  namespace: default
spec:
  type: git
  content: Package
  deployment: false
  git:
    repo: https://github.com/YOUR-ORG/catalog.git
    branch: custom-nads
    directory: /workloads
EOF
```

## Alternative: KRM Function Approach

If you don't want to fork packages, create a custom KRM function that maps network names to your NADs:

```yaml
# nad-mapping-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nad-mapping
  namespace: default
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  mappings: |
    my-ran:
      n2: ran-ctrl-net
      n3: ran-user-net
      f1c: ran-ctrl-net
      f1u: ran-user-net
      e1: ran-ctrl-net
    my-core:
      n2: core-ctrl-net
      n3: core-user-net
      n4: core-ctrl-net
      n6: core-user-net
```

Then reference this in your PackageVariant:

```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: free5gc-amf-my-core
spec:
  upstream:
    repo: catalog-workloads-free5gc
    package: pkg-example-amf-bp
    revision: main
  downstream:
    repo: my-core
    package: free5gc-amf
  pipeline:
    mutators:
      - image: docker.io/nephio/interface-fn:v3.0.0
        configPath: nad-mapping-config.yaml
      - image: docker.io/nephio/nad-fn:v3.0.0
```

## Verification

After deployment, verify NAD attachments:

```bash
# On my-ran cluster
kubectl get pods -n openairinterface -o json | \
  jq -r '.items[] | select(.metadata.annotations."k8s.v1.cni.cncf.io/networks" != null) | 
  {name: .metadata.name, networks: .metadata.annotations."k8s.v1.cni.cncf.io/networks"}'

# On my-core cluster  
kubectl get pods -n free5gc -o json | \
  jq -r '.items[] | select(.metadata.annotations."k8s.v1.cni.cncf.io/networks" != null) |
  {name: .metadata.name, networks: .metadata.annotations."k8s.v1.cni.cncf.io/networks"}'
```

Expected output should show your NAD names (`ran-ctrl-net`, `core-ctrl-net`, etc.) attached to the pods.

## Troubleshooting

**Issue:** Pods stuck in ContainerCreating
```bash
# Check multus logs
kubectl logs -n kube-system ds/kube-multus-ds

# Check if NADs exist
kubectl get network-attachment-definitions -A

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

**Issue:** Interface function not finding NADs
```bash
# Check if Interface resources are being created
kubectl get interfaces -A

# Check package revision status
kubectl get packagerevisions -n <namespace>
```

**Issue:** Wrong NAD being selected
- Ensure your NAD names don't conflict with existing NADs
- Check namespace - NADs are namespace-scoped
- Verify annotations on Interface resources

## Summary

The key files to modify are:
1. **Interface YAML files** in each blueprint package (`interface-*.yaml`)
2. **Kptfiles** to configure pipeline functions
3. **PackageVariant** resources when deploying to clusters

For your simple 2-cluster setup, the cleanest approach is:
- Fork the catalog
- Modify Interface specs to use `attachmentType: none` (no VLANs)
- Update `networkInstance.name` to match your intent
- Ensure NADs exist with correct names before deploying workloads

The Nephio operators (free5gc-operator, oai-operator) will read these Interface resources and generate the appropriate pod annotations to attach your NADs.