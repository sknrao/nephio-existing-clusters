# Complete Cluster Baseline - Questions Answered

## Question 1: Missing Baseline Components

You're absolutely right! I've now added:

### Complete Package Structure

```
cluster-baseline/
├── Kptfile                           # Updated with all setters
├── configsync.yaml                   # GitOps operator ✓
├── rootsync.yaml                     # Git sync config ✓
├── git-credentials-secret.yaml       # Auth for private repos ✓
├── namespaces.yaml                   # REPLACED - see pod-security.yaml
├── pod-security.yaml                 # ✅ NEW - Namespaces + PSS
├── node-configuration.yaml           # ✅ NEW - Node labels
├── default-resource-limits.yaml      # ✅ NEW - LimitRanges
└── storage-class.yaml                # ✅ NEW - Storage classes
```

### What Each New Component Does

#### 1. **pod-security.yaml** (Replaces simple namespaces.yaml)

**What it adds:**
- Pod Security Standards (PSS) labels on each namespace
- Proper security posture for different workload types

**Why it's needed:**
```yaml
# System namespaces = privileged (for CNI, storage)
pod-security.kubernetes.io/enforce: privileged

# NF namespaces = baseline (for 5G capabilities like NET_ADMIN)
pod-security.kubernetes.io/enforce: baseline
```

**Impact:**
- Prevents privilege escalation attacks
- Still allows necessary capabilities for 5G NFs (hostNetwork, NET_ADMIN)
- Kubernetes 1.23+ best practice

#### 2. **node-configuration.yaml** (Node labels)

**What it adds:**
- Automated node labeling job
- Standard Nephio node labels

**Labels applied:**
```bash
nephio.org/cluster-name=my-ran
nephio.org/cluster-type=workload
nephio.org/workload-type=ran
nephio.org/site-id=site-ran-01
topology.kubernetes.io/zone=zone-a
```

**Why it's needed:**
- Nephio operators use these labels to discover clusters
- Enables proper pod scheduling (e.g., "schedule CU-CP on RAN nodes")
- Required for multi-cluster topologies
- Helps with capacity planning and monitoring

**How it works:**
```yaml
# Runs as a Job after cluster-baseline is applied
apiVersion: batch/v1
kind: Job
metadata:
  name: label-nodes-job
spec:
  template:
    spec:
      containers:
      - name: node-labeler
        image: bitnami/kubectl:latest
        command: ["/bin/bash", "/scripts/label-nodes.sh"]
```

#### 3. **default-resource-limits.yaml** (LimitRanges)

**What it adds:**
- Default CPU/memory requests if pods don't specify
- Maximum limits per container/pod
- Minimum required resources

**Example:**
```yaml
spec:
  limits:
  - type: Container
    default:           # If pod doesn't specify limits
      cpu: "2"
      memory: "4Gi"
    defaultRequest:    # If pod doesn't specify requests
      cpu: "500m"
      memory: "1Gi"
    max:               # Maximum allowed
      cpu: "8"
      memory: "16Gi"
    min:               # Minimum required
      cpu: "100m"
      memory: "128Mi"
```

**Why it's needed:**
- **Protection**: Single-node clusters can't afford one pod consuming all resources
- **Best practices**: Forces developers to think about resource needs
- **Scheduling**: Kubernetes can't schedule pods without requests
- **Cost control**: Prevents accidental over-allocation

**Difference from ResourceQuotas (in platform-addons):**

| LimitRange | ResourceQuota |
|------------|---------------|
| Per container/pod limits | Namespace-wide totals |
| Default if not specified | Hard caps across all pods |
| Min/max validation | Total budget enforcement |

You need BOTH:
- LimitRange = "Each container can use 2-8 CPUs"
- ResourceQuota = "This namespace total: 20 CPUs"

#### 4. **storage-class.yaml** (Storage Classes)

**What it adds:**
- Multiple storage class definitions
- Documentation on when to use each

**Classes defined:**
```yaml
1. local-path (default)
   - Reclaim: Delete
   - Use: General purpose

2. local-path-fast
   - Can point to SSD path
   - Use: High-performance workloads

3. local-path-retain
   - Reclaim: Retain
   - Use: Critical data that must survive pod deletion
```

