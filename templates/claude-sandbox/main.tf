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
  description = "Use host kubeconfig? (false if Coder runs in same K8s cluster)"
  default     = false
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces"
  default     = "coder-workspaces"
}

# ========================================
# WORKSPACE PARAMETERS
# ========================================

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  description  = "Docker image for the workspace"
  type         = "string"
  default      = "codercom/enterprise-node:ubuntu"
  mutable      = true
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

# ========================================
# CODER AGENT
# ========================================

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # Minimal setup
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Create workspace directory
    mkdir -p /home/coder/workspace

    echo "✅ Sandbox ready!"
  EOT

  # Workspace metadata
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
}

# ========================================
# OFFICIAL MODULES (registry.coder.com)
# ========================================

# Claude Code - Primary AI coding assistant
module "claude-code" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.2"

  agent_id = coder_agent.main.id
  workdir  = "/home/coder/workspace"
  order    = 999

  # Provision-time prompt injection from Coder Tasks
  ai_prompt = data.coder_task.me.prompt

  # Sandbox-specific system prompt (optional)
  system_prompt = <<-EOT
    You are Claude Code running in a minimal sandbox environment.

    Environment details:
    - Container: Ubuntu (lightweight)
    - Kubernetes pod (simple, no Envbox)
    - Resources: 2 CPU, 4GB RAM
    - Tooling: Node.js, Python, git, curl, jq

    Guidelines:
    - Keep code simple and self-contained
    - Avoid large dependencies
    - Use external git repos for persistence
    - Focus on rapid iteration and experimentation
  EOT

  model           = "sonnet"
  permission_mode = "bypassPermissions"
}

# Dotfiles - Official module (dynamic GitHub fetch)
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id

  # Users can override in Coder UI: Account → Dotfiles
  # Default to the coder-dotfiles submodule repo
  default_dotfiles_uri = "https://github.com/julesintime/coder-dotfiles.git"
}

# Personalize - Git configuration from Coder user data
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

# Code Server - Lightweight VS Code
module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/workspace"
  order    = 1

  settings = {
    "files.autoSave" : "afterDelay"
  }

  # Minimal extensions for sandbox
  extensions = []
}

# Coder AI Task integration
resource "coder_ai_task" "main" {
  count  = data.coder_workspace.me.start_count
  app_id = module.claude-code[0].task_app_id
}

# ========================================
# KUBERNETES RESOURCES
# ========================================

# Persistent Volume Claim (20GB)
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
        storage = "20Gi"
      }
    }
  }
}

# Simple Kubernetes Pod (no Envbox - faster startup!)
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
    # Single container (no Envbox overhead)
    container {
      name    = "dev"
      image   = data.coder_parameter.container_image.value
      command = ["sh", "-c", coder_agent.main.init_script]

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      # Lightweight resource limits
      resources {
        requests = {
          cpu    = "500m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }

      # Volume mount
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }

    # Volume
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }
  }
}
