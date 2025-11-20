terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

# ========================================
# CODER TASK DATA SOURCE
# ========================================

# Required for AI Tasks - provides task metadata including the prompt
data "coder_task" "me" {}

# ========================================
# VARIABLES
# ========================================

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces. A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder-workspaces"
}

# ========================================
# WORKSPACE PARAMETERS
# ========================================

# Workspace presets - these define all parameter values for each preset
# See https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets
data "coder_workspace_preset" "nano" {
  name = "Nano (1CPU/2GB/20GB)"
  parameters = {
    preset                = "nano"
    container_image       = "codercom/enterprise-node:ubuntu"
    preview_port          = "3000"
    git_clone_repo_url    = ""
    git_clone_path        = "/home/coder/projects/repo"
    enable_filebrowser    = "true"
    enable_kasmvnc        = "false"
    enable_claude_code_ui = "true"
    enable_vibe_kanban    = "true"
    claude_code_ui_port   = "38401"
    vibe_kanban_port      = "38402"
    gitea_url             = ""
  }
}

data "coder_workspace_preset" "mini" {
  name    = "Mini (2CPU/8GB/50GB)"
  default = true
  parameters = {
    preset                = "mini"
    container_image       = "codercom/enterprise-node:ubuntu"
    preview_port          = "3000"
    git_clone_repo_url    = ""
    git_clone_path        = "/home/coder/projects/repo"
    enable_filebrowser    = "true"
    enable_kasmvnc        = "false"
    enable_claude_code_ui = "true"
    enable_vibe_kanban    = "true"
    claude_code_ui_port   = "38401"
    vibe_kanban_port      = "38402"
    gitea_url             = ""
  }
}

data "coder_workspace_preset" "mega" {
  name = "Mega (16CPU/32GB/200GB)"
  parameters = {
    preset                = "mega"
    container_image       = "codercom/enterprise-node:ubuntu"
    preview_port          = "3000"
    git_clone_repo_url    = ""
    git_clone_path        = "/home/coder/projects/repo"
    enable_filebrowser    = "true"
    enable_kasmvnc        = "false"
    enable_claude_code_ui = "true"
    enable_vibe_kanban    = "true"
    claude_code_ui_port   = "38401"
    vibe_kanban_port      = "38402"
    gitea_url             = ""
  }
}

data "coder_parameter" "preset" {
  name         = "preset"
  display_name = "Workspace Preset"
  description  = "Choose a preset (can be overridden by individual CPU/RAM/Disk below)"
  default      = "mini"
  type         = "string"
  icon         = "/icon/gear.svg"
  mutable      = true
  ephemeral    = false # Persist preset selection across restarts

  option {
    name        = "nano"
    description = "Nano: 1 CPU, 2GB RAM, 20GB disk"
    value       = "nano"
  }

  option {
    name        = "mini"
    description = "Mini: 2 CPU, 8GB RAM, 50GB disk"
    value       = "mini"
  }

  option {
    name        = "mega"
    description = "Mega: 16 CPU, 32GB RAM, 200GB disk"
    value       = "mega"
  }
}

# CPU Override (optional - overrides preset if not "auto")
data "coder_parameter" "cpu_override" {
  name         = "cpu_override"
  display_name = "CPU Cores (Override)"
  description  = "Override preset CPU (leave as 'auto' to use preset value)"
  default      = "auto"
  type         = "string"
  icon         = "/icon/compute.svg"
  mutable      = false

  option {
    name  = "auto"
    value = "auto"
  }
  option {
    name  = "1"
    value = "1"
  }
  option {
    name  = "2"
    value = "2"
  }
  option {
    name  = "4"
    value = "4"
  }
  option {
    name  = "8"
    value = "8"
  }
  option {
    name  = "16"
    value = "16"
  }
}

