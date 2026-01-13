# Complete PackageVariant Deployment Workflow

## Overview

You're correct - I showed the KPT packages but not how Nephio actually deploys them! Here's the complete picture:

```
┌─────────────────────────────────────────────────────────────┐
│ Nephio Management Cluster                                   │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │ Upstream Repos   │         │ PackageVariants  │         │
│  │ (Blueprints)     │────────▶│ (Deployment      │         │
│  │                  │         │  Instructions)   │         │
│  │ • multus-cni     │         │                  │         │
│  │ • whereabouts    │         │ • multus-my-ran  │         │
│  │ • network-intents│         │ • multus-my-core │         │
│  │ • nad-renderer   │         │ • nads-my-ran    │         │
│  └──────────────────┘         └──────────────────┘         │
│                                        │                     │
│                                        ▼                     │
│                          ┌──────────────────────┐           │
│                          │ Porch Controller     │           │
│                          │ (Renders packages)   │           │
│                          └──────────────────────┘           │
│                                        │                     │
└────────────────────────────────────────┼─────────────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                         │
                    ▼                                         ▼
         ┌──────────────────────┐                  ┌──────────────────────┐
         │ Downstream Repo      │                  │ Downstream Repo      │
         │ nephio-my-ran        │                  │ nephio-my-core       │
         │                      │                  │                      │
         │ Rendered packages:   │                  │ Rendered packages:   │
         │ • multus-cni/        │                  │ • multus-cni/        │
         │ • whereabouts-ipam/  │                  │ • whereabouts-ipam/  │
         │ • network-attachments│                  │ • network-attachments│
         └──────────────────────┘                  └──────────────────────┘
                    │                                         │
                    │ ConfigSync/                             │ ConfigSync/
                    │ Flux pulls                              │ Flux pulls
                    ▼                                         ▼
         ┌──────────────────────┐                  ┌──────────────────────┐
         │ my-ran cluster       │                  │ my-core cluster      │
         │                      │                  │                      │
         │ Deployed resources:  │                  │ Deployed resources:  │
         │ • Multus DaemonSet   │                  │ • Multus DaemonSet   │
         │ • Whereabouts DS     │                  │ • Whereabouts DS     │
         │ • ran-ctrl-net NAD   │                  │ • core-ctrl-net NAD  │
         │ • ran-user-net NAD   │                  │ • core-user-net NAD  │
         └──────────────────────┘                  └──────────────────────┘
```

## Step-by-Step Deployment

### Prerequisites

1. **Nephio Management Cluster** running with Porch
2. **Git Repositories** (3 repos needed):
   - Blueprint repo (upstream): Your networking packages
   - my-ran repo (downstream): Rendered packages for RAN cluster
   - my-core repo (downstream): Rendered packages for Core cluster
3. **Workload Clusters Registered** with Nephio

### Step 1: Set Up Git Repositories

```bash
# Create blueprint repository
mkdir -p nephio-networking-packages
cd nephio-networking-packages

# Add the KPT packages I created
git clone <temp-location>/multus-cni
git clone <temp-location>/whereabouts-ipam
git clone <temp-location>/network-intents
git clone <temp-location>/network-attachment-renderer

git init
git add .
git commit -m "Initial networking blueprints"
git remote add origin https://github.com/YOUR-ORG/nephio-networking-packages.git
git push -u origin main

# Create downstream repos (empty initially)
mkdir nephio-my-ran && cd nephio-my-ran
git init
echo "# Deployment packages for my-ran cluster" > README.md
git add . && git commit -m "Initial commit"
git remote add origin https://github.com/YOUR-ORG/nephio-my-ran.git
git push -u origin main

mkdir nephio-my-core && cd nephio-my-core
git init
echo "# Deployment packages for my-core cluster" > README.md
git add . && git commit -m "Initial commit"
git remote add origin https://github.com/YOUR-ORG/nephio-my-core.git
git push -u origin main
```

### Step 2: Register Repositories in Nephio

```bash
# Switch to your management cluster context
kubectl config use-context nephio-mgmt

# Apply repository definitions
kubectl apply -f repository-setup.yaml
```

Wait for repositories to sync:
```bash
kubectl get repositories -n default
# Should show all 3 repos as Ready
```

### Step 3: Deploy PackageVariants

```bash
# Apply all PackageVariants
kubectl apply -f packagevariants-networking.yaml
```

### Step 4: Monitor PackageVariant Status

```bash
# Check PackageVariant status
kubectl get packagevariants -n default

# Expected output:
# NAME                  AGE   READY
# multus-my-ran         30s   True
# multus-my-core        30s   True
# whereabouts-my-ran    30s   True
# whereabouts-my-core   30s   True
# network-intents       30s   True
# nads-my-ran          30s   True
# nads-my-core         30s   True
```

Check individual PackageVariant:
```bash
kubectl describe packagevariant multus-my-ran -n default
```

### Step 5: Verify Package Revisions

```bash
# Check rendered packages in downstream repos
kubectl get packagerevisions -n default | grep my-ran

# Should see:
# nephio-my-ran-multus-cni-v1
# nephio-my-ran-whereabouts-ipam-v1
# nephio-my-ran-network-attachments-v1
```

