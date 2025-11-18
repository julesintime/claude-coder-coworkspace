# Unified DevOps Template - Deployment Guide

## Overview

This guide walks you through deploying the Unified DevOps Coder template on various Kubernetes platforms with external authentication and AI tool integration.

---

## Deployment Scenarios

### Scenario 1: K3s Self-Hosted (Recommended for Testing)

Perfect for local development, homelab, or small teams.

#### Prerequisites
- K3s cluster running
- kubectl configured
- Helm 3 installed

#### Step-by-Step Deployment

**1. Install PostgreSQL**

```bash
# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create Coder namespace
kubectl create namespace coder

# Install PostgreSQL
helm install coder-db bitnami/postgresql \
  --namespace coder \
  --set auth.username=coder \
  --set auth.password=coder \
  --set auth.database=coder \
  --set primary.persistence.storageClass=local-path \
  --set primary.persistence.size=10Gi

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n coder --timeout=300s
```

**2. Create Database URL Secret**

```bash
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"
```

**3. Configure GitHub External Auth (Optional)**

Create a GitHub OAuth App:
- Go to https://github.com/settings/developers
- Click "New OAuth App"
- Fill in:
  - Application name: `Coder DevOps`
  - Homepage URL: `https://coder.example.com` (your Coder URL)
  - Callback URL: `https://coder.example.com/external-auth/primary-github/callback`
- Note the Client ID and Client Secret

**4. Install Coder with External Auth**

```bash
# Add Coder Helm repository
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update

# Install Coder with GitHub external auth
helm install coder coder-v2/coder \
  --namespace coder \
  --set coder.env[0].name=CODER_PG_CONNECTION_URL \
  --set coder.env[0].valueFrom.secretKeyRef.name=coder-db-url \
  --set coder.env[0].valueFrom.secretKeyRef.key=url \
  --set coder.env[1].name=CODER_ACCESS_URL \
  --set coder.env[1].value="https://coder.example.com" \
  --set coder.env[2].name=CODER_EXTERNAL_AUTH_0_ID \
  --set coder.env[2].value="primary-github" \
  --set coder.env[3].name=CODER_EXTERNAL_AUTH_0_TYPE \
  --set coder.env[3].value="github" \
  --set coder.env[4].name=CODER_EXTERNAL_AUTH_0_CLIENT_ID \
  --set coder.env[4].value="<your-github-client-id>" \
  --set coder.env[5].name=CODER_EXTERNAL_AUTH_0_CLIENT_SECRET \
  --set coder.env[5].value="<your-github-client-secret>"

# Wait for Coder to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=coder -n coder --timeout=300s
```

**5. Create Workspace Namespace**

```bash
kubectl create namespace coder-workspaces
```

**6. Configure Ingress (K3s Traefik)**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: coder
  namespace: coder
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
  - host: coder.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: coder
            port:
              number: 80
  tls:
  - hosts:
    - coder.example.com
    secretName: coder-tls
EOF
```

**7. Deploy Template**

```bash
# Install Coder CLI
curl -L https://coder.com/install.sh | sh

# Login to Coder
coder login https://coder.example.com

# Push template
cd unified-devops-template
coder templates push unified-devops
```

---

### Scenario 2: Google Kubernetes Engine (GKE)

#### Prerequisites
- GKE cluster created
- gcloud CLI installed
- kubectl configured for GKE

#### Step-by-Step Deployment

**1. Configure kubectl for GKE**

```bash
# Get cluster credentials
gcloud container clusters get-credentials CLUSTER_NAME --region REGION

# Verify connection
kubectl cluster-info
```

**2. Create GKE Workload Identity (for GitHub auth)**

```bash
# Create service account
gcloud iam service-accounts create coder-sa \
  --display-name="Coder Service Account"

# Bind to Kubernetes service account
kubectl create namespace coder

kubectl create serviceaccount coder-ksa -n coder

gcloud iam service-accounts add-iam-policy-binding \
  coder-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[coder/coder-ksa]"

kubectl annotate serviceaccount coder-ksa -n coder \
  iam.gke.io/gcp-service-account=coder-sa@PROJECT_ID.iam.gserviceaccount.com
