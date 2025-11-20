# Unified DevOps Template - Refactoring Plan

## Executive Summary

This document provides a comprehensive refactoring plan for the unified-devops Coder template. The refactoring focuses on:

1. **Proper separation of concerns** between system setup (template) and user personalization (dotfiles/personalize)
2. **Simplification of coder_script resources** by moving UI tools to PM2 management in startup script
3. **Leveraging Coder's official modules** (personalize + dotfiles) for better maintainability
4. **Following community best practices** from Coder Registry and official documentation

---

## Current Architecture Analysis

### ✅ What's Working Well

1. **Module Pattern**: Gemini module demonstrates excellent modular design using agentapi v2.0.0
2. **Dotfiles Structure**: Well-organized dotfiles directory with:
   - `install.sh` - Main orchestrator
   - `scripts/` - Reusable helper scripts
   - `.bashrc.append` - Clean bash configuration
3. **Presets System**: Nano/Mini/Mega presets with override capabilities
4. **Authentication**: Centralized handling of GitHub, Gitea, Claude, Gemini tokens
5. **Docker-in-Docker**: Envbox integration with proper volume mounts

### ⚠️ Issues to Address

1. **Dotfiles Location**: Currently in template directory, should be separate user-controlled repository
2. **PM2 Management**: Three separate `coder_script` resources (install_pm2, claude_code_ui, vibe_kanban) can be consolidated
3. **Missing Personalize Module**: No mechanism for users to add workspace-specific customizations
4. **Git Configuration Duplication**: Both template and dotfiles handle git config
5. **Startup Script Bloat**: Many package installations could be moved or optimized

---

## Refactoring Strategy

### Phase 1: Dotfiles Reorganization

#### Current State
```
unified-devops/
├── main.tf
├── dotfiles/              # ❌ In template - should be user repo
│   ├── install.sh
│   ├── scripts/
│   ├── .bashrc.append
│   └── README.md
└── modules/
```

#### Target State
```
unified-devops/
├── main.tf
├── dotfiles-example/      # ✅ Example only, not used by template
│   └── README.md          # Points users to their own repo
└── modules/

user-coder-dotfiles/       # ✅ User's personal repository
├── install.sh
├── scripts/
│   ├── claude-helpers.sh
│   └── bash-aliases.sh
├── .bashrc.append
└── README.md
```

#### Implementation

**Step 1.1**: Create example dotfiles repository
- Move current `dotfiles/` content to `dotfiles-example/`
- Update README to guide users to fork/create their own
- Add repository template badge

**Step 1.2**: Update main.tf to use official dotfiles module
```hcl
# Use official Coder dotfiles module
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/coder/dotfiles"
  version  = "1.2.1"
  agent_id = coder_agent.main.id

  # Users configure via Coder UI: Account → Dotfiles
  # Or via template parameter (optional)
}
```

**Step 1.3**: Add personalize module for workspace-specific customization
```hcl
# Allow users to add workspace-specific customizations
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/coder/personalize"
  version  = "1.0.8"
  agent_id = coder_agent.main.id
}
```

---

### Phase 2: Simplify PM2 and UI Tools

#### Current State (3 separate coder_script resources)

```hcl
# main.tf:857 - Blocking script
resource "coder_script" "install_pm2" {
  start_blocks_login = true
  timeout = 300
  # ~35 lines of install logic with retries
}

# main.tf:908 - Non-blocking script
resource "coder_script" "claude_code_ui" {
  count = enable_claude_code_ui ? 1 : 0
  start_blocks_login = false
  timeout = 600
  # ~50 lines including npm install + PM2 start
}

# main.tf:968 - Non-blocking script
resource "coder_script" "vibe_kanban" {
  count = enable_vibe_kanban ? 1 : 0
  start_blocks_login = false
  timeout = 600
  # ~40 lines including PM2 start with npx
}
```

**Problems**:
- ❌ 125+ lines of script code in Terraform
- ❌ Three separate resources when they're tightly coupled
- ❌ Retry logic duplicated across scripts
- ❌ PM2 installation blocks login unnecessarily
- ❌ Difficult to debug script failures

#### Target State (Consolidated approach)

