#!/bin/bash
# Lab 02 Setup Script
# This script automates the setup of Lab 02: First Stage with Auto-promotion

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Lab 02: First Stage Setup ===${NC}\n"

# Step 1: Check prerequisites
echo -e "${BLUE}[1/5] Checking prerequisites${NC}"

# Check if Lab 01 is complete
if ! oc get warehouse demo-app -n kargo-lab &>/dev/null; then
    echo -e "${RED}✗ Lab 01 not complete. Please complete Lab 01 first.${NC}"
    exit 1
fi

if ! oc get freight -n kargo-lab &>/dev/null; then
    echo -e "${RED}✗ No Freight discovered. Please complete Lab 01 first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Lab 01 prerequisites met${NC}\n"

# Step 2: Check Git credentials
echo -e "${BLUE}[2/5] Checking Git credentials${NC}"

if ! oc get secret git-credentials -n kargo-lab &>/dev/null; then
    echo -e "${YELLOW}⚠ Git credentials not configured${NC}"
    echo -e "${YELLOW}Please run: bash setup/configure-git-credentials.sh${NC}"
    exit 1
fi

# Verify the secret has the required label
LABEL=$(oc get secret git-credentials -n kargo-lab -o jsonpath='{.metadata.labels.kargo\.akuity\.io/cred-type}' 2>/dev/null || echo "")
if [ "$LABEL" != "git" ]; then
    echo -e "${RED}✗ Git credentials secret missing required label${NC}"
    echo -e "${YELLOW}Please run: bash setup/configure-git-credentials.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Git credentials configured${NC}\n"

# Step 3: Update Warehouse with Git subscription
echo -e "${BLUE}[3/5] Updating Warehouse with Git subscription${NC}"

if oc apply -f labs/02-first-stage/warehouse-with-git.yaml; then
    echo -e "${GREEN}✓ Warehouse updated${NC}\n"
else
    echo -e "${RED}✗ Failed to update Warehouse${NC}"
    exit 1
fi

# Wait for Warehouse to reconcile
echo -e "${YELLOW}Waiting for Warehouse to reconcile...${NC}"
sleep 5

# Step 4: Create ArgoCD Application
echo -e "${BLUE}[4/5] Creating ArgoCD Application${NC}"

if oc apply -f labs/02-first-stage/argocd-app-test.yaml; then
    echo -e "${GREEN}✓ ArgoCD Application created${NC}\n"
else
    echo -e "${RED}✗ Failed to create ArgoCD Application${NC}"
    exit 1
fi

# Step 5: Create Stage
echo -e "${BLUE}[5/5] Creating Test Stage${NC}"

if oc apply -f labs/02-first-stage/stage-test.yaml; then
    echo -e "${GREEN}✓ Stage created${NC}\n"
else
    echo -e "${RED}✗ Failed to create Stage${NC}"
    exit 1
fi

# Summary
echo -e "${GREEN}=== Setup Complete! ===${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Watch auto-promotion:"
echo -e "   ${YELLOW}watch -n 2 'oc get promotions -n kargo-lab'${NC}\n"

echo -e "2. Check Stage status:"
echo -e "   ${YELLOW}oc get stage test -n kargo-lab${NC}\n"

echo -e "3. Verify deployment:"
echo -e "   ${YELLOW}oc get pods -n kargo-lab-test${NC}\n"

echo -e "4. Run verification:"
echo -e "   ${YELLOW}bash labs/02-first-stage/verify.sh${NC}\n"

echo -e "${BLUE}Monitoring promotion...${NC}"
echo -e "This may take 30-60 seconds...\n"

# Wait and show promotion status
for i in {1..30}; do
    PROMOTION_COUNT=$(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l)
    if [ "$PROMOTION_COUNT" -gt 0 ]; then
        PROMOTION_STATUS=$(oc get promotions -n kargo-lab -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
        echo -e "${YELLOW}Promotion status: $PROMOTION_STATUS${NC}"
        
        if [ "$PROMOTION_STATUS" = "Succeeded" ]; then
            echo -e "\n${GREEN}✓ Promotion completed successfully!${NC}"
            break
        elif [ "$PROMOTION_STATUS" = "Failed" ]; then
            echo -e "\n${RED}✗ Promotion failed. Check logs for details.${NC}"
            break
        fi
    fi
    sleep 2
done

echo -e "\n${BLUE}Lab 02 setup complete!${NC}"

