#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Kargo Learning Lab - Infrastructure Installation ==="
echo ""

# Check prerequisites first
if [ -f "setup/prerequisites.sh" ]; then
    bash setup/prerequisites.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Prerequisites check failed. Please install missing tools.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: prerequisites.sh not found. Skipping prerequisites check.${NC}"
fi

echo ""
echo "=== Starting Infrastructure Installation ==="
echo ""

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    echo "Waiting for pods in namespace $namespace to be ready..."
    if oc wait --for=condition=Ready pods --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} All pods in $namespace are ready"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Some pods in $namespace may not be ready yet"
        oc get pods -n "$namespace"
        return 1
    fi
}

# 1. Install cert-manager
echo -e "${BLUE}[1/3] Installing cert-manager v1.16.3...${NC}"
echo ""

# Create namespace
oc apply -f infrastructure/cert-manager/namespace.yaml

# Add Helm repo
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v1.16.3 \
    --values infrastructure/cert-manager/values.yaml \
    --wait \
    --timeout 5m

echo ""
wait_for_pods cert-manager 300
echo ""

# 2. Install ArgoCD
echo -e "${BLUE}[2/3] Installing ArgoCD v2.13.3...${NC}"
echo ""

# Create namespace
oc apply -f infrastructure/argocd/namespace.yaml

# Install ArgoCD
oc apply -n argocd -f infrastructure/argocd/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD pods to start..."
sleep 10
wait_for_pods argocd 300

# Apply ConfigMap patch for insecure mode
echo "Applying ConfigMap patch for OpenShift Route compatibility..."
oc apply -f infrastructure/argocd/configmap-patch.yaml

# Restart ArgoCD server to pick up the config change
echo "Restarting ArgoCD server..."
oc rollout restart deployment argocd-server -n argocd
oc rollout status deployment argocd-server -n argocd --timeout=300s

# Create Route
oc apply -f infrastructure/argocd/route.yaml

echo ""
echo -e "${GREEN}✓${NC} ArgoCD installed successfully"
echo ""

# 3. Install Kargo
echo -e "${BLUE}[3/3] Installing Kargo v1.9.3...${NC}"
echo ""

# Create namespace
oc apply -f infrastructure/kargo/namespace.yaml

# Install Kargo via Helm
helm upgrade --install kargo \
    oci://ghcr.io/akuity/kargo-charts/kargo \
    --version 1.9.3 \
    --namespace kargo \
    --values infrastructure/kargo/values.yaml \
    --wait \
    --timeout 5m

echo ""
wait_for_pods kargo 300

# Create Route
oc apply -f infrastructure/kargo/route.yaml

# Patch the Kargo TLS certificate to include the Route hostname.
# The Helm chart only adds "localhost" by default, which causes browsers
# to reject the connection with a hostname mismatch error.
echo "Patching Kargo TLS certificate with Route hostname..."
KARGO_HOST=$(oc get route kargo-api -n kargo -o jsonpath='{.spec.host}')
oc patch certificate kargo-api -n kargo --type=json -p="[
  {\"op\": \"add\", \"path\": \"/spec/dnsNames/-\", \"value\": \"$KARGO_HOST\"},
  {\"op\": \"add\", \"path\": \"/spec/dnsNames/-\", \"value\": \"kargo-api.kargo.svc\"},
  {\"op\": \"add\", \"path\": \"/spec/dnsNames/-\", \"value\": \"kargo-api.kargo.svc.cluster.local\"}
]"
oc wait certificate kargo-api -n kargo --for=condition=Ready --timeout=60s

# Also name the service port so the Route targetPort resolves correctly
# (Helm chart creates the port without a name)
oc patch svc kargo-api -n kargo --type=json \
  -p='[{"op":"add","path":"/spec/ports/0/name","value":"https"}]' 2>/dev/null || true

# Restart API to load the new certificate
oc rollout restart deployment kargo-api -n kargo
oc rollout status deployment kargo-api -n kargo --timeout=120s

echo ""
echo -e "${GREEN}✓${NC} Kargo installed successfully"
echo ""

# Display access information
echo "=== Installation Complete! ==="
echo ""
echo -e "${GREEN}All infrastructure components are installed and running.${NC}"
echo ""

# Get ArgoCD info
ARGOCD_URL=$(oc get route argocd-server -n argocd -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-found")
ARGOCD_PASS=$(oc get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "not-found")

echo "=== ArgoCD Access ==="
echo "URL: https://$ARGOCD_URL"
echo "Username: admin"
echo "Password: $ARGOCD_PASS"
echo ""
echo "Login via CLI:"
echo "  argocd login $ARGOCD_URL --username admin --password '$ARGOCD_PASS' --insecure"
echo ""

# Get Kargo info
KARGO_URL=$(oc get route kargo-api -n kargo -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-found")

echo "=== Kargo Access ==="
echo "URL: https://$KARGO_URL"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Login via CLI:"
echo "  kargo login https://$KARGO_URL --admin --password admin --insecure-skip-tls-verify"
echo ""

echo "=== Next Steps ==="
echo "1. Verify all pods are running:"
echo "   oc get pods -n cert-manager"
echo "   oc get pods -n argocd"
echo "   oc get pods -n kargo"
echo ""
echo "2. Access the UIs using the URLs above"
echo ""
echo "3. Start with Lab 01:"
echo "   cd labs/01-warehouse-and-freight"
echo "   cat README.md"
echo ""
echo -e "${GREEN}Happy learning!${NC}"

