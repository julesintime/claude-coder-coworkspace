# DevContainer Migration Plan - Industry Best Practices

## Executive Summary

This document outlines the migration from Terraform-heavy templates to a **devcontainer.json-first architecture** following industry best practices for 2025.

### Current Problem
- **Terraform complexity**: All configuration embedded in main.tf (startup scripts, app installations, PM2 management)
- **Hard to maintain**: Every change requires Terraform updates and template pushes
- **Not portable**: Configuration locked to Coder, can't be used in VS Code/GitHub Codespaces
- **PM2 race conditions**: Services fail because dependencies aren't ready

### Solution: 3-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Terraform (Infrastructure)                        │
│  - Kubernetes resources only (pods, PVCs, networking)       │
│  - Parameters (API keys, presets)                           │
│  - Minimal coder_agent config                               │
│  - NO app installations, NO startup scripts                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: devcontainer.json (Project Environment)           │
│  - Base image + features (docker-in-docker, tools)          │
│  - postCreateCommand: Install PM2, system tools             │
│  - postStartCommand: Start PM2 services                     │
│  - customizations.coder.apps: Define coder_apps             │
│  - Version controlled with your project                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Dotfiles (User Personalization)                   │
│  - User-specific bashrc, aliases, git config                │
│  - Personal tools and preferences                           │
│  - Managed via Coder's dotfiles module                      │
│  - Separate repo, shared across all workspaces              │
└─────────────────────────────────────────────────────────────┘
```

## Industry Best Practices (2025)

### 1. **Separation of Concerns**
- **Infrastructure (Terraform)**: What Kubernetes resources to create
- **Environment (devcontainer.json)**: What tools/services the project needs
- **Personalization (Dotfiles)**: What the user prefers

### 2. **Portability**
- `devcontainer.json` is an **open standard** (supported by VS Code, GitHub Codespaces, JetBrains, etc.)
- Your dev environment works in Coder, VS Code locally, or GitHub Codespaces
- **No vendor lock-in**

### 3. **Version Control**
- `devcontainer.json` lives **with your project code**
- Team members get the same environment automatically
- Changes tracked in git

### 4. **User Autonomy**
- Users can customize via dotfiles without touching team config
- Dotfiles repo can be reused across all workspaces

## Architecture Comparison

### Before (Terraform-Heavy)

```terraform
# main.tf - 1400+ lines 😱

resource "coder_agent" "main" {
  startup_script = <<-EOT
    # Install kubectl
    curl -fsSL ... | sudo gpg ...

    # Install GitHub CLI
    wget ...

    # Install PM2
    for i in 1 2 3; do
      sudo npm install -g pm2 ...
    done

    # Install TypeScript
    sudo npm install -g typescript

    # ... 100+ more lines
  EOT
}

resource "coder_script" "install_pm2" {
  # More PM2 logic
}

resource "coder_script" "claude_code_ui" {
  # Install and start Claude Code UI
  # Verify PM2, install npm package, start with pm2
}

resource "coder_script" "vibe_kanban" {
  # Install and start Vibe Kanban
  # More PM2 logic
}

# ... 20+ more modules
```

**Problems:**
- 1400+ lines of Terraform
- PM2 race conditions
- Hard to test changes
- Not portable
- Duplicate logic

### After (devcontainer.json-First)

```terraform
# main.tf - ~300 lines ✅

terraform {
  required_providers {
    coder      = { source = "coder/coder" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

# ... Parameters (API keys, presets)

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  startup_script = "echo 'Workspace ready!'"

  env = {
    CODER_AGENT_DEVCONTAINERS_ENABLE = "true"
  }
}

module "devcontainers-cli" {
  source   = "dev.registry.coder.com/modules/devcontainers-cli/coder"
  agent_id = coder_agent.main.id
}

resource "coder_devcontainer" "main" {
  agent_id         = coder_agent.main.id
  workspace_folder = "/home/coder/projects"
}

module "dotfiles" {
  source   = "dev.registry.coder.com/coder/dotfiles/coder"
  agent_id = coder_agent.main.id
}

# ... Kubernetes resources (pod, PVC)
```

```json
// .devcontainer/devcontainer.json - ~200 lines ✅

{
  "name": "Unified DevOps Workspace",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:latest",

  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": false,
      "dockerDashComposeVersion": "v2"
    },
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {
      "version": "1.31",
      "helm": "latest"
    },
    "ghcr.io/devcontainers/features/github-cli:1": {
      "version": "latest"
    }
  },

  "postCreateCommand": ".devcontainer/scripts/post-create.sh",
  "postStartCommand": ".devcontainer/scripts/post-start.sh",

  "customizations": {
    "coder": {
      "apps": [
        {
          "slug": "claude-code-ui",
          "displayName": "Claude Code UI",
          "url": "http://localhost:38401",
          "icon": "/icon/code.svg",
          "healthCheck": {
            "url": "http://localhost:38401",
            "interval": 5,
            "threshold": 20
          }
        },
        {
          "slug": "vibe-kanban",
          "displayName": "Vibe Kanban",
          "url": "http://localhost:38402",
          "icon": "/icon/workspace.svg",
          "healthCheck": {
            "url": "http://localhost:38402",
            "interval": 10,
            "threshold": 30
          }
        }
      ]
    }
  },

  "mounts": [
    "source=claude-workspace-home,target=/home/coder,type=volume"
  ]
}
```

```bash
# .devcontainer/scripts/post-create.sh - ~50 lines ✅

