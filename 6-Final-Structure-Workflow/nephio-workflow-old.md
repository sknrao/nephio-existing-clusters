# Nephio Deployment Workflow - Confirmed & Corrected

## Your Workflow (with Corrections)

### ❌ What You Said (Incorrect)
> "Then create a single repo for 2 clusters, including cluster-baseline and networking and platform-addons"

### ✅ Corrected Workflow

You need **THREE** repositories, not one:

1. **ONE Blueprint Repo** (upstream) - Contains the package templates
2. **TWO Deployment Repos** (downstream) - One per cluster for rendered packages

## Complete Step-by-Step Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ Prerequisites: Already Done ✓                               │
├─────────────────────────────────────────────────────────────┤
│ • Nephio Management Cluster running                         │
│ • my-ran workload cluster running (with Calico)            │
│ • my-core workload cluster running (with Calico)           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Register Workload Clusters in Nephio               │
├─────────────────────────────────────────────────────────────┤
│ Create ClusterContext resources for both clusters          │
│ Apply to Nephio management cluster                         │
│                                                             │
│ Result: Nephio knows about my-ran and my-core              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Create Git Repositories (3 repos)                  │
├─────────────────────────────────────────────────────────────┤
│ 1. nephio-blueprints (upstream)                            │
│    • cluster-baseline/                                      │
│    • platform-addons/                                       │
│    • networking/multus-cni/                                 │
│    • networking/whereabouts-ipam/                           │
│    • networking/network-intents/                            │
│    • networking/network-attachment-renderer/                │
│                                                             │
│ 2. nephio-my-ran (downstream)                              │
│    • Empty initially (Porch will populate)                  │
│                                                             │
│ 3. nephio-my-core (downstream)                             │
│    • Empty initially (Porch will populate)                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Register Repositories in Nephio                    │
├─────────────────────────────────────────────────────────────┤
│ Create Repository resources in management cluster          │
│ Point to all 3 git repos                                    │
│                                                             │
│ Result: Porch can read/write to these repos                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Deploy PackageVariants                             │
├─────────────────────────────────────────────────────────────┤
│ Apply PackageVariant manifests to management cluster       │
│                                                             │
│ This creates (per cluster):                                 │
│ • baseline-my-ran PackageVariant                           │
│ • baseline-my-core PackageVariant                          │
│ • addons-my-ran PackageVariant                             │
│ • addons-my-core PackageVariant                            │
│ • multus-my-ran PackageVariant                             │
│ • multus-my-core PackageVariant                            │
│ • whereabouts-my-ran PackageVariant                        │
│ • whereabouts-my-core PackageVariant                       │
│ • nads-my-ran PackageVariant                               │
│ • nads-my-core PackageVariant                              │
│                                                             │
│ Result: Porch renders packages and commits to downstream   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Approve PackageRevisions                           │
├─────────────────────────────────────────────────────────────┤
│ Rendered packages are in "Draft" state                      │
│ Manually approve or auto-approve                            │
│                                                             │
│ Result: Packages moved to "Published" state                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 6: Bootstrap ConfigSync on Workload Clusters          │
├─────────────────────────────────────────────────────────────┤
│ THIS IS MANUAL - Cannot be done via PackageVariants!       │
│                                                             │
│ On my-ran cluster:                                          │
│ • kubectl apply -f cluster-baseline/configsync.yaml        │
│ • kubectl apply -f cluster-baseline/rootsync.yaml          │
│                                                             │
│ On my-core cluster:                                         │
│ • kubectl apply -f cluster-baseline/configsync.yaml        │
│ • kubectl apply -f cluster-baseline/rootsync.yaml          │
│                                                             │
│ Result: ConfigSync running and watching git repos          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 7: ConfigSync Deploys Everything                      │
├─────────────────────────────────────────────────────────────┤
│ ConfigSync automatically pulls from downstream repos       │
│ and applies all manifests                                   │
│                                                             │
│ Result: All components deployed to workload clusters       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 8: Verify Deployment                                  │
├─────────────────────────────────────────────────────────────┤
│ Check that all pods are running                            │
│ Verify NADs, storage, metrics server                       │
│                                                             │
│ Result: Clusters ready for workloads                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 9: Deploy OAI RAN and Free5GC                         │
├─────────────────────────────────────────────────────────────┤
│ Create PackageVariants for network functions               │
│ Nephio deploys via same GitOps flow                        │
│                                                             │
│ Result: 5G network functions running                       │
└─────────────────────────────────────────────────────────────┘
```

## Key Clarification: Deployment Script vs PackageVariants

### ❌ Don't Use Both
You should choose ONE approach:

**Option A: PackageVariants (Full Nephio GitOps)**
- Use PackageVariants in management cluster
- Porch renders and commits to git
- ConfigSync pulls and applies
- **This is the proper Nephio way**

**Option B: Direct Deployment Script**
- Run the bash script I provided
- Directly applies manifests with kubectl
- No PackageVariants, no Porch
- **This bypasses Nephio's GitOps workflow**

### ✅ Recommended: Use PackageVariants

Since you have a management cluster, use the full GitOps workflow:
- **Management cluster**: Create PackageVariants
- **Git repos**: Porch writes rendered packages
- **Workload clusters**: ConfigSync pulls and applies

**Don't use the deployment script** - it's for environments without a management cluster.

## Why THREE Repositories?

### Nephio Package Repository Pattern

```
┌──────────────────────────────────────┐
│ nephio-blueprints (UPSTREAM)         │
│ • Contains package TEMPLATES         │
│ • Has kpt-set markers: ${var}        │
│ • deployment: false                  │
│ • One package, many uses             │
└──────────────────────────────────────┘
          │
          │ Porch reads from here
          ↓
┌─────────────────────────────────────────────────────┐
│ PackageVariant Controller (in management cluster)   │
│ • Clones upstream package                           │
│ • Applies setters (cluster-specific values)         │
│ • Runs KRM functions                                │
│ • Commits to downstream                             │
└─────────────────────────────────────────────────────┘
          │                    │
          ↓                    ↓
┌─────────────────────┐  ┌─────────────────────┐
│ nephio-my-ran       │  │ nephio-my-core      │
│ (DOWNSTREAM)        │  │ (DOWNSTREAM)        │
│ • Rendered packages │  │ • Rendered packages │
│ • Actual values     │  │ • Actual values     │
│ • deployment: true  │  │ • deployment: true  │
└─────────────────────┘  └─────────────────────┘
          │                    │
          │ ConfigSync         │ ConfigSync
          │ watches            │ watches
          ↓                    ↓
┌─────────────────────┐  ┌─────────────────────┐
│ my-ran cluster      │  │ my-core cluster     │
│ • ConfigSync running│  │ • ConfigSync running│
│ • Applies manifests │  │ • Applies manifests │
└─────────────────────┘  └─────────────────────┘
```

### Why Not One Repo for Both Clusters?

**Repository is 1:1 with Cluster**
- Each cluster needs its own deployment repo
- ConfigSync on cluster A watches repo A
- ConfigSync on cluster B watches repo B
- Allows independent versioning and rollback per cluster

## Repository Structure

Here's exactly what you need to create: