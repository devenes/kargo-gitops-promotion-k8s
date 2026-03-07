# Lab 03: Multi-stage Pipeline (test → uat → prod)

## Learning Objectives

In this lab, you will learn:
- How to create a multi-stage promotion pipeline
- How to configure stage dependencies
- How to implement manual approval gates for production
- How automatic promotion flows through stages
- How to manually promote to production

## Prerequisites

- Lab 01 and Lab 02 completed
- Test stage running successfully
- Understanding of Kargo promotion workflow

## Concepts

### Stage Dependencies
Stages can request Freight from upstream stages instead of directly from a Warehouse. This creates a promotion pipeline where Freight must pass through earlier stages before reaching later ones.

### Promotion Flow
In this lab, we'll create a three-stage pipeline:
```
Warehouse → test (auto) → uat (auto) → prod (manual)
```

- **test**: Receives Freight directly from Warehouse, auto-promotes
- **uat**: Receives Freight from test stage, auto-promotes
- **prod**: Receives Freight from uat stage, requires manual approval

### Manual Approval
Production deployments typically require human approval. By not enabling auto-promotion for the prod stage, we create a manual gate that requires explicit approval before deployment.

## Lab Steps

### Step 1: Update Project with UAT Auto-promotion

First, update the Project to enable auto-promotion for the UAT stage:

```bash
oc apply -f labs/03-multi-stage-pipeline/project-updated.yaml
```

This adds UAT to the auto-promotion policy while keeping production manual.

Verify the update:

```bash
oc get project.kargo.akuity.io kargo-lab -n kargo-lab -o yaml | grep -A 10 promotionPolicies
```

### Step 2: Create UAT ArgoCD Application

Apply the UAT Application:

```bash
oc apply -f labs/03-multi-stage-pipeline/argocd-app-uat.yaml
```

This Application:
- Points to the `stage/uat` branch
- Uses the `stages/uat` Kustomize overlay
- Is authorized for the `kargo-lab:uat` stage

Verify:

```bash
oc get application demo-app-uat -n argocd
argocd app get demo-app-uat
```

### Step 3: Create UAT Stage

Apply the UAT Stage:

```bash
oc apply -f labs/03-multi-stage-pipeline/stage-uat.yaml
```

Key differences from test stage:
- **requestedFreight**: Comes from `test` stage, not directly from Warehouse
- **Promotion steps**: Similar to test, but targets `stage/uat` branch

Verify:

```bash
oc get stage uat -n kargo-lab
kargo get stage uat --project kargo-lab
```

### Step 4: Watch Test → UAT Auto-promotion

Since UAT has auto-promotion enabled, Kargo will automatically promote Freight that has been verified in test:

```bash
# Watch promotions
watch -n 5 'oc get promotions -n kargo-lab'

# Or watch stages
watch -n 5 'oc get stages -n kargo-lab'
```

You should see:
1. UAT stage receives Freight from test
2. Promotion to UAT starts automatically
3. `stage/uat` branch is created
4. ArgoCD deploys to `kargo-lab-uat` namespace

### Step 5: Verify UAT Deployment

Check that UAT is running:

```bash
# Check namespace
oc get namespace kargo-lab-uat

# Check pods
oc get pods -n kargo-lab-uat

# Check ArgoCD sync status
argocd app get demo-app-uat

# Get UAT URL
oc get route -n kargo-lab-uat
UAT_URL=$(oc get route uat-demo-app -n kargo-lab-uat -o jsonpath='{.spec.host}')
echo "UAT URL: https://$UAT_URL"
curl -I https://$UAT_URL
```

### Step 6: Create Production ArgoCD Application

Apply the Production Application:

```bash
oc apply -f labs/03-multi-stage-pipeline/argocd-app-prod.yaml
```

Verify:

```bash
oc get application demo-app-prod -n argocd
argocd app get demo-app-prod
```

### Step 7: Create Production Stage

Apply the Production Stage:

```bash
oc apply -f labs/03-multi-stage-pipeline/stage-prod.yaml
```

Key points:
- **requestedFreight**: Comes from `uat` stage
- **No auto-promotion**: Production requires manual approval
- **Higher replica count**: Production runs 3 replicas (configured in Kustomize)

Verify:

```bash
oc get stage prod -n kargo-lab
kargo get stage prod --project kargo-lab
```

### Step 8: Observe Production Waiting for Approval

Production will NOT auto-promote. Check the stage status:

```bash
# View all stages
oc get stages -n kargo-lab

# Check prod stage details
oc describe stage prod -n kargo-lab

# View in Kargo UI
# You should see Freight available for prod but not promoted
```

### Step 9: Manually Promote to Production

**Option A: Using Kargo UI (Recommended)**

1. Access the Kargo UI
2. Navigate to the `kargo-lab` project
3. Click on the `prod` stage
4. Click on the available Freight
5. Click "Promote" button
6. Confirm the promotion

**Option B: Using Kargo CLI**

