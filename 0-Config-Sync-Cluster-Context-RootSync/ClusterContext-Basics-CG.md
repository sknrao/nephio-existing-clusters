This is an **excellent, fundamental question**, and you are absolutely right to pause here.
Let me answer it **clearly, precisely, and without hand-waving**, because this is the core of how Nephio actually *touches* workload clusters.

---

# Short answer (then we’ll unpack it)

✅ **Yes** — something *must* run on each workload cluster to pull rendered manifests from Git and apply them.
That component is **Config Sync (from Anthos Config Management)**.

❌ Nephio **does NOT** directly kubectl-apply to workload clusters.
❌ Porch **does NOT** apply manifests to clusters.
❌ Git alone does nothing.

👉 **Config Sync is mandatory on every workload cluster.**

---

# Correct mental model (this is the key)

Nephio uses a **pure GitOps execution model**.

```
Porch → Git (downstream repo) → Config Sync → kubernetes-apiserver
```

So your intuition is **100% correct**.

---

# What actually happens end-to-end

Let’s walk through **exactly** how `my-ran` gets a NAD.

### 1️⃣ You create PackageVariant (on mgmt cluster)

* Targets `my-ran`
* References upstream package
* Specifies downstream repo

### 2️⃣ Porch renders the package

* Applies setters
* Resolves cluster-specific values
* Writes **rendered YAML** to:

```
nephio-downstream/my-ran/networking/v1/
```

### 3️⃣ Config Sync (on my-ran cluster)

* Watches `nephio-downstream`
* Detects new commit
* Applies YAML to `my-ran` cluster

✔ Now the NAD exists in `my-ran`

---

# So yes — **Config Sync is REQUIRED**

Nephio assumes **Config Sync is already installed** on each workload cluster.

This is not optional.

---

# Minimum required components on workload clusters

Here is the **complete and exact list**.

---

## 1️⃣ Config Sync (MANDATORY)

**Purpose**

* Pull from downstream Git repo
* Apply rendered YAML

**Runs on**

* Every workload cluster (`my-ran`, `my-core`)

**Installed once per cluster**

Nephio will **not install it for you**.

---

## 2️⃣ Kubernetes (obviously)

* Any CNCF-conformant Kubernetes
* Baremetal, single-node is fine
* kube-apiserver reachable from mgmt cluster

---

## 3️⃣ Primary CNI (already present)

* Calico, Flannel, etc.
* Required before Multus
* You already have this ✔

---

## 4️⃣ Git access (implicit requirement)

Each workload cluster must be able to:

* Reach the Git repo (HTTPS or SSH)
* Authenticate (token, SSH key, etc.)

This is configured in **Config Sync RootSync**

---

# What is *NOT* required on workload clusters

❌ Porch
❌ kpt CLI
❌ PackageVariant CRDs
❌ Nephio controllers
❌ Direct access to upstream repos

All of that runs **only on the management cluster**.

---

# Config Sync specifics (important)

On each workload cluster, you will have:

### RootSync object

Example (simplified):

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

For `my-core`, only `dir:` changes.

This is the **binding** between:

* A cluster
* A directory in downstream repo

---

# Does Nephio install Config Sync?

❌ **No**

This is intentional:

* Nephio treats clusters as **externally managed**
* You may use any bootstrap mechanism (cloud-init, Ansible, PXE, etc.)

---

# Summary table (pin this)

| Component      | Mgmt cluster | Workload cluster |
| -------------- | ------------ | ---------------- |
| Porch          | ✅            | ❌                |
| PackageVariant | ✅            | ❌                |
| ClusterContext | ✅            | ❌                |
| Config Sync    | ❌            | ✅                |
| Git creds      | ❌            | ✅                |
| Multus         | ❌            | ✅ (via GitOps)   |
| Whereabouts    | ❌            | ✅ (via GitOps)   |

---

# Final, precise answer to your question

> **Yes — Config Sync must run on every workload cluster.
> Other than Kubernetes, primary CNI, Git access, and Config Sync, there are no additional mandatory Nephio requirements.**

Everything else (Multus, IPAM, NADs, addons, CNFs) is delivered **through GitOps**.

---

## Why this is powerful (and why Nephio chose this)

* Zero kubeconfig sprawl
* Full audit trail
* Rollback = `git revert`
* Scales to thousands of clusters
* Air-gapped friendly

---

If you want next, I can:

* Show **Config Sync install YAML**
* Explain **RootSync vs RepoSync**
* Walk through **failure modes** (what breaks if Config Sync is down)
* Show **how Nephio labels drive RootSync directory structure**

Just tell me where you want to go next.