### Step 6: Approve Packages (if needed)

If packages are in "Draft" state:
```bash
# Propose packages
kpt alpha rpkg propose nephio-my-ran-multus-cni-v1 -n default

# Approve packages
kpt alpha rpkg approve nephio-my-ran-multus-cni-v1 -n default

# Or using kubectl
kubectl patch packagerevision nephio-my-ran-multus-cni-v1 -n default \
  --type=merge -p '{"spec":{"lifecycle":"Published"}}'
```

### Step 7: Verify Git Commits

```bash
# Check downstream repos - should have new commits
cd nephio-my-ran
git pull

# Should see directories:
# multus-cni/
# whereabouts-ipam/
# network-attachments/
```

### Step 8: Deploy to Workload Clusters

Configure ConfigSync or Flux on each workload cluster:

**For my-ran cluster:**
```yaml
# configsync-ran.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/YOUR-ORG/nephio-my-ran.git
    branch: main
    dir: /
    auth: token
    secretRef:
      name: git-creds
```

**For my-core cluster:**
```yaml
# configsync-core.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/YOUR-ORG/nephio-my-core.git
    branch: main
    dir: /
    auth: token
    secretRef:
      name: git-creds
```

### Step 9: Verify Deployment on Workload Clusters

```bash
# On my-ran cluster
kubectl config use-context my-ran

# Check Multus
kubectl get daemonsets -n kube-system | grep multus
kubectl get pods -n kube-system -l app=multus

# Check Whereabouts
kubectl get daemonsets -n kube-system | grep whereabouts
kubectl get pods -n kube-system -l app=whereabouts

# Check NADs
kubectl get network-attachment-definitions -n openairinterface
# Should show: ran-ctrl-net, ran-user-net

# Repeat for my-core cluster
```

## Understanding the Flow

### 1. Blueprint Packages (Upstream)
These are your "templates" - generic, reusable packages:
- `multus-cni/` - Works on any cluster
- `whereabouts-ipam/` - Works on any cluster
- `network-intents/` - Cluster-agnostic network definitions
- `network-attachment-renderer/` - Logic to create NADs

### 2. PackageVariants (Deployment Instructions)
These tell Nephio:
- Which blueprint to use
- Which cluster to deploy to
- What customizations to apply (setters)
- Which KRM functions to run

### 3. Downstream Packages (Rendered)
Porch controller:
- Clones upstream package
- Applies setters (cluster-specific values)
- Runs KRM functions
- Commits to downstream repo

### 4. Actual Deployment
ConfigSync/Flux on workload cluster:
- Watches downstream repo
- Applies manifests to cluster
- Reports sync status

## Key Differences from Manual Apply

| Aspect | Manual Apply | PackageVariant |
|--------|--------------|----------------|
| Source of truth | Local files | Git repos |
| Customization | Manual editing | Setters + functions |
| Multi-cluster | Copy-paste + edit | One PV per cluster |
| Updates | Re-apply manually | Update upstream, PVs propagate |
| Rollback | Manual restore | Git revert |
| Auditability | None | Full Git history |

## Common Issues and Solutions

### Issue 1: PackageVariant stuck in "Progressing"

```bash
# Check events
kubectl describe packagevariant multus-my-ran -n default

# Common causes:
# - Upstream repo not accessible
# - KRM function failure
# - Invalid setter values
```

### Issue 2: Package not appearing in downstream repo

```bash
# Check PackageRevision status
kubectl get packagerevisions -n default

# If in Draft state, approve it
kubectl patch packagerevision <name> -n default \
  --type=merge -p '{"spec":{"lifecycle":"Published"}}'
```

### Issue 3: ConfigSync not syncing

```bash
# Check RootSync status
kubectl get rootsync -n config-management-system

# Check sync logs
kubectl logs -n config-management-system \
  deployment/root-reconciler
```

## Simplified Alternative: Direct Apply Without PackageVariants

If PackageVariants feel too complex for your 2-cluster setup:

```bash
# 1. Render packages locally
cd multus-cni
kpt fn eval --image gcr.io/kpt-fn/apply-setters:v0.2

# 2. Apply directly to cluster
kubectl apply -f multus-cni/ --context my-ran

# This is valid! PackageVariants are optional.
# Use them when you want GitOps workflow.
```

## Recommendation for Your Setup

Given you have only 2 clusters and are learning:

**Option A: Full Nephio Way (with PackageVariants)**
- More setup initially
- Better for production
- True GitOps workflow

**Option B: Hybrid (KPT packages + manual render/apply)**
- Use KPT packages for structure
- Render locally with `kpt fn eval`
- Apply with `kubectl apply`
- Easier to understand

**Option C: Pure Manual (what you have now)**
- Simplest
- Best for learning/experimentation
- Migrate to A or B later

I'd suggest **Option B** for you - use the KPT packages I created, but skip PackageVariants until you need true multi-cluster GitOps.

Would you like me to show the Option B workflow in detail?