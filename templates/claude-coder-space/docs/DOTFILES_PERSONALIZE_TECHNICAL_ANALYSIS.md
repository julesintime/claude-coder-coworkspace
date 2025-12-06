# Dotfiles + Personalize Module - Technical Analysis

## Critical Findings from Source Code

### How Dotfiles Module Actually Works

#### Source Code Analysis (`dotfiles/main.tf`)

```terraform
# Lines 42-53: Creates a USER PROMPT during workspace creation
data "coder_parameter" "dotfiles_uri" {
  count = var.dotfiles_uri == null ? 1 : 0

  type         = "string"
  name         = "dotfiles_uri"
  display_name = "Dotfiles URL (optional)"
  default      = var.default_dotfiles_uri  # ← This is our default!
  description  = "Enter a URL for a dotfiles repository to personalize your workspace"
  mutable      = true
}

# Line 56: Priority logic
locals {
  dotfiles_uri = var.dotfiles_uri != null ? var.dotfiles_uri : data.coder_parameter.dotfiles_uri[0].value
}

# Lines 60-69: Runs as coder_script
resource "coder_script" "dotfiles" {
  agent_id     = var.agent_id
  script       = templatefile("${path.module}/run.sh", {...})
  display_name = "Dotfiles"
  run_on_start = true  # Runs on every workspace start
}
```

#### What `run.sh` Does

```bash
# Line 13: Uses Coder CLI command
coder dotfiles "$DOTFILES_URI" -y 2>&1 | tee ~/.dotfiles.log
```

**Key Points:**
1. **User is prompted** during workspace creation (NOT in account settings)
2. **Default value** from `default_dotfiles_uri` is pre-filled in the prompt
3. **Runs `coder dotfiles` CLI command** to clone and apply dotfiles
4. **Priority**: hardcoded URI > user input > default_dotfiles_uri

---

### How Personalize Module Works

#### Source Code Analysis (`personalize/main.tf`)

```terraform
# Lines 29-39: Blocks login until script completes!
resource "coder_script" "personalize" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", {...})
  display_name       = "Personalize"
  run_on_start       = true
  start_blocks_login = true  # ← BLOCKS LOGIN!
}
```

#### What `run.sh` Does

```bash
# Lines 11-16: If ~/personalize doesn't exist, educate user
if [ ! -f $SCRIPT ]; then
  printf "✨ You don't have a personalize script!\n"
  printf "Run touch $SCRIPT && chmod +x $SCRIPT to create one.\n"
  exit 0  # Exit gracefully
fi

# Lines 20-24: Check if executable
if [ ! -x $SCRIPT ]; then
  echo "🔐 Your personalize script isn't executable!"
  exit 0
fi

# Line 27: Run the script
$SCRIPT
```

**Key Points:**
1. **Blocks login** by default (`start_blocks_login = true`)
2. **Gracefully exits** if ~/personalize doesn't exist (doesn't fail workspace)
3. **Educates user** on how to create the script
4. **User creates** `~/personalize` manually in their workspace

---

## ⚠️ CRITICAL ISSUE: Parallel Execution

### The Problem

**Both `coder_script` resources run IN PARALLEL, not sequentially!**

From Coder documentation:
> Multiple coder_script resources execute in parallel by default

**Our Current Configuration:**
```terraform
module "personalize" {
  count = data.coder_workspace.me.start_count
  # Creates coder_script.personalize
  # start_blocks_login = true
}

module "dotfiles" {
  count = data.coder_workspace.me.start_count
  # Creates coder_script.dotfiles
  # start_blocks_login = false (default)
}
```

**Execution Timeline:**
```
Workspace Start
    ├─ startup_script runs (sequential steps)
    ├─ coder_script.personalize runs (BLOCKS login)
    └─ coder_script.dotfiles runs (parallel)
         └─ Both race to completion!
```

**Race Condition:**
- If dotfiles takes longer than personalize, dotfiles may still be running after user logs in
- If personalize needs dotfiles to complete first, it may fail
- No guaranteed execution order

