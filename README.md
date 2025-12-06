# Coder Templates Monorepo

This repository hosts multiple Coder workspace templates with native Claude Code support.

## 📁 Repository Structure

```
coder-templates/
├── README.md                          # This file
├── .gitmodules                        # Git submodules configuration
│
├── templates/                         # All Coder templates
│   ├── claude-coder-space/           # Full-featured development workspace
│   └── claude-sandbox/                # Minimal quick-start sandbox
│
├── coder-dotfiles/                    # Git submodule
│   └── → https://github.com/julesintime/coder-dotfiles.git
│
└── docs/                              # Repository documentation
    └── legacy/                        # Archived documentation
```

## 📦 Available Templates

### 1. claude-coder-space (Full-Featured)

**Path**: `templates/claude-coder-space/`
**Type**: Production development environment

Complete workspace with:
- ✅ Kubernetes + Envbox (Docker-in-Docker)
- ✅ Multiple AI tools (Claude Code, Gemini CLI, GitHub Copilot)
- ✅ Multiple IDEs (VS Code, Cursor, Windsurf, JetBrains)
- ✅ Resource presets (nano/mini/mega: 1-16 CPU, 2-32GB RAM)
- ✅ Optional UI tools (File Browser, KasmVNC, Claude Code UI, Vibe Kanban)
- ✅ Full Docker-in-Docker support

**Resources**: Configurable (2-16 CPU, 2-32GB RAM)
**Startup**: ~60-90 seconds
**Best for**: Production development, complex projects, team collaboration

**Deploy**:
```bash
cd templates/claude-coder-space
coder templates push claude-coder-space
```

[→ View template README](templates/claude-coder-space/docs/README.md)

---

### 2. claude-sandbox (Minimal)

**Path**: `templates/claude-sandbox/`
**Type**: Quick-start sandbox

Minimal workspace for rapid experimentation:
- ⚡ Fast startup (~20-30 seconds)
- 🎯 Claude Code only
- 📦 Simple Kubernetes pod (no Envbox)
- 🔄 Provision-time prompt injection
- 💾 20GB persistent storage

**Resources**: Fixed (2 CPU, 4GB RAM)
**Startup**: ~20-30 seconds
**Best for**: Quick experiments, learning, prototyping, temporary tasks

**Deploy**:
```bash
cd templates/claude-sandbox
coder templates push claude-sandbox
```

**Usage**:
```bash
# Create workspace with initial prompt
coder create my-sandbox \
  --template claude-sandbox \
  --ai-prompt "Build a React todo app with TypeScript"
```

[→ View template README](templates/claude-sandbox/README.md)

---

## 🎯 Template Comparison

| Feature | claude-sandbox | claude-coder-space |
|---------|---------------|-------------------|
| **Startup Time** | ⚡ 20-30 seconds | 🐢 60-90 seconds |
| **Container** | Simple pod | Envbox (DinD) |
| **Resources** | 2 CPU, 4GB RAM | 2-16 CPU, 2-32GB RAM |
| **AI Tools** | Claude Code | Claude, Gemini, Copilot |
| **IDEs** | VS Code | VS Code, Cursor, Windsurf, JetBrains |
| **Docker Support** | ❌ No | ✅ Full Docker-in-Docker |
| **UI Tools** | ❌ No | ✅ File Browser, KasmVNC, etc. |
| **Complexity** | 🟢 Simple | 🟡 Advanced |
| **Use Case** | Experiments | Production development |

## 🔧 Dotfiles Strategy

Both templates use the **official dotfiles module** from `registry.coder.com`.

### Default Dotfiles Repository

**URL**: https://github.com/julesintime/coder-dotfiles.git (git submodule)

This repository provides:
- Common bash aliases and functions
- Tmux configuration
- Git setup helpers
- Claude Code statusline integration
- Gemini CLI installation

### Using Personal Dotfiles

Users can override with their own dotfiles:

1. **Create dotfiles repository**:
   ```bash
   my-dotfiles/
   ├── install.sh      # Auto-executed on workspace start
   ├── .bashrc         # Bash customization
   ├── .gitconfig      # Git configuration
   └── .tmux.conf      # Tmux settings
   ```

2. **Configure in Coder UI**:
   - Go to: Account → Settings → Dotfiles
   - Set URL: `https://github.com/username/my-dotfiles.git`
   - Restart workspace

3. **Dotfiles are fetched automatically** on workspace creation

