# Unified Platform Implementation Plan
## Formula Marketplace with OIDC Pre-provisioning

**Status**: Final Implementation Guide
**Architecture**: Backstage + Hybrid OIDC Pre-provisioning
**UI System**: Backstage UI (BUI) with CSS theming
**GitOps**: Mono-repo with formula bundles
**Timeline**: 9 weeks with 2-3 engineers

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────┐
│  Logto/Keycloak (OIDC Provider)                        │
│  - User registration                                    │
│  - Organization management                              │
│  - Webhook on user creation                            │
└─────────────────────────────────────────────────────────┘
                      ↓ Webhook
┌─────────────────────────────────────────────────────────┐
│  Backstage (Control Plane)                             │
│  - Pre-provisioning service (webhook handler)          │
│  - Software Catalog (formula marketplace)              │
│  - Software Templates (self-service provisioning)      │
│  - Custom scaffolder actions                           │
└─────────────────────────────────────────────────────────┘
                      ↓ API calls
┌────────────┬──────────┬────────────┬───────────────────┐
│   Coder    │  Gitea   │ Mattermost │  Twenty CRM       │
│ (Workspaces│  (Git)   │  (Chat)    │  (CRM)           │
└────────────┴──────────┴────────────┴───────────────────┘
```

### Key Design Decisions

1. **OIDC Strategy**: Hybrid pre-provisioning
   - Pre-create users via admin APIs with OIDC-compatible claims
   - Services auto-link on first OIDC login

2. **UI System**: Backstage UI (BUI) with CSS variables
   - CSS-first theming (not Material-UI)
   - shadcn-inspired color palette

3. **Formula Marketplace**: Backstage Software Templates
   - Each formula = bundled configuration (Backstage template + Coder template + Claude config)
   - Self-service provisioning

4. **GitOps**: Single mono-repo
   - Formula bundles versioned together
   - CI/CD pushes Coder templates, pulls Backstage templates

---

## User Workflow: New Organization Sign-up

### Step 1: User Registration (Logto/Keycloak)

```
User → Logto Sign-up Form
  ↓
User submits: email, name, organization
  ↓
Logto creates OIDC identity
  ↓
Logto webhook → POST to Backstage pre-provisioning endpoint
```

**Webhook Payload**:
```json
{
  "event": "user.created",
  "user": {
    "id": "usr_abc123",
    "email": "alice@acme.com",
    "name": "Alice Chen",
    "organization": "acme-corp"
  }
}
```

### Step 2: Backstage Pre-provisioning (Webhook Handler)

Backstage receives webhook and pre-provisions accounts across all services:

**Backend Service**: `packages/backend/src/modules/pre-provisioning.ts`

```typescript
export async function handleUserCreation(req: Request) {
  const { user } = req.body;

  // 1. Create Backstage user entity
  await catalogClient.addEntity({
    apiVersion: 'backstage.io/v1alpha1',
    kind: 'User',
    metadata: {
      name: user.email.split('@')[0],
      annotations: {
        'logto.io/user-id': user.id,
      },
    },
    spec: {
      profile: {
        displayName: user.name,
        email: user.email,
      },
      memberOf: [`group:${user.organization}`],
    },
  });

  // 2. Pre-create Coder user (OIDC-compatible)
  await coderClient.post('/api/v2/users', {
    username: user.email.split('@')[0],
    email: user.email,
    login_type: 'oidc', // ← Marks for OIDC linking
  });

  // 3. Pre-create Gitea user (OIDC-compatible)
  await giteaClient.post('/api/v1/admin/users', {
    username: user.email.split('@')[0],
    email: user.email,
    login_source: 'oauth2', // ← Links to OIDC provider
    login_name: user.email,
    must_change_password: false,
  });

  // 4. Pre-create Mattermost user
  await mattermostClient.post('/api/v4/users', {
    username: user.email.split('@')[0],
    email: user.email,
    auth_service: 'oidc', // ← Links to OIDC
    auth_data: user.email,
  });

  // 5. Create Twenty CRM person
  await twentyClient.graphql(`
    mutation {
      createPerson(data: {
        name: { firstName: "Alice", lastName: "Chen" }
        email: "${user.email}"
        company: { connect: { name: "acme-corp" } }
      }) {
        id
      }
    }
  `);

  return { success: true };
}
```

### Step 3: User Redirects to Backstage

After Logto sign-up completes:

```
Logto redirects → https://backstage.acme.com/
  ↓
Backstage OIDC sign-in resolver
  ↓
Links OIDC identity to pre-provisioned Backstage user
  ↓
User lands on Backstage homepage
```

**OIDC Sign-in Resolver**: `packages/backend/src/modules/auth-keycloak.ts`

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import { authProvidersExtensionPoint } from '@backstage/plugin-auth-node';

export const authModuleKeycloakProvider = createBackendModule({
  pluginId: 'auth',
  moduleId: 'keycloak-provider',
  register(reg) {
    reg.registerInit({
      deps: { providers: authProvidersExtensionPoint },
      async init({ providers }) {
        providers.registerProvider({
          providerId: 'keycloak',
          factory: ({ config }) => ({
            async signInResolver({ profile }, ctx) {
              // Find pre-provisioned user by email
              const username = profile.email.split('@')[0];

              return ctx.issueToken({
                claims: {
                  sub: username,
                  ent: [`user:default/${username}`],
                },
              });
            },
          }),
        });
      },
    });
  },
});
```

### Step 4: User Sees Formula Marketplace

User lands on Backstage catalog page with formula templates:

```
https://backstage.acme.com/catalog?filters[kind]=template
```

**Available Formulas**:
- 🧪 ML Research Workspace (PyTorch, Jupyter, H100 GPU)
- 💻 Full-Stack Development (Node.js, React, PostgreSQL)
- 📊 Data Analysis (Python, Pandas, Spark)
- ☁️ Cloud Infrastructure (Terraform, Kubernetes, ArgoCD)

### Step 5: User Provisions Workspace

User clicks "ML Research Workspace" → Form appears:

**Template Parameters**:
- Workspace name: `alice-ml-research`
- GPU type: `h100` / `a100` / `none`
- Python version: `3.11` / `3.10`
- Git repository: Auto-create in Gitea
- Enable GitHub OAuth: Yes/No

User submits → Backstage scaffolder executes:

```yaml
# Executed by Backstage scaffolder
steps:
  # 1. Create Gitea repository
  - id: gitea-repo
    action: publish:gitea
    input:
      repoUrl: gitea.acme.com?owner=alice&repo=ml-research
      defaultBranch: main

  # 2. Create Coder workspace
  - id: coder-workspace
    action: coder:create-workspace
    input:
      user: alice
      template: ml-research-v2  # ← Pre-deployed Coder template
      name: alice-ml-research
      parameters:
        git_repo_url: ${{ steps['gitea-repo'].output.remoteUrl }}
        gpu_type: h100
        python_version: "3.11"

  # 3. Add to Mattermost team
  - id: mattermost-team
    action: mattermost:add-to-team
    input:
      username: alice
      team: ml-research-team
      channels: ['general', 'support']

  # 4. Create Twenty CRM project
  - id: twenty-project
    action: twenty:create-opportunity
    input:
      name: "ML Research - Alice"
      person: alice@acme.com
      stage: active

  # 5. GitHub OAuth (optional)
  - id: github-oauth
    if: ${{ parameters.enable_github }}
    action: http:backstage:request
    input:
      method: GET
      path: /api/proxy/github/login/oauth/authorize
```

### Step 6: Workspace Ready

User sees success page with links:

```
✅ Workspace provisioned successfully!

📦 Resources Created:
- Coder Workspace: https://coder.acme.com/@alice/ml-research
- Gitea Repository: https://gitea.acme.com/alice/ml-research
- Mattermost Team: #ml-research-team
- CRM Opportunity: ML Research - Alice

🚀 Next Steps:
[Open Workspace] [View Repository] [Join Chat]
```

---

## GitOps Repository Structure

### Mono-repo: `platform-formulas`

```
platform-formulas/
├── formulas/
│   ├── ml-research/
│   │   ├── backstage-template.yaml          # Backstage Software Template
│   │   ├── coder-template/                  # Coder Terraform template
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── .claude/                     # Embedded Claude Code config
│   │   │   │   ├── settings.json
│   │   │   │   ├── skills/
│   │   │   │   │   └── ml-debugging/SKILL.md
│   │   │   │   └── agents/
│   │   │   │       └── experiment/agent.md
│   │   │   └── .mcp.json                    # MCP servers config
│   │   └── README.md
│   │
│   ├── fullstack-dev/
│   │   ├── backstage-template.yaml
│   │   ├── coder-template/
│   │   │   ├── main.tf
│   │   │   └── .claude/
│   │   │       ├── settings.json
│   │   │       └── skills/
│   │   │           ├── code-review/SKILL.md
│   │   │           └── testing/SKILL.md
│   │   └── README.md
│   │
│   └── data-analysis/
│       └── [same structure]
│
├── enterprise/
│   └── claude-code/
│       ├── managed-settings.json            # Global enterprise settings
│       ├── managed-mcp.json                 # Global MCP servers
│       └── k8s/
│           └── configmap.yaml               # K8s ConfigMap for deployment
│
├── backstage/
│   ├── app-config.yaml                      # Backstage configuration
│   ├── app-config.production.yaml
│   ├── packages/
│   │   └── app/
│   │       └── src/
│   │           ├── App.tsx
│   │           └── theme/
│   │               └── custom-theme.css     # BUI CSS theme
│   └── plugins/
│       ├── scaffolder-backend-coder/        # Custom Coder action
│       ├── scaffolder-backend-mattermost/   # Custom Mattermost action
│       └── scaffolder-backend-twenty/       # Custom Twenty action
│
└── .github/
    └── workflows/
        ├── deploy-formula.yml               # Formula deployment pipeline
        ├── deploy-backstage.yml             # Backstage deployment
        └── deploy-claude-enterprise.yml     # Claude enterprise config
```

### Why Mono-repo?

**Tight Coupling**:
- Backstage template references Coder template by name
- Coder template embeds Claude Code configuration
- Version synchronization: Formula v2.0 → all components at v2.0

**Atomic Deployments**:
- Single commit updates all components
- No version drift between layers

**Simplified CI/CD**:
- One pipeline orchestrates deployment order
- Easy to test formula as a bundle

---

## Backstage UI Customization (BUI)

### CSS-First Theming

**File**: `backstage/packages/app/src/theme/custom-theme.css`

```css
/* Import BUI base styles */
@import '@backstage/ui/css/styles.css';

/* shadcn-inspired color palette */
:root {
  /* Background */
  --bui-bg: hsl(0 0% 100%);
  --bui-bg-muted: hsl(210 40% 96.1%);

  /* Foreground */
  --bui-fg-primary: hsl(222.2 84% 4.9%);
  --bui-fg-secondary: hsl(215.4 16.3% 46.9%);
  --bui-fg-tertiary: hsl(215.4 16.3% 56.9%);

  /* Primary color (brand) */
  --bui-primary: hsl(222.2 47.4% 11.2%);
  --bui-primary-fg: hsl(210 40% 98%);

  /* Border */
  --bui-border: hsl(214.3 31.8% 91.4%);
  --bui-border-hover: hsl(215.4 16.3% 46.9%);

  /* Radius */
  --bui-radius: 0.5rem;
  --bui-radius-sm: 0.375rem;
  --bui-radius-lg: 0.75rem;

  /* Destructive */
  --bui-destructive: hsl(0 84.2% 60.2%);
  --bui-destructive-fg: hsl(210 40% 98%);

  /* Success */
  --bui-success: hsl(142.1 76.2% 36.3%);

  /* Warning */
  --bui-warning: hsl(38 92% 50%);

  /* Typography */
  --bui-font-family: 'Inter', -apple-system, system-ui, sans-serif;
  --bui-font-family-mono: 'JetBrains Mono', ui-monospace, monospace;
}

/* Dark mode */
[data-theme-mode='dark'] {
  --bui-bg: hsl(222.2 84% 4.9%);
  --bui-bg-muted: hsl(217.2 32.6% 17.5%);

  --bui-fg-primary: hsl(210 40% 98%);
  --bui-fg-secondary: hsl(215 20.2% 65.1%);

  --bui-primary: hsl(210 40% 98%);
  --bui-primary-fg: hsl(222.2 47.4% 11.2%);

  --bui-border: hsl(217.2 32.6% 17.5%);
  --bui-border-hover: hsl(215 20.2% 65.1%);
}

/* Component customizations */
.bui-Button {
  font-weight: 500;
  text-transform: none;
}

.bui-Card {
  box-shadow: none;
  border: 1px solid var(--bui-border);
}

.bui-Table {
  border-collapse: separate;
  border-spacing: 0;
}
```

**Integration**: `backstage/packages/app/src/App.tsx`

```tsx
import React from 'react';
import { createApp } from '@backstage/app-defaults';
import { AppRouter, FlatRoutes } from '@backstage/core-app-api';

// Import custom BUI theme
import './theme/custom-theme.css';

const app = createApp({
  // ... app config
});

export default app.createRoot(
  <AppRouter>
    <FlatRoutes>
      {/* routes */}
    </FlatRoutes>
  </AppRouter>
);
```

**Install Fonts**: `backstage/packages/app/public/index.html`

```html
<head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link
    href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap"
    rel="stylesheet"
  />
</head>
```

---

## Coder Template Registry Integration

### Coder Template Structure

**File**: `formulas/ml-research/coder-template/main.tf`

```hcl
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# Use Coder registry modules
module "code-server" {
  source  = "registry.coder.com/modules/code-server/coder"
  version = "1.0.19"

  agent_id = coder_agent.main.id
  extensions = [
    "ms-python.python",
    "ms-toolsai.jupyter",
  ]
}

module "git-clone" {
  source  = "registry.coder.com/modules/git-clone/coder"
  version = "1.0.15"

  agent_id = coder_agent.main.id
  url      = var.git_repo_url
}

# Workspace resources
resource "kubernetes_pod" "workspace" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.namespace
  }

  spec {
    container {
      name  = "dev"
      image = "ghcr.io/acme/ml-research:latest"

      # Mount Claude Code enterprise config
      volume_mount {
        name       = "claude-enterprise-config"
        mount_path = "/etc/claude-code"
        read_only  = true
      }

      resources {
        requests = {
          "nvidia.com/gpu" = var.gpu_type == "none" ? 0 : 1
        }
      }
    }

    # ConfigMap with enterprise Claude Code settings
    volume {
      name = "claude-enterprise-config"
      config_map {
        name = "claude-code-enterprise-config"
      }
    }
  }
}

# Coder agent
resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  # Claude Code project-specific settings
  startup_script = <<-EOT
    #!/bin/bash

    # Copy Claude Code project config
    mkdir -p ~/.claude
    cp -r /template/.claude/* ~/.claude/

    # Install dependencies
    pip install -r requirements.txt
  EOT
}

# Variables
variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "gpu_type" {
  description = "GPU type (h100, a100, none)"
  type        = string
  default     = "none"
}

variable "python_version" {
  description = "Python version"
  type        = string
  default     = "3.11"
}
```

### Claude Code Configuration in Template

**File**: `formulas/ml-research/coder-template/.claude/settings.json`

```json
{
  "version": "1.0.0",
  "skills": {
    "autoLoad": ["ml-debugging", "experiment-tracking"]
  },
  "agents": {
    "experiment": {
      "enabled": true,
      "triggerPatterns": ["experiment", "training", "model"]
    }
  },
  "hooks": {
    "onStartup": {
      "command": "python scripts/setup_environment.py"
    }
  },
  "security": {
    "allowedCommands": ["python", "pip", "jupyter", "tensorboard"],
    "denyListPaths": [".env", "secrets/"]
  }
}
```

**File**: `formulas/ml-research/coder-template/.mcp.json`

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "mlflow": {
      "type": "http",
      "url": "${MLFLOW_TRACKING_URI}/mcp",
      "description": "Experiment tracking and model registry"
    }
  }
}
```

### CI/CD: Deploy Coder Template

**File**: `.github/workflows/deploy-formula.yml`

```yaml
name: Deploy Formula

