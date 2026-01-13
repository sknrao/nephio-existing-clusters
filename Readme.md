# Nephio Integration Workflow - Complete Guide

## Starting Point

✅ **Prerequisites (Already Done):**
- Nephio management cluster is running
- `my-ran` workload cluster is running (with Calico CNI)
- `my-core` workload cluster is running (with Calico CNI)
- `kubectl` configured with contexts for all 3 clusters
- GitHub account with permissions to create repositories

## End Goal

After completing this workflow:
- ✅ Both workload clusters registered with Nephio
- ✅ Infrastructure packages deployed (ConfigSync, storage, networking)
- ✅ GitOps-based management enabled
- ✅ Ready to deploy 5G network functions (OAI RAN, Free5GC)

---

## Workflow Overview

```
Step 1: Create 4 Git Repositories
         ↓
Step 2: Populate Blueprint Repo with Packages
         ↓
Step 3: Populate Management Config Repo
         ↓
Step 4: Apply Management Configuration
         ↓
Step 5: Verify Repository Registration
         ↓
Step 6: Create and Apply PackageVariants
         ↓
Step 7: Approve PackageRevisions
         ↓
Step 8: Bootstrap ConfigSync on Workload Clusters
         ↓
Step 9: Verify Deployment
         ↓
Step 10: Test Everything
```

**Estimated Time:** 90-120 minutes

---

## Step 1: Create 4 Git Repositories (15 min)

### 1.1 Create Repositories on GitHub

```bash
# Set your GitHub organization/username
export GITHUB_ORG="your-github-username"

# Create all 4 repositories
gh repo create ${GITHUB_ORG}/nephio-management-config --public
gh repo create ${GITHUB_ORG}/nephio-blueprints --public
gh repo create ${GITHUB_ORG}/nephio-my-ran --public
gh repo create ${GITHUB_ORG}/nephio-my-core --public
```

### 1.2 Initialize nephio-management-config

```bash
mkdir -p nephio-management-config
cd nephio-management-config

# Create directory structure
mkdir -p cluster-contexts
mkdir -p repositories
mkdir -p packagevariants/{baseline,addons,networking}

# Create root kustomization.yaml
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - cluster-contexts/
  - repositories/
  - packagevariants/baseline/
  - packagevariants/addons/
  - packagevariants/networking/
EOF

# Create README
echo "# Nephio Management Configuration" > README.md
echo "Contains ClusterContexts, Repository CRs, and PackageVariants" >> README.md

# Initialize git
git init
git add .
git commit -m "Initial structure"
git branch -M main
git remote add origin https://github.com/${GITHUB_ORG}/nephio-management-config.git
git push -u origin main

cd ..
```

### 1.3 Initialize nephio-blueprints

```bash
mkdir -p nephio-blueprints
cd nephio-blueprints

echo "# Nephio Blueprint Packages" > README.md
echo "Blueprint packages for infrastructure deployment" >> README.md

git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/${GITHUB_ORG}/nephio-blueprints.git
git push -u origin main

cd ..
```

### 1.4 Initialize nephio-my-ran (Keep Empty)

```bash
mkdir -p nephio-my-ran
cd nephio-my-ran

echo "# Deployment Repository for my-ran Cluster" > README.md
echo "Porch will populate this repository with rendered packages" >> README.md

git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/${GITHUB_ORG}/nephio-my-ran.git
git push -u origin main

cd ..
```

### 1.5 Initialize nephio-my-core (Keep Empty)

```bash
mkdir -p nephio-my-core
cd nephio-my-core

echo "# Deployment Repository for my-core Cluster" > README.md
echo "Porch will populate this repository with rendered packages" >> README.md

git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/${GITHUB_ORG}/nephio-my-core.git
git push -u origin main

cd ..
```

**✅ Checkpoint:** You now have 4 empty repositories on GitHub

---

## Step 2: Populate Blueprint Repo with Packages (20 min)

### 2.1 Create cluster-baseline Package

