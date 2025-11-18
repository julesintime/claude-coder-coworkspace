# Unified DevOps Coder Template - Documentation Index

## Quick Links

### Getting Started (Choose One)
- 🚀 **[QUICKSTART.md](QUICKSTART.md)** - Get running in 10 minutes
- 📖 **[README.md](README.md)** - Complete user documentation
- 🏗️ **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Production deployment

### Reference
- 🤖 **[CLAUDE.md](CLAUDE.md)** - AI assistant context
- 📊 **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical overview

---

## Documentation Overview

### QUICKSTART.md (3KB)
**For**: New users wanting to test quickly
**Time**: 10 minutes
**Content**:
- Prerequisites checklist
- 5-step installation
- Verification steps
- Quick tests
- Troubleshooting basics

**Start here if**: You want to try the template quickly on a test cluster.

---

### README.md (17KB)
**For**: Users and administrators
**Time**: 30 minutes to read, reference guide
**Content**:
- Complete feature overview
- Prerequisites and requirements
- Quick start guide
- Configuration options
- Usage examples
- Architecture details
- Troubleshooting (20+ issues)
- Advanced usage
- Security considerations
- Performance optimization
- FAQ

**Start here if**: You're deploying for actual use and want to understand all features.

---

### DEPLOYMENT_GUIDE.md (18KB)
**For**: Platform administrators
**Time**: 1-2 hours to deploy
**Content**:
- K3s deployment (step-by-step)
- GKE deployment (step-by-step)
- EKS deployment (step-by-step)
- External authentication setup
- AI tools configuration
- Post-deployment verification
- Troubleshooting deployment
- Upgrading procedures
- Backup & restore
- Security hardening
- Production checklist

**Start here if**: You're deploying to production or managed Kubernetes.

---

### CLAUDE.md (9KB)
**For**: AI assistants and developers
**Time**: Reference material
**Content**:
- System architecture overview
- Available tools and commands
- Bash aliases reference
- Environment variables
- Usage guidelines for AI
- Tool selection decision tree
- Project structure
- Best practices
- Troubleshooting

**Start here if**: You're an AI assistant or want to understand the development workflow.

---

### PROJECT_SUMMARY.md (13KB)
**For**: Technical stakeholders
**Time**: 20 minutes
**Content**:
- Executive summary
- Technical specifications
- Features matrix
- Implementation details
- File structure
- Comparison with legacy templates
- Usage scenarios
- Performance characteristics
- Security features
- Testing & validation
- Version history

**Start here if**: You need a technical overview or are evaluating the template.

---

## Template Files

### main.tf (25KB)
**Purpose**: Terraform template for Coder
**Content**:
- Provider configuration
- Workspace parameters (12+)
- Coder agent configuration
- AI modules integration
- IDE modules (4)
- Kubernetes resources (Pod, PVC)
- Environment variables
- Apps and monitoring

**Lines**: 800+

---

### Scripts

#### scripts/setup-ai-auth.sh (3KB)
**Purpose**: Configure AI tools and authentication
**Features**:
- GitHub CLI authentication
- Gitea CLI authentication
- Claude Code verification
- Gemini CLI verification
- Git configuration
- kubectl setup
- MCP servers configuration
- Status summary

#### scripts/install-tools.sh (4KB)
**Purpose**: Install optional development tools
**Features**:
- Homebrew installation
- Zsh and Oh My Zsh
- Development tools (htop, fzf, ripgrep, etc.)
- Docker Compose
- Kubernetes tools (helm, k9s, kubectx)
- Language tools (nvm, poetry, rust)
- Interactive menu

---

### Configuration Files

#### .vscode/extensions.json
**Purpose**: VS Code extension recommendations
**Count**: 20+ extensions
**Categories**:
- Language support (Python, Go, C++)
- DevOps tools (Kubernetes, Docker, Terraform)
- AI assistants (Copilot)
- Git tools (GitLens)
- Code quality (ESLint, Prettier)

