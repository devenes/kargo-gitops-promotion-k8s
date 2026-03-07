#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Kargo Manual Promotion Helper ===${NC}"
echo ""

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <stage-name> [freight-name]"
    echo ""
    echo "Examples:"
    echo "  $0 prod                    # Promote latest Freight to prod"
    echo "  $0 prod abc123def456       # Promote specific Freight to prod"
    echo ""
    echo "Available stages:"
    oc get stages -n kargo-lab -o custom-columns=NAME:.metadata.name,CURRENT_FREIGHT:.status.currentFreight.name 2>/dev/null || echo "  No stages found"
    exit 1
fi

STAGE=$1
FREIGHT=$2

# Check if stage exists
if ! oc get stage "$STAGE" -n kargo-lab &> /dev/null; then
    echo -e "${RED}✗ Stage '$STAGE' not found${NC}"
    echo ""
    echo "Available stages:"
    oc get stages -n kargo-lab -o custom-columns=NAME:.metadata.name 2>/dev/null
    exit 1
fi

# If no freight specified, get the latest available for this stage
if [ -z "$FREIGHT" ]; then
    echo "Finding latest Freight available for stage '$STAGE'..."
    
    # Get the upstream stage for this stage
    UPSTREAM_STAGE=$(oc get stage "$STAGE" -n kargo-lab -o jsonpath='{.spec.requestedFreight[0].sources.stages[0]}' 2>/dev/null || echo "")
    
    if [ -n "$UPSTREAM_STAGE" ]; then
        # Get Freight from upstream stage
        FREIGHT=$(oc get stage "$UPSTREAM_STAGE" -n kargo-lab -o jsonpath='{.status.currentFreight.name}' 2>/dev/null || echo "")
        if [ -z "$FREIGHT" ]; then
            echo -e "${RED}✗ No Freight available from upstream stage '$UPSTREAM_STAGE'${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} Found Freight from upstream stage '$UPSTREAM_STAGE': $FREIGHT"
    else
        # Get latest Freight from Warehouse
        FREIGHT=$(oc get freight -n kargo-lab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -z "$FREIGHT" ]; then
            echo -e "${RED}✗ No Freight available${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} Found latest Freight: $FREIGHT"
    fi
fi

# Verify Freight exists
if ! oc get freight "$FREIGHT" -n kargo-lab &> /dev/null; then
    echo -e "${RED}✗ Freight '$FREIGHT' not found${NC}"
    echo ""
    echo "Available Freight:"
    oc get freight -n kargo-lab -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp 2>/dev/null
    exit 1
fi

# Show Freight details
echo ""
echo -e "${BLUE}Freight Details:${NC}"
IMAGE_TAG=$(oc get freight "$FREIGHT" -n kargo-lab -o jsonpath='{.images[0].tag}' 2>/dev/null || echo "N/A")
GIT_COMMIT=$(oc get freight "$FREIGHT" -n kargo-lab -o jsonpath='{.commits[0].id}' 2>/dev/null || echo "N/A")
echo "  Name: $FREIGHT"
echo "  Image Tag: $IMAGE_TAG"
echo "  Git Commit: ${GIT_COMMIT:0:8}"

# Show current stage status
echo ""
echo -e "${BLUE}Stage Status:${NC}"
CURRENT_FREIGHT=$(oc get stage "$STAGE" -n kargo-lab -o jsonpath='{.status.currentFreight.name}' 2>/dev/null || echo "None")
echo "  Stage: $STAGE"
echo "  Current Freight: $CURRENT_FREIGHT"

if [ "$CURRENT_FREIGHT" = "$FREIGHT" ]; then
    echo -e "${YELLOW}⚠${NC} This Freight is already deployed to this stage"
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Confirm promotion
echo ""
echo -e "${YELLOW}Ready to promote:${NC}"
echo "  Freight: $FREIGHT"
echo "  To Stage: $STAGE"
echo ""
read -p "Proceed with promotion? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Promotion cancelled."
    exit 0
fi

# Create Promotion resource
PROMOTION_NAME="${STAGE}-$(date +%s)"

echo "Creating Promotion: $PROMOTION_NAME"
cat <<EOF | oc apply -f -
apiVersion: kargo.akuity.io/v1alpha1
kind: Promotion
metadata:
  name: $PROMOTION_NAME
  namespace: kargo-lab
spec:
  stage: $STAGE
  freight: $FREIGHT
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Promotion created successfully!${NC}"
    echo ""
    echo "Monitor promotion progress:"
    echo "  oc get promotion $PROMOTION_NAME -n kargo-lab -w"
    echo ""
    echo "Or use Kargo CLI:"
    echo "  kargo get promotion $PROMOTION_NAME --project kargo-lab"
    echo ""
    echo "View in Kargo UI:"
    KARGO_URL=$(oc get route kargo-api -n kargo -o jsonpath='{.spec.host}' 2>/dev/null || echo "kargo-ui")
    echo "  https://$KARGO_URL"
else
    echo ""
    echo -e "${RED}✗ Failed to create Promotion${NC}"
    exit 1
fi

