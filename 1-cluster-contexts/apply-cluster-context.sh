#!/bin/bash
#==============================================================================
# Script to Apply ClusterContexts to Nephio Management Cluster
#==============================================================================

set -e

# Configuration
MGMT_CONTEXT="nephio-mgmt"  # Change this to your management cluster context name

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Registering Workload Clusters with Nephio${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Switch to management cluster context
echo -e "${BLUE}Switching to management cluster context: ${MGMT_CONTEXT}${NC}"
if ! kubectl config use-context ${MGMT_CONTEXT} &> /dev/null; then
    echo -e "${RED}Error: Could not switch to context ${MGMT_CONTEXT}${NC}"
    echo "Available contexts:"
    kubectl config get-contexts -o name
    exit 1
fi

echo -e "${GREEN}✓ Connected to management cluster${NC}"
echo ""

# Apply ClusterContext for my-ran
echo -e "${BLUE}Registering my-ran cluster...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-ran
  namespace: default
  labels:
    nephio.org/cluster-type: workload
    nephio.org/workload-type: ran
    nephio.org/site-code: site-ran-01
spec:
  clusterName: my-ran
  siteCode: site-ran-01
  cnis:
    - calico
    - macvlan
  annotations:
    nephio.org/description: "RAN workload cluster for OAI deployment"
    nephio.org/location: "Bengaluru, Karnataka, IN"
    nephio.org/environment: "development"
  provider: baremetal
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ my-ran ClusterContext created${NC}"
else
    echo -e "${RED}✗ Failed to create my-ran ClusterContext${NC}"
    exit 1
fi
echo ""

# Apply ClusterContext for my-core
echo -e "${BLUE}Registering my-core cluster...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: infra.nephio.org/v1alpha1
kind: ClusterContext
metadata:
  name: my-core
  namespace: default
  labels:
    nephio.org/cluster-type: workload
    nephio.org/workload-type: core
    nephio.org/site-code: site-core-01
spec:
  clusterName: my-core
  siteCode: site-core-01
  cnis:
    - calico
    - macvlan
  annotations:
    nephio.org/description: "Core workload cluster for Free5GC deployment"
    nephio.org/location: "Bengaluru, Karnataka, IN"
    nephio.org/environment: "development"
  provider: baremetal
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ my-core ClusterContext created${NC}"
else
    echo -e "${RED}✗ Failed to create my-core ClusterContext${NC}"
    exit 1
fi
echo ""

# Verify ClusterContexts
echo -e "${BLUE}Verifying ClusterContexts...${NC}"
echo ""

kubectl get clustercontexts

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}ClusterContexts registered successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Show details
echo -e "${BLUE}my-ran ClusterContext details:${NC}"
kubectl get clustercontext my-ran -o yaml
echo ""

echo -e "${BLUE}my-core ClusterContext details:${NC}"
kubectl get clustercontext my-core -o yaml
echo ""

echo -e "${GREEN}Next steps:${NC}"
echo "1. Register git repositories (Repository CRs)"
echo "2. Create PackageVariants for baseline, addons, and networking"
echo "3. Approve PackageRevisions"
echo "4. Bootstrap ConfigSync on workload clusters"