# Memory Override (optional - overrides preset if not "auto")
data "coder_parameter" "memory_override" {
  name         = "memory_override"
  display_name = "Memory GB (Override)"
  description  = "Override preset memory (leave as 'auto' to use preset value)"
  default      = "auto"
  type         = "string"
  icon         = "/icon/memory.svg"
  mutable      = false

  option {
    name  = "auto"
    value = "auto"
  }
  option {
    name  = "2"
    value = "2"
  }
  option {
    name  = "4"
    value = "4"
  }
  option {
    name  = "8"
    value = "8"
  }
  option {
    name  = "16"
    value = "16"
  }
  option {
    name  = "32"
    value = "32"
  }
  option {
    name  = "64"
    value = "64"
  }
}

# Disk Override (optional - overrides preset if not "auto")
data "coder_parameter" "disk_override" {
  name         = "disk_override"
  display_name = "Disk GB (Override)"
  description  = "Override preset disk (leave as 'auto' to use preset value)"
  default      = "auto"
  type         = "string"
  icon         = "/icon/folder.svg"
  mutable      = false

  option {
    name  = "auto"
    value = "auto"
  }
  option {
    name  = "20"
    value = "20"
  }
  option {
    name  = "50"
    value = "50"
  }
  option {
    name  = "100"
    value = "100"
  }
  option {
    name  = "200"
    value = "200"
  }
  option {
    name  = "500"
    value = "500"
  }
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  description  = "Docker image to use for the workspace (runs inside Envbox)"
  default      = "codercom/enterprise-node:ubuntu"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "Port for application preview in Coder Tasks"
  type         = "number"
  default      = "3000"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

# ========================================
# AI & AUTHENTICATION PARAMETERS
# ========================================

data "coder_parameter" "claude_api_key" {
  name         = "claude_api_key"
  display_name = "Anthropic API Key (Optional)"
  description  = "API key for Anthropic Claude. Leave empty if using OAuth token. Generate at: https://console.anthropic.com/settings/keys"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}

data "coder_parameter" "claude_oauth_token" {
  name         = "claude_oauth_token"
  display_name = "Claude OAuth Token (Optional)"
  description  = "OAuth token for Claude subscription. Leave empty if using API key. Generate with: claude setup-token"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}

data "coder_parameter" "claude_api_endpoint" {
  name         = "claude_api_endpoint"
  display_name = "Anthropic API Endpoint (Optional)"
  description  = "Custom API endpoint for Anthropic Claude (optional, defaults to official endpoint)"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}

data "coder_parameter" "gemini_api_key" {
  name         = "gemini_api_key"
  display_name = "Google Gemini API Key (Optional)"
  description  = "API key for Google Gemini CLI. Generate at: https://aistudio.google.com/apikey"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}

data "coder_parameter" "github_token" {
  name         = "github_token"
  display_name = "GitHub Personal Access Token (Optional)"
  description  = "GitHub PAT for gh CLI and Copilot. Generate at: https://github.com/settings/tokens"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}

data "coder_parameter" "gitea_url" {
  name         = "gitea_url"
  display_name = "Gitea Instance URL (Optional)"
  description  = "URL of your Gitea instance (e.g., https://gitea.example.com)"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "gitea_token" {
  name         = "gitea_token"
  display_name = "Gitea Access Token (Optional)"
  description  = "Gitea access token for tea CLI authentication"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true # Keep ephemeral - this is a secret token
}

data "coder_parameter" "openai_api_key" {
  name         = "openai_api_key"
  display_name = "OpenAI API Key (Optional)"
  description  = "API key for OpenAI Codex. Generate at: https://platform.openai.com/api-keys"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true
}


data "coder_parameter" "git_clone_repo_url" {
  name         = "git_clone_repo_url"
  display_name = "Git Clone Repository URL (Optional)"
  description  = "Git repository to automatically clone into workspace"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "git_clone_path" {
  name         = "git_clone_path"
  display_name = "Git Clone Path"
  description  = "Directory path where repository will be cloned"
  type         = "string"
  default      = "/home/coder/projects/repo"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "enable_filebrowser" {
  name         = "enable_filebrowser"
  display_name = "Enable File Browser"
  description  = "Enable web-based file browser for managing workspace files"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "enable_kasmvnc" {
  name         = "enable_kasmvnc"
  display_name = "Enable KasmVNC Desktop"
  description  = "Enable web-based Linux desktop environment (resource intensive)"
  type         = "bool"
  default      = "false"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "enable_claude_code_ui" {
  name         = "enable_claude_code_ui"
  display_name = "Enable Claude Code UI"
  description  = "Enable web-based interface for Claude Code sessions (mobile/desktop access)"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "enable_vibe_kanban" {
  name         = "enable_vibe_kanban"
  display_name = "Enable Vibe Kanban"
  description  = "Enable Kanban board for AI agent orchestration and task management"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "claude_code_ui_port" {
  name         = "claude_code_ui_port"
  display_name = "Claude Code UI Port"
  description  = "Port for Claude Code UI web interface"
  type         = "number"
  default      = "38401"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

data "coder_parameter" "vibe_kanban_port" {
  name         = "vibe_kanban_port"
  display_name = "Vibe Kanban Port"
  description  = "Port for Vibe Kanban interface"
  type         = "number"
  default      = "38402"
  mutable      = true
  ephemeral    = false # Set via preset to avoid prompting
}

# ========================================
# ADVANCED PARAMETERS
# ========================================

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "AI System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for AI agents with generalized instructions"
  mutable      = true # Must be mutable for ephemeral
  ephemeral    = true
  default      = <<-EOT
    -- Framing --
    You are a helpful AI assistant in a unified DevOps development environment. You are running inside a Coder Workspace with full Docker-in-Docker support (Envbox) and multiple AI agents available. You provide status updates via Coder MCP.

    -- Available AI Tools --
    - Claude Code: Primary AI coding assistant (this interface)
    - Gemini CLI: Google's AI for additional perspectives
    - GitHub Copilot CLI: GitHub's AI assistant (if configured)

    -- Development Tools --
    - Docker & Docker Compose: Full containerization support
    - Kubernetes: kubectl configured for cluster operations
    - GitHub CLI (gh): Authenticated GitHub operations
    - Gitea CLI (tea): Gitea instance operations (if configured)
    - VS Code: Pre-configured with extensions

    -- Best Practices --
    - Stay on track with the original plan
    - Debug thoroughly before changing architecture
    - Ask the user before making major architectural changes
    - Use Docker for long-running services (docker-compose up -d)
    - Use built-in tools for one-off commands and file operations
    - Leverage the appropriate AI tool for each task

    -- Docker Support --
    This workspace has full Docker-in-Docker capability via Envbox:
    - Run docker build and docker-compose commands
    - Create and test containerized applications
    - Run databases, services, and full-stack applications
    - All Docker data persists across workspace restarts
  EOT
}

data "coder_parameter" "unified_ai_prompt" {
  type        = "string"
  name        = "Unified AI Prompt"
  default     = ""
  description = "Write a prompt for AI tools (supports Coder Tasks for Claude, Copilot, Codex, Goose)"
  mutable     = true
  # NOTE: ephemeral must be false for Coder Tasks to work properly
  # Tasks require persistent parameters to display in the UI
}

# NOTE: Dotfiles are now configured via Coder's built-in dotfiles system
# Users set their dotfiles URL in their Coder account settings
# This is handled by the official dotfiles module below
# No template parameter needed!

# NOTE: Setup script parameter has been removed. Template initialization is now
# handled in coder_agent.startup_script above, and user personalization is handled
# by the official dotfiles module below. This follows Coder best practices for
# clean separation of concerns: template handles system setup, dotfiles handle
# user preferences.

# ========================================
# PROVIDER CONFIGURATION
# ========================================

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# External authentication for GitHub
# The ID must match what's configured in Coder server's external auth settings
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

# ========================================
# LOCALS
# ========================================

locals {
  # Preset configurations (CORRECTED to match description)
  preset_configs = {
    nano = {
      cpu    = 1
      memory = 2
      disk   = 20
    }
    mini = {
      cpu    = 2
      memory = 8
      disk   = 50
    }
    mega = {
      cpu    = 8
      memory = 32
      disk   = 200
    }
  }

  # Use override if set, otherwise use preset values
  cpu_value    = data.coder_parameter.cpu_override.value != "auto" ? tonumber(data.coder_parameter.cpu_override.value) : local.preset_configs[data.coder_parameter.preset.value].cpu
  memory_value = data.coder_parameter.memory_override.value != "auto" ? tonumber(data.coder_parameter.memory_override.value) : local.preset_configs[data.coder_parameter.preset.value].memory
  disk_value   = data.coder_parameter.disk_override.value != "auto" ? tonumber(data.coder_parameter.disk_override.value) : local.preset_configs[data.coder_parameter.preset.value].disk

  has_claude_auth = length(data.coder_parameter.claude_api_key.value) > 0 || length(data.coder_parameter.claude_oauth_token.value) > 0
  use_oauth_token = length(data.coder_parameter.claude_oauth_token.value) > 0
  use_api_key     = length(data.coder_parameter.claude_api_key.value) > 0 && !local.use_oauth_token
  has_gemini_key  = length(data.coder_parameter.gemini_api_key.value) > 0

  # GitHub authentication - prioritize external auth, fall back to parameter
  has_github_external_auth = data.coder_external_auth.github.access_token != ""
  has_github_param_token   = length(data.coder_parameter.github_token.value) > 0
  github_token             = local.has_github_external_auth ? data.coder_external_auth.github.access_token : data.coder_parameter.github_token.value
  has_github_token         = local.has_github_external_auth || local.has_github_param_token

  has_gitea_config = length(data.coder_parameter.gitea_url.value) > 0 && length(data.coder_parameter.gitea_token.value) > 0
}

# ========================================
# CODER AGENT
# ========================================

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # ========================================
    # INITIAL SETUP
    # ========================================

    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Fix sudo hostname resolution error
    CURRENT_HOSTNAME=$(hostname)
    if ! grep -q "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
      echo "⚙️ Fixing hostname resolution for sudo..."
      echo "127.0.1.1 $CURRENT_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
    fi

    # Create project directories
    mkdir -p /home/coder/projects
    mkdir -p ~/.claude/resume-logs
    mkdir -p ~/scripts

    # ========================================
    # SYSTEM PACKAGES (Sequential - No Apt Locks!)
    # ========================================

    echo "📦 Installing system packages and CLIs..."

    # Single apt-get update (not multiple!)
    sudo apt-get update

    # Install core packages
    sudo apt-get install -y --fix-missing \
      apt-transport-https gnupg \
      tmux \
      || echo "⚠️ Some packages failed, continuing..."

    # Kubernetes CLI (kubectl)
    if ! command -v kubectl >/dev/null 2>&1; then
      echo "📦 Installing kubectl..."
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubectl
    fi

    # GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
      echo "📦 Installing GitHub CLI..."
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y gh
    fi

    # Gitea CLI (tea)
    if ! command -v tea >/dev/null 2>&1; then
      echo "📦 Installing Gitea CLI (tea)..."
      wget -qO- https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64 -O /tmp/tea
      sudo install -m 755 /tmp/tea /usr/local/bin/tea
      rm /tmp/tea
    fi

    # TypeScript (optional)
    if ! command -v tsc >/dev/null 2>&1; then
      if command -v npm >/dev/null 2>&1; then
        echo "📦 Installing TypeScript..."
        sudo npm install -g typescript || echo "⚠️ TypeScript installation failed"
      fi
    fi

    echo "✅ All system packages and tools installed successfully"

    # ========================================
    # PM2 AND UI TOOLS (Non-blocking background)
    # ========================================

    (
      echo "📦 Setting up PM2 and UI tools in background..."

      # Install PM2 if needed
      if ! command -v pm2 >/dev/null 2>&1; then
        echo "📦 Installing PM2..."
        if command -v npm >/dev/null 2>&1; then
          sudo npm install -g pm2 --force 2>&1 || {
            echo "⚠️ PM2 install failed, UI tools will not be available"
            exit 0
          }
          echo "✅ PM2 installed: $(pm2 --version)"
        else
          echo "⚠️ npm not found, skipping PM2 and UI tools"
          exit 0
        fi
      fi

      # Claude Code UI (conditional)
      if [ "${data.coder_parameter.enable_claude_code_ui.value}" = "true" ]; then
        echo "🎨 Setting up Claude Code UI..."
        sudo npm install -g @siteboon/claude-code-ui --force 2>&1 || echo "⚠️ Claude Code UI install failed"
        mkdir -p ~/.claude-code-ui
        pm2 delete claude-code-ui 2>/dev/null || true
        PORT=${data.coder_parameter.claude_code_ui_port.value} \
        DATABASE_PATH=~/.claude-code-ui/database.json \
        pm2 start claude-code-ui --name claude-code-ui 2>&1 || echo "⚠️ Failed to start Claude Code UI"
        echo "✅ Claude Code UI started on port ${data.coder_parameter.claude_code_ui_port.value}"
      fi

      # Vibe Kanban (conditional)
      if [ "${data.coder_parameter.enable_vibe_kanban.value}" = "true" ]; then
        echo "📋 Setting up Vibe Kanban..."
        mkdir -p ~/.vibe-kanban
        pm2 delete vibe-kanban 2>/dev/null || true
        BACKEND_PORT=${data.coder_parameter.vibe_kanban_port.value} \
        HOST=0.0.0.0 \
        pm2 start "npx vibe-kanban" --name vibe-kanban 2>&1 || echo "⚠️ Failed to start Vibe Kanban"
        echo "✅ Vibe Kanban started on port ${data.coder_parameter.vibe_kanban_port.value}"
      fi

      # Save PM2 process list
      pm2 save 2>/dev/null || true

      echo "✅ UI tools setup complete - check 'pm2 list' for status"
    ) > /tmp/ui-tools-setup.log 2>&1 &

    echo "🚀 Workspace initialization complete!"
    echo "💡 UI tools are installing in background. Check: tail -f /tmp/ui-tools-setup.log"
  EOT

  # Environment variables for AI tools and authentication
  # Note: Git configuration is handled by the personalize module
  # Note: Claude env vars (CLAUDE_API_KEY, ANTHROPIC_BASE_URL, etc) are managed by claude-code module
  env = merge(
    # Gemini API key
    local.has_gemini_key ? {
      GOOGLE_AI_API_KEY = data.coder_parameter.gemini_api_key.value
    } : {},
    # GitHub token (from external auth or parameter)
    local.has_github_token ? {
      GITHUB_TOKEN = local.github_token
      GH_TOKEN     = local.github_token
    } : {},
    # Gitea configuration
    local.has_gitea_config ? {
      GITEA_URL   = data.coder_parameter.gitea_url.value
      GITEA_TOKEN = data.coder_parameter.gitea_token.value
    } : {}
  )

  # Workspace metadata for monitoring
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Docker Status"
    key          = "8_docker_status"
    script       = <<EOT
      if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        echo "✓ Running"
      else
        echo "✗ Not Available"
      fi
    EOT
    interval     = 30
    timeout      = 5
  }

  metadata {
    display_name = "Docker Containers"
    key          = "9_docker_containers"
    script       = <<EOT
      if command -v docker >/dev/null 2>&1; then
        docker ps --format "{{.Names}}" | wc -l | awk '{print $1 " running"}'
      else
        echo "N/A"
      fi
    EOT
    interval     = 30
    timeout      = 5
  }

  metadata {
    display_name = "AI Agents Status"
    key          = "10_ai_tools"
    script       = <<EOT
      tools=""
      command -v claude >/dev/null 2>&1 && tools="$tools Claude"
      command -v gemini >/dev/null 2>&1 && tools="$tools Gemini"
      command -v gh >/dev/null 2>&1 && gh copilot --version >/dev/null 2>&1 && tools="$tools Copilot"
      [ -z "$tools" ] && echo "None" || echo "$tools"
    EOT
    interval     = 60
    timeout      = 5
  }
}

# ========================================
# AI MODULES
# ========================================
# NOTE: All environment variables are managed either by:
# 1. coder_agent.main.env (Gemini, GitHub, Gitea)
# 2. claude-code module (Claude API key, OAuth token, system prompt, API endpoint)

module "claude-code" {
  count   = data.coder_workspace.me.start_count # ALWAYS install Claude Code
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.2" # Auto-update to latest 4.x version (currently 4.2.0+)

  agent_id                     = coder_agent.main.id
  workdir                      = "/home/coder/projects"
  order                        = 999
  ai_prompt                    = data.coder_parameter.unified_ai_prompt.value
  system_prompt                = data.coder_parameter.system_prompt.value
  model                        = "sonnet"
  permission_mode              = "bypassPermissions"
  post_install_script          = ""
  dangerously_skip_permissions = "true"

  # Authentication (module manages env vars internally)
  claude_api_key          = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""

  # MCP Server Configuration (JSON format)
  mcp = <<-EOF
  {
    "mcpServers": {
      "sequential-thinking": {
        "command": "npx"
        "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
      },
      "context7": {
        "command": "npx"
        "args": ["-y", "@upstash/context7-mcp"]
      },
      "deepwiki": {
        "url": "https://mcp.deepwiki.com/mcp"
      },
    }
  }
  EOF

}

# Custom Anthropic API endpoint (if specified)
resource "coder_env" "anthropic_base_url" {
  count    = data.coder_parameter.claude_api_endpoint.value != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "ANTHROPIC_BASE_URL"
  value    = data.coder_parameter.claude_api_endpoint.value
}

# Coder Tasks Integration - use Claude Code as the task interface
resource "coder_ai_task" "main" {
  count  = data.coder_workspace.me.start_count
  app_id = module.claude-code[0].task_app_id
}

# ========================================
# DEVELOPER TOOL MODULES
# ========================================

# Personalize - Git configuration from Coder user data (official module)
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

# Dotfiles - Official module with default repository
# Default: Uses unified-devops dotfiles repository
# Users can override via Coder UI: Account → Dotfiles → https://github.com/username/custom-dotfiles.git
module "dotfiles" {
  count                = data.coder_workspace.me.start_count
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "~> 1.0"
  agent_id             = coder_agent.main.id
  default_dotfiles_uri = "https://github.com/julesintime/coder-dotfiles.git"
}

# Git Clone (conditional on repo URL)
module "git-clone" {
  count    = data.coder_parameter.git_clone_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_clone_repo_url.value
  base_dir = "/home/coder"
}

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
  count               = data.coder_parameter.enable_kasmvnc.value ? data.coder_workspace.me.start_count : 0
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "~> 1.2"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
}

# Archive Tool
module "archive" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/archive/coder"
  version  = "~> 0.0"
  agent_id = coder_agent.main.id
}

# ========================================
# IDE MODULES
# ========================================

# VS Code (code-server)
module "code-server" {
  count   = data.coder_workspace.me.start_count
  folder  = "/home/coder/projects"
  source  = "registry.coder.com/coder/code-server/coder"
  version = "~> 1.0"

  agent_id = coder_agent.main.id
  order    = 1

  settings = {
    "window.autoDetectColorScheme" : true
    "editor.formatOnSave" : true
    "files.autoSave" : "afterDelay"
    "terminal.integrated.defaultProfile.linux" : "tmux"
  }

  # Extensions - these will use the GITHUB_TOKEN environment variable for authentication
  # Note: GitHub extensions (copilot, copilot-chat) and C++ tools not available in code-server marketplace
  extensions = [
    "ms-azuretools.vscode-docker",
    "johnpapa.vscode-peacock",
    "coder.coder-remote"
  ]
}

# Cursor IDE
module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

# Windsurf IDE
module "windsurf" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/windsurf/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

# JetBrains IDEs - DISABLED for automated workspace creation
# The JetBrains module creates interactive parameter prompts that block automation
# Re-enable by changing count to data.coder_workspace.me.start_count if needed
module "jetbrains" {
  count      = 0 # Disabled to allow CLI automation
  source     = "registry.coder.com/coder/jetbrains/coder"
  version    = "~> 1.0"
  agent_id   = coder_agent.main.id
  agent_name = "main"
  folder     = "/home/coder/projects"
}

# ========================================
# CODER APPS
# ========================================

# Application preview
resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "App Preview"
  icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
  url          = "http://localhost:${data.coder_parameter.preview_port.value}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 0

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.preview_port.value}/"
    interval  = 5
    threshold = 15
  }
}

# Claude Code UI - Web interface for managing Claude Code sessions
resource "coder_app" "claude_code_ui" {
  count        = data.coder_parameter.enable_claude_code_ui.value ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "claude-code-ui"
  display_name = "Claude Code UI"
  icon         = "/icon/code.svg"
  url          = "http://localhost:${data.coder_parameter.claude_code_ui_port.value}"
  share        = "owner" # Only workspace owner can access
  subdomain    = true
  open_in      = "tab"
  order        = 1

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.claude_code_ui_port.value}/"
    interval  = 5
    threshold = 20
  }
}

