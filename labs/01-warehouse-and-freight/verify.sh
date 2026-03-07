#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Lab 01 Verification: Warehouse and Freight ==="
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

# 1. Check if Project exists
echo -e "${BLUE}[1/4] Checking Kargo Project${NC}"
if check "Project 'kargo-lab' exists" "oc get project.kargo.akuity.io kargo-lab -n kargo-lab"; then
    info "Project details:"
    oc get project.kargo.akuity.io kargo-lab -n kargo-lab -o jsonpath='{.metadata.name}{"\n"}'
fi
echo ""

# 2. Check if namespace was created
echo -e "${BLUE}[2/4] Checking Namespace${NC}"
if check "Namespace 'kargo-lab' exists" "oc get namespace kargo-lab"; then
    info "Namespace created by Kargo Project"
fi
echo ""

# 3. Check if Warehouse exists
echo -e "${BLUE}[3/4] Checking Warehouse${NC}"
if check "Warehouse 'demo-app' exists" "oc get warehouse demo-app -n kargo-lab"; then
    info "Warehouse details:"
    echo "  Name: demo-app"
    echo "  Interval: $(oc get warehouse demo-app -n kargo-lab -o jsonpath='{.spec.interval}')"
    echo "  Subscriptions:"
    
    # Check image subscription
    IMAGE_REPO=$(oc get warehouse demo-app -n kargo-lab -o jsonpath='{.spec.subscriptions[?(@.image)].image.repoURL}' 2>/dev/null || echo "")
    if [ -n "$IMAGE_REPO" ]; then
        echo "    - Image: $IMAGE_REPO"
    fi
    
    # Check git subscription
    GIT_REPO=$(oc get warehouse demo-app -n kargo-lab -o jsonpath='{.spec.subscriptions[?(@.git)].git.repoURL}' 2>/dev/null || echo "")
    if [ -n "$GIT_REPO" ]; then
        echo "    - Git: $GIT_REPO"
    fi
fi
echo ""

# 4. Check if Freight has been discovered
echo -e "${BLUE}[4/4] Checking Freight Discovery${NC}"
FREIGHT_COUNT=$(oc get freight -n kargo-lab --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$FREIGHT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Freight discovered: $FREIGHT_COUNT item(s)"
    echo ""
    info "Freight list:"
    oc get freight -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
AGE:.metadata.creationTimestamp,\
WAREHOUSE:.origin.kind
    
    echo ""
    info "Latest Freight details:"
    LATEST_FREIGHT=$(oc get freight -n kargo-lab -o jsonpath='{.items[0].metadata.name}')
    
    # Show image info
    IMAGE_TAG=$(oc get freight $LATEST_FREIGHT -n kargo-lab -o jsonpath='{.images[0].tag}' 2>/dev/null || echo "N/A")
    if [ "$IMAGE_TAG" != "N/A" ]; then
        echo "  Image Tag: $IMAGE_TAG"
    fi
    
    # Show git commit
    GIT_COMMIT=$(oc get freight $LATEST_FREIGHT -n kargo-lab -o jsonpath='{.commits[0].id}' 2>/dev/null || echo "N/A")
    if [ "$GIT_COMMIT" != "N/A" ]; then
        echo "  Git Commit: ${GIT_COMMIT:0:8}"
    fi
else
    echo -e "${RED}✗${NC} No Freight discovered yet"
    echo ""
    warn "Freight discovery may take a few minutes."
    warn "You can:"
    warn "  1. Wait for automatic discovery (~5 minutes)"
    warn "  2. Trigger manual refresh in Kargo UI"
    warn "  3. Check Warehouse status: oc describe warehouse demo-app -n kargo-lab"
    ALL_CHECKS_PASSED=false
fi
echo ""

# Summary
echo "=== Verification Summary ==="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Lab 01 is complete. You have successfully:"
    echo "  ✓ Created a Kargo Project"
    echo "  ✓ Configured a Warehouse"
    echo "  ✓ Discovered Freight"
    echo ""
    echo "Next: Proceed to Lab 02 to create your first Stage"
    echo "  cd ../02-first-stage"
    echo "  cat README.md"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please review the errors above and:"
    echo "  1. Ensure all resources are applied correctly"
    echo "  2. Wait for Freight discovery if needed"
    echo "  3. Check Kargo controller logs if issues persist:"
    echo "     oc logs -n kargo -l app.kubernetes.io/component=controller --tail=50"
    exit 1
fi

