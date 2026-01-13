Perfect 👍
I’ll now give you a **clean, end-to-end, step-by-step example** for **onboarding an existing cluster into Nephio using ONE GitHub repo**, with **no assumptions**, and **minimal risk**.

I’ll keep this **conceptual + concrete**, not copy-paste heavy, so the mental model stays intact.

---

# Goal (what we’re building)

* ✅ One **existing Kubernetes cluster**
* ✅ One **GitHub repo**
* ✅ Nephio manages **only what you declare**
* ✅ Safe, incremental adoption

Final state:

```
GitHub (desired state)
   ↓
Porch (package lifecycle)
   ↓
Existing cluster (selected config only)
```

---

# Step 0 — Prerequisites (assumed done)

* Nephio **management cluster** is installed
* Porch is running
* You already created:

  * `ClusterContext` for your existing cluster
* You have a **cluster-admin kubeconfig** for the workload cluster

We will **not** touch cluster creation or CAPI.

---

# Step 1 — Create ONE GitHub repo (per cluster)

Create a new GitHub repo:

```
nephio-existing-cluster-01
```

Empty repo is fine.

Why one repo?

* Clear ownership
* Easy rollback
* Simple audit trail

---

# Step 2 — Decide directory = package mapping

Inside this repo, we’ll use **three directories**, each becoming a **kpt package**.

```
nephio-existing-cluster-01/
├── cluster-baseline/
├── networking/
└── platform-addons/
```

> These are **packages**, not repos.

Porch will treat each directory independently.

---

# Step 3 — Initialize the first (SAFE) package: cluster-baseline

This is the **least risky starting point**.

### cluster-baseline should contain only:

* Namespaces
* Labels
* Non-intrusive RBAC
* Nothing that touches networking or CNFs

Example intent:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nephio-managed
  labels:
    nephio.org/managed: "true"
```

This:

* Proves Git → Porch → Cluster works
* Cannot break the cluster

Commit this to GitHub.

---

# Step 4 — Register the GitHub repo in Porch

In the **management cluster**:

Create a `Repository` object pointing to GitHub.

Conceptually:

```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: existing-cluster-01-repo
  namespace: nephio-system
spec:
  type: git
  git:
    repo: https://github.com/<org>/nephio-existing-cluster-01.git
    branch: main
    directory: /
```

Porch now:

* Knows about the repo
* Can discover packages

---

# Step 5 — Porch discovers packages automatically

Porch will detect:

```
cluster-baseline/
networking/
platform-addons/
```

Each directory becomes:

* A versioned KRM package
* Independently deployable

Nothing is applied yet.

---

# Step 6 — Bind ONLY the baseline package to your cluster

Create a `PackageVariant` (or equivalent binding) that says:

> “Apply `cluster-baseline` to cluster X”

Key idea:

* Binding happens via **cluster labels**
* Not hardcoded cluster names

Example logic:

```yaml
spec:
  targets:
  - clusterSelector:
      matchLabels:
        nephio.org/role: workload
```

Result:

* Porch renders package
* Applies it via ClusterContext
* Namespace appears in cluster

✔ You’ve safely onboarded the cluster.

---

# Step 7 — Expand scope gradually (networking later)

Only **after baseline is stable**:

### networking package may include:

* Multus installation
* NADs
* IPAM configs

### platform-addons may include:

* SR-IOV device plugin
* Node feature discovery
* Monitoring agents

Each addition is:

1. Git commit
2. Porch render
3. Reconcile

No manual kubectl.

---

# Step 8 — What stays unmanaged (important)

Nephio will NOT touch:

* Existing CNFs
* Existing namespaces (unless declared)
* Existing CNI
* Existing secrets

Unless you **declare intent**.

---

# What NOT to do initially

🚫 Do not import existing manifests
🚫 Do not declare kube-system resources
🚫 Do not manage CNI on day one
🚫 Do not enable destructive policies

---

# Visual summary

```
GitHub repo
 ├── cluster-baseline   ← applied first
 ├── networking         ← later
 └── platform-addons    ← later
         ↓
       Porch
         ↓
 Existing cluster
```

---

# Why this works

* Matches Nephio’s GitOps philosophy
* Avoids accidental takeover
* Mirrors official demos (simplified)
* Scales to many clusters later

---

# Before I give you the next step-by-step

Next logical steps could be:

1️⃣ Turn `networking/` into a **Multus + NAD intent package**
2️⃣ Show **PackageVariant YAML** in detail
3️⃣ Walk through **Porch UI / API flow**
4️⃣ Show **how labels control targeting**
5️⃣ Show **how to safely take over existing networking**

👉 Tell me which one you want next, and I’ll go deep on that specific piece.
