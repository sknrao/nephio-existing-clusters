# Repository Registration Guide

## What are Repository CRs?

Repository CRs tell Nephio's Porch (Package Orchestration) system about your Git repositories:
- **Upstream/Blueprint repos**: Where package templates live
- **Downstream/Deployment repos**: Where Porch writes rendered packages for specific clusters

## Prerequisites

Before registering repositories:

1. ✅ ClusterContexts created and applied
2. ✅ Git repositories created on GitHub/GitLab
3. ✅ Repositories initialized (at minimum, have a README.md)
4. ✅ You have access credentials if repos are private

## Repository Types

### Upstream Repository (nephio-blueprints)
```yaml
deployment: false    # Porch READS from here
content: Package     # Contains KPT packages
type: git
```

**Purpose:** Store blueprint/template packages
**Who writes:** You (package developers)
**Who reads:** Porch (to render packages)

### Downstream Repositories (nephio-my-ran, nephio-my-core)
```yaml
deployment: true     # Porch WRITES here
content: Package     # Contains rendered packages
type: git
```

**Purpose:** Store rendered packages for specific clusters
**Who writes:** Porch (automatic)
**Who reads:** ConfigSync (on workload clusters)

## Quick Start

### Step 1: Create Git Repositories

You need to create these repositories on GitHub/GitLab **before** applying Repository CRs:

```bash
# Option A: Using GitHub CLI (gh)
gh repo create YOUR-ORG/nephio-blueprints --public
gh repo create YOUR-ORG/nephio-my-ran --public
gh repo create YOUR-ORG/nephio-my-core --public

# Option B: Using git commands
mkdir nephio-blueprints && cd nephio-blueprints
git init
echo "# Nephio Blueprint Packages" > README.md
git add . && git commit -m "Initial commit"
git remote add origin https://github.com/YOUR-ORG/nephio-blueprints.git
git push -u origin main

# Repeat for nephio-my-ran and nephio-my-core
```

**IMPORTANT:** Downstream repos (my-ran, my-core) should be **empty** except for README.md. Porch will populate them.

### Step 2: Apply Repository CRs

#### Option A: Using the Script (Easiest)

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR-REPO/apply-repositories.sh
chmod +x apply-repositories.sh

# Edit configuration
vim apply-repositories.sh
# Set: GITHUB_ORG="your-github-username"
# Set: MGMT_CONTEXT="your-mgmt-context"
# If private repos, set: USE_PRIVATE_REPOS="true"

# Run
./apply-repositories.sh
```

#### Option B: Manual Apply

```bash
# Switch to management cluster
kubectl config use-context nephio-mgmt

# Apply all Repository CRs
kubectl apply -f repositories.yaml

# Verify
kubectl get repositories
```

#### Option C: Direct Apply

```bash
kubectl config use-context nephio-mgmt

# Apply blueprints repo
kubectl apply -f - <<EOF
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
    repo: https://github.com/YOUR-ORG/nephio-blueprints.git
    branch: main
    directory: /
EOF

# Apply my-ran repo
kubectl apply -f - <<EOF
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
    repo: https://github.com/YOUR-ORG/nephio-my-ran.git
    branch: main
    directory: /
EOF

# Apply my-core repo
kubectl apply -f - <<EOF
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
    repo: https://github.com/YOUR-ORG/nephio-my-core.git
    branch: main
    directory: /
EOF
```

## For Private Repositories

If your repos are private, you need to provide authentication.

### Step 1: Create GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` scope (full control of private repositories)
3. Save the token securely

### Step 2: Create Kubernetes Secret

```bash
kubectl create secret generic git-credentials \
  --namespace=default \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=YOUR_GITHUB_USERNAME \
  --from-literal=password=YOUR_GITHUB_TOKEN
```

### Step 3: Reference Secret in Repository CRs

Add `secretRef` to the git section:

```yaml
spec:
  git:
    repo: https://github.com/YOUR-ORG/nephio-blueprints.git
    branch: main
    directory: /
    secretRef:
      name: git-credentials  # Reference to the secret
```

## Understanding Repository Spec Fields

### Required Fields

```yaml
spec:
  type: git              # Only "git" is supported currently
  content: Package       # Must be "Package" for KPT packages
  deployment: false      # false=upstream, true=downstream
  git:
    repo: <git-url>      # HTTPS URL to repository
    branch: main         # Branch to watch
    directory: /         # Directory within repo (/ = root)
```

