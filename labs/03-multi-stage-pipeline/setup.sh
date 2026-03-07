#!/bin/bash
# Lab 03 Setup Script
# This script automates the setup of Lab 03: Multi-stage Pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Lab 03: Multi-stage Pipeline Setup ===${NC}\n"

# Step 1: Check prerequisites
echo -e "${BLUE}[1/6] Checking prerequisites${NC}"

# Check if Lab 02 is complete
if ! oc get stage test -n kargo-lab &>/dev/null; then
    echo -e "${RED}✗ Lab 02 not complete. Please complete Lab 02 first.${NC}"
    exit 1
fi

# Check if test stage has been promoted
PROMOTION_COUNT=$(oc get promotions -n kargo-lab --no-headers 2>/dev/null | wc -l)
if [ "$PROMOTION_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No promotions found. Please complete Lab 02 first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Lab 02 prerequisites met${NC}\n"

# Step 2: Update Project with all stages
echo -e "${BLUE}[2/6] Updating Project configuration${NC}"

if oc apply -f labs/03-multi-stage-pipeline/project-updated.yaml; then
    echo -e "${GREEN}✓ Project updated with UAT and Prod stages${NC}\n"
else
    echo -e "${RED}✗ Failed to update Project${NC}"
    exit 1
fi

# Step 3: Create UAT ArgoCD Application
echo -e "${BLUE}[3/6] Creating UAT ArgoCD Application${NC}"

if oc apply -f labs/03-multi-stage-pipeline/argocd-app-uat.yaml; then
    echo -e "${GREEN}✓ UAT ArgoCD Application created${NC}\n"
else
    echo -e "${RED}✗ Failed to create UAT ArgoCD Application${NC}"
    exit 1
fi

# Step 4: Create UAT Stage
echo -e "${BLUE}[4/6] Creating UAT Stage${NC}"

if oc apply -f labs/03-multi-stage-pipeline/stage-uat.yaml; then
    echo -e "${GREEN}✓ UAT Stage created${NC}\n"
else
    echo -e "${RED}✗ Failed to create UAT Stage${NC}"
    exit 1
fi

# Step 5: Create Production ArgoCD Application
echo -e "${BLUE}[5/6] Creating Production ArgoCD Application${NC}"

if oc apply -f labs/03-multi-stage-pipeline/argocd-app-prod.yaml; then
    echo -e "${GREEN}✓ Production ArgoCD Application created${NC}\n"
else
    echo -e "${RED}✗ Failed to create Production ArgoCD Application${NC}"
    exit 1
fi

# Step 6: Create Production Stage
echo -e "${BLUE}[6/6] Creating Production Stage${NC}"

if oc apply -f labs/03-multi-stage-pipeline/stage-prod.yaml; then
    echo -e "${GREEN}✓ Production Stage created (manual promotion)${NC}\n"
else
    echo -e "${RED}✗ Failed to create Production Stage${NC}"
    exit 1
fi

# Summary
echo -e "${GREEN}=== Setup Complete! ===${NC}\n"

echo -e "${BLUE}Pipeline Structure:${NC}"
echo -e "  Warehouse (demo-app)"
echo -e "    ↓ (auto)"
echo -e "  Test Stage"
echo -e "    ↓ (auto)"
echo -e "  UAT Stage"
echo -e "    ↓ (manual)"
echo -e "  Production Stage\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Watch UAT auto-promotion:"
echo -e "   ${YELLOW}watch -n 2 'oc get promotions -n kargo-lab'${NC}\n"

echo -e "2. Check all stages:"
echo -e "   ${YELLOW}oc get stages -n kargo-lab${NC}\n"

echo -e "3. Manually promote to Production:"
echo -e "   ${YELLOW}bash scripts/promote.sh kargo-lab prod${NC}\n"

echo -e "4. Run verification:"
echo -e "   ${YELLOW}bash labs/03-multi-stage-pipeline/verify.sh${NC}\n"

echo -e "${BLUE}Monitoring UAT promotion...${NC}"
echo -e "This may take 30-60 seconds...\n"

# Wait and show UAT promotion status
for i in {1..30}; do
    UAT_PROMOTION=$(oc get promotions -n kargo-lab -l kargo.akuity.io/stage=uat --no-headers 2>/dev/null | head -1)
    if [ -n "$UAT_PROMOTION" ]; then
        PROMOTION_STATUS=$(echo "$UAT_PROMOTION" | awk '{print $3}')
        echo -e "${YELLOW}UAT Promotion status: $PROMOTION_STATUS${NC}"
        
        if [ "$PROMOTION_STATUS" = "Succeeded" ]; then
            echo -e "\n${GREEN}✓ UAT promotion completed successfully!${NC}"
            echo -e "${YELLOW}You can now manually promote to Production${NC}"
            break
        elif [ "$PROMOTION_STATUS" = "Failed" ]; then
            echo -e "\n${RED}✗ UAT promotion failed. Check logs for details.${NC}"
            break
        fi
    fi
    sleep 2
done

echo -e "\n${BLUE}Lab 03 setup complete!${NC}"
echo -e "${YELLOW}Remember: Production requires manual promotion for safety${NC}"

