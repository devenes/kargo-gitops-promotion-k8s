#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Kargo Learning Lab - Git Credentials Configuration ==="
echo ""
echo "This script will help you create a Kubernetes Secret for Git credentials."
echo "Kargo needs these credentials to push changes to your repository."
echo ""

# Default values
DEFAULT_REPO_URL="https://github.com/devenes/kargo-gitops-promotion-k8s"
DEFAULT_NAMESPACE="kargo-lab"

# Prompt for repository URL
echo -e "${BLUE}Repository URL${NC}"
read -p "Enter your Git repository URL [$DEFAULT_REPO_URL]: " REPO_URL
REPO_URL=${REPO_URL:-$DEFAULT_REPO_URL}
echo ""

# Prompt for GitHub username
echo -e "${BLUE}GitHub Username${NC}"
read -p "Enter your GitHub username: " GIT_USERNAME
if [ -z "$GIT_USERNAME" ]; then
    echo -e "${RED}Error: GitHub username is required${NC}"
    exit 1
fi
echo ""

# Prompt for GitHub token
echo -e "${BLUE}GitHub Personal Access Token${NC}"
echo "You need a GitHub Personal Access Token with 'repo' scope."
echo "Create one at: https://github.com/settings/tokens/new"
echo ""
read -sp "Enter your GitHub token: " GIT_TOKEN
echo ""
if [ -z "$GIT_TOKEN" ]; then
    echo -e "${RED}Error: GitHub token is required${NC}"
    exit 1
fi
echo ""

# Prompt for namespace
echo -e "${BLUE}Namespace${NC}"
read -p "Enter the Kargo project namespace [$DEFAULT_NAMESPACE]: " NAMESPACE
NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Warning: Namespace '$NAMESPACE' does not exist yet.${NC}"
    echo "It will be created when you apply the Kargo Project resource."
    echo ""
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

# Create the secret
echo "Creating Git credentials Secret..."
echo ""

# Create secret YAML
cat > /tmp/git-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: git-credentials
  namespace: $NAMESPACE
  labels:
    kargo.akuity.io/cred-type: git
type: Opaque
stringData:
  repoURL: $REPO_URL
  username: $GIT_USERNAME
  password: $GIT_TOKEN
EOF

# Apply the secret
if oc apply -f /tmp/git-credentials.yaml; then
    echo ""
    echo -e "${GREEN}✓${NC} Git credentials Secret created successfully!"
    echo ""
    echo "Secret details:"
    echo "  Name: git-credentials"
    echo "  Namespace: $NAMESPACE"
    echo "  Repository: $REPO_URL"
    echo "  Username: $GIT_USERNAME"
    echo ""
    echo -e "${YELLOW}Important: The label 'kargo.akuity.io/cred-type: git' is required!${NC}"
    echo ""
    
    # Clean up temp file
    rm -f /tmp/git-credentials.yaml
    
    echo "You can now proceed with Lab 02 and beyond."
else
    echo ""
    echo -e "${RED}✗${NC} Failed to create Secret"
    echo ""
    echo "The Secret YAML has been saved to: /tmp/git-credentials.yaml"
    echo "You can manually apply it later with:"
    echo "  oc apply -f /tmp/git-credentials.yaml"
    exit 1
fi