### Optional Fields

```yaml
spec:
  description: "Human-readable description"
  git:
    secretRef:           # Only if repo is private
      name: git-credentials
```

### Common Configurations

**Public Repository:**
```yaml
spec:
  git:
    repo: https://github.com/YOUR-ORG/nephio-blueprints.git
    branch: main
    directory: /
    # No secretRef needed
```

**Private Repository:**
```yaml
spec:
  git:
    repo: https://github.com/YOUR-ORG/nephio-blueprints.git
    branch: main
    directory: /
    secretRef:
      name: git-credentials
```

**Repository with Subdirectory:**
```yaml
spec:
  git:
    repo: https://github.com/YOUR-ORG/monorepo.git
    branch: main
    directory: /nephio-packages  # Only watch this subdirectory
```

**Repository with Different Branch:**
```yaml
spec:
  git:
    repo: https://github.com/YOUR-ORG/nephio-blueprints.git
    branch: development  # Watch 'development' branch
    directory: /
```

## Verification

### Check Repository Registration

```bash
# List all repositories
kubectl get repositories

# Expected output:
# NAME                 TYPE   CONTENT   DEPLOYMENT   READY
# nephio-blueprints    git    Package   false        True
# nephio-my-ran        git    Package   true         True
# nephio-my-core       git    Package   true         True
```

### Check Repository Status

```bash
# Get detailed status
kubectl get repositories -o wide

# Check specific repository
kubectl describe repository nephio-blueprints

# Check Ready condition
kubectl get repository nephio-blueprints -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

### Monitor Repository Sync

```bash
# Watch repositories until Ready
kubectl get repositories -w

# Should see status change to Ready within 1-2 minutes
```

### Check for Packages

After repositories sync, check if Porch can see packages:

```bash
# List all package revisions
kubectl get packagerevisions

# List packages from blueprints repo
kubectl get packagerevisions | grep nephio-blueprints

# If blueprints repo has packages, you'll see them listed
```

## Troubleshooting

### Issue: Repository Not Syncing

**Symptoms:**
```bash
kubectl get repositories
# Shows: READY = False or Unknown
```

**Check details:**
```bash
kubectl describe repository nephio-blueprints

# Look for error messages in Status.Conditions
```

**Common causes:**
1. Repository doesn't exist or URL is wrong
2. Branch doesn't exist
3. Authentication failure (for private repos)
4. Network connectivity issues

**Solutions:**
```bash
# Verify repo exists
git ls-remote https://github.com/YOUR-ORG/nephio-blueprints.git

# Check secret exists (for private repos)
kubectl get secret git-credentials -n default

# Delete and recreate repository CR
kubectl delete repository nephio-blueprints
kubectl apply -f repository-blueprints.yaml
```

### Issue: Authentication Failed

**Error in describe:**
```
authentication required
```

**Solutions:**
```bash
# Verify secret exists
kubectl get secret git-credentials -n default

# Check secret contents
kubectl get secret git-credentials -n default -o yaml

# Recreate secret with correct credentials
kubectl delete secret git-credentials -n default
kubectl create secret generic git-credentials \
  --namespace=default \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_TOKEN

# Update Repository CR to reference secret
kubectl edit repository nephio-blueprints
```

### Issue: Wrong Branch or Directory

**Error:**
```
reference not found
```

**Solutions:**
```bash
# Check which branches exist
git ls-remote --heads https://github.com/YOUR-ORG/nephio-blueprints.git

# Update Repository CR
kubectl edit repository nephio-blueprints
# Change spec.git.branch to correct branch

# For directory issues, check if directory exists
git clone <repo-url>
cd <repo-name>
ls -la <directory-path>
```

### Issue: Porch Not Seeing Packages

**Symptoms:**
```bash
kubectl get packagerevisions
# Returns empty or doesn't show expected packages
```

**Check:**
```bash
# 1. Verify repository is Ready
kubectl get repositories

# 2. Check if packages exist in git repo
git clone <blueprints-repo-url>
cd nephio-blueprints
ls -la
# Should see directories with Kptfile

# 3. Check Porch logs
kubectl logs -n porch-system deployment/porch-server

