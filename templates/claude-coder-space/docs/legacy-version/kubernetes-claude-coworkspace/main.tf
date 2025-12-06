terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces). If the Coder host is itself running as a Pod on the same Kubernetes cluster as you are deploying workspaces to, set this to the same namespace."
  default     = "coder-workspaces"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  default      = "4"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "6 Cores"
    value = "6"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "The amount of memory in GB"
  default      = "8"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "12 GB"
    value = "12"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB (for home directory and Docker cache)"
  default      = "30"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 10
    max = 99999
  }
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

# Claude Code module (latest version)
# CHANGED: Always run, regardless of auth status - Claude Code works without auth
module "claude-code" {
  count   = data.coder_workspace.me.start_count # ALWAYS install Claude Code
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.0" # Use latest 4.x version, fallback to 3.x if unavailable

  agent_id                     = coder_agent.main.id
  workdir                      = "/home/coder/projects"
  order                        = 999
  ai_prompt                    = data.coder_task.me.prompt # Use task prompt, not parameter
  system_prompt                = data.coder_parameter.system_prompt.value
  model                        = "sonnet"
  permission_mode              = "bypassPermissions"
  post_install_script          = "" # Empty - we'll use a separate script for MCP setup
  dangerously_skip_permissions = "true"
  # Authentication (optional - Claude Code works without it)
  claude_api_key          = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""
}

# MCP Server Configuration Script
# Runs AFTER Claude Code module installs the CLI
resource "coder_script" "configure_mcp_servers" {
  agent_id     = coder_agent.main.id
  display_name = "Configure MCP Servers"
  icon         = "/icon/docker.svg"
  script       = <<-EOT
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
  timeout            = 600
}

# Workspace preset with Docker-in-Docker example
data "coder_workspace_preset" "default" {
  name    = "Real World App with Docker: Angular + Django"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant that can help with code. You are running inside a Coder Workspace with Docker-in-Docker support (Envbox). You provide status updates to the user via Coder MCP. Stay on track, feel free to debug, but when the original plan fails, do not choose a different route/architecture without checking the user first.

      -- Available Tools --
      - Docker & Docker Compose: Full support for containerized development
      - Built-in tools: use for file operations, git commands, builds & installs, one-off shell commands

      Remember this decision rule:
      - Stays running? → Docker (docker-compose up -d)
      - Finishes immediately? → built-in tools

      -- Docker Support --
      This workspace has full Docker-in-Docker capability via Envbox. You can:
      - Run `docker build` and `docker-compose up`
      - Create Dockerfiles and docker-compose.yml
      - Use Docker for development environments
      - Run containerized databases, services, etc.
      - Test containerized applications locally
    EOT

    "setup_script" = <<-EOT
    # Set up projects dir
    mkdir -p /home/coder/projects
    cd $HOME/projects

    # Packages: Install additional packages with error handling
    echo "Installing packages..."
    sudo apt-get update
    sudo apt-get install -y --fix-missing tmux curl wget git || \
      sudo apt-get install -y --fix-missing tmux curl wget || \
      echo "⚠ Some packages failed to install, continuing..."

    # Docker: Verify Docker is working
    if command -v docker >/dev/null 2>&1; then
      echo "✓ Docker is available"
      docker version
    else
      echo "⚠ Docker not found (expected with Envbox)"
    fi

    # Optional: Install Playwright (requires Node.js to be pre-installed in image)
    # if command -v npx >/dev/null 2>&1 && ! command -v google-chrome >/dev/null 2>&1; then
    #   yes | npx playwright install chrome
    # fi

    # Optional: Install MCP Server packages (requires Node.js to be pre-installed)
    # if command -v npm >/dev/null 2>&1; then
    #   npm install -g @wonderwhy-er/desktop-commander
    # fi

    # Workspace is ready!
    echo "✅ Workspace setup complete!"
    echo "Docker is available - try: docker run hello-world"

    # Return success
    exit 0
    EOT

    "preview_port"    = "3000"
    "container_image" = "codercom/enterprise-base:ubuntu"
  }
}

# Advanced parameters (these are all set via preset)
data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for the agent with generalized instructions"
  mutable      = false
}

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  default     = ""
  description = "Write a prompt for Claude Code"
  mutable     = true
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Script to run before running the agent"
  mutable      = false
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Inner Container Image"
  type         = "string"
  description  = "Docker image to use for the workspace (runs inside Envbox)"
  default      = "codercom/enterprise-base:ubuntu"
  mutable      = false
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "The port the web app is running to preview in Tasks"
  type         = "number"
  default      = "3000"
  mutable      = false
}