[→ View default dotfiles](https://github.com/julesintime/coder-dotfiles)

## 🚀 Quick Start

### Prerequisites

- Coder CLI installed ([installation guide](https://coder.com/docs/install))
- Access to a Coder deployment
- Kubernetes cluster (for workspace deployment)

### Deploy Templates

```bash
# Clone this repository
git clone https://github.com/julesintime/coder-templates.git
cd coder-templates

# Initialize submodules (dotfiles)
git submodule update --init --recursive

# Deploy claude-coder-space (full-featured)
cd templates/claude-coder-space
coder templates push claude-coder-space

# Deploy claude-sandbox (minimal)
cd ../claude-sandbox
coder templates push claude-sandbox
```

### Create Workspace

```bash
# Full-featured workspace
coder create my-workspace --template claude-coder-space

# Minimal sandbox with prompt
coder create my-sandbox \
  --template claude-sandbox \
  --ai-prompt "Create a FastAPI REST API with PostgreSQL"
```

## 📖 Architecture

### Template Design Principles

1. ✅ **Official modules only**: All modules from `registry.coder.com`
2. ✅ **No custom modules**: Avoid maintenance overhead
3. ✅ **Dotfiles as submodule**: Isolated, version-controlled, shareable
4. ✅ **Native Claude Code**: Use default system prompts (coder-space) or custom (sandbox)
5. ✅ **Git history preserved**: All file moves use `git mv`

### Dotfiles as Git Submodule

The `coder-dotfiles/` directory is a **git submodule** pointing to:
- https://github.com/julesintime/coder-dotfiles.git

**Benefits**:
- ✅ Independent versioning
- ✅ Shared across templates
- ✅ Users can fork and customize
- ✅ Easy updates via `git submodule update`

**Update submodule**:
```bash
# Update to latest version
git submodule update --remote coder-dotfiles

# Commit the update
git add coder-dotfiles
git commit -m "chore: update dotfiles submodule"
```

### Module Philosophy

**We use ONLY official modules from `registry.coder.com`:**

| Module | Purpose | Version |
|--------|---------|---------|
| `claude-code` | AI coding assistant | `~> 4.2` |
| `code-server` | VS Code web IDE | `~> 1.0` |
| `dotfiles` | Personal dotfiles fetch | `~> 1.0` |
| `personalize` | Git config from Coder | `~> 1.0` |
| `filebrowser` | Web file manager | `~> 1.0` |
| `kasmvnc` | Desktop environment | `~> 1.2` |
| `cursor` | Cursor IDE | `~> 1.0` |
| `windsurf` | Windsurf IDE | `~> 1.0` |
| `jetbrains` | JetBrains IDEs | `~> 1.0` |
| `archive` | Workspace export | `~> 0.0` |

[→ Browse all modules](https://registry.coder.com)

## 🛠️ Development

### Adding a New Template

1. **Create template directory**:
   ```bash
   mkdir -p templates/my-new-template
   cd templates/my-new-template
   ```

2. **Create `main.tf`** (use official modules only):
   ```hcl
   terraform {
     required_providers {
       coder = {
         source  = "coder/coder"
         version = ">= 2.5.0"
       }
     }
   }

   # Use official modules
   module "claude-code" {
     source  = "registry.coder.com/coder/claude-code/coder"
     version = "~> 4.2"
     # ...
   }
   ```

3. **Create `README.md`** with:
   - Template description
   - Features and use cases
   - Quick start guide
   - Troubleshooting

4. **Test locally**:
   ```bash
   terraform init
   terraform validate
   terraform fmt

   # Dry-run push
   coder templates push my-template --directory . --dry-run
   ```

5. **Deploy**:
   ```bash
   coder templates push my-template --directory .
   ```

6. **Update monorepo README** (this file)

### Modifying Existing Templates

**⚠️ Important**: The `claude-coder-space` template is **production-ready**. Avoid breaking changes!

**Safe changes**:
- ✅ Add optional modules (with `count` conditional)
- ✅ Add new parameters
- ✅ Update module versions (patch/minor only)
- ✅ Improve documentation

**Dangerous changes**:
- ❌ Remove existing modules
- ❌ Change required parameters
- ❌ Modify resource names (breaks existing workspaces)
- ❌ Major version upgrades without testing

**Testing workflow**:
```bash
# Create test template
coder templates push claude-coder-space-test --directory templates/claude-coder-space

# Create test workspace
coder create test-workspace --template claude-coder-space-test

# Verify everything works
coder ssh test-workspace

# If good, update production
coder templates push claude-coder-space --directory templates/claude-coder-space
```

## 📚 Documentation

### Template-Specific Docs

- [claude-coder-space](templates/claude-coder-space/docs/)
  - [README](templates/claude-coder-space/docs/README.md) - Template overview
  - [DEPLOYMENT_GUIDE](templates/claude-coder-space/docs/DEPLOYMENT_GUIDE.md) - Deployment instructions
  - [QUICKSTART](templates/claude-coder-space/docs/QUICKSTART.md) - Quick start guide
  - Legacy documentation preserved in `docs/legacy-version/`

- [claude-sandbox](templates/claude-sandbox/README.md)
  - Quick-start guide
  - Configuration options
  - Troubleshooting

### External Resources

- [Coder Documentation](https://coder.com/docs)
- [Coder AI (Claude Code)](https://coder.com/docs/ai-coder)
- [Coder Templates Guide](https://coder.com/docs/templates)
- [Coder Modules Registry](https://registry.coder.com)
- [Terraform Coder Provider](https://registry.terraform.io/providers/coder/coder/latest/docs)

## 🤝 Contributing

### Contribution Guidelines

1. **Use official modules only** - No custom modules
2. **Preserve git history** - Use `git mv` for file moves
3. **Test before pushing** - Use `--dry-run` first
4. **Document changes** - Update READMEs
5. **Follow Terraform best practices**:
   - Use `terraform fmt`
   - Add comments for complex logic
   - Version lock with `~>` (allow patches)

### Pull Request Process

1. Fork this repository
2. Create feature branch: `git checkout -b feature/my-improvement`
3. Make changes (follow guidelines above)
4. Test thoroughly
5. Commit with clear messages
6. Push and create Pull Request
7. Wait for review

## 📋 Changelog

### v2.0.0 (Monorepo Refactor) - 2025-12-06
- ✨ Converted to monorepo structure
- ✨ Added `claude-sandbox` minimal template
- ✨ Converted `coder-dotfiles` to git submodule
- ♻️ Moved `claude-coder-space` to `templates/` (no code changes)
- 📝 Comprehensive documentation updates
- ✅ Git history preserved for all moves

### v1.x (Pre-Monorepo)
- See [claude-coder-space docs](templates/claude-coder-space/docs/) for historical changes

## 📄 License

MIT License - see LICENSE file

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/julesintime/coder-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/julesintime/coder-templates/discussions)
- **Coder Community**: [Coder Discord](https://coder.com/discord)

---

**Happy Coding!** 🚀

Built with ❤️ using [Coder](https://coder.com) and [Claude Code](https://coder.com/docs/ai-coder)
