# Quick Start: kubernetes-claude-dind on K3s

> **Get Docker-in-Docker + AI-powered workspaces running in 15 minutes**

## 🎯 Prerequisites

- K3s cluster running (or any Kubernetes 1.19+)
- `kubectl` configured and working
- `helm` installed (v3+)
- Domain or IP for Coder access

## 🚀 Installation (5 Steps)

### Step 1: Deploy Coder Control Plane (5 min)

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

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n coder --timeout=300s

# Create database connection secret
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
    --set coder.env[1].value="http://YOUR_IP_OR_DOMAIN"

# Wait for Coder to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=coder -n coder --timeout=300s
```

### Step 2: Access Coder Dashboard (1 min)

```bash
# Get Coder URL
kubectl get svc -n coder coder

# Visit: http://<EXTERNAL-IP> or your configured domain
# Create your first user (admin)
```

### Step 3: Install Coder CLI (1 min)

```bash
# macOS
brew install coder

# Or download from: https://github.com/coder/coder/releases

# Login
coder login https://YOUR_CODER_URL
```

### Step 4: Create Workspace Namespace (30 sec)

```bash
kubectl create namespace coder-workspaces
```

### Step 5: Push Template and Create Workspace (3 min)

```bash
# Clone this repo (if not already)
cd kubernetes-claude-dind

# Push template to Coder
coder templates push kubernetes-claude-dind

# Create your first workspace
coder create my-dev-workspace --template kubernetes-claude-dind

# When prompted, enter your Anthropic API key or OAuth token
# Get API key: https://console.anthropic.com/settings/keys
```

## ✅ Verify Everything Works

```bash
# SSH into workspace
coder ssh my-dev-workspace

# Test Docker
docker --version
docker ps
docker run hello-world

# Test Docker build
cat << 'EOF' > Dockerfile
FROM alpine
RUN echo "Hello from Docker-in-Docker!"
EOF
docker build -t test .
docker run test

# Test Docker Compose
cat << 'EOF' > docker-compose.yml
version: '3.8'
services:
  hello:
    image: alpine
    command: echo "Docker Compose works!"
EOF
docker-compose up

# All good? You're ready to develop! 🎉
```

## 🎨 Access Your Workspace

### Via Web IDE
```
https://YOUR_CODER_URL/@YOUR_USERNAME/my-dev-workspace/apps/code-server
```

### Via SSH
```bash
coder ssh my-dev-workspace
```

### Via VS Code Remote
```bash
# Install Coder extension in VS Code
# Or use coder CLI:
coder code my-dev-workspace
```

## 🤖 Using Claude Code

Claude Code is automatically configured! Just start using it:

1. Go to Coder dashboard → Workspaces → Your workspace
2. Click "Tasks" tab
3. Enter a prompt like: "Create a Dockerfile for a Node.js Express app"
4. Watch Claude Code work!

## 📊 Monitor Your Workspace

Coder dashboard shows:
- ✅ CPU Usage
- ✅ RAM Usage  
- ✅ Disk Usage
- ✅ Docker Status
- ✅ Running Containers

## 🛠️ Common Commands

```bash
# List workspaces
coder list

# Stop workspace (saves resources)
coder stop my-dev-workspace

# Start workspace
coder start my-dev-workspace

# Update workspace (after template changes)
coder update my-dev-workspace

# Delete workspace
coder delete my-dev-workspace

# View workspace logs
kubectl logs -n coder-workspaces <pod-name> -c dev

# Check PVC
kubectl get pvc -n coder-workspaces
```

## 🐛 Troubleshooting

### Workspace stuck in "Starting"
```bash
# Check pod status
kubectl get pods -n coder-workspaces

# Check pod logs
kubectl logs -n coder-workspaces <pod-name> -c dev

# Check events
kubectl describe pod -n coder-workspaces <pod-name>
```

### Docker not working
```bash
# Inside workspace
docker info
sudo systemctl status docker  # If systemd is used

# Check envbox logs
kubectl logs -n coder-workspaces <pod-name> -c dev | grep envbox
```

### PVC not binding
```bash
# Check storage class
kubectl get storageclass

# Check PVC status
kubectl describe pvc -n coder-workspaces

# Verify local-path-provisioner
kubectl get pods -n kube-system | grep local-path
```

## 📖 Next Steps

- **Read full docs**: [README.md](./README.md)
- **K3s deployment guide**: [K3S_DEPLOYMENT_GUIDE.md](../K3S_DEPLOYMENT_GUIDE.md)
- **Docker-in-Docker solutions**: [DOCKER_IN_DOCKER_SOLUTIONS.md](../DOCKER_IN_DOCKER_SOLUTIONS.md)
- **Coder documentation**: https://coder.com/docs

## 🎓 Example Projects to Try

### 1. Containerized Node.js App
```bash
mkdir my-app && cd my-app
npm init -y
npm install express

cat << 'EOF' > index.js
const express = require('express');
const app = express();
app.get('/', (req, res) => res.send('Hello from Docker!'));
app.listen(3000, () => console.log('Server running on port 3000'));
EOF

cat << 'EOF' > Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
EOF

docker build -t my-app .
docker run -p 3000:3000 my-app
```

### 2. Docker Compose Full Stack
```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
  
  api:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis

volumes:
  pgdata:
```

### 3. Multi-Stage Build
```dockerfile
# Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm install --production
CMD ["node", "dist/index.js"]
```

## 💡 Pro Tips

1. **Use Docker BuildKit**: 
   ```bash
   export DOCKER_BUILDKIT=1
   docker build --progress=plain -t myapp .
   ```

2. **Clean up regularly**:
   ```bash
   docker system prune -af
   ```

3. **Use Docker Compose for dev**:
   ```bash
   docker-compose up -d  # Background
   docker-compose logs -f api  # Follow logs
   ```

4. **Persistent volumes**:
   - Your home directory (`/home/coder`) persists
   - Docker images persist across restarts
   - Docker volumes are persistent

5. **Resource limits**:
   - Adjust CPU/memory when creating workspace
   - Monitor usage in Coder dashboard
   - Increase disk size if needed (default: 30GB)

## 🎉 You're All Set!

You now have:
- ✅ Full Docker-in-Docker environment
- ✅ AI-powered development with Claude Code
- ✅ Multiple IDE options (VS Code, Windsurf, Cursor, JetBrains)
- ✅ Persistent workspace with Docker cache
- ✅ Running on your K3s cluster

**Happy coding! 🚀**
