#!/bin/bash

#==============================================================================
# Complete Nephio Integration Deployment Script
# Deploys networking, baseline, and addons to my-ran and my-core clusters
#==============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ $1${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#==============================================================================
# Configuration - CUSTOMIZE THESE VALUES
#==============================================================================

# GitHub Organization/Username
GITHUB_ORG="YOUR-ORG"

# Cluster contexts (as shown in 'kubectl config get-contexts')
RAN_CONTEXT="my-ran"
CORE_CONTEXT="my-core"
MGMT_CONTEXT="nephio-mgmt"  # Optional: for full Nephio GitOps

# Git repositories (will be created if they don't exist)
BLUEPRINTS_REPO="nephio-blueprints"
RAN_REPO="nephio-my-ran"
CORE_REPO="nephio-my-core"

# Cluster-specific settings
RAN_CLUSTER_NAME="my-ran"
RAN_SITE_ID="site-ran-01"
RAN_NODE_NAME=""  # Leave empty to auto-detect

CORE_CLUSTER_NAME="my-core"
CORE_SITE_ID="site-core-01"
CORE_NODE_NAME=""  # Leave empty to auto-detect

# Network configuration
CONTROL_PLANE_CIDR="192.168.10.0/24"
CONTROL_PLANE_GATEWAY="192.168.10.1"
USER_PLANE_CIDR="192.168.20.0/24"
USER_PLANE_GATEWAY="192.168.20.1"
PHYSICAL_INTERFACE="eth0"  # Your actual interface name
MTU="1500"

# Deployment mode
DEPLOYMENT_MODE="manual"  # Options: "manual" or "gitops"
# manual = kubectl apply directly
# gitops = use Nephio PackageVariants (requires management cluster)

# Git authentication (only needed for private repos in gitops mode)
GIT_USERNAME=""
GIT_TOKEN=""

#==============================================================================
# Pre-flight Checks
#==============================================================================

preflight_checks() {
    log_section "Running Pre-flight Checks"
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    log_success "kubectl found"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "git not found. Please install git."
        exit 1
    fi
    log_success "git found"
    
    # Check cluster contexts
    if ! kubectl config get-contexts "$RAN_CONTEXT" &> /dev/null; then
        log_error "RAN cluster context '$RAN_CONTEXT' not found"
        log_info "Available contexts:"
        kubectl config get-contexts -o name
        exit 1
    fi
    log_success "RAN cluster context found: $RAN_CONTEXT"
    
    if ! kubectl config get-contexts "$CORE_CONTEXT" &> /dev/null; then
        log_error "CORE cluster context '$CORE_CONTEXT' not found"
        exit 1
    fi
    log_success "CORE cluster context found: $CORE_CONTEXT"
    
    # Check cluster connectivity
    log_info "Checking RAN cluster connectivity..."
    if ! kubectl --context="$RAN_CONTEXT" get nodes &> /dev/null; then
        log_error "Cannot connect to RAN cluster"
        exit 1
    fi
    log_success "Connected to RAN cluster"
    
    log_info "Checking CORE cluster connectivity..."
    if ! kubectl --context="$CORE_CONTEXT" get nodes &> /dev/null; then
        log_error "Cannot connect to CORE cluster"
        exit 1
    fi
    log_success "Connected to CORE cluster"
    
    # Auto-detect node names if not specified
    if [ -z "$RAN_NODE_NAME" ]; then
        RAN_NODE_NAME=$(kubectl --context="$RAN_CONTEXT" get nodes -o jsonpath='{.items[0].metadata.name}')
        log_info "Auto-detected RAN node: $RAN_NODE_NAME"
    fi
    
    if [ -z "$CORE_NODE_NAME" ]; then
        CORE_NODE_NAME=$(kubectl --context="$CORE_CONTEXT" get nodes -o jsonpath='{.items[0].metadata.name}')
        log_info "Auto-detected CORE node: $CORE_NODE_NAME"
    fi
    
    # Check if kpt is installed (for gitops mode)
    if [ "$DEPLOYMENT_MODE" == "gitops" ]; then
        if ! command -v kpt &> /dev/null; then
            log_error "kpt not found. Install from: https://kpt.dev/installation/"
            exit 1
        fi
        log_success "kpt found"
        
        # Check management cluster
        if ! kubectl config get-contexts "$MGMT_CONTEXT" &> /dev/null; then
            log_error "Management cluster context '$MGMT_CONTEXT' not found"
            exit 1
        fi
        log_success "Management cluster context found: $MGMT_CONTEXT"
    fi
    
    log_success "All pre-flight checks passed!"
}

