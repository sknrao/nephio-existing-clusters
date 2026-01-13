#!/bin/bash
#==============================================================================
# Updated Nephio Deployment with Management Config Repo
# Changes from original:
# - Added nephio-management-config repo
# - Simplified CR application (kubectl apply -k)
# - Option for combined downstream repo
#==============================================================================

set -e

GITHUB_ORG="YOUR-GITHUB-ORG"  # CHANGE THIS
MGMT_CONTEXT="nephio-mgmt"
RAN_CONTEXT="my-ran"
CORE_CONTEXT="my-core"

# Choose your downstream repo strategy
DOWNSTREAM_STRATEGY="separate"  # Options: "separate" or "combined"
# separate = 4 repos total (management-config + blueprints + ran + core)
# combined = 3 repos total (management-config + blueprints + workload-clusters)

#==============================================================================
# STEP 1: Create Git Repositories
#==============================================================================

echo "Step 1: Creating Git Repositories"

# 1.1 Management Config Repo (NEW!)
mkdir -p nephio-management-config
cd nephio-management-config

# Create directory structure
mkdir -p cluster-contexts
mkdir -p repositories
mkdir -p packagevariants/{baseline,addons,networking}

# Create root kustomization
cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - cluster-contexts/
  - repositories/
  - packagevariants/baseline/
  - packagevariants/addons/
  - packagevariants/networking/
EOF

echo "# Nephio Management Cluster Configuration" > README.md
echo "This repository contains ClusterContexts, Repository CRs, and PackageVariants" >> README.md

git init
git add .
git commit -m "Initial management config structure"
gh repo create ${GITHUB_ORG}/nephio-management-config --public --source=. --push
cd ..

# 1.2 Blueprint Repo (UNCHANGED)
mkdir -p nephio-blueprints
cd nephio-blueprints
echo "# Nephio Blueprint Packages" > README.md
# TODO: Add all package files
git init
git add .
git commit -m "Initial blueprints"
gh repo create ${GITHUB_ORG}/nephio-blueprints --public --source=. --push
cd ..

# 1.3 Downstream Repos (DEPENDS ON STRATEGY)
if [ "$DOWNSTREAM_STRATEGY" == "separate" ]; then
    echo "Creating separate downstream repos..."
    
    # RAN deployment repo
    mkdir -p nephio-my-ran
    cd nephio-my-ran
    echo "# Deployment packages for my-ran cluster" > README.md
    git init
    git add README.md
    git commit -m "Initial commit"
    gh repo create ${GITHUB_ORG}/nephio-my-ran --public --source=. --push
    cd ..
    
    # CORE deployment repo
    mkdir -p nephio-my-core
    cd nephio-my-core
    echo "# Deployment packages for my-core cluster" > README.md
    git init
    git add README.md
    git commit -m "Initial commit"
    gh repo create ${GITHUB_ORG}/nephio-my-core --public --source=. --push
    cd ..
    
else
    echo "Creating combined downstream repo..."
    
    # Combined workload clusters repo
    mkdir -p nephio-workload-clusters
    cd nephio-workload-clusters
    mkdir -p ran core
    echo "# Deployment packages for workload clusters" > README.md
    echo "- ran/ contains RAN cluster packages" >> README.md
    echo "- core/ contains CORE cluster packages" >> README.md
    git init
    git add .
    git commit -m "Initial commit"
    gh repo create ${GITHUB_ORG}/nephio-workload-clusters --public --source=. --push
    cd ..
fi

#==============================================================================
# STEP 2: Populate Management Config Repo
#==============================================================================

echo "Step 2: Populating Management Config Repo"

cd nephio-management-config

# 2.1 ClusterContexts
cat > cluster-contexts/clustercontext-my-ran.yaml <<EOF
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

cat > cluster-contexts/clustercontext-my-core.yaml <<EOF
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

cat > cluster-contexts/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - clustercontext-my-ran.yaml
  - clustercontext-my-core.yaml
EOF

