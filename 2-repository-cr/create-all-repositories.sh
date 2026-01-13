#!/bin/bash
#==============================================================================
# Create All 4 Git Repositories for Nephio Setup
# CORRECTED: nephio-management-config is separate from Porch repos
#==============================================================================

set -e

GITHUB_ORG="YOUR-ORG"  # CHANGE THIS

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Creating 4 Git Repositories for Nephio${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$GITHUB_ORG" == "YOUR-ORG" ]; then
    echo -e "${YELLOW}Please edit this script and set GITHUB_ORG${NC}"
    exit 1
fi

#==============================================================================
# Repository 1: nephio-management-config (NOT a Porch repo)
#==============================================================================

echo -e "${BLUE}Creating nephio-management-config repository...${NC}"

mkdir -p nephio-management-config
cd nephio-management-config

# Create directory structure
mkdir -p cluster-contexts
mkdir -p repositories
mkdir -p packagevariants/{baseline,addons,networking}

# Root kustomization
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

# README
cat > README.md <<'EOF'
# Nephio Management Configuration

This repository contains all Custom Resources for managing the Nephio deployment:

## Structure

- `cluster-contexts/` - ClusterContext CRs for registering workload clusters
- `repositories/` - Repository CRs for registering git repos with Porch
- `packagevariants/` - PackageVariant CRs for deploying packages to clusters

## Usage

```bash
# Apply all configuration to management cluster
kubectl config use-context nephio-mgmt
kubectl apply -k .

# Or apply selectively
kubectl apply -k cluster-contexts/
kubectl apply -k repositories/
kubectl apply -k packagevariants/
```

## Repositories

This creates:
- **ClusterContexts**: Registers my-ran and my-core clusters
- **Repository CRs**: Points Porch to blueprint and deployment repos
- **PackageVariants**: Instructions for deploying packages

## Notes

- This is NOT a Porch Repository (deployment: false)
- Contents are applied directly with kubectl
- Changes require manual kubectl apply (no auto-sync)
EOF

# Cluster contexts kustomization
cat > cluster-contexts/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - clustercontext-my-ran.yaml
  - clustercontext-my-core.yaml
EOF

# ClusterContext files
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

# Repositories kustomization
cat > repositories/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - repository-blueprints.yaml
  - repository-my-ran.yaml
  - repository-my-core.yaml
EOF

# Repository CRs
cat > repositories/repository-blueprints.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-blueprints
  namespace: default
  labels:
    nephio.org/repository-type: upstream
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

cat > repositories/repository-my-ran.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-ran
  namespace: default
  labels:
    nephio.org/repository-type: downstream
    nephio.org/cluster: my-ran
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

cat > repositories/repository-my-core.yaml <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-my-core
  namespace: default
  labels:
    nephio.org/repository-type: downstream
    nephio.org/cluster: my-core
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

# PackageVariants kustomizations (placeholders)
cat > packagevariants/baseline/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Add PackageVariant files here
  # - baseline-my-ran.yaml
  # - baseline-my-core.yaml
EOF

cat > packagevariants/addons/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Add PackageVariant files here
EOF

cat > packagevariants/networking/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Add PackageVariant files here
EOF

# Initialize git
git init
git add .
git commit -m "Initial management configuration"

# Create on GitHub
gh repo create ${GITHUB_ORG}/nephio-management-config --public --source=. --push || {
    echo -e "${YELLOW}Manual push required${NC}"
    echo "Run: git remote add origin https://github.com/${GITHUB_ORG}/nephio-management-config.git"
    echo "     git push -u origin main"
}

echo -e "${GREEN}✓ nephio-management-config created${NC}"
cd ..

#==============================================================================
# Repository 2: nephio-blueprints (IS a Porch repo)
#==============================================================================

echo -e "${BLUE}Creating nephio-blueprints repository...${NC}"

mkdir -p nephio-blueprints
cd nephio-blueprints

cat > README.md <<'EOF'
# Nephio Blueprint Packages

This repository contains blueprint/template packages for Nephio infrastructure.

## Packages

- `cluster-baseline/` - ConfigSync, namespaces, security policies
- `platform-addons/` - Storage, monitoring, resource management
- `networking/` - Multus, Whereabouts, NADs

## Usage

This is an upstream/blueprint repository registered with Porch.
PackageVariants reference packages from this repo to create cluster-specific deployments.

## Structure

Each directory with a `Kptfile` is a KPT package that Porch can discover.
EOF

git init
git add .
git commit -m "Initial blueprint repo"

gh repo create ${GITHUB_ORG}/nephio-blueprints --public --source=. --push || {
    echo -e "${YELLOW}Manual push required${NC}"
}

echo -e "${GREEN}✓ nephio-blueprints created${NC}"
echo -e "${YELLOW}  ⚠ Remember to add package files to this repo${NC}"
cd ..

#==============================================================================
# Repository 3: nephio-my-ran (IS a Porch repo)
#==============================================================================

echo -e "${BLUE}Creating nephio-my-ran repository...${NC}"

mkdir -p nephio-my-ran
cd nephio-my-ran

cat > README.md <<'EOF'
# Nephio my-ran Deployment Repository

This repository contains rendered packages for the my-ran workload cluster.

## Important

- This is a downstream/deployment repository
- Porch automatically writes rendered packages here
- ConfigSync on my-ran cluster watches this repo
- **Do not manually edit files** - Porch manages this repo

## Contents

After PackageVariants are processed, this repo will contain:
- cluster-baseline/
- platform-addons/
- multus-cni/
- whereabouts-ipam/
- network-attachments/
EOF

git init
git add .
git commit -m "Initial deployment repo"

gh repo create ${GITHUB_ORG}/nephio-my-ran --public --source=. --push || {
    echo -e "${YELLOW}Manual push required${NC}"
}

echo -e "${GREEN}✓ nephio-my-ran created${NC}"
cd ..

#==============================================================================
# Repository 4: nephio-my-core (IS a Porch repo)
#==============================================================================

echo -e "${BLUE}Creating nephio-my-core repository...${NC}"

mkdir -p nephio-my-core
cd nephio-my-core

cat > README.md <<'EOF'
# Nephio my-core Deployment Repository

This repository contains rendered packages for the my-core workload cluster.

## Important

- This is a downstream/deployment repository
- Porch automatically writes rendered packages here
- ConfigSync on my-core cluster watches this repo
- **Do not manually edit files** - Porch manages this repo

## Contents

After PackageVariants are processed, this repo will contain:
- cluster-baseline/
- platform-addons/
- multus-cni/
- whereabouts-ipam/
- network-attachments/
EOF

git init
git add .
git commit -m "Initial deployment repo"

gh repo create ${GITHUB_ORG}/nephio-my-core --public --source=. --push || {
    echo -e "${YELLOW}Manual push required${NC}"
}

echo -e "${GREEN}✓ nephio-my-core created${NC}"
cd ..

#==============================================================================
# Summary
#==============================================================================

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}All 4 repositories created successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

