# Nephio Integration Deployment Guide

Complete step-by-step guide for deploying networking, baseline, and addons to your bare-metal Kubernetes clusters.

## Quick Start

```bash
# 1. Download the deployment script
wget https://raw.githubusercontent.com/YOUR-REPO/complete-nephio-deployment.sh
chmod +x complete-nephio-deployment.sh

# 2. Edit configuration at the top of the script
vim complete-nephio-deployment.sh
# OR use the separate config file:
cp deployment-config.env.example deployment-config.env
vim deployment-config.env

# 3. Run the deployment
./complete-nephio-deployment.sh
```

## Prerequisites

### Required Tools

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# git (usually pre-installed)
sudo apt-get install git  # Debian/Ubuntu
sudo yum install git       # RHEL/CentOS

# Optional: kpt (for GitOps mode)
# https://kpt.dev/installation/
```

### Cluster Requirements

Both `my-ran` and `my-core` clusters must have:
- ✅ Kubernetes 1.23+ installed
- ✅ Calico CNI running
- ✅ kubectl contexts configured
- ✅ Connectivity from your machine

### Verify Prerequisites

```bash
# Check kubectl
kubectl version --client

# Check cluster contexts
kubectl config get-contexts

# Test connectivity to RAN cluster
kubectl --context=my-ran get nodes

# Test connectivity to CORE cluster
kubectl --context=my-core get nodes

# Check Calico is running
kubectl --context=my-ran get pods -n kube-system -l k8s-app=calico-node
```

## Configuration

### Step 1: Identify Your Network Interface

On each cluster node:
```bash
# SSH to node
ip addr show

# Common interface names:
# - eth0 (traditional)
# - ens33 (VMware)
# - enp1s0 (Dell)
# - eno1 (HP)
```

Update `PHYSICAL_INTERFACE` in the script with the correct name.

### Step 2: Plan IP Addressing

The script uses two separate networks:

| Network | Purpose | Default CIDR | Interfaces |
|---------|---------|--------------|------------|
| Control Plane | Signaling, SBI | 192.168.10.0/24 | N2, N4, F1-C, E1 |
| User Plane | Data traffic | 192.168.20.0/24 | N3, N6, F1-U |

**Customize if needed:**
- Must not conflict with existing networks
- Should be on the same LAN as your nodes
- Gateway IPs should be reachable from nodes

### Step 3: Configure Cluster Contexts

```bash
# List available contexts
kubectl config get-contexts

# Rename if needed
kubectl config rename-context old-name my-ran
kubectl config rename-context old-name my-core

# Or edit the script to use your actual context names
```

### Step 4: Edit Script Configuration

Open `complete-nephio-deployment.sh` and modify the configuration section:

```bash
# Required changes:
GITHUB_ORG="your-username"           # Your GitHub username
RAN_CONTEXT="my-ran"                 # Your RAN context name
CORE_CONTEXT="my-core"               # Your CORE context name
PHYSICAL_INTERFACE="eth0"            # Your interface name

# Optional (if different from LAN):
CONTROL_PLANE_CIDR="192.168.10.0/24"
USER_PLANE_CIDR="192.168.20.0/24"
```

## Deployment Modes

### Mode 1: Manual (Recommended for Bare-Metal)

**Best for:**
- Testing and development
- Learning Nephio concepts
- Simple 2-cluster setups
- No management cluster available

**How it works:**
1. Script generates package manifests locally
2. Applies directly using `kubectl apply`
3. No git repositories needed
4. Immediate feedback

**Set in script:**
```bash
DEPLOYMENT_MODE="manual"
```

### Mode 2: GitOps (Production)

**Best for:**
- Production deployments
- Multiple clusters (3+)
- Full Nephio workflow
- Team collaboration

**Requirements:**
- Nephio management cluster running
- Git repositories (can be created automatically)
- Porch installed on management cluster

**Set in script:**
```bash
DEPLOYMENT_MODE="gitops"
MGMT_CONTEXT="nephio-mgmt"  # Your management cluster context
```

## Running the Deployment

### Dry Run (Preview)

```bash
# Edit script to enable dry run
DRY_RUN="true"