#!/bin/bash
set -e

# Install PM2 globally
npm install -g pm2

# Install UI tools
npm install -g @siteboon/claude-code-ui

# Install Claude Code (using Coder module in parallel)
# No need to do it here - Coder module handles it

# Create directories
mkdir -p ~/.claude/resume-logs ~/scripts
```

```bash
# .devcontainer/scripts/post-start.sh - ~30 lines ✅

#!/bin/bash
set -e

# Start services with PM2
pm2 delete all || true

# Start Claude Code UI
PORT=38401 \
DATABASE_PATH=~/.claude-code-ui/database.json \
pm2 start claude-code-ui --name claude-code-ui

# Start Vibe Kanban
BACKEND_PORT=38402 \
HOST=0.0.0.0 \
pm2 start "npx vibe-kanban" --name vibe-kanban

pm2 save
pm2 list
```

**Benefits:**
- Terraform: 300 lines (was 1400+) = **78% reduction**
- No PM2 race conditions (postCreateCommand runs before postStartCommand)
- Portable to VS Code, GitHub Codespaces
- Easy to test (just rebuild container)
- Version controlled with project

## Migration Roadmap

### Phase 1: Proof of Concept (Day 1)
- [ ] Create `.devcontainer/` directory in `kubernetes-claude-devcontainer/`
- [ ] Write `devcontainer.json` with basic features
- [ ] Write `post-create.sh` script (install PM2, tools)
- [ ] Write `post-start.sh` script (start PM2 services)
- [ ] Update `main.tf` to use `coder_devcontainer` resource
- [ ] Test workspace creation

### Phase 2: Migrate UI Tools (Day 2)
- [ ] Add Claude Code UI to `customizations.coder.apps`
- [ ] Add Vibe Kanban to `customizations.coder.apps`
- [ ] Test healthchecks
- [ ] Verify PM2 services start correctly

### Phase 3: Dotfiles Integration (Day 2)
- [ ] Create separate dotfiles repo (or use existing)
- [ ] Add dotfiles module to Terraform
- [ ] Move bash aliases, git config to dotfiles
- [ ] Test dotfiles installation

### Phase 4: Complete Migration (Day 3)
- [ ] Move remaining features to devcontainer.json
- [ ] Remove all coder_script resources from Terraform
- [ ] Clean up Terraform to minimal config
- [ ] Update documentation

### Phase 5: Testing & Rollout (Day 4)
- [ ] Test all presets (nano, mini, mega)
- [ ] Test workspace restarts
- [ ] Test with different API keys
- [ ] Create migration guide for users
- [ ] Push to production

## File Structure (After Migration)

```
kubernetes-claude-devcontainer/
├── .devcontainer/
│   ├── devcontainer.json          # Main config (200 lines)
│   └── scripts/
│       ├── post-create.sh         # Install tools (50 lines)
│       └── post-start.sh          # Start services (30 lines)
├── main.tf                        # Infrastructure only (300 lines)
├── README.md
└── examples/
    └── sample-project/
        └── .devcontainer/         # Project-specific overrides
```

**Separate dotfiles repo:**
```
coder-dotfiles/
├── .bashrc
├── .bash_aliases
├── .gitconfig
├── scripts/
│   ├── claude-resume-helpers.sh
│   └── bash-aliases.sh
└── install.sh
```

## PM2 in Devcontainer: Best Practices

### Why PM2 Works Well Here

1. **Ordered Execution**:
   - `postCreateCommand` runs ONCE when container is created
   - `postStartCommand` runs EVERY TIME container starts
   - No race conditions!

2. **Persistence**:
   - PM2 process list saved to `~/.pm2/`
   - Home directory is mounted as volume
   - Services automatically restart on workspace restart

3. **Monitoring**:
   - `pm2 list` shows all services
   - `pm2 logs` for debugging
   - `pm2 monit` for real-time monitoring

### Installation Pattern

```bash
# post-create.sh (runs once)
npm install -g pm2
npm install -g @siteboon/claude-code-ui
# Other one-time installations
```

```bash
# post-start.sh (runs every start)
pm2 delete all || true  # Clean slate
pm2 start claude-code-ui --name claude-code-ui
pm2 start "npx vibe-kanban" --name vibe-kanban
pm2 save  # Persist process list
```

### Exposing via coder_app

```json
{
  "customizations": {
    "coder": {
      "apps": [
        {
          "slug": "claude-code-ui",
          "displayName": "Claude Code UI",
          "url": "http://localhost:38401",
          "icon": "/icon/code.svg",
          "openIn": "tab",
          "share": "owner",
          "healthCheck": {
            "url": "http://localhost:38401",
            "interval": 5,
            "threshold": 20
          }
        }
      ]
    }
  }
}
```

**How it works:**
1. PM2 starts service on port 38401 inside container
2. `coder_app` exposes it via Coder's app proxy
3. Healthcheck monitors service status
4. Shows up in Coder dashboard automatically

## Dotfiles Strategy

### What Goes in Dotfiles?

**YES (User-specific):**
- `.bashrc`, `.bash_aliases`
- `.gitconfig` (personal name, email)
- `.vimrc`, `.tmuxconf`
- Personal helper scripts
- Editor preferences

**NO (Project-specific):**
- Project tools (kubectl, docker, etc.) → devcontainer.json features
- Project services (databases, APIs) → docker-compose.yml
- Team aliases → project's `.devcontainer/scripts/`

### Dotfiles Repo Structure

```
coder-dotfiles/
├── .bashrc                    # Bash configuration
├── .bash_aliases              # User aliases
├── .gitconfig.template        # Git config template
├── scripts/
│   ├── claude-resume-helpers.sh
│   └── bash-aliases.sh
└── install.sh                 # Installation script