---

## Execution Order Analysis

### Current Reality

```
┌────────────────────────────────────────────────────┐
│ Stage 1: Agent Startup (Sequential)                │
│ ├─ coder_agent.main.startup_script                 │
│ │  ├─ Install system packages (apt-get)            │
│ │  ├─ Install kubectl, gh, tea                     │
│ │  └─ PM2 + UI tools (background) ←─ NEW!         │
│ └─ Completes in ~30-45 seconds                     │
└────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────┐
│ Stage 2: Coder Scripts (PARALLEL)                  │
│ ├─ coder_script.personalize (BLOCKS login)         │
│ │  └─ Runs ~/personalize if exists                 │
│ └─ coder_script.dotfiles (non-blocking)            │
│    └─ Runs coder dotfiles <url>                    │
│                                                     │
│ ⚠️ These run at THE SAME TIME!                     │
└────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────┐
│ User Login                                         │
│ - Blocked until personalize completes              │
│ - Dotfiles may still be running                    │
└────────────────────────────────────────────────────┘
```

### What Coder Documentation Says

**From `workspace-dotfiles` docs:**
> Templates can prompt users for their dotfiles repo URL during workspace creation

**From `personalize` docs:**
> The personalize script executes every time the workspace rebuilds

**Execution Order:**
1. ✅ `startup_script` runs first (always)
2. ⚠️ `coder_script` resources run in PARALLEL (not sequential)
3. ❌ No guaranteed order between personalize and dotfiles

---

## Current Template Analysis

### What We Have Now

```terraform
# main.tf:564-698
resource "coder_agent" "main" {
  startup_script = <<-EOT
    # ... package installations ...

    # PM2 + UI tools (background process) ←─ OUR REFACTORING
    (
      # Install PM2
      # Install Claude Code UI
      # Install Vibe Kanban
    ) > /tmp/ui-tools-setup.log 2>&1 &
  EOT
}

# main.tf:1042-1047
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
  version  = "1.0.8"
  agent_id = coder_agent.main.id
  # Internally: start_blocks_login = true
}

# main.tf:1052-1058
module "dotfiles" {
  count                = data.coder_workspace.me.start_count
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "1.0.14"
  agent_id             = coder_agent.main.id
  default_dotfiles_uri = "https://github.com/julesintime/coder-dotfiles.git"
  # Internally: start_blocks_login = false (default)
}
```

### Issues with Current Setup

1. **Personalize blocks login unnecessarily**
   - Most users won't have ~/personalize script
   - Blocks workspace access waiting for nothing
   - Poor UX

2. **Dotfiles runs in parallel with personalize**
   - No guaranteed execution order
   - Race conditions possible

3. **User prompted for dotfiles URL on EVERY workspace creation**
   - Even though we set `default_dotfiles_uri`
   - Parameter is mutable, so it prompts again
   - Annoying UX

4. **PM2 background installation may not finish before dotfiles**
   - Dotfiles scripts might depend on PM2 being installed
   - Could cause failures in helper scripts

---

## Proposed Simplification

### Option 1: Remove Both Modules, Consolidate in startup_script

**Rationale:**
- Avoid parallel execution issues
- Guarantee execution order
- Simplify template (no module dependencies)
- Full control over blocking behavior

**Implementation:**