# Run to see what would be deployed
./complete-nephio-deployment.sh
```

### Full Deployment

```bash
# Run the script
./complete-nephio-deployment.sh

# The script will:
# 1. ✓ Check prerequisites
# 2. ✓ Create working directory
# 3. ✓ Generate package manifests
# 4. ✓ Label nodes
# 5. ✓ Deploy to RAN cluster
# 6. ✓ Deploy to CORE cluster
# 7. ✓ Verify deployments
# 8. ✓ Print summary
```

### Expected Output

```
╔══════════════════════════════════════════════════════════════╗
║ Running Pre-flight Checks
╚══════════════════════════════════════════════════════════════╝

[SUCCESS] kubectl found
[SUCCESS] git found
[SUCCESS] RAN cluster context found: my-ran
[SUCCESS] CORE cluster context found: my-core
[SUCCESS] Connected to RAN cluster
[SUCCESS] Connected to CORE cluster
[INFO] Auto-detected RAN node: ran-node-01
[INFO] Auto-detected CORE node: core-node-01
[SUCCESS] All pre-flight checks passed!

╔══════════════════════════════════════════════════════════════╗
║ Setting Up Workspace
╚══════════════════════════════════════════════════════════════╝
...
```

### Deployment Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Pre-flight | 30s | Check tools and connectivity |
| Package Generation | 10s | Create manifests |
| Node Labeling | 5s | Apply Nephio labels |
| Baseline Deployment | 2-3m | ConfigSync, namespaces |
| Addons Deployment | 2-3m | Storage, metrics server |
| Networking Deployment | 1-2m | Multus, Whereabouts, NADs |
| Verification | 1m | Check all components |
| **Total** | **~10m** | Complete deployment |

## What Gets Deployed

### On Both Clusters

#### 1. Cluster Baseline
```
✓ config-management-system namespace
✓ ConfigSync controller (GitOps)
✓ Namespaces (openairinterface, free5gc, etc)
✓ Pod Security Standards (baseline policy)
✓ Node labels (nephio.org/*)
```

#### 2. Platform Addons
```
✓ local-path-storage namespace
✓ Local Path Provisioner DaemonSet
✓ local-path StorageClass (default)
✓ Metrics Server Deployment
```

#### 3. Networking
```
✓ Multus CNI DaemonSet
✓ Whereabouts IPAM DaemonSet
✓ Network Attachment Definitions:
  - <cluster>-ctrl-net (control plane)
  - <cluster>-user-net (user plane)
```

### Cluster-Specific Differences

| Component | RAN Cluster | CORE Cluster |
|-----------|-------------|--------------|
| Node labels | workload-type=ran | workload-type=core |
| NAD names | my-ran-ctrl-net | my-core-ctrl-net |
| Namespaces | openairinterface | free5gc |

## Verification

### Automated Verification

The script automatically verifies:
- ✓ Namespaces created
- ✓ Storage class exists
- ✓ Multus running
- ✓ Whereabouts running
- ✓ NADs created
- ✓ Node labels applied

### Manual Verification

#### Check Overall Status
```bash
# RAN cluster
kubectl --context=my-ran get pods -A

# CORE cluster
kubectl --context=my-core get pods -A

# Should see pods in:
# - config-management-system
# - kube-system (multus, whereabouts, metrics-server)
# - local-path-storage
```

#### Check Storage
```bash
# Check storage class
kubectl --context=my-ran get storageclass

# Test PVC creation
cat <<EOF | kubectl --context=my-ran apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

# Check it's bound
kubectl --context=my-ran get pvc test-pvc

# Clean up
kubectl --context=my-ran delete pvc test-pvc
```

#### Check Metrics Server
```bash
# Check metrics server pod
kubectl --context=my-ran get pods -n kube-system -l k8s-app=metrics-server

# Test metrics
kubectl --context=my-ran top nodes
kubectl --context=my-ran top pods -n kube-system

# Should display CPU/memory usage
```

#### Check Networking
```bash
# Check Multus
kubectl --context=my-ran get daemonset -n kube-system kube-multus-ds
kubectl --context=my-ran logs -n kube-system -l name=multus --tail=20

# Check Whereabouts
kubectl --context=my-ran get daemonset -n kube-system whereabouts
kubectl --context=my-ran logs -n kube-system -l name=whereabouts --tail=20

# Check NADs
kubectl --context=my-ran get network-attachment-definitions -A

# Should show:
# openairinterface   my-ran-ctrl-net
# openairinterface   my-ran-user-net
```

#### Check Node Labels
```bash
# View all Nephio labels
kubectl --context=my-ran get nodes --show-labels | grep nephio

# Should include:
# - nephio.org/cluster-name=my-ran
# - nephio.org/workload-type=ran
# - nephio.org/site-id=site-ran-01
```

#### Test Network Attachment
```bash
# Create test pod with NAD attached
cat <<EOF | kubectl --context=my-ran apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-net-pod
  namespace: openairinterface
  annotations:
    k8s.v1.cni.cncf.io/networks: my-ran-ctrl-net
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
EOF

# Wait for pod to be running
kubectl --context=my-ran wait --for=condition=Ready pod/test-net-pod -n openairinterface

# Check interfaces (should see eth0 + net1)
kubectl --context=my-ran exec -n openairinterface test-net-pod -- ip addr

# Check IP allocation from Whereabouts
kubectl --context=my-ran exec -n openairinterface test-net-pod -- ip addr show net1
# Should have IP from 192.168.10.0/24 range

# Clean up
kubectl --context=my-ran delete pod test-net-pod -n openairinterface
```

## Troubleshooting

### Issue: Pre-flight checks fail

**Symptom:** Script exits during pre-flight checks

**Solutions:**
```bash
# If kubectl not found
sudo snap install kubectl --classic

# If cluster context not found
kubectl config get-contexts
kubectl config use-context <correct-name>

# If cannot connect to cluster
kubectl cluster-info
# Check kubeconfig: ~/.kube/config
```

### Issue: Multus pods CrashLoopBackOff

**Symptom:** 
```
kubectl get pods -n kube-system -l name=multus
NAME                   READY   STATUS             RESTARTS
kube-multus-ds-xxxxx   0/1     CrashLoopBackOff   5
```

**Solutions:**
```bash
# Check logs
kubectl logs -n kube-system -l name=multus

# Common issue: Calico config conflict
# Verify Calico is running
kubectl get pods -n kube-system -l k8s-app=calico-node

# Check CNI config directory
ls -la /etc/cni/net.d/

# If needed, manually fix Multus config
kubectl edit daemonset kube-multus-ds -n kube-system
```

### Issue: Storage PVCs stuck in Pending

**Symptom:**
```
kubectl get pvc
NAME       STATUS    VOLUME   CAPACITY
test-pvc   Pending
```

**Solutions:**
```bash
# Check provisioner logs
kubectl logs -n local-path-storage -l app=local-path-provisioner

# Common issue: Directory doesn't exist
# SSH to node and create:
sudo mkdir -p /opt/local-path-provisioner
sudo chmod 777 /opt/local-path-provisioner

# Restart provisioner
kubectl delete pod -n local-path-storage -l app=local-path-provisioner
```

### Issue: NADs not working

**Symptom:** Pods fail to attach secondary interfaces

**Solutions:**
```bash
# 1. Check NAD exists
kubectl get network-attachment-definitions -n openairinterface

# 2. Check NAD configuration
kubectl get network-attachment-definition my-ran-ctrl-net -n openairinterface -o yaml

# 3. Verify Whereabouts CRDs
kubectl get crd | grep whereabouts
kubectl get ippools -A

# 4. Check interface exists on node
# SSH to node:
ip link show eth0  # Replace with your interface

# 5. Test with debug pod (see verification section above)
```

### Issue: Metrics Server not working

**Symptom:**
```
kubectl top nodes
error: Metrics API not available
```

**Solutions:**
```bash
# Check metrics-server pod
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Common issue: Certificate verification
# Already handled in script with --kubelet-insecure-tls

# If still failing, check kubelet:
systemctl status kubelet

# Test kubelet metrics endpoint
curl -k https://localhost:10250/metrics
```

### Issue: ConfigSync not syncing (GitOps mode)

**Symptom:** Packages not appearing in cluster

**Solutions:**
```bash
# Check RootSync status
kubectl get rootsync -n config-management-system

# Check for errors
kubectl describe rootsync root-sync -n config-management-system

# Check reconciler logs
kubectl logs -n config-management-system -l app=reconciler-manager

# Common issues:
# 1. Wrong git repo URL
# 2. Authentication failure (need git-creds secret)
# 3. Invalid manifests in repo
```

## Post-Deployment

### Next Steps

1. **Deploy Network Functions**
   - Clone OAI RAN packages
   - Clone Free5GC packages
   - Modify to reference your NADs
   - Deploy to respective clusters

2. **Set Up Monitoring** (Optional)
   ```bash
   # Install Prometheus and Grafana
   # Monitor resource usage
   # Set up alerts
   ```

3. **Test End-to-End**
   - Deploy UE simulator
   - Test data plane connectivity
   - Validate 5G call flows

### Clean Up (if needed)

```bash
# Remove everything from RAN cluster
kubectl --context=my-ran delete namespace openairinterface
kubectl --context=my-ran delete namespace config-management-system
kubectl --context=my-ran delete namespace local-path-storage
kubectl --context=my-ran delete daemonset -n kube-system kube-multus-ds whereabouts

# Remove everything from CORE cluster
kubectl --context=my-core delete namespace free5gc
kubectl --context=my-core delete namespace config-management-system
kubectl --context=my-core delete namespace local-path-storage
kubectl --context=my-core delete daemonset -n kube-system kube-multus-ds whereabouts

# Remove node labels
kubectl --context=my-ran label nodes --all nephio.org/cluster-name-
kubectl --context=my-core label nodes --all nephio.org/cluster-name-
```

### Updating Configuration

To change network configuration after deployment:

```bash
# 1. Edit NADs
kubectl --context=my-ran edit network-attachment-definition my-ran-ctrl-net -n openairinterface

# 2. Update CIDR or gateway
# Modify the 'config' field

# 3. Restart Whereabouts to clear IP allocations
kubectl delete pod -n kube-system -l name=whereabouts

# 4. Redeploy workload pods to get new IPs
```

## Script Customization

### Adding Additional Namespaces

Edit the `generate_cluster_baseline()` function:

```bash
cat >> "$pkg_dir/namespaces.yaml" <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: my-custom-namespace
  labels:
    nephio.org/cluster-name: my-ran
EOF
```

### Changing Storage Path

Edit `generate_platform_addons()`:

```bash
# Change from /opt/local-path-provisioner to /data/storage
# Update the ConfigMap section
```

### Adding More NADs

Edit the `create_nads()` function to add additional networks.

## Support and Resources

- **Nephio Documentation**: https://nephio.org/docs
- **Multus CNI**: https://github.com/k8snetworkplumbingwg/multus-cni
- **Whereabouts**: https://github.com/k8snetworkplumbingwg/whereabouts
- **ConfigSync**: https://cloud.google.com/anthos-config-management/docs/config-sync-overview

## Summary

This deployment script provides a complete, automated way to integrate your bare-metal Kubernetes clusters with Nephio, deploying all necessary networking, storage, and baseline components in approximately 10 minutes.

After successful deployment, your clusters will be ready to host OAI RAN and Free5GC network functions with proper networking, storage, and GitOps capabilities.