**Option A: Single Startup Script (Recommended)**
```hcl
resource "coder_agent" "main" {
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # ... existing package installations ...

    # ========================================
    # PM2 AND UI TOOLS (Non-blocking background)
    # ========================================

    (
      # Install PM2 if needed
      if ! command -v pm2 >/dev/null 2>&1; then
        echo "📦 Installing PM2..."
        sudo npm install -g pm2 --force || {
          echo "⚠️ PM2 install failed, UI tools will not be available"
          exit 0
        }
      fi

      # Claude Code UI (conditional)
      if [ "${data.coder_parameter.enable_claude_code_ui.value}" = "true" ]; then
        echo "🎨 Setting up Claude Code UI..."
        sudo npm install -g @siteboon/claude-code-ui --force || echo "⚠️ Claude Code UI install failed"
        mkdir -p ~/.claude-code-ui
        pm2 delete claude-code-ui 2>/dev/null || true
        PORT=${data.coder_parameter.claude_code_ui_port.value} \
        DATABASE_PATH=~/.claude-code-ui/database.json \
        pm2 start claude-code-ui --name claude-code-ui || echo "⚠️ Failed to start Claude Code UI"
      fi

      # Vibe Kanban (conditional)
      if [ "${data.coder_parameter.enable_vibe_kanban.value}" = "true" ]; then
        echo "📋 Setting up Vibe Kanban..."
        mkdir -p ~/.vibe-kanban
        pm2 delete vibe-kanban 2>/dev/null || true
        BACKEND_PORT=${data.coder_parameter.vibe_kanban_port.value} \
        HOST=0.0.0.0 \
        pm2 start "npx vibe-kanban" --name vibe-kanban || echo "⚠️ Failed to start Vibe Kanban"
      fi

      # Save PM2 process list
      pm2 save 2>/dev/null || true
      pm2 startup 2>/dev/null || true

      echo "✅ UI tools setup complete"
    ) > /tmp/ui-tools-setup.log 2>&1 &

    echo "✅ Workspace initialization complete!"
    echo "💡 UI tools are installing in the background. Check 'pm2 list' for status."
  EOT
}
```

**Benefits**:
- ✅ Single consolidated script
- ✅ Non-blocking - user can start working immediately
- ✅ Graceful failure - UI tools optional, won't break workspace
- ✅ Easier to debug - all UI setup in one place
- ✅ Background execution - faster perceived startup

**Option B: Dotfiles Integration (Alternative)**
Move PM2 and UI tools setup to dotfiles `install.sh`:
```bash
# In user's dotfiles repo: install.sh
#!/bin/bash

# ... existing dotfiles setup ...

# Optional: Install UI tools if PM2 available
if command -v pm2 >/dev/null 2>&1; then
  echo "🎨 Setting up optional UI tools..."
  # Same logic as Option A
fi
```

**Recommendation**: Use **Option A** (startup_script) because:
- UI tools are template-provided features, not user personalization
- Users shouldn't need to maintain this logic in their dotfiles
- Template controls versions and configuration

---

### Phase 3: Git Configuration Cleanup

#### Current Duplication

**In main.tf** (via personalize module):
```hcl
module "personalize" {
  # Automatically sets GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL from Coder user
}
```

**In dotfiles/install.sh** (lines 32-46):
```bash
# Configure Git with GitHub authenticated user (if available)
if command -v gh >/dev/null 2>&1 && [ -n "$GITHUB_TOKEN" ]; then
  GH_USER=$(gh api user --jq '.name // .login' 2>/dev/null || echo "")
  GH_EMAIL=$(gh api user --jq '.email // ""' 2>/dev/null || echo "")

  if [ -n "$GH_USER" ]; then
    git config --global user.name "$GH_USER"
  fi

  if [ -n "$GH_EMAIL" ]; then
    git config --global user.email "$GH_EMAIL"
  fi
fi
```

#### Resolution Strategy

**Decision Tree**:
```
Does user have GitHub external auth configured?
├─ YES → Use personalize module (Coder user data)
└─ NO  → Use dotfiles fallback (GitHub API)

Priority Order:
1. Coder user profile (personalize module)
2. GitHub API (dotfiles fallback)
3. Manual git config by user
```

**Implementation**:
```bash
# In dotfiles/install.sh
# Only set git config if not already configured by personalize module
if [ -z "$(git config --global user.name)" ]; then
  echo "⚙️ Git not configured by template, trying GitHub fallback..."
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    GH_USER=$(gh api user --jq '.name // .login' 2>/dev/null)
    GH_EMAIL=$(gh api user --jq '.email // ""' 2>/dev/null)

    [ -n "$GH_USER" ] && git config --global user.name "$GH_USER"
    [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ] && git config --global user.email "$GH_EMAIL"

    echo "✓ Git configured from GitHub profile"
  fi
else
  echo "✓ Git already configured by template"
fi
```

