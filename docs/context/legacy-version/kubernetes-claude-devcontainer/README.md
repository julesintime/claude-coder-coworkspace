# Kubernetes Claude DevContainer Template

A lightweight, fast-provisioning Coder template for TypeScript/Node.js development with full Docker-in-Docker support and AI coding assistance.

## Overview

This template provides a cloud development environment optimized for:
- **TypeScript/Node.js** development (lighter than universal image)
- **Docker-in-Docker** via Envbox for containerized development
- **Claude Code AI** for intelligent coding assistance
- **Fast provisioning** (~10 minutes vs ~50+ minutes for full-featured templates)
- **DevContainer compatibility** (optional customization support)

## Architecture

```
┌──────────────────────────────────────────────────┐
│ Kubernetes Pod                                   │
│ ┌──────────────────────────────────────────────┐ │
│ │ Envbox Container (Privileged)                │ │
│ │ - ghcr.io/coder/envbox:latest                │ │
│ │ - Provides Docker-in-Docker capability       │ │
│ │                                               │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ TypeScript DevContainer Image           │ │ │
│ │ │ - mcr.microsoft.com/devcontainers/      │ │ │
│ │ │   typescript-node:latest                 │ │ │
│ │ │                                           │ │ │
│ │ │ Pre-installed:                            │ │ │
│ │ │ ✓ Node.js & npm                          │ │ │
│ │ │ ✓ TypeScript compiler                    │ │ │
│ │ │ ✓ Git & common dev tools                │ │ │
│ │ │ ✓ Docker CLI (via Envbox)                │ │ │
│ │ │                                           │ │ │
│ │ │ Installed by template:                    │ │ │
│ │ │ ✓ kubectl (Kubernetes CLI)               │ │ │
│ │ │ ✓ gh (GitHub CLI)                        │ │ │
│ │ │ ✓ Claude Code AI                         │ │ │
│ │ │ ✓ MCP servers (context7, deepwiki, etc) │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

## Features

### Core Capabilities
- ✅ **TypeScript/Node.js Development** - Pre-configured with latest LTS
- ✅ **Docker-in-Docker** - Full Docker and docker-compose support via Envbox
- ✅ **Claude Code AI** - Integrated AI coding assistant
- ✅ **MCP Servers** - context7, sequential-thinking, deepwiki pre-configured
- ✅ **Kubernetes Access** - kubectl pre-installed and configured
- ✅ **GitHub Integration** - GitHub CLI with optional external auth
- ✅ **Fast Provisioning** - ~10 minute workspace creation (vs 50+ for full templates)

### Resource Presets
Choose your workspace size:
- **Nano**: 1 CPU, 2GB RAM, 20GB disk - For light development
- **Mini**: 2 CPU, 8GB RAM, 50GB disk - Default, balanced option
- **Mega**: 8 CPU, 32GB RAM, 200GB disk - For heavy workloads

### Optional Features
- 📁 **File Browser** - Web-based file management
- 🔐 **GitHub External Auth** - Seamless GitHub integration
- 📂 **Git Clone** - Auto-clone repository on workspace creation
- 🎨 **Dotfiles** - Personal environment customization
- 💻 **Multiple IDEs** - VS Code (web), Cursor, Windsurf support

## Quick Start

### 1. Push Template to Coder

```bash
cd kubernetes-claude-devcontainer
coder templates push kubernetes-claude-devcontainer
```

### 2. Create Workspace

```bash
# Create workspace with defaults
coder create my-ts-workspace --template kubernetes-claude-devcontainer

# Or create with specific parameters
coder create my-ts-workspace --template kubernetes-claude-devcontainer \
  --parameter preset=mega \
  --parameter git_clone_repo_url=https://github.com/user/repo.git