```

**3. Install Cloud SQL Proxy (Alternative to in-cluster PostgreSQL)**

```bash
# Create Cloud SQL instance (via console or gcloud)
# Then install proxy

kubectl create secret generic cloudsql-instance-credentials \
  --from-file=credentials.json=PATH_TO_SERVICE_ACCOUNT_KEY.json \
  -n coder

# Deploy proxy sidecar with Coder (see GKE-specific Helm values)
```

**4. Install Coder on GKE**

```bash
# Create GKE-specific values file
cat > coder-values.yaml <<EOF
coder:
  serviceAccount:
    name: coder-ksa

  env:
    - name: CODER_PG_CONNECTION_URL
      value: "postgres://coder:PASSWORD@127.0.0.1:5432/coder"
    - name: CODER_ACCESS_URL
      value: "https://coder.example.com"
    - name: CODER_EXTERNAL_AUTH_0_ID
      value: "primary-github"
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "github"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "YOUR_GITHUB_CLIENT_ID"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      value: "YOUR_GITHUB_CLIENT_SECRET"

  extraContainers:
    - name: cloudsql-proxy
      image: gcr.io/cloudsql-docker/gce-proxy:latest
      command:
        - "/cloud_sql_proxy"
        - "-instances=PROJECT_ID:REGION:INSTANCE_NAME=tcp:5432"
        - "-credential_file=/secrets/cloudsql/credentials.json"
      volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /secrets/cloudsql
          readOnly: true

  extraVolumes:
    - name: cloudsql-instance-credentials
      secret:
        secretName: cloudsql-instance-credentials

ingress:
  enabled: true
  host: coder.example.com
  tls:
    enabled: true
    secretName: coder-tls
EOF

# Install Coder
helm install coder coder-v2/coder \
  --namespace coder \
  --values coder-values.yaml
```

**5. Configure GKE Ingress**

```bash
# Install cert-manager for TLS
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: gce
EOF
```

---

### Scenario 3: Amazon EKS

#### Prerequisites
- EKS cluster created
- AWS CLI configured
- kubectl configured for EKS

#### Step-by-Step Deployment

**1. Configure kubectl for EKS**

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region REGION \
  --name CLUSTER_NAME

# Verify connection
kubectl cluster-info
```

**2. Install RDS PostgreSQL (Recommended for EKS)**

```bash
# Create RDS instance via AWS Console or CLI
# Note the endpoint URL

# Create secret with connection string
kubectl create secret generic coder-db-url -n coder \
  --from-literal=url="postgres://coder:PASSWORD@RDS_ENDPOINT:5432/coder"
```

**3. Configure IAM Roles for Service Accounts (IRSA)**

```bash
# Create IAM OIDC provider for cluster
eksctl utils associate-iam-oidc-provider \
  --cluster CLUSTER_NAME \
  --approve

# Create IAM role for Coder service account
eksctl create iamserviceaccount \
  --name coder-sa \
  --namespace coder \
  --cluster CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
  --approve
```

**4. Install Coder on EKS**

```bash
# Create EKS-specific values
cat > coder-eks-values.yaml <<EOF
coder:
  serviceAccount:
    create: false
    name: coder-sa

  env:
    - name: CODER_PG_CONNECTION_URL
      valueFrom:
        secretKeyRef:
          name: coder-db-url
          key: url
    - name: CODER_ACCESS_URL
      value: "https://coder.example.com"
    - name: CODER_EXTERNAL_AUTH_0_ID
      value: "primary-github"
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "github"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "YOUR_GITHUB_CLIENT_ID"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      value: "YOUR_GITHUB_CLIENT_SECRET"

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
EOF

# Install Coder
kubectl create namespace coder
helm install coder coder-v2/coder \
  --namespace coder \
  --values coder-eks-values.yaml
```

**5. Configure Application Load Balancer**

```bash
# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=CLUSTER_NAME

# Create Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: coder
  namespace: coder
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:REGION:ACCOUNT:certificate/CERT_ID
spec:
  rules:
  - host: coder.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: coder
            port:
              number: 80
EOF
```

