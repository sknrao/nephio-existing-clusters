Absolutely! Let me create the ClusterContext resources for your two existing clusters.Perfect! I've created complete ClusterContext resources for your clusters. Here's what you have:

## 📦 What I Created

### 1. **ClusterContext YAML Files**
Two ClusterContext resources ready to apply:
- `my-ran` - For your RAN cluster (OAI deployment)
- `my-core` - For your CORE cluster (Free5GC deployment)

### 2. **Application Script**
`apply-clustercontexts.sh` - Automated script that:
- Switches to management cluster
- Applies both ClusterContexts
- Verifies creation
- Shows detailed output

### 3. **Complete Guide**
`ClusterContext-Setup-Guide.md` - Documentation covering:
- What ClusterContext is
- Multiple ways to apply
- Customization options
- Troubleshooting
- Next steps

## 🚀 Quick Start - Apply Now

### Option 1: Direct Apply (Fastest)

```bash
# Switch to your management cluster
kubectl config use-context nephio-mgmt  # Use your actual context name

# Apply both ClusterContexts
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
---
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

# Verify
kubectl get clustercontexts
```

### Option 2: Using the Script

```bash
# Save the script
# Edit MGMT_CONTEXT to match your management cluster context name
vim apply-clustercontexts.sh

# Run it
chmod +x apply-clustercontexts.sh
./apply-clustercontexts.sh
```

## ✅ What These ClusterContexts Include

| Field | my-ran | my-core | Purpose |
|-------|--------|---------|---------|
| clusterName | my-ran | my-core | Logical cluster identifier |
| siteCode | site-ran-01 | site-core-01 | Unique site identifier |
| CNIs | calico, macvlan | calico, macvlan | Available CNI plugins |
| workload-type | ran | core | Type of workloads |
| provider | baremetal | baremetal | Infrastructure type |
| location | Bengaluru, IN | Bengaluru, IN | Physical location |

## 🎯 What Happens After You Apply

1. **Immediate:** ClusterContexts created in management cluster
2. **Nephio registers** your clusters in its inventory
3. **PackageVariants can now target** these clusters by name
4. **Ready for next step:** Register git repositories

## ⏭️ Next Steps (After ClusterContexts)

```bash
# 1. Verify ClusterContexts (do this now)
kubectl get clustercontexts

# 2. Next: Register git repositories
# (I can create these for you next)

# 3. Then: Create PackageVariants
# (Already created in previous artifacts)

# 4. Then: Bootstrap ConfigSync
# (Manual step on workload clusters)
```

## 🔍 Verification Commands

```bash
# List all ClusterContexts
kubectl get clustercontexts

# View details of my-ran
kubectl describe clustercontext my-ran

# View details of my-core
kubectl describe clustercontext my-core

# Check labels
kubectl get clustercontexts --show-labels

# Filter by workload type
kubectl get clustercontexts -l nephio.org/workload-type=ran
kubectl get clustercontexts -l nephio.org/workload-type=core
```

**These ClusterContexts are ready to apply immediately!** They match your existing cluster setup (Calico CNI, bare-metal, 2 clusters in Bengaluru).

Would you like me to:
1. Create the Repository CRs (next step after ClusterContexts)?
2. Adjust any fields in the ClusterContexts before you apply them?
3. Create the complete management-config repo structure with these ClusterContexts included?