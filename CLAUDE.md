# Unified DevOps Coder Template - AI Context

## Overview

This is a comprehensive, unified Coder template designed for modern DevOps workflows. It combines the best features from multiple template approaches to provide a complete cloud development environment with:

- **Full Docker-in-Docker support** via Envbox
- **Multiple AI assistants** (Claude Code, Gemini CLI, GitHub Copilot)
- **Kubernetes integration** for cloud-native development
- **Pre-configured authentication** for GitHub, Gitea, and AI services
- **Professional IDE setup** with VS Code, Cursor, Windsurf, and JetBrains

## Architecture

### Container Structure

```
┌─────────────────────────────────────────────────┐
│  Kubernetes Pod                                 │
│  ┌───────────────────────────────────────────┐  │
│  │ Outer Container (Envbox)                  │  │
│  │ - Privileged mode for Docker support     │  │
│  │ - ghcr.io/coder/envbox:latest            │  │
│  │                                           │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │ Inner Container                     │  │  │
│  │  │ - Non-privileged workspace          │  │  │
│  │  │ - codercom/enterprise-base:ubuntu   │  │  │
│  │  │ - Full Docker + systemd support     │  │  │
│  │  │ - All AI tools installed            │  │  │
│  │  │ - Coder agent running               │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Storage Layout

```
PersistentVolumeClaim (PVC)
├── home/                          → /home/coder (user workspace)
├── cache/docker/                  → /var/lib/coder/docker
├── cache/containers/              → /var/lib/coder/containers
├── envbox/containers/             → /var/lib/containers
└── envbox/docker/                 → /var/lib/docker (Docker images & volumes)

EmptyDir (ephemeral)
└── sysbox/                        → /var/lib/sysbox (Sysbox runtime)

HostPath (read-only)
├── /usr/src                       → /usr/src (kernel sources)
└── /lib/modules                   → /lib/modules (kernel modules)
```

## Available Tools

### AI Assistants

1. **Claude Code** (Primary)
   - Command: `claude` or `cc-c` (alias)
   - Full Coder Tasks integration
   - Automatic task reporting to Coder UI
   - Model: Claude Sonnet 4.5

2. **Gemini CLI**
   - Command: `gemini` or `gemini-chat`
   - Google's AI for alternative perspectives
   - Great for research and code generation

3. **GitHub Copilot CLI** (if configured)
   - Command: `gh copilot`
   - GitHub's AI assistant
   - Requires GitHub subscription

### Development Tools

- **Docker**: Full Docker-in-Docker via Envbox
  - `docker`, `docker-compose` available
  - Persistent image cache
  - `dc` alias for docker-compose

- **Kubernetes**: kubectl pre-installed
  - `kubectl` or `k` (alias)
  - Pre-configured cluster access
  - Helm, k9s available via install-tools.sh

- **Git & CI/CD**:
  - GitHub CLI (`gh`) with authentication
  - Gitea CLI (`tea`) with authentication
  - GitLens for VS Code

### IDEs Available

- VS Code (code-server) - Primary web IDE
- Cursor - AI-native editor
- Windsurf - Modern code editor
- JetBrains IDEs - Professional IDE suite

## Bash Aliases

The following aliases are pre-configured:

```bash
# AI Tools
cc-c          # Claude Code
cc            # Claude Code (short)
gemini-chat   # Gemini CLI
copilot       # GitHub Copilot CLI

# Docker
dc            # docker-compose
dps           # docker ps
di            # docker images
dclean        # docker system prune -af

# Kubernetes
k             # kubectl
kgp           # kubectl get pods
kgs           # kubectl get svc
kdp           # kubectl describe pod

# Git
gs            # git status
ga            # git add
gc            # git commit
gp            # git push
gl            # git log --oneline

# GitHub
ghpr          # gh pr
ghissue       # gh issue

