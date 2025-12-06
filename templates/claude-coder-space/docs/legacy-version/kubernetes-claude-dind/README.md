# kubernetes-claude-dind

> **Docker-in-Docker + AI-Powered Development**  
> Full Docker support inside Kubernetes workspaces with Claude Code integration

## 🚀 Features

### Docker-in-Docker via Envbox
- ✅ Run `docker build`, `docker-compose up`, and full Docker workflows
- ✅ Secure containerization using Sysbox (no privileged inner containers)
- ✅ Persistent Docker cache and images across workspace restarts
- ✅ Systemd support for running services
- ✅ Full network device support (TUN/FUSE for VPN, SSHFS, etc.)

### AI-Powered Development
- ✅ **Claude Code** (v3.0.0) with MCP integration for automated task management
- ✅ **Workspace Presets** with system prompts and setup scripts
- ✅ Multiple IDE support: VS Code (code-server), Windsurf, Cursor, JetBrains
- ✅ Automated repository cloning and dev server startup

### Kubernetes Native
- ✅ Works on **K3s**, GKE, EKS, AKS, and any Kubernetes 1.19+
- ✅ Uses K3s `local-path` storage class by default (no special config)
- ✅ Persistent home directory and Docker data
- ✅ Resource limits (CPU, memory) via Kubernetes
- ✅ Pod anti-affinity for even workspace distribution

---

## 📋 Prerequisites

### Coder Control Plane
- Coder v2.27.1+ installed on Kubernetes
- PostgreSQL database (in-cluster or managed)
- Namespace for workspaces (e.g., `coder-workspaces`)

### Kubernetes Cluster
- Kubernetes 1.19+ (K3s recommended for self-hosted)
- Storage provisioner (K3s `local-path` works perfectly)
- Privileged containers allowed (envbox requirement)
- At least 4GB RAM and 2 CPU cores per workspace

