#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Kargo Learning Lab - Infrastructure Uninstallation ==="
echo ""
echo -e "${YELLOW}WARNING: This will remove all infrastructure components and lab resources!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "Starting uninstallation..."
echo ""

# Function to safely delete namespace
delete_namespace() {
    local ns=$1
    if oc get namespace "$ns" &> /dev/null; then
        echo "Deleting namespace: $ns"
        oc delete namespace "$ns" --timeout=60s || true
        echo -e "${GREEN}✓${NC} Namespace $ns deleted"
    else
        echo "Namespace $ns does not exist, skipping..."
    fi
}

# Function to safely uninstall Helm release
uninstall_helm() {
    local release=$1
    local namespace=$2
    if helm list -n "$namespace" | grep -q "$release"; then
        echo "Uninstalling Helm release: $release from namespace $namespace"
        helm uninstall "$release" -n "$namespace" --timeout 5m || true
        echo -e "${GREEN}✓${NC} Helm release $release uninstalled"
    else
        echo "Helm release $release not found in namespace $namespace, skipping..."
    fi
}

# Delete lab namespaces first
echo "=== Cleaning up lab namespaces ==="
delete_namespace "kargo-lab"
delete_namespace "kargo-lab-test"
delete_namespace "kargo-lab-uat"
delete_namespace "kargo-lab-prod"
echo ""

# Uninstall Kargo
echo "=== Uninstalling Kargo ==="
uninstall_helm "kargo" "kargo"
delete_namespace "kargo"
echo ""

# Uninstall ArgoCD
echo "=== Uninstalling ArgoCD ==="
if oc get namespace argocd &> /dev/null; then
    echo "Deleting ArgoCD resources..."
    oc delete -n argocd -f infrastructure/argocd/install.yaml --timeout=60s || true
fi
delete_namespace "argocd"
echo ""

# Uninstall cert-manager
echo "=== Uninstalling cert-manager ==="
uninstall_helm "cert-manager" "cert-manager"
delete_namespace "cert-manager"
echo ""

# Clean up CRDs (optional - be careful with this in shared clusters)
echo "=== Cleaning up CRDs (optional) ==="
read -p "Do you want to delete Kargo and cert-manager CRDs? This affects the entire cluster! (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deleting Kargo CRDs..."
    oc get crd | grep kargo.akuity.io | awk '{print $1}' | xargs -r oc delete crd || true
    
    echo "Deleting cert-manager CRDs..."
    oc get crd | grep cert-manager.io | awk '{print $1}' | xargs -r oc delete crd || true
    
    echo -e "${GREEN}✓${NC} CRDs deleted"
else
    echo "Skipping CRD deletion"
fi
echo ""

echo "=== Uninstallation Complete ==="
echo ""
echo -e "${GREEN}All infrastructure components have been removed.${NC}"
echo ""
echo "To reinstall, run: bash setup/install.sh"