```terraform
resource "coder_agent" "main" {
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # ========================================
    # STAGE 1: Critical System Setup (Blocking)
    # ========================================

    echo "📦 Installing critical packages..."
    sudo apt-get update -qq
    sudo apt-get install -y tmux git curl

    mkdir -p ~/projects ~/.claude/resume-logs ~/scripts

    # ========================================
    # STAGE 2: Dotfiles (Blocking)
    # ========================================

    DOTFILES_URI="https://github.com/julesintime/coder-dotfiles.git"

    echo "✨ Applying dotfiles from $DOTFILES_URI"
    coder dotfiles "$DOTFILES_URI" -y 2>&1 | tee ~/.dotfiles.log || {
      echo "⚠️ Dotfiles failed, continuing anyway..."
    }

    # ========================================
    # STAGE 3: Optional Tools (Non-blocking Background)
    # ========================================

    (
      echo "📦 Installing optional tools..."

      # kubectl, gh, tea
      # ... (existing code)

      # PM2 + UI tools
      # ... (existing code)

      echo "✅ Background installations complete"
    ) > /tmp/background-setup.log 2>&1 &

    # ========================================
    # STAGE 4: Personalize Script (Non-blocking)
    # ========================================

    # Check if user has personalize script
    if [ -f ~/personalize ] && [ -x ~/personalize ]; then
      echo "🎨 Running personalize script..."
      ~/personalize 2>&1 | tee ~/personalize.log &
    else
      echo "💡 Tip: Create ~/personalize script for workspace customization"
    fi

    echo "🚀 Workspace ready! Background tools installing..."
  EOT
}
```

**Benefits:**
- ✅ Guaranteed execution order
- ✅ Dotfiles complete before user access
- ✅ Personalize doesn't block (runs in background)
- ✅ No module dependencies
- ✅ Easier to debug (single script)
- ✅ No user prompts (uses hardcoded dotfiles URL)

**Drawbacks:**
- ❌ Users can't easily override dotfiles URL
- ❌ More code in startup_script
- ❌ Not following "module best practices"

---

### Option 2: Keep Modules, Fix Execution Order

**Rationale:**
- Follow Coder module patterns
- Allow users to override dotfiles
- Modular architecture

**Implementation:**

```terraform
# Fix 1: Make personalize non-blocking
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/personalize/coder"
  version  = "1.0.8"
  agent_id = coder_agent.main.id

  # Can't change start_blocks_login in module!
  # PROBLEM: Module hardcodes start_blocks_login = true
}

# Fix 2: Force dotfiles URI to avoid prompting
module "dotfiles" {
  count        = data.coder_workspace.me.start_count
  source       = "registry.coder.com/coder/dotfiles/coder"
  version      = "1.0.14"
  agent_id     = coder_agent.main.id
  dotfiles_uri = "https://github.com/julesintime/coder-dotfiles.git"

  # Setting dotfiles_uri (not default_dotfiles_uri) DISABLES the prompt!
  # Users can't override anymore
}
```

**Issues:**
- ⚠️ Can't change personalize blocking behavior (module limitation)
- ⚠️ Setting `dotfiles_uri` removes user override capability
- ⚠️ Still no guaranteed execution order (parallel)