# 2.2 Repository CRs
cat > repositories/repository-blueprints.yaml <<EOF
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

if [ "$DOWNSTREAM_STRATEGY" == "separate" ]; then
    cat > repositories/repository-my-ran.yaml <<EOF
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

    cat > repositories/repository-my-core.yaml <<EOF
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

    cat > repositories/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - repository-blueprints.yaml
  - repository-my-ran.yaml
  - repository-my-core.yaml
EOF

else
    cat > repositories/repository-workload-clusters.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-workload-clusters
  namespace: default
spec:
  description: Deployment packages for workload clusters
  type: git
  content: Package
  deployment: true
  git:
    repo: https://github.com/${GITHUB_ORG}/nephio-workload-clusters.git
    branch: main
    directory: /
EOF

    cat > repositories/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - repository-blueprints.yaml
  - repository-workload-clusters.yaml
EOF
fi

# 2.3 PackageVariants (depends on strategy)
# Baseline PackageVariants
if [ "$DOWNSTREAM_STRATEGY" == "separate" ]; then
    DOWNSTREAM_REPO_RAN="nephio-my-ran"
    DOWNSTREAM_REPO_CORE="nephio-my-core"
    PACKAGE_PREFIX_RAN=""
    PACKAGE_PREFIX_CORE=""
else
    DOWNSTREAM_REPO_RAN="nephio-workload-clusters"
    DOWNSTREAM_REPO_CORE="nephio-workload-clusters"
    PACKAGE_PREFIX_RAN="ran/"
    PACKAGE_PREFIX_CORE="core/"
fi

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
    repo: ${DOWNSTREAM_REPO_RAN}
    package: ${PACKAGE_PREFIX_RAN}cluster-baseline
  adoption: adoptExisting
  packageContext:
    data:
      cluster-name: my-ran
    repositoryRef:
      name: ${DOWNSTREAM_REPO_RAN}
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-ran
          cluster-type: workload
          workload-type: ran
          site-id: site-ran-01
          cluster-repo-url: https://github.com/${GITHUB_ORG}/${DOWNSTREAM_REPO_RAN}.git
          cluster-repo-branch: main
          storage-class-name: local-path
EOF

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
    repo: ${DOWNSTREAM_REPO_CORE}
    package: ${PACKAGE_PREFIX_CORE}cluster-baseline
  adoption: adoptExisting
  packageContext:
    data:
      cluster-name: my-core
    repositoryRef:
      name: ${DOWNSTREAM_REPO_CORE}
  pipeline:
    mutators:
      - image: gcr.io/kpt-fn/apply-setters:v0.2
        configMap:
          cluster-name: my-core
          cluster-type: workload
          workload-type: core
          site-id: site-core-01
          cluster-repo-url: https://github.com/${GITHUB_ORG}/${DOWNSTREAM_REPO_CORE}.git
          cluster-repo-branch: main
          storage-class-name: local-path
EOF

cat > packagevariants/baseline/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - baseline-my-ran.yaml
  - baseline-my-core.yaml
EOF

# Similar structure for addons and networking packagevariants...
# (abbreviated for brevity - full files would follow same pattern)

# Commit and push
git add .
git commit -m "Add ClusterContexts, Repositories, and PackageVariants"
git push

cd ..

#==============================================================================
# STEP 3: Apply Management Configuration (SIMPLIFIED!)
#==============================================================================

echo "Step 3: Applying Management Configuration"

kubectl config use-context ${MGMT_CONTEXT}

# Clone management config repo
git clone https://github.com/${GITHUB_ORG}/nephio-management-config.git
cd nephio-management-config

# Apply everything with single command!
echo "Applying all management configuration..."
kubectl apply -k .

# OR apply in stages for better control:
# kubectl apply -k cluster-contexts/
# kubectl apply -k repositories/
# sleep 30  # Wait for repos to sync
# kubectl apply -k packagevariants/

# Verify
echo "Verifying ClusterContexts..."
kubectl get clustercontexts

