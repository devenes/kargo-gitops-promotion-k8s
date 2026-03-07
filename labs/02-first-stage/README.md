# Lab 02: First Stage - Auto-promotion

## Learning Objectives

In this lab, you will learn:
- How to create a Kargo Stage
- How to configure inline promotion steps
- How to set up Git credentials for Kargo
- How to integrate Kargo with ArgoCD
- How automatic promotion works
- How stage-specific Git branches are created

## Prerequisites

- Lab 01 completed (Project and Warehouse created, Freight discovered)
- GitHub Personal Access Token with `repo` scope
- Basic understanding of GitOps and ArgoCD

## Concepts

### Stage
A Stage represents an environment in your delivery pipeline (e.g., test, uat, prod). It defines:
- What Freight it should receive
- How to promote that Freight (promotion steps)
- Whether promotion is automatic or manual

### Promotion Steps
Promotion steps are the actions Kargo takes to deploy Freight to a Stage. Common steps include:
- `git-clone`: Clone Git repositories
- `git-clear`: Clear directory contents
- `kustomize-set-image`: Update image tags in Kustomize
- `kustomize-build`: Build Kustomize manifests
- `git-commit`: Commit changes
- `git-push`: Push to a branch
- `argocd-update`: Trigger ArgoCD sync

### Stage-specific Branches
Kargo uses stage-specific branches (e.g., `stage/test`, `stage/uat`, `stage/prod`) to isolate each environment's configuration. These branches are created automatically during promotion.

### ArgoCD Integration
ArgoCD Applications must be authorized to be updated by Kargo using the annotation:
```yaml
kargo.akuity.io/authorized-stage: "<project>:<stage>"
```

## Lab Steps

### Step 1: Configure Git Credentials

Kargo needs Git credentials to push changes to your repository.

**Option A: Use the helper script (recommended)**

```bash
bash setup/configure-git-credentials.sh
```

