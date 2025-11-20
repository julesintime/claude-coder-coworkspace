# Claude Code Session Management - Diagnostic Report

## Executive Summary

After thorough investigation via SSH into the mega workspace, the Claude Code session management is **mostly working correctly**, but there are **critical bugs in the personalize script** that need fixing.

## Key Findings

### ✅ What's Working

1. **Session persistence**: Claude data persists correctly in `/home/coder/.claude/`
   - Directory structure includes: projects, resume-logs, downloads, shell-snapshots, todos
   - All session data survives workspace restarts

2. **lastSessionId cleanup**: The `lastSessionId` field is correctly set to `null`
   - No stale session ID issues detected
   - Claude Code can properly detect and resume from conversation history

3. **Module dependency**: We fixed the personalize → dotfiles dependency
   - Personalize now waits for dotfiles to complete (line 853 in main.tf)

### ❌ Critical Issues Found

1. **Personalize Script Syntax Error** (CRITICAL)
   ```
   /home/coder/personalize: line 18: unexpected EOF while looking for matching `"`
   ```
   - Location: Dotfiles repo personalize script
   - Impact: Prevents user personalization from running
   - Appears on EVERY workspace restart

2. **Gemini CLI Installation Failure**
   ```
   npm error 404  '@google/generative-ai-cli@*' is not in this registry.
   ```
   - Package doesn't exist in npm registry
   - Installation fails but is handled gracefully
   - Needs correction or removal

## Root Cause Analysis

The "session conflicts or missing" issue is NOT about Claude Code session management, but rather:

1. **Dotfiles personalize script** has a bash quoting error
2. This causes the personalize module to fail during startup
3. The failure appears in logs on every restart, creating perception of instability

## Comprehensive Solution

### 1. Fix Dotfiles Repository (REQUIRED)

The personalize script in `https://github.com/julesintime/coder-dotfiles` needs fixes:

**File**: `personalize`
**Line 18**: Fix the unclosed quote

**Also fix**: Gemini CLI installation
- Either use correct package name
- OR remove Gemini CLI installation entirely
- OR handle npm 404 gracefully with proper error checking

### 2. Add Session Health Check to main.tf (RECOMMENDED)

Add to unified-devops/main.tf startup_script:

```bash
# Claude Code session health check
echo "🔍 Checking Claude Code session health..."
if [ -f ~/.claude.json ]; then
  # Validate JSON integrity
  if ! jq empty ~/.claude.json 2>/dev/null; then
    echo "⚠️ Corrupt .claude.json detected, backing up and resetting..."
    cp ~/.claude.json ~/.claude.json.backup.$(date +%s)
    echo '{}' > ~/.claude.json
  fi

  # Remove stale lastSessionId (already handled by module, but adding safety)
  if [ "$(jq -r '.lastSessionId // "null"' ~/.claude.json)" != "null" ]; then
    echo "🧹 Cleaning stale session ID..."
    jq 'del(.lastSessionId)' ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
  fi
fi
```

### 3. Document Claude Session Helpers (RECOMMENDED)

The dotfiles already provide excellent Claude resume helpers. Document them prominently:

Available session management commands:
- `ccr <session-id>` - Resume specific Claude session
- `ccr-list` - List all recent sessions with metadata
- `ccr-find <keyword>` - Search sessions by content
- `cct [session-id]` - Run Claude in tmux for persistent sessions
- `ccra` - Resume all rate-limited sessions (batch recovery)

### 4. Add Startup Banner (OPTIONAL)

Add to startup_script after Claude Code installs:

```bash
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Claude Code Session Management                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Sessions persist across workspace restarts in ~/.claude/  ║"
echo "║                                                            ║"
echo "║  Helpers:                                                  ║"
echo "║    ccr-list          - List all sessions                   ║"
echo "║    ccr <session-id>  - Resume specific session             ║"
echo "║    ccr-find <term>   - Search sessions                     ║"
echo "║    cct               - Claude in tmux (persistent)         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
```

## Implementation Priority

### HIGH PRIORITY (Do First)
1. ✅ Fix personalize depends_on dotfiles (DONE)
2. ❌ Fix dotfiles personalize script syntax error
3. ❌ Fix or remove Gemini CLI installation

### MEDIUM PRIORITY (Enhances UX)
4. Add session health check to startup_script
5. Add startup banner documenting helpers

### LOW PRIORITY (Nice to Have)
6. Add automated session backup/restore
7. Add session conflict detection and resolution
8. Create session recovery webhook

## Technical Details

### Current Session Flow

```
Workspace Start
    ↓
Agent startup_script runs (installs packages)
    ↓
Dotfiles module runs (clones repo, runs install.sh)
    ↓
Personalize module runs (FAILS due to syntax error)
    ↓
Claude-code module runs (installs + configures)
    ↓
AgentAPI starts
    ↓
Claude Code ready (sessions persist correctly)
```

### Session Data Locations

- Config: `~/.claude.json`
- Session history: `~/.claude/projects/<project-id>/history/`
- Resume logs: `~/.claude/resume-logs/`
- Todos: `~/.claude/todos/`
- Debug logs: `~/.claude/debug/`

### MCP Servers Status

Currently configured MCP servers (post_install_script):
```bash
claude mcpadd --transport http context7 https://mcp.context7.com/mcp
claude mcpadd --transport http deepwiki https://mcp.deepwiki.com/mcp
```

These are added AFTER Claude installs, working correctly.

## Monitoring Commands

Run these in workspace to validate session health:

```bash
# Check .claude.json integrity
jq empty ~/.claude.json && echo "✅ Valid JSON" || echo "❌ Corrupt JSON"

# List Claude sessions
ls -lah ~/.claude/projects/*/history/ 2>/dev/null

# Check for personalize script issues
bash -n ~/personalize && echo "✅ Valid syntax" || echo "❌ Syntax error"

# Validate Claude Code installation
claude --version

# Check MCP servers
claude mcp list
```

## Next Steps

1. **IMMEDIATE**: Fix the dotfiles personalize script
   - Fix line 18 quoting issue
   - Fix Gemini CLI installation
   - Test in fresh workspace

2. **SOON**: Add session health check to main.tf
   - Validates .claude.json on startup
   - Cleans stale data proactively

3. **LATER**: Document session management
   - Add to CLAUDE.md
   - Create runbook for session recovery
   - Add troubleshooting guide

## Conclusion

The Claude Code session management infrastructure is **solid and working correctly**. The perceived "conflicts or missing sessions" is actually caused by the **dotfiles personalize script syntax error** appearing in logs on every restart.

**Fix the personalize script and the issue will be resolved.**
