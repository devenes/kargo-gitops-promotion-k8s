#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Kargo Freight Status ===${NC}"
echo ""

# Check if kargo-lab project exists
if ! oc get namespace kargo-lab &> /dev/null; then
    echo -e "${RED}✗ Project 'kargo-lab' not found${NC}"
    echo "Run Lab 01 first: cd labs/01-warehouse-and-freight"
    exit 1
fi

# 1. Warehouse Status
echo -e "${BLUE}[1/4] Warehouse Status${NC}"
if oc get warehouse demo-app -n kargo-lab &> /dev/null; then
    echo -e "${GREEN}✓${NC} Warehouse: demo-app"
    
    # Get last refresh time
    LAST_REFRESH=$(oc get warehouse demo-app -n kargo-lab -o jsonpath='{.status.lastHandledRefresh}' 2>/dev/null || echo "N/A")
    echo "  Last refresh: $LAST_REFRESH"
    
    # Get discovered freight count
    FREIGHT_COUNT=$(oc get freight -n kargo-lab --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "  Discovered Freight: $FREIGHT_COUNT"
else
    echo -e "${RED}✗${NC} Warehouse not found"
fi
echo ""

# 2. Freight List
echo -e "${BLUE}[2/4] Available Freight${NC}"
if [ "$(oc get freight -n kargo-lab --no-headers 2>/dev/null | wc -l)" -gt 0 ]; then
    oc get freight -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
ORIGIN:.origin.kind,\
IMAGE_TAG:.images[0].tag,\
GIT_COMMIT:.commits[0].id,\
AGE:.metadata.creationTimestamp 2>/dev/null | head -10
else
    echo "  No Freight discovered yet"
fi
echo ""

# 3. Stage Status
echo -e "${BLUE}[3/4] Stage Status${NC}"
STAGES=$(oc get stages -n kargo-lab -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "$STAGES" ]; then
    for stage in $STAGES; do
        CURRENT_FREIGHT=$(oc get stage "$stage" -n kargo-lab -o jsonpath='{.status.currentFreight.name}' 2>/dev/null || echo "None")
        HEALTH=$(oc get stage "$stage" -n kargo-lab -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        if [ "$CURRENT_FREIGHT" != "None" ]; then
            echo -e "${GREEN}✓${NC} Stage: $stage"
            echo "  Current Freight: $CURRENT_FREIGHT"
            echo "  Health: $HEALTH"
        else
            echo -e "${YELLOW}⚠${NC} Stage: $stage"
            echo "  Current Freight: None (waiting for promotion)"
            echo "  Health: $HEALTH"
        fi
    done
else
    echo "  No stages found"
fi
echo ""

# 4. Recent Promotions
echo -e "${BLUE}[4/4] Recent Promotions${NC}"
PROMOTION_COUNT=$(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$PROMOTION_COUNT" -gt 0 ]; then
    echo "Total promotions: $PROMOTION_COUNT"
    echo ""
    oc get promotions -n kargo-lab -o custom-columns=\
NAME:.metadata.name,\
STAGE:.spec.stage,\
FREIGHT:.spec.freight,\
PHASE:.status.phase,\
AGE:.metadata.creationTimestamp 2>/dev/null | head -10

    # Count by phase
    echo ""
    SUCCEEDED=$(oc get promotions -n kargo-lab -o jsonpath='{.items[?(@.status.phase=="Succeeded")].metadata.name}' 2>/dev/null | wc -w)
    RUNNING=$(oc get promotions -n kargo-lab -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | wc -w)
    FAILED=$(oc get promotions -n kargo-lab -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null | wc -w)

    echo "Summary:"
    echo "  Succeeded: $SUCCEEDED"
    echo "  Running: $RUNNING"
    echo "  Failed: $FAILED"
else
    echo "  No promotions yet"
fi
echo ""

# Summary
echo -e "${CYAN}=== Summary ===${NC}"
echo "Warehouse: $(oc get warehouse -n kargo-lab --no-headers 2>/dev/null | wc -l) found"
echo "Freight: $(oc get freight -n kargo-lab --no-headers 2>/dev/null | wc -l) discovered"
echo "Stages: $(oc get stages -n kargo-lab --no-headers 2>/dev/null | wc -l) configured"
echo "Promotions: $(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l) executed"
echo ""
echo "For detailed view, use:"
echo "  kargo get freight --project kargo-lab"
echo "  kargo get stages --project kargo-lab"
echo "  kargo get promotions --project kargo-lab"