---

### Phase 4: Startup Script Optimization

#### Current Issues

The `coder_agent.main.startup_script` (lines 568-645) currently:
- Runs 600ms `apt-get update` multiple times (lines 600, 613, 623)
- Installs packages sequentially (kubectl, gh, tea, typescript)
- Some packages may not be needed immediately

#### Optimization Strategy

**Categorize packages by importance**:

1. **Critical (Keep in startup_script)**:
   - tmux (needed for claude session management)
   - git (core development)

2. **Important but not blocking (Move to background)**:
   - kubectl (Kubernetes CLI)
   - gh (GitHub CLI)
   - tea (Gitea CLI)
   - typescript (TypeScript compiler)

3. **User-specific (Move to dotfiles/personalize)**:
   - Additional language runtimes
   - Personal development tools

**Refactored Approach**:

```hcl
startup_script = <<-EOT
  set -e

  # ========================================
  # INITIAL SETUP (Fast)
  # ========================================

  if [ ! -f ~/.init_done ]; then
    cp -rT /etc/skel ~
    touch ~/.init_done
  fi

  # Fix sudo hostname
  CURRENT_HOSTNAME=$(hostname)
  if ! grep -q "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 $CURRENT_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
  fi

  # Create directories
  mkdir -p ~/projects ~/.claude/resume-logs ~/scripts

  # ========================================
  # CRITICAL PACKAGES ONLY (Blocking)
  # ========================================

  echo "📦 Installing critical packages..."
  sudo apt-get update -qq
  sudo apt-get install -y --fix-missing tmux git curl || true

  echo "✅ Critical setup complete - workspace ready!"

  # ========================================
  # OPTIONAL TOOLS (Non-blocking background)
  # ========================================

  (
    echo "📦 Installing additional tools in background..."

    # Install kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
        sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
        sudo tee /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update -qq
      sudo apt-get install -y kubectl
    fi

    # Install GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y gh
    fi

    # Install Gitea CLI
    if ! command -v tea >/dev/null 2>&1; then
      wget -qO /tmp/tea https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64
      sudo install -m 755 /tmp/tea /usr/local/bin/tea
      rm /tmp/tea
    fi

    # TypeScript (if npm available)
    if command -v npm >/dev/null 2>&1 && ! command -v tsc >/dev/null 2>&1; then
      sudo npm install -g typescript 2>/dev/null || true
    fi

    # PM2 and UI tools (from Phase 2)
    # ... (see Option A above)

    echo "✅ Background installations complete"
  ) > /tmp/background-setup.log 2>&1 &

  echo "💡 Additional tools installing in background"
  echo "💡 Check progress: tail -f /tmp/background-setup.log"
EOT
```

**Benefits**:
- ✅ Faster initial login (10-15 seconds vs 60+ seconds)
- ✅ User can start working immediately
- ✅ Single apt-get update for critical packages
- ✅ All optional tools install in background
- ✅ Better error isolation

---

## Detailed Migration Plan

### Step-by-Step Implementation

#### Step 1: Prepare Dotfiles Repository (Week 1)

**1.1**: Create example dotfiles repository structure
```bash
cd unified-devops/
mv dotfiles dotfiles-example
cd dotfiles-example
```

**1.2**: Update README with fork instructions
- Add "Fork this repository" button
- Document how to configure in Coder UI
- Add troubleshooting section

**1.3**: Create template repository on GitHub
- `coder/unified-devops-dotfiles-template` (example)
- Users can generate new repo from template

**1.4**: Test dotfiles module integration
```hcl
# Add to main.tf for testing
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/coder/dotfiles"
  version  = "1.2.1"
  agent_id = coder_agent.main.id
}
```

#### Step 2: Add Personalize Module (Week 1)

**2.1**: Add personalize module to main.tf
```hcl
module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/coder/personalize"
  version  = "1.0.8"
  agent_id = coder_agent.main.id
}
```

**2.2**: Update documentation
- Explain ~/personalize script usage
- Provide examples of workspace-specific customizations
- Document execution order: template → dotfiles → personalize

**2.3**: Test personalize functionality
```bash
# Users can create ~/personalize script:
#!/bin/bash
echo "Custom workspace setup"
npm install -g my-favorite-tool
git clone git@github.com:user/project ~/projects/myproject
```

#### Step 3: Refactor PM2 and UI Tools (Week 2)