```bash
cd nephio-blueprints

mkdir -p cluster-baseline

# Create Kptfile
cat > cluster-baseline/Kptfile <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: cluster-baseline
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Baseline configuration for Nephio workload clusters
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        cluster-name: my-cluster
        cluster-repo-url: https://github.com/CHANGE-ME/repo.git
        cluster-repo-branch: main
        workload-type: ran
EOF

# Create ConfigSync manifest
cat > cluster-baseline/configsync.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: config-management-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: root-reconciler
  namespace: config-management-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: root-reconciler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: root-reconciler
  namespace: config-management-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reconciler-manager
  namespace: config-management-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reconciler-manager
  template:
    metadata:
      labels:
        app: reconciler-manager
    spec:
      serviceAccountName: root-reconciler
      containers:
      - name: reconciler-manager
        image: gcr.io/config-management-release/reconciler-manager:v1.17.2
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
EOF

# Create RootSync manifest
cat > cluster-baseline/rootsync.yaml <<'EOF'
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/CHANGE-ME/repo.git # kpt-set: ${cluster-repo-url}
    branch: main # kpt-set: ${cluster-repo-branch}
    dir: /
    auth: none
    period: 15s
EOF

# Create namespaces manifest
cat > cluster-baseline/namespaces.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: openairinterface
  labels:
    nephio.org/cluster-name: my-ran # kpt-set: ${cluster-name}
    pod-security.kubernetes.io/enforce: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: free5gc
  labels:
    nephio.org/cluster-name: my-core # kpt-set: ${cluster-name}
    pod-security.kubernetes.io/enforce: baseline
EOF
```

### 2.2 Create platform-addons Package

```bash
mkdir -p platform-addons/storage

# Create Kptfile
cat > platform-addons/Kptfile <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: platform-addons
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Platform add-ons (storage, monitoring)
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        cluster-name: my-cluster
EOF

# Create local-path-provisioner
cat > platform-addons/storage/local-path-provisioner.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: local-path-storage
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: local-path-provisioner-service-account
  namespace: local-path-storage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-path-provisioner
  template:
    metadata:
      labels:
        app: local-path-provisioner
    spec:
      serviceAccountName: local-path-provisioner-service-account
      containers:
      - name: local-path-provisioner
        image: rancher/local-path-provisioner:v0.0.26
        command:
        - local-path-provisioner
        - start
        - --config
        - /etc/config/config.json
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config/
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
      volumes:
      - name: config-volume
        configMap:
          name: local-path-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap":[
        {
          "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths":["/opt/local-path-provisioner"]
        }
      ]
    }
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
```

### 2.3 Create networking Package

```bash
mkdir -p networking/multus-cni
mkdir -p networking/whereabouts-ipam

# Multus Kptfile
cat > networking/multus-cni/Kptfile <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: multus-cni
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Multus CNI for multi-interface support
EOF

# Simplified Multus (for demo - use full version in production)
cat > networking/multus-cni/multus-daemonset.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-multus-ds
  namespace: kube-system
  labels:
    app: multus
spec:
  selector:
    matchLabels:
      name: multus
  template:
    metadata:
      labels:
        name: multus
    spec:
      hostNetwork: true
      containers:
      - name: kube-multus
        image: ghcr.io/k8snetworkplumbingwg/multus-cni:v4.0.2
        command: ["/thin_entrypoint"]
        args: ["--multus-conf-file=auto"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: cni
          mountPath: /host/etc/cni/net.d
        - name: cnibin
          mountPath: /host/opt/cni/bin
      volumes:
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: cnibin
        hostPath:
          path: /opt/cni/bin
EOF

# Whereabouts Kptfile
cat > networking/whereabouts-ipam/Kptfile <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: whereabouts-ipam
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Whereabouts IPAM for dynamic IP allocation
EOF

# Simplified Whereabouts (for demo)
cat > networking/whereabouts-ipam/whereabouts.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: whereabouts
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: whereabouts
  template:
    metadata:
      labels:
        name: whereabouts
    spec:
      hostNetwork: true
      containers:
      - name: whereabouts
        image: ghcr.io/k8snetworkplumbingwg/whereabouts:v0.6.3
        command: ["/ip-control-loop"]
        volumeMounts:
        - name: cnibin
          mountPath: /host/opt/cni/bin
      volumes:
      - name: cnibin
        hostPath:
          path: /opt/cni/bin
EOF
```

### 2.4 Commit and Push

```bash
git add .
git commit -m "Add cluster-baseline, platform-addons, and networking packages"
git push
```

**✅ Checkpoint:** Blueprint repo now contains 3 packages

---

## Step 3: Populate Management Config Repo (15 min)

### 3.1 Add ClusterContexts

