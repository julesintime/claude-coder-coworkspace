# CRITICAL BUG REPORT: Claude Code Not Installing

**Date**: November 18, 2025
**Template**: unified-devops
**Workspace**: cccws

---

## ROOT CAUSE IDENTIFIED ✅

The `setup_script` parameter value is **NOT being interpolated** into workspaces created with older template versions!

### Why Claude Code Wasn't Installing:

1. **The `setup_script` parameter was `mutable = false`**
   - When workspaces were created, this parameter value was locked
   - Updating the template didn't update existing workspaces
   - The `startup_script` received an EMPTY value instead of the full script

2. **The Claude Code MODULE didn't run**
   - Module only runs if `has_claude_auth = true` (line 655)
   - Requires either `CLAUDE_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
   - If no authentication provided → module doesn't install Claude Code

3. **Result**: NO Claude Code installation at all!

---

## FIXES APPLIED ✅

### 1. MCP Server Configuration Fixed
**File**: `main.tf` lines 373-383

**BEFORE** (wrong):
```bash
claude mcp add desktop-commander
```

**AFTER** (correct):
```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http deepwiki https://mcp.deepwiki.com/mcp
```

### 2. Made `setup_script` Temporarily Mutable
**File**: `main.tf` line 269

```hcl
mutable = true  # Temporarily mutable to allow workspace updates
```

This allows existing workspaces to receive the updated setup_script value.

### 3. Updated Documentation
- `README.md`: Removed desktop-commander references
- `IMPLEMENTATION_SUMMARY.md`: Updated MCP server list

---

## HOW TO FIX EXISTING WORKSPACES

### Option 1: Delete and Recreate (RECOMMENDED)

```bash
# 1. Delete the old workspace
coder delete jxu002700/cccws

# 2. Create a new workspace with the updated template
coder create cccws --template unified-devops

# 3. When prompted for parameters:
#    - Provide Claude API Key OR OAuth Token (REQUIRED for Claude Code module)
#    - Accept defaults for other parameters
```

###Option 2: Update Workspace (Requires manual parameter entry)

```bash
# 1. Update the workspace
coder update jxu002700/cccws --always-prompt

# 2. When prompted, provide:
#    - setup_script: Press ENTER to use default (huge script)
#    - Other parameters: Accept defaults or customize
```

**IMPORTANT**: Since `setup_script` is now mutable, you'll be prompted for it during update.

---

## VERIFICATION STEPS

After recreating/updating the workspace:

```bash
# 1. SSH into the workspace
coder ssh jxu002700/cccws

# 2. Verify setup script ran
cat /tmp/coder-startup-script.log | wc -l
# Should show > 100 lines

# 3. Check Claude Code installation
claude --version
# Should show: 2.0.44 (Claude Code) or similar

# 4. Verify MCP servers
claude mcp list
# Should show:
# - context7 (HTTP)
# - sequential-thinking (npx)
# - deepwiki (HTTP)

# 5. Verify Node.js/npm available
node --version
npm --version

# 6. Check Docker
docker --version
docker ps
```

---

## TECHNICAL DETAILS

### Terraform Parameter Issue

The `setup_script` parameter interpolation in `startup_script` was failing:

```hcl
# main.tf line 501-512
startup_script = <<-EOT
  set -e

  # Prepare user home
  if [ ! -f ~/.init_done ]; then
    cp -rT /etc/skel ~
    touch ~/.init_done
  fi

  # Run the setup script from the parameter
  ${data.coder_parameter.setup_script.value}  # ← THIS WAS EMPTY!
EOT
```

**Why it was empty:**
- Workspaces created before the parameter existed/was updated
- `mutable = false` prevented updates
- Terraform didn't re-evaluate the parameter value

### Agent Startup Log Evidence

```bash
$ cat /tmp/coder-startup-script.log
# Empty file (0 bytes)

$ coder logs | grep startup
2025-11-18 10:18:54.137 [info]  /tmp/coder-startup-script.log script completed
  execution_time=31.399ms  exit_code=0
```

The startup script completed in **31ms** - way too fast! It only ran the prep commands, not the full setup script.

---

## FILES MODIFIED

### Commits:
1. `4ee459d` - "fix: replace desktop-commander with correct MCP servers"
2. `2ea414b` - "temp: make setup_script mutable for workspace updates"

### Changed Files:
- `main.tf` - Fixed MCP servers (lines 373-383), made setup_script mutable (line 269)
- `README.md` - Removed desktop-commander references
- `IMPLEMENTATION_SUMMARY.md` - Updated MCP server documentation

---

## NEXT STEPS

1. ✅ Template fixes pushed to GitHub
2. ✅ Template updated in Coder (`unified-devops`)
3. ⚠️ **ACTION REQUIRED**: Delete and recreate `cccws` workspace
4. 🔄 After recreation, change `setup_script` back to `mutable = false` for production

---

## PREVENTION

To prevent this in the future:

1. **Always provide Claude authentication** when creating workspaces
   - Either: `CLAUDE_API_KEY`
   - Or: `CLAUDE_CODE_OAUTH_TOKEN`

2. **Test template changes** with NEW workspaces before updating production

3. **Document immutable parameters** - they can't be updated without recreation

4. **Use workspace tags/labels** to track template versions

---

## SUMMARY

**Problem**: Claude Code not installing in `cccws` workspace
**Cause**: Empty `setup_script` parameter + no Claude authentication
**Solution**: Delete workspace, recreate with proper configuration
**Status**: Template fixed, waiting for workspace recreation

**MCP Servers Now Configured**:
- ✅ context7 (via HTTP: https://mcp.context7.com/mcp)
- ✅ sequential-thinking (via npx)
- ✅ deepwiki (via HTTP: https://mcp.deepwiki.com/mcp)
- ❌ desktop-commander (REMOVED - not needed)
