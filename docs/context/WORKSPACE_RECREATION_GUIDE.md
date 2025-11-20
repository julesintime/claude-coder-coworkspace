# Workspace Recreation Guide - cccws

## ✅ ALL FIXES COMPLETED

### Fixes Applied to Template:

1. **✅ MCP Servers Fixed** (Commit: 4ee459d, 2430281)
   - Removed: desktop-commander
   - Added: context7 (HTTP), sequential-thinking (npx), deepwiki (HTTP)
   - Lines 377-379 in main.tf now correctly configure MCP servers

2. **✅ Template Pushed to Coder**
   - Latest version: Nov 18 11:01:24
   - Template name: `unified-devops`
   - Status: Active

3. **✅ Documentation Updated**
   - README.md - Removed desktop-commander references
   - IMPLEMENTATION_SUMMARY.md - Updated MCP list
   - CRITICAL_BUG_REPORT.md - Full analysis created

### Root Cause Summary:

**Problem**: Claude Code wasn't installing because:
1. `setup_script` parameter was empty in old workspaces (immutable parameter locked)
2. Claude Code module requires authentication (API key or OAuth token)
3. MCP servers were misconfigured (desktop-commander instead of correct ones)

**Solution**: Delete workspace and recreate with updated template

---

## 🚀 CREATE NEW WORKSPACE (MANUAL STEPS)

Since automation has parameter prompt issues, here's the manual process:

### Option 1: Coder Web UI (RECOMMENDED - EASIEST)

```
1. Open Coder dashboard: https://coder.xuperson.org
2. Click "Create Workspace"
3. Select template: "unified-devops"
4. Name: cccws
5. Fill parameters:
   - CPU: 4 cores
   - Memory: 16 GB
   - Home Disk: 50 GB
   - Container Image: codercom/enterprise-node:ubuntu (default)
   - Preview Port: 3000 (default)
   - AI Parameters: Leave empty (optional)
   - JetBrains IDEs: None (or select if needed)
   - Setup Script: Press ENTER to accept default
   - System Prompt: Press ENTER to accept default
6. Click "Create Workspace"
7. Wait 2-3 minutes for setup to complete
```

### Option 2: Coder CLI (Interactive)

```bash
coder create cccws --template unified-devops

# When prompted:
# - ai_prompt: Press ENTER (empty)
# - claude_api_key: Press ENTER (empty)
# - claude_oauth_token: Press ENTER (empty)
# - claude_api_endpoint: Press ENTER (empty)
# - gemini_api_key: Press ENTER (empty)
# - github_token: Press ENTER (will use external auth)
# - gitea_url: Press ENTER (empty)
# - gitea_token: Press ENTER (empty)
# - jetbrains_ides: Press ENTER (none selected)
# - setup_script: Press ENTER (use default - CRITICAL!)
# - system_prompt: Press ENTER (use default)
```

---

## ✅ VERIFICATION STEPS

After workspace is created and started:

```bash
# 1. SSH into workspace
coder ssh cccws

# 2. Verify setup script ran (should show 100+ lines)
wc -l /tmp/coder-startup-script.log

# 3. Check Claude Code installation
claude --version
# Expected: 2.0.44 (Claude Code) or similar

# 4. Verify MCP servers
claude mcp list
# Expected output:
# context7: https://mcp.context7.com/mcp (HTTP) - ✓ Connected
# sequential-thinking: npx -y @modelcontextprotocol/server-sequential-thinking - ✓ Connected
# deepwiki: https://mcp.deepwiki.com/mcp (HTTP) - ✓ Connected

# 5. Verify Node.js/npm
node --version && npm --version

# 6. Verify Docker
docker --version
docker ps

# 7. Check startup completion
tail -50 /tmp/coder-startup-script.log
# Should end with:
# ✅ Workspace setup complete!
# 🎯 Available AI tools: Claude Code (cc-c), Gemini CLI
# 🎯 MCP servers: context7, sequential-thinking, deepwiki
```

---

## 🐛 TROUBLESHOOTING

### If Claude Code is NOT installed:

```bash
# Check if setup script ran
cat /tmp/coder-startup-script.log

# If empty/short (< 100 lines):
# → setup_script parameter was empty!
# → Delete workspace and recreate, making sure to PRESS ENTER on setup_script prompt

# If script ran but Claude not installed:
# → Check for npm installation errors in log
sudo npm install -g @anthropic-ai/claude-code
```

### If MCP servers are wrong:

```bash
# List current MCP servers
claude mcp list

# Remove wrong ones
claude mcp remove desktop-commander

# Add correct ones
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http deepwiki https://mcp.deepwiki.com/mcp
```

### If Docker not working:

```bash
# Check Docker status
docker info

# If error: verify Envbox is running
kubectl get pods -n coder-workspaces | grep cccws
```

---

## 📝 IMPORTANT NOTES

1. **DO NOT** provide Claude API Key unless you want the Claude Code module
   - Module only needed for automatic Claude Code setup via Coder
   - The startup script installs Claude Code via npm regardless

2. **ALWAYS** accept the default for `setup_script` parameter
   - It contains the full 180-line installation script
   - Changing it will break the installation

3. **GitHub Token** is automatically provided via external auth
   - No need to manually enter it
   - Will be available as $GITHUB_TOKEN in workspace

4. **Workspace takes 2-3 minutes** to fully start
   - Docker needs time to pull images
   - npm packages need to install
   - Don't interrupt during startup!

---

## 🎯 EXPECTED RESULT

After successful creation, you should have:

✅ Claude Code CLI installed (`claude --version`)
✅ MCP Servers: context7, sequential-thinking, deepwiki
✅ Gemini CLI installed (`gemini --version`)
✅ Docker working (`docker ps`)
✅ Kubectl configured (`kubectl version`)
✅ GitHub CLI authenticated (`gh auth status`)
✅ TypeScript available (`tsc --version`)
✅ Node.js/npm available
✅ All bash aliases configured

**Test it:**
```bash
workspace-info  # Shows all tool versions
claude mcp list # Shows MCP servers
docker run hello-world # Tests Docker
```

---

## 📚 FILES REFERENCE

- **Template**: /home/coder/projects/claude-coder-space/main.tf
- **Bug Report**: CRITICAL_BUG_REPORT.md
- **Implementation Summary**: IMPLEMENTATION_SUMMARY.md
- **This Guide**: WORKSPACE_RECREATION_GUIDE.md

**Git Commits:**
- `4ee459d` - Fixed MCP servers
- `2430281` - Reverted setup_script to immutable

**Template Version**: Nov 18 11:01:24 (boring_haslett6 or later)

---

**Status**: ⚠️ Ready for manual workspace creation via Web UI or CLI

**Next Action**: Create workspace manually following Option 1 or Option 2 above