echo "Verifying Repositories..."
kubectl get repositories

echo "Waiting for repositories to sync..."
sleep 30

echo "Verifying PackageVariants..."
kubectl get packagevariants

cd ..

#==============================================================================
# STEP 4: Approve PackageRevisions (UNCHANGED)
#==============================================================================

echo "Step 4: Approving PackageRevisions"

# Wait for rendering
echo "Waiting for Porch to render packages..."
sleep 60

# Get and approve all PackageRevisions
kubectl get packagerevisions -o name | grep -E "(my-ran|my-core)" | while read pr; do
    echo "Approving $pr"
    kubectl patch $pr --type=merge -p '{"spec":{"lifecycle":"Published"}}'
done

# Verify
kubectl get packagerevisions | grep -E "(my-ran|my-core)"

#==============================================================================
# STEP 5: Verify Git Commits (CHANGED based on strategy)
#==============================================================================

echo "Step 5: Verifying Git Commits"

if [ "$DOWNSTREAM_STRATEGY" == "separate" ]; then
    # Pull separate repos
    git clone https://github.com/${GITHUB_ORG}/nephio-my-ran.git
    cd nephio-my-ran
    echo "RAN repo contents:"
    ls -la
    cd ..
    
    git clone https://github.com/${GITHUB_ORG}/nephio-my-core.git
    cd nephio-my-core
    echo "CORE repo contents:"
    ls -la
    cd ..
else
    # Pull combined repo
    git clone https://github.com/${GITHUB_ORG}/nephio-workload-clusters.git
    cd nephio-workload-clusters
    echo "RAN packages in ran/:"
    ls -la ran/
    echo "CORE packages in core/:"
    ls -la core/
    cd ..
fi

#==============================================================================
# STEP 6: Bootstrap ConfigSync (MANUAL - CHANGED based on strategy)
#==============================================================================

echo "Step 6: Bootstrapping ConfigSync (MANUAL STEP)"

if [ "$DOWNSTREAM_STRATEGY" == "separate" ]; then
    cat <<'EOF'
# On my-ran cluster:
kubectl config use-context my-ran
cd nephio-my-ran
kubectl apply -f cluster-baseline/configsync.yaml
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s
kubectl apply -f cluster-baseline/rootsync.yaml

# On my-core cluster:
kubectl config use-context my-core
cd nephio-my-core
kubectl apply -f cluster-baseline/configsync.yaml
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s
kubectl apply -f cluster-baseline/rootsync.yaml
EOF
else
    cat <<'EOF'
# On my-ran cluster:
kubectl config use-context my-ran
cd nephio-workload-clusters
kubectl apply -f ran/cluster-baseline/configsync.yaml
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s
kubectl apply -f ran/cluster-baseline/rootsync.yaml
# Note: rootsync.yaml should have dir: /ran

# On my-core cluster:
kubectl config use-context my-core
cd nephio-workload-clusters
kubectl apply -f core/cluster-baseline/configsync.yaml
kubectl wait --for=condition=Ready pod -l app=reconciler-manager \
  -n config-management-system --timeout=300s
kubectl apply -f core/cluster-baseline/rootsync.yaml
# Note: rootsync.yaml should have dir: /core
EOF
fi

#==============================================================================
# STEP 7: Verify Deployment (UNCHANGED)
#==============================================================================

echo ""
echo "Step 7: Verification Commands"

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

# Check ConfigSync status:
kubectl --context=my-ran get rootsync -n config-management-system
kubectl --context=my-core get rootsync -n config-management-system
EOF

echo ""
echo "Deployment complete!"
echo ""
echo "Summary of changes from original workflow:"
echo "✓ Added nephio-management-config repository"
echo "✓ Simplified CR application (kubectl apply -k)"
echo "✓ Version control for management configuration"
if [ "$DOWNSTREAM_STRATEGY" == "combined" ]; then
    echo "✓ Using combined downstream repo with ran/ and core/ folders"
else
    echo "✓ Using separate downstream repos"
fi