```bash
cd ../nephio-management-config

# Create ClusterContexts kustomization
cat > cluster-contexts/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - clustercontext-my-ran.yaml
  - clustercontext-my-core.yaml
EOF

# Create my-ran ClusterContext
cat > cluster-contexts/clustercontext-my-ran.yaml <<'EOF'
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
EOF

# Create my-core ClusterContext
cat > cluster-contexts/clustercontext-my-core.yaml <<'EOF'
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
```

### 3.2 Add Repository CRs

```bash
# Create Repositories kustomization
cat > repositories/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - repository-blueprints.yaml
  - repository-my-ran.yaml
  - repository-my-core.yaml
EOF

# Create blueprints Repository CR
cat > repositories/repository-blueprints.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-blueprints
  namespace: default
spec:
  description: Nephio blueprint packages
  type: git
  content: Package
  deployment: false
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-blueprints.git
    branch: main
    directory: /
EOF

# Create my-ran Repository CR
cat > repositories/repository-my-ran.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-ran
  namespace: default
spec:
  description: Deployment packages for my-ran
  type: git
  content: Package
  deployment: true
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-my-ran.git
    branch: main
    directory: /
EOF

# Create my-core Repository CR
cat > repositories/repository-my-core.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-core
  namespace: default
spec:
  description: Deployment packages for my-core
  type: git
  content: Package
  deployment: true
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-my-core.git
    branch: main
    directory: /
EOF
```

### 3.3 Add PackageVariants (We'll create these in Step 6)

```bash
# Create placeholder kustomizations for now
cat > packagevariants/baseline/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources: []
  # Will add PackageVariant files in Step 6
EOF

cat > packagevariants/addons/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources: []
EOF

cat > packagevariants/networking/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources: []
EOF
```

### 3.4 Commit and Push

```bash
git add .
git commit -m "Add ClusterContexts and Repository CRs"
git push
```

**✅ Checkpoint:** Management config repo contains ClusterContexts and Repository CRs

---

## Step 4: Apply Management Configuration (5 min)

### 4.1 Apply ClusterContexts and Repository CRs

```bash
# Switch to management cluster
kubectl config use-context nephio-mgmt

# Verify you're on the right cluster
kubectl cluster-info

# Apply ClusterContexts
kubectl apply -k cluster-contexts/

# Expected output:
# clustercontext.infra.nephio.org/my-ran created
# clustercontext.infra.nephio.org/my-core created

# Apply Repository CRs
kubectl apply -k repositories/

# Expected output:
# repository.config.porch.kpt.dev/nephio-blueprints created
# repository.config.porch.kpt.dev/nephio-my-ran created
# repository.config.porch.kpt.dev/nephio-my-core created
```

**✅ Checkpoint:** Clusters registered, repositories registered with Porch

---

## Step 5: Verify Repository Registration (5 min)

### 5.1 Check ClusterContexts

```bash
kubectl get clustercontexts

# Expected output:
# NAME      AGE
# my-ran    30s
# my-core   30s
```

### 5.2 Check Repositories

```bash
kubectl get repositories

# Expected output (wait 30-60 seconds for Ready):
# NAME                 TYPE   CONTENT   DEPLOYMENT   READY
# nephio-blueprints    git    Package   false        True
# nephio-my-ran        git    Package   true         True
# nephio-my-core       git    Package   true         True
```

### 5.3 Check Package Discovery

```bash
# Wait for Porch to discover packages (may take 1-2 minutes)
sleep 60

kubectl get packagerevisions

# Expected output (should show packages from blueprints repo):
# NAME                                    PACKAGE              REVISION   ...
# nephio-blueprints-xxx-cluster-baseline  cluster-baseline     v1         ...
# nephio-blueprints-xxx-platform-addons   platform-addons      v1         ...
# nephio-blueprints-xxx-multus-cni        multus-cni          v1         ...
# nephio-blueprints-xxx-whereabouts-ipam  whereabouts-ipam    v1         ...
```

**✅ Checkpoint:** Porch has discovered all packages from blueprint repo

---

## Step 6: Create and Apply PackageVariants (15 min)

### 6.1 Create cluster-baseline PackageVariants

