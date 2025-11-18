# Unified DevOps Template - Quick Start Guide

Get up and running in 10 minutes!

## Prerequisites

✅ Kubernetes cluster (K3s, GKE, EKS, AKS)
✅ kubectl configured
✅ Helm 3 installed
✅ (Optional) GitHub OAuth App for external auth
✅ (Optional) API keys for AI tools (Claude, Gemini, GitHub)

---

## 5-Step Quick Start

### Step 1: Install Coder (3 minutes)

```bash
# Create namespace
kubectl create namespace coder

# Install PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install coder-db bitnami/postgresql \
  --namespace coder \
  --set auth.username=coder \
  --set auth.password=coder \
  --set auth.database=coder

# Create database secret
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
  --set coder.env[1].value="http://localhost:3000"

# Wait for Coder to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=coder -n coder --timeout=300s
```

### Step 2: Access Coder Dashboard (1 minute)

```bash
# Port forward to access locally
kubectl port-forward -n coder svc/coder 3000:80

# Open browser to http://localhost:3000
# Create admin account when prompted
```

### Step 3: Install Coder CLI (1 minute)

```bash
# Install CLI
curl -L https://coder.com/install.sh | sh

# Login
coder login http://localhost:3000
```

### Step 4: Create Workspace Namespace (30 seconds)

```bash
kubectl create namespace coder-workspaces
```

### Step 5: Deploy Template & Create Workspace (5 minutes)

```bash
# Push template
cd unified-devops-template
coder templates push unified-devops

# Create workspace with AI tools
coder create my-workspace \
  --template unified-devops \
  --parameter cpu=4 \
  --parameter memory=8 \
  --parameter claude_api_key=sk-ant-... \
  --parameter gemini_api_key=AIza... \
  --parameter github_token=ghp_...

# Wait for workspace to start (2-5 minutes)
coder list

# SSH into workspace
coder ssh my-workspace
```

---

## Verify Installation

Inside your workspace:

```bash
# Check Docker
docker --version
docker ps

# Check Kubernetes
kubectl version --client

# Check AI tools
cc-c --version        # Claude Code
gemini --version      # Gemini CLI (if configured)
gh --version          # GitHub CLI

# Check authentication
bash ~/scripts/setup-ai-auth.sh

# Run workspace info
workspace-info
```

---

## Quick Test

### Test Docker

```bash
docker run hello-world
```

### Test Claude Code

```bash
cc-c "create a simple Python hello world script"
```

### Test Kubernetes

```bash
kubectl version
kubectl get nodes
```

### Test Git

```bash
git config --list
gh auth status
```

---

## Next Steps

1. **Read the full documentation**: [README.md](README.md)
2. **Configure external auth**: See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
3. **Customize the template**: Edit [main.tf](main.tf)
4. **Set up CI/CD**: Integrate with your Git provider
5. **Explore AI features**: Try different AI assistants

---

## Troubleshooting

### Workspace won't start

```bash
# Check pod status
kubectl get pods -n coder-workspaces

# View pod logs
kubectl logs -n coder-workspaces <pod-name>

# Check PVC
kubectl get pvc -n coder-workspaces
```

### Docker not working

```bash
# Inside workspace
docker info

# Check if Envbox is running
ps aux | grep envbox
```

### AI tools not working

```bash
# Check environment variables
env | grep -E "CLAUDE|GEMINI|GITHUB"

# Re-run authentication setup
bash ~/scripts/setup-ai-auth.sh
```

---

## Production Deployment

For production, consider:

1. **External database**: Use managed PostgreSQL (RDS, Cloud SQL, Azure Database)
2. **TLS/HTTPS**: Configure ingress with TLS certificates
3. **External auth**: Set up GitHub/GitLab/OIDC OAuth
4. **High availability**: Run multiple Coder replicas
5. **Monitoring**: Set up Prometheus/Grafana
6. **Backups**: Automated database and PVC backups

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for details.

---

## Support

- **Documentation**: [README.md](README.md)
- **Deployment**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **AI Context**: [CLAUDE.md](CLAUDE.md)
- **Coder Docs**: https://coder.com/docs
- **Community**: https://discord.gg/coder

---

**You're ready to start coding!** 🚀