# install.sh
#!/bin/bash
set -e

echo "🚀 Installing personal dotfiles..."

# Copy files
cp .bashrc ~/.bashrc
cp .bash_aliases ~/.bash_aliases

# Git config (from GitHub if available)
if command -v gh >/dev/null 2>&1 && [ -n "$GITHUB_TOKEN" ]; then
  GH_USER=$(gh api user --jq '.name // .login')
  GH_EMAIL=$(gh api user --jq '.email')
  git config --global user.name "$GH_USER"
  git config --global user.email "$GH_EMAIL"
else
  cat .gitconfig.template >> ~/.gitconfig
fi

# Install scripts
mkdir -p ~/scripts
cp scripts/* ~/scripts/
chmod +x ~/scripts/*.sh

echo "✅ Dotfiles installed!"
```

### Coder Integration

```terraform
# main.tf
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/dotfiles/coder"
  version  = "1.2.1"
  agent_id = coder_agent.main.id
}
```

**OR** via parameter:

```terraform
data "coder_parameter" "dotfiles_url" {
  name         = "dotfiles_url"
  display_name = "Dotfiles Repository"
  description  = "Your personal dotfiles repository (optional)"
  type         = "string"
  default      = "https://github.com/xoojulian/coder-dotfiles.git"
  mutable      = true
}
```

## Benefits Summary

### For Developers
- ✅ Portable: Works in Coder, VS Code, GitHub Codespaces
- ✅ Fast: Pre-built images, cached layers
- ✅ Customizable: Personal dotfiles without breaking team config
- ✅ Predictable: No race conditions, ordered execution

### For Teams
- ✅ Maintainable: 78% less Terraform code
- ✅ Version Controlled: Environment config in git with code
- ✅ Testable: Rebuild container locally to test changes
- ✅ Scalable: Add features without Terraform changes

### For Operations
- ✅ Simple: Terraform only manages infrastructure
- ✅ Reliable: No PM2 race conditions
- ✅ Observable: PM2 monitoring built-in
- ✅ Flexible: Easy to add/remove features

## Migration Checklist

### Pre-Migration
- [ ] Backup current workspace
- [ ] Document current functionality
- [ ] Test current workspace baseline

### Migration
- [ ] Create `.devcontainer/` directory
- [ ] Write `devcontainer.json`
- [ ] Write post-create script
- [ ] Write post-start script
- [ ] Update Terraform to use `coder_devcontainer`
- [ ] Add dotfiles module

### Testing
- [ ] Create new workspace
- [ ] Verify all tools installed
- [ ] Verify PM2 services running
- [ ] Verify coder_apps accessible
- [ ] Verify dotfiles applied
- [ ] Test workspace restart
- [ ] Test workspace rebuild

### Rollout
- [ ] Update documentation
- [ ] Create migration guide
- [ ] Notify team
- [ ] Push to production
- [ ] Monitor for issues

## Next Steps

1. **Review this plan** - Ensure it aligns with your requirements
2. **Create `.devcontainer/` structure** - Start with proof of concept
3. **Test iteratively** - Don't migrate everything at once
4. **Gather feedback** - Test with team before full rollout

---

**This architecture follows 2025 industry best practices for:**
- Dev Containers (VS Code, GitHub, JetBrains)
- Cloud Development Environments (Coder, Gitpod, Codespaces)
- Infrastructure as Code (Terraform)
- Dotfiles Management (Chezmoi, YADM, GNU Stow)

**References:**
- [Dev Containers Specification](https://containers.dev/)
- [Coder Dev Containers Guide](https://coder.com/docs/admin/templates/extending-templates/devcontainers)
- [Dotfiles Best Practices](https://www.daytona.io/dotfiles/ultimate-guide-to-dev-containers)