on:
  push:
    branches: [main]
    paths: ['formulas/**']

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      formulas: ${{ steps.changed-formulas.outputs.all_changed_files }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Get changed formulas
        id: changed-formulas
        uses: tj-actions/changed-files@v40
        with:
          dir_names: true
          dir_names_max_depth: 2
          files: formulas/**

  deploy-coder-template:
    needs: detect-changes
    runs-on: ubuntu-latest
    strategy:
      matrix:
        formula: ${{ fromJson(needs.detect-changes.outputs.formulas) }}
    steps:
      - uses: actions/checkout@v4

      - name: Install Coder CLI
        run: |
          curl -fsSL https://coder.com/install.sh | sh
          coder login ${{ secrets.CODER_URL }} --token ${{ secrets.CODER_SESSION_TOKEN }}

      - name: Validate Terraform
        run: |
          cd ${{ matrix.formula }}/coder-template
          terraform init -backend=false
          terraform fmt -check
          terraform validate

      - name: Push to Coder
        run: |
          FORMULA_NAME=$(basename ${{ matrix.formula }})
          cd ${{ matrix.formula }}/coder-template

          coder templates push $FORMULA_NAME \
            --directory . \
            --variable git_repo_url="https://gitea.acme.com/test/repo" \
            --message "Deploy from commit ${{ github.sha }}" \
            --yes

      - name: Test workspace creation
        run: |
          FORMULA_NAME=$(basename ${{ matrix.formula }})

          # Create test workspace
          coder create test-$FORMULA_NAME \
            --template $FORMULA_NAME \
            --yes

          # Wait for workspace to be ready
          coder list --output json | jq -e ".[] | select(.name==\"test-$FORMULA_NAME\") | select(.latest_build.status==\"running\")"

          # Delete test workspace
          coder delete test-$FORMULA_NAME --yes

  update-backstage-catalog:
    needs: deploy-coder-template
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Backstage catalog refresh
        run: |
          curl -X POST ${{ secrets.BACKSTAGE_URL }}/api/catalog/refresh \
            -H "Authorization: Bearer ${{ secrets.BACKSTAGE_TOKEN }}"
```

---

## Claude Code Enterprise Configuration

### Global Enterprise Settings

**File**: `enterprise/claude-code/managed-settings.json`

```json
{
  "version": "1.0.0",
  "security": {
    "allowedCommands": [
      "git",
      "docker",
      "kubectl",
      "terraform",
      "npm",
      "yarn",
      "pip",
      "python"
    ],
    "blockedCommands": [
      "rm -rf /",
      "dd",
      "mkfs"
    ],
    "denyListPaths": [
      "**/.env",
      "**/secrets/**",
      "**/*.key",
      "**/*.pem",
      "**/credentials.json"
    ]
  },
  "tools": {
    "bash": {
      "timeout": 300000,
      "maxConcurrent": 5
    },
    "edit": {
      "maxFileSize": "10MB"
    }
  },
  "network": {
    "allowedDomains": [
      "github.com",
      "gitlab.com",
      "*.acme.com",
      "api.anthropic.com",
      "registry.coder.com"
    ]
  }
}
```

**File**: `enterprise/claude-code/managed-mcp.json`

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "description": "Enterprise-approved library documentation"
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Structured reasoning"
    },
    "acme-internal-docs": {
      "type": "http",
      "url": "https://docs.internal.acme.com/mcp",
      "auth": {
        "type": "bearer",
        "token": "${ACME_DOCS_TOKEN}"
      },
      "description": "Internal company documentation"
    }
  }
}
```