```

### 3. Connect

```bash
coder ssh my-ts-workspace
```

## Configuration

### AI Authentication (Optional)

Configure Claude Code authentication via one of:

**Option 1: API Key**
- Generate at: https://console.anthropic.com/settings/keys
- Provide during workspace creation or set as parameter

**Option 2: OAuth Token**
- Run: `claude setup-token` locally
- Copy token to workspace parameter

### GitHub Authentication (Optional)

**Recommended: External Auth**
- Configure in Coder server settings
- Automatically authenticated on workspace creation

**Alternative: Personal Access Token**
- Generate at: https://github.com/settings/tokens
- Provide during workspace creation

### Gemini AI (Optional)

- Generate API key at: https://aistudio.google.com/apikey
- Provide during workspace creation

## Parameters

### Core Settings
| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `preset` | Workspace size (nano/mini/mega) | mini | No |
| `preview_port` | App preview port | 3000 | No |

### AI & Authentication
| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `claude_api_key` | Anthropic API key | "" | No |
| `claude_oauth_token` | Claude OAuth token | "" | No |
| `claude_api_endpoint` | Custom Claude endpoint | "" | No |
| `gemini_api_key` | Google Gemini API key | "" | No |
| `github_token` | GitHub PAT | "" | No |

### Git & Projects
| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `git_clone_repo_url` | Repo to clone | "" | No |
| `git_clone_path` | Clone destination | /home/coder/projects/repo | No |

### Optional Features
| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `enable_filebrowser` | Enable file browser | true | No |

### Advanced
| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `system_prompt` | AI system prompt | (see template) | No |
| `setup_script` | Custom setup script | (see template) | No |

## Usage Examples

### Example 1: Basic TypeScript Development

```bash
coder create ts-dev --template kubernetes-claude-devcontainer
coder ssh ts-dev

# Inside workspace
mkdir my-project && cd my-project
npm init -y
npm install --save-dev typescript @types/node
npx tsc --init

# Start coding with Claude Code
claude
```

### Example 2: Clone Existing Project

```bash
coder create my-app --template kubernetes-claude-devcontainer \
  --parameter git_clone_repo_url=https://github.com/user/my-app.git

coder ssh my-app
cd projects/my-app
npm install
npm run dev
```

### Example 3: Docker Development

```bash
coder create docker-dev --template kubernetes-claude-devcontainer

coder ssh docker-dev

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    image: node:18
    volumes:
      - ./:/app
    working_dir: /app
    command: npm run dev
    ports:
      - "3000:3000"
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
EOF

# Start services
docker-compose up -d
docker ps
```

### Example 4: Kubernetes Development

```bash
coder create k8s-dev --template kubernetes-claude-devcontainer

coder ssh k8s-dev

# Check cluster access
kubectl cluster-info
kubectl get nodes

# Deploy an app
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
```

## Docker-in-Docker Support

This template provides full Docker-in-Docker via Envbox:

```bash
# All Docker commands work
docker run hello-world
docker build -t myapp .
docker-compose up -d

# Docker data persists across restarts
# Images, volumes, and containers are preserved
```

### Storage Locations

Persistent storage (survives workspace restarts):
```
/home/coder                    → User workspace
/var/lib/docker                → Docker images & volumes (via PVC)
/var/lib/containers            → Container data (via PVC)
```

## AI Tools

### Claude Code

```bash
# Start Claude Code
claude

# Resume previous session
ccr <session-id>

# List recent sessions
ccr-list
```

### MCP Servers (Pre-configured)

- **context7** - Up-to-date library documentation
- **sequential-thinking** - Advanced reasoning capabilities
- **deepwiki** - GitHub repository documentation

```bash
# List configured MCP servers
claude mcp list
```

### Gemini CLI (Optional)

```bash
# If GOOGLE_AI_API_KEY is configured
gemini-chat
```

### GitHub Copilot (Optional)

```bash
# If GitHub token is configured
gh copilot suggest "create a typescript interface"
gh copilot explain "explain this code"
```

## Bash Aliases

Pre-configured aliases for productivity:

```bash
# AI Tools
cc              # claude
gemini-chat     # gemini CLI
copilot         # gh copilot

# Docker
dc              # docker-compose
dps             # docker ps
di              # docker images
dclean          # docker system prune -af

# Kubernetes
k               # kubectl
kgp             # kubectl get pods
kgs             # kubectl get svc

# Git
gs              # git status
ga              # git add
gc              # git commit
gp              # git push

