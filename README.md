# Unified DevOps Coder Template

> **Production-Ready Cloud Development Environment**
> Docker-in-Docker + Multi-AI + Kubernetes + Full DevOps Toolchain

## Features

### Core Infrastructure
- **Docker-in-Docker** via Envbox (Sysbox) for secure containerization
- **Kubernetes-native** deployment with proper resource management
- **Persistent storage** for home directory, Docker images, and caches
- **Resource limits** configurable CPU (2-8 cores) and memory (4-32GB)

### AI-Powered Development
- **Claude Code** (latest module version) - Primary AI assistant with Coder Tasks integration
- **Gemini CLI** - Google's AI for research and alternative perspectives
- **GitHub Copilot CLI** - GitHub's AI assistant (requires subscription)
- **Multi-agent workflow** - Leverage different AI tools for different tasks

### Authentication & CLI Tools
- **GitHub External Auth** - OAuth integration for repositories and Copilot
- **GitHub CLI (gh)** - Authenticated GitHub operations
- **Gitea CLI (tea)** - Self-hosted Git platform integration
- **Automatic authentication** - Tokens configured via workspace parameters

### Development Environment
- **VS Code (code-server)** - Pre-configured web IDE with 20+ extensions
- **Cursor, Windsurf, JetBrains** - Multiple IDE options
- **Docker & Docker Compose** - Full containerization support
- **kubectl & Kubernetes tools** - Cloud-native development ready
- **Bash aliases** - 30+ productivity shortcuts

### DevOps Toolchain
- **Container orchestration** - Docker + Kubernetes
- **CI/CD ready** - GitHub Actions, GitLab CI integration
- **Infrastructure as Code** - Terraform, Helm support
- **Monitoring** - Built-in workspace metrics

---

## Prerequisites

### Required
- **Coder** v2.27.1+ running on Kubernetes
- **Kubernetes** 1.19+ cluster (K3s, GKE, EKS, AKS, etc.)
- **Storage provisioner** (K3s local-path works perfectly)
- **Privileged containers** allowed (for Envbox)
- **Namespace** for workspaces (default: `coder-workspaces`)

### Recommended Resources
- **Per Workspace**: 4GB RAM, 2 CPU cores minimum
- **Storage**: 50GB+ for home directory and Docker cache
- **Network**: Cluster networking with LoadBalancer or Ingress

### Optional (Enable Features)
- **Claude Code**: Anthropic API key or OAuth token
- **Gemini CLI**: Google AI API key
- **GitHub**: Personal access token with repo and copilot scopes
- **Gitea**: Instance URL and access token

---

## Quick Start

### 1. Deploy Coder (if not already running)

For K3s deployment:

```bash
# Create Coder namespace
kubectl create namespace coder

# Install PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install coder-db bitnami/postgresql \
  --namespace coder \
  --set auth.username=coder \
  --set auth.password=coder \
  --set auth.database=coder

# Create database URL secret
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"

# Install Coder
helm repo add coder-v2 https://helm.coder.com/v2
helm install coder coder-v2/coder \
  --namespace coder \
  --set coder.env[0].name=CODER_PG_CONNECTION_URL \
  --set coder.env[0].valueFrom.secretKeyRef.name=coder-db-url \
  --set coder.env[0].valueFrom.secretKeyRef.key=url \
  --set coder.env[1].name=CODER_ACCESS_URL \
  --set coder.env[1].value="https://coder.example.com"
```

### 2. Create Workspace Namespace

```bash
kubectl create namespace coder-workspaces
```

### 3. Configure GitHub External Auth (Optional)

Create GitHub OAuth App at https://github.com/settings/applications/new

```bash
# Set Coder environment variables
CODER_EXTERNAL_AUTH_0_ID="primary-github"
CODER_EXTERNAL_AUTH_0_TYPE="github"
CODER_EXTERNAL_AUTH_0_CLIENT_ID="<your-client-id>"
CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="<your-client-secret>"
```

Callback URL: `https://coder.example.com/external-auth/primary-github/callback`

### 4. Push Template to Coder

```bash
# Install Coder CLI
curl -L https://coder.com/install.sh | sh

# Login to Coder
coder login https://coder.example.com

# Push template
cd unified-devops-template
coder templates push unified-devops
```

### 5. Create Workspace