### Kubernetes ConfigMap Deployment

**File**: `enterprise/claude-code/k8s/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: claude-code-enterprise-config
  namespace: coder
data:
  managed-settings.json: |
    {
      "version": "1.0.0",
      "security": {
        "allowedCommands": ["git", "docker", "kubectl"],
        "denyListPaths": ["**/.env", "**/secrets/**"]
      }
    }

  managed-mcp.json: |
    {
      "mcpServers": {
        "context7": {
          "type": "http",
          "url": "https://mcp.context7.com/mcp"
        }
      }
    }
```

**CI/CD Deployment**:

```yaml
# .github/workflows/deploy-claude-enterprise.yml
name: Deploy Claude Enterprise Config

on:
  push:
    branches: [main]
    paths: ['enterprise/claude-code/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.28.0'

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Apply ConfigMap
        run: |
          kubectl apply -f enterprise/claude-code/k8s/configmap.yaml
          kubectl rollout restart deployment/coder -n coder
```

---

## Backstage Software Template Example

### ML Research Formula Template

**File**: `formulas/ml-research/backstage-template.yaml`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: formula-ml-research
  title: ML Research Workspace
  description: |
    Complete ML research environment with PyTorch, Jupyter, GPU support,
    and experiment tracking. Pre-configured with Claude Code ML debugging skills.
  tags:
    - python
    - machine-learning
    - gpu
    - jupyter
  annotations:
    backstage.io/formula-version: "2.1.0"
    backstage.io/coder-template: "ml-research-v2"

