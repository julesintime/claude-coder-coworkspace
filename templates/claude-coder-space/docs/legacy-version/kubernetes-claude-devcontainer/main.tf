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
# WORKSPACE PARAMETERS - PRESETS
# ========================================

data "coder_workspace_preset" "nano" {
  name = "Nano (1CPU/2GB/20GB)"
  parameters = {
    preset             = "nano"
    git_clone_repo_url = ""
    git_clone_path     = "/home/node/projects/repo"
  }
}

data "coder_workspace_preset" "mini" {
  name    = "Mini (2CPU/8GB/50GB)"
  default = true
  parameters = {
    preset             = "mini"
    git_clone_repo_url = ""
    git_clone_path     = "/home/node/projects/repo"
  }
}

data "coder_workspace_preset" "mega" {
  name = "Mega (8CPU/32GB/200GB)"
  parameters = {
    preset             = "mega"
    git_clone_repo_url = ""
    git_clone_path     = "/home/node/projects/repo"
  }
}

data "coder_parameter" "preset" {
  name         = "preset"
  display_name = "Workspace Preset"
  description  = "Choose a preset configuration for CPU, RAM, and disk"
  default      = "mini"
  type         = "string"
  icon         = "/icon/gear.svg"
  mutable      = true
  ephemeral    = false

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

data "coder_parameter" "git_clone_repo_url" {
  name         = "git_clone_repo_url"
  display_name = "Git Clone Repository URL (Optional)"
  description  = "Git repository to automatically clone into workspace"
  type         = "string"
  default      = ""
  mutable      = true
  ephemeral    = false
}

data "coder_parameter" "git_clone_path" {
  name         = "git_clone_path"
  display_name = "Git Clone Path"
  description  = "Directory path where repository will be cloned"
  type         = "string"
  default      = "/home/node/projects/repo"
  mutable      = true
  ephemeral    = false
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
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

# ========================================
# LOCALS
# ========================================

locals {
  # Preset configurations
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

  # Use preset values
  cpu_value    = local.preset_configs[data.coder_parameter.preset.value].cpu
  memory_value = local.preset_configs[data.coder_parameter.preset.value].memory
  disk_value   = local.preset_configs[data.coder_parameter.preset.value].disk

  has_claude_auth = length(data.coder_parameter.claude_api_key.value) > 0 || length(data.coder_parameter.claude_oauth_token.value) > 0
  use_oauth_token = length(data.coder_parameter.claude_oauth_token.value) > 0
  use_api_key     = length(data.coder_parameter.claude_api_key.value) > 0 && !local.use_oauth_token
  has_gemini_key  = length(data.coder_parameter.gemini_api_key.value) > 0

  # GitHub authentication - prioritize external auth, fall back to parameter
  has_github_external_auth = data.coder_external_auth.github.access_token != ""
  has_github_param_token   = length(data.coder_parameter.github_token.value) > 0
  github_token             = local.has_github_external_auth ? data.coder_external_auth.github.access_token : data.coder_parameter.github_token.value
  has_github_token         = local.has_github_external_auth || local.has_github_param_token
}

# ========================================
# CODER AGENT
# ========================================

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Minimal startup script - devcontainer handles the rest
  startup_script = <<-EOT
    set -e

    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ 2>/dev/null || true
      touch ~/.init_done
    fi

    echo "✅ Workspace ready! DevContainer will handle environment setup..."
  EOT

  # Environment variables for AI tools and authentication
  env = merge(
    {
      # Enable devcontainers support
      CODER_AGENT_DEVCONTAINERS_ENABLE = "true"

      # Git configuration
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

# ========================================
# DEVCONTAINER SUPPORT
# ========================================

# Install devcontainers CLI
module "devcontainers-cli" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/devcontainers-cli/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}

# Configure devcontainer to start automatically
resource "coder_devcontainer" "main" {
  count            = data.coder_workspace.me.start_count
  agent_id         = coder_agent.main.id
  workspace_folder = "/home/node/projects"

  depends_on = [module.devcontainers-cli]
}

# ========================================
# AI MODULES
# ========================================

# Claude Code module (handles MCP configuration)
module "claude-code" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.2"

  agent_id                     = coder_agent.main.id
  workdir                      = "/home/node/projects"
  order                        = 999
  model                        = "sonnet"
  permission_mode              = "bypassPermissions"
  dangerously_skip_permissions = "true"

  # Authentication (optional - Claude Code works without it)
  claude_api_key          = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""

  # MCP Server Configuration (JSON format)
  mcp = jsonencode({
    mcpServers = {
      context7 = {
        url = "https://mcp.context7.com/mcp"
      }
      sequential-thinking = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-sequential-thinking"]
      }
      deepwiki = {
        url = "https://mcp.deepwiki.com/mcp"
      }
    }
  })
}

# ========================================
# DEVELOPER TOOL MODULES
# ========================================

# Dotfiles - Official Coder module
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "1.0.14"
  agent_id = coder_agent.main.id
}

# Git Clone (conditional on repo URL)
module "git-clone" {
  count    = data.coder_parameter.git_clone_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.12"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_clone_repo_url.value
  base_dir = "/home/node"
}

# ========================================
# IDE MODULES
# ========================================

# VS Code (code-server)
module "code-server" {
  count   = data.coder_workspace.me.start_count
  folder  = "/home/node/projects"
  source  = "registry.coder.com/coder/code-server/coder"
  version = "~> 1.0"

  agent_id = coder_agent.main.id
  order    = 1

  settings = {
    "window.autoDetectColorScheme" : true
    "editor.formatOnSave" : true
    "files.autoSave" : "afterDelay"
    "terminal.integrated.defaultProfile.linux" : "bash"
  }

  extensions = [
    "ms-azuretools.vscode-docker",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "johnpapa.vscode-peacock",
    "coder.coder-remote"
  ]
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
        value = "mcr.microsoft.com/devcontainers/typescript-node:latest"
      }

      env {
        name  = "CODER_INNER_USERNAME"
        value = "node"
      }

      env {
        name  = "CODER_BOOTSTRAP_SCRIPT"
        value = coder_agent.main.init_script
      }

      env {
        name  = "CODER_MOUNTS"
        value = "/home/node:/home/node"
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
        mount_path = "/home/node"
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