```bash
# Create baseline-my-ran PackageVariant
cat > packagevariants/baseline/baseline-my-ran.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: baseline-my-ran
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: cluster-baseline
    revision: main
  downstream:
    repo: nephio-my-ran
    package: cluster-baseline
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-ran
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-ran
          cluster-repo-url: https://github.com/${GITHUB_ORG}/nephio-my-ran.git
          cluster-repo-branch: main
          workload-type: ran
EOF

# Create baseline-my-core PackageVariant
cat > packagevariants/baseline/baseline-my-core.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: baseline-my-core
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: cluster-baseline
    revision: main
  downstream:
    repo: nephio-my-core
    package: cluster-baseline
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-core
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-core
          cluster-repo-url: https://github.com/${GITHUB_ORG}/nephio-my-core.git
          cluster-repo-branch: main
          workload-type: core
EOF

# Update kustomization
cat > packagevariants/baseline/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - baseline-my-ran.yaml
  - baseline-my-core.yaml
EOF
```

### 6.2 Create platform-addons PackageVariants

```bash
cat > packagevariants/addons/addons-my-ran.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: addons-my-ran
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: platform-addons
    revision: main
  downstream:
    repo: nephio-my-ran
    package: platform-addons
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-ran
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-ran
EOF

cat > packagevariants/addons/addons-my-core.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: addons-my-core
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: platform-addons
    revision: main
  downstream:
    repo: nephio-my-core
    package: platform-addons
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-core
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-core
EOF

cat > packagevariants/addons/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - addons-my-ran.yaml
  - addons-my-core.yaml
EOF
```

### 6.3 Create networking PackageVariants

```bash
cat > packagevariants/networking/multus-my-ran.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: multus-my-ran
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/multus-cni
    revision: main
  downstream:
    repo: nephio-my-ran
    package: multus-cni
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-ran
EOF

cat > packagevariants/networking/multus-my-core.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: multus-my-core
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/multus-cni
    revision: main
  downstream:
    repo: nephio-my-core
    package: multus-cni
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-core
EOF

cat > packagevariants/networking/whereabouts-my-ran.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: whereabouts-my-ran
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/whereabouts-ipam
    revision: main
  downstream:
    repo: nephio-my-ran
    package: whereabouts-ipam
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-ran
EOF

cat > packagevariants/networking/whereabouts-my-core.yaml <<'EOF'
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: whereabouts-my-core
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/whereabouts-ipam
    revision: main
  downstream:
    repo: nephio-my-core
    package: whereabouts-ipam
  adoption: adoptExisting
  packageContext:
    repositoryRef:
      name: nephio-my-core
EOF

cat > packagevariants/networking/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - multus-my-ran.yaml
  - multus-my-core.yaml
  - whereabouts-my-ran.yaml
  - whereabouts-my-core.yaml
EOF
```

### 6.4 Commit and Apply

```bash
# Commit PackageVariants to git
git add .
git commit -m "Add PackageVariants for baseline, addons, and networking"
git push

# Apply cluster-baseline PackageVariants
kubectl apply -k packagevariants/baseline/

# Wait and check
sleep 10
kubectl get packagevariants | grep baseline

# Apply platform-addons PackageVariants
kubectl apply -k packagevariants/addons/

# Wait and check
sleep 10
kubectl get packagevariants | grep addons

# Apply networking PackageVariants
kubectl apply -k packagevariants/networking/

# Wait and check
sleep 10
kubectl get packagevariants | grep -E "multus|whereabouts"
```

**✅ Checkpoint:** All PackageVariants created and applied

---

## Step 7: Approve PackageRevisions (10 min)

### 7.1 Wait for Porch to Render Packages

```bash
# Wait for rendering (takes 30-60 seconds)
echo "Waiting for Porch to render packages..."
sleep 60

# Check PackageRevisions
kubectl get packagerevisions | grep -E "my-ran|my-core"

# Expected to see packages in "Draft" state
```

### 7.2 Approve All PackageRevisions

```bash
# Approve all Draft packages for my-ran
kubectl get packagerevisions -o name | grep my-ran | grep -v blueprints | while read pr; do
  echo "Approving $pr"
  kubectl patch $pr --type=merge -p '{"spec":{"lifecycle":"Published"}}'
done

# Approve all Draft packages for my-core
kubectl get packagerevisions -o name | grep my-core | grep -v blueprints | while read pr; do
  echo "Approving $pr"
  kubectl patch $pr --type=merge -p '{"spec":{"lifecycle":"Published"}}'
done

# Verify all are Published
kubectl get packagerevisions | grep -E "my-ran|my-core"
```

### 7.3 Verify Git Commits

```bash
# Check nephio-my-ran repo
cd ../nephio-my-ran
git pull

ls -la
# Should see: cluster-baseline/, platform-addons/, multus-cni/, whereabouts-ipam/

# Check nephio-my-core repo
cd ../nephio-my-core
git pull

ls -la
# Should see: cluster-baseline/, platform-addons/, multus-cni/, whereabouts-ipam/
```