spec:
  owner: platform-team
  type: formula

  parameters:
    - title: Workspace Configuration
      required: [name, gpu_type]
      properties:
        name:
          title: Workspace Name
          type: string
          description: Unique name for your workspace
          pattern: '^[a-z0-9-]+$'
          ui:autofocus: true

        gpu_type:
          title: GPU Type
          type: string
          description: Select GPU for training
          enum: [none, a100, h100]
          enumNames: ['No GPU (CPU only)', 'NVIDIA A100', 'NVIDIA H100']
          default: none

        python_version:
          title: Python Version
          type: string
          enum: ['3.11', '3.10', '3.9']
          default: '3.11'

        enable_github:
          title: Enable GitHub Integration
          type: boolean
          description: Connect your GitHub account for private repos
          default: false

  steps:
    # 1. Create Gitea repository
    - id: gitea-repo
      name: Create Git Repository
      action: publish:gitea
      input:
        repoUrl: gitea.acme.com?owner=${{ user.entity.metadata.name }}&repo=${{ parameters.name }}
        description: ML Research workspace for ${{ user.entity.spec.profile.displayName }}
        defaultBranch: main
        repoVisibility: private

    # 2. Create Coder workspace
    - id: coder-workspace
      name: Create Coder Workspace
      action: coder:create-workspace
      input:
        user: ${{ user.entity.metadata.name }}
        template: ml-research-v2  # ← References deployed Coder template
        name: ${{ parameters.name }}
        parameters:
          git_repo_url: ${{ steps['gitea-repo'].output.remoteUrl }}
          gpu_type: ${{ parameters.gpu_type }}
          python_version: ${{ parameters.python_version }}

    # 3. Add to Mattermost
    - id: mattermost
      name: Add to ML Research Team
      action: mattermost:add-to-team
      input:
        username: ${{ user.entity.metadata.name }}
        team: ml-research
        channels: ['general', 'model-training', 'paper-discussions']

    # 4. Create CRM opportunity
    - id: twenty-crm
      name: Track in CRM
      action: twenty:create-opportunity
      input:
        name: "ML Research - ${{ user.entity.spec.profile.displayName }}"
        person: ${{ user.entity.spec.profile.email }}
        stage: active
        customFields:
          workspace_url: ${{ steps['coder-workspace'].output.workspaceUrl }}

    # 5. GitHub OAuth (conditional)
    - id: github-oauth
      if: ${{ parameters.enable_github === true }}
      name: Connect GitHub Account
      action: http:backstage:request
      input:
        method: POST
        path: /api/proxy/github/apps/installation
        body:
          user: ${{ user.entity.metadata.name }}

    # 6. Register in catalog
    - id: register
      name: Register Workspace
      action: catalog:register
      input:
        catalogInfoUrl: ${{ steps['gitea-repo'].output.repoContentsUrl }}/catalog-info.yaml

  output:
    links:
      - title: Open Workspace
        icon: coder
        url: ${{ steps['coder-workspace'].output.workspaceUrl }}

      - title: Git Repository
        icon: gitea
        url: ${{ steps['gitea-repo'].output.remoteUrl }}

      - title: Mattermost Team
        icon: mattermost
        url: https://mattermost.acme.com/ml-research/channels/general

      - title: CRM Record
        icon: twenty
        url: ${{ steps['twenty-crm'].output.opportunityUrl }}

    text:
      - title: Next Steps
        content: |
          ✅ Your ML research workspace is ready!

          **Getting Started:**
          1. Click "Open Workspace" to access your Coder environment
          2. Claude Code is pre-configured with ML debugging skills
          3. Join the #model-training channel on Mattermost for support

          **Pre-installed Tools:**
          - PyTorch 2.2.0
          - TensorFlow 2.15
          - Jupyter Lab
          - MLflow experiment tracking
          - Claude Code with ML skills