# Utilities
workspace-info # Display workspace information
```

## Environment Variables

The following environment variables are automatically configured:

### Git Configuration
- `GIT_AUTHOR_NAME` - Your full name from Coder
- `GIT_AUTHOR_EMAIL` - Your email from Coder
- `GIT_COMMITTER_NAME` - Same as author name
- `GIT_COMMITTER_EMAIL` - Same as author email

### AI Tool Authentication
- `CLAUDE_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` - Claude authentication
- `ANTHROPIC_BASE_URL` - Custom API endpoint (optional)
- `GOOGLE_AI_API_KEY` - Gemini API key
- `GITHUB_TOKEN` / `GH_TOKEN` - GitHub authentication

### Gitea (if configured)
- `GITEA_URL` - Gitea instance URL
- `GITEA_TOKEN` - Gitea access token

## Usage Guidelines

### For AI Assistants

When working in this environment, you should:

1. **Use Docker for services**: Run databases, web servers, and other services in Docker containers
   ```bash
   docker-compose up -d
   ```

2. **Use Kubernetes for deployments**: Deploy applications to the cluster
   ```bash
   kubectl apply -f deployment.yaml
   ```

3. **Leverage multiple AI tools**:
   - Use Claude Code for primary development
   - Use Gemini for research and alternative approaches
   - Use Copilot for quick code completions

4. **Follow DevOps best practices**:
   - Containerize applications
   - Use Infrastructure as Code (Terraform, Helm)
   - Implement CI/CD pipelines
   - Version control everything

### Tool Selection Decision Tree

```
┌─ Task requires long-running process (server, watcher)?
│  └─ YES → Use Docker (docker-compose up -d)
│  └─ NO → Continue...
│
├─ Task requires cluster interaction?
│  └─ YES → Use kubectl
│  └─ NO → Continue...
│
├─ Task requires file operations or builds?
│  └─ YES → Use built-in tools (git, npm, pip, etc.)
│  └─ NO → Continue...
│
└─ Task requires complex reasoning or planning?
   └─ Use appropriate AI tool (Claude, Gemini, Copilot)
```

## Project Structure

```
/home/coder/projects/           # Main workspace directory
├── .vscode/                    # VS Code configuration
│   ├── extensions.json         # Recommended extensions
│   └── settings.json           # Editor settings
├── scripts/                    # Utility scripts
│   ├── setup-ai-auth.sh       # AI tools authentication
│   └── install-tools.sh       # Optional tools installer
└── [your-projects]/           # Your code repositories
```

## Troubleshooting

### Docker not working

```bash
# Check Docker status
docker info

# Verify Envbox container
kubectl get pods -n coder-workspaces

# Check logs
kubectl logs -n coder-workspaces <pod-name> -c dev
```

### AI tools not authenticated

```bash
# Run authentication setup
bash ~/scripts/setup-ai-auth.sh

# Verify environment variables
env | grep -E "CLAUDE|GEMINI|GITHUB|GITEA"
```

### kubectl not connecting

```bash
# Check cluster access
kubectl cluster-info

# Verify kubeconfig
ls -la ~/.kube/

# Test with simple command
kubectl version --client
```

## Best Practices

1. **Version Control**: Commit early and often
   ```bash
   ga .
   gc -m "feat: add new feature"
   gp
   ```

2. **Docker Cleanup**: Clean up regularly to save disk space
   ```bash
   dclean
   ```

3. **Use AI Wisely**:
   - Ask Claude Code for implementation
   - Use Gemini for research and alternatives
   - Verify AI suggestions before committing

4. **Kubernetes Resources**: Clean up unused resources
   ```bash
   kubectl delete pod <old-pod>
   ```

5. **Persistence**: Remember that only /home/coder is persistent
   - Store all code in ~/projects
   - Docker images persist automatically
   - Install user-level tools in ~/.local

## Additional Resources

- **Coder Documentation**: https://coder.com/docs
- **Envbox**: https://github.com/coder/envbox
- **Claude Code**: https://claude.com/product/claude-code
- **Gemini CLI**: https://github.com/google-gemini/gemini-cli
- **GitHub CLI**: https://cli.github.com/

## Support

For issues with:
- **Template**: Check the README.md
- **Coder Platform**: Contact your Coder administrator
- **AI Tools**: Refer to respective documentation
- **Kubernetes**: Check cluster documentation

---

**Happy Coding!** 🚀
