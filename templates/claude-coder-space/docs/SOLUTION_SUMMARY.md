# Solution: Running Gemini and Claude Code Together

## ✅ Problem Solved

Both **Claude Code v4.2.0** and **Gemini v2.1.1** can now run together without conflicts.

## 🔧 What Was Changed

### 1. Created Local Gemini Module with AgentAPI v2.0.0

**Location:** `modules/gemini/`

**Key Changes:**
- Upgraded agentapi from v1.2.0 → v2.0.0 (line 180 in modules/gemini/main.tf)
- Added `task_app_id` output (lines 230-233)

```terraform
module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "2.0.0"  # ← Changed from 1.2.0
  ...
}

output "task_app_id" {
  value       = module.agentapi.task_app_id
  description = "The ID of the AgentAPI web app for use in coder_ai_task"
}
```

### 2. Updated main.tf Module Configuration

**Claude Code Module** (lines 1057-1074):
```terraform
module "claude-code" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/claude-code/coder"
  version = "~> 4.2" # ← Auto-updates to latest 4.x
  ...
}
```

**Gemini Module** (lines 1289-1296):
```terraform
module "gemini" {
  count            = local.has_gemini_key ? data.coder_workspace.me.start_count : 0
  source           = "./modules/gemini"  # ← Local module
  agent_id         = coder_agent.main.id
  gemini_api_key   = data.coder_parameter.gemini_api_key.value
  folder           = "/home/coder/projects"
  install_agentapi = false  # ← Claude Code already installs agentapi
}
```

**Coder AI Task** (lines 1086-1090):
```terraform
resource "coder_ai_task" "main" {
  count = data.coder_workspace.me.start_count
  app_id = module.claude-code[0].task_app_id  # ← Claude Code is primary UI
}
```

## 📊 Architecture

### Before (Broken)
```
gemini v2.1.1 → agentapi v1.2.0 → creates coder_ai_task (conflict!)
                                      ↓
claude-code v4.2.0 → agentapi v2.0.0 → exports task_app_id
                                      ↓
main.tf → creates coder_ai_task.main (conflict!)

❌ ERROR: Only one coder_ai_task allowed
```

### After (Fixed)
```
gemini (local) → agentapi v2.0.0 → exports task_app_id
claude-code v4.2.0 → agentapi v2.0.0 → exports task_app_id
                                      ↓
main.tf → creates ONE coder_ai_task pointing to claude-code

✅ SUCCESS: Both modules coexist, one coder_ai_task
```

## 🔑 Key Insights

### AgentAPI Evolution

| Version | Module Behavior | Creates coder_ai_task? | Exports task_app_id? |
|---------|----------------|------------------------|---------------------|
| v1.0.0 | Old (buggy) | ✅ Yes (unconditional) | ❌ No |
| v1.2.0 | Old (buggy) | ✅ Yes (unconditional) | ❌ No |
| v2.0.0 | New (fixed) | ❌ No | ✅ Yes |

### Module Compatibility

| Module | Version | AgentAPI | Status |
|--------|---------|----------|--------|
| claude-code | 4.2.0+ | v2.0.0 | ✅ Compatible |
| gemini (registry) | 2.1.1 | v1.2.0 | ❌ Conflicts |
| gemini (local) | 2.1.1 | v2.0.0 | ✅ Compatible |
| goose | 3.0.0+ | v2.0.0 | ✅ Compatible |

## 🚀 How Version Constraints Work

### ~> Operator (Pessimistic Constraint)

```terraform
version = "~> 4.2"  # Allows: 4.2.x, 4.3.x, 4.9.x
                    # Blocks: 5.0.0, 3.x.x

version = "~> 4.2.0"  # Allows: 4.2.x only
                      # Blocks: 4.3.0, 5.0.0
```

### Auto-Update Strategy

**Current Configuration:**
- `claude-code: "~> 4.2"` → Auto-updates to 4.3, 4.4, etc. (safe minor/patch updates)
- `gemini: local module` → Manual update when registry updates to agentapi v2.0.0

**Why This Works:**
- Terraform updates modules on `terraform init -upgrade`
- Version constraints prevent breaking changes (e.g., 5.0.0)
- Both modules stay current with latest features and fixes

## 📁 File Structure

```
unified-devops/
├── main.tf                          # ← Updated: Uses local gemini, ~> 4.2 claude-code
├── modules/
│   └── gemini/
│       ├── main.tf                  # ← Updated: agentapi v2.0.0, task_app_id output
│       └── scripts/
│           ├── install.sh
│           └── start.sh
└── .terraform/
    └── modules/
        ├── claude-code/             # Registry module (auto-updated)
        ├── claude-code.agentapi/    # agentapi v2.0.0
        └── gemini.agentapi/         # Not used (local module has own)
```

## ✨ Benefits

1. **Both AI tools available:** Claude Code + Gemini CLI/Web UI
2. **Auto-updates enabled:** `~> 4.2` keeps claude-code current
3. **No conflicts:** Only one coder_ai_task resource
4. **Future-proof:** When gemini v3.x releases with agentapi v2.0.0, easy migration

## 🔄 Migration Path

### When Gemini v3.x+ Uses AgentAPI v2.0.0

Simply update main.tf:

```terraform
module "gemini" {
  source  = "registry.coder.com/coder-labs/gemini/coder"
  version = "~> 3.0"  # ← Switch back to registry when available
  ...
}
```

Then remove local module:
```bash
rm -rf modules/gemini/
```

## 🧪 Testing

### Verify Configuration
```bash
terraform init -upgrade
terraform validate
terraform plan
```

### Expected Output
- ✅ No "only one coder_ai_task" errors
- ✅ Both claude-code and gemini modules enabled
- ✅ Latest claude-code version (4.2.0+)

### In Workspace
```bash
# Check both tools installed
claude --version
gemini --version

# Both web UIs available
# - Claude Code: via Coder Tasks UI
# - Gemini: via workspace apps (port 3284)
```

## 📚 Additional Notes

### Why Not Just Update Registry Gemini?

The registry gemini v2.1.1 is maintained by coder-labs and needs to be updated by them. Our local module is a temporary fix until official update.

### Alternative: Switch Primary Task UI to Gemini

If you prefer Gemini in the Tasks UI:

```terraform
resource "coder_ai_task" "main" {
  count = data.coder_workspace.me.start_count
  app_id = module.gemini[0].task_app_id  # ← Point to Gemini instead
}
```

Both tools remain functional regardless of which appears in Tasks UI.

## 🎯 Summary

**Problem:** Gemini v2.1.1 (registry) uses old agentapi v1.2.0 → conflict with Claude Code

**Solution:**
1. Created local gemini module with agentapi v2.0.0 upgrade
2. Added task_app_id output
3. Updated main.tf to use local module
4. Used ~> version constraints for auto-updates

**Result:** Both modules work perfectly together! 🎉

---

**Created:** 2025-01-XX
**Last Updated:** Auto-updating via ~> constraints
**Status:** ✅ Production Ready
