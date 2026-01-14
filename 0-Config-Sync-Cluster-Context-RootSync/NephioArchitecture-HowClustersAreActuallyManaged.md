# Nephio Architecture - How Clusters Are Actually Managed

## The Critical Truth

**Nephio does NOT directly manage workload clusters.**

Nephio uses a **GitOps pull model**, where:
- Nephio writes to git repos
- Workload clusters pull from git repos
- You must manually bootstrap the "puller" (ConfigSync)

---

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ MANAGEMENT CLUSTER (Nephio)                                     │
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────┐            │
│  │ ClusterContext   │         │ PackageVariant   │            │
│  │                  │         │                  │            │
│  │ my-ran:          │────────>│ Deploy:          │            │
│  │ • name           │         │ • cluster-       │            │
│  │ • site           │         │   baseline       │            │
│  │ • CNIs           │         │ To repo:         │            │
│  │ (METADATA ONLY)  │         │ • nephio-my-ran  │            │
│  └──────────────────┘         └──────────────────┘            │
│                                        │                        │
│                                        ↓                        │
│                               ┌──────────────────┐             │
│                               │ Porch Controller │             │
│                               │                  │             │
│                               │ 1. Reads upstream│             │
│                               │ 2. Renders       │             │
│                               │ 3. Writes to GIT │             │
│                               └──────────────────┘             │
│                                        │                        │
└────────────────────────────────────────┼────────────────────────┘
                                         │
                                         │ Git Commit
                                         ↓
                              ┌─────────────────────┐
                              │ GitHub/GitLab       │
                              │                     │
                              │ nephio-my-ran/      │
                              │ ├── cluster-baseline│
                              │ ├── platform-addons │
                              │ └── networking/     │
                              │                     │
                              │ (Git is the bridge) │
                              └─────────────────────┘
                                         │
                                         │ Git Pull
                                         ↓
┌─────────────────────────────────────────────────────────────────┐
│ WORKLOAD CLUSTER (my-ran)                                       │
│                                                                  │
│  ┌───────────────────────────────────────────┐                 │
│  │ ConfigSync (YOU installed this manually)  │                 │
│  │                                            │                 │
│  │ 1. Watches nephio-my-ran git repo         │                 │
│  │ 2. Pulls changes every 15 seconds         │                 │
│  │ 3. Applies manifests to THIS cluster      │                 │
│  │ 4. Reconciles drift                        │                 │
│  └───────────────────────────────────────────┘                 │
│                        │                                         │
│                        ↓                                         │
│  ┌───────────────────────────────────────────┐                 │
│  │ Kubernetes Resources (applied locally)    │                 │
│  │                                            │                 │
│  │ • Namespaces (openairinterface)           │                 │
│  │ • Storage (local-path-provisioner)        │                 │
│  │ • Networking (Multus, Whereabouts)        │                 │
│  │ • Everything from git repo                │                 │
│  └───────────────────────────────────────────┘                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Bootstrap Sequence

### What You MUST Do Manually

```
┌──────────────────────────────────────────────┐
│ Step 1: One-Time Manual Bootstrap            │
│ (This is YOUR responsibility)                │
└──────────────────────────────────────────────┘
          │
          ↓
┌──────────────────────────────────────────────┐
│ SSH or kubectl to my-ran cluster             │
│                                               │
│ kubectl config use-context my-ran            │
│                                               │
│ kubectl apply -f configsync.yaml             │
│ kubectl apply -f rootsync.yaml               │
│                                               │
│ RootSync points to:                          │
│ git.repo: nephio-my-ran                      │
│ git.dir: /                                   │
└──────────────────────────────────────────────┘
          │
          ↓
┌──────────────────────────────────────────────┐
│ Step 2: ConfigSync Starts Watching Git       │
│ (Automatic from this point)                  │
└──────────────────────────────────────────────┘
          │
          ↓
┌──────────────────────────────────────────────┐
│ Step 3: ConfigSync Pulls and Applies         │
│ Everything in nephio-my-ran repo             │
│ (Automatic, continuous)                      │
└──────────────────────────────────────────────┘
```

---

## Why ClusterContext Doesn't Have Connection Info

### What ClusterContext Contains
```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-ran
spec:
  clusterName: my-ran        # Just a name
  siteCode: site-ran-01      # Just metadata
  cnis: [calico, macvlan]    # Available CNIs (info only)
  provider: baremetal        # Info only
```

**NO:**
- ❌ Kubeconfig
- ❌ API server URL
- ❌ Credentials
- ❌ Connection details

### Why?

Because Nephio follows the **GitOps pull model**:
- Nephio pushes to git
- Workload cluster pulls from git
- **No direct connection needed**

---

## Comparison: Push vs Pull Models

### ❌ Push Model (Not Used by Nephio)
```
Management Cluster
    │
    │ kubectl apply --context=workload-cluster
    │ (Direct connection required)
    ↓
Workload Cluster
```

**Problems:**
- Management cluster needs kubeconfig for all clusters
- Management cluster needs network access to all clusters
- Security risk (cluster-admin credentials everywhere)
- Doesn't scale

### ✅ Pull Model (Used by Nephio)
```
Management Cluster
    │
    │ git push
    ↓
Git Repository
    ↑
    │ git pull
    │
Workload Cluster (ConfigSync)
```