# Utilities
workspace-info  # Show workspace details
```

## DevContainer Support (Future)

This template is designed for future .devcontainer support:

1. **Place `.devcontainer/devcontainer.json`** in your git repository
2. **Future versions** will detect and build custom images using envbuilder
3. **Customize** VS Code settings, extensions, and features

See `.devcontainer-examples/` for sample configurations.

## Comparison with Other Templates

| Feature | This Template | Unified-DevOps | kubernetes-devcontainer |
|---------|--------------|----------------|------------------------|
| **Base Image** | TypeScript (~3GB) | enterprise-node (~2GB) | User-provided |
| **Languages** | Node.js, TypeScript | Node.js only | Depends on image |
| **Provisioning Time** | ~10 min | ~50+ min | ~15 min |
| **Docker-in-Docker** | ✅ Yes (Envbox) | ✅ Yes (Envbox) | ❌ No |
| **AI Tools** | Claude Code, MCP | Claude, Gemini, Copilot, UIs | None |
| **Git Repo Required** | ❌ Optional | ❌ Optional | ✅ Yes |
| **Custom Apps** | None (simpler) | claude-code-ui, vibe-kanban | None |
| **Complexity** | Low | High | Medium |
| **Use Case** | TS/Node.js dev | Full DevOps | Custom images |

## Troubleshooting

### Workspace Won't Start

```bash
# Check pod status
kubectl get pods -n coder-workspaces | grep <username>-<workspace>

# Check pod logs
kubectl logs -n coder-workspaces <pod-name> -c dev

# Check events
kubectl describe pod -n coder-workspaces <pod-name>
```

### Docker Not Working

```bash
# Inside workspace, check Docker
docker info

# If not working, check Envbox logs
kubectl logs -n coder-workspaces <pod-name> -c dev | grep -i docker
```

### Claude Code Not Authenticated

```bash
# Check environment variables
env | grep CLAUDE

# Re-authenticate
claude setup-token

# Verify
claude --version
```

### Slow Provisioning

- First workspace creation pulls the TypeScript image (~3GB)
- Subsequent creations use cached image (much faster)
- Check cluster resources if consistently slow

### MCP Servers Not Working

```bash
# List MCP servers
claude mcp list

# Re-add if missing
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

## Advanced Configuration

### Custom Setup Script

Modify the `setup_script` parameter to run custom initialization:

```bash
coder create my-workspace --template kubernetes-claude-devcontainer \
  --parameter 'setup_script=#!/bin/bash
echo "Custom setup"
npm install -g pnpm
pnpm setup
'
```

### Custom System Prompt

Customize AI behavior via `system_prompt` parameter:

```bash
--parameter 'system_prompt=You are a TypeScript expert specializing in NestJS development...'
```

### Persistent Dotfiles

Configure personal dotfiles:

1. Fork https://github.com/xoojulian/coder-dotfiles
2. Modify the dotfiles script to use your fork
3. Or create custom dotfiles in `/home/coder/.dotfiles`

## Development

### Testing Changes

```bash
# Make changes to main.tf
vim main.tf

# Push updated template
coder templates push kubernetes-claude-devcontainer --yes

# Create test workspace
coder create test-ws --template kubernetes-claude-devcontainer

# Check logs
coder logs test-ws
```

### Template Variables

Modify Terraform variables in `main.tf`:
- `use_kubeconfig` - Cluster connection method
- `namespace` - Kubernetes namespace

## Performance Tips

1. **Use appropriate preset** - Don't over-provision resources
2. **Clean up Docker** - Run `dclean` periodically
3. **Archive old workspaces** - Use the archive module
4. **Monitor resource usage** - Check workspace metadata in Coder UI

## Security Considerations

- Envbox runs privileged (required for Docker-in-Docker)
- Store secrets in Coder parameters (marked as ephemeral)
- Use external authentication when possible
- Regularly update the base image
- Review dotfiles before applying

## Contributing

Improvements welcome! Please:
1. Test changes thoroughly
2. Update documentation
3. Follow existing patterns
4. Consider backward compatibility

## License

Based on Coder templates - MIT License

## Support

- **Template Issues**: Open GitHub issue
- **Coder Platform**: Contact your Coder administrator
- **Claude Code**: https://claude.com/product/claude-code
- **DevContainers**: https://containers.dev/

---

**Happy coding with AI! 🚀🤖**
