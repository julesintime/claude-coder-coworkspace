# Solution: Running Gemini and Claude Code Modules Together

## Problem Analysis

### Root Cause
The conflict occurs because:

1. **Coder allows only ONE `coder_ai_task` resource per workspace**
2. **Gemini module v1.0.0** uses `agentapi module v1.0.0` which:
   - **ALWAYS creates `coder_ai_task.agentapi`** (unconditionally)
   - The `install_agentapi = false` parameter only controls binary installation
   - Does NOT control Terraform resource creation

3. **Claude Code module v4.0.0** uses `agentapi module v2.0.0` which:
   - Does NOT create `coder_ai_task`
   - Only exports `task_app_id` output
   - Lets parent module decide whether to create `coder_ai_task`

4. **Our manual `coder_ai_task.main`** (line 1086-1090 in main.tf):
   - Uses `app_id = module.claude-code[0].task_app_id`
   - Conflicts with gemini's auto-created `coder_ai_task.agentapi`

### Technical Deep Dive

**Agentapi v1.0.0 (gemini.agentapi/main.tf):**
```terraform
# Line 209-213: UNCONDITIONAL coder_ai_task creation
resource "coder_ai_task" "agentapi" {
  sidebar_app {
    id = coder_app.agentapi_web.id
  }
}
```

**Agentapi v2.0.0 (claude-code.agentapi/main.tf):**
```terraform
# NO coder_ai_task resource!
# Line 242-244: Only exports app ID
output "task_app_id" {
  value = coder_app.agentapi_web.id
}
```

---

## Solution Options

### ✅ SOLUTION 1: Create Local Gemini Module (Recommended)

**Pros:**
- ✅ Keeps full gemini module functionality (web UI + CLI)
- ✅ Both modules work together seamlessly
- ✅ No conflicts
- ✅ Future-proof and maintainable

**Steps:**

1. **Create local module directory:**
```bash
mkdir -p unified-devops/modules/gemini-fixed
```

2. **Download gemini module source:**
```bash
# Get current gemini module files
cp -r .terraform/modules/gemini/* modules/gemini-fixed/
```

3. **Modify `modules/gemini-fixed/main.tf`:**

Change line 167-169 from:
```terraform
module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "1.0.0"  # OLD VERSION
```

To:
```terraform
module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "2.0.0"  # UPGRADED VERSION
```

4. **Add task_app_id output to `modules/gemini-fixed/main.tf`:**

Add at the end of the file:
```terraform
output "task_app_id" {
  value       = module.agentapi.task_app_id
  description = "The ID of the AgentAPI web app for use in coder_ai_task"
}
```

5. **Update `unified-devops/main.tf` to use local module:**

Change lines 1292-1300 from:
```terraform
# module "gemini" {
#   count            = data.coder_workspace.me.start_count
#   source           = "registry.coder.com/coder-labs/gemini/coder"
#   version          = "1.0.0"
```

To:
```terraform
module "gemini" {
  count            = local.has_gemini_key ? data.coder_workspace.me.start_count : 0
  source           = "./modules/gemini-fixed"  # LOCAL MODULE
  agent_id         = coder_agent.main.id
  gemini_api_key   = data.coder_parameter.gemini_api_key.value
  folder           = "/home/coder/projects"
  install_agentapi = false  # Let claude-code handle agentapi
}
```

6. **Keep manual coder_ai_task pointing to claude-code:**

Lines 1086-1090 remain unchanged - Claude Code is the primary Tasks UI.

---

### ✅ SOLUTION 2: Manual Gemini CLI Installation (Simpler)

**Pros:**
- ✅ Simple implementation
- ✅ No module conflicts
- ✅ Gemini CLI fully functional

**Cons:**
- ❌ No Gemini web UI
- ❌ Only CLI access

**Implementation:**

Add this to `unified-devops/main.tf`:

```terraform
# Manual Gemini CLI installation (no web UI, no conflicts)
resource "coder_script" "gemini_cli" {
  count        = local.has_gemini_key ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.main.id
  display_name = "Install Gemini CLI"
  icon         = "/icon/gemini.svg"
  script = <<-EOT
    #!/bin/bash
    set -e

    echo "📦 Installing Gemini CLI..."

    # Install Gemini CLI via npm
    if ! command -v gemini >/dev/null 2>&1; then
      sudo npm install -g @google/generative-ai-cli
    fi

    # Configure API key
    if [ -n "${data.coder_parameter.gemini_api_key.value}" ]; then
      mkdir -p ~/.gemini
      cat > ~/.gemini/config.json <<EOF
{
  "apiKey": "${data.coder_parameter.gemini_api_key.value}",
  "model": "gemini-2.5-pro"
}
EOF
    fi

    echo "✅ Gemini CLI installed! Use 'gemini' command."
    gemini --version || true
  EOT
  run_on_start = true
  run_on_stop  = false
  depends_on   = [coder_script.install_system_packages]
  start_blocks_login = false
  timeout = 300
}
```