**✅ Checkpoint:** All packages rendered and committed to downstream repos

---

## Step 8: Bootstrap ConfigSync on Workload Clusters (15 min)

### 8.1 Bootstrap my-ran Cluster

```bash
# Switch to my-ran cluster
kubectl config use-context my-ran

# Apply ConfigSync from rendered package
cd ../nephio-my-ran
kubectl apply -f cluster-baseline/configsync.yaml

# Wait for ConfigSync to be ready
echo "Waiting for ConfigSync pods..."
kubectl wait --for=condition=Ready \
  pod -l app=reconciler-manager \
  -n config-management-system \
  --timeout=300s

# Apply RootSync
kubectl apply -f cluster-baseline/rootsync.yaml

# Verify RootSync is syncing
sleep 10
kubectl get rootsync -n config-management-system
```

### 8.2 Bootstrap my-core Cluster

```bash
# Switch to my-core cluster
kubectl config use-context my-core

# Apply ConfigSync from rendered package
cd ../nephio-my-core
kubectl apply -f cluster-baseline/configsync.yaml

# Wait for ConfigSync to be ready
echo "Waiting for ConfigSync pods..."
kubectl wait --for=condition=Ready \
  pod -l app=reconciler-manager \
  -n config-management-system \
  --timeout=300s

# Apply RootSync
kubectl apply -f cluster-baseline/rootsync.yaml

# Verify RootSync is syncing
sleep 10
kubectl get rootsync -n config-management-system
```

**✅ Checkpoint:** ConfigSync running on both clusters and syncing from git

---

## Step 9: Verify Deployment (10 min)

### 9.1 Verify ConfigSync on Both Clusters

```bash
# On my-ran cluster
kubectl config use-context my-ran

# Check ConfigSync status
kubectl get rootsync -n config-management-system

# Expected output:
# NAME        SOURCECOMMIT   SYNCCOMMIT     STATUS
# root-sync   abc123...      abc123...      SYNCED

# Check ConfigSync pods
kubectl get pods -n config-management-system

# Expected: All pods Running

# On my-core cluster
kubectl config use-context my-core

kubectl get rootsync -n config-management-system
kubectl get pods -n config-management-system
```

### 9.2 Verify Namespaces Created

```bash
# On my-ran
kubectl config use-context my-ran
kubectl get namespaces | grep -E "openairinterface|local-path"

# Expected:
# openairinterface
# local-path-storage
# config-management-system

# On my-core
kubectl config use-context my-core
kubectl get namespaces | grep -E "free5gc|local-path"

# Expected:
# free5gc
# local-path-storage
# config-management-system
```

### 9.3 Verify Storage Deployed

```bash
# On my-ran
kubectl config use-context my-ran

kubectl get storageclass
# Expected: local-path (default)

kubectl get pods -n local-path-storage
# Expected: local-path-provisioner pod Running

# On my-core
kubectl config use-context my-core

kubectl get storageclass
kubectl get pods -n local-path-storage
```

### 9.4 Verify Networking Deployed

```bash
# On my-ran
kubectl config use-context my-ran

kubectl get daemonsets -n kube-system | grep -E "multus|whereabouts"
# Expected: kube-multus-ds, whereabouts

kubectl get pods -n kube-system -l name=multus
kubectl get pods -n kube-system -l name=whereabouts

# On my-core
kubectl config use-context my-core

kubectl get daemonsets -n kube-system | grep -E "multus|whereabouts"
kubectl get pods -n kube-system -l name=multus
kubectl get pods -n kube-system -l name=whereabouts
```

**✅ Checkpoint:** All infrastructure components deployed to both clusters

---

## Step 10: Test Everything (15 min)

### 10.1 Test Storage on my-ran

```bash
kubectl config use-context my-ran

# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF

# Wait and check
sleep 10
kubectl get pvc test-pvc

# Expected: STATUS = Bound

# Create test pod using PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "echo 'Storage test successful' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Wait and check
sleep 20
kubectl get pod test-pod

# Expected: STATUS = Running

# Verify data written
kubectl exec test-pod -- cat /data/test.txt
# Expected: Storage test successful

# Cleanup
kubectl delete pod test-pod
kubectl delete pvc test-pvc
```

### 10.2 Test Multus on my-ran

