#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Lab 02 Verification: First Stage - Auto-promotion ==="
echo ""

# Track overall success
ALL_CHECKS_PASSED=true

# Function to check a condition
check() {
    local description=$1
    local command=$2
    
    echo -n "Checking: $description... "
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to display info
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to display warning
warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check Git credentials
echo -e "${BLUE}[1/7] Checking Git Credentials${NC}"
if check "Git credentials Secret exists" "oc get secret git-credentials -n kargo-lab"; then
    # Check for required label
    LABEL=$(oc get secret git-credentials -n kargo-lab -o jsonpath='{.metadata.labels.kargo\.akuity\.io/cred-type}' 2>/dev/null || echo "")
    if [ "$LABEL" = "git" ]; then
        echo -e "${GREEN}✓${NC} Secret has required label: kargo.akuity.io/cred-type=git"
    else
        echo -e "${RED}✗${NC} Secret missing required label"
        warn "Add label: oc label secret git-credentials kargo.akuity.io/cred-type=git -n kargo-lab"
        ALL_CHECKS_PASSED=false
    fi
else
    warn "Create Git credentials using: bash setup/configure-git-credentials.sh"
fi
echo ""

# 2. Check Stage exists
echo -e "${BLUE}[2/7] Checking Stage${NC}"
if check "Stage 'test' exists" "oc get stage test -n kargo-lab"; then
    info "Stage details:"
    echo "  Name: test"
    echo "  Namespace: kargo-lab"
    
    # Check if Stage has Freight
    CURRENT_FREIGHT=$(oc get stage test -n kargo-lab -o jsonpath='{.status.currentFreight.name}' 2>/dev/null || echo "")
    if [ -n "$CURRENT_FREIGHT" ]; then
        echo "  Current Freight: $CURRENT_FREIGHT"
    else
        echo "  Current Freight: None (waiting for promotion)"
    fi
fi
echo ""

# 3. Check ArgoCD Application
echo -e "${BLUE}[3/7] Checking ArgoCD Application${NC}"
if check "ArgoCD Application 'demo-app-test' exists" "oc get application demo-app-test -n argocd"; then
    # Check authorization annotation
    ANNOTATION=$(oc get application demo-app-test -n argocd -o jsonpath='{.metadata.annotations.kargo\.akuity\.io/authorized-stage}' 2>/dev/null || echo "")
    if [ "$ANNOTATION" = "kargo-lab:test" ]; then
        echo -e "${GREEN}✓${NC} Application has required annotation: kargo.akuity.io/authorized-stage=kargo-lab:test"
    else
        echo -e "${RED}✗${NC} Application missing required annotation"
        ALL_CHECKS_PASSED=false
    fi
    
    # Check sync status
    SYNC_STATUS=$(oc get application demo-app-test -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(oc get application demo-app-test -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    info "Application status:"
    echo "  Sync: $SYNC_STATUS"
    echo "  Health: $HEALTH_STATUS"
fi
echo ""

# 4. Check stage/test branch
echo -e "${BLUE}[4/7] Checking stage/test Branch${NC}"
REPO_URL="https://github.com/devenes/kargo-gitops-promotion-k8s"
if git ls-remote --heads "$REPO_URL" stage/test &> /dev/null; then
    echo -e "${GREEN}✓${NC} stage/test branch exists"
    
    # Get latest commit
    COMMIT=$(git ls-remote --heads "$REPO_URL" stage/test 2>/dev/null | awk '{print $1}' | cut -c1-8)
    info "Latest commit: $COMMIT"
else
    echo -e "${RED}✗${NC} stage/test branch not found"
    warn "Branch will be created during first promotion"
    warn "Check promotion status: oc get promotions -n kargo-lab"
    ALL_CHECKS_PASSED=false
fi
echo ""

# 5. Check namespace
echo -e "${BLUE}[5/7] Checking Namespace${NC}"
if check "Namespace 'kargo-lab-test' exists" "oc get namespace kargo-lab-test"; then
    info "Namespace created by ArgoCD"
fi
echo ""

# 6. Check pods
echo -e "${BLUE}[6/7] Checking Pods${NC}"
POD_COUNT=$(oc get pods -n kargo-lab-test --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$POD_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Pods found: $POD_COUNT"
    
    # Check pod status
    RUNNING_PODS=$(oc get pods -n kargo-lab-test --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$RUNNING_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Running pods: $RUNNING_PODS"
        info "Pod list:"
        oc get pods -n kargo-lab-test -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp
    else
        echo -e "${YELLOW}⚠${NC} No pods in Running state yet"
        warn "Pods may still be starting. Check status: oc get pods -n kargo-lab-test"
    fi
else
    echo -e "${RED}✗${NC} No pods found"
    warn "Pods should be created by ArgoCD after promotion"
    warn "Check ArgoCD sync status: argocd app get demo-app-test"
    ALL_CHECKS_PASSED=false
fi
echo ""

# 7. Check promotions
echo -e "${BLUE}[7/7] Checking Promotions${NC}"
PROMOTION_COUNT=$(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PROMOTION_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Promotions found: $PROMOTION_COUNT"
    
    info "Promotion history:"
    oc get promotions -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
STAGE:.spec.stage,\
PHASE:.status.phase,\
AGE:.metadata.creationTimestamp
    
    # Check latest promotion status
    LATEST_PROMOTION=$(oc get promotions -n kargo-lab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$LATEST_PROMOTION" ]; then
        PHASE=$(oc get promotion "$LATEST_PROMOTION" -n kargo-lab -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo ""
        info "Latest promotion: $LATEST_PROMOTION"
        echo "  Phase: $PHASE"
        
        if [ "$PHASE" = "Succeeded" ]; then
            echo -e "${GREEN}✓${NC} Promotion completed successfully"
        elif [ "$PHASE" = "Running" ]; then
            echo -e "${YELLOW}⚠${NC} Promotion in progress"
            warn "Wait for promotion to complete"
        elif [ "$PHASE" = "Failed" ]; then
            echo -e "${RED}✗${NC} Promotion failed"
            warn "Check promotion details: oc describe promotion $LATEST_PROMOTION -n kargo-lab"
            ALL_CHECKS_PASSED=false
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} No promotions found yet"
    warn "Auto-promotion should trigger automatically"
    warn "Check Stage status: oc get stage test -n kargo-lab -o yaml"
fi
echo ""

# Summary
echo "=== Verification Summary ==="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Lab 02 is complete. You have successfully:"
    echo "  ✓ Configured Git credentials"
    echo "  ✓ Created a Stage with promotion steps"
    echo "  ✓ Integrated with ArgoCD"
    echo "  ✓ Achieved automatic promotion"
    echo "  ✓ Deployed to test environment"
    echo ""
    echo "Access your application:"
    ROUTE_HOST=$(oc get route test-demo-app -n kargo-lab-test -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-found")
    if [ "$ROUTE_HOST" != "not-found" ]; then
        echo "  URL: https://$ROUTE_HOST"
        echo "  Test: curl -I https://$ROUTE_HOST"
    fi
    echo ""
    echo "Next: Proceed to Lab 03 to create a multi-stage pipeline"
    echo "  cd ../03-multi-stage-pipeline"
    echo "  cat README.md"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Git credentials not configured or missing label"
    echo "  2. Promotion still in progress (wait a few minutes)"
    echo "  3. ArgoCD Application not synced yet"
    echo ""
    echo "Troubleshooting commands:"
    echo "  - Check promotions: oc get promotions -n kargo-lab"
    echo "  - Check Stage: oc describe stage test -n kargo-lab"
    echo "  - Check ArgoCD: argocd app get demo-app-test"
    echo "  - Check Kargo logs: oc logs -n kargo -l app.kubernetes.io/component=controller --tail=50"
    exit 1
fi