---

### ✅ SOLUTION 3: Switchable Task UI (Advanced)

**Pros:**
- ✅ User chooses which AI tool appears in Coder Tasks UI
- ✅ Both modules fully functional
- ✅ Flexible

**Cons:**
- ❌ More complex configuration
- ❌ Only one AI tool visible in Tasks UI at a time

**Implementation:**

1. **Add parameter for task UI selection:**

```terraform
data "coder_parameter" "ai_task_tool" {
  name         = "ai_task_tool"
  display_name = "Primary AI Tool for Tasks UI"
  description  = "Which AI tool should appear in the Coder Tasks sidebar"
  default      = "claude-code"
  type         = "string"
  mutable      = false

  option {
    name  = "Claude Code"
    value = "claude-code"
  }

  option {
    name  = "Gemini"
    value = "gemini"
  }
}
```

2. **Conditional coder_ai_task creation:**

```terraform
# Use local gemini-fixed module (from Solution 1)
module "gemini" {
  count            = local.has_gemini_key ? data.coder_workspace.me.start_count : 0
  source           = "./modules/gemini-fixed"
  agent_id         = coder_agent.main.id
  gemini_api_key   = data.coder_parameter.gemini_api_key.value
  folder           = "/home/coder/projects"
  install_agentapi = false
}

# Conditional task UI - Claude Code
resource "coder_ai_task" "claude_task" {
  count  = data.coder_parameter.ai_task_tool.value == "claude-code" ? 1 : 0
  app_id = module.claude-code[0].task_app_id
}

# Conditional task UI - Gemini
resource "coder_ai_task" "gemini_task" {
  count  = data.coder_parameter.ai_task_tool.value == "gemini" && local.has_gemini_key ? 1 : 0
  app_id = module.gemini[0].task_app_id
}
```

---

## Recommended Implementation

**For most users: SOLUTION 1 (Local Gemini Module)**

This provides the best balance of:
- Full functionality for both AI tools
- Clean architecture
- No conflicts
- Easy maintenance

**For quick CLI-only usage: SOLUTION 2 (Manual CLI)**

If you only need Gemini as a command-line alternative to Claude and don't require the web UI.

---

## Verification Steps

After implementing any solution:

1. **Run terraform init:**
```bash
cd unified-devops
terraform init -upgrade
```

2. **Validate configuration:**
```bash
terraform validate
```

3. **Check for conflicts:**
```bash
terraform plan
# Look for any errors about "only one coder_ai_task"
```

4. **Test in workspace:**
```bash
# After workspace creation:
claude --version
gemini --version
```

---

## Additional Notes

### Why This Happened

The Coder team released agentapi v2.0.0 to fix this exact issue - allowing multiple AI tool modules to coexist. However, older modules (like gemini v1.0.0) still use agentapi v1.0.0 which has the unconditional `coder_ai_task` creation bug.

### Future Updates

Monitor the Coder registry for:
- Gemini module v2.0.0 (if/when released)
- Other AI tool modules using agentapi v2.0.0

Once gemini module is updated in the registry, you can switch back from the local module.

### Module Compatibility Matrix

| Module | Version | AgentAPI Version | Creates coder_ai_task | Compatible |
|--------|---------|------------------|----------------------|------------|
| claude-code | 4.0.0 | 2.0.0 | ❌ No (exports task_app_id) | ✅ Yes |
| gemini | 1.0.0 | 1.0.0 | ✅ Yes (unconditional) | ❌ Conflicts |
| gemini-fixed (local) | 1.0.0 | 2.0.0 | ❌ No (exports task_app_id) | ✅ Yes |
| goose | 3.0.0 | 2.x | ❌ No (respects install_agentapi) | ✅ Yes |

---

## Questions or Issues?

If you encounter problems:

1. Check Terraform version: `terraform version` (requires >= 1.0)
2. Verify module sources are accessible
3. Check Coder provider version: `>= 2.12` required for coder_ai_task app_id field
4. Review Coder logs for any task registration errors