### Authentication (Choose One)
- **Option 1**: Anthropic API Key ([Generate here](https://console.anthropic.com/settings/keys))
- **Option 2**: Claude OAuth Token (run `claude setup-token`)

---

## 🛠️ Installation

### 1. Deploy Coder on K3s

See the comprehensive [K3S_DEPLOYMENT_GUIDE.md](../K3S_DEPLOYMENT_GUIDE.md) for full instructions.

**Quick Start:**
```bash
# Create namespace
kubectl create namespace coder

# Install PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgresql bitnami/postgresql \
    --namespace coder \
    --set auth.username=coder \
    --set auth.password=coder \
    --set auth.database=coder \
    --set primary.persistence.storageClass=local-path

# Create DB secret
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:coder@postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"

# Install Coder
helm repo add coder-v2 https://helm.coder.com/v2
helm install coder coder-v2/coder \
    --namespace coder \
    --set coder.env[0].name=CODER_PG_CONNECTION_URL \
    --set coder.env[0].valueFrom.secretKeyRef.name=coder-db-url \
    --set coder.env[0].valueFrom.secretKeyRef.key=url \
    --set coder.env[1].name=CODER_ACCESS_URL \
    --set coder.env[1].value="http://coder.example.com"
```

### 2. Create Workspace Namespace

```bash
kubectl create namespace coder-workspaces
```

### 3. Push Template to Coder

```bash
# Login to Coder
coder login https://coder.example.com

# Push template
cd kubernetes-claude-dind
coder templates push kubernetes-claude-dind
```

### 4. Create a Workspace

```bash
# Via CLI
coder create my-dev-workspace --template kubernetes-claude-dind

# Or use the Coder dashboard
# https://coder.example.com → Create Workspace → kubernetes-claude-dind
```

---

## ⚙️ Configuration

### Template Variables

Edit these in the template or set during workspace creation:

| Variable | Default | Description |
|----------|---------|-------------|
| `cpu` | `4` | Number of CPU cores (2-8) |
| `memory` | `8` | Memory in GB (4-16) |
| `home_disk_size` | `30` | Home directory size in GB (includes Docker cache) |
| `container_image` | `codercom/enterprise-base:ubuntu` | Inner workspace image |
| `preview_port` | `3000` | Port for app preview |

### Authentication Parameters

Set these when creating a workspace:

- **`claude_api_key`**: Anthropic API key (if using API key auth)
- **`claude_oauth_token`**: OAuth token (if using Claude CLI auth)
- **`claude_api_endpoint`**: Custom API endpoint (optional)

### Kubernetes Variables

Edit `main.tf` directly:

```terraform
variable "use_kubeconfig" {
  default = false  # Set to false for Coder running inside K3s
}

variable "namespace" {
  default = "coder-workspaces"  # Namespace for workspaces
}
```

---

## 🐳 Using Docker-in-Docker

### Verify Docker Works

```bash
# SSH into workspace
coder ssh my-dev-workspace

# Check Docker
docker --version
docker ps

# Test build
echo "FROM alpine" > Dockerfile
docker build -t test .

# Run container
docker run hello-world
```

### Docker Compose Example

```yaml
# docker-compose.yml
version: '3.8'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
  web:
    image: nginx:latest
    ports:
      - "8080:80"
```

```bash
docker-compose up -d
docker-compose ps
```

### Persistent Docker Data

All Docker data persists across workspace restarts:
- **Images**: Cached in `/var/lib/docker` (PVC sub_path)
- **Containers**: Data in `/var/lib/containers` (PVC sub_path)
- **Volumes**: Stored in `/var/lib/coder/docker` (PVC sub_path)

---

## 🤖 AI Features

### Claude Code Integration

The template includes Claude Code v3.0.0 with:
- **Automated Task Reporting**: Progress updates via Coder MCP
- **System Prompts**: Pre-configured instructions for AI agent
- **Workspace Presets**: Quick-start templates with example apps

### MCP Tools Available

The workspace includes these MCP servers:
- **`@wonderwhy-er/desktop-commander`**: Run long-running commands (servers, watchers)
- **Playwright**: Browser automation for testing
- **Built-in Coder tools**: File operations, git, shell commands

### Using Claude Code

```bash
# Start Claude Code (automatic via agent module)
# Access via Coder dashboard → Tasks → Claude Code

# Example prompt:
"Create a Dockerfile for a Node.js app with Express"
```

---

## 🔍 Monitoring

The template includes built-in workspace metrics:

- **CPU Usage**: Current CPU utilization
- **RAM Usage**: Memory consumption
- **Home Disk**: Disk space usage
- **Docker Status**: Whether Docker daemon is running
- **Docker Containers**: Number of running containers

View in Coder dashboard → Workspace → Metrics

---

## 🐛 Troubleshooting

### Docker Not Working

**Symptom**: `docker ps` fails with connection error

**Solutions**:
1. Check envbox logs:
   ```bash
   kubectl logs -n coder-workspaces <pod-name> -c dev
   ```

2. Verify privileged mode:
   ```bash
   kubectl get pod <pod-name> -n coder-workspaces -o jsonpath='{.spec.containers[0].securityContext.privileged}'
   # Should return: true
   ```

3. Check volume mounts:
   ```bash
   kubectl describe pod <pod-name> -n coder-workspaces | grep Mounts -A 20
   ```

### Workspace Won't Start

**Symptom**: Pod stuck in Pending or CrashLoopBackOff

**Solutions**:
1. Check PVC status:
   ```bash
   kubectl get pvc -n coder-workspaces
   kubectl describe pvc coder-<workspace-id>-home -n coder-workspaces
   ```

2. Verify storage class:
   ```bash
   kubectl get storageclass
   # K3s should show: local-path (default)
   ```

3. Check pod events:
   ```bash
   kubectl describe pod <pod-name> -n coder-workspaces
   ```

### "error launch agent!" Status

**Symptom**: Workspace shows error in Coder dashboard

**Solutions**:
1. Check agent token:
   ```bash
   kubectl logs -n coder-workspaces <pod-name> -c dev | grep CODER_AGENT_TOKEN
   ```

2. Verify CODER_ACCESS_URL:
   ```bash
   # In Coder Helm values:
   coder:
     env:
       - name: CODER_ACCESS_URL
         value: "http://coder.example.com"  # Must be reachable from pods
   ```

3. Test connectivity from workspace:
   ```bash
   coder ssh <workspace-name>
   curl -I $CODER_AGENT_URL
   ```

### Out of Disk Space

**Symptom**: Docker builds fail with "no space left on device"

**Solutions**:
1. Increase `home_disk_size` parameter (default: 30GB)
2. Clean Docker cache:
   ```bash
   docker system prune -af
   docker volume prune -f
   ```

3. Check actual disk usage:
   ```bash
   df -h /home/coder
   du -sh /var/lib/docker
   ```

---

## 📚 Architecture

### Container Structure

```
┌─────────────────────────────────────────┐
│  Kubernetes Pod                         │
│  ┌───────────────────────────────────┐  │
│  │ OUTER Container (envbox)          │  │
│  │ - Privileged                      │  │
│  │ - ghcr.io/coder/envbox:latest     │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ INNER Container             │  │  │
│  │  │ - Non-privileged           │  │  │
│  │  │ - codercom/enterprise-base │  │  │
│  │  │ - Docker + Systemd         │  │  │
│  │  │ - Coder Agent              │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Volume Structure

```
PersistentVolumeClaim (local-path)
├── home/                          → /home/coder
├── cache/docker/                  → /var/lib/coder/docker
├── cache/containers/              → /var/lib/coder/containers
├── envbox/containers/             → /var/lib/containers
└── envbox/docker/                 → /var/lib/docker

EmptyDir (ephemeral)
└── sysbox/                        → /var/lib/sysbox

HostPath (readonly)
├── /usr/src                       → /usr/src
└── /lib/modules                   → /lib/modules
```

---

## 🔒 Security

### Outer Container (Envbox)
- **Privileged**: Yes (required for Sysbox runtime)
- **Purpose**: Manage inner container with Docker support
- **Isolation**: Sysbox provides strong namespace isolation

### Inner Container (Workspace)
- **Privileged**: No (runs unprivileged inside Sysbox)
- **Purpose**: User workspace with Docker access
- **Security**: Full container isolation via Sysbox

### Best Practices
1. **Use RBAC**: Limit who can create privileged pods
2. **Network Policies**: Restrict egress/ingress if needed
3. **Resource Limits**: Set CPU/memory limits per workspace
4. **PodSecurityPolicies**: Use PSP/PSA to control privileged pods
5. **Image Scanning**: Scan `codercom/enterprise-base` for vulnerabilities

---

## 📖 Additional Resources

- **Official Coder Docs**: https://coder.com/docs
- **Envbox Repository**: https://github.com/coder/envbox
- **Sysbox Runtime**: https://github.com/nestybox/sysbox
- **K3s Documentation**: https://k3s.io
- **Docker-in-Docker Solutions**: See [DOCKER_IN_DOCKER_SOLUTIONS.md](../DOCKER_IN_DOCKER_SOLUTIONS.md)
- **K3s Deployment Guide**: See [K3S_DEPLOYMENT_GUIDE.md](../K3S_DEPLOYMENT_GUIDE.md)

---

## 🤝 Contributing

Issues and pull requests welcome! This template is designed for:
- Self-hosted K3s Kubernetes deployments
- AI-powered development with Claude Code
- Full Docker-in-Docker support via Envbox

---

## 📝 License

This template is provided as-is for use with Coder. See Coder's license for terms.

---

## 🎯 Quick Commands Reference

```bash
# Template Management
coder templates push kubernetes-claude-dind
coder templates list
coder templates versions kubernetes-claude-dind

# Workspace Management
coder create my-workspace --template kubernetes-claude-dind
coder list
coder ssh my-workspace
coder stop my-workspace
coder start my-workspace
coder delete my-workspace

# Kubernetes Debugging
kubectl get pods -n coder-workspaces
kubectl logs -n coder-workspaces <pod-name> -c dev
kubectl describe pod -n coder-workspaces <pod-name>
kubectl get pvc -n coder-workspaces

# Docker Commands (Inside Workspace)
docker ps
docker images
docker system df
docker system prune -af
```

---

**Enjoy your AI-powered Docker-in-Docker development environment! 🚀**