data "coder_parameter" "claude_api_key" {
  name         = "claude_api_key"
  display_name = "Anthropic API Key (Optional)"
  description  = "API key for Anthropic Claude. Leave empty if using OAuth token. Generate one at: https://console.anthropic.com/settings/keys"
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

data "coder_parameter" "claude_oauth_token" {
  name         = "claude_oauth_token"
  display_name = "Anthropic OAuth Token (Optional)"
  description  = "OAuth token for Anthropic Claude subscription. Leave empty if using API key. Generate with: claude setup-token"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Required for AI Tasks - provides task metadata including the prompt
data "coder_task" "me" {}

locals {
  has_claude_auth = length(data.coder_parameter.claude_api_key.value) > 0 || length(data.coder_parameter.claude_oauth_token.value) > 0
  # Prioritize OAuth token over API key if both are provided
  use_oauth_token = length(data.coder_parameter.claude_oauth_token.value) > 0
  use_api_key     = length(data.coder_parameter.claude_api_key.value) > 0 && !local.use_oauth_token
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e
    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Run the setup script from the preset
    ${data.coder_parameter.setup_script.value}
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  env = merge({
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
    },
    # Set custom Anthropic API endpoint if provided
    length(data.coder_parameter.claude_api_endpoint.value) > 0 ? {
      ANTHROPIC_BASE_URL = data.coder_parameter.claude_api_endpoint.value
    } : {}
  )

  # Metadata for workspace monitoring
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

# Set up Claude API key environment variable if provided
resource "coder_env" "claude_api_key" {
  count    = local.use_api_key ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "CLAUDE_API_KEY"
  value    = data.coder_parameter.claude_api_key.value
}

# Set up Claude OAuth token environment variable if provided
resource "coder_env" "claude_oauth_token" {
  count    = local.use_oauth_token ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_OAUTH_TOKEN"
  value    = data.coder_parameter.claude_oauth_token.value
}

# Set up system prompt for the module
resource "coder_env" "claude_system_prompt" {
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_SYSTEM_PROMPT"
  value    = data.coder_parameter.system_prompt.value
}

# IDE Modules
module "code-server" {
  count  = data.coder_workspace.me.start_count
  folder = "/home/coder/projects"
  source = "registry.coder.com/coder/code-server/coder"

  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }

  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  order    = 1
}

module "windsurf" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/windsurf/coder"
  version  = "1.1.0"
  agent_id = coder_agent.main.id
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.2.0"
  agent_id = coder_agent.main.id
}

# JetBrains module temporarily disabled for Docker testing
# module "jetbrains" {
#   count      = data.coder_workspace.me.start_count
#   source     = "registry.coder.com/coder/jetbrains/coder"
#   version    = "~> 1.0"
#   agent_id   = coder_agent.main.id
#   agent_name = "main"
#   folder     = "/home/coder/projects"
# }

# Persistent Volume Claim for home directory and Docker cache
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      # Coder-specific labels
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
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
    # K3s uses local-path storage class by default
    # Uncomment if you want to explicitly specify it:
    # storage_class_name = "local-path"
  }
}

# Preview app
resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview your app"
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

# Pod with Envbox (Docker-in-Docker)
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
    # Outer container: Envbox (privileged, manages Sysbox runtime)
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

      # Volume mounts for Envbox
      # 1. Home directory (persistent)
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        sub_path   = "home"
        read_only  = false
      }

      # 2. Docker data (persistent)
      volume_mount {
        mount_path = "/var/lib/coder/docker"
        name       = "home"
        sub_path   = "cache/docker"
        read_only  = false
      }

      # 3. Coder containers cache (persistent)
      volume_mount {
        mount_path = "/var/lib/coder/containers"
        name       = "home"
        sub_path   = "cache/containers"
        read_only  = false
      }

      # 4. Envbox containers (persistent)
      volume_mount {
        mount_path = "/var/lib/containers"
        name       = "home"
        sub_path   = "envbox/containers"
        read_only  = false
      }

      # 5. Envbox Docker (persistent)
      volume_mount {
        mount_path = "/var/lib/docker"
        name       = "home"
        sub_path   = "envbox/docker"
        read_only  = false
      }

      # 6. Sysbox runtime (ephemeral)
      volume_mount {
        mount_path = "/var/lib/sysbox"
        name       = "sysbox"
        read_only  = false
      }

      # 7. Kernel source (readonly, from host)
      volume_mount {
        mount_path = "/usr/src"
        name       = "usr-src"
        read_only  = true
      }

      # 8. Kernel modules (readonly, from host)
      volume_mount {
        mount_path = "/lib/modules"
        name       = "lib-modules"
        read_only  = true
      }
    }

    # Volume definitions
    # Persistent storage (PVC)
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    # Ephemeral storage (EmptyDir for Sysbox)
    volume {
      name = "sysbox"
      empty_dir {}
    }

    # Host paths (kernel source and modules)
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
