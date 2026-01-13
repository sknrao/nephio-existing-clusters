Now let me create a companion configuration file and usage guide:Perfect! I've created a complete deployment automation package for you. Here's what you now have:

## 📦 Complete Package

### 1. **complete-nephio-deployment.sh** (Main Script)
A fully automated bash script that:
- ✅ Checks prerequisites (kubectl, git, cluster connectivity)
- ✅ Auto-detects node names and configurations
- ✅ Generates all package manifests on-the-fly
- ✅ Labels nodes with Nephio discovery labels
- ✅ Deploys to both clusters in correct order
- ✅ Verifies all deployments
- ✅ Provides colored, easy-to-read output
- ✅ Includes error handling and rollback capability

### 2. **deployment-config.env** (Configuration File)
Separate configuration file where you can customize:
- Cluster contexts
- Network settings (IPs, interface names)
- Git repository names
- Deployment mode (manual vs GitOps)

### 3. **DEPLOYMENT-GUIDE.md** (Documentation)
Complete guide covering:
- Prerequisites and setup
- Configuration options
- Deployment modes
- Verification steps
- Troubleshooting for common issues
- Post-deployment next steps

## 🚀 Quick Start

```bash
# 1. Download the script
wget [script-url]/complete-nephio-deployment.sh
chmod +x complete-nephio-deployment.sh

# 2. Edit configuration (top of script)
vim complete-nephio-deployment.sh
# Change: GITHUB_ORG, RAN_CONTEXT, CORE_CONTEXT, PHYSICAL_INTERFACE

# 3. Run!
./complete-nephio-deployment.sh
```

## 🎯 What It Deploys

**Timeline: ~10 minutes total**

### Both Clusters Get:
1. **Cluster Baseline** (3 min)
   - ConfigSync for GitOps
   - Namespaces with Pod Security
   - Node labels for Nephio

2. **Platform Addons** (3 min)
   - Local Path Provisioner (storage)
   - Metrics Server

3. **Networking** (3 min)
   - Multus CNI
   - Whereabouts IPAM
   - Network Attachment Definitions (NADs)

4. **Verification** (1 min)
   - Automated checks of all components

## 🔑 Key Features

**Smart Defaults:**
- Auto-detects node names
- Validates cluster connectivity before deploying
- Uses safe defaults for single-node bare-metal

**Safety:**
- Checks prerequisites before starting
- Confirmation prompt before applying
- Detailed error messages
- Verification after each phase

**Flexibility:**
- Two deployment modes (manual/GitOps)
- All settings configurable via variables
- Can be run multiple times safely
- Modular functions for easy customization

**User-Friendly:**
- Color-coded output (green=success, red=error, yellow=warning)
- Progress indicators
- Clear section headers
- Helpful summary at the end

## 📊 Deployment Flow

```
Pre-flight Checks ✓
     ↓
Workspace Setup ✓
     ↓
Generate Packages ✓
     ↓
Label Nodes ✓
     ↓
Deploy to RAN Cluster ✓
  → Baseline
  → Addons
  → Networking
  → NADs
     ↓
Deploy to CORE Cluster ✓
  → Baseline
  → Addons
  → Networking
  → NADs
     ↓
Verify Both Clusters ✓
     ↓
Print Summary 🎉
```

## 🔧 Customization Points

All easily edited in the script:
- **Network CIDRs**: Control plane, user plane ranges
- **Interface name**: eth0, ens33, etc.
- **Cluster names**: Logical names for labeling
- **Site IDs**: For multi-site deployments
- **Storage path**: Where PVs are stored

## ✨ Next Steps After Running Script

1. **Verify everything deployed** (script does this automatically)
2. **Test with a simple pod** that uses NADs and PVCs
3. **Deploy OAI RAN** to my-ran cluster
4. **Deploy Free5GC** to my-core cluster
5. **Configure connectivity** between RAN and Core

The script creates a working directory `nephio-deployment/` with all generated manifests, so you can inspect or modify them if needed.

Would you like me to:
1. Create a **rollback script** to cleanly undo the deployment?
2. Add a **health monitoring dashboard** script to check cluster status?
3. Create **sample workload deployment scripts** for testing the NADs?