**3.1**: Extract UI tools logic from coder_script to shell script
```bash
cd unified-devops/
mkdir -p scripts/
cat > scripts/setup-ui-tools.sh <<'EOF'
#!/bin/bash
# Setup PM2-managed UI tools
# This script runs in the background during workspace startup

set -e

# ... (logic from Option A above)
EOF
chmod +x scripts/setup-ui-tools.sh
```

**3.2**: Update startup_script to call background script
```hcl
startup_script = <<-EOT
  # ... existing setup ...

  # Start UI tools in background
  bash ~/scripts/setup-ui-tools.sh > /tmp/ui-tools-setup.log 2>&1 &
EOT
```

**3.3**: Remove coder_script resources
```hcl
# Delete these resources:
# - resource "coder_script" "install_pm2"
# - resource "coder_script" "claude_code_ui"
# - resource "coder_script" "vibe_kanban"
```

**3.4**: Test UI tools functionality
- Create test workspace
- Verify PM2 installs correctly
- Check Claude Code UI and Vibe Kanban start
- Verify coder_app healthchecks work

#### Step 4: Optimize Startup Script (Week 2)

**4.1**: Refactor package installations
- Identify critical vs optional packages
- Move optional packages to background script

**4.2**: Create background installation script
```bash
cat > scripts/setup-optional-tools.sh <<'EOF'
#!/bin/bash
# Install optional development tools in background
# This runs after workspace is ready for user access

set -e

echo "📦 Installing optional tools..."

# kubectl, gh, tea, typescript installations
# ... (from Phase 4 above)
EOF
```

**4.3**: Update startup_script
```hcl
startup_script = <<-EOT
  # Critical setup only (fast)
  sudo apt-get update -qq
  sudo apt-get install -y tmux git curl

  # Background installations
  bash ~/scripts/setup-optional-tools.sh > /tmp/optional-tools.log 2>&1 &
  bash ~/scripts/setup-ui-tools.sh > /tmp/ui-tools.log 2>&1 &

  echo "✅ Workspace ready! Optional tools installing in background."
EOT
```

**4.4**: Add status indicator
```hcl
# Add metadata to show background installation status
metadata {
  display_name = "Background Setup"
  key          = "background_setup"
  script       = <<-EOT
    if pgrep -f "setup-optional-tools.sh" >/dev/null 2>&1; then
      echo "⏳ Installing..."
    elif [ -f /tmp/optional-tools.log ]; then
      echo "✅ Complete"
    else
      echo "⚠️ Not started"
    fi
  EOT
  interval = 30
  timeout  = 5
}
```

#### Step 5: Update Git Configuration (Week 3)

**5.1**: Update dotfiles install.sh to check for existing config
```bash
# Add to dotfiles-example/install.sh
if [ -z "$(git config --global user.name)" ]; then
  # Only configure if personalize module didn't already
  # ... GitHub API fallback logic
fi
```

**5.2**: Document git config precedence
- Update CLAUDE.md with configuration order
- Add troubleshooting for git config issues

#### Step 6: Testing and Validation (Week 3)

**6.1**: Test workspace creation
```bash
# Test new workspace with all features
coder templates push unified-devops
coder create test-workspace --template unified-devops
```

**6.2**: Validate functionality checklist
- [ ] Workspace starts successfully
- [ ] User can login immediately (< 20 seconds)
- [ ] Background installations complete without errors
- [ ] PM2 and UI tools start correctly
- [ ] Git config is set correctly
- [ ] Dotfiles module works (test with example repo)
- [ ] Personalize module allows custom scripts
- [ ] All coder_app healthchecks pass
- [ ] Claude Code integration works
- [ ] Gemini module functions correctly

**6.3**: Performance benchmarks
- Measure startup time: before vs after
- Document improvement metrics
- Create performance report

#### Step 7: Documentation (Week 4)

**7.1**: Update main README.md
- New dotfiles workflow
- Personalize module usage
- Background installation behavior
- Troubleshooting guide

**7.2**: Create migration guide for existing users
- How to migrate dotfiles to personal repo
- Breaking changes (if any)
- Upgrade instructions

**7.3**: Update CLAUDE.md
- New architecture explanation
- Updated tool selection guide
- Performance improvements

---

