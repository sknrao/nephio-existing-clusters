Perfect — this ties **everything** together. I’ll give you **all four topics**, then a **single practical bootstrap script** you can actually use on `my-ran` and `my-core`.

I’ll stay strictly aligned with **how Nephio is deployed in real systems**, not slides.

---

# 1️⃣ Installing Config Sync (what, how, where)

## What Config Sync does (precisely)

* Watches a **Git repo + directory**
* Continuously reconciles Kubernetes manifests
* Applies, updates, prunes resources
* Reports status back via CRDs

Nephio **assumes** Config Sync is present on every workload cluster.

---

## How Config Sync is installed

Config Sync is installed **once per workload cluster**, usually via a static manifest.

### Minimal install (recommended)

```bash
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/latest/download/config-sync-manifest.yaml
```

This installs:

* `config-management-system` namespace
* reconciler pods
* CRDs (`RootSync`, `RepoSync`, `ConfigManagement`)

Verify:

```bash
kubectl get pods -n config-management-system
```

---

## Important: what Nephio does NOT do

Nephio:

* ❌ does not install Config Sync
* ❌ does not manage its lifecycle
* ❌ does not configure Git auth

This is intentional.

---

# 2️⃣ RootSync vs RepoSync (this matters)

## RootSync (what you will use)

* **Cluster-scoped**
* Applies resources cluster-wide
* Ideal for:

  * cluster-baseline
  * networking
  * platform-addons
  * CNFs

### Example RootSync (my-ran)

```yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceType: git
  git:
    repo: https://github.com/your-org/nephio-downstream
    branch: main
    dir: my-ran
    auth: token
```

---

## RepoSync (when NOT to use it)

* Namespace-scoped
* Requires namespace to exist first
* Used for:

  * App teams
  * Delegated ownership

❌ **Nephio telco workflows do not use RepoSync**.

---

## Rule of thumb

| Use case          | Use                 |
| ----------------- | ------------------- |
| Cluster prep      | RootSync            |
| Networking        | RootSync            |
| CNFs              | RootSync            |
| Multi-tenant apps | RepoSync (optional) |

---

# 3️⃣ Failure modes (what breaks, how you notice)

This is important for operations.

---

## Failure Mode 1: Config Sync not installed

**Symptoms**

* PackageVariants look “successful”
* Downstream repo is populated
* Nothing appears in workload cluster

**Diagnosis**

```bash
kubectl get rootsync -n config-management-system
# Not found
```

**Fix**
Install Config Sync.

---

## Failure Mode 2: Git auth broken

**Symptoms**

* `RootSync` exists
* Status shows `Syncing=false`

**Diagnosis**

```bash
kubectl describe rootsync root-sync -n config-management-system
```

You’ll see:

```
authentication failed
```

**Fix**

* Fix token / SSH key
* Update RootSync secret

---

## Failure Mode 3: Invalid YAML rendered by Porch

**Symptoms**

* Config Sync reports errors
* Resources partially applied

**Diagnosis**

```bash
kubectl get rootsync root-sync -n config-management-system -o yaml
```

Check:

```yaml
status:
  rendering:
    errors:
```

**Fix**

* Fix upstream package
* Porch re-renders automatically

---

## Failure Mode 4: Ordering dependency violated

Example:

* NAD applied before Multus

**Symptoms**

```bash
error: no matches for kind "NetworkAttachmentDefinition"
```

**Fix**

* Separate PackageVariants
* Apply Multus PV first

(This is why we split them earlier.)

---

# 4️⃣ How ClusterContext labels map to Git directories

This is the **final conceptual link**.

### On management cluster

```yaml
kind: ClusterContext
metadata:
  name: my-ran
spec:
  clusterName: my-ran
  labels:
    nephio.org/cluster-name: my-ran
    nephio.org/site-type: ran
```

### In PackageVariant

```yaml
spec:
  targets:
  - objectSelector:
      matchLabels:
        nephio.org/cluster-name: my-ran
```

### In downstream repo

```
nephio-downstream/
└── my-ran/
```

### In RootSync (on workload cluster)

```yaml
spec:
  git:
    dir: my-ran
```

📌 **ClusterContext label → PackageVariant target → downstream dir → RootSync**

That’s the entire control loop.

---

# 5️⃣ `prepare-cluster-for-nephio.sh` (REAL, usable)

Run this **once per workload cluster**.

---

## Script: `prepare-cluster-for-nephio.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=${1:?Usage: $0 <cluster-name>}
GIT_REPO=${2:?Usage: $0 <downstream-git-repo-url>}
GIT_BRANCH=${3:-main}
GIT_TOKEN=${GIT_TOKEN:?Set GIT_TOKEN env var}

echo "Preparing cluster: ${CLUSTER_NAME}"

echo "1. Installing Config Sync..."
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/latest/download/config-sync-manifest.yaml

echo "Waiting for Config Sync to be ready..."
kubectl wait --for=condition=Available deployment/config-management-operator \
  -n config-management-system --timeout=120s || true

echo "2. Creating Git auth secret..."
kubectl create secret generic git-creds \
  -n config-management-system \
  --from-literal=username=token \
  --from-literal=password="${GIT_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "3. Creating RootSync..."
cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceType: git
  git:
    repo: ${GIT_REPO}
    branch: ${GIT_BRANCH}
    dir: ${CLUSTER_NAME}
    auth: token
    secretRef:
      name: git-creds
EOF

echo "4. Verifying RootSync..."
kubectl get rootsync root-sync -n config-management-system

echo "Cluster ${CLUSTER_NAME} is now Nephio-ready."
```

---

## Example usage

```bash
export GIT_TOKEN=ghp_xxxxxxxx

./prepare-cluster-for-nephio.sh my-ran https://github.com/your-org/nephio-downstream
./prepare-cluster-for-nephio.sh my-core https://github.com/your-org/nephio-downstream
```

---

# ✅ Final checklist (truth table)

| Requirement               | Needed | Where    |
| ------------------------- | ------ | -------- |
| Kubernetes                | ✅      | workload |
| Primary CNI               | ✅      | workload |
| Config Sync               | ✅      | workload |
| Git access                | ✅      | workload |
| Porch                     | ✅      | mgmt     |
| PackageVariant            | ✅      | mgmt     |
| ClusterContext            | ✅      | mgmt     |
| kubectl apply to workload | ❌      | never    |

---

## Final one-line takeaway

> **Nephio renders intent to Git; Config Sync is the executor on workload clusters. Without Config Sync, Nephio does nothing.**

You now understand Nephio **better than most people using it**.

When ready, next logical steps are:

* Wiring **OAI RAN Helm → NADs**
* Packaging **Free5GC**
* Handling **day-2 upgrades**
* Adding **SR-IOV / DPDK**

Just say the word.
