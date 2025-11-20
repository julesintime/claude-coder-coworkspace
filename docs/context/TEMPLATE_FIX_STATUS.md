# Template Fix Status Report

**Generated:** 2025-11-18
**Issue:** Claude Code not installing, MCP servers not configured in workspace

## ✅ Completed Changes

### 1. Fixed claude-code Module (main.tf:625-644)

**Problem:** Module only ran when authentication was present (`has_claude_auth` condition)

**Solution:** Changed module count to always run:
```hcl
# BEFORE (conditional):
count = local.has_claude_auth ? data.coder_workspace.me.start_count : 0

# AFTER (always runs):
count = data.coder_workspace.me.start_count
```

**Rationale:** Claude Code CLI works without authentication. Auth is optional for enhanced features.

### 2. Added MCP Server Configuration Script (main.tf:646-690)

**Created:** New `coder_script` resource named "configure_mcp_servers"

**Features:**
- Waits up to 60 seconds for Claude CLI to be installed by the module
- Configures three MCP servers:
  - **context7**: `--transport http` → https://mcp.context7.com/mcp
  - **sequential-thinking**: `npx -y @modelcontextprotocol/server-sequential-thinking`
  - **deepwiki**: `--transport http` → https://mcp.deepwiki.com/mcp
- Runs on workspace start
- Non-blocking (allows login during execution)
- 300-second timeout

### 3. Git Commits

**Commit:** c849f55 - "fix: claude-code module always runs, add MCP server configuration"
- Pushed to GitHub: ✅
- Branch: main

## ⚠️ BLOCKED - Coder Server Issues

### Server Status
- **Health Check:** 500 Internal Server Error
- **All Operations Blocked:**
  - ❌ `coder templates push` - fails with "unexpected non-JSON response"
  - ❌ `coder ssh` - fails with 500 error
  - ❌ `coder create/delete/list` - all blocked

### Error Details
```
error: API request error to "GET:https://coder.xuperson.org/api/v2/users/me/organizations"
Status code 500
Trace=[get organizations: ]
unexpected non-JSON response "text/plain; charset=UTF-8"
```

**Server:** https://coder.xuperson.org
**Healthz Endpoint:** Returns 500

## 📋 Remaining Tasks (Pending Server Recovery)

### 1. Push Updated Template
```bash
coder templates push unified-devops --yes
```

### 2. Rebuild/Restart Workspace
Option A - Rebuild with new template:
```bash
coder stop jxu002700/cccws
coder start jxu002700/cccws --build
```

Option B - Delete and recreate:
```bash
coder delete jxu002700/cccws --yes
coder create cccws --template unified-devops --yes
```

### 3. Verify Installations
```bash
# SSH into workspace
coder ssh cccws

# Check Claude Code
claude --version

# Check MCP servers
claude mcp list
# Expected output: context7, sequential-thinking, deepwiki

# Check for other tools
gemini --version  # May still be missing - needs additional work
codex --version   # Unknown tool, need clarification
```

## 🔍 Additional Work Needed

### Gemini CLI Installation
**Current Status:** Not found in workspace
**Options:**
1. Check Coder registry for Gemini module
2. Keep in startup script with proper installation logic
3. Use npm global install (simplest)

### Codex CLI
**Status:** Unknown tool
**Action:** Need to clarify what "codex" refers to:
- OpenAI Codex (deprecated)?
- GitHub Copilot CLI?
- Different tool?

### Startup Script Optimization
**Current Issue:** Script may have duplicate installations
**Action:** Remove Claude Code npm installation from startup script since module handles it

## 🎯 Next Steps (When Server Recovers)

1. **Wait for Coder server recovery** or contact administrator
2. **Push template** with `coder templates push unified-devops --yes`
3. **Restart workspace** to apply changes
4. **Test and verify:**
   - Claude Code installed and working
   - MCP servers configured correctly
   - Identify missing tools (gemini, codex)
5. **Iterate on startup script** to add missing tools via appropriate methods

## 📊 Success Criteria

- ✅ Claude Code module runs without authentication
- ✅ MCP configuration script added to template
- ⏳ Template pushed to Coder server (blocked)
- ⏳ Workspace rebuilt with new template (blocked)
- ⏳ `claude mcp list` shows all three servers (blocked)
- ⏳ All required CLI tools available (needs verification)

## 🐛 Known Issues

1. **Coder Server 500 Error** - Blocking all operations
2. **Gemini CLI Missing** - Not yet addressed
3. **Codex Tool Unknown** - Needs clarification
4. **Startup Script Performance** - May need optimization

## 📝 Notes

- Template changes are committed to Git (c849f55)
- Changes are ready to deploy when server recovers
- No data loss risk - all changes in version control
- Workspace can be deleted and recreated safely