#### .vscode/settings.json
**Purpose**: VS Code configuration
**Settings**: 40+
**Categories**:
- Editor preferences
- Formatting rules
- Language-specific settings
- Git integration
- Docker & Kubernetes
- GitHub Copilot

#### .gitignore
**Purpose**: Git ignore patterns
**Categories**:
- Terraform files
- Coder files
- IDE files
- Secrets
- Build artifacts

---

## File Statistics

```
Total Files: 11
Total Size: 144KB
Documentation: 60KB (5 files)
Code: 25KB (main.tf)
Scripts: 7KB (2 files)
Configuration: 2KB (3 files)
```

---

## Reading Path by Role

### 👨‍💻 Developer
1. [QUICKSTART.md](QUICKSTART.md) - Get started
2. [CLAUDE.md](CLAUDE.md) - Understand workflow
3. [README.md](README.md) - Reference as needed

### 👨‍💼 Administrator
1. [README.md](README.md) - Understand features
2. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Deploy to production
3. [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Technical details

### 🤖 AI Assistant
1. [CLAUDE.md](CLAUDE.md) - Your primary context
2. [README.md](README.md) - Feature reference
3. [main.tf](main.tf) - Template understanding

### 📊 Decision Maker
1. [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Technical overview
2. [README.md](README.md) - Features and capabilities
3. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Implementation requirements

---

## Common Tasks

### I want to...

**Try the template quickly**
→ [QUICKSTART.md](QUICKSTART.md)

**Deploy to production**
→ [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

**Configure GitHub authentication**
→ [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#external-authentication-configuration)

**Set up AI tools**
→ [README.md](README.md#configuration) + [scripts/setup-ai-auth.sh](scripts/setup-ai-auth.sh)

**Understand the architecture**
→ [README.md](README.md#architecture) or [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md#technical-specifications)

**Troubleshoot an issue**
→ [README.md](README.md#troubleshooting) or [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting-deployment)

**Customize the template**
→ [README.md](README.md#advanced-usage) + [main.tf](main.tf)

**Learn about AI capabilities**
→ [CLAUDE.md](CLAUDE.md#available-tools)

**Compare with other templates**
→ [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md#comparison-with-legacy-templates)

**See what's new**
→ [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md#version-history)

---

## Support Resources

### Documentation
- This template's README and guides
- [Coder Documentation](https://coder.com/docs)
- [Envbox Repository](https://github.com/coder/envbox)
- [Claude Code Docs](https://claude.com/product/claude-code)

### Community
- [Coder Discord](https://discord.gg/coder)
- [Coder GitHub](https://github.com/coder/coder)
- Template issues: (your repository)

### Commercial Support
- Coder Enterprise Support
- Professional Services
- Custom Development

---

## Version Information

- **Current Version**: 1.0.0
- **Release Date**: 2025-01-18
- **Status**: Production-Ready
- **Compatibility**: Coder v2.27.1+, Kubernetes 1.19+

---

## Quick Reference Card

```bash
# Template Operations
coder templates push unified-devops      # Deploy template
coder templates list                     # List templates
coder create my-workspace                # Create workspace

# Workspace Operations
coder list                               # List workspaces
coder ssh my-workspace                   # SSH into workspace
coder stop my-workspace                  # Stop workspace
coder start my-workspace                 # Start workspace

# Inside Workspace
cc-c                                     # Claude Code
gemini                                   # Gemini CLI
gh copilot                               # GitHub Copilot
docker ps                                # Docker status
kubectl get pods                         # Kubernetes
workspace-info                           # Show workspace info
bash ~/scripts/setup-ai-auth.sh         # Setup authentication
```

---

**Navigation**:
[⬆️ Top](#unified-devops-coder-template---documentation-index) |
[📖 README](README.md) |
[🚀 Quick Start](QUICKSTART.md) |
[🏗️ Deployment](DEPLOYMENT_GUIDE.md)
