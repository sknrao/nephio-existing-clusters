# ClusterContext Setup Guide

## What is ClusterContext?

ClusterContext is a Nephio Custom Resource that registers your existing Kubernetes clusters with the Nephio management cluster. It tells Nephio:
- Which clusters exist
- What type of workloads they should run (RAN, Core, Edge)
- What CNIs are available
- Site/location information

## Prerequisites

Before applying ClusterContexts, ensure:

1. ✅ Nephio management cluster is running
2. ✅ You have `kubectl` access to management cluster
3. ✅ Your workload clusters (my-ran, my-core) are running with Calico CNI
4. ✅ You can switch between cluster contexts

## Verify Prerequisites

```bash
# Check you can access management cluster
kubectl config use-context nephio-mgmt
kubectl get nodes

# Check ClusterContext CRD exists
kubectl get crd clustercontexts.infra.nephio.org

# If CRD doesn't exist, Nephio might not be properly installed
```

## Quick Start

### Option 1: Using the Script (Easiest)

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR-REPO/apply-clustercontexts.sh
chmod +x apply-clustercontexts.sh

# Edit the script to set your management cluster context
vim apply-clustercontexts.sh
# Change: MGMT_CONTEXT="nephio-mgmt" to your actual context name

# Run the script
./apply-clustercontexts.sh
```

### Option 2: Manual Apply

```bash
# Switch to management cluster
kubectl config use-context nephio-mgmt

# Apply ClusterContexts
kubectl apply -f clustercontext-my-ran.yaml
kubectl apply -f clustercontext-my-core.yaml

# Verify
kubectl get clustercontexts
```

### Option 3: Direct Apply (Copy-Paste)

```bash
kubectl config use-context nephio-mgmt

# Apply my-ran
kubectl apply -f - <<EOF
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-ran
  namespace: default
  labels:
    nephio.org/cluster-type: workload
    nephio.org/workload-type: ran
spec:
  clusterName: my-ran
  siteCode: site-ran-01
  cnis:
    - calico
    - macvlan
  provider: baremetal
EOF

# Apply my-core
kubectl apply -f - <<EOF
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-core
  namespace: default
  labels:
    nephio.org/cluster-type: workload
    nephio.org/workload-type: core
spec:
  clusterName: my-core
  siteCode: site-core-01
  cnis:
    - calico
    - macvlan
  provider: baremetal
EOF
```

## Understanding the ClusterContext Spec

### Required Fields

```yaml
spec:
  clusterName: my-ran          # Logical name for this cluster
  siteCode: site-ran-01        # Unique site identifier
  cnis:                        # List of CNIs on this cluster
    - calico                   # Primary CNI (already installed)
    - macvlan                  # Secondary CNI (will be added)
```

### Optional but Recommended Fields

```yaml
metadata:
  labels:
    nephio.org/cluster-type: workload     # Type: workload, management, edge
    nephio.org/workload-type: ran         # Workload: ran, core, edge

spec:
  provider: baremetal                     # Provider: baremetal, gcp, aws, azure
  annotations:
    nephio.org/description: "RAN cluster"
    nephio.org/location: "Bengaluru, IN"
    nephio.org/environment: "development"
```

### Advanced Fields (Optional)

```yaml
spec:
  # Network contexts for IP planning
  networkContexts:
    - name: control-plane
      ipRange: 192.168.10.0/24
    - name: user-plane
      ipRange: 192.168.20.0/24
  
  # Kubeconfig reference (if you want Nephio to directly access cluster)
  # Only needed for advanced automation
  kubeconfigRef:
    name: my-ran-kubeconfig
    namespace: default
```

## Customization for Your Environment

### If Your Clusters Have Different Names

Edit the `clusterName` field:

```yaml
spec:
  clusterName: my-actual-ran-cluster-name  # Use your actual cluster name
```

### If You're Using Different CNIs

Update the `cnis` list:

```yaml
spec:
  cnis:
    - flannel      # If using Flannel instead of Calico
    - macvlan      # Secondary CNI
    - sriov        # If using SR-IOV
```

### If You Have Multiple Sites

Use different site codes:

```yaml
# Site 1 RAN
spec:
  siteCode: bangalore-ran-01
  
# Site 2 RAN
spec:
  siteCode: mumbai-ran-01
```

### If Using Cloud Providers

Change the provider:

```yaml
spec:
  provider: gcp     # Options: gcp, aws, azure, baremetal, vsphere
```

## Verification

### Check ClusterContexts Created

```bash
# List all ClusterContexts
kubectl get clustercontexts

# Expected output:
# NAME      AGE
# my-ran    30s
# my-core   30s
```

### View Detailed Information

```bash
# Get full details of my-ran ClusterContext
kubectl get clustercontext my-ran -o yaml

# Check labels
kubectl get clustercontext my-ran -o jsonpath='{.metadata.labels}'

# Check CNIs configured
kubectl get clustercontext my-ran -o jsonpath='{.spec.cnis}'
```

### Verify Labels

```bash
# Find all RAN clusters
kubectl get clustercontexts -l nephio.org/workload-type=ran