#==============================================================================
# Setup Working Directory
#==============================================================================

setup_workspace() {
    log_section "Setting Up Workspace"
    
    WORK_DIR="$(pwd)/nephio-deployment"
    
    if [ -d "$WORK_DIR" ]; then
        log_warn "Work directory exists: $WORK_DIR"
        read -p "Remove and recreate? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$WORK_DIR"
            log_info "Removed existing directory"
        fi
    fi
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    log_info "Working directory: $WORK_DIR"
    
    # Create directory structure
    mkdir -p packages/{cluster-baseline,platform-addons,networking}
    mkdir -p packages/networking/{multus-cni,whereabouts-ipam,network-intents,network-attachment-renderer}
    
    log_success "Workspace created"
}

#==============================================================================
# Generate Package Files
#==============================================================================

generate_cluster_baseline() {
    log_section "Generating Cluster Baseline Package"
    
    local pkg_dir="packages/cluster-baseline"
    
    # Create Kptfile
    cat > "$pkg_dir/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: cluster-baseline
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Complete baseline configuration for Nephio workload clusters
  keywords:
    - nephio
    - baseline
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        cluster-name: my-cluster
        cluster-type: workload
        workload-type: ran
        site-id: site-01
        cluster-repo-url: https://github.com/CHANGE-ME/repo.git
        cluster-repo-branch: main
        storage-class-name: local-path
EOF

    # Create ConfigSync
    cat > "$pkg_dir/configsync.yaml" <<'EOF'
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

    # Create namespaces with pod security
    cat > "$pkg_dir/namespaces.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: openairinterface
  labels:
    nephio.org/cluster-name: my-ran # kpt-set: ${cluster-name}
    nephio.org/workload-type: ran
    pod-security.kubernetes.io/enforce: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: free5gc
  labels:
    nephio.org/cluster-name: my-core # kpt-set: ${cluster-name}
    nephio.org/workload-type: core
    pod-security.kubernetes.io/enforce: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: local-path-storage
  labels:
    pod-security.kubernetes.io/enforce: privileged
EOF

    log_success "Cluster baseline package generated"
}

generate_platform_addons() {
    log_section "Generating Platform Addons Package"
    
    local pkg_dir="packages/platform-addons"
    
    # Create storage provisioner
    cat > "$pkg_dir/local-path-provisioner.yaml" <<'EOF'
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
        - --debug
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

    # Create metrics server
    cat > "$pkg_dir/metrics-server.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-server
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      containers:
      - name: metrics-server
        image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
        args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
        ports:
        - containerPort: 4443
          name: https
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
EOF

    log_success "Platform addons package generated"
}

generate_networking_packages() {
    log_section "Generating Networking Packages"
    
    # Generate simplified versions inline
    # In production, these would be full packages from the artifacts I created earlier
    
    log_info "Creating Multus package..."
    cat > "packages/networking/multus-cni/multus.yaml" <<'EOF'
# Simplified Multus - use full version from artifacts for production
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-multus-ds
  namespace: kube-system
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
EOF

    log_info "Creating Whereabouts package..."
    cat > "packages/networking/whereabouts-ipam/whereabouts.yaml" <<'EOF'
# Simplified Whereabouts - use full version from artifacts for production
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
EOF

    log_success "Networking packages generated"
}

#==============================================================================
# Label Nodes
#==============================================================================

label_nodes() {
    local context=$1
    local cluster_name=$2
    local workload_type=$3
    local site_id=$4
    local node_name=$5
    
    log_info "Labeling node $node_name on cluster $cluster_name..."
    
    kubectl --context="$context" label node "$node_name" \
        nephio.org/cluster-name="$cluster_name" \
        nephio.org/cluster-type=workload \
        nephio.org/workload-type="$workload_type" \
        nephio.org/site-id="$site_id" \
        topology.kubernetes.io/zone=zone-a \
        --overwrite
    
    log_success "Node labeled successfully"
}

#==============================================================================
# Deploy to Single Cluster
#==============================================================================