# 4. Trigger resync (delete and recreate Repository CR)
kubectl delete repository nephio-blueprints
kubectl apply -f repository-blueprints.yaml
```

### Issue: Downstream Repo Not Empty

**Problem:** nephio-my-ran or nephio-my-core already has content

**Impact:** May cause conflicts when Porch tries to write

**Solution:**
```bash
# Option A: Clean the repo (destructive)
cd nephio-my-ran
git checkout main
git rm -r .
echo "# Deployment repo" > README.md
git add README.md
git commit -m "Clean for Porch"
git push --force

# Option B: Use different branch
kubectl edit repository nephio-my-ran
# Change spec.git.branch to "porch-managed"
```

## What Happens After Registration?

After registering repositories, Porch:

1. ✅ **Clones repositories** to internal storage
2. ✅ **Scans for packages** in upstream repo
3. ✅ **Creates PackageRevision CRs** for each package found
4. ✅ **Watches for changes** (polls every ~1 minute)
5. ✅ **Ready for PackageVariants** to reference these repos

**However, registration does NOT:**
- ❌ Automatically create packages
- ❌ Deploy anything to clusters
- ❌ Render packages (PackageVariants do this)

## Repository Workflow

```
┌─────────────────────────────────────────┐
│ 1. You create git repos on GitHub      │
│    - nephio-blueprints (with packages)  │
│    - nephio-my-ran (empty)              │
│    - nephio-my-core (empty)             │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 2. You apply Repository CRs             │
│    kubectl apply -f repositories.yaml   │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 3. Porch registers and syncs repos     │
│    - Clones repos                       │
│    - Discovers packages                 │
│    - Creates PackageRevisions           │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 4. Ready for PackageVariants            │
│    - Can reference repos by name        │
│    - Can deploy packages to clusters    │
└─────────────────────────────────────────┘
```

## Best Practices

### 1. Use Descriptive Names
```yaml
metadata:
  name: nephio-blueprints  # Clear, consistent naming
  labels:
    nephio.org/repository-type: upstream
```

### 2. Add Labels for Organization
```yaml
metadata:
  labels:
    nephio.org/repository-type: downstream
    nephio.org/cluster: my-ran
    nephio.org/workload-type: ran
    nephio.org/owner: platform-team
```

### 3. Use Separate Repos for Separation
```
✓ GOOD: nephio-my-ran, nephio-my-core (separate)
✗ AVOID: nephio-workloads (single repo for everything)

Reason: Better isolation, independent versioning
```

### 4. Keep Downstream Repos Empty Initially
```
nephio-my-ran/
└── README.md  # Only this file

Let Porch populate the rest
```

### 5. Use Consistent Branch Names
```yaml
# All repos use 'main' branch
spec:
  git:
    branch: main

# Easier to manage than mixed main/master/develop
```

### 6. Protect Downstream Repo Branches
```
On GitHub:
Settings → Branches → Branch protection rules
- Require pull request reviews: NO
- Allow force pushes: YES (Porch needs this)
- Restrict who can push: Nephio service account only
```

## Next Steps

After repositories are registered and Ready:

### Step 1: Verify Registration
```bash
kubectl get repositories
# All should show READY = True
```

### Step 2: Check Discovered Packages
```bash
kubectl get packagerevisions | grep nephio-blueprints
```

### Step 3: Create PackageVariants
```bash
# Tell Nephio which packages to deploy where
kubectl apply -f packagevariants.yaml
```

### Step 4: Monitor Rendering
```bash
# Watch Porch render packages
kubectl get packagerevisions -w
```

### Step 5: Approve and Deploy
```bash
# Approve rendered packages
kubectl patch packagerevision <n> --type=merge \
  -p '{"spec":{"lifecycle":"Published"}}'
```

## Using with Management Config Repo

If following the management-config repo pattern:

```
nephio-management-config/
├── cluster-contexts/
│   └── ...
├── repositories/
│   ├── kustomization.yaml
│   ├── repository-blueprints.yaml      ← Place here
│   ├── repository-my-ran.yaml          ← Place here
│   ├── repository-my-core.yaml         ← Place here
│   └── git-credentials-secret.yaml     ← If needed
└── packagevariants/
    └── ...
```

Apply with:
```bash
kubectl apply -k nephio-management-config/repositories/
```

## Summary

Repository registration is **Step 2** after ClusterContext registration. It:

1. Takes 5 minutes to set up
2. Connects Nephio to your git repositories
3. Enables package discovery and orchestration
4. Is required before creating PackageVariants

After registration, you're ready to deploy packages to your clusters!