```

### Backstage Catalog Configuration

**File**: `backstage/app-config.yaml`

```yaml
catalog:
  locations:
    # Load formula templates from Git
    - type: url
      target: https://github.com/acme-corp/platform-formulas/blob/main/formulas/ml-research/backstage-template.yaml

    - type: url
      target: https://github.com/acme-corp/platform-formulas/blob/main/formulas/fullstack-dev/backstage-template.yaml

    - type: url
      target: https://github.com/acme-corp/platform-formulas/blob/main/formulas/data-analysis/backstage-template.yaml

  rules:
    - allow: [Template, Component, System, API, Resource, Location]

# OIDC authentication
auth:
  environment: production
  providers:
    keycloak:
      production:
        clientId: backstage-client
        clientSecret: ${KEYCLOAK_CLIENT_SECRET}
        metadataUrl: https://keycloak.acme.com/realms/acme/.well-known/openid-configuration
        prompt: auto

# Pre-provisioning webhook
backend:
  baseUrl: https://backstage.acme.com
  listen:
    port: 7007

  # Custom endpoints
  csp:
    connect-src: ["'self'", 'https://keycloak.acme.com']
```

---

## Custom Scaffolder Actions

### Coder Action

**File**: `backstage/plugins/scaffolder-backend-coder/src/actions/create-workspace.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import axios from 'axios';