---

## External Authentication Configuration

### GitHub External Auth

**Required Scopes:**
- `repo` - Repository access
- `read:user` - User profile read
- `user:email` - Email access
- `read:org` - Organization read (optional)
- `copilot` - GitHub Copilot access (if using)

**Configuration:**

```bash
# In Coder Helm values or environment
CODER_EXTERNAL_AUTH_0_ID="primary-github"
CODER_EXTERNAL_AUTH_0_TYPE="github"
CODER_EXTERNAL_AUTH_0_CLIENT_ID="<client-id>"
CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="<client-secret>"
CODER_EXTERNAL_AUTH_0_REVOKE_URL="https://api.github.com/applications/<client-id>/grant"
```

### GitHub Enterprise

For self-hosted GitHub:

```bash
CODER_EXTERNAL_AUTH_0_ID="github-enterprise"
CODER_EXTERNAL_AUTH_0_TYPE="github"
CODER_EXTERNAL_AUTH_0_CLIENT_ID="<client-id>"
CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="<client-secret>"
CODER_EXTERNAL_AUTH_0_AUTH_URL="https://github.enterprise.com/login/oauth/authorize"
CODER_EXTERNAL_AUTH_0_TOKEN_URL="https://github.enterprise.com/login/oauth/access_token"
CODER_EXTERNAL_AUTH_0_VALIDATE_URL="https://github.enterprise.com/api/v3/user"
```

### Multiple Git Providers

Configure multiple external auth providers:

```bash
# GitHub.com
CODER_EXTERNAL_AUTH_0_ID="github-public"
CODER_EXTERNAL_AUTH_0_TYPE="github"
...

# GitHub Enterprise
CODER_EXTERNAL_AUTH_1_ID="github-enterprise"
CODER_EXTERNAL_AUTH_1_TYPE="github"
...

# GitLab
CODER_EXTERNAL_AUTH_2_ID="gitlab"
CODER_EXTERNAL_AUTH_2_TYPE="gitlab"
...
```

---

## AI Tools Configuration

### Claude Code Setup

**Option 1: API Key**

1. Get API key from https://console.anthropic.com/settings/keys
2. When creating workspace, enter in `claude_api_key` parameter
3. Environment variable `CLAUDE_API_KEY` will be set automatically

**Option 2: OAuth Token**

1. Run `claude setup-token` locally
2. Copy the token
3. When creating workspace, enter in `claude_oauth_token` parameter
4. Environment variable `CLAUDE_CODE_OAUTH_TOKEN` will be set automatically

### Gemini CLI Setup

1. Get API key from https://aistudio.google.com/apikey
2. When creating workspace, enter in `gemini_api_key` parameter
3. Environment variable `GOOGLE_AI_API_KEY` will be set automatically

### GitHub Copilot Setup

1. Ensure you have GitHub Copilot subscription
2. Create GitHub PAT with `copilot` scope
3. When creating workspace, enter in `github_token` parameter
4. GitHub CLI will be automatically authenticated
5. Use `gh copilot` commands

---

## Workspace Creation

### Via CLI

```bash
# Basic workspace
coder create my-workspace --template unified-devops

# With parameters
coder create my-workspace \
  --template unified-devops \
  --parameter cpu=8 \
  --parameter memory=16 \
  --parameter claude_api_key=sk-ant-... \
  --parameter gemini_api_key=AIza... \
  --parameter github_token=ghp_...
```

### Via Web UI

1. Navigate to Coder dashboard
2. Click "Create Workspace"
3. Select "unified-devops" template
4. Configure parameters:
   - **Resources**: CPU, Memory, Disk
   - **AI Tools**: Claude, Gemini API keys
   - **Git Auth**: GitHub, Gitea tokens
5. Click "Create Workspace"
6. Wait for provisioning (2-5 minutes)
7. Access via code-server, SSH, or other IDEs

---

## Post-Deployment Verification

### Verify Coder Installation

```bash
# Check Coder pods
kubectl get pods -n coder

# Check Coder service
kubectl get svc -n coder

# Check Coder logs
kubectl logs -n coder -l app.kubernetes.io/name=coder
```

