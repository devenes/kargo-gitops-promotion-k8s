# Kargo Lab GitOps Promotion Pipelines on OpenShift

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OpenShift](https://img.shields.io/badge/OpenShift-%3E%3D4.14-red)](https://www.openshift.com/)
[![Kargo](https://img.shields.io/badge/Kargo-v1.9.3-green)](https://kargo.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.13.3-blue)](https://argo-cd.readthedocs.io/)

Learn [Kargo](https://kargo.io/) by building — progressive delivery pipelines on OpenShift, from zero to multi-stage promotion in hands-on labs.

## 🎯 What You'll Learn

This repository provides a structured series of labs that teach every Kargo concept through working examples:

- **Lab 01**: Warehouse and Freight discovery
- **Lab 02**: First Stage with auto-promotion
- **Lab 03**: Multi-stage pipeline (test → uat → prod)
- **Lab 04**: PromotionTask for DRY promotion steps *(coming soon)*
- **Lab 05**: Verification with AnalysisTemplates *(coming soon)*
- **Lab 06**: Manual approval and soak time *(coming soon)*
- **Lab 07**: Multi-warehouse coordination *(coming soon)*
- **Lab 08**: PR-based promotion workflow *(coming soon)*
- **Lab 09**: Helm chart promotion *(coming soon)*

## 🏗️ Architecture

```
┌─────────────┐
│  Warehouse  │  ← Discovers container images and Git commits
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Freight   │  ← Immutable artifact collections
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: test │────▶│ ArgoCD: test     │
│ (auto)      │     │ Namespace: test  │
└──────┬──────┘     └──────────────────┘
       │
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: uat  │────▶│ ArgoCD: uat      │
│ (auto)      │     │ Namespace: uat   │
└──────┬──────┘     └──────────────────┘
       │
       ▼
┌─────────────┐     ┌──────────────────┐
│ Stage: prod │────▶│ ArgoCD: prod     │
│ (manual)    │     │ Namespace: prod  │
└─────────────┘     └──────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **OpenShift cluster** (>= 4.14) with cluster-admin access
- **oc CLI** installed and configured
- **Helm** (>= 3.13)
- **Git** (>= 2.0)
- **GitHub Personal Access Token** with `repo` scope

### Installation (20 minutes)

1. **Clone the repository**

```bash
git clone https://github.com/devenes/kargo-gitops-promotion-k8s.git
cd kargo-gitops-promotion-k8s
```

2. **Login to your OpenShift cluster**

```bash
oc login <your-cluster-url>
```

3. **Check prerequisites**

```bash
bash setup/prerequisites.sh
```

4. **Install infrastructure** (cert-manager, ArgoCD, Kargo)

```bash
bash setup/install.sh
```

This will:
- Install cert-manager v1.16.3
- Install ArgoCD v2.13.3
- Install Kargo v1.9.3
- Create OpenShift Routes for UIs
- Display access credentials

5. **Access the UIs**

After installation completes, you'll see:

```
=== ArgoCD Access ===
URL: https://argocd-server-argocd.apps.your-cluster.com
Username: admin
Password: <generated-password>

=== Kargo Access ===
URL: https://kargo-api-kargo.apps.your-cluster.com
Username: admin
Password: admin
```

6. **Start Lab 01**

```bash
cd labs/01-warehouse-and-freight
cat README.md
```

## 📚 Lab Structure

Each lab includes:
- **README.md**: Step-by-step instructions with explanations
- **YAML manifests**: Kargo and ArgoCD resources
- **verify.sh**: Automated verification script

### Lab Progression

```
Lab 01: Warehouse & Freight
    ↓
Lab 02: First Stage (auto-promotion)
    ↓
Lab 03: Multi-stage Pipeline (test → uat → prod)
    ↓
Labs 04-09: Advanced patterns (coming soon)
```

## 🛠️ Technology Stack

| Component        | Version     | Purpose                                      |
| ---------------- | ----------- | -------------------------------------------- |
| **Kargo**        | v1.9.3      | Progressive delivery and promotion pipelines |
| **ArgoCD**       | v2.13.3     | GitOps continuous delivery                   |
| **cert-manager** | v1.16.3     | Certificate management for Kargo webhooks    |
| **OpenShift**    | >= 4.14     | Kubernetes platform                          |
| **nginx**        | 1.25-alpine | Demo application                             |

All versions are pinned for reproducibility.

## 📖 Key Concepts

### Kargo Components

- **Project**: Top-level organizational unit, creates a namespace
- **Warehouse**: Defines what artifacts to track (images, Git repos, Helm charts)
- **Freight**: Immutable collection of artifacts ready for promotion
- **Stage**: Represents an environment (test, uat, prod)
- **Promotion**: The act of deploying Freight to a Stage

### Promotion Flow

1. **Warehouse** discovers new artifacts (images, commits)
2. **Freight** is created with artifact references
3. **Stage** receives Freight (auto or manual)
4. **Promotion steps** execute (git-clone, kustomize-set-image, git-push, etc.)
5. **ArgoCD** syncs the changes to the cluster

### Stage-specific Branches

Kargo uses Git branches per stage:
- `stage/test` - Test environment configuration
- `stage/uat` - UAT environment configuration  
- `stage/prod` - Production environment configuration

These branches are created and managed automatically by Kargo.

## 🔧 Development Workflow

This repository follows a **local-first workflow**:

```bash
# 1. Make changes locally
vim labs/01-warehouse-and-freight/warehouse.yaml

# 2. Apply to cluster
oc apply -f labs/01-warehouse-and-freight/warehouse.yaml

# 3. Verify
bash labs/01-warehouse-and-freight/verify.sh

# 4. Commit and push
git add .
git commit -m "feat: update warehouse configuration"
git push
```

**Important**: GitHub Actions only perform static validation (linting, syntax checks). All cluster operations must be executed locally.

## 📁 Repository Structure

```
kargo-gitops-promotion-k8s/
├── README.md                    # This file
├── LICENSE                      # Apache 2.0
├── .gitignore
├── setup/                       # Installation scripts
│   ├── install.sh              # One-command infrastructure setup
│   ├── uninstall.sh            # Clean teardown
│   ├── prerequisites.sh        # Tool verification
│   └── configure-git-credentials.sh
├── infrastructure/              # Infrastructure manifests
│   ├── argocd/                 # ArgoCD v2.13.3
│   ├── cert-manager/           # cert-manager v1.16.3
│   └── kargo/                  # Kargo v1.9.3
├── base/                        # Kustomize base manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── route.yaml
│   └── kustomization.yaml
├── stages/                      # Kustomize overlays per stage
│   ├── test/
│   ├── uat/
│   └── prod/
└── labs/                        # Hands-on labs
    ├── 01-warehouse-and-freight/
    ├── 02-first-stage/
    └── 03-multi-stage-pipeline/
```

## 🧪 Verification

Each lab includes a verification script:

```bash
# Verify a specific lab
bash labs/01-warehouse-and-freight/verify.sh

# Verify all labs (coming soon)
bash scripts/verify-all.sh
```

## 🐛 Troubleshooting

### Common Issues

**1. Namespace already exists**

```bash
# Kargo Project creates the namespace automatically
# If it exists, delete it first
oc delete namespace kargo-lab
oc apply -f labs/01-warehouse-and-freight/project.yaml
```

**2. Git credentials not working**

```bash
# Ensure the Secret has the required label
oc label secret git-credentials kargo.akuity.io/cred-type=git -n kargo-lab

# Verify
oc get secret git-credentials -n kargo-lab -o jsonpath='{.metadata.labels}'
```

**3. ArgoCD Application unauthorized**

```bash
# Ensure the Application has the authorization annotation
oc annotate application demo-app-test \
  kargo.akuity.io/authorized-stage=kargo-lab:test \
  -n argocd
```

**4. Promotion stuck or failed**

```bash
# Check promotion status
oc get promotions -n kargo-lab

# View promotion details
oc describe promotion <promotion-name> -n kargo-lab

# Check Kargo controller logs
oc logs -n kargo -l app.kubernetes.io/component=controller --tail=50
```

### Getting Help

- Check lab-specific README troubleshooting sections
- View Kargo logs: `oc logs -n kargo -l app.kubernetes.io/component=controller`
- View ArgoCD logs: `oc logs -n argocd -l app.kubernetes.io/name=argocd-server`
- [Kargo Documentation](https://docs.kargo.io/)
- [Kargo GitHub Issues](https://github.com/akuity/kargo/issues)

## 🧹 Cleanup

To remove all infrastructure and lab resources:

```bash
bash setup/uninstall.sh
```

This will:
- Remove all lab namespaces
- Uninstall Kargo
- Uninstall ArgoCD
- Uninstall cert-manager
- Optionally remove CRDs

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Kargo](https://kargo.io/) by Akuity for progressive delivery
- [ArgoCD](https://argo-cd.readthedocs.io/) for GitOps
- [OpenShift](https://www.openshift.com/) for the Kubernetes platform

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/devenes/kargo-gitops-promotion-k8s/issues)
- **Discussions**: [GitHub Discussions](https://github.com/devenes/kargo-gitops-promotion-k8s/discussions)

---

**Ready to learn Kargo?** Start with [Lab 01: Warehouse and Freight](labs/01-warehouse-and-freight/README.md)