deploy_to_cluster() {
    local context=$1
    local cluster_name=$2
    local workload_type=$3
    
    log_section "Deploying to $cluster_name ($context)"
    
    # 1. Deploy Cluster Baseline
    log_info "Deploying cluster baseline..."
    kubectl --context="$context" apply -f packages/cluster-baseline/namespaces.yaml
    kubectl --context="$context" apply -f packages/cluster-baseline/configsync.yaml
    
    # Wait for ConfigSync to be ready
    log_info "Waiting for ConfigSync pods..."
    kubectl --context="$context" wait --for=condition=Ready \
        pod -l app=reconciler-manager \
        -n config-management-system \
        --timeout=300s 2>/dev/null || log_warn "ConfigSync might not be ready yet"
    
    # 2. Deploy Platform Addons
    log_info "Deploying platform addons..."
    kubectl --context="$context" apply -f packages/platform-addons/local-path-provisioner.yaml
    kubectl --context="$context" apply -f packages/platform-addons/metrics-server.yaml
    
    # Wait for storage
    log_info "Waiting for local-path-provisioner..."
    kubectl --context="$context" wait --for=condition=Ready \
        pod -l app=local-path-provisioner \
        -n local-path-storage \
        --timeout=120s 2>/dev/null || log_warn "Storage provisioner might not be ready"
    
    # 3. Deploy Networking
    log_info "Deploying networking components..."
    kubectl --context="$context" apply -f packages/networking/multus-cni/multus.yaml
    kubectl --context="$context" apply -f packages/networking/whereabouts-ipam/whereabouts.yaml
    
    # Wait for networking
    log_info "Waiting for Multus and Whereabouts..."
    sleep 10  # Give DaemonSets time to start
    
    # 4. Create NADs
    log_info "Creating Network Attachment Definitions..."
    create_nads "$context" "$cluster_name" "$workload_type"
    
    log_success "Deployment to $cluster_name complete!"
}

#==============================================================================
# Create Network Attachment Definitions
#==============================================================================

create_nads() {
    local context=$1
    local cluster_name=$2
    local workload_type=$3
    
    local namespace
    if [ "$workload_type" == "ran" ]; then
        namespace="openairinterface"
    else
        namespace="free5gc"
    fi
    
    # Control plane NAD
    cat <<EOF | kubectl --context="$context" apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ${cluster_name}-ctrl-net
  namespace: ${namespace}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "${PHYSICAL_INTERFACE}",
      "mode": "bridge",
      "mtu": ${MTU},
      "ipam": {
        "type": "whereabouts",
        "range": "${CONTROL_PLANE_CIDR}",
        "gateway": "${CONTROL_PLANE_GATEWAY}",
        "exclude": [
          "${CONTROL_PLANE_GATEWAY}/32"
        ]
      }
    }
EOF

    # User plane NAD
    cat <<EOF | kubectl --context="$context" apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ${cluster_name}-user-net
  namespace: ${namespace}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "${PHYSICAL_INTERFACE}",
      "mode": "bridge",
      "mtu": ${MTU},
      "ipam": {
        "type": "whereabouts",
        "range": "${USER_PLANE_CIDR}",
        "gateway": "${USER_PLANE_GATEWAY}",
        "exclude": [
          "${USER_PLANE_GATEWAY}/32"
        ]
      }
    }
EOF

    log_success "NADs created in namespace: $namespace"
}

#==============================================================================
# Verification
#==============================================================================

verify_cluster() {
    local context=$1
    local cluster_name=$2
    
    log_section "Verifying $cluster_name Deployment"
    
    local failed=0
    
    # Check namespaces
    log_info "Checking namespaces..."
    if kubectl --context="$context" get ns config-management-system local-path-storage &>/dev/null; then
        log_success "System namespaces exist"
    else
        log_error "System namespaces missing"
        ((failed++))
    fi
    
    # Check storage
    log_info "Checking storage..."
    if kubectl --context="$context" get storageclass local-path &>/dev/null; then
        log_success "Storage class exists"
    else
        log_error "Storage class missing"
        ((failed++))
    fi
    
    # Check networking
    log_info "Checking networking..."
    if kubectl --context="$context" get daemonset -n kube-system kube-multus-ds &>/dev/null; then
        log_success "Multus deployed"
    else
        log_error "Multus missing"
        ((failed++))
    fi
    
    if kubectl --context="$context" get daemonset -n kube-system whereabouts &>/dev/null; then
        log_success "Whereabouts deployed"
    else
        log_error "Whereabouts missing"
        ((failed++))
    fi
    
    # Check NADs
    log_info "Checking Network Attachment Definitions..."
    local nad_count=$(kubectl --context="$context" get network-attachment-definitions -A --no-headers 2>/dev/null | wc -l)
    if [ "$nad_count" -ge 2 ]; then
        log_success "NADs created ($nad_count found)"
    else
        log_warn "Expected 2+ NADs, found $nad_count"
    fi
    
    # Check node labels
    log_info "Checking node labels..."
    if kubectl --context="$context" get nodes -l nephio.org/cluster-name="$cluster_name" --no-headers | grep -q "$cluster_name"; then
        log_success "Node labels applied"
    else
        log_warn "Node labels might not be applied"
    fi
    
    if [ $failed -eq 0 ]; then
        log_success "All verification checks passed for $cluster_name!"
        return 0
    else
        log_error "$failed verification checks failed for $cluster_name"
        return 1
    fi
}

