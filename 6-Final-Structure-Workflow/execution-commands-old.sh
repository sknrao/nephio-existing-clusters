#!/bin/bash
#==============================================================================
# Complete Nephio Deployment - Exact Commands
# Execute these commands in order
#==============================================================================

set -e  # Exit on error

GITHUB_ORG="YOUR-GITHUB-ORG"  # CHANGE THIS
MGMT_CONTEXT="nephio-mgmt"    # Your management cluster context
RAN_CONTEXT="my-ran"          # Your RAN cluster context
CORE_CONTEXT="my-core"        # Your CORE cluster context

#==============================================================================
# STEP 1: Create Git Repositories
#==============================================================================

echo "Step 1: Creating Git Repositories"

# Create blueprint repo (upstream)
mkdir -p nephio-blueprints
cd nephio-blueprints
git init
echo "# Nephio Blueprint Packages" > README.md
# TODO: Add all package files from artifacts
git add .
git commit -m "Initial blueprints"
gh repo create ${GITHUB_ORG}/nephio-blueprints --public --source=. --push

# Create RAN deployment repo (downstream)
cd ..
mkdir -p nephio-my-ran
cd nephio-my-ran
git init
echo "# Deployment packages for my-ran cluster" > README.md
git add README.md
git commit -m "Initial commit"
gh repo create ${GITHUB_ORG}/nephio-my-ran --public --source=. --push

# Create CORE deployment repo (downstream)
cd ..
mkdir -p nephio-my-core
cd nephio-my-core
git init
echo "# Deployment packages for my-core cluster" > README.md
git add README.md
git commit -m "Initial commit"
gh repo create ${GITHUB_ORG}/nephio-my-core --public --source=. --push

cd ..

#==============================================================================
# STEP 2: Register Workload Clusters (ClusterContext)
#==============================================================================

echo "Step 2: Registering Workload Clusters in Management Cluster"

kubectl config use-context ${MGMT_CONTEXT}

# Register my-ran cluster
cat <<EOF | kubectl apply -f -
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-ran
  namespace: default
spec:
  clusterName: my-ran
  siteCode: ran-site-01
  cnis:
    - macvlan
    - calico
EOF

# Register my-core cluster
cat <<EOF | kubectl apply -f -
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-core
  namespace: default
spec:
  clusterName: my-core
  siteCode: core-site-01
  cnis:
    - macvlan
    - calico
EOF

# Verify
kubectl get clustercondexts

#==============================================================================
# STEP 3: Register Repositories in Porch
#==============================================================================

echo "Step 3: Registering Repositories"

# Register blueprint repository (upstream)
cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-blueprints
  namespace: default
spec:
  description: Nephio blueprint packages (upstream)
  type: git
  content: Package
  deployment: false
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-blueprints.git
    branch: main
    directory: /
EOF

# Register my-ran deployment repository (downstream)
cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-ran
  namespace: default
spec:
  description: Deployment packages for my-ran cluster
  type: git
  content: Package
  deployment: true
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-my-ran.git
    branch: main
    directory: /
EOF

# Register my-core deployment repository (downstream)
cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-core
  namespace: default
spec:
  description: Deployment packages for my-core cluster
  type: git
  content: Package
  deployment: true
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-my-core.git
    branch: main
    directory: /
EOF

# Wait for repos to sync
echo "Waiting for repositories to sync..."
sleep 30

# Verify
kubectl get repositories

#==============================================================================
# STEP 4: Deploy PackageVariants
#==============================================================================

echo "Step 4: Deploying PackageVariants"

# Cluster Baseline PackageVariants
cat <<EOF | kubectl apply -f -
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
    data:
      cluster-name: my-ran
    repositoryRef:
      name: nephio-my-ran
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-ran
          cluster-type: workload
          workload-type: ran
          site-id: site-ran-01
          cluster-repo-url: https://github.com/${GITHUB_ORG}/nephio-my-ran.git
          cluster-repo-branch: main
          storage-class-name: local-path
---
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
    data:
      cluster-name: my-core
    repositoryRef:
      name: nephio-my-core
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-core
          cluster-type: workload
          workload-type: core
          site-id: site-core-01
          cluster-repo-url: https://github.com/${GITHUB_ORG}/nephio-my-core.git
          cluster-repo-branch: main
          storage-class-name: local-path
EOF