## Architecture Diagram (After Refactoring)

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER 1: Base Image (codercom/enterprise-node:ubuntu)      │
│ - OS packages, Node.js, Docker runtime                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 2: Template (main.tf) - Admin Controlled             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ startup_script (blocking - critical only)               │ │
│ │ - tmux, git, curl                                       │ │
│ │ - Directory creation                                     │ │
│ │ - Hostname fix                                          │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ startup_script (background - optional)                  │ │
│ │ - kubectl, gh, tea                                      │ │
│ │ - PM2 + UI tools (claude-code-ui, vibe-kanban)         │ │
│ │ - TypeScript, additional tools                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Modules                                                  │ │
│ │ - claude-code (with MCP servers)                        │ │
│ │ - gemini (via agentapi v2)                             │ │
│ │ - personalize (user customization)                      │ │
│ │ - dotfiles (user preferences)                          │ │
│ │ - code-server, cursor, windsurf (IDEs)                 │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 3: User Dotfiles Repository (user-controlled)        │
│ - Shell configurations (.bashrc, .zshrc)                    │
│ - Git configuration fallback                                │
│ - Helper scripts (claude-helpers.sh, bash-aliases.sh)      │
│ - IDE settings and extensions                               │
│ - SSH keys and personal configs                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 4: Personalize Script (~/personalize)                │
│ - Workspace-specific tool installations                     │
│ - Project cloning and setup                                 │
│ - Custom environment variables                              │
│ - One-time workspace initialization                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Benefits Summary

### Performance Improvements
- **Startup Time**: 60+ seconds → 15-20 seconds (70% reduction)
- **Time to Interactive**: Immediate after login vs waiting for PM2
- **Background Processing**: UI tools and optional packages install without blocking

### Maintainability
- **Less Terraform Code**: ~125 lines of coder_script → ~30 lines in startup_script
- **Easier Debugging**: Centralized logs in /tmp vs scattered across resources
- **Better Separation**: Template (system) vs Dotfiles (user) clearly defined
- **Module Reuse**: Leveraging official Coder modules (personalize, dotfiles)

### User Experience
- **Immediate Access**: Users can start coding while tools install
- **Customization**: Users control their own dotfiles repository
- **Flexibility**: ~/personalize script for workspace-specific setup
- **Transparency**: Clear logs showing background installation progress

### Best Practices Compliance
- ✅ Follows Coder official module patterns
- ✅ Matches GitHub Codespaces dotfiles behavior
- ✅ Clear separation of concerns (template vs user)
- ✅ Non-blocking optional features
- ✅ Graceful degradation (UI tools optional)

---

## Risk Assessment

### Low Risk
- ✅ Dotfiles module is official and well-tested
- ✅ Personalize module is official and stable
- ✅ Background script approach is standard practice
- ✅ Git config fallback maintains compatibility

### Medium Risk
- ⚠️ Users need to migrate dotfiles to personal repo (one-time effort)
- ⚠️ Background installations might fail silently (mitigation: logs + status metadata)
- ⚠️ PM2 startup might have race conditions (mitigation: proper error handling)

### Mitigation Strategies
1. **Dotfiles Migration**: Provide clear guide and example repository
2. **Background Failures**: Add metadata to show installation status
3. **PM2 Issues**: Use PM2 startup scripts + ecosystem config for reliability
4. **Rollback Plan**: Keep old template version tagged for emergency rollback

---

## Testing Strategy

### Unit Tests (Template Components)
```bash
# Test startup script independently
bash -c "$(terraform output startup_script)"

# Test background scripts
bash scripts/setup-ui-tools.sh
bash scripts/setup-optional-tools.sh

# Verify PM2 management
pm2 list
pm2 logs claude-code-ui --lines 50
```

### Integration Tests (Full Workspace)
```bash
# Create workspace and measure timing
time coder create test-refactored --template unified-devops

# Validate all services start
coder ssh test-refactored -- "pm2 list"
coder ssh test-refactored -- "kubectl version --client"
coder ssh test-refactored -- "claude --version"

# Check background installations
coder ssh test-refactored -- "tail /tmp/ui-tools-setup.log"
coder ssh test-refactored -- "tail /tmp/optional-tools.log"
```

### User Acceptance Tests
1. Create workspace with dotfiles configured
2. Verify personalize script executes
3. Test all AI tools (Claude, Gemini)
4. Validate UI tools (Claude Code UI, Vibe Kanban)
5. Confirm git config is correct
6. Check Docker-in-Docker functionality

---

## Rollout Plan

### Phase 1: Development (Week 1-2)
- Implement refactoring in feature branch
- Test with development workspaces
- Gather feedback from early adopters

### Phase 2: Staging (Week 3)
- Deploy to staging environment
- Run full integration test suite
- Document any issues and fixes