#==============================================================================
# Post-Deployment Summary
#==============================================================================

print_summary() {
    log_section "Deployment Summary"
    
    echo ""
    echo "📦 Packages Deployed:"
    echo "  ✓ Cluster Baseline (ConfigSync, Namespaces)"
    echo "  ✓ Platform Addons (Storage, Metrics)"
    echo "  ✓ Networking (Multus, Whereabouts, NADs)"
    echo ""
    echo "🎯 Next Steps:"
    echo ""
    echo "1. Verify deployments:"
    echo "   kubectl --context=$RAN_CONTEXT get pods -A"
    echo "   kubectl --context=$CORE_CONTEXT get pods -A"
    echo ""
    echo "2. Test storage:"
    echo "   kubectl --context=$RAN_CONTEXT get storageclass"
    echo "   kubectl top nodes --context=$RAN_CONTEXT"
    echo ""
    echo "3. Check NADs:"
    echo "   kubectl --context=$RAN_CONTEXT get network-attachment-definitions -n openairinterface"
    echo "   kubectl --context=$CORE_CONTEXT get network-attachment-definitions -n free5gc"
    echo ""
    echo "4. Deploy workloads:"
    echo "   - OAI RAN packages to $RAN_CONTEXT"
    echo "   - Free5GC packages to $CORE_CONTEXT"
    echo ""
    echo "📝 Configuration Files:"
    echo "   Located in: $WORK_DIR/packages/"
    echo ""
    echo "🔍 Logs and troubleshooting:"
    echo "   ConfigSync: kubectl --context=$RAN_CONTEXT logs -n config-management-system -l app=reconciler-manager"
    echo "   Multus: kubectl --context=$RAN_CONTEXT logs -n kube-system -l name=multus"
    echo "   Storage: kubectl --context=$RAN_CONTEXT logs -n local-path-storage -l app=local-path-provisioner"
    echo ""
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    log_section "Nephio Integration Deployment Script"
    
    echo "Configuration:"
    echo "  RAN Cluster: $RAN_CONTEXT ($RAN_CLUSTER_NAME)"
    echo "  CORE Cluster: $CORE_CONTEXT ($CORE_CLUSTER_NAME)"
    echo "  Deployment Mode: $DEPLOYMENT_MODE"
    echo "  Network Interface: $PHYSICAL_INTERFACE"
    echo "  Control Plane: $CONTROL_PLANE_CIDR"
    echo "  User Plane: $USER_PLANE_CIDR"
    echo ""
    
    read -p "Continue with deployment? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    # Execute deployment steps
    preflight_checks
    setup_workspace
    generate_cluster_baseline
    generate_platform_addons
    generate_networking_packages
    
    # Label nodes
    label_nodes "$RAN_CONTEXT" "$RAN_CLUSTER_NAME" "ran" "$RAN_SITE_ID" "$RAN_NODE_NAME"
    label_nodes "$CORE_CONTEXT" "$CORE_CLUSTER_NAME" "core" "$CORE_SITE_ID" "$CORE_NODE_NAME"
    
    # Deploy to clusters
    deploy_to_cluster "$RAN_CONTEXT" "$RAN_CLUSTER_NAME" "ran"
    deploy_to_cluster "$CORE_CONTEXT" "$CORE_CLUSTER_NAME" "core"
    
    # Verify deployments
    verify_cluster "$RAN_CONTEXT" "$RAN_CLUSTER_NAME"
    verify_cluster "$CORE_CONTEXT" "$CORE_CLUSTER_NAME"
    
    # Print summary
    print_summary
    
    log_success "Deployment Complete! 🎉"
}

# Run main function
main "$@"