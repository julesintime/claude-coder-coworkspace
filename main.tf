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

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores allocated to the workspace (1, 2, 4, 6, 8, or 16)"
  default      = "4"
  type         = "number"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 1
    max = 16
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "Amount of memory in GB (2-64)"
  default      = "16"
  type         = "number"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 2
    max = 64
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home Disk Size"
  description  = "Size of the home disk in GB (includes Docker cache and container storage)"
  default      = "50"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 10
    max = 500
  }
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  description  = "Docker image to use for the workspace (runs inside Envbox)"
  default      = "codercom/enterprise-node:ubuntu"
  mutable      = false
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "Port for application preview in Coder Tasks"
  type         = "number"
  default      = "3000"
  mutable      = false
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
}

data "coder_parameter" "claude_oauth_token" {
  name         = "claude_oauth_token"
  display_name = "Claude OAuth Token (Optional)"
  description  = "OAuth token for Claude subscription. Leave empty if using API key. Generate with: claude setup-token"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "claude_api_endpoint" {
  name         = "claude_api_endpoint"
  display_name = "Anthropic API Endpoint (Optional)"
  description  = "Custom API endpoint for Anthropic Claude (optional, defaults to official endpoint)"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "gemini_api_key" {
  name         = "gemini_api_key"
  display_name = "Google Gemini API Key (Optional)"
  description  = "API key for Google Gemini CLI. Generate at: https://aistudio.google.com/apikey"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "github_token" {
  name         = "github_token"
  display_name = "GitHub Personal Access Token (Optional)"
  description  = "GitHub PAT for gh CLI and Copilot. Generate at: https://github.com/settings/tokens"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "gitea_url" {
  name         = "gitea_url"
  display_name = "Gitea Instance URL (Optional)"
  description  = "URL of your Gitea instance (e.g., https://gitea.example.com)"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "gitea_token" {
  name         = "gitea_token"
  display_name = "Gitea Access Token (Optional)"
  description  = "Gitea access token for tea CLI authentication"
  type         = "string"
  default      = ""
  mutable      = true
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
  mutable      = false
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

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "ai_prompt"
  default     = ""
  description = "Initial prompt for Claude Code on workspace startup"
  mutable     = true
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Bash script to run before starting the AI agent"
  mutable      = false
  default      = <<-EOT
    #!/bin/bash
    set -e

    echo "🚀 Starting Unified DevOps Workspace Setup..."

    # Create project directory
    mkdir -p /home/coder/projects
    cd /home/coder/projects

    # Configure tmux
    echo "⚙️ Configuring tmux..."
    mkdir -p ~/.config/tmux
    cat > ~/.tmux.conf << 'TMUX_EOF'
# Enable mouse support
set -g mouse on

# Improve colors
set -g default-terminal "screen-256color"

# Set scrollback buffer
set -g history-limit 50000

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1
TMUX_EOF

    # System packages and CLIs (using apt for easier upgrades)
    echo "📦 Installing system packages and CLIs..."
    sudo apt-get update
    sudo apt-get install -y --fix-missing \
      tmux curl wget git jq \
      build-essential \
      python3-pip \
      || echo "⚠️ Some packages failed, continuing..."

    # Docker verification
    if command -v docker >/dev/null 2>&1; then
      echo "✓ Docker is available"
      docker version
    else
      echo "⚠️ Docker not found (expected with Envbox)"
    fi

    # Kubernetes CLI (kubectl) via apt
    if ! command -v kubectl >/dev/null 2>&1; then
      echo "📦 Installing kubectl via apt..."
      sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubectl
    fi

    # GitHub CLI via apt
    if ! command -v gh >/dev/null 2>&1; then
      echo "📦 Installing GitHub CLI via apt..."
      (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y
    fi

    # Gitea CLI (tea) via apt
    if ! command -v tea >/dev/null 2>&1; then
      echo "📦 Installing Gitea CLI (tea) via apt..."
      wget -qO- https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64 -O /tmp/tea \
        && sudo install -m 755 /tmp/tea /usr/local/bin/tea \
        && rm /tmp/tea
    fi

    # TypeScript verification (should be pre-installed in enterprise-node image)
    if command -v tsc >/dev/null 2>&1; then
      echo "✓ TypeScript already installed: $(tsc --version)"
    else
      echo "📦 Installing TypeScript globally..."
      if command -v npm >/dev/null 2>&1; then
        sudo npm install -g typescript || echo "⚠️ TypeScript installation failed, skipping..."
      fi
    fi

    # Gemini CLI (via npm for auto-updates)
    if ! command -v gemini >/dev/null 2>&1; then
      echo "📦 Installing Gemini CLI..."
      if command -v npm >/dev/null 2>&1; then
        sudo npm install -g @google/generative-ai-cli || echo "⚠️ Gemini CLI installation failed, skipping..."
      else
        echo "⚠️ npm not found, skipping Gemini CLI installation"
      fi
    fi

    # Claude Code CLI (via npm for auto-updates)
    if ! command -v claude >/dev/null 2>&1; then
      echo "📦 Installing Claude Code CLI..."
      if command -v npm >/dev/null 2>&1; then
        sudo npm install -g @anthropic-ai/claude-code || echo "⚠️ Claude CLI installation failed, skipping..."
      fi
    fi

    # MCP Servers (using claude mcp add)
    if command -v claude >/dev/null 2>&1; then
      echo "📦 Configuring MCP servers with Claude Code..."
      # Add MCP servers using claude mcp add with appropriate transports
      claude mcp add --transport http context7 https://mcp.context7.com/mcp || echo "⚠️ context7 MCP server failed to add"
      claude mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking || echo "⚠️ sequential-thinking MCP server failed to add"
      claude mcp add --transport http deepwiki https://mcp.deepwiki.com/mcp || echo "⚠️ deepwiki MCP server failed to add"
      echo "✓ MCP servers configured (context7, sequential-thinking, deepwiki)"
    else
      echo "⚠️ Claude CLI not available, skipping MCP server configuration"
    fi

    # Bash aliases and configuration
    echo "⚙️ Configuring bash aliases..."
    cat >> ~/.bashrc << 'EOF'

# ========================================
# Unified DevOps Template Aliases
# ========================================

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

    echo "✅ Workspace setup complete!"
    echo "🎯 Available AI tools: Claude Code (cc-c), Gemini CLI"
    echo "🎯 MCP servers: context7, sequential-thinking, deepwiki"
    echo "🐳 Docker is ready - try: docker run hello-world"
    echo "☸️ Kubernetes is ready - try: kubectl version"

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
# AI MODULES
# ========================================

# Claude Code module (latest version)
# Note: Checking for 4.x version or using latest available
module "claude-code" {
  count   = local.has_claude_auth ? data.coder_workspace.me.start_count : 0
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.0" # Use latest 4.x version, fallback to 3.x if unavailable

  agent_id            = coder_agent.main.id
  workdir             = "/home/coder/projects"
  order               = 999
  ai_prompt           = data.coder_parameter.ai_prompt.value
  system_prompt       = data.coder_parameter.system_prompt.value
  model               = "sonnet"
  permission_mode     = "plan"
  post_install_script = data.coder_parameter.setup_script.value

  # Authentication
  claude_api_key          = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""
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
    "workbench.colorTheme" : "Default Dark Modern"
    "editor.formatOnSave" : true
    "files.autoSave" : "afterDelay"
  }

  # Extensions - these will use the GITHUB_TOKEN environment variable for authentication
  # Note: GitHub extensions (copilot, copilot-chat) and C++ tools not available in code-server marketplace
  extensions = [
    "ms-python.python",
    "hashicorp.terraform",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "ms-azuretools.vscode-docker",
    "eamodio.gitlens"
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

# JetBrains IDEs
module "jetbrains" {
  count      = data.coder_workspace.me.start_count
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
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
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
          "cpu"    = "${data.coder_parameter.cpu.value}"
          "memory" = "${data.coder_parameter.memory.value}Gi"
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
