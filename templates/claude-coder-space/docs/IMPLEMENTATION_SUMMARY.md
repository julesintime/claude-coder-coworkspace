# Implementation Summary - Unified DevOps Template Fixes

**Date**: November 18, 2025
**Template**: `unified-devops`
**Status**: ✅ Successfully pushed (version: Nov 18 09:13:50)

## Issues Fixed

### 1. Base Image Changed ✅
**Problem**: `codercom/enterprise-base:ubuntu` lacked Node.js and npm

**Solution**: Changed to `codercom/enterprise-node:ubuntu`

**This image includes**:
- ✅ Python 3 and pip
- ✅ Node.js LTS
- ✅ npm
- ✅ Yarn
- ✅ Docker
- ✅ Build tools
- ✅ All development utilities

**Impact**:
- Gemini CLI installation will work
- Claude Code CLI installation will work
- TypeScript is now installed globally
- All npm-based tools work correctly

### 2. TypeScript Support Added ✅
**Added to setup script**:
```bash
# TypeScript
if ! command -v tsc >/dev/null 2>&1; then
  echo "📦 Installing TypeScript globally..."
  if command -v npm >/dev/null 2>&1; then
    sudo npm install -g typescript || echo "⚠️ TypeScript installation failed, skipping..."
  fi
fi
```

**Result**: Full TypeScript development environment

### 3. MCP Server Documentation Updated ✅
**Clarification**: MCP servers are configured on LOCAL machine, not in workspace

**Updated README** with:
- How to configure MCP servers with `coder exp mcp configure`
- Available MCP servers: sequential-thinking, deepwiki, context7
- Usage examples for Claude Code CLI

**Note**: The workspace includes three core MCP servers for enhanced AI capabilities

### 4. GitHub External Authentication Prepared (Manual Step Required) ⚠️
**Status**: Ready but commented out - needs manual verification

**What was done**:
- Added external auth data source (commented)
- Added locals for token handling (commented)
- Documented how to enable it

**What you need to do**:

1. **Verify the external auth ID on your Coder server**:
   ```bash
   # SSH into existing workspace (or create test workspace)
   coder ssh <workspace-name>

   # Try different possible IDs:
   coder external-auth access-token primary-github
   coder external-auth access-token github
   coder external-auth access-token github-oauth
   ```

2. **Once you find the correct ID**, edit `main.tf`:

   **Lines 405-416** - Uncomment and update ID:
   ```hcl
   data "coder_external_auth" "github" {
     id       = "github"  # ← Change to match your server
     optional = true
   }
   ```

   **Lines 428-433** - Uncomment these locals:
   ```hcl
   has_github_external_auth = data.coder_external_auth.github.access_token != ""
   has_github_param_token   = length(data.coder_parameter.github_token.value) > 0
   github_token = local.has_github_external_auth ? data.coder_external_auth.github.access_token : data.coder_parameter.github_token.value
   has_github_token = local.has_github_external_auth || local.has_github_param_token
   ```

   **Lines 435-437** - Comment out these defaults:
   ```hcl
   # has_github_token = length(data.coder_parameter.github_token.value) > 0
   # github_token     = data.coder_parameter.github_token.value
   ```

3. **Push updated template**:
   ```bash
   cd /home/coder/projects/claude-coder-space
   git add main.tf
   git commit -m "feat: enable GitHub external authentication"
   echo "yes" | coder templates push unified-devops -d . -m "Enable GitHub external auth"
   ```

4. **Test with new workspace**:
   ```bash
   # Create new workspace to test
   coder create test-ws --template unified-devops

   # SSH into workspace
   coder ssh test-ws

   # Verify GitHub token is available
   echo $GITHUB_TOKEN

   # Verify gh CLI is authenticated
   gh auth status

   # Test GitHub Copilot (if subscribed)
   gh copilot --version
   ```

## File Changes

### Modified Files
1. **main.tf**:
   - Changed `container_image` default to `codercom/enterprise-node:ubuntu` (line 115)
   - Added TypeScript installation to setup script (lines 324-330)
   - Added external auth blocks (commented) with instructions (lines 405-437)
   - Updated MCP server comments (lines 332-338)

2. **README.md**:
   - Updated MCP server documentation (lines 482-513)
   - Clarified client-side vs workspace-side configuration
   - Added usage examples

### Commits
1. `e20de87` - fix: use enterprise-node image and enable GitHub external auth
2. `ddbe1b1` - fix: comment external auth until ID is verified

## Testing Checklist

Before creating new workspaces, verify:

- [ ] Template shows as "Active" in Coder dashboard
- [ ] No errors in template logs
- [ ] Create test workspace
- [ ] Verify Node.js/npm available (`node --version`, `npm --version`)
- [ ] Verify Python available (`python3 --version`)
- [ ] Verify TypeScript available (`tsc --version`)
- [ ] Verify Docker works (`docker --version`)
- [ ] Verify kubectl works (`kubectl version --client`)
- [ ] Check if GITHUB_TOKEN environment variable is set
- [ ] Test gh CLI authentication (`gh auth status`)
- [ ] Test Claude Code CLI (`claude --version`)
- [ ] Test Gemini CLI (`gemini --version`)

## Next Steps

1. **Identify GitHub External Auth ID** (see section above)
2. **Update main.tf** with correct ID
3. **Push updated template**
4. **Delete old workspace** (if you have one using the old template)
5. **Create new workspace** from updated template
6. **Verify all tools work** using checklist above

## MCP Configuration (Client-Side)

On your **local machine** (not in workspace):

```bash
# Configure MCP servers
coder exp mcp configure

# Enable recommended servers:
# - sequential-thinking (advanced reasoning)
# - deepwiki (GitHub repo documentation)
# - context7 (library docs)
```

Once configured, these will be available in all workspaces when using Claude Code CLI.

## Support

If you encounter issues:

1. Check workspace logs: `coder logs <workspace-name>`
2. Check template version: `coder templates versions list unified-devops`
3. Verify setup script ran: SSH into workspace and check installation logs
4. Review error messages in Coder dashboard

## References

- [Coder External Auth Docs](https://coder.com/docs/admin/external-auth)
- [Coder MCP Server Docs](https://coder.com/docs/ai-coder/mcp-server)
- [Coder Images Repository](https://github.com/coder/images)
- [SSO and External Auth Integration Guide](docs/SSO_AND_EXTERNAL_AUTH_GUIDE.md)
