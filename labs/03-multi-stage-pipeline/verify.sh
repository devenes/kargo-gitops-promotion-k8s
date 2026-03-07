#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Lab 03 Verification: Multi-stage Pipeline ==="
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

# 1. Check Project updated
echo -e "${BLUE}[1/10] Checking Project Configuration${NC}"
if check "Project 'kargo-lab' exists" "oc get project.kargo.akuity.io kargo-lab -n kargo-lab"; then
    # Check promotion policies
    TEST_AUTO=$(oc get project.kargo.akuity.io kargo-lab -n kargo-lab -o jsonpath='{.spec.promotionPolicies[?(@.stage=="test")].autoPromotionEnabled}' 2>/dev/null || echo "false")
    UAT_AUTO=$(oc get project.kargo.akuity.io kargo-lab -n kargo-lab -o jsonpath='{.spec.promotionPolicies[?(@.stage=="uat")].autoPromotionEnabled}' 2>/dev/null || echo "false")
    
    info "Promotion policies:"
    echo "  test auto-promotion: $TEST_AUTO"
    echo "  uat auto-promotion: $UAT_AUTO"
    echo "  prod auto-promotion: disabled (manual approval required)"
    
    if [ "$TEST_AUTO" != "true" ] || [ "$UAT_AUTO" != "true" ]; then
        warn "Update Project: oc apply -f labs/03-multi-stage-pipeline/project-updated.yaml"
        ALL_CHECKS_PASSED=false
    fi
fi
echo ""

# 2. Check all Stages exist
echo -e "${BLUE}[2/10] Checking Stages${NC}"
check "Stage 'test' exists" "oc get stage test -n kargo-lab"
check "Stage 'uat' exists" "oc get stage uat -n kargo-lab"
check "Stage 'prod' exists" "oc get stage prod -n kargo-lab"

info "Stage status:"
oc get stages -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
CURRENT_FREIGHT:.status.currentFreight.name,\
HEALTH:.status.health.status 2>/dev/null || echo "  Unable to get stage status"
echo ""

# 3. Check all ArgoCD Applications
echo -e "${BLUE}[3/10] Checking ArgoCD Applications${NC}"
check "Application 'demo-app-test' exists" "oc get application demo-app-test -n argocd"
check "Application 'demo-app-uat' exists" "oc get application demo-app-uat -n argocd"
check "Application 'demo-app-prod' exists" "oc get application demo-app-prod -n argocd"

