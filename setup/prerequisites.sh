#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Kargo Learning Lab - Prerequisites Check ==="
echo ""

# Track if all prerequisites are met
ALL_GOOD=true

# Function to check if a command exists
check_command() {
    local cmd=$1
    local required_version=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd version 2>&1 | head -n 1 || echo "unknown")
        echo -e "${GREEN}✓${NC} $cmd is installed: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd is NOT installed"
        if [ -n "$required_version" ]; then
            echo "  Required: $required_version"
        fi
        ALL_GOOD=false
        return 1
    fi
}

# Check OpenShift CLI
echo "Checking OpenShift CLI..."
if check_command "oc" ">= 4.14"; then
    # Check cluster connectivity
    if oc whoami &> /dev/null; then
        CLUSTER_VERSION=$(oc version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
        CURRENT_USER=$(oc whoami 2>/dev/null || echo "unknown")
        CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "none")
        echo -e "${GREEN}✓${NC} Connected to OpenShift cluster"
        echo "  Cluster version: $CLUSTER_VERSION"
        echo "  Current user: $CURRENT_USER"
        echo "  Current project: $CURRENT_PROJECT"
    else
        echo -e "${RED}✗${NC} Not connected to OpenShift cluster"
        echo "  Run: oc login <cluster-url>"
        ALL_GOOD=false
    fi
else
    echo "  Install: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
fi
echo ""

# Check Helm
echo "Checking Helm..."
if check_command "helm" ">= 3.13"; then
    :
else
    echo "  Install: https://helm.sh/docs/intro/install/"
fi
echo ""

# Check kustomize
echo "Checking kustomize..."
if check_command "kustomize" ">= 5.0"; then
    :
else
    echo "  Install: https://kubectl.docs.kubernetes.io/installation/kustomize/"
fi
echo ""

# Check Kargo CLI
echo "Checking Kargo CLI..."
if check_command "kargo" "v1.9.3"; then
    :
else
    echo "  Install: https://github.com/akuity/kargo/releases/tag/v1.9.3"
    echo "  Linux: curl -L -o kargo https://github.com/akuity/kargo/releases/download/v1.9.3/kargo-linux-amd64"
    echo "  macOS: curl -L -o kargo https://github.com/akuity/kargo/releases/download/v1.9.3/kargo-darwin-amd64"
    echo "  Then: chmod +x kargo && sudo mv kargo /usr/local/bin/"
fi
echo ""

# Check ArgoCD CLI
echo "Checking ArgoCD CLI..."
if check_command "argocd" "v2.13.3"; then
    :
else
    echo "  Install: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    echo "  Linux: curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v2.13.3/argocd-linux-amd64"
    echo "  macOS: curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v2.13.3/argocd-darwin-amd64"
    echo "  Then: chmod +x argocd && sudo mv argocd /usr/local/bin/"
fi
echo ""

# Check git
echo "Checking git..."
if check_command "git" ">= 2.0"; then
    :
else
    echo "  Install: https://git-scm.com/downloads"
fi
echo ""

# Check curl
echo "Checking curl..."
if check_command "curl"; then
    :
else
    echo "  Install: Usually pre-installed on most systems"
fi
echo ""

# Check jq (optional but recommended)
echo "Checking jq (optional)..."
if check_command "jq"; then
    :
else
    echo -e "${YELLOW}⚠${NC} jq is NOT installed (optional but recommended for JSON parsing)"
    echo "  Install: https://stedolan.github.io/jq/download/"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✓ All required prerequisites are met!${NC}"
    echo ""
    echo "You can now run: bash setup/install.sh"
    exit 0
else
    echo -e "${RED}✗ Some prerequisites are missing${NC}"
    echo ""
    echo "Please install the missing tools and try again."
    exit 1
fi