# Platform Addons PackageVariants
cat <<EOF | kubectl apply -f -
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
          storage-class-name: local-path
---
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
          storage-class-name: local-path
EOF

# Networking PackageVariants (Multus)
cat <<EOF | kubectl apply -f -
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
---
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

# Networking PackageVariants (Whereabouts)
cat <<EOF | kubectl apply -f -
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
---
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

# NAD Renderer PackageVariants
cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: nads-my-ran
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/network-attachment-renderer
    revision: main
  downstream:
    repo: nephio-my-ran
    package: network-attachments
  adoption: adoptExisting
  packageContext:
    data:
      cluster-name: my-ran
      target-namespace: openairinterface
    repositoryRef:
      name: nephio-my-ran
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          target-cluster: my-ran
          target-namespace: openairinterface
---
apiVersion: config.porch.kpt.dev/v1alpha2
kind: PackageVariant
metadata:
  name: nads-my-core
  namespace: default
spec:
  upstream:
    repo: nephio-blueprints
    package: networking/network-attachment-renderer
    revision: main
  downstream:
    repo: nephio-my-core
    package: network-attachments
  adoption: adoptExisting
  packageContext:
    data:
      cluster-name: my-core
      target-namespace: free5gc
    repositoryRef:
      name: nephio-my-core
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          target-cluster: my-core
          target-namespace: free5gc
EOF

# Wait for PackageVariants to be processed
echo "Waiting for PackageVariants to be processed..."
sleep 60

# Check status
kubectl get packagevariants

#==============================================================================
# STEP 5: Approve PackageRevisions
#==============================================================================

echo "Step 5: Approving PackageRevisions"

# Get all PackageRevisions and approve them
kubectl get packagerevisions -o name | grep -E "(my-ran|my-core)" | while read pr; do
  echo "Approving $pr"
  kubectl patch $pr --type=merge -p '{"spec":{"lifecycle":"Published"}}'
done

# Verify all are Published
kubectl get packagerevisions | grep -E "(my-ran|my-core)"

#==============================================================================
# STEP 6: Verify Git Commits
#==============================================================================

echo "Step 6: Verifying Git Commits"

# Pull downstream repos to see rendered packages
cd nephio-my-ran
git pull
echo "RAN repo contents:"
ls -la

cd ../nephio-my-core
git pull
echo "CORE repo contents:"
ls -la

cd ..

#==============================================================================
# STEP 7: Bootstrap ConfigSync on Workload Clusters
#==============================================================================

echo "Step 7: Bootstrapping ConfigSync (MANUAL STEP)"

echo "On my-ran cluster:"
cat <<'EOF'
# Switch to RAN cluster
kubectl config use-context my-ran

# Clone the rendered repo
git clone https://github.com/${GITHUB_ORG}/nephio-my-ran.git
cd nephio-my-ran

# Apply ConfigSync
kubectl apply -f cluster-baseline/configsync.yaml

# Wait for ConfigSync to be ready
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s

# Apply RootSync (tells ConfigSync where to pull from)
kubectl apply -f cluster-baseline/rootsync.yaml

# Verify RootSync is syncing
kubectl get rootsync -n config-management-system
EOF

echo ""
echo "On my-core cluster:"
cat <<'EOF'
# Switch to CORE cluster
kubectl config use-context my-core

# Clone the rendered repo
git clone https://github.com/${GITHUB_ORG}/nephio-my-core.git
cd nephio-my-core

# Apply ConfigSync
kubectl apply -f cluster-baseline/configsync.yaml

# Wait for ConfigSync to be ready
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s

# Apply RootSync
kubectl apply -f cluster-baseline/rootsync.yaml

# Verify RootSync is syncing
kubectl get rootsync -n config-management-system
EOF

#==============================================================================
# STEP 8: Verify Deployment
#==============================================================================

echo ""
echo "Step 8: Verification Commands"

cat <<'EOF'
# On RAN cluster:
kubectl --context=my-ran get pods -A
kubectl --context=my-ran get network-attachment-definitions -n openairinterface
kubectl --context=my-ran get storageclass
kubectl --context=my-ran top nodes

# On CORE cluster:
kubectl --context=my-core get pods -A
kubectl --context=my-core get network-attachment-definitions -n free5gc
kubectl --context=my-core get storageclass
kubectl --context=my-core top nodes
EOF

echo ""
echo "Deployment complete! Your clusters are ready for OAI RAN and Free5GC."