**Benefits:**
- ✅ No credentials needed in management cluster
- ✅ Workload clusters pull (more secure)
- ✅ Git is source of truth
- ✅ Scales to thousands of clusters
- ✅ Audit trail in git

---

## The Missing Link: ConfigSync

### Why ConfigSync is Essential

ConfigSync is the **agent** that runs on the workload cluster and makes GitOps work.

**Without ConfigSync:**
```
Nephio → Git Repo → ❌ Nothing happens on cluster
```

**With ConfigSync:**
```
Nephio → Git Repo → ConfigSync pulls → Applies to cluster ✅
```

### What ConfigSync Does

```
┌──────────────────────────────────────┐
│ ConfigSync Pod (on workload cluster) │
│                                       │
│ Every 15 seconds:                    │
│ 1. git pull nephio-my-ran            │
│ 2. Compare with cluster state        │
│ 3. kubectl apply differences         │
│ 4. Report sync status                │
└──────────────────────────────────────┘
```

### ConfigSync Configuration (RootSync)

```yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: https://github.com/YOUR-ORG/nephio-my-ran.git
    branch: main
    dir: /
    auth: none
    period: 15s  # Check every 15 seconds
```

This tells ConfigSync:
- Where to pull from (nephio-my-ran repo)
- How often to check (15 seconds)
- What to apply (everything in the repo)

---

## Complete Flow Example

### Deploying cluster-baseline Package

```
┌─────────────────────────────────────────────────────────┐
│ STEP 1: Management Cluster (You)                        │
└─────────────────────────────────────────────────────────┘

kubectl apply -f packagevariant-baseline-my-ran.yaml

PackageVariant says:
- upstream: nephio-blueprints/cluster-baseline
- downstream: nephio-my-ran/cluster-baseline
- setters: cluster-name=my-ran

┌─────────────────────────────────────────────────────────┐
│ STEP 2: Porch (Automatic)                               │
└─────────────────────────────────────────────────────────┘

Porch:
1. Clones nephio-blueprints/cluster-baseline
2. Applies setters (cluster-name → my-ran)
3. Renders final manifests
4. Commits to nephio-my-ran repo in git

Git commit message: "Rendered cluster-baseline v1 for my-ran"

┌─────────────────────────────────────────────────────────┐
│ STEP 3: ConfigSync (Automatic, on my-ran cluster)       │
└─────────────────────────────────────────────────────────┘

ConfigSync (running on my-ran):
1. Detects new commit in nephio-my-ran
2. git pull
3. Sees new cluster-baseline/ directory
4. kubectl apply -f cluster-baseline/

Result on my-ran cluster:
✅ Namespaces created
✅ ConfigSync itself updated (if changes)
✅ All manifests applied

┌─────────────────────────────────────────────────────────┐
│ STEP 4: Verification (You)                              │
└─────────────────────────────────────────────────────────┘

kubectl --context=my-ran get namespaces
# Shows: openairinterface namespace exists

kubectl --context=my-ran get rootsync -n config-management-system
# Shows: SYNCED status
```

---

## Why You Were Confused (Totally Valid!)

### The Documentation Gap

Most Nephio docs say:
- "Create ClusterContext to register cluster" ✅
- "Create PackageVariants to deploy packages" ✅
- **But they DON'T emphasize:**
  - ⚠️ You MUST manually bootstrap ConfigSync
  - ⚠️ ClusterContext alone does nothing
  - ⚠️ Packages don't magically appear on clusters

### What's Usually Missing

```
Typical docs: "Create ClusterContext, then PackageVariants, done!"

Reality: "Create ClusterContext, PackageVariants, 
         THEN manually install ConfigSync on EACH cluster,
         THEN it works"
```

---

## Summary: Your Question Answered

### Q: "Without connection info, how does Nephio apply packages?"

**A: It doesn't!**

The actual flow is:
1. **Nephio (Porch)** renders packages
2. **Nephio (Porch)** writes to git repos  
3. **ConfigSync (on cluster)** pulls from git
4. **ConfigSync (on cluster)** applies packages

### Q: "What's the point of ClusterContext?"

**A: Just metadata for rendering.**

Used by:
- Porch to fill in cluster-name setter
- Network operators to validate IPs
- Package generators to know available CNIs
- **NOT used for cluster access**

### Q: "What's the point of packages if Nephio can't access clusters?"

**A: Git is the delivery mechanism.**

Packages go:
- Nephio → Git repo → ConfigSync → Cluster
- **Not:** Nephio → Cluster

---

## The Complete Picture

### Required Components

| Component | Where | Purpose |
|-----------|-------|---------|
| ClusterContext | Management cluster | Metadata for rendering |
| Repository CRs | Management cluster | Tell Porch about git repos |
| PackageVariants | Management cluster | Tell Porch what to render |
| Porch | Management cluster | Renders and commits to git |
| Git repos | GitHub/GitLab | Delivery mechanism |
| **ConfigSync** | **Workload cluster** | **Pulls from git and applies** |
| RootSync | Workload cluster | Tells ConfigSync which repo |

### The Manual Step

```
YOU MUST MANUALLY DO THIS ONCE PER CLUSTER:

kubectl --context=my-ran apply -f configsync.yaml
kubectl --context=my-ran apply -f rootsync.yaml

After this, everything is automatic via GitOps
```

---

Does this clarify how it all works? The key insight is that **Nephio is a GitOps orchestrator**, not a direct cluster manager. ConfigSync is the essential bridge between git and your clusters!