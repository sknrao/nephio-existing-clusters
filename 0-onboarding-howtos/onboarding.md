Below is a **practical, end-to-end guide** to onboarding an **existing Kubernetes cluster** into **Nephio** using **ClusterContext**, including **what information you need**, **how Nephio uses it**, and **what Nephio expects from a workload cluster**.

---

## 1. What is ClusterContext in Nephio (quick recap)

In Nephio, a **ClusterContext** is the **declarative representation of a workload cluster** inside the Nephio management plane.

It provides:

* How Nephio can **authenticate to the cluster**
* How it can **apply configs (KRM packages)**
* Metadata describing the cluster’s **role, region, and capabilities**

Nephio **does not create** the cluster in this case — it **onboards** an already-existing one.

---

## 2. High-level onboarding flow

```text
Existing Cluster
   │
   │  (kubeconfig + metadata)
   ▼
Nephio Management Cluster
   │
   ├─ ClusterContext (API object)
   ├─ Secret (credentials)
   └─ Porch packages → Git → applied to workload cluster
```

---

## 3. Information you need from your existing cluster

### Mandatory information

You must collect the following from the workload cluster:

### 1️⃣ Kubeconfig with sufficient RBAC

Nephio needs **cluster-admin–level access** (or equivalent).

From the workload cluster:

```bash
kubectl config view --minify --raw > workload-cluster.kubeconfig
```

Minimum permissions required:

* Create/update/delete:

  * Namespaces
  * CRDs
  * Deployments, DaemonSets, Services
  * Network policies
* Apply arbitrary KRM resources

> ⚠️ Nephio assumes it can **fully manage lifecycle** of deployed resources.

---

### 2️⃣ Cluster name (unique in Nephio)

Example:

```text
edge-cluster-01
```

Used as:

* ClusterContext name
* Package targeting selector
* Inventory identity

---

### 3️⃣ Cluster labels / metadata

Nephio heavily relies on **labels** for targeting.

Typical labels:

```yaml
region: us-central
site: edge-01
cluster-type: workload
nephio.org/role: workload
```

These labels determine:

* Which packages get deployed
* Which interfaces / network functions apply

---

### 4️⃣ API server endpoint (usually in kubeconfig)

Automatically extracted from kubeconfig:

```yaml
server: https://10.0.0.5:6443
```

---

### Optional but strongly recommended

* Kubernetes version
* CNI type (Calico, Cilium, etc.)
* Multi-network capability (Multus present or not)
* Infrastructure type (bare metal, VM, cloud)

---

## 4. Creating the ClusterContext

### Step 1: Create a Secret with kubeconfig

In the **Nephio management cluster**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: edge-cluster-01-kubeconfig
  namespace: nephio-system
type: Opaque
stringData:
  kubeconfig: |
    <PASTE WORKLOAD CLUSTER KUBECONFIG HERE>
```

Apply:

```bash
kubectl apply -f kubeconfig-secret.yaml
```

---

### Step 2: Create the ClusterContext

Example ClusterContext:

```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: edge-cluster-01
  namespace: nephio-system
  labels:
    nephio.org/role: workload
    region: us-central
    site: edge-01
spec:
  kubeconfig:
    secretRef:
      name: edge-cluster-01-kubeconfig
      key: kubeconfig
  contextName: ""
```

Apply:

```bash
kubectl apply -f clustercontext.yaml
```

> `contextName` can be empty if kubeconfig has a single context.

---

### Step 3: Verify onboarding

```bash
kubectl get clustercontexts -n nephio-system
kubectl describe clustercontext edge-cluster-01 -n nephio-system
```

Nephio will:

* Validate connectivity
* Start reconciling package deployments

---

## 5. What Nephio expects from a workload cluster

### ✅ Mandatory expectations

#### 1️⃣ Standard Kubernetes cluster

* CNCF-conformant Kubernetes
* CRDs enabled
* Admission controllers enabled

#### 2️⃣ Full lifecycle control

Nephio assumes:

* It can **apply**, **update**, and **delete** resources
* No manual drift correction on managed namespaces

---

### ⚠️ Strong expectations (not always enforced, but assumed)

#### 3️⃣ GitOps-compatible behavior

* Nephio pushes config via **Porch**
* Cluster state must converge to Git state
* Manual changes may be reverted

---

#### 4️⃣ Networking capabilities (depends on use case)

If doing **telco / multi-network workloads**, Nephio typically expects:

* **CNI plugin installed** (Calico / Cilium)
* **Multus CNI** (for secondary networks)
* IPAM support (where applicable)

Nephio itself does NOT install CNI unless packaged.

---

#### 5️⃣ Namespace isolation

Nephio assumes it can:

* Create namespaces
* Enforce naming conventions
* Own specific namespaces (e.g., `nephio-*`)

---

## 6. What Nephio does NOT require

❌ Nephio does NOT require:

* Cluster API (CAPI)
* Specific cloud provider
* Bare metal vs cloud distinction
* Preinstalled telco CNFs

---

## 7. Common pitfalls

### ❌ Insufficient RBAC

Symptoms:

* Packages stuck in `Rendering` or `Applying`
* Errors like `forbidden: User cannot create CRDs`

Fix:

* Use `cluster-admin` during onboarding

---

### ❌ Kubeconfig context mismatch

Fix:

* Ensure kubeconfig has correct `current-context`
* Or explicitly set `contextName` in ClusterContext

---

### ❌ Missing labels

Fix:

* Add cluster labels early
* Packages rely heavily on label selectors

---

## 8. Minimal checklist before onboarding

✅ Existing cluster reachable
✅ cluster-admin kubeconfig
✅ Unique cluster name
✅ Meaningful labels
✅ Networking stack known

---

## 9. Next steps after ClusterContext

Once onboarded, you typically:

1. Create **PackageVariants**
2. Bind packages to cluster labels
3. Deploy infra → networking → workloads
4. Observe reconciliation via Porch

---

If you want, I can:

* Review your **actual ClusterContext YAML**
* Help you design **labeling strategy**
* Walk through **Porch package binding**
* Explain **Nephio + Multus expectations** for telco CNFs

Just tell me how far you want to go.