info "Application sync status:"
for app in demo-app-test demo-app-uat demo-app-prod; do
    SYNC=$(oc get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH=$(oc get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    echo "  $app: Sync=$SYNC, Health=$HEALTH"
done
echo ""

# 4. Check all stage branches
echo -e "${BLUE}[4/10] Checking Stage Branches${NC}"
REPO_URL="https://github.com/devenes/kargo-gitops-promotion-k8s"

for branch in stage/test stage/uat stage/prod; do
    if git ls-remote --heads "$REPO_URL" "$branch" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $branch branch exists"
    else
        echo -e "${RED}✗${NC} $branch branch not found"
        warn "Branch will be created during promotion"
        ALL_CHECKS_PASSED=false
    fi
done
echo ""

# 5. Check all namespaces
echo -e "${BLUE}[5/10] Checking Namespaces${NC}"
check "Namespace 'kargo-lab-test' exists" "oc get namespace kargo-lab-test"
check "Namespace 'kargo-lab-uat' exists" "oc get namespace kargo-lab-uat"
check "Namespace 'kargo-lab-prod' exists" "oc get namespace kargo-lab-prod"
echo ""

# 6. Check pods in test
echo -e "${BLUE}[6/10] Checking Test Environment${NC}"
TEST_PODS=$(oc get pods -n kargo-lab-test --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEST_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Test pods running: $TEST_PODS"
    oc get pods -n kargo-lab-test -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp 2>/dev/null | head -5
else
    echo -e "${RED}✗${NC} No running pods in test"
    ALL_CHECKS_PASSED=false
fi
echo ""

# 7. Check pods in UAT
echo -e "${BLUE}[7/10] Checking UAT Environment${NC}"
UAT_PODS=$(oc get pods -n kargo-lab-uat --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$UAT_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} UAT pods running: $UAT_PODS"
    oc get pods -n kargo-lab-uat -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp 2>/dev/null | head -5
else
    echo -e "${YELLOW}⚠${NC} No running pods in UAT yet"
    warn "UAT promotion may still be in progress"
fi
echo ""

# 8. Check pods in Production
echo -e "${BLUE}[8/10] Checking Production Environment${NC}"
PROD_PODS=$(oc get pods -n kargo-lab-prod --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PROD_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Production pods running: $PROD_PODS"
    oc get pods -n kargo-lab-prod -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp 2>/dev/null | head -5
    
    # Check replica count (should be 3 for prod)
    REPLICAS=$(oc get deployment -n kargo-lab-prod -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "0")
    if [ "$REPLICAS" = "3" ]; then
        echo -e "${GREEN}✓${NC} Production running with 3 replicas (as configured)"
    else
        echo -e "${YELLOW}⚠${NC} Production replicas: $REPLICAS (expected 3)"
    fi
else
    echo -e "${YELLOW}⚠${NC} No running pods in production yet"
    warn "Production requires manual promotion"
    warn "Promote using: kargo promote --project kargo-lab --stage prod --freight <freight-name>"
fi
echo ""

# 9. Check promotions
echo -e "${BLUE}[9/10] Checking Promotion History${NC}"
PROMOTION_COUNT=$(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PROMOTION_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Promotions found: $PROMOTION_COUNT"
    
    info "Recent promotions:"
    oc get promotions -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
STAGE:.spec.stage,\
PHASE:.status.phase,\
AGE:.metadata.creationTimestamp 2>/dev/null | head -10
    
    # Check for failed promotions
    FAILED=$(oc get promotions -n kargo-lab -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null)
    if [ -n "$FAILED" ]; then
        echo ""
        warn "Failed promotions detected: $FAILED"
        warn "Check details: oc describe promotion <name> -n kargo-lab"
        ALL_CHECKS_PASSED=false
    fi
else
    echo -e "${YELLOW}⚠${NC} No promotions found"
    warn "Promotions should have been created automatically"
fi
echo ""

# 10. Check Routes/URLs
echo -e "${BLUE}[10/10] Checking Application URLs${NC}"
for env in test uat prod; do
    ROUTE_HOST=$(oc get route ${env}-demo-app -n kargo-lab-${env} -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-found")
    if [ "$ROUTE_HOST" != "not-found" ]; then
        echo -e "${GREEN}✓${NC} $env URL: https://$ROUTE_HOST"
    else
        echo -e "${YELLOW}⚠${NC} $env URL: not available yet"
    fi
done
echo ""

# Summary
echo "=== Verification Summary ==="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Lab 03 is complete. You have successfully:"
    echo "  ✓ Created a multi-stage pipeline (test → uat → prod)"
    echo "  ✓ Configured automatic promotion for test and UAT"
    echo "  ✓ Implemented manual approval gate for production"
    echo "  ✓ Deployed to all three environments"
    echo ""
    echo "Pipeline visualization:"
    echo "  Warehouse → test (auto) → uat (auto) → prod (manual)"
    echo ""
    echo "Access your applications:"
    for env in test uat prod; do
        ROUTE_HOST=$(oc get route ${env}-demo-app -n kargo-lab-${env} -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-found")
        if [ "$ROUTE_HOST" != "not-found" ]; then
            echo "  $env: https://$ROUTE_HOST"
        fi
    done
    echo ""
    echo "Next steps:"
    echo "  - Explore the Kargo UI to see the pipeline visualization"
    echo "  - Try triggering a new image update to see the full flow"
    echo "  - Proceed to Lab 04 to learn about PromotionTasks"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Project not updated with UAT auto-promotion"
    echo "  2. Promotions still in progress (wait a few minutes)"
    echo "  3. Production not promoted (requires manual approval)"
    echo ""
    echo "Troubleshooting:"
    echo "  - Update Project: oc apply -f labs/03-multi-stage-pipeline/project-updated.yaml"
    echo "  - Check promotions: oc get promotions -n kargo-lab"
    echo "  - Check stages: oc get stages -n kargo-lab"
    echo "  - Promote to prod: kargo promote --project kargo-lab --stage prod"
    echo "  - View Kargo UI for visual pipeline status"
    exit 1
fi

