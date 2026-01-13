#==============================================================================
# OPTION 1: RECOMMENDED - 4 SEPARATE REPOSITORIES
# Most scalable, best separation of concerns
#==============================================================================

#------------------------------------------------------------------------------
# REPO 1: nephio-management-config
# Purpose: Management cluster configuration (NEW!)
# URL: https://github.com/YOUR-ORG/nephio-management-config.git
#------------------------------------------------------------------------------

nephio-management-config/
├── README.md
├── kustomization.yaml
│
├── cluster-contexts/
│   ├── kustomization.yaml
│   ├── clustercontext-my-ran.yaml
│   └── clustercontext-my-core.yaml
│
├── repositories/
│   ├── kustomization.yaml
│   ├── repository-blueprints.yaml
│   ├── repository-my-ran.yaml
│   └── repository-my-core.yaml
│
└── packagevariants/
    ├── kustomization.yaml
    │
    ├── baseline/
    │   ├── kustomization.yaml
    │   ├── baseline-my-ran.yaml
    │   └── baseline-my-core.yaml
    │
    ├── addons/
    │   ├── kustomization.yaml
    │   ├── addons-my-ran.yaml
    │   └── addons-my-core.yaml
    │
    └── networking/
        ├── kustomization.yaml
        ├── multus-my-ran.yaml
        ├── multus-my-core.yaml
        ├── whereabouts-my-ran.yaml
        ├── whereabouts-my-core.yaml
        ├── nads-my-ran.yaml
        └── nads-my-core.yaml

#------------------------------------------------------------------------------
# REPO 2: nephio-blueprints
# Purpose: Blueprint packages (upstream)
# URL: https://github.com/YOUR-ORG/nephio-blueprints.git
#------------------------------------------------------------------------------

nephio-blueprints/
├── README.md
│
├── cluster-baseline/
│   ├── Kptfile
│   ├── configsync.yaml
│   ├── rootsync.yaml
│   ├── git-credentials-secret.yaml
│   ├── pod-security.yaml
│   ├── node-configuration.yaml
│   ├── default-resource-limits.yaml
│   └── storage-class.yaml
│
├── platform-addons/
│   ├── Kptfile
│   ├── storage/
│   │   └── local-path-provisioner.yaml
│   ├── monitoring/
│   │   └── metrics-server.yaml
│   └── resource-management/
│       └── resource-quotas.yaml
│
└── networking/
    ├── multus-cni/
    │   ├── Kptfile
    │   └── multus-daemonset.yaml
    │
    ├── whereabouts-ipam/
    │   ├── Kptfile
    │   └── whereabouts.yaml
    │
    ├── network-intents/
    │   ├── Kptfile
    │   ├── control-plane.yaml
    │   └── user-plane.yaml
    │
    └── network-attachment-renderer/
        ├── Kptfile
        ├── nad-renderer-config.yaml
        └── examples/
            ├── ran-nads.yaml
            └── core-nads.yaml

#------------------------------------------------------------------------------
# REPO 3: nephio-my-ran
# Purpose: Rendered packages for RAN cluster (downstream)
# URL: https://github.com/YOUR-ORG/nephio-my-ran.git
# Initial state: EMPTY (just README.md)
# After Porch: Populated with rendered packages
#------------------------------------------------------------------------------

nephio-my-ran/
├── README.md  # Initial file
│
# After Porch renders:
├── cluster-baseline/
│   ├── Kptfile
│   ├── configsync.yaml
│   ├── rootsync.yaml
│   ├── git-credentials-secret.yaml
│   ├── pod-security.yaml
│   ├── node-configuration.yaml
│   ├── default-resource-limits.yaml
│   ├── storage-class.yaml
│   └── resourcegroup.yaml
│
├── platform-addons/
│   ├── Kptfile
│   ├── storage/
│   │   └── local-path-provisioner.yaml
│   ├── monitoring/
│   │   └── metrics-server.yaml
│   ├── resource-management/
│   │   └── resource-quotas.yaml
│   └── resourcegroup.yaml
│
├── multus-cni/
│   ├── Kptfile
│   ├── multus-daemonset.yaml
│   └── resourcegroup.yaml
│
├── whereabouts-ipam/
│   ├── Kptfile
│   ├── whereabouts.yaml
│   └── resourcegroup.yaml
│
└── network-attachments/
    ├── Kptfile
    ├── ran-ctrl-net.yaml
    ├── ran-user-net.yaml
    └── resourcegroup.yaml

