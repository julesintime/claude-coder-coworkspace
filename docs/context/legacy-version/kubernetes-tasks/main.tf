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
  default      = "2"
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
  default      = "4"
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
  description  = "The size of the home disk in GB"
  default      = "20"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 1
    max = 99999
  }
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

# This template is designed for Docker-based deployments
# The Claude Code module does the automatic task reporting
# Other agent modules: https://registry.coder.com/modules?search=agent
# Or use a custom agent:
module "claude-code" {
  count  = local.has_claude_auth ? data.coder_workspace.me.start_count : 0
  source = "registry.coder.com/coder/claude-code/coder"
  version = "3.0.0"
  agent_id = coder_agent.main.id
  workdir = "/home/coder/projects"
  order = 999
  ai_prompt = data.coder_parameter.ai_prompt.value
  system_prompt = data.coder_parameter.system_prompt.value
  model = "sonnet"
  permission_mode = "plan"
  post_install_script = data.coder_parameter.setup_script.value

  # Pass authentication to the module - it will use the env vars we set above
  claude_api_key = local.use_api_key ? data.coder_parameter.claude_api_key.value : ""
  claude_code_oauth_token = local.use_oauth_token ? data.coder_parameter.claude_oauth_token.value : ""
}

# We are using presets to set the prompts, image, and set up instructions
# See https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets
data "coder_workspace_preset" "default" {
  name    = "Real World App: Angular + Django"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant that can help with code. You are running inside a Coder Workspace and provide status updates to the user via Coder MCP. Stay on track, feel free to debug, but when the original plan fails, do not choose a different route/architecture without checking the user first.

      -- Tool Selection --
      - playwright: previewing your changes after you made them
        to confirm it worked as expected
	    -	desktop-commander - use only for commands that keep running
        (servers, dev watchers, GUI apps).
      -	Built-in tools - use for everything else:
       (file operations, git commands, builds & installs, one-off shell commands)
	    
      Remember this decision rule:
      - Stays running? → desktop-commander
      - Finishes immediately? → built-in tools
      
      -- Context --
      There is an existing app and tmux dev server running on port 8000. Be sure to read it's CLAUDE.md (./realworld-django-rest-framework-angular/CLAUDE.md) to learn more about it. 

      Since this app is for demo purposes and the user is previewing the homepage and subsequent pages, aim to make the first visual change/prototype very quickly so the user can preview it, then focus on backend or logic which can be a more involved, long-running architecture plan.

    EOT

    "setup_script"    = <<-EOT
    # Set up projects dir
    mkdir -p /home/coder/projects
    cd $HOME/projects

    # Packages: Install additional packages
    sudo apt-get update && sudo apt-get install -y tmux
    if ! command -v google-chrome >/dev/null 2>&1; then
      yes | npx playwright install chrome
    fi

    # MCP: Install MCP Server packages (Claude Code module will configure them)
    npm install -g @wonderwhy-er/desktop-commander

    # Repo: Clone and pull changes from the git repository
    if [ ! -d "realworld-django-rest-framework-angular" ]; then
      git clone https://github.com/coder-contrib/realworld-django-rest-framework-angular.git
    else
      cd realworld-django-rest-framework-angular
      git fetch
      # Check for uncommitted changes
      if git diff-index --quiet HEAD -- && \
        [ -z "$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi

      cd ..
    fi

    # Initialize: Start the development server in the background
    cd realworld-django-rest-framework-angular
    nohup ./start-dev.sh > /tmp/start-dev.log 2>&1 &
    
    # Wait a moment for servers to initialize
    sleep 5
    echo "Development servers started in background. Check status with: cd ~/projects/realworld-django-rest-framework-angular && ./start-dev.sh status"
    
    # Return success
    exit 0
    EOT
    "preview_port"    = "4200"
    "container_image" = "codercom/example-universal:ubuntu"
  }

  # Pre-builds is a Coder Premium
  # feature to speed up workspace creation
  # 
  # see https://coder.com/docs/admin/templates/extending-templates/prebuilt-workspaces
  # prebuilds {
  #   instances = 1
  #   expiration_policy {
  #      ttl = 86400  # Time (in seconds) after which unclaimed prebuilds are expired (1 day)
  #  }
  # }
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
  display_name = "Container Image"
  type         = "string"
  default      = "codercom/example-universal:ubuntu"
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

locals {
  has_claude_auth = length(data.coder_parameter.claude_api_key.value) > 0 || length(data.coder_parameter.claude_oauth_token.value) > 0
  # Prioritize OAuth token over API key if both are provided
  use_oauth_token = length(data.coder_parameter.claude_oauth_token.value) > 0
  use_api_key = length(data.coder_parameter.claude_api_key.value) > 0 && !local.use_oauth_token
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
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
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

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
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
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
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
resource "coder_env" "claude_code_oauth_token" {
  count    = local.use_oauth_token ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_OAUTH_TOKEN"
  value    = data.coder_parameter.claude_oauth_token.value
}

# Set up custom API endpoint if provided (NOTE: ANTHROPIC_BASE_URL is already set in the agent's env block above)
# resource "coder_env" "anthropic_base_url" {
#   count    = data.coder_parameter.claude_api_endpoint.value != "" ? 1 : 0
#   agent_id = coder_agent.main.id
#   name     = "ANTHROPIC_BASE_URL"
#   value    = data.coder_parameter.claude_api_endpoint.value
# }

# Set up CLAUDE.md path for the module
resource "coder_env" "claude_code_md_path" {
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_MD_PATH"
  value    = "/home/coder/projects/realworld-django-rest-framework-angular/CLAUDE.md"
}

# Set up system prompt for the module  
resource "coder_env" "claude_code_system_prompt" {
  agent_id = coder_agent.main.id
  name     = "CLAUDE_CODE_SYSTEM_PROMPT"
  value    = data.coder_parameter.system_prompt.value
}

# See https://registry.coder.com/modules/coder/code-server
module "code-server" {
  count  = data.coder_workspace.me.start_count
  folder = "/home/coder/projects"
  source = "registry.coder.com/coder/code-server/coder"

  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

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

module "jetbrains" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/jetbrains/coder"
  version    = "~> 1.0"
  agent_id   = coder_agent.main.id
  agent_name = "main"
  folder     = "/home/coder/projects"
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
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
  }
}

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

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
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
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
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
      }
      spec {
        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        container {
          name              = "dev"
          image             = data.coder_parameter.container_image.value
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}