Follow the prompts to enter:
- Repository URL (default: https://github.com/devenes/kargo-gitops-promotion-k8s)
- GitHub username
- GitHub Personal Access Token

**Option B: Manual creation**

Create a GitHub Personal Access Token:
1. Go to https://github.com/settings/tokens/new
2. Select scope: `repo` (Full control of private repositories)
3. Generate token and copy it

Create the Secret manually:

```bash
# Replace with your values
GITHUB_USERNAME="your-username"
GITHUB_TOKEN="your-token"
REPO_URL="https://github.com/devenes/kargo-gitops-promotion-k8s"

oc create secret generic git-credentials \
  --from-literal=repoURL="$REPO_URL" \
  --from-literal=username="$GITHUB_USERNAME" \
  --from-literal=password="$GITHUB_TOKEN" \
  -n kargo-lab

# Add the required label
oc label secret git-credentials \
  kargo.akuity.io/cred-type=git \
  -n kargo-lab
```

**Important**: The label `kargo.akuity.io/cred-type: git` is required!

Verify the Secret:

```bash
oc get secret git-credentials -n kargo-lab
oc get secret git-credentials -n kargo-lab -o jsonpath='{.metadata.labels}'
```

### Step 2: Create ArgoCD Application

The ArgoCD Application defines how to deploy to the test environment.

Apply the Application:

```bash
oc apply -f labs/02-first-stage/argocd-app-test.yaml
```

Key points:
- **Annotation**: `kargo.akuity.io/authorized-stage: kargo-lab:test` authorizes Kargo to update this Application
- **Source**: Points to `stage/test` branch (will be created by Kargo)
- **Path**: `stages/test` (our Kustomize overlay)
- **Sync Policy**: Automated with prune and self-heal

Verify the Application:

```bash
# Check Application exists
oc get application demo-app-test -n argocd

# View Application status
argocd app get demo-app-test

# Note: Application will be "OutOfSync" until stage/test branch is created
```

### Step 3: Create the Test Stage

The Stage defines how to promote Freight to the test environment.

Apply the Stage:

```bash
oc apply -f labs/02-first-stage/stage-test.yaml
```

This Stage is configured to:
- Request Freight directly from the `demo-app` Warehouse
- Use inline promotion steps to:
  1. Clone the repository (main and stage/test branches)
  2. Clear the output directory
  3. Update the image tag using Kustomize
  4. Build the Kustomize manifests
  5. Commit the changes
  6. Push to the `stage/test` branch
  7. Update the ArgoCD Application

Verify the Stage:

```bash
# Check Stage exists
oc get stage test -n kargo-lab

# View Stage details
kargo get stage test --project kargo-lab
```

### Step 4: Watch Auto-promotion

Since the Project has `autoPromotionEnabled: true` for the test stage, Kargo will automatically promote available Freight.

Watch the promotion process:

```bash
# Watch promotions
watch -n 5 'oc get promotions -n kargo-lab'

# Or use Kargo CLI
kargo get promotions --project kargo-lab --watch
```

You should see:
1. A Promotion resource created automatically
2. Promotion status progressing through steps
3. Promotion completing successfully

### Step 5: Verify Stage Branch Created

Check that Kargo created the `stage/test` branch:

```bash
# List remote branches
git ls-remote --heads https://github.com/devenes/kargo-gitops-promotion-k8s

# You should see: refs/heads/stage/test
```

You can also view the branch on GitHub:
- Navigate to your repository
- Click on the branch dropdown
- You should see `stage/test` branch

### Step 6: Verify ArgoCD Deployment

Check that ArgoCD deployed the application:

```bash
# Check Application sync status
argocd app get demo-app-test

# Check namespace created
oc get namespace kargo-lab-test

# Check pods running
oc get pods -n kargo-lab-test

# Check all resources
oc get all -n kargo-lab-test

# Get the Route URL
oc get route -n kargo-lab-test
```

Access the application:

```bash
# Get the URL
APP_URL=$(oc get route test-demo-app -n kargo-lab-test -o jsonpath='{.spec.host}')
echo "Application URL: https://$APP_URL"

# Test it
curl -I https://$APP_URL
```

### Step 7: Explore in Kargo UI

Access the Kargo UI and explore:

1. Navigate to the `kargo-lab` project
2. View the pipeline visualization
3. See the test Stage with promoted Freight
4. Click on the Stage to see promotion history
5. Examine the promotion steps and their logs

## Verification

Run the verification script:

```bash
bash labs/02-first-stage/verify.sh
```

Expected output:
- ✓ Stage exists
- ✓ ArgoCD Application exists
- ✓ stage/test branch created
- ✓ Namespace created
- ✓ Pods running
- ✓ Promotion completed

## What You Learned

- ✅ How to configure Git credentials for Kargo
- ✅ How to create a Stage with inline promotion steps
- ✅ How to integrate Kargo with ArgoCD
- ✅ How automatic promotion works
- ✅ How stage-specific branches are created and managed
- ✅ How to verify end-to-end deployment

## Troubleshooting

### Promotion fails with "unauthorized" error

**Cause**: ArgoCD Application missing authorization annotation

**Solution**: Ensure the Application has:
```yaml
annotations:
  kargo.akuity.io/authorized-stage: kargo-lab:test
```

### Promotion fails with Git authentication error

**Cause**: Missing or incorrect Git credentials

**Solution**:
1. Verify Secret exists: `oc get secret git-credentials -n kargo-lab`
2. Check label: `oc get secret git-credentials -n kargo-lab -o jsonpath='{.metadata.labels}'`
3. Verify credentials are correct
4. Recreate Secret if needed

### stage/test branch not created

**Cause**: Promotion hasn't completed or failed

**Solution**:
1. Check promotion status: `oc get promotions -n kargo-lab`
2. View promotion logs in Kargo UI
3. Check Kargo controller logs: `oc logs -n kargo -l app.kubernetes.io/component=controller`

### ArgoCD Application stuck in "OutOfSync"

**Cause**: stage/test branch doesn't exist yet or sync policy issue

**Solution**:
1. Wait for promotion to complete
2. Manually sync: `argocd app sync demo-app-test`
3. Check Application health: `argocd app get demo-app-test`

### Pods not running in kargo-lab-test

**Cause**: ArgoCD hasn't synced or deployment issue

**Solution**:
1. Check ArgoCD sync status
2. View pod events: `oc describe pods -n kargo-lab-test`
3. Check pod logs: `oc logs -n kargo-lab-test -l app=demo-app`

## Next Steps

Proceed to [Lab 03: Multi-stage Pipeline](../03-multi-stage-pipeline/README.md) to learn how to:
- Create multiple stages (test → uat → prod)
- Configure stage dependencies
- Implement manual approval gates for production

## Additional Resources

- [Kargo Stages Documentation](https://docs.kargo.io/concepts/stages/)
- [Kargo Promotion Steps Reference](https://docs.kargo.io/references/promotion-steps/)
- [ArgoCD Integration Guide](https://docs.kargo.io/integrations/argocd/)