#------------------------------------------------------------------------------
# REPO 4: nephio-my-core
# Purpose: Rendered packages for CORE cluster (downstream)
# URL: https://github.com/YOUR-ORG/nephio-my-core.git
# Initial state: EMPTY (just README.md)
# After Porch: Populated with rendered packages
#------------------------------------------------------------------------------

nephio-my-core/
├── README.md  # Initial file
│
# After Porch renders:
├── cluster-baseline/
│   ├── Kptfile
│   ├── configsync.yaml
│   ├── rootsync.yaml
│   ├── git-credentials-secret.yaml
│   ├── pod-security.yaml
│   ├── node-configuration.yaml
│   ├── default-resource-limits.yaml
│   ├── storage-class.yaml
│   └── resourcegroup.yaml
│
├── platform-addons/
│   ├── Kptfile
│   ├── storage/
│   │   └── local-path-provisioner.yaml
│   ├── monitoring/
│   │   └── metrics-server.yaml
│   ├── resource-management/
│   │   └── resource-quotas.yaml
│   └── resourcegroup.yaml
│
├── multus-cni/
│   ├── Kptfile
│   ├── multus-daemonset.yaml
│   └── resourcegroup.yaml
│
├── whereabouts-ipam/
│   ├── Kptfile
│   ├── whereabouts.yaml
│   └── resourcegroup.yaml
│
└── network-attachments/
    ├── Kptfile
    ├── core-ctrl-net.yaml
    ├── core-user-net.yaml
    └── resourcegroup.yaml


#==============================================================================
# OPTION 2: COMPACT - 3 REPOSITORIES WITH COMBINED DOWNSTREAM
# Fewer repos, but coupled deployments
#==============================================================================

#------------------------------------------------------------------------------
# REPO 1: nephio-management-config (same as Option 1)
#------------------------------------------------------------------------------

nephio-management-config/
├── README.md
├── kustomization.yaml
├── cluster-contexts/
│   ├── kustomization.yaml
│   ├── clustercontext-my-ran.yaml
│   └── clustercontext-my-core.yaml
├── repositories/
│   ├── kustomization.yaml
│   ├── repository-blueprints.yaml
│   └── repository-workload-clusters.yaml  # Single downstream repo
└── packagevariants/
    ├── kustomization.yaml
    ├── baseline/
    │   ├── baseline-my-ran.yaml   # downstream.package: ran/cluster-baseline
    │   └── baseline-my-core.yaml  # downstream.package: core/cluster-baseline
    ├── addons/
    │   ├── addons-my-ran.yaml
    │   └── addons-my-core.yaml
    └── networking/
        ├── multus-my-ran.yaml
        ├── multus-my-core.yaml
        ├── whereabouts-my-ran.yaml
        ├── whereabouts-my-core.yaml
        ├── nads-my-ran.yaml
        └── nads-my-core.yaml

#------------------------------------------------------------------------------
# REPO 2: nephio-blueprints (same as Option 1)
#------------------------------------------------------------------------------

nephio-blueprints/
├── README.md
├── cluster-baseline/
│   └── ... (same as Option 1)
├── platform-addons/
│   └── ... (same as Option 1)
└── networking/
    └── ... (same as Option 1)

#------------------------------------------------------------------------------
# REPO 3: nephio-workload-clusters (COMBINED downstream)
# Purpose: Rendered packages for BOTH clusters
# URL: https://github.com/YOUR-ORG/nephio-workload-clusters.git
#------------------------------------------------------------------------------

