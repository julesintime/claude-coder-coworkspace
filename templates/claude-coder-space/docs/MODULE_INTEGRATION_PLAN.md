# Coder Registry Module Integration Plan

**Status:** In Progress
**Phase:** Parameters added, ready for module integration
**Date:** 2025-11-18

## ✅ Completed

### 1. Module Research
- Researched 18+ Coder registry modules
- Identified available vs unavailable modules
- Documented parameters and requirements

### 2. Parameters Added (Lines 181-239 in main.tf)
- `openai_api_key` - For Codex module
- `dotfiles_repo_url` - For dotfiles module
- `git_clone_repo_url` - For git-clone module
- `git_clone_path` - Clone destination path
- `enable_filebrowser` - Toggle for filebrowser
- `enable_kasmvnc` - Toggle for KasmVNC desktop

## 🔄 Next Steps

### Step 1: Clean Startup Script
Remove sections that will be replaced by modules:

**Find and remove/comment:**
1. Tmux configuration (lines starting with "Configure tmux")
2. Gemini CLI npm installation (lines with `npm install -g @google/generative-ai-cli`)

**Keep:**
- System packages (apt-get install)
- kubectl, gh CLI, tea CLI installations
- Git configuration (no git-config module exists)

### Step 2: Add Module Blocks

Insert modules after line 690 (after MCP configuration script). Add in this order:

#### **Phase 1: Core AI Tools** (High Priority)
```terraform
# ========================================
# AI TOOL MODULES
# ========================================

# Gemini CLI (replaces npm installation)
module "gemini" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/gemini/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  api_key  = data.coder_parameter.gemini_api_key.value
}

# GitHub Copilot CLI
module "copilot" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/copilot/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

# OpenAI Codex CLI
module "codex" {
  count          = data.coder_parameter.openai_api_key.value != "" ? data.coder_workspace.me.start_count : 0
  source         = "registry.coder.com/coder-labs/codex/coder"
  version        = "~> 2.1"
  agent_id       = coder_agent.main.id
  openai_api_key = data.coder_parameter.openai_api_key.value
  folder         = "/home/coder/projects"
  ai_prompt      = data.coder_parameter.ai_prompt.value
}

# Goose AI Agent
module "goose" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/goose/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/projects"
}

# Cursor CLI
module "cursor-cli" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/cursor-cli/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}
```

#### **Phase 2: Configuration Modules**
```terraform
# ========================================
# CONFIGURATION MODULES
# ========================================

# Tmux with plugins (replaces bash config)
module "tmux" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/anomaly/tmux/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  # Enable mouse support as requested by user
}
```

#### **Phase 3: Developer Tools**
```terraform
# ========================================
# DEVELOPER TOOL MODULES
# ========================================

# Dotfiles (conditional on repo URL)
module "dotfiles" {
  count                = data.coder_parameter.dotfiles_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "~> 1.2"
  agent_id             = coder_agent.main.id
  default_dotfiles_uri = data.coder_parameter.dotfiles_repo_url.value
}

# Git Clone (conditional on repo URL)
module "git-clone" {
  count    = data.coder_parameter.git_clone_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_clone_repo_url.value
  base_dir = dirname(data.coder_parameter.git_clone_path.value)
}

# GitHub SSH Key Upload (conditional on GitHub auth)
module "github-upload-public-key" {
  count    = data.coder_external_auth.github.access_token != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/github-upload-public-key/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}
```

#### **Phase 4: Optional UI/Tools**
```terraform
# ========================================
# OPTIONAL UI/TOOL MODULES
# ========================================

# File Browser (conditional toggle)
module "filebrowser" {
  count    = data.coder_parameter.enable_filebrowser.value ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/filebrowser/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# KasmVNC Desktop (conditional toggle)
module "kasmvnc" {
  count                = data.coder_parameter.enable_kasmvnc.value ? data.coder_workspace.me.start_count : 0
  source               = "registry.coder.com/coder/kasmvnc/coder"
  version              = "~> 1.0"
  agent_id             = coder_agent.main.id
  desktop_environment  = "xfce"
}

# Archive Tool
module "archive" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/archive/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}
```

### Step 3: Validation
```bash
cd /home/coder/projects/claude-coder-space
terraform fmt
terraform validate
```

### Step 4: Commit & Deploy
```bash
git add main.tf MODULE_INTEGRATION_PLAN.md
git commit -m "feat: add Coder registry modules for AI tools and dev experience"
git push
coder templates push unified-devops --directory . --yes
```

### Step 5: Test
Create a test workspace and verify all modules install correctly.

## 📝 Notes

**Modules NOT Added (Not Available):**
- `git-config` - Doesn't exist; use dotfiles or environment variables
- `devcontainers-cli` - In development, not yet available
- `zed` - Feature request open, not implemented
- `mux` - Not a Terraform module (desktop app)
- `local-windows-rdp` - Platform-specific, skipped

**Module Versions:**
- Using `~> X.Y` version constraints to allow patch updates
- Check registry.coder.com for latest versions before deploying

**Performance Considerations:**
- KasmVNC is resource-intensive (disabled by default)
- Multiple AI tools may increase startup time
- Consider phased rollout to users

## 🎯 Expected Benefits

1. **Cleaner Template** - Less bash scripting, more declarative modules
2. **Faster Workspace Startup** - Optimized registry modules
3. **Better Maintainability** - Use community-tested modules
4. **More AI Tools** - Copilot, Codex, Goose, Gemini, Cursor all available
5. **Enhanced Developer Experience** - Dotfiles, git-clone, filebrowser

## 🔗 Resources

- Coder Registry: https://registry.coder.com/modules
- Coder Modules GitHub: https://github.com/coder/modules
- Module Research Doc: (agent research output above)