export const createCoderWorkspaceAction = () => {
  return createTemplateAction({
    id: 'coder:create-workspace',
    schema: {
      input: {
        type: 'object',
        required: ['user', 'template', 'name'],
        properties: {
          user: { type: 'string' },
          template: { type: 'string' },
          name: { type: 'string' },
          parameters: { type: 'object' },
        },
      },
      output: {
        type: 'object',
        properties: {
          workspaceUrl: { type: 'string' },
          workspaceId: { type: 'string' },
        },
      },
    },

    async handler(ctx) {
      const { user, template, name, parameters } = ctx.input;

      // Get Coder API URL and token from config
      const coderUrl = ctx.config.getString('coder.url');
      const coderToken = ctx.config.getString('coder.token');

      ctx.logger.info(`Creating Coder workspace ${name} for user ${user}`);

      // Get template ID
      const templatesResp = await axios.get(
        `${coderUrl}/api/v2/templates`,
        { headers: { 'Coder-Session-Token': coderToken } }
      );

      const templateObj = templatesResp.data.find(t => t.name === template);
      if (!templateObj) {
        throw new Error(`Template ${template} not found`);
      }

      // Get user ID
      const usersResp = await axios.get(
        `${coderUrl}/api/v2/users`,
        { headers: { 'Coder-Session-Token': coderToken } }
      );

      const userObj = usersResp.data.users.find(u => u.username === user);
      if (!userObj) {
        throw new Error(`User ${user} not found in Coder`);
      }

      // Create workspace
      const createResp = await axios.post(
        `${coderUrl}/api/v2/organizations/${userObj.organization_ids[0]}/members/${userObj.id}/workspaces`,
        {
          name,
          template_id: templateObj.id,
          rich_parameter_values: Object.entries(parameters || {}).map(([name, value]) => ({
            name,
            value: String(value),
          })),
        },
        { headers: { 'Coder-Session-Token': coderToken } }
      );

      const workspaceUrl = `${coderUrl}/@${user}/${name}`;

      ctx.logger.info(`Workspace created: ${workspaceUrl}`);

      ctx.output('workspaceUrl', workspaceUrl);
      ctx.output('workspaceId', createResp.data.id);
    },
  });
};
```

### Mattermost Action

**File**: `backstage/plugins/scaffolder-backend-mattermost/src/actions/add-to-team.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import axios from 'axios';