```bash
# List available Freight for prod
kargo get freight --project kargo-lab --stage prod

# Get the Freight name
FREIGHT_NAME=$(kargo get freight --project kargo-lab --stage prod -o json | jq -r '.[0].metadata.name')

# Promote to production
kargo promote --project kargo-lab --stage prod --freight $FREIGHT_NAME
```

**Option C: Using kubectl**

```bash
# Create a Promotion resource manually
cat <<EOF | oc apply -f -
apiVersion: kargo.akuity.io/v1alpha1
kind: Promotion
metadata:
  name: prod-$(date +%s)
  namespace: kargo-lab
spec:
  stage: prod
  freight: $(oc get stage uat -n kargo-lab -o jsonpath='{.status.currentFreight.name}')
EOF
```

### Step 10: Watch Production Deployment

Monitor the production promotion:

```bash
# Watch promotions
watch -n 5 'oc get promotions -n kargo-lab'

# Watch production pods
watch -n 5 'oc get pods -n kargo-lab-prod'
```

### Step 11: Verify Production Deployment

Check that production is running:

```bash
# Check namespace
oc get namespace kargo-lab-prod

# Check pods (should be 3 replicas)
oc get pods -n kargo-lab-prod

# Check ArgoCD sync status
argocd app get demo-app-prod

# Get production URL
oc get route -n kargo-lab-prod
PROD_URL=$(oc get route prod-demo-app -n kargo-lab-prod -o jsonpath='{.spec.host}')
echo "Production URL: https://$PROD_URL"
curl -I https://$PROD_URL
```

### Step 12: View Complete Pipeline

View the entire pipeline in Kargo UI:

1. Navigate to the `kargo-lab` project
2. See the visual pipeline: Warehouse → test → uat → prod
3. Observe Freight flowing through stages
4. Check promotion history for each stage

Or use CLI:

```bash
# View all stages
kargo get stages --project kargo-lab

# View all promotions
kargo get promotions --project kargo-lab

# View Freight status
kargo get freight --project kargo-lab
```

## Verification

Run the verification script:

```bash
bash labs/03-multi-stage-pipeline/verify.sh
```

Expected output:
- ✓ All three stages exist (test, uat, prod)
- ✓ All three ArgoCD Applications exist
- ✓ All three stage branches created
- ✓ All three namespaces exist
- ✓ Pods running in all environments
- ✓ Promotions completed for all stages

## What You Learned

- ✅ How to create a multi-stage promotion pipeline
- ✅ How to configure stage dependencies (upstream stages)
- ✅ How automatic promotion flows through stages
- ✅ How to implement manual approval gates
- ✅ How to manually promote to production
- ✅ How to verify deployments across multiple environments

## Architecture

```
┌─────────────┐
│  Warehouse  │
│  (demo-app) │
└──────┬──────┘
       │ discovers
       ▼
┌─────────────┐
│   Freight   │
└──────┬──────┘
       │ auto-promotes
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: test │────▶│ ArgoCD: test     │
│ (auto)      │     │ Namespace: test  │
└──────┬──────┘     └──────────────────┘
       │ auto-promotes
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: uat  │────▶│ ArgoCD: uat      │
│ (auto)      │     │ Namespace: uat   │
└──────┬──────┘     └──────────────────┘
       │ manual approval required
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: prod │────▶│ ArgoCD: prod     │
│ (manual)    │     │ Namespace: prod  │
└─────────────┘     └──────────────────┘
```

## Troubleshooting

### UAT not auto-promoting

**Cause**: Project not updated with UAT auto-promotion policy

**Solution**:
```bash
oc apply -f labs/03-multi-stage-pipeline/project-updated.yaml
oc get project.kargo.akuity.io kargo-lab -n kargo-lab -o yaml | grep -A 10 promotionPolicies
```

### Production promoted automatically

**Cause**: Project has auto-promotion enabled for prod (should not)

**Solution**: Ensure Project does NOT have prod in promotionPolicies

### Stage branch not created

**Cause**: Promotion failed or still in progress

**Solution**:
```bash
oc get promotions -n kargo-lab
oc describe promotion <promotion-name> -n kargo-lab
```

### Pods not running in a namespace

**Cause**: ArgoCD not synced or deployment issue

**Solution**:
```bash
argocd app get demo-app-<stage>
argocd app sync demo-app-<stage>
oc describe pods -n kargo-lab-<stage>
```

## Next Steps

You now have a complete multi-stage pipeline! Next labs will cover:

- **Lab 04**: PromotionTask - DRY up promotion steps
- **Lab 05**: Verification with AnalysisTemplates
- **Lab 06**: Manual approval and soak time
- **Lab 07**: Multi-warehouse coordination
- **Lab 08**: PR-based promotion workflow
- **Lab 09**: Helm chart promotion

## Additional Resources

- [Kargo Stage Dependencies](https://docs.kargo.io/concepts/stages/#stage-dependencies)
- [Promotion Policies](https://docs.kargo.io/concepts/projects/#promotion-policies)
- [Manual Promotions](https://docs.kargo.io/how-to/manual-promotions/)