**Why in cluster-baseline vs platform-addons?**

| Component | Location | Reason |
|-----------|----------|--------|
| StorageClass | cluster-baseline | Interface definition |
| Provisioner | platform-addons | Implementation |

Think of it like:
- StorageClass = API contract ("provide storage")
- Provisioner = Implementation ("here's how I provide it")

**Analogy:**
```
StorageClass = "I need a car"
Provisioner = "Here's a Toyota factory"
```

Pods reference StorageClass names, not provisioners. This allows you to swap provisioners (local-path → Rook → NFS) without changing pod specs.

## Question 2: Separate Kptfiles for my-core?

**Short answer: NO, you don't need separate Kptfiles!**

### The Nephio Pattern

```
ONE blueprint package (cluster-baseline)
    │
    ├──> PackageVariant (my-ran) ──> Rendered package in nephio-my-ran repo
    │         └── Different setters
    │
    └──> PackageVariant (my-core) ──> Rendered package in nephio-my-core repo
              └── Different setters
```

### How It Works

**1. Single Blueprint (Upstream)**
```
nephio-blueprints/cluster-baseline/
├── Kptfile                    # Contains ALL possible setters
├── configsync.yaml           # Uses: ${cluster-name}
├── pod-security.yaml         # Uses: ${cluster-name}, ${workload-type}
├── node-configuration.yaml   # Uses: ${cluster-name}, ${site-id}
└── ...
```

**2. Two PackageVariants (Different Configurations)**
```yaml
# PackageVariant 1: my-ran
configMap:
  cluster-name: my-ran          # ← Different
  workload-type: ran            # ← Different
  site-id: site-ran-01          # ← Different
  cluster-repo-url: .../my-ran  # ← Different

# PackageVariant 2: my-core
configMap:
  cluster-name: my-core         # ← Different
  workload-type: core           # ← Different
  site-id: site-core-01         # ← Different
  cluster-repo-url: .../my-core # ← Different
```

**3. Two Rendered Packages (Downstream)**
```
nephio-my-ran/cluster-baseline/
├── configsync.yaml           # Has "my-ran" everywhere
├── pod-security.yaml         # Namespaces labeled "workload-type: ran"
├── node-configuration.yaml   # Labels nodes with "my-ran"

nephio-my-core/cluster-baseline/
├── configsync.yaml           # Has "my-core" everywhere
├── pod-security.yaml         # Namespaces labeled "workload-type: core"
├── node-configuration.yaml   # Labels nodes with "my-core"
```

### Why This is Better Than Separate Kptfiles

**❌ Bad Approach: Separate Kptfiles**
```
cluster-baseline-ran/Kptfile      # Hard-coded ran values
cluster-baseline-core/Kptfile     # Hard-coded core values

Problems:
- Duplicate code
- Must fix bugs twice
- Can't easily add cluster-03
- Version skew between variants
```

**✅ Good Approach: One Kptfile + Setters**
```
cluster-baseline/Kptfile          # Parameterized

Benefits:
- Single source of truth
- Bug fixes apply to all clusters
- Easy to add cluster-03, cluster-04...
- Consistent across all clusters
```

### When You WOULD Need Separate Packages

Only if clusters have **fundamentally different components**, not just different values:

```yaml
# RAN clusters need:
- SRIOV network device plugin
- DPDK configuration
- RU-specific hardware setup

# Core clusters need:
- External database connections
- Load balancers
- Different monitoring stack

# Then create:
cluster-baseline-ran/         # Different components
cluster-baseline-core/        # Different components
```

But for **your case**, where differences are just values (cluster name, repo URL, etc.), use **one package with setters**.

## Practical Example: How Setters Work

### In Your Blueprint (cluster-baseline/node-configuration.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-config-script
  namespace: kube-system
data:
  label-nodes.sh: |
    #!/bin/bash
    CLUSTER_NAME="${CLUSTER_NAME:-my-ran}" # kpt-set: ${cluster-name}
    WORKLOAD_TYPE="${WORKLOAD_TYPE:-ran}"  # kpt-set: ${workload-type}
    SITE_ID="${SITE_ID:-site-01}"          # kpt-set: ${site-id}
    
    kubectl label nodes \
      nephio.org/cluster-name=$CLUSTER_NAME \
      nephio.org/workload-type=$WORKLOAD_TYPE \
      nephio.org/site-id=$SITE_ID