# Vibe Kanban - AI agent orchestration board
resource "coder_app" "vibe_kanban" {
  count        = data.coder_parameter.enable_vibe_kanban.value ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "vibe-kanban"
  display_name = "Vibe Kanban"
  icon         = "/icon/workspace.svg"
  url          = "http://localhost:${data.coder_parameter.vibe_kanban_port.value}"
  share        = "owner" # Only workspace owner can access
  subdomain    = true
  open_in      = "tab"
  order        = 2

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.vibe_kanban_port.value}/"
    interval  = 10
    threshold = 30 # Increased threshold for slower startup
  }
}

# ========================================
# KUBERNETES RESOURCES
# ========================================

# Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }

    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "${local.disk_value}Gi"
      }
    }
  }
}

# Kubernetes Pod with Envbox (Docker-in-Docker)
resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count

  depends_on = [
    kubernetes_persistent_volume_claim.home
  ]

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }

    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    # Outer container: Envbox (provides Docker-in-Docker)
    container {
      name    = "dev"
      image   = "ghcr.io/coder/envbox:latest"
      command = ["/envbox", "docker"]

      security_context {
        privileged = true
      }

      # Envbox environment variables
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "CODER_AGENT_URL"
        value = data.coder_workspace.me.access_url
      }

      env {
        name  = "CODER_INNER_IMAGE"
        value = data.coder_parameter.container_image.value
      }

      env {
        name  = "CODER_INNER_USERNAME"
        value = "coder"
      }

      env {
        name  = "CODER_BOOTSTRAP_SCRIPT"
        value = coder_agent.main.init_script
      }

      env {
        name  = "CODER_MOUNTS"
        value = "/home/coder:/home/coder"
      }

      # CPU limit via Downward API
      env {
        name = "CODER_CPUS"
        value_from {
          resource_field_ref {
            resource = "limits.cpu"
          }
        }
      }

      # Memory limit via Downward API
      env {
        name = "CODER_MEMORY"
        value_from {
          resource_field_ref {
            resource = "limits.memory"
          }
        }
      }

      # Resource limits
      resources {
        requests = {
          "cpu"    = "500m"
          "memory" = "1Gi"
        }
        limits = {
          "cpu"    = "${local.cpu_value}"
          "memory" = "${local.memory_value}Gi"
        }
      }

      # Volume mounts
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        sub_path   = "home"
        read_only  = false
      }

      volume_mount {
        mount_path = "/var/lib/coder/docker"
        name       = "home"
        sub_path   = "cache/docker"
        read_only  = false
      }

      volume_mount {
        mount_path = "/var/lib/coder/containers"
        name       = "home"
        sub_path   = "cache/containers"
        read_only  = false
      }

      volume_mount {
        mount_path = "/var/lib/containers"
        name       = "home"
        sub_path   = "envbox/containers"
        read_only  = false
      }

      volume_mount {
        mount_path = "/var/lib/docker"
        name       = "home"
        sub_path   = "envbox/docker"
        read_only  = false
      }

      volume_mount {
        mount_path = "/var/lib/sysbox"
        name       = "sysbox"
        read_only  = false
      }

      volume_mount {
        mount_path = "/usr/src"
        name       = "usr-src"
        read_only  = true
      }

      volume_mount {
        mount_path = "/lib/modules"
        name       = "lib-modules"
        read_only  = true
      }
    }

    # Volume definitions
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    volume {
      name = "sysbox"
      empty_dir {}
    }

    volume {
      name = "usr-src"
      host_path {
        path = "/usr/src"
        type = ""
      }
    }

    volume {
      name = "lib-modules"
      host_path {
        path = "/lib/modules"
        type = ""
      }
    }
  }
}
