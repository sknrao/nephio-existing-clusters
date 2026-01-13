# Complete Cluster Baseline - Package Structure

## Final Package Contents

```
cluster-baseline/
├── Kptfile ⭐ UPDATED
│   └── Now includes: cluster-name, workload-type, site-id, storage-class-name
│
├── Core GitOps (existing)
│   ├── configsync.yaml
│   ├── rootsync.yaml
│   └── git-credentials-secret.yaml
│
└── NEW Additions ✨
    ├── pod-security.yaml           # Namespaces + Pod Security Standards
    ├── node-configuration.yaml     # Auto-label nodes for Nephio
    ├── default-resource-limits.yaml # LimitRanges per namespace
    └── storage-class.yaml          # StorageClass definitions
```

## What Changed

### Original (Incomplete)
```
cluster-baseline/
├── Kptfile
├── configsync.yaml
├── rootsync.yaml
├── git-credentials-secret.yaml
└── namespaces.yaml              # Simple namespaces only
```

### Enhanced (Complete)
```
cluster-baseline/
├── Kptfile                      # Enhanced with more setters
├── configsync.yaml              
├── rootsync.yaml                
├── git-credentials-secret.yaml  
├── pod-security.yaml            # Replaces namespaces.yaml + adds PSS
├── node-configuration.yaml      # NEW: Node labels + Job
├── default-resource-limits.yaml # NEW: Per-namespace LimitRanges
└── storage-class.yaml           # NEW: Storage class definitions
```

## Quick Comparison

| Feature | Before | After |
|---------|--------|-------|
| Namespaces | ✅ | ✅ Enhanced with labels |
| ConfigSync | ✅ | ✅ |
| Pod Security | ❌ | ✅ PSS on all namespaces |
| Node Labels | ❌ | ✅ Auto-labeling job |
| Resource Limits | ❌ | ✅ Per-namespace defaults |
| Storage Classes | ❌ | ✅ Multiple classes |

## Files You Should Use

### Essential (Must Have)
1. ✅ **configsync.yaml** - GitOps controller
2. ✅ **rootsync.yaml** - Sync from your repo
3. ✅ **pod-security.yaml** - Namespaces with security

### Highly Recommended (Should Have)
4. ⚠️ **node-configuration.yaml** - For Nephio discovery
5. ⚠️ **default-resource-limits.yaml** - Protect single-node clusters
6. ⚠️ **storage-class.yaml** - For database PVs

### Optional
7. 🔧 **git-credentials-secret.yaml** - Only if private repos

## Deployment Example

### For my-ran Cluster
```yaml
# PackageVariant
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        cluster-name: my-ran           # All files updated
        workload-type: ran              # Pod labels set
        site-id: site-ran-01            # Node labels set
        cluster-repo-url: .../my-ran    # RootSync configured
        storage-class-name: local-path  # Storage class name
```

### For my-core Cluster
```yaml
# Same PackageVariant, different values
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        cluster-name: my-core           # All files updated
        workload-type: core             # Pod labels set
        site-id: site-core-01           # Node labels set
        cluster-repo-url: .../my-core   # RootSync configured
        storage-class-name: local-path  # Storage class name
```

## What Each Setter Does Across Files

| Setter | Used In | Effect |
|--------|---------|--------|
| `cluster-name` | All files | Labels, names, node labels |
| `workload-type` | pod-security.yaml, node-configuration.yaml | Namespace labels, node labels |
| `site-id` | node-configuration.yaml | Node label for site identification |
| `cluster-repo-url` | rootsync.yaml | Where ConfigSync pulls from |
| `storage-class-name` | storage-class.yaml | Name of default storage class |

## Integration Points

### With Networking Packages
```
cluster-baseline (namespaces) → networking (NADs in those namespaces)
```

### With Platform Addons
```
cluster-baseline (storage classes) → platform-addons (provisioner implementation)
cluster-baseline (namespaces) → platform-addons (resource quotas)
```

### With Workload Packages
```
cluster-baseline (node labels) → workload packages (node affinity)
cluster-baseline (pod security) → workload packages (security context)
cluster-baseline (resource limits) → workload packages (default resources)
```

## Testing Checklist

After deploying cluster-baseline:

```bash
# 1. Check namespaces exist with labels
kubectl get ns -l nephio.org/cluster-name=my-ran
kubectl get ns -l nephio.org/workload-type=ran

# 2. Check pod security labels
kubectl get ns openairinterface -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
# Should output: baseline

# 3. Check node labels
kubectl get nodes --show-labels | grep nephio.org

# 4. Check limit ranges
kubectl get limitrange -A
kubectl describe limitrange default-limits -n openairinterface

# 5. Check storage classes
kubectl get storageclass
kubectl get sc local-path -o yaml

# 6. Check ConfigSync running
kubectl get pods -n config-management-system
kubectl get rootsync -n config-management-system
```

## Minimum vs Complete Deployment

### Minimum (Just to Get Started)
```bash
kubectl apply -f cluster-baseline/configsync.yaml
kubectl apply -f cluster-baseline/rootsync.yaml
kubectl apply -f cluster-baseline/pod-security.yaml
```

### Complete (Production Ready)
```bash
kubectl apply -f cluster-baseline/
# Applies all files
```

### Recommended Order
```bash
# 1. GitOps first
kubectl apply -f cluster-baseline/configsync.yaml
kubectl apply -f cluster-baseline/rootsync.yaml

# 2. Wait for ConfigSync to be ready
kubectl wait --for=condition=Ready \
  pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s

# 3. Let ConfigSync apply the rest
# (It will pull from git and apply everything else)
```

## Files by Priority

### Priority 1: Must Deploy First
- configsync.yaml
- rootsync.yaml

### Priority 2: Deploy After ConfigSync Ready
- pod-security.yaml (namespaces needed for everything else)

### Priority 3: Can Deploy Anytime
- node-configuration.yaml (labels can be added later)
- default-resource-limits.yaml (limits apply to new pods)
- storage-class.yaml (classes used when PVCs created)

### Priority 4: Only If Needed
- git-credentials-secret.yaml (only for private repos)