# Find all workload clusters
kubectl get clustercontexts -l nephio.org/cluster-type=workload
```

## Troubleshooting

### Issue: CRD Not Found

**Error:**
```
error: unable to recognize "clustercontext.yaml": no matches for kind "ClusterContext"
```

**Solution:**
```bash
# Check if Nephio is properly installed
kubectl get crd | grep nephio

# If ClusterContext CRD is missing, reinstall Nephio
# Or manually install the CRD:
kubectl apply -f https://raw.githubusercontent.com/nephio-project/api/main/config/crd/bases/infra.nephio.org_clustercontexts.yaml
```

### Issue: Permission Denied

**Error:**
```
Error from server (Forbidden): clustercontexts.infra.nephio.org is forbidden
```

**Solution:**
```bash
# Check your RBAC permissions
kubectl auth can-i create clustercontexts

# If "no", you need cluster-admin or appropriate role
# Contact your Nephio admin to grant permissions
```

### Issue: Wrong Context

**Error:**
```
error: context "nephio-mgmt" does not exist
```

**Solution:**
```bash
# List available contexts
kubectl config get-contexts

# Use correct context name in script or commands
kubectl config use-context <actual-management-context-name>
```

### Issue: ClusterContext Already Exists

**Error:**
```
Error from server (AlreadyExists): clustercontexts.infra.nephio.org "my-ran" already exists
```

**Solution:**
```bash
# Delete existing ClusterContext
kubectl delete clustercontext my-ran

# Or update existing one
kubectl apply -f clustercontext-my-ran.yaml
# This will update the existing resource
```

## What Happens After ClusterContext Creation?

After you create ClusterContexts, Nephio:

1. ✅ **Registers clusters** in its inventory
2. ✅ **Makes clusters available** for package deployment
3. ✅ **Enables cluster selection** in PackageVariants
4. ✅ **Provides cluster metadata** to controllers

**However, ClusterContext does NOT:**
- ❌ Automatically install anything on workload clusters
- ❌ Configure networking on workload clusters
- ❌ Deploy workloads to clusters
- ❌ Setup ConfigSync on workload clusters

## Next Steps

After ClusterContexts are created:

### Step 1: Verify Registration
```bash
kubectl get clustercontexts
```

### Step 2: Register Git Repositories
```bash
# Create Repository CRs pointing to your git repos
kubectl apply -f repositories.yaml
```

### Step 3: Create PackageVariants
```bash
# Tell Nephio what packages to deploy to which clusters
kubectl apply -f packagevariants.yaml
```

### Step 4: Monitor Package Rendering
```bash
# Watch Porch render packages
kubectl get packagerevisions -w
```

### Step 5: Approve Packages
```bash
# Approve rendered packages for deployment
kubectl patch packagerevision <name> --type=merge \
  -p '{"spec":{"lifecycle":"Published"}}'
```

### Step 6: Bootstrap ConfigSync
```bash
# Manually install ConfigSync on each workload cluster
# (This is the only manual step after ClusterContext)
```

## Using with Management Config Repo

If you're using the management-config repository approach:

### Directory Structure
```
nephio-management-config/
├── cluster-contexts/
│   ├── kustomization.yaml
│   ├── clustercontext-my-ran.yaml      ← Place here
│   └── clustercontext-my-core.yaml     ← Place here
├── repositories/
└── packagevariants/
```

### kustomization.yaml
```yaml
# cluster-contexts/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - clustercontext-my-ran.yaml
  - clustercontext-my-core.yaml
```

### Apply with Kustomize
```bash
kubectl apply -k nephio-management-config/cluster-contexts/
```

## Best Practices

### 1. Use Consistent Naming
```yaml
clusterName: my-ran        # Use same name throughout
siteCode: site-ran-01      # Consistent site codes
```

### 2. Label Everything
```yaml
metadata:
  labels:
    nephio.org/cluster-type: workload
    nephio.org/workload-type: ran
    nephio.org/region: south-asia
    nephio.org/provider: baremetal
```

### 3. Document Your Clusters
```yaml
spec:
  annotations:
    nephio.org/description: "Production RAN cluster"
    nephio.org/contact: "ran-team@example.com"
    nephio.org/environment: "production"
```

### 4. Plan Site Codes
```
Format: <location>-<type>-<number>
Examples:
  - bangalore-ran-01
  - bangalore-core-01
  - mumbai-edge-01
```

### 5. Keep CNI List Accurate
```yaml
spec:
  cnis:
    - calico      # Actually installed
    - macvlan     # Will be installed
    # Don't list CNIs you don't have!
```

## Summary

ClusterContext is the **first step** in integrating existing clusters with Nephio. It's a simple registration process that:

1. Takes 2 minutes to apply
2. Requires no changes to workload clusters
3. Makes clusters visible to Nephio
4. Enables package deployment

After creating ClusterContexts, you're ready to proceed with git repository registration and package deployment!