nephio-workload-clusters/
├── README.md
│
├── ran/  # RAN cluster packages (ConfigSync watches this folder)
│   ├── cluster-baseline/
│   │   ├── Kptfile
│   │   ├── configsync.yaml
│   │   ├── rootsync.yaml  # dir: /ran
│   │   ├── pod-security.yaml
│   │   ├── node-configuration.yaml
│   │   ├── default-resource-limits.yaml
│   │   ├── storage-class.yaml
│   │   └── resourcegroup.yaml
│   │
│   ├── platform-addons/
│   │   ├── Kptfile
│   │   ├── storage/
│   │   ├── monitoring/
│   │   ├── resource-management/
│   │   └── resourcegroup.yaml
│   │
│   ├── multus-cni/
│   │   ├── Kptfile
│   │   ├── multus-daemonset.yaml
│   │   └── resourcegroup.yaml
│   │
│   ├── whereabouts-ipam/
│   │   ├── Kptfile
│   │   ├── whereabouts.yaml
│   │   └── resourcegroup.yaml
│   │
│   └── network-attachments/
│       ├── Kptfile
│       ├── ran-ctrl-net.yaml
│       ├── ran-user-net.yaml
│       └── resourcegroup.yaml
│
└── core/  # CORE cluster packages (ConfigSync watches this folder)
    ├── cluster-baseline/
    │   ├── Kptfile
    │   ├── configsync.yaml
    │   ├── rootsync.yaml  # dir: /core
    │   ├── pod-security.yaml
    │   ├── node-configuration.yaml
    │   ├── default-resource-limits.yaml
    │   ├── storage-class.yaml
    │   └── resourcegroup.yaml
    │
    ├── platform-addons/
    │   ├── Kptfile
    │   ├── storage/
    │   ├── monitoring/
    │   ├── resource-management/
    │   └── resourcegroup.yaml
    │
    ├── multus-cni/
    │   ├── Kptfile
    │   ├── multus-daemonset.yaml
    │   └── resourcegroup.yaml
    │
    ├── whereabouts-ipam/
    │   ├── Kptfile
    │   ├── whereabouts.yaml
    │   └── resourcegroup.yaml
    │
    └── network-attachments/
        ├── Kptfile
        ├── core-ctrl-net.yaml
        ├── core-user-net.yaml
        └── resourcegroup.yaml


#==============================================================================
# KEY DIFFERENCES BETWEEN OPTIONS
#==============================================================================

# Option 1 (4 repos):
# - nephio-management-config  (mgmt cluster config)
# - nephio-blueprints         (upstream)
# - nephio-my-ran            (RAN downstream)
# - nephio-my-core           (CORE downstream)
#
# Pros: Clean separation, independent versioning, scalable
# Cons: 4 repos to manage

# Option 2 (3 repos):
# - nephio-management-config       (mgmt cluster config)
# - nephio-blueprints              (upstream)
# - nephio-workload-clusters       (combined downstream with ran/ and core/)
#
# Pros: Fewer repos, centralized view
# Cons: Coupled deployments, larger repo

#==============================================================================
# CONFIGURATION DIFFERENCES FOR OPTION 2
#==============================================================================

# PackageVariant changes for Option 2:
# Instead of:
#   downstream:
#     repo: nephio-my-ran
#     package: cluster-baseline
#
# Use:
#   downstream:
#     repo: nephio-workload-clusters
#     package: ran/cluster-baseline  # Folder prefix!

# RootSync changes for Option 2:
# RAN cluster RootSync:
#   spec:
#     git:
#       repo: https://github.com/YOUR-ORG/nephio-workload-clusters.git
#       dir: /ran  # Only watch ran/ folder
#
# CORE cluster RootSync:
#   spec:
#     git:
#       repo: https://github.com/YOUR-ORG/nephio-workload-clusters.git
#       dir: /core  # Only watch core/ folder

#==============================================================================
# FILE COUNTS
#==============================================================================

# Option 1 (4 repos):
# - nephio-management-config: ~15 files
# - nephio-blueprints: ~30 files
# - nephio-my-ran: ~35 files (after Porch)
# - nephio-my-core: ~35 files (after Porch)
# Total: ~115 files

# Option 2 (3 repos):
# - nephio-management-config: ~15 files
# - nephio-blueprints: ~30 files
# - nephio-workload-clusters: ~70 files (ran/ + core/ after Porch)
# Total: ~115 files (same total, different organization)