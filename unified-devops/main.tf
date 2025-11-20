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
    preset                 = "nano"
    container_image        = "codercom/enterprise-node:ubuntu"
    preview_port           = "3000"
    git_clone_repo_url     = ""
    git_clone_path         = "/home/coder/projects/repo"
    enable_filebrowser     = "true"
    enable_kasmvnc         = "false"
    enable_claude_code_ui  = "true"
    enable_vibe_kanban     = "true"
    claude_code_ui_port    = "38401"
    vibe_kanban_port       = "38402"
    gitea_url              = ""
  }
}

data "coder_workspace_preset" "mini" {
  name    = "Mini (2CPU/8GB/50GB)"
  default = true
  parameters = {
    preset                 = "mini"
    container_image        = "codercom/enterprise-node:ubuntu"
    preview_port           = "3000"
    git_clone_repo_url     = ""
    git_clone_path         = "/home/coder/projects/repo"
    enable_filebrowser     = "true"
    enable_kasmvnc         = "false"
    enable_claude_code_ui  = "true"
    enable_vibe_kanban     = "true"
    claude_code_ui_port    = "38401"
    vibe_kanban_port       = "38402"
    gitea_url              = ""
  }
}

data "coder_workspace_preset" "mega" {
  name = "Mega (8CPU/32GB/200GB)"
  parameters = {
    preset                 = "mega"
    container_image        = "codercom/enterprise-node:ubuntu"
    preview_port           = "3000"
    git_clone_repo_url     = ""
    git_clone_path         = "/home/coder/projects/repo"
    enable_filebrowser     = "true"
    enable_kasmvnc         = "false"
    enable_claude_code_ui  = "true"
    enable_vibe_kanban     = "true"
    claude_code_ui_port    = "38401"
    vibe_kanban_port       = "38402"
    gitea_url              = ""
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
  ephemeral    = false  # Persist preset selection across restarts

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
    description = "Mega: 8 CPU, 32GB RAM, 200GB disk"
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
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "Port for application preview in Coder Tasks"
  type         = "number"
  default      = "3000"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
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
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "gitea_token" {
  name         = "gitea_token"
  display_name = "Gitea Access Token (Optional)"
  description  = "Gitea access token for tea CLI authentication"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = true  # Keep ephemeral - this is a secret token
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
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "git_clone_path" {
  name         = "git_clone_path"
  display_name = "Git Clone Path"
  description  = "Directory path where repository will be cloned"
  type         = "string"
  default      = "/home/coder/projects/repo"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "enable_filebrowser" {
  name         = "enable_filebrowser"
  display_name = "Enable File Browser"
  description  = "Enable web-based file browser for managing workspace files"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "enable_kasmvnc" {
  name         = "enable_kasmvnc"
  display_name = "Enable KasmVNC Desktop"
  description  = "Enable web-based Linux desktop environment (resource intensive)"
  type         = "bool"
  default      = "false"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "enable_claude_code_ui" {
  name         = "enable_claude_code_ui"
  display_name = "Enable Claude Code UI"
  description  = "Enable web-based interface for Claude Code sessions (mobile/desktop access)"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "enable_vibe_kanban" {
  name         = "enable_vibe_kanban"
  display_name = "Enable Vibe Kanban"
  description  = "Enable Kanban board for AI agent orchestration and task management"
  type         = "bool"
  default      = "true"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "claude_code_ui_port" {
  name         = "claude_code_ui_port"
  display_name = "Claude Code UI Port"
  description  = "Port for Claude Code UI web interface"
  type         = "number"
  default      = "38401"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
}

data "coder_parameter" "vibe_kanban_port" {
  name         = "vibe_kanban_port"
  display_name = "Vibe Kanban Port"
  description  = "Port for Vibe Kanban interface"
  type         = "number"
  default      = "38402"
  mutable      = true
  ephemeral    = false  # Set via preset to avoid prompting
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
  mutable      = true  # Must be mutable for ephemeral
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

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Bash script to run before starting the AI agent"
  mutable      = true  # Must be mutable for ephemeral to work
  ephemeral    = true
  default      = <<-EOT
    #!/bin/bash
    set -e

    echo "🚀 Starting Unified DevOps Workspace Setup..."

    # Fix sudo hostname resolution error
    # Add current hostname to /etc/hosts if not already present
    CURRENT_HOSTNAME=$(hostname)
    if ! grep -q "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
      echo "⚙️ Fixing hostname resolution for sudo..."
      echo "127.0.1.1 $CURRENT_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
    fi

    # Create project directory
    mkdir -p /home/coder/projects
    cd /home/coder/projects

    # Docker verification
    if command -v docker >/dev/null 2>&1; then
      echo "✓ Docker is available"
      docker version
    else
      echo "⚠️ Docker not found (expected with Envbox)"
    fi

    # Install Claude Resume Helpers
    echo "⚙️ Installing Claude session management helpers..."
    mkdir -p ~/scripts ~/.claude/resume-logs

    # Download claude-resume-helpers.sh from template
    cat > ~/scripts/claude-resume-helpers.sh << 'CLAUDE_HELPERS_EOF'
#!/bin/bash
# Claude Code Resume Helpers - Integrated into Coder Workspace

# CCR - Claude Code Resume
ccr() {
    local session_id=$$1
    local prompt=$${2:-"continue"}
    if [ -z "$$session_id" ]; then
        echo "❌ Usage: ccr <session-id> [prompt]"
        echo "💡 Tip: Use 'ccr-list' to see recent sessions"
        return 1
    fi
    echo "🔄 Resuming Claude session: $$session_id"
    claude --dangerously-skip-permissions -r "$$session_id" "$$prompt"
}

# CCR-LIST - List Recent Sessions
ccr-list() {
    local limit=$${1:-20}
    echo "📋 Recent Claude Code sessions:"
    [ ! -f ~/.claude/history.jsonl ] && echo "⚠️  No history found" && return 1
    tail -$$limit ~/.claude/history.jsonl | jq -r 'if .timestamp then ((.timestamp / 1000) | strftime("%Y-%m-%d %H:%M")) as $$time | "\($$time) | \(.sessionId[0:8])... | \(.project // "?") | \(.display[0:60] // "no prompt")" else "? | ? | ? | ?" end' | tac | nl
    echo ""
    echo "💡 Resume with: ccr <full-session-id>"
}

# CCR-FIND - Search Sessions
ccr-find() {
    [ -z "$1" ] && echo "❌ Usage: ccr-find <keyword>" && return 1
    echo "🔍 Searching: $1"
    grep -i "$1" ~/.claude/history.jsonl 2>/dev/null | jq -r 'if .timestamp then ((.timestamp / 1000) | strftime("%Y-%m-%d %H:%M")) as $time | "\($time) | \(.sessionId) | \(.project // "?") | \(.display[0:80])" else "? | ? | ? | ?" end' | head -20 | nl
}

# CCT - Claude Code Tmux
cct() {
    local session_id=$${1:-""}
    local project_path=$${2:-$$(pwd)}
    local tmux_session="claude-$$(basename $$project_path)"

    if ! tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo "🚀 Creating tmux session: $tmux_session"
        tmux new-session -d -s "$tmux_session" -c "$project_path" -n "claude"
        tmux new-window -t "$tmux_session:2" -c "$project_path" -n "terminal"
        tmux new-window -t "$tmux_session:3" -c "$project_path" -n "logs"

        if [ -n "$session_id" ]; then
            tmux send-keys -t "$tmux_session:1" "cd $project_path && claude -r $session_id" C-m
        else
            tmux send-keys -t "$tmux_session:1" "cd $project_path && claude" C-m
        fi

        tmux send-keys -t "$tmux_session:3" "watch -n 5 'tail -20 ~/.claude/debug/*.txt 2>/dev/null | tail -50'" C-m
        tmux select-window -t "$tmux_session:1"
    fi

    tmux attach -t "$tmux_session"
}

# CCT-LIST - List Tmux Sessions
cct-list() {
    echo "📺 Active Claude tmux sessions:"
    tmux list-sessions 2>/dev/null | grep "claude-" || echo "⚠️  No sessions"
}

# CCT-KILL - Kill Tmux Session
cct-kill() {
    local name=$${1:-""}
    [ -z "$$name" ] && cct-list && read -p "Enter session: " name
    [ -n "$$name" ] && tmux kill-session -t "$$name" 2>/dev/null && echo "✅ Killed: $$name" || echo "❌ Not found"
}

# CCRA - Resume All Rate-Limited
ccra() {
    echo "🔄 Scanning for rate-limited sessions..."
    local sessions=$(find ~/.claude/projects -name "*.jsonl" -exec grep -l "rate.*limit\|exceeded" {} \; 2>/dev/null)
    [ -z "$sessions" ] && echo "✅ No rate-limited sessions" && return 0

    local count=0
    for file in $sessions; do
        local sid=$(basename "$file" .jsonl)
        [[ $sid == agent-* ]] && continue
        count=$((count + 1))
        echo "[$count] Resuming: $sid"
        timeout 30s claude -r "$sid" "continue" > ~/.claude/resume-logs/$(date +%Y%m%d-%H%M%S)-$sid.log 2>&1 &
        sleep 2
    done
    echo "✅ Resumed $count session(s)"
}

# CCR-CURRENT - Show Current Session
ccr-current() {
    echo "🔍 Current session info:"
    [ -f ~/.claude/history.jsonl ] && tail -1 ~/.claude/history.jsonl | jq -r '"📝 \(.sessionId[0:8])... - \(.project) - \(.display[0:50])"'
    pgrep -f "claude" >/dev/null && echo "🏃 Claude is running (PID: $(pgrep -f claude))" || echo "⚠️  No active Claude"
}

export -f ccr ccr-list ccr-find cct cct-list cct-kill ccra ccr-current
CLAUDE_HELPERS_EOF

    chmod +x ~/scripts/claude-resume-helpers.sh

    # Bash aliases and configuration
    echo "⚙️ Configuring bash aliases..."
    cat >> ~/.bashrc << 'EOF'

# ========================================
# Unified DevOps Template Aliases
# ========================================

# Claude Session Management (source helpers)
if [ -f ~/scripts/claude-resume-helpers.sh ]; then
    source ~/scripts/claude-resume-helpers.sh
fi

# AI Tools
alias cc-c='claude'
alias cc='claude'
alias gemini-chat='gemini'
alias copilot='gh copilot'

# Docker shortcuts
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dclean='docker system prune -af'

# Kubernetes shortcuts
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# GitHub CLI
alias ghpr='gh pr'
alias ghissue='gh issue'

# AI UI Tools
alias claude-code-ui-logs='pm2 logs claude-code-ui'
alias vibe-logs='pm2 logs vibe-kanban'
alias ai-ui-restart='pm2 restart claude-code-ui vibe-kanban'
alias ai-ui-status='pm2 list'
alias update-ai-uis='npm update -g @siteboon/claude-code-ui vibe-kanban && pm2 restart claude-code-ui vibe-kanban'

# Workspace info
alias workspace-info='echo "🚀 Unified DevOps Workspace"; echo "Docker: $(docker --version 2>/dev/null || echo Not available)"; echo "Kubectl: $(kubectl version --client --short 2>/dev/null || echo Not available)"; echo "Claude: $(claude --version 2>/dev/null || echo Not installed)"; echo "Gemini: $(gemini --version 2>/dev/null || echo Not installed)"'

EOF

    source ~/.bashrc

    # Configure Git with GitHub authenticated user (if available)
    if command -v gh >/dev/null 2>&1 && [ -n "$GITHUB_TOKEN" ]; then
      echo "⚙️ Configuring Git with GitHub authenticated user..."
      GH_USER=$(gh api user --jq '.name // .login' 2>/dev/null || echo "")
      GH_EMAIL=$(gh api user --jq '.email // ""' 2>/dev/null || echo "")

      if [ -n "$GH_USER" ]; then
        git config --global user.name "$GH_USER"
        echo "✓ Git user.name set to: $GH_USER (from GitHub)"
      fi

      if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
        git config --global user.email "$GH_EMAIL"
        echo "✓ Git user.email set to: $GH_EMAIL (from GitHub)"
      fi
    fi

    echo "✅ Workspace base setup complete!"
    echo "⏳ System packages, PM2, and AI tools are installing in parallel..."
    echo "🐳 Docker is ready - try: docker run hello-world"

    exit 0
  EOT
}

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
  cpu_value = data.coder_parameter.cpu_override.value != "auto" ? tonumber(data.coder_parameter.cpu_override.value) : local.preset_configs[data.coder_parameter.preset.value].cpu
  memory_value = data.coder_parameter.memory_override.value != "auto" ? tonumber(data.coder_parameter.memory_override.value) : local.preset_configs[data.coder_parameter.preset.value].memory
  disk_value = data.coder_parameter.disk_override.value != "auto" ? tonumber(data.coder_parameter.disk_override.value) : local.preset_configs[data.coder_parameter.preset.value].disk

  has_claude_auth  = length(data.coder_parameter.claude_api_key.value) > 0 || length(data.coder_parameter.claude_oauth_token.value) > 0
  use_oauth_token  = length(data.coder_parameter.claude_oauth_token.value) > 0
  use_api_key      = length(data.coder_parameter.claude_api_key.value) > 0 && !local.use_oauth_token
  has_gemini_key   = length(data.coder_parameter.gemini_api_key.value) > 0

  # GitHub authentication - prioritize external auth, fall back to parameter
  has_github_external_auth = data.coder_external_auth.github.access_token != ""
  has_github_param_token   = length(data.coder_parameter.github_token.value) > 0
  github_token = local.has_github_external_auth ? data.coder_external_auth.github.access_token : data.coder_parameter.github_token.value
  has_github_token = local.has_github_external_auth || local.has_github_param_token

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

    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Run the setup script from the parameter
    ${data.coder_parameter.setup_script.value}
  EOT

  # Environment variables for Git, AI tools, and authentication
  env = merge(
    {
      GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    },
    # Claude API endpoint
    length(data.coder_parameter.claude_api_endpoint.value) > 0 ? {
      ANTHROPIC_BASE_URL = data.coder_parameter.claude_api_endpoint.value
    } : {},
    # Gemini API key
    local.has_gemini_key ? {
      GOOGLE_AI_API_KEY = data.coder_parameter.gemini_api_key.value
    } : {},
    # GitHub token (from external auth or parameter)
    local.has_github_token ? {
      GITHUB_TOKEN = local.github_token
      GH_TOKEN     = local.github_token
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
# ENVIRONMENT VARIABLES
# ========================================

# Claude API key
resource "coder_env" "claude_api_key" {
  count    = local.use_api_key ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "CLAUDE_API_KEY"
  value    = data.coder_parameter.claude_api_key.value
}

# Claude OAuth token
resource "coder_env" "claude_oauth_token" {
  count    = local.use_oauth_token ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_OAUTH_TOKEN"
  value    = data.coder_parameter.claude_oauth_token.value
}

# Claude system prompt
resource "coder_env" "claude_system_prompt" {
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_SYSTEM_PROMPT"
  value    = data.coder_parameter.system_prompt.value
}

# Gitea configuration
resource "coder_env" "gitea_url" {
  count    = local.has_gitea_config ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GITEA_URL"
  value    = data.coder_parameter.gitea_url.value
}

resource "coder_env" "gitea_token" {
  count    = local.has_gitea_config ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GITEA_TOKEN"
  value    = data.coder_parameter.gitea_token.value
}

# ========================================
# CRITICAL DEPENDENCIES
# ========================================

# Install system packages FIRST - blocks login to prevent race conditions
resource "coder_script" "install_system_packages" {
  agent_id     = coder_agent.main.id
  display_name = "Install System Packages"
  icon         = "/icon/memory.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "📦 Installing system packages and CLIs..."

    # Wait for any existing apt processes to complete
    for i in {1..30}; do
      if ! sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
         ! sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        break
      fi
      echo "Waiting for other apt processes... ($i/30)"
      sleep 2
    done

    # NOTE: codercom/enterprise-node:ubuntu already has: curl, wget, git, jq, build-essential,
    # python3-pip, ca-certificates, docker, Node.js, npm, yarn
    # We only install what's MISSING from the base image

    echo "Installing additional system packages..."
    sudo apt-get update
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

    # TypeScript (if not present)
    if ! command -v tsc >/dev/null 2>&1; then
      if command -v npm >/dev/null 2>&1; then
        echo "📦 Installing TypeScript..."
        sudo npm install -g typescript || echo "⚠️ TypeScript installation failed"
      fi
    fi

    echo "✅ System packages installed successfully"
  EOT
  run_on_start = true
  run_on_stop  = false
  # CRITICAL: Block login until packages are installed to prevent race conditions
  start_blocks_login = true
  timeout = 600
}

# Install PM2 AFTER system packages - also blocks login
resource "coder_script" "install_pm2" {
  agent_id     = coder_agent.main.id
  display_name = "Install PM2"
  icon         = "/icon/code.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "📦 Installing PM2 process manager..."

    if ! command -v pm2 >/dev/null 2>&1; then
      if command -v npm >/dev/null 2>&1; then
        echo "Trying npm install without sudo first..."
        if npm install -g pm2 2>&1; then
          echo "✅ PM2 installed successfully with npm"
        else
          echo "npm install failed, trying with sudo..."
          for i in 1 2 3; do
            echo "PM2 install attempt $i/3 with sudo..."
            if sudo npm install -g pm2 --force 2>&1; then
              echo "✅ PM2 installed successfully with sudo"
              break
            else
              echo "⚠️ PM2 install attempt $i failed"
              if [ $i -eq 3 ]; then
                echo "❌ PM2 installation failed after 3 attempts"
                exit 1
              else
                sleep 5
              fi
            fi
          done
        fi
      else
        echo "❌ npm not found, cannot install PM2"
        exit 1
      fi
    else
      echo "✅ PM2 already installed"
    fi

    pm2 --version
  EOT
  run_on_start = true
  run_on_stop  = false
  # PM2 must be installed before UI tools can start
  depends_on = [coder_script.install_system_packages]
  start_blocks_login = true
  timeout = 300
}

# ========================================
# AI MODULES
# ========================================

# Claude Code module (latest version)
# CHANGED: Always run, regardless of auth status - Claude Code works without auth
module "claude-code" {
  count   = data.coder_workspace.me.start_count  # ALWAYS install Claude Code
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.0" # Use latest 4.x version, fallback to 3.x if unavailable

  agent_id            = coder_agent.main.id
  workdir             = "/home/coder/projects"
  order               = 999
  ai_prompt           = data.coder_task.me.prompt  # Use task prompt, not parameter
  system_prompt       = data.coder_parameter.system_prompt.value
  model               = "sonnet"
  permission_mode     = "bypassPermissions"
  post_install_script = ""  # Empty - we'll use a separate script for MCP setup
  dangerously_skip_permissions = "true"
  # Authentication (optional - Claude Code works without it)
  claude_api_key          = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""
}

# NOTE: Gemini module uses agentapi v1.0.0 which ALWAYS creates coder_ai_task
# We use gemini's coder_ai_task for Coder Tasks integration

# MCP Server Configuration Script
# Runs AFTER Claude Code module installs the CLI
resource "coder_script" "configure_mcp_servers" {
  agent_id     = coder_agent.main.id
  display_name = "Configure MCP Servers"
  icon         = "/icon/docker.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "📦 Configuring MCP servers for Claude Code..."

    # Wait for claude CLI to be available (installed by claude-code module)
    for i in {1..30}; do
      if command -v claude >/dev/null 2>&1; then
        echo "✓ Claude CLI found"
        break
      fi
      echo "Waiting for Claude CLI installation... ($i/30)"
      sleep 2
    done

    if ! command -v claude >/dev/null 2>&1; then
      echo "⚠️  Claude CLI not found after waiting, skipping MCP configuration"
      exit 0
    fi

    # Configure MCP servers
    echo "Adding context7 MCP server..."
    claude mcp add --transport http context7 https://mcp.context7.com/mcp || echo "⚠️  context7 failed to add"

    echo "Adding sequential-thinking MCP server..."
    claude mcp add sequential-thinking npx @modelcontextprotocol/server-sequential-thinking || echo "⚠️  sequential-thinking failed to add"

    echo "Adding deepwiki MCP server..."
    claude mcp add --transport http deepwiki https://mcp.deepwiki.com/mcp || echo "⚠️  deepwiki failed to add"

    echo "✅ MCP servers configured!"
    claude mcp list || echo "⚠️  Could not list MCP servers"
  EOT
  run_on_start = true
  run_on_stop  = false
  # Ensure the Claude Code module is installed before configuring MCP servers
  depends_on = [module.claude-code]
  # CRITICAL: Block login to ensure MCP is configured before UI tools start
  # UI tools depend on MCP servers being ready, so this must complete first
  start_blocks_login = true
  timeout = 600
}

# ========================================
# AI UI TOOLS
# ========================================

# Claude Code UI - Web interface for Claude Code sessions
resource "coder_script" "claude_code_ui" {
  count        = data.coder_parameter.enable_claude_code_ui.value ? 1 : 0
  agent_id     = coder_agent.main.id
  display_name = "Claude Code UI"
  icon         = "/icon/code.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "🎨 Setting up Claude Code UI..."

    # Wait for PM2 to be installed (install_pm2 script runs with start_blocks_login=true)
    # But we run without blocking, so we need to wait for PM2 to become available
    echo "⏳ Waiting for PM2 to be installed..."
    for i in {1..60}; do
      if command -v pm2 >/dev/null 2>&1; then
        echo "✅ PM2 found!"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "❌ Timeout waiting for PM2 installation"
        exit 1
      fi
      echo "Waiting for PM2... ($i/60)"
      sleep 10
    done

    # Install Claude Code UI with retry logic for network issues
    echo "📦 Installing Claude Code UI..."
    for i in 1 2 3; do
      echo "Claude Code UI install attempt $i/3..."
      if sudo npm install -g @siteboon/claude-code-ui --force 2>&1; then
        echo "✅ Claude Code UI installed successfully"
        break
      else
        echo "⚠️ Install attempt $i failed"
        if [ $i -eq 3 ]; then
          echo "❌ Claude Code UI installation failed after 3 attempts"
          exit 1
        else
          sleep 10
        fi
      fi
    done

    # Create data directory for persistence
    mkdir -p /home/coder/.claude-code-ui

    # Stop existing instance if running
    pm2 delete claude-code-ui 2>/dev/null || true

    # Start with PM2
    echo "🚀 Starting Claude Code UI on port ${data.coder_parameter.claude_code_ui_port.value}..."
    PORT=${data.coder_parameter.claude_code_ui_port.value} \
    DATABASE_PATH=/home/coder/.claude-code-ui/database.json \
    pm2 start claude-code-ui --name claude-code-ui

    pm2 save
    echo "✅ Claude Code UI started successfully!"
    pm2 list
  EOT
  run_on_start = true
  run_on_stop  = false
  # Only depends on PM2 - UI tools are independent of Claude Code
  depends_on = [coder_script.install_pm2]
  # UI is non-blocking for login (doesn't need to block user access)
  start_blocks_login = false
  timeout = 600  # Increased for slow networks and retries
}

# Vibe Kanban - AI agent orchestration board
resource "coder_script" "vibe_kanban" {
  count        = data.coder_parameter.enable_vibe_kanban.value ? 1 : 0
  agent_id     = coder_agent.main.id
  display_name = "Vibe Kanban"
  icon         = "/icon/code.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "📋 Setting up Vibe Kanban..."

    # Verify npm is available
    if ! command -v npm >/dev/null 2>&1; then
      echo "❌ npm not found, cannot start Vibe Kanban"
      exit 1
    fi

    # Wait for PM2 to be installed (install_pm2 script runs with start_blocks_login=true)
    # But we run without blocking, so we need to wait for PM2 to become available
    echo "⏳ Waiting for PM2 to be installed..."
    for i in {1..60}; do
      if command -v pm2 >/dev/null 2>&1; then
        echo "✅ PM2 found!"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "❌ Timeout waiting for PM2 installation"
        exit 1
      fi
      echo "Waiting for PM2... ($i/60)"
      sleep 2
    done

    # Create data directory for persistence
    mkdir -p /home/coder/.vibe-kanban

    # Stop existing instance if running
    pm2 delete vibe-kanban 2>/dev/null || true

    # Start with PM2 using npx (recommended by official docs)
    # npx handles binary extraction correctly, unlike global install
    echo "🚀 Starting Vibe Kanban on port ${data.coder_parameter.vibe_kanban_port.value}..."
    BACKEND_PORT=${data.coder_parameter.vibe_kanban_port.value} \
    HOST=0.0.0.0 \
    pm2 start "npx vibe-kanban" --name vibe-kanban

    pm2 save
    echo "✅ Vibe Kanban started successfully!"
    pm2 list
  EOT
  run_on_start = true
  run_on_stop  = false
  # Only depends on PM2 - UI tools are independent of Claude Code
  depends_on = [coder_script.install_pm2]
  # Non-blocking for login; kanban is optional UI
  start_blocks_login = false
  timeout = 600  # Increased for slow networks and retries
}

# ========================================
# AI TOOL MODULES
# ========================================

# NOTE: Codex and Copilot modules DISABLED
# Both use agentapi v1.2.0 which ALWAYS creates coder_ai_task regardless of install_agentapi parameter
# This conflicts with gemini's coder_ai_task. Only ONE module with agentapi v1.x can be enabled.
# Waiting for module updates to agentapi v2.x before re-enabling.

# Google Gemini CLI
# Always create module so app appears in panel (module handles empty API key gracefully)
module "gemini" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder-labs/gemini/coder"
  version        = "1.0.0"
  agent_id       = coder_agent.main.id
  gemini_api_key = data.coder_parameter.gemini_api_key.value
  folder         = "/home/coder/projects"
  # This module uses agentapi v1.0.0 which ALWAYS creates coder_ai_task (for Coder Tasks)
  depends_on = [module.claude-code]
}

# Goose AI Agent
# Both modules write to /tmp/install.sh simultaneously causing "Text file busy" error
# Using manual installation script below instead
module "goose" {
  count            = 0 # Disabled due to script conflicts with other modules
  source           = "registry.coder.com/coder/goose/coder"
  version          = "3.0.0"
  agent_id         = coder_agent.main.id
  folder           = "/home/coder/projects"
  install_goose    = true
  goose_provider   = "anthropic"
  goose_model      = "claude-3-5-sonnet-20241022"
  agentapi_version = "v0.11.0"  # Use agentapi v2.x which respects install_agentapi parameter
  install_agentapi = false      # Disable to avoid coder_ai_task conflict
}

# ========================================
# CONFIGURATION MODULES
# ========================================

# NOTE: tmux is installed via apt in install_system_packages
# Configured via dotfiles (.tmux.conf) for session persistence and mouse support
# No separate module needed - tmux binary + dotfiles is sufficient

# ========================================
# DEVELOPER TOOL MODULES
# ========================================

# Dotfiles - custom script (module has prompting issues with presets)
resource "coder_script" "dotfiles" {
  agent_id     = coder_agent.main.id
  display_name = "Dotfiles"
  icon         = "/icon/dotfiles.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    # Use hardcoded dotfiles URL since module prompts despite defaults
    DOTFILES_URI="https://github.com/xoojulian/coder-dotfiles.git"

    echo "📦 Cloning dotfiles from $DOTFILES_URI..."
    rm -rf ~/.dotfiles
    git clone "$DOTFILES_URI" ~/.dotfiles

    # Run install script if it exists
    if [ -f ~/.dotfiles/install.sh ]; then
      echo "🔧 Running dotfiles install script..."
      cd ~/.dotfiles && bash install.sh
    else
      # Create symlinks for all dotfiles
      echo "🔗 Creating symlinks..."
      for file in ~/.dotfiles/.*; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "." ] && [ "$(basename "$file")" != ".." ] && [ "$(basename "$file")" != ".git" ]; then
          ln -sf "$file" ~/
          echo "✓ Linked $(basename "$file")"
        fi
      done
    fi

    echo "✅ Dotfiles installed!"
  EOT
  run_on_start       = true
  run_on_stop        = false
  start_blocks_login = false
  timeout            = 300
}

# Git Clone (conditional on repo URL)
module "git-clone" {
  count    = data.coder_parameter.git_clone_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.12"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_clone_repo_url.value
  base_dir = "/home/coder"
}

# GitHub SSH Key Upload (conditional on GitHub auth)
module "github-upload-public-key" {
  count    = data.coder_external_auth.github.access_token != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/github-upload-public-key/coder"
  version  = "1.0.31"
  agent_id = coder_agent.main.id
}

# ========================================
# OPTIONAL UI/TOOL MODULES
# ========================================

# File Browser (conditional toggle)
module "filebrowser" {
  count    = data.coder_parameter.enable_filebrowser.value ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/filebrowser/coder"
  version  = "1.0.8"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

# KasmVNC Desktop (conditional toggle)
module "kasmvnc" {
  count                = data.coder_parameter.enable_kasmvnc.value ? data.coder_workspace.me.start_count : 0
  source               = "registry.coder.com/coder/kasmvnc/coder"
  version              = "1.2.5"
  agent_id             = coder_agent.main.id
  desktop_environment  = "xfce"
}

# Archive Tool
module "archive" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/archive/coder"
  version  = "0.0.1"
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
    "ms-python.python",
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
  count      = 0  # Disabled to allow CLI automation
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
  share        = "owner"  # Only workspace owner can access
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
  share        = "owner"  # Only workspace owner can access
  subdomain    = true
  open_in      = "tab"
  order        = 2

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.vibe_kanban_port.value}/"
    interval  = 10
    threshold = 30  # Increased threshold for slower startup
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