### Verify Workspace

```bash
# List workspaces
coder list

# SSH into workspace
coder ssh my-workspace

# Inside workspace, verify:
docker --version
kubectl version --client
claude --version
gemini --version
gh --version
tea --version
```

### Verify Authentication

```bash
# Inside workspace
bash /home/coder/scripts/setup-ai-auth.sh

# Check GitHub auth
gh auth status

# Check environment variables
env | grep -E "CLAUDE|GEMINI|GITHUB|GITEA"
```

---

## Troubleshooting Deployment

### Coder Pod Won't Start

```bash
# Check pod status
kubectl describe pod -n coder -l app.kubernetes.io/name=coder

# Common issues:
# - Database connection failed
# - PVC not bound
# - Image pull errors

# Verify database connection
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql "postgres://coder:coder@coder-db-postgresql.coder.svc.cluster.local:5432/coder"
```

### External Auth Not Working

```bash
# Check Coder environment variables
kubectl get deployment coder -n coder -o yaml | grep -A 20 env

# Verify callback URL matches OAuth app
# Should be: https://coder.example.com/external-auth/<ID>/callback

# Check Coder logs for auth errors
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i auth
```

### Workspace Creation Fails

```bash
# Check workspace pod events
kubectl describe pod -n coder-workspaces <pod-name>

# Common issues:
# - Privileged containers not allowed
# - Storage class not found
# - Resource limits too high

# Verify storage class exists
kubectl get storageclass

# Check if privileged pods allowed
kubectl auth can-i create pod/privileged -n coder-workspaces
```

---

## Upgrading

### Upgrade Coder

```bash
# Update Helm repository
helm repo update

# Upgrade Coder
helm upgrade coder coder-v2/coder \
  --namespace coder \
  --reuse-values

# Or with new values
helm upgrade coder coder-v2/coder \
  --namespace coder \
  --values coder-values.yaml
```

### Update Template

```bash
# Pull latest template
git pull

# Push updated template
coder templates push unified-devops

# Existing workspaces will update on next start
```

---

## Backup & Restore

### Backup Coder Database

```bash
# PostgreSQL backup
kubectl exec -n coder coder-db-postgresql-0 -- \
  pg_dump -U coder coder > coder-backup-$(date +%Y%m%d).sql

# Restore
kubectl exec -i -n coder coder-db-postgresql-0 -- \
  psql -U coder coder < coder-backup-20250118.sql
```

### Backup Workspace Data

```bash
# From inside workspace
tar -czf ~/workspace-backup-$(date +%Y%m%d).tar.gz ~/projects

# Or via PVC snapshot (Kubernetes-dependent)
kubectl snapshot create \
  -n coder-workspaces \
  coder-<workspace-id>-home-snapshot \
  --pvc coder-<workspace-id>-home
```

---

## Security Hardening

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: coder-workspaces-policy
  namespace: coder-workspaces
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: coder
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

### Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: coder-workspaces
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: workspace-quota
  namespace: coder-workspaces
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    persistentvolumeclaims: "50"
```

---

## Production Checklist

- [ ] PostgreSQL database is highly available (managed service or StatefulSet)
- [ ] TLS/HTTPS configured with valid certificates
- [ ] External authentication configured (GitHub/GitLab/OIDC)
- [ ] Resource quotas set on workspace namespace
- [ ] Network policies configured
- [ ] Backup strategy implemented
- [ ] Monitoring and alerting configured
- [ ] Pod security policies/standards enforced
- [ ] Ingress/Load balancer configured
- [ ] DNS configured correctly
- [ ] Workspace auto-stop configured
- [ ] Template versioning strategy defined
- [ ] User onboarding documentation created

---

## Support

For issues during deployment:

1. Check Coder documentation: https://coder.com/docs
2. Review Kubernetes cluster logs
3. Verify all prerequisites are met
4. Check GitHub issues: https://github.com/coder/coder/issues
5. Join Coder Discord: https://discord.gg/coder

---

**Deployment Guide Complete!** 🎉

You should now have a fully functional Coder deployment with the Unified DevOps template ready for your team.