**Alternative: Use depends_on (Doesn't Work!)**

```terraform
# DOESN'T WORK: coder_script doesn't support depends_on
module "personalize" {
  # ...
  depends_on = [module.dotfiles]  # ❌ No effect on coder_script timing
}
```

---

### Option 3: Hybrid Approach (RECOMMENDED)

**Rationale:**
- Keep dotfiles module for user override capability
- Integrate personalize into startup_script for control
- Best of both worlds

**Implementation:**

```terraform
resource "coder_agent" "main" {
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Stage 1: Critical setup (blocking)
    echo "📦 Critical setup..."
    sudo apt-get update -qq
    sudo apt-get install -y tmux git curl
    mkdir -p ~/projects ~/scripts

    # Stage 2: Background installations (non-blocking)
    (
      # kubectl, gh, tea
      # PM2 + UI tools

      # Personalize script (if exists)
      if [ -f ~/personalize ] && [ -x ~/personalize ]; then
        echo "🎨 Running personalize script..."
        ~/personalize 2>&1 | tee ~/personalize.log
      else
        echo "💡 Tip: Create ~/personalize for customization"
        echo "Run: touch ~/personalize && chmod +x ~/personalize"
      fi

      echo "✅ Background setup complete"
    ) > /tmp/background-setup.log 2>&1 &

    echo "🚀 Workspace ready!"
  EOT
}

# Keep dotfiles module for user override
module "dotfiles" {
  count                = data.coder_workspace.me.start_count
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "1.0.14"
  agent_id             = coder_agent.main.id
  default_dotfiles_uri = "https://github.com/julesintime/coder-dotfiles.git"
  # User CAN override via parameter prompt
}

# REMOVE personalize module (handled in startup_script)
```

**Benefits:**
- ✅ Dotfiles runs first (as coder_script)
- ✅ Personalize runs in background (no blocking)
- ✅ Users can override dotfiles URL (via prompt)
- ✅ Guaranteed execution order (dotfiles → background personalize)
- ✅ Simpler than having both modules
- ✅ Better UX (no unnecessary blocking)

**Execution Flow:**
```
Workspace Start
    ├─ startup_script (critical setup) [10s]
    ├─ coder_script.dotfiles [20s, non-blocking]
    ├─ startup_script background process starts
    │  ├─ Optional tools installation
    │  └─ Personalize script (if exists)
    └─ User can login immediately after dotfiles completes
```

---

## Comparison Matrix

| Aspect | Current | Option 1 (No Modules) | Option 2 (Fix Modules) | Option 3 (Hybrid) |
|--------|---------|----------------------|----------------------|-------------------|
| **Execution Order** | ❌ Parallel | ✅ Sequential | ❌ Parallel | ✅ Sequential |
| **User Login Time** | ⚠️ Blocked | ⚠️ Blocked | ⚠️ Blocked | ✅ Fast (dotfiles only) |
| **User Override** | ✅ Yes | ❌ No | ⚠️ Complex | ✅ Yes |
| **Code Simplicity** | ⚠️ Medium | ✅ Simple | ❌ Complex | ✅ Simple |
| **Module Pattern** | ✅ Yes | ❌ No | ✅ Yes | ⚠️ Partial |
| **Personalize Blocking** | ❌ Blocks | ✅ Non-blocking | ❌ Blocks | ✅ Non-blocking |
| **Debugging** | ⚠️ Hard | ✅ Easy | ❌ Hard | ✅ Easy |

---

## Recommendation

**Use Option 3 (Hybrid Approach)**

### Why?

1. **Best UX**: Dotfiles complete before login, personalize doesn't block
2. **User Control**: Users can still override dotfiles URL
3. **Guaranteed Order**: Dotfiles → Background installations → Personalize
4. **Simplicity**: Remove personalize module, keep dotfiles module
5. **Maintainability**: Clear execution flow, easy to debug

### Implementation Steps

1. ✅ Keep dotfiles module with `default_dotfiles_uri`
2. ✅ Remove personalize module from main.tf
3. ✅ Add personalize logic to startup_script background process
4. ✅ Update documentation

---

## User Documentation

### For Template Users

**Dotfiles:**
1. When creating a workspace, you'll be prompted: "Dotfiles URL (optional)"
2. Default: `https://github.com/julesintime/coder-dotfiles.git` (pre-filled)
3. Override: Enter your own dotfiles repository URL
4. Skip: Leave blank to skip dotfiles

**Personalize:**
1. Create a script: `touch ~/personalize && chmod +x ~/personalize`
2. Add custom commands: `echo 'npm install -g my-tool' >> ~/personalize`
3. Runs automatically: On every workspace restart (in background)
4. View logs: `tail -f ~/personalize.log`

### For Template Admins

**Update dotfiles repo:**
```bash
# The dotfiles directory is a separate git repo
cd unified-devops/dotfiles
git add .
git commit -m "Update dotfiles"
git push origin main
```

**Update template:**
```bash
# Only push template changes
cd unified-devops
coder templates push unified-devops --directory .
```

---

## Next Steps

1. **Review** this analysis with stakeholders
2. **Choose** implementation option (recommend Option 3)
3. **Implement** chosen option
4. **Test** with real workspace creation
5. **Update** documentation
6. **Rollout** to users

---

**Document Version**: 1.0
**Date**: 2025-11-20
**Status**: Ready for Implementation
