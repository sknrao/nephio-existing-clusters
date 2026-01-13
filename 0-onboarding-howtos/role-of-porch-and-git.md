Great questions — these two points are **where most Nephio confusion actually happens**. I’ll be very explicit and separate **what Nephio *does*** vs **what it deliberately does *not*** do.

---

# 1️⃣ Role of Porch and Git **for cluster lifecycle (NOT workloads)**

> Key idea upfront
> **Nephio does *not* own cluster creation or destruction.**
> It owns **cluster configuration state after the cluster exists**.

Think of Porch + Git as **“Day-1.5 / Day-2 cluster configuration management”**.

---

## 1.1 What “cluster lifecycle” means *in Nephio terms*

| Lifecycle aspect                                              | Owned by Nephio? |
| ------------------------------------------------------------- | ---------------- |
| Create / delete cluster                                       | ❌ No             |
| Scale nodes                                                   | ❌ No             |
| Upgrade Kubernetes version                                    | ❌ No             |
| Install infra components (CNI, Multus, SR-IOV, logging, etc.) | ✅ Yes            |
| Configure networking, namespaces, policies                    | ✅ Yes            |
| Maintain desired state                                        | ✅ Yes            |

Nephio assumes:

> **“The cluster exists. From now on, its configuration is declarative and Git-driven.”**

---

## 1.2 Porch’s exact role

Porch is Nephio’s **KRM package lifecycle controller**.

Porch:

* Manages **KRM packages** stored in Git
* Renders packages per cluster
* Applies them to workload clusters via **ClusterContext**
* Tracks inventory and drift

### Porch does NOT:

* Talk directly to cloud APIs
* Create nodes or VMs
* Replace Cluster API (CAPI)

---

## 1.3 Git’s role (very important distinction)

Git is the **source of truth for cluster configuration**, not runtime state.

```text
Git (desired state)
  ↓
Porch (render + reconcile)
  ↓
Workload cluster (actual state)
```

Git stores:

* CNI installation manifests
* Multus configs
* NetworkAttachmentDefinitions
* Telco infra CRDs
* Namespace and RBAC structure
* Node feature discovery configs
* IPAM configs

---

## 1.4 How cluster lifecycle looks in practice

### Example: onboarding an existing cluster

Once `ClusterContext` exists:

1. You bind a **“cluster-baseline” package**
2. Porch applies:

   * CNI config
   * Multus
   * Node labels
   * SR-IOV device plugin
3. Git now represents the **entire cluster config**

No imperative `kubectl apply` anymore.

---

### Example: cluster reconfiguration

| Change      | What you do        |
| ----------- | ------------------ |
| Add SR-IOV  | Commit new package |
| Change MTU  | Update Git         |
| Enable IPv6 | Update Git         |
| Add logging | Add package        |

Porch detects Git changes → reconciles cluster.

---

## 1.5 What happens if someone changes the cluster manually?

Nephio + Porch assume **GitOps discipline**.

* Manual changes → **drift**
* Drift → overwritten on next reconciliation
* No interactive conflict resolution

> Nephio is intentionally **opinionated**.

---

## 1.6 Cluster deletion scenario

If the cluster disappears:

* Porch reports apply failures
* Git remains unchanged
* Nephio does not attempt recovery

Deletion is **out of scope**.

---

### 🧠 Mental model

> **Terraform / CAPI creates clusters**
> **Nephio configures them declaratively forever**

---

# 2️⃣ Nephio & Multus expectations for Telco CNFs

This is where Nephio becomes **telco-specific**.

---

## 2.1 Why Multus is central to Nephio

Telco CNFs typically need:

* Multiple networks per pod
* Separation of:

  * Control plane traffic
  * User plane traffic
  * OAM traffic

Nephio assumes **multi-network is the default**, not optional.

---

## 2.2 What Nephio expects regarding Multus

### Mandatory for Telco use cases

| Component      | Expected                    |
| -------------- | --------------------------- |
| Primary CNI    | Installed (Calico / Cilium) |
| Multus         | Installed                   |
| Secondary CNIs | macvlan / ipvlan / SR-IOV   |
| IPAM           | Whereabouts / static        |

Nephio may install these via packages, but **it expects them to exist** before CNFs are deployed.

---

## 2.3 How Nephio models networks (important)

Nephio uses **KRM-based network intent**, not imperative NADs.

Typical abstractions:

* Network intent → rendered into:

  * `NetworkAttachmentDefinition`
  * IP pools
  * VLAN mappings
  * MTU configs

All of this is:

* Stored in Git
* Rendered per cluster
* Applied via Porch

---

## 2.4 Expectations from the workload cluster

### Networking prerequisites

The cluster must support:

| Capability                   | Why                   |
| ---------------------------- | --------------------- |
| Multus admission webhook     | Pod network injection |
| CRDs allowed                 | NADs, IPAM CRDs       |
| Node-level networking config | VLANs, PFs, VFs       |
| Privileged DaemonSets        | SR-IOV, DPDK          |

---

### Node expectations (very important)

Nephio assumes nodes can be **labeled and selected**.

Examples:

```yaml
feature.node.kubernetes.io/network-sriov.capable: "true"
nephio.org/role: upf
```

These labels drive:

* Where CNFs land
* Which network attachments apply

---

## 2.5 SR-IOV specific expectations

If using SR-IOV:

* SR-IOV capable NICs
* BIOS + kernel config done beforehand
* IOMMU enabled
* Hugepages configured

Nephio **does not**:

* Configure BIOS
* Install kernel modules

But it **does**:

* Deploy SR-IOV device plugin
* Configure NetworkAttachmentDefinitions
* Assign resources to pods

---

## 2.6 Multus & CNF contract

Nephio assumes CNFs:

* Use **standard Multus annotations**
* Do NOT hardcode NAD names
* Accept network intent via KRM

Example (simplified):

```yaml
k8s.v1.cni.cncf.io/networks:
- name: user-plane-net
- name: control-plane-net
```

Rendered by Nephio from higher-level intent.

---

## 2.7 Failure modes Nephio does not hide

| Problem        | Result                 |
| -------------- | ---------------------- |
| Missing Multus | CNFs fail              |
| Wrong VLAN     | Pods stuck             |
| IPAM exhausted | Pod scheduling failure |
| Node mismatch  | No eligible nodes      |

Nephio surfaces errors but does not auto-correct infra issues.

---

## 2.8 Strong opinions Nephio enforces

* Declarative networking
* Git as single source of truth
* No per-cluster snowflakes
* Repeatable telco topology

This is intentional for **carrier-grade operations**.

---

# Final summary

### Porch + Git

* Manage **cluster configuration**, not cluster existence
* Provide full GitOps lifecycle for infra
* Enforce reconciliation discipline

### Nephio + Multus

* Assume multi-network as baseline
* Expect Multus-ready clusters
* Encode network intent declaratively
* Target telco CNFs with strict contracts

---

If you want, next we can:

* Design a **baseline cluster package**
* Walk through **network intent → NAD rendering**
* Review **SR-IOV onboarding checklist**
* Compare **Nephio vs CAPI responsibilities**

Just say which one.