### Phase 3: Production (Week 4)
- Create migration guide for existing users
- Deploy to production template registry
- Announce changes in release notes
- Monitor for issues

### Phase 4: Cleanup (Week 5)
- Archive old template version
- Update all documentation
- Close related issues/tickets

---

## Success Metrics

### Quantitative
- Workspace startup time < 20 seconds
- Background installation success rate > 95%
- User login time < 15 seconds
- PM2 service uptime > 99%

### Qualitative
- Users can customize via dotfiles easily
- Template code is more maintainable
- Debugging is faster with centralized logs
- New features easier to add

---

## References

### Official Documentation
- [Coder Dotfiles Guide](https://coder.com/docs/user-guides/workspace-dotfiles)
- [Personalize Module](https://registry.coder.com/modules/coder/personalize)
- [Dotfiles Module](https://registry.coder.com/modules/coder/dotfiles)
- [AgentAPI Module v2](https://registry.coder.com/modules/coder/agentapi)
- [Resource Ordering](https://coder.com/docs/admin/templates/extending-templates/resource-ordering)

### Community Examples
- [Kubernetes Pod Template](https://github.com/coder/coder/tree/main/examples/templates/kubernetes)
- [Docker in Docker Template](https://github.com/coder/coder/tree/main/examples/templates/docker-in-docker)
- [Module Best Practices](https://registry.coder.com/modules)

---

## Appendix A: File Changes Summary

### Files to Create
- `scripts/setup-ui-tools.sh` - PM2 and UI tools installation
- `scripts/setup-optional-tools.sh` - Background tool installations
- `dotfiles-example/README.md` - User guide for dotfiles
- `MIGRATION_GUIDE.md` - Guide for existing users

### Files to Modify
- `main.tf` - Add personalize/dotfiles modules, refactor startup_script
- `CLAUDE.md` - Update architecture documentation
- `README.md` - Update usage instructions

### Files to Remove
- None (dotfiles → dotfiles-example, still available for reference)

### Resources to Remove from main.tf
- `resource "coder_script" "install_pm2"`
- `resource "coder_script" "claude_code_ui"`
- `resource "coder_script" "vibe_kanban"`

### Resources to Add to main.tf
- `module "personalize"`
- `module "dotfiles"`
- New metadata block for background installation status

---

## Appendix B: Comparison Table

| Aspect | Current | After Refactoring |
|--------|---------|-------------------|
| **Startup time** | 60+ seconds | 15-20 seconds |
| **Login blocking** | Yes (PM2 install) | No |
| **Lines of script in TF** | ~200 lines | ~60 lines |
| **Dotfiles location** | In template | User's repo |
| **Personalization** | Manual | ~/personalize script |
| **Git config** | Duplicated | Single source |
| **Background installs** | No | Yes |
| **Error isolation** | Mixed | Separated |
| **Debuggability** | Difficult | Easy (logs) |
| **Module compliance** | Partial | Full |

---

## Appendix C: Example User Workflows

### Workflow 1: New User (First Workspace)

1. User creates Coder account
2. Admin provisions unified-devops template
3. User creates workspace → Gets defaults
4. User forks dotfiles-example repository
5. User configures dotfiles URL in Coder settings
6. User creates new workspace → Gets personalized environment
7. User creates ~/personalize script for workspace-specific tools

### Workflow 2: Existing User (Migration)

1. User has workspace with current template
2. Admin updates template to refactored version
3. User receives migration notice
4. User forks current dotfiles directory to personal repo
5. User configures dotfiles URL in Coder
6. User creates new workspace with refactored template
7. User's dotfiles automatically applied
8. User validates everything works

### Workflow 3: Power User (Advanced Customization)

1. User forks dotfiles-example
2. User adds custom helper functions
3. User adds IDE extensions and configs
4. User creates ~/personalize script:
   ```bash
   #!/bin/bash
   # Clone my projects
   gh repo clone user/project1 ~/projects/project1
   gh repo clone user/project2 ~/projects/project2

   # Install project-specific tools
   cd ~/projects/project1
   npm install

   # Set up environment
   cp .env.example .env.local
   ```
5. User creates workspace → Fully customized environment ready

---

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Prioritize phases** based on urgency and resources
3. **Create issues/tickets** for each implementation step
4. **Assign ownership** for different refactoring tasks
5. **Set timeline** for completion
6. **Schedule testing** windows
7. **Plan communication** to users about changes

---

**Document Version**: 1.0
**Last Updated**: 2025-11-20
**Status**: Ready for Review
