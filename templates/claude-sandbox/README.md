# Claude Sandbox - Minimal Quick-Start Template

Fast, lightweight Kubernetes workspace for rapid Claude Code sessions and experimentation.

## Features

- ⚡ **Fast startup**: ~20-30 seconds (no Envbox overhead)
- 🎯 **Claude Code focused**: Primary tool for AI-assisted coding
- 📦 **Lightweight**: Simple Kubernetes pod (2 CPU, 4GB RAM)
- 🔄 **Prompt injection**: Provision-time prompts via `--ai-prompt`
- 👤 **Personal dotfiles**: Dynamic fetch from GitHub
- 💾 **Persistent storage**: 20GB PVC for workspace data

## Quick Start

### Create workspace with initial prompt

```bash
# Using Coder Tasks (recommended)
coder create my-sandbox \
  --template claude-sandbox \
  --ai-prompt "Build a React todo app with TypeScript"

# Without prompt (manual start)
coder create my-sandbox --template claude-sandbox
```

### Access workspace

```bash
# Via Coder CLI
coder ssh my-sandbox

# Via Web UI
# Open Coder dashboard → my-sandbox → Open in VS Code
```

## Configuration

### Container Image

Default: `codercom/enterprise-node:ubuntu` (includes Node.js, Python, git, curl)

Change during creation:
```bash
coder create my-sandbox \
  --template claude-sandbox \
  --parameter container_image="codercom/enterprise-base:ubuntu"
```

### Dotfiles

The template uses the official dotfiles module pointing to:
**Default**: https://github.com/julesintime/coder-dotfiles.git

Users can override with personal dotfiles:
1. Go to Coder UI → Account Settings → Dotfiles
2. Set your dotfiles repo URL: `https://github.com/username/dotfiles.git`
3. Restart workspace

**Example dotfiles structure**:
```
my-dotfiles/
├── install.sh      # Auto-executed on startup
├── .bashrc         # Bash customization
├── .gitconfig      # Git config template
└── .tmux.conf      # Tmux configuration
```

## System Prompt

The template includes a sandbox-specific system prompt that guides Claude Code:

```
You are Claude Code running in a minimal sandbox environment.

Environment details:
- Container: Ubuntu (lightweight)
- Kubernetes pod (simple, no Envbox)
- Resources: 2 CPU, 4GB RAM
- Tooling: Node.js, Python, git, curl, jq

Guidelines:
- Keep code simple and self-contained
- Avoid large dependencies
- Use external git repos for persistence
- Focus on rapid iteration and experimentation
```

## Included Tools

### AI Tools
- **Claude Code**: Primary AI coding assistant (Sonnet 4.5)

### IDEs
- **VS Code (code-server)**: Lightweight web-based editor

### Development Tools
- **Node.js**: JavaScript/TypeScript runtime
- **Python**: Python 3 interpreter
- **git**: Version control
- **curl, jq**: HTTP and JSON utilities

## Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 2 cores |
| Memory | 1GB | 4GB |
| Storage | 20GB (PVC) | 20GB |

## Use Cases

✅ **Perfect for**:
- Quick prototyping and experimentation
- Learning and tutorials
- Small projects and scripts
- Testing code snippets
- Temporary development tasks

❌ **Not suitable for**:
- Large multi-service applications
- Docker-in-Docker workflows
- Heavy compute tasks
- Production deployments
- Long-running services

For complex workflows, use the `claude-coder-space` template instead.

## Comparison with claude-coder-space

| Feature | claude-sandbox | claude-coder-space |
|---------|---------------|-------------------|
| **Startup Time** | 20-30 seconds | 60-90 seconds |
| **Container** | Simple pod | Envbox (Docker-in-Docker) |
| **Resources** | 2 CPU, 4GB RAM | 2-16 CPU, 2-32GB RAM |
| **AI Tools** | Claude Code only | Claude, Gemini, Copilot |
| **IDEs** | VS Code only | VS Code, Cursor, Windsurf, JetBrains |
| **Docker Support** | ❌ No | ✅ Full Docker-in-Docker |
| **Use Case** | Quick experiments | Production development |

## Troubleshooting

### Slow startup

```bash
# Check pod status
kubectl get pods -n coder-workspaces | grep $(coder list -o json | jq -r '.[0].id')

# Check pod events
kubectl describe pod -n coder-workspaces <pod-name>
```

### Claude Code not starting

```bash
# Check agent status
coder ssh my-sandbox "systemctl status coder-agent"

# Check Claude Code logs
coder ssh my-sandbox "journalctl -u claude-code -n 50"
```

### Dotfiles not applying

```bash
# Check dotfiles module logs
coder ssh my-sandbox "cat ~/.dotfiles.log"

# Manually trigger dotfiles install
coder ssh my-sandbox "bash ~/.dotfiles/install.sh"
```

## Advanced Usage

### Custom system prompt

Edit `templates/claude-sandbox/main.tf` and modify the `system_prompt` in the `claude-code` module.

### Add more modules

Browse official modules: https://registry.coder.com

Example - add File Browser:
```hcl
module "filebrowser" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/filebrowser/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/workspace"
}
```

### Increase resources

Edit `main.tf` in the `kubernetes_pod.main` resource:
```hcl
resources {
  limits = {
    cpu    = "4"      # Increase to 4 cores
    memory = "8Gi"    # Increase to 8GB
  }
}
```

## Deployment

```bash
# Push template to Coder
cd templates/claude-sandbox
coder templates push claude-sandbox

# Update existing template
coder templates push claude-sandbox --name claude-sandbox
```

## Links

- [Coder Documentation](https://coder.com/docs)
- [Claude Code Docs](https://coder.com/docs/ai-coder)
- [Coder Modules Registry](https://registry.coder.com)
- [Dotfiles Repository](https://github.com/julesintime/coder-dotfiles)

---

**Tip**: For Docker-in-Docker support and more advanced features, use the `claude-coder-space` template instead.