```bash
# Check Multus is ready
kubectl get daemonset -n kube-system kube-multus-ds

# Check Multus logs (should show no errors)
kubectl logs -n kube-system -l name=multus --tail=50

# Success if no errors in logs
```

### 10.3 Test Whereabouts on my-ran

```bash
# Check Whereabouts is ready
kubectl get daemonset -n kube-system whereabouts

# Check Whereabouts logs
kubectl logs -n kube-system -l name=whereabouts --tail=50

# Success if no errors in logs
```

### 10.4 Repeat Tests on my-core

```bash
kubectl config use-context my-core

# Test storage (same steps as above)
# Test Multus (same steps as above)
# Test Whereabouts (same steps as above)
```

### 10.5 Summary Check

```bash
# Check everything from management cluster
kubectl config use-context nephio-mgmt

echo "=== ClusterContexts ==="
kubectl get clustercontexts

echo "=== Repositories ==="
kubectl get repositories

echo "=== PackageVariants ==="
kubectl get packagevariants

echo "=== PackageRevisions ==="
kubectl get packagerevisions | grep Published

# Check workload clusters
echo "=== my-ran Status ==="
kubectl --context=my-ran get pods -A | grep -v kube-system | head -20

echo "=== my-core Status ==="
kubectl --context=my-core get pods -A | grep -v kube-system | head -20
```

**✅ Final Checkpoint:** All systems operational and tested!

---

## Completion Checklist

- ✅ 4 git repositories created
- ✅ Blueprint repo populated with packages
- ✅ Management config repo populated with CRs
- ✅ ClusterContexts registered
- ✅ Repositories registered with Porch
- ✅ PackageVariants created and applied
- ✅ PackageRevisions approved
- ✅ ConfigSync bootstrapped on both clusters
- ✅ All infrastructure deployed
- ✅ Storage tested and working
- ✅ Networking tested and working

---

## What You Have Now

### On Management Cluster
- ClusterContext registrations for my-ran and my-core
- Repository registrations pointing to git repos
- PackageVariants defining what to deploy where
- Porch rendering and managing packages

### On my-ran Cluster
- ✅ ConfigSync running and syncing from nephio-my-ran repo
- ✅ Namespace: openairinterface (ready for OAI RAN)
- ✅ Storage: local-path StorageClass
- ✅ Networking: Multus CNI + Whereabouts IPAM
- ✅ GitOps-based management enabled

### On my-core Cluster
- ✅ ConfigSync running and syncing from nephio-my-core repo
- ✅ Namespace: free5gc (ready for Free5GC Core)
- ✅ Storage: local-path StorageClass
- ✅ Networking: Multus CNI + Whereabouts IPAM
- ✅ GitOps-based management enabled

---

## Next Steps: Deploy 5G Network Functions

Now that infrastructure is ready, you can:

1. **Add NAD packages** to blueprint repo for network attachments
2. **Create PackageVariants** for OAI RAN (to my-ran)
3. **Create PackageVariants** for Free5GC (to my-core)
4. **Approve and deploy** network functions

Your clusters are now **fully integrated with Nephio** and ready for 5G workloads! 🎉

---

## Troubleshooting

### If ConfigSync doesn't sync:
```bash
kubectl describe rootsync root-sync -n config-management-system
kubectl logs -n config-management-system -l app=reconciler-manager
```

### If Porch doesn't discover packages:
```bash
kubectl describe repository nephio-blueprints
kubectl logs -n porch-system deployment/porch-server
```

### If PackageRevisions stuck in Draft:
```bash
kubectl get packagerevisions -o wide
kubectl describe packagerevision <name>
```

### If storage doesn't work:
```bash
# On nodes, ensure path exists:
sudo mkdir -p /opt/local-path-provisioner
sudo chmod 777 /opt/local-path-provisioner
```

---

## Time Summary

| Step | Duration | Task |
|------|----------|------|
| 1 | 15 min | Create 4 git repositories |
| 2 | 20 min | Populate blueprint repo |
| 3 | 15 min | Populate management config |
| 4 | 5 min | Apply management config |
| 5 | 5 min | Verify registration |
| 6 | 15 min | Create PackageVariants |
| 7 | 10 min | Approve packages |
| 8 | 15 min | Bootstrap ConfigSync |
| 9 | 10 min | Verify deployment |
| 10 | 15 min | Test everything |
| **Total** | **~2 hours** | Complete workflow |