export const addToMattermostTeamAction = () => {
  return createTemplateAction({
    id: 'mattermost:add-to-team',
    schema: {
      input: {
        type: 'object',
        required: ['username', 'team', 'channels'],
        properties: {
          username: { type: 'string' },
          team: { type: 'string' },
          channels: { type: 'array', items: { type: 'string' } },
        },
      },
    },

    async handler(ctx) {
      const { username, team, channels } = ctx.input;

      const mattermostUrl = ctx.config.getString('mattermost.url');
      const mattermostToken = ctx.config.getString('mattermost.token');

      const headers = { Authorization: `Bearer ${mattermostToken}` };

      // Get user ID
      const userResp = await axios.get(
        `${mattermostUrl}/api/v4/users/username/${username}`,
        { headers }
      );
      const userId = userResp.data.id;

      // Get team ID
      const teamsResp = await axios.get(
        `${mattermostUrl}/api/v4/teams`,
        { headers }
      );
      const teamObj = teamsResp.data.find(t => t.name === team);

      // Add to team
      await axios.post(
        `${mattermostUrl}/api/v4/teams/${teamObj.id}/members`,
        { team_id: teamObj.id, user_id: userId },
        { headers }
      );

      // Add to channels
      for (const channelName of channels) {
        const channelResp = await axios.get(
          `${mattermostUrl}/api/v4/teams/${teamObj.id}/channels/name/${channelName}`,
          { headers }
        );

        await axios.post(
          `${mattermostUrl}/api/v4/channels/${channelResp.data.id}/members`,
          { user_id: userId },
          { headers }
        );
      }

      ctx.logger.info(`Added ${username} to team ${team}`);
    },
  });
};
```

### Twenty CRM Action

**File**: `backstage/plugins/scaffolder-backend-twenty/src/actions/create-opportunity.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { GraphQLClient, gql } from 'graphql-request';

export const createTwentyOpportunityAction = () => {
  return createTemplateAction({
    id: 'twenty:create-opportunity',
    schema: {
      input: {
        type: 'object',
        required: ['name', 'person', 'stage'],
        properties: {
          name: { type: 'string' },
          person: { type: 'string' },
          stage: { type: 'string' },
          customFields: { type: 'object' },
        },
      },
      output: {
        type: 'object',
        properties: {
          opportunityId: { type: 'string' },
          opportunityUrl: { type: 'string' },
        },
      },
    },

    async handler(ctx) {
      const { name, person, stage, customFields } = ctx.input;

      const twentyUrl = ctx.config.getString('twenty.url');
      const twentyToken = ctx.config.getString('twenty.token');

      const client = new GraphQLClient(`${twentyUrl}/graphql`, {
        headers: { Authorization: `Bearer ${twentyToken}` },
      });

      // Find person by email
      const findPersonQuery = gql`
        query FindPerson($email: String!) {
          people(filter: { email: { eq: $email } }) {
            edges {
              node {
                id
                name
              }
            }
          }
        }
      `;

      const personData = await client.request(findPersonQuery, { email: person });
      const personId = personData.people.edges[0]?.node.id;

      // Create opportunity
      const createOpportunityMutation = gql`
        mutation CreateOpportunity($data: OpportunityCreateInput!) {
          createOpportunity(data: $data) {
            id
            name
            stage
          }
        }
      `;

      const oppData = await client.request(createOpportunityMutation, {
        data: {
          name,
          personId,
          stage,
          ...customFields,
        },
      });

      const opportunityUrl = `${twentyUrl}/objects/opportunities/${oppData.createOpportunity.id}`;

      ctx.output('opportunityId', oppData.createOpportunity.id);
      ctx.output('opportunityUrl', opportunityUrl);
    },
  });
};
```

---

## Implementation Timeline

### Week 1-2: Foundation

**Deliverables**:
- Set up `platform-formulas` mono-repo
- Configure Backstage instance with BUI theme
- Deploy Keycloak OIDC provider
- Implement Logto webhook → Backstage pre-provisioning endpoint

**Tasks**:
```bash
# Initialize mono-repo
git init platform-formulas
cd platform-formulas
mkdir -p formulas backstage enterprise .github/workflows

# Deploy Backstage
cd backstage
npx @backstage/create-app@latest
# Apply BUI theme (custom-theme.css)

# Configure OIDC
# Add auth module for Keycloak

# Implement pre-provisioning service
# packages/backend/src/modules/pre-provisioning.ts
```

### Week 3-4: Coder Integration

**Deliverables**:
- Create first Coder template (ml-research)
- Embed Claude Code configuration in template
- Deploy Claude enterprise ConfigMap to K8s
- Implement `coder:create-workspace` scaffolder action

**Tasks**:
```bash
# Create formula
cd formulas/ml-research/coder-template
# Write main.tf with GPU support

