# Unified DevOps Template - Verification Steps

## ✅ Completed Tasks

1. **Git Repository Initialized** ✓
   - Branch: `main`
   - Initial commit created

2. **GitHub Repository Created** ✓
   - Repository: https://github.com/julesintime/claude-coder-coworkspace
   - Code pushed successfully

3. **Coder Template Pushed** ✓
   - Template name: `unified-devops`
   - Organization: `coder`
   - Status: Available for workspace creation
   - Created: November 18, 2025

## 📝 Next Steps: Create Test Workspace

### Option 1: Via Coder Web UI (Recommended)

1. **Access Coder Dashboard**
   ```bash
   coder login --print-url
   ```
   Or directly access your Coder instance URL

2. **Create Workspace**
   - Click "Create Workspace" or "New Workspace"
   - Select template: **unified-devops**
   - Configure parameters:

   **Required Parameters:**
   - `cpu`: 4 cores (or your preference: 2, 4, 6, 8)
   - `memory`: 8 GB (or your preference: 4, 8, 12, 16, 32)
   - `home_disk_size`: 50 GB (default)

   **Optional AI Parameters** (leave empty if not using):
   - `claude_api_key`: Your Anthropic API key
   - `gemini_api_key`: Your Google AI API key
   - `github_token`: Your GitHub PAT
   - `gitea_url`: Your Gitea instance URL
   - `gitea_token`: Your Gitea token

3. **Wait for Provisioning** (2-5 minutes)
   - Kubernetes pod will be created
   - Envbox container will start
   - Docker-in-Docker will initialize
   - IDE modules will be configured

4. **Access Workspace**
   - Click "code-server" to open VS Code
   - Or SSH: `coder ssh <workspace-name>`

### Option 2: Via CLI (Advanced)

```bash
# Create workspace with minimal parameters
coder create my-test-workspace \
  --template unified-devops

# You'll be prompted for parameters interactively
# Or provide all parameters:
coder create my-test-workspace \
  --template unified-devops \
  --parameter cpu=4 \
  --parameter memory=8 \
  --parameter home_disk_size=50 \
  --parameter ai_prompt="" \
  --parameter claude_api_endpoint="" \
  --parameter claude_api_key="" \
  --parameter claude_oauth_token="" \
  --parameter gemini_api_key="" \
  --parameter github_token="" \
  --parameter gitea_url="" \
  --parameter gitea_token="" \
  --yes
```

## 🧪 Verification Checklist

Once your workspace is created, verify the following:

### 1. Basic Functionality
```bash
# SSH into workspace
coder ssh <workspace-name>

# Check Docker
docker --version
docker ps

# Check Kubernetes CLI
kubectl version --client

# Check AI tools
command -v claude && echo "Claude Code: ✓" || echo "Claude Code: ✗"
command -v gemini && echo "Gemini CLI: ✓" || echo "Gemini CLI: ✗"
command -v gh && echo "GitHub CLI: ✓" || echo "GitHub CLI: ✗"
command -v tea && echo "Gitea CLI: ✓" || echo "Gitea CLI: ✗"
```

### 2. Docker-in-Docker
```bash
# Test Docker
docker run hello-world

# Check Docker storage
docker system df
```

### 3. Bash Aliases
```bash
# Test aliases
cc-c --version   # Claude Code
dc --version     # Docker Compose
k version        # kubectl
workspace-info   # Workspace information
```

### 4. VS Code
- Open code-server from Coder dashboard
- Verify extensions are installed
- Check terminal access

### 5. GitHub External Authentication (Recommended)

If your Coder server has GitHub External Auth configured:

```bash
# Check if GitHub token is available from external auth
coder external-auth access-token primary-github

# Verify token is in environment
echo $GITHUB_TOKEN

# Test GitHub CLI authentication
gh auth status
```

**Note**: External auth is preferred over manual PAT because:
- Auto-refreshes tokens (no expiration)
- Works with GitHub Copilot extensions in code-server
- Requires one-time OAuth login per user

### 6. Authentication (if using manual tokens)
```bash
# Run authentication setup
bash ~/scripts/setup-ai-auth.sh

# Check environment variables
env | grep -E "CLAUDE|GEMINI|GITHUB|GITEA"
```

### 7. GitHub Copilot Extensions

If you have GitHub Copilot access and external auth configured:

```bash
# Open code-server from Coder dashboard
# Extensions should install automatically:
# - github.copilot
# - github.copilot-chat
# - eamodio.gitlens

# Copilot will use the GITHUB_TOKEN from external auth automatically
```

## 📊 Template Information

- **Template Name**: unified-devops
- **Version**: 1.0.0
- **Created**: November 18, 2025
- **GitHub**: https://github.com/julesintime/claude-coder-coworkspace
- **Organization**: coder

## 🎯 Features to Test

### Docker Capabilities
- [ ] Build Docker images
- [ ] Run containers
- [ ] Use docker-compose
- [ ] Persistent image storage

### AI Tools
- [ ] Claude Code (if configured)
- [ ] Gemini CLI (if configured)
- [ ] GitHub Copilot (if configured)

### Development Environment
- [ ] VS Code web IDE
- [ ] Terminal access
- [ ] Git operations
- [ ] File editing

### Kubernetes Integration
- [ ] kubectl access
- [ ] Cluster connectivity
- [ ] Resource management

## ⚠️ Known Issues

1. **CLI Version Mismatch**: Client v2.28.3, Server v2.27.1
   - This is a warning only, template works correctly
   - You can update the CLI to match if desired

2. **Parameter Prompts**: The `--yes` flag doesn't skip all parameter prompts
   - Use web UI for easier workspace creation
   - Or provide all parameters explicitly via CLI

## 📚 Additional Resources

- [QUICKSTART.md](QUICKSTART.md) - 10-minute quick start
- [README.md](README.md) - Complete documentation
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Production deployment
- [CLAUDE.md](CLAUDE.md) - AI assistant context

## 🎉 Success Criteria

Your workspace is successfully verified when:
- ✅ Docker commands work
- ✅ IDEs are accessible
- ✅ AI tools are functional (if configured)
- ✅ kubectl works
- ✅ Bash aliases work
- ✅ Persistent storage works across workspace restarts

---

**Status**: Template successfully pushed to Coder and ready for workspace creation!

**Next Action**: Create a workspace via Coder web UI and run the verification checklist above.