Via CLI:
```bash
coder create my-workspace --template unified-devops
```

Via Web UI:
1. Navigate to https://coder.example.com
2. Click "Create Workspace"
3. Select "unified-devops" template
4. Configure parameters (CPU, memory, API keys)
5. Click "Create"

---

## Configuration

### Workspace Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cpu` | 4 | CPU cores (2, 4, 6, 8) |
| `memory` | 8 | Memory in GB (4, 8, 12, 16, 32) |
| `home_disk_size` | 50 | Home disk size in GB (10-500) |
| `container_image` | `codercom/enterprise-base:ubuntu` | Inner container image |
| `preview_port` | 3000 | Application preview port |

### Authentication Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `claude_api_key` | Optional | Anthropic API key ([Get one](https://console.anthropic.com/settings/keys)) |
| `claude_oauth_token` | Optional | Claude OAuth token (alternative to API key) |
| `claude_api_endpoint` | Optional | Custom API endpoint |
| `gemini_api_key` | Optional | Google Gemini API key ([Get one](https://aistudio.google.com/apikey)) |
| `github_token` | Optional | GitHub PAT ([Generate](https://github.com/settings/tokens)) |
| `gitea_url` | Optional | Gitea instance URL |
| `gitea_token` | Optional | Gitea access token |

### Advanced Configuration

Edit `system_prompt` parameter to customize AI behavior:

```hcl
data "coder_parameter" "system_prompt" {
  default = <<-EOT
    Your custom system prompt here...
  EOT
}
```

Edit `setup_script` parameter to customize workspace initialization.

---

## Usage

### Accessing the Workspace

```bash
# SSH into workspace
coder ssh my-workspace

# Port forward (if needed)
coder port-forward my-workspace --tcp 3000:3000

# Open VS Code
# Click "code-server" in Coder dashboard
```

### Using AI Tools

#### Claude Code
```bash
# Primary AI assistant (alias)
cc-c

# Full command
claude

# With prompt
claude "create a Dockerfile for Node.js app"
```

#### Gemini CLI
```bash
# Start Gemini chat
gemini-chat

# Or use full command
gemini "explain this code"
```

#### GitHub Copilot
```bash
# Explain command
gh copilot explain "kubectl get pods"

# Suggest command
gh copilot suggest "deploy to kubernetes"
```

### Docker Operations

```bash
# Verify Docker
docker --version
docker ps

# Build image
docker build -t myapp .

# Run container
docker run -d -p 8080:80 myapp

# Docker Compose
docker-compose up -d

# Clean up
dclean  # Alias for docker system prune -af
```

### Kubernetes Operations

```bash
# Check cluster
kubectl cluster-info

# Get resources
k get pods  # Alias
kgp         # Alias for kubectl get pods

# Deploy application
kubectl apply -f deployment.yaml

# Port forward
kubectl port-forward pod/myapp 8080:80
```

### Git & GitHub

```bash
# Git operations (auto-configured)
gs    # git status
ga .  # git add
gc -m "message"  # git commit
gp    # git push

# GitHub CLI
gh repo create
gh pr create
gh issue list
```

---

## Project Structure

```
unified-devops-template/
├── main.tf                    # Terraform template
├── README.md                  # This file
├── CLAUDE.md                  # AI context and guidelines
├── .vscode/                   # VS Code configuration
│   ├── extensions.json        # Recommended extensions
│   └── settings.json          # Editor settings
└── scripts/                   # Utility scripts
    ├── setup-ai-auth.sh       # Authentication setup
    └── install-tools.sh       # Optional tools installer
```

---

## Architecture

### Envbox Container Structure

The workspace runs in a nested container architecture:

```
Kubernetes Pod
└─ Outer Container (Envbox - Privileged)
   ├─ Sysbox runtime
   └─ Inner Container (Workspace - Non-privileged)
      ├─ Ubuntu base with dev tools
      ├─ Docker daemon (via Sysbox)
      ├─ Coder agent
      ├─ AI CLI tools
      └─ Your code
```

### Storage Architecture

```
PVC: coder-<workspace-id>-home (50GB default)
├─ home/                    # User workspace (/home/coder)
├─ cache/docker/            # Docker layer cache
├─ cache/containers/        # Container cache
├─ envbox/containers/       # Envbox containers
└─ envbox/docker/           # Docker images & volumes
```

### Network Architecture

```
User → Coder Dashboard → Workspace Pod
                       ├─ code-server (VS Code)
                       ├─ Claude Code UI
                       ├─ App Preview
                       └─ Terminal (SSH)
```

---

## Troubleshooting

### Docker Issues

**Problem**: `docker ps` fails with connection error

**Solution**:
```bash
# Check if Docker daemon is running
docker info

# Check Envbox logs
kubectl logs -n coder-workspaces <pod-name> -c dev | grep -i docker

# Verify privileged mode
kubectl get pod <pod-name> -n coder-workspaces -o yaml | grep privileged
```

### Workspace Won't Start

**Problem**: Pod stuck in Pending or CrashLoopBackOff

**Solution**:
```bash
# Check PVC status
kubectl get pvc -n coder-workspaces

# Describe PVC for issues
kubectl describe pvc coder-<workspace-id>-home -n coder-workspaces

# Check pod events
kubectl describe pod <pod-name> -n coder-workspaces

# View pod logs
kubectl logs <pod-name> -n coder-workspaces
```

### AI Tools Not Working

**Problem**: AI commands fail or not authenticated

**Solution**:
```bash
# Run authentication setup
bash /home/coder/scripts/setup-ai-auth.sh

# Check environment variables
env | grep -E "CLAUDE|GEMINI|GITHUB"

# Verify API keys in Coder dashboard
# Go to Workspace → Parameters → Edit

# Test individual tools
claude --version
gemini --version
gh auth status
```

### Out of Disk Space

**Problem**: "no space left on device" errors

**Solution**:
```bash
# Check disk usage
df -h /home/coder
du -sh /var/lib/docker

# Clean Docker cache
docker system prune -af
docker volume prune -f

# Increase disk size (requires workspace rebuild)
# Edit workspace parameters → home_disk_size
```

### kubectl Not Working

**Problem**: Cannot connect to Kubernetes cluster

**Solution**:
```bash
# Check if running in cluster
kubectl cluster-info

# If external cluster, configure kubeconfig
mkdir -p ~/.kube
# Copy your kubeconfig to ~/.kube/config

# Verify permissions
kubectl auth can-i get pods --all-namespaces
```

---

## Advanced Usage

### Custom MCP Servers

Add custom MCP servers to `~/.config/coder/mcp/config.json`:

```json
{
  "mcpServers": {
    "desktop-commander": {
      "command": "desktop-commander",
      "enabled": true
    },
    "custom-server": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "enabled": true
    }
  }
}
```

### Install Additional Tools

```bash
# Run interactive installer
bash /home/coder/scripts/install-tools.sh

# Available options:
# - Development tools (htop, ripgrep, fzf, etc.)
# - Kubernetes tools (helm, k9s, kubectx)
# - Language tools (nvm, poetry, rust)
# - Zsh and Oh My Zsh
# - Homebrew
```

### Custom Docker Images

Edit the `container_image` parameter in `main.tf`:

```hcl
data "coder_parameter" "container_image" {
  default = "your-registry.com/custom-image:tag"
}
```

Build custom images with pre-installed tools:

```dockerfile
FROM codercom/enterprise-base:ubuntu

# Install additional tools
RUN apt-get update && apt-get install -y \
    your-tools-here

# Pre-install language runtimes
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get install -y nodejs

USER coder
```

### Kubernetes Access Configuration

For workspaces to access the Kubernetes cluster:

1. **In-cluster access** (recommended):
   - Workspace pod automatically gets service account token
   - kubectl configured automatically

2. **External cluster access**:
   - Set `use_kubeconfig = true` in variables
   - Mount kubeconfig as secret

---

## Security Considerations

### Container Security

- **Outer container**: Privileged (required for Envbox/Sysbox)
- **Inner container**: Non-privileged (your workspace)
- **Isolation**: Sysbox provides strong namespace isolation

### Best Practices

1. **Use RBAC**: Limit who can create workspaces
2. **Network Policies**: Restrict pod-to-pod communication
3. **Resource Quotas**: Set namespace limits
4. **Pod Security**: Use PodSecurityPolicies or PodSecurityAdmission
5. **Secrets Management**: Use Kubernetes secrets for tokens
6. **Image Scanning**: Scan base images regularly
7. **Audit Logging**: Enable Kubernetes audit logs

### API Key Management

- Store API keys as workspace parameters (encrypted at rest)
- Never commit API keys to version control
- Rotate keys regularly
- Use OAuth tokens when possible

---

## Performance Optimization

### Resource Allocation

```hcl
# Recommended settings for different workloads

# Lightweight (web development)
cpu    = "2"
memory = "4"

# Medium (full-stack)
cpu    = "4"
memory = "8"

# Heavy (AI/ML, large builds)
cpu    = "8"
memory = "16"
```

### Storage Optimization

```bash
# Periodic cleanup (add to cron)
docker system prune -af --volumes
docker image prune -af

# Increase disk size if needed
# Edit workspace → Parameters → home_disk_size
```

### Network Optimization

- Use Coder's built-in reverse proxy for apps
- Enable subdomain isolation
- Configure CDN for static assets

---

## Monitoring & Observability

### Built-in Metrics

The template includes automatic metrics collection:

- CPU Usage (container & host)
- Memory Usage (container & host)
- Disk Usage (home directory)
- Docker Status
- Container Count
- AI Tools Status

View in: Coder Dashboard → Workspace → Metrics

### Custom Metrics

Add custom metrics in `main.tf`:

```hcl
metadata {
  display_name = "Custom Metric"
  key          = "custom_metric"
  script       = "echo 'value'"
  interval     = 60
  timeout      = 5
}
```

---

## Migration Guide

### From kubernetes-claude-dind

1. Template already includes all DinD features
2. Update workspace parameters with new names
3. Re-authenticate AI tools if needed

### From kubernetes-tasks

1. All task features included
2. Additional AI tools now available
3. Configure new authentication parameters

### From Other Templates

1. Export your code: `tar -czf backup.tar.gz ~/projects`
2. Create new workspace from this template
3. Import code: `tar -xzf backup.tar.gz -C ~/`

---

## Contributing

Improvements and extensions welcome!

### Adding New Features

1. Fork the template
2. Add features to `main.tf`
3. Update `CLAUDE.md` with AI guidelines
4. Update `README.md` with documentation
5. Test thoroughly
6. Submit pull request

### Testing Changes

```bash
# Validate Terraform
terraform init
terraform validate

# Test deployment
coder templates push unified-devops-test

# Create test workspace
coder create test-ws --template unified-devops-test
```

---

## FAQ

**Q: Can I use this without AI tools?**
A: Yes! All AI parameters are optional. Skip them during workspace creation.

**Q: Does this work on managed Kubernetes (GKE/EKS/AKS)?**
A: Yes, as long as privileged containers are allowed.

**Q: Can I use multiple Gemini/Claude accounts?**
A: Yes, configure different API keys per workspace.

**Q: How do I update the template?**
A: Run `coder templates push unified-devops` again.

**Q: Can I customize the base image?**
A: Yes, edit the `container_image` parameter.

**Q: Is Docker data persistent?**
A: Yes, all Docker images and volumes persist in the PVC.

**Q: Can I run systemd services?**
A: Yes, Sysbox supports systemd inside containers.

**Q: What's the resource overhead of Envbox?**
A: Minimal (~500MB RAM, ~0.5 CPU for outer container).

**Q: Can I use this for production workloads?**
A: This is a development environment. For production, deploy to the cluster.

---

## Changelog

### v1.0.0 (2025-01-18)
- Initial unified template release
- Envbox Docker-in-Docker support
- Claude Code module (v4.x)
- Gemini CLI integration
- GitHub Copilot CLI support
- GitHub external auth
- Gitea CLI integration
- Multi-IDE support (VS Code, Cursor, Windsurf, JetBrains)
- Pre-configured bash aliases
- Comprehensive documentation

---

## License

This template is provided as-is for use with Coder.
See Coder's license for terms: https://coder.com/legal/terms-of-service

---

## Support & Resources

- **Coder Docs**: https://coder.com/docs
- **Coder Community**: https://discord.gg/coder
- **Envbox**: https://github.com/coder/envbox
- **Claude Code**: https://claude.com/product/claude-code
- **Gemini CLI**: https://github.com/google-gemini/gemini-cli
- **GitHub CLI**: https://cli.github.com/
- **Kubernetes**: https://kubernetes.io/docs/

---

**Built with by the Coder community** 🚀

For questions or issues, please consult the documentation or reach out to your Coder administrator.