# Add Claude config
mkdir .claude
# Write settings.json, skills/, agents/

# Deploy to Coder
coder templates push ml-research --directory .

# Build scaffolder action
cd backstage/plugins/scaffolder-backend-coder
yarn create @backstage/plugin
```

### Week 5-6: Service Integrations

**Deliverables**:
- Implement pre-provisioning for Gitea, Mattermost, Twenty
- Create custom scaffolder actions for all services
- Test OIDC hybrid flow end-to-end

**Tasks**:
```typescript
// Pre-provisioning webhook handler
// Test: Create user in Logto → Verify users created in all services

// Scaffolder actions
// - publish:gitea (use official plugin)
// - mattermost:add-to-team
// - twenty:create-opportunity
```

### Week 7: Formula Marketplace

**Deliverables**:
- Create 3 complete formulas:
  - ML Research
  - Full-Stack Development
  - Data Analysis
- Write Backstage templates for each
- Test end-to-end provisioning flow

### Week 8: CI/CD & Testing

**Deliverables**:
- GitHub Actions workflows for formula deployment
- Integration tests for all scaffolder actions
- Documentation and runbooks

**Workflows**:
- `deploy-formula.yml` - Validates and pushes Coder templates
- `deploy-backstage.yml` - Updates catalog
- `deploy-claude-enterprise.yml` - Updates K8s ConfigMap

### Week 9: Production Deployment

**Deliverables**:
- Deploy to production environment
- User acceptance testing
- Training materials for internal users
- Launch formula marketplace

**Validation**:
1. New user signs up on Logto
2. Verify pre-provisioned accounts in all services
3. User logs into Backstage via OIDC
4. User provisions ML Research workspace
5. Verify Coder workspace, Gitea repo, Mattermost team, CRM record
6. User opens Coder workspace, Claude Code is pre-configured

---

## Production Checklist

### Infrastructure

- [ ] Kubernetes cluster with GPU nodes (for ML formulas)
- [ ] Persistent storage for Coder workspaces (PVC)
- [ ] PostgreSQL for Backstage catalog
- [ ] Redis for Backstage cache (optional)

### Services Configuration

- [ ] Logto/Keycloak OIDC provider configured
- [ ] Backstage connected to Keycloak
- [ ] Coder connected to Keycloak
- [ ] Gitea connected to Keycloak
- [ ] Mattermost connected to Keycloak
- [ ] Twenty CRM deployed

### Secrets Management

- [ ] Coder session token (for scaffolder actions)
- [ ] Gitea admin token
- [ ] Mattermost bot token
- [ ] Twenty API token
- [ ] Keycloak client secret
- [ ] GitHub OAuth app credentials (optional)

### Monitoring

- [ ] Backstage logs aggregation
- [ ] Coder workspace metrics
- [ ] Pre-provisioning webhook monitoring
- [ ] Scaffolder action success/failure rates

### Security

- [ ] Claude Code enterprise managed-settings.json deployed
- [ ] Claude Code managed-mcp.json deployed
- [ ] API tokens rotated regularly
- [ ] RBAC configured in Backstage catalog
- [ ] Network policies for Kubernetes pods

---

## Troubleshooting

### User not pre-provisioned

**Symptom**: User signs up in Logto but doesn't exist in Coder/Gitea

**Debug**:
```bash
# Check Logto webhook logs
kubectl logs -n auth deployment/logto

# Check Backstage pre-provisioning endpoint
kubectl logs -n backstage deployment/backstage | grep pre-provisioning

# Manually trigger pre-provisioning
curl -X POST https://backstage.acme.com/api/pre-provision \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "alice@acme.com", "name": "Alice"}}'
```

### Coder template push fails

**Symptom**: CI/CD fails when pushing Coder template

**Debug**:
```bash
# Validate Terraform locally
cd formulas/ml-research/coder-template
terraform init -backend=false
terraform validate

# Test push manually
coder templates push ml-research --directory . --dry-run

# Check Coder server logs
kubectl logs -n coder deployment/coder
```

### Claude Code config not loading

**Symptom**: Claude Code doesn't see enterprise settings

**Debug**:
```bash
# Check ConfigMap exists
kubectl get configmap claude-code-enterprise-config -n coder

# Verify mount in pod
kubectl exec -it coder-alice-ml-research -n coder -- cat /etc/claude-code/managed-settings.json

# Check Claude Code precedence
# Enterprise settings should override user settings
claude /config
```

---

## Next Steps

1. **Review and approve architecture** with stakeholders
2. **Set up development environment** (Week 1)
3. **Implement pre-provisioning MVP** (Week 2)
4. **Create first formula** (Week 3-4)
5. **Internal beta testing** (Week 7)
6. **Production launch** (Week 9)

---

**Document Version**: 1.0
**Last Updated**: 2025-01-18
**Status**: Ready for Implementation
