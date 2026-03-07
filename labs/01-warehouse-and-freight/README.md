# Lab 01: Warehouse and Freight

## Learning Objectives

In this lab, you will learn:
- How to create a Kargo Project
- How to configure a Warehouse to discover artifacts
- How Kargo discovers and tracks Freight (deployable artifacts)
- How to subscribe to container images and Git repositories

## Prerequisites

- Infrastructure installed (ArgoCD, cert-manager, Kargo)
- Access to Kargo UI and CLI
- Basic understanding of Kubernetes resources

## Concepts

### Project
A Kargo Project is the top-level organizational unit. Creating a Project resource causes Kargo to automatically create a corresponding namespace with the same name. **Important**: The namespace must NOT already exist.

### Warehouse
A Warehouse defines what artifacts Kargo should track. It can subscribe to:
- Container image repositories (e.g., Docker Hub, Quay, ECR)
- Git repositories
- Helm chart repositories

### Freight
Freight represents a specific, immutable collection of artifacts that can be promoted through stages. When a Warehouse discovers new artifacts, Kargo automatically creates Freight resources.

## Lab Steps

### Step 1: Create the Kargo Project

Apply the Project resource:

```bash
oc apply -f labs/01-warehouse-and-freight/project.yaml
```

This will create:
- A Project resource named `kargo-lab`
- A namespace named `kargo-lab` (automatically created by Kargo)

Verify the Project:

```bash
# Check the Project resource
oc get project.kargo.akuity.io kargo-lab -n kargo-lab

# Check the namespace was created
oc get namespace kargo-lab

# View Project details
kargo get project kargo-lab
```

### Step 2: Create the Warehouse

Apply the Warehouse resource:

```bash
oc apply -f labs/01-warehouse-and-freight/warehouse.yaml
```

This Warehouse is configured to:
- Poll every 5 minutes for new artifacts
- Subscribe to the `nginx` image with constraint `1.25-alpine`
- Subscribe to the main branch of this Git repository

Verify the Warehouse:

```bash
# Check the Warehouse resource
oc get warehouse demo-app -n kargo-lab

# View Warehouse details
kargo get warehouse demo-app --project kargo-lab
```

### Step 3: Wait for Freight Discovery

Kargo will automatically discover artifacts based on the Warehouse subscriptions. This typically takes a few minutes.

You can:
1. **Wait for automatic discovery** (~5 minutes based on polling interval)
2. **Trigger manual refresh** via Kargo UI:
   - Navigate to the Kargo UI
   - Go to the `kargo-lab` project
   - Click on the Warehouse
   - Click "Refresh" to trigger immediate discovery

Check for Freight:

```bash
# List all Freight in the project
oc get freight -n kargo-lab

# View Freight details
kargo get freight --project kargo-lab

# Watch for new Freight (Ctrl+C to stop)
watch -n 5 'oc get freight -n kargo-lab'
```

### Step 4: Inspect Freight Details

Once Freight is discovered, examine its contents:

```bash
# Get detailed YAML of a Freight resource
FREIGHT_NAME=$(oc get freight -n kargo-lab -o jsonpath='{.items[0].metadata.name}')
oc get freight $FREIGHT_NAME -n kargo-lab -o yaml
```

You should see:
- **Image reference**: The nginx image with its digest
- **Git commit**: The latest commit from the main branch
- **Metadata**: Creation time, origin (Warehouse), etc.

### Step 5: Explore in Kargo UI

Access the Kargo UI and explore:

1. Navigate to the `kargo-lab` project
2. View the Warehouse and its configuration
3. See the discovered Freight
4. Examine the artifact details (image tags, commit SHAs)

## Verification

Run the verification script:

```bash
bash labs/01-warehouse-and-freight/verify.sh
```

Expected output:
- ✓ Project exists
- ✓ Warehouse exists
- ✓ Freight discovered (at least 1 item)

## What You Learned

- ✅ How to create a Kargo Project
- ✅ How to configure a Warehouse with image and Git subscriptions
- ✅ How Kargo automatically discovers and tracks Freight
- ✅ How to inspect Freight resources

## Troubleshooting

### No Freight discovered after 5 minutes

**Possible causes:**
1. Warehouse polling interval hasn't elapsed yet
2. Network issues preventing access to image registry or Git repository
3. Invalid subscription configuration

**Solutions:**
- Trigger manual refresh in Kargo UI
- Check Warehouse status: `oc describe warehouse demo-app -n kargo-lab`
- Check Kargo controller logs: `oc logs -n kargo -l app.kubernetes.io/component=controller`

### Project creation fails

**Error**: "namespace already exists"

**Solution**: Delete the existing namespace first:
```bash
oc delete namespace kargo-lab
# Wait for deletion to complete, then retry
oc apply -f labs/01-warehouse-and-freight/project.yaml
```

## Next Steps

Proceed to [Lab 02: First Stage](../02-first-stage/README.md) to learn how to:
- Create a Stage that consumes Freight
- Configure automatic promotion
- Integrate with ArgoCD for deployment

## Additional Resources

- [Kargo Projects Documentation](https://docs.kargo.io/concepts/projects/)
- [Kargo Warehouses Documentation](https://docs.kargo.io/concepts/warehouses/)
- [Kargo Freight Documentation](https://docs.kargo.io/concepts/freight/)