echo "Created repositories:"
echo "1. ${GITHUB_ORG}/nephio-management-config (Management config)"
echo "2. ${GITHUB_ORG}/nephio-blueprints (Blueprint packages)"
echo "3. ${GITHUB_ORG}/nephio-my-ran (RAN deployment)"
echo "4. ${GITHUB_ORG}/nephio-my-core (CORE deployment)"
echo ""

echo "Next steps:"
echo ""
echo "1. Populate nephio-blueprints with package files:"
echo "   cd nephio-blueprints"
echo "   # Add cluster-baseline/, platform-addons/, networking/ directories"
echo "   git add . && git commit -m 'Add packages' && git push"
echo ""
echo "2. Apply management configuration to Nephio management cluster:"
echo "   cd nephio-management-config"
echo "   kubectl config use-context nephio-mgmt"
echo "   kubectl apply -k ."
echo ""
echo "3. Verify ClusterContexts and Repositories registered:"
echo "   kubectl get clustercontexts"
echo "   kubectl get repositories"
echo ""
echo "4. Add PackageVariants to nephio-management-config/packagevariants/"
echo "   Then: kubectl apply -k nephio-management-config/packagevariants/"
echo ""
echo "Repository roles:"
echo "  • management-config: kubectl apply (NOT Porch)"
echo "  • blueprints: Porch reads"
echo "  • my-ran: Porch writes, ConfigSync reads"
echo "  • my-core: Porch writes, ConfigSync reads"