```

### PackageVariant for my-ran Sets Values

```yaml
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: baseline-my-ran
spec:
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-ran      # Replaces ${cluster-name}
          workload-type: ran         # Replaces ${workload-type}
          site-id: site-ran-01       # Replaces ${site-id}
```

### Rendered in nephio-my-ran Repo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-config-script
  namespace: kube-system
data:
  label-nodes.sh: |
    #!/bin/bash
    CLUSTER_NAME="my-ran"          # ← Replaced!
    WORKLOAD_TYPE="ran"            # ← Replaced!
    SITE_ID="site-ran-01"          # ← Replaced!
    
    kubectl label nodes \
      nephio.org/cluster-name=my-ran \
      nephio.org/workload-type=ran \
      nephio.org/site-id=site-ran-01
```

### Same Process for my-core

PackageVariant just uses different setter values:
```yaml
configMap:
  cluster-name: my-core
  workload-type: core
  site-id: site-core-01
```

Result: Same blueprint → Different rendered packages!

## Complete Deployment Flow

```bash
# 1. Create ONE blueprint repo
mkdir nephio-blueprints
cd nephio-blueprints
# Add cluster-baseline/ with ALL new files
git add . && git commit -m "Complete baseline" && git push

# 2. Create TWO deployment repos (empty)
mkdir nephio-my-ran && cd nephio-my-ran
git init && git push

mkdir nephio-my-core && cd nephio-my-core
git init && git push

# 3. Register repos in Nephio management cluster
kubectl apply -f - <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-blueprints
spec:
  type: git
  deployment: false  # Blueprint repo
  git:
    repo: https://github.com/YOU/nephio-blueprints.git
---
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-ran
spec:
  type: git
  deployment: true   # Deployment repo
  git:
    repo: https://github.com/YOU/nephio-my-ran.git
---
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-core
spec:
  type: git
  deployment: true   # Deployment repo
  git:
    repo: https://github.com/YOU/nephio-my-core.git
EOF

# 4. Create TWO PackageVariants (one blueprint, two targets)
kubectl apply -f packagevariants-baseline.yaml

# This creates:
# - baseline-my-ran PackageVariant
# - baseline-my-core PackageVariant

# 5. Porch renders packages with different values
# Check rendered packages:
kubectl get packagerevisions | grep baseline

# 6. Approve and publish
kubectl patch packagerevision baseline-my-ran-v1 \
  --type=merge -p '{"spec":{"lifecycle":"Published"}}'

kubectl patch packagerevision baseline-my-core-v1 \
  --type=merge -p '{"spec":{"lifecycle":"Published"}}'

# 7. Verify in git repos
cd nephio-my-ran && git pull
ls cluster-baseline/
# All files present with "my-ran" values

cd nephio-my-core && git pull
ls cluster-baseline/
# All files present with "my-core" values

# 8. Deploy to actual clusters (manually bootstrap ConfigSync)
kubectl --context my-ran apply -f nephio-my-ran/cluster-baseline/

kubectl --context my-core apply -f nephio-my-core/cluster-baseline/

# 9. After ConfigSync is running, it auto-syncs future changes
```

## Summary Table

| Component | Purpose | Required? | Location |
|-----------|---------|-----------|----------|
| ConfigSync/RootSync | GitOps sync | ✅ Yes | cluster-baseline |
| Namespaces | NF landing zones | ✅ Yes | pod-security.yaml |
| Pod Security | Security posture | ✅ Yes | pod-security.yaml |
| Node Labels | Cluster discovery | ⚠️ Recommended | node-configuration.yaml |
| Resource Limits | Per-pod protection | ⚠️ Recommended | default-resource-limits.yaml |
| Storage Classes | Storage interface | ⚠️ Recommended | storage-class.yaml |

**Minimum viable:** ConfigSync + Namespaces
**Production ready:** All of the above

## Answer to "Do I need separate Kptfiles?"

**NO!** Use:
- ✅ ONE Kptfile with setters (what I provided)
- ✅ TWO PackageVariants with different setter values
- ❌ NOT two separate Kptfile packages

This is the Nephio way and follows GitOps best practices.