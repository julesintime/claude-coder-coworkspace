# Claude Code Session Resume Guide
## Handling 5-Hour OAuth Limits in Coder Workspaces

---

## 🎯 Solution Overview

**Simple, lightweight session management** integrated directly into your Coder workspace template. No complex databases, no systemd timers, just practical bash functions.

### Key Features
✅ **Persistent Sessions** - All Claude sessions automatically saved to `/home/coder/.claude` (backed by Kubernetes PVC)
✅ **Quick Resume** - `ccr <session-id>` to resume any session
✅ **Tmux Integration** - `cct` for persistent Claude sessions
✅ **Auto-Recovery** - `ccra` to resume all rate-limited sessions
✅ **Zero Configuration** - Automatically deployed with workspace

---

## 📦 Volume Persistence (Verified)

Your Coder workspace uses a **Longhorn PVC** for `/home/coder`:

```bash
$ df -h /home/coder
Filesystem                                              Size  Used Avail Use%
/dev/longhorn/pvc-e10e6a5c-3abb-49f6-bab8-f7bce68692e4   20G  6.8G   13G  35%

$ mount | grep /home/coder
/dev/longhorn/pvc-e10e6a5c-3abb-49f6-bab8-f7bce68692e4 on /home/coder type ext4 (rw,relatime)
```

**This means:**
- ✅ All data in `/home/coder` persists across workspace stops/starts
- ✅ `~/.claude/` directory is **permanent**
- ✅ All session files in `~/.claude/projects/` are **preserved**
- ✅ OAuth tokens in `~/.claude/.credentials.json` are **persistent**
- ✅ No need for archive module - data is already safe

---

## 🚀 Quick Start Commands

### 1. List Recent Sessions
```bash
ccr-list
```
Output:
```
📋 Recent Claude Code sessions:
 1 [2025-11-18 17:49] 4bb63347... - /home/coder/projects/portfolio-com - create fresh vanilla nextjs
 2 [2025-11-18 15:31] dae96318... - /home/coder/projects/portfolio-com - how to fix code not installed
 3 [2025-11-18 11:10] 0d6f336f... - /home/coder/projects/claude-coder-space - hi
```

### 2. Resume Specific Session
```bash
ccr "4bb63347-fb0d-4478-85b2-c7d1a7f248fa"
```

Or with custom prompt:
```bash
ccr "4bb63347-fb0d-4478-85b2-c7d1a7f248fa" "continue with the previous task and add tests"
```

### 3. Start Claude in Tmux (Persistent Terminal)
```bash
# New session
cct

# Resume existing session in tmux
cct "4bb63347-fb0d-4478-85b2-c7d1a7f248fa"

# Resume session in specific project
cct "4bb63347-fb0d-4478-85b2-c7d1a7f248fa" "/home/coder/projects/myproject"
```

**Tmux Layout:**
- Window 1: Claude session (interactive)
- Window 2: Regular terminal
- Window 3: Live logs (auto-updating)

**Tmux Navigation:**
- `Ctrl+b n` - Next window
- `Ctrl+b p` - Previous window
- `Ctrl+b d` - Detach (keeps running in background)
- `Ctrl+b ?` - Show all keybindings

### 4. Resume All Rate-Limited Sessions
```bash
ccra
```

This will:
- Scan all sessions for rate limit errors
- Auto-resume each one in background
- Log output to `~/.claude/resume-logs/`

---

## 📚 All Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `ccr <id> [prompt]` | Resume specific session | `ccr "abc123" "continue"` |
| `ccr-list [limit]` | List recent sessions (default 20) | `ccr-list 50` |
| `ccr-find <keyword>` | Search sessions by keyword | `ccr-find "nextjs"` |
| `ccr-current` | Show current/most recent session | `ccr-current` |
| `cct [id] [path]` | Start Claude in tmux | `cct` or `cct "abc123"` |
| `cct-list` | List active tmux sessions | `cct-list` |
| `cct-kill [name]` | Kill tmux session | `cct-kill claude-myproject` |
| `ccra` | Resume all rate-limited | `ccra` |

---

## 🔧 Technical Details

### Session Storage Structure
```
~/.claude/
├── projects/
│   ├── -home-coder-projects-repo1/
│   │   ├── 4bb63347-fb0d-4478-85b2-c7d1a7f248fa.jsonl  # User session
│   │   └── agent-b0cabcd1.jsonl                         # Agent session
│   └── -home-coder-projects-repo2/
│       └── ...
├── history.jsonl         # Global session index (fast lookup)
├── .credentials.json     # OAuth tokens
├── debug/                # Debug logs
└── resume-logs/          # Resume operation logs
```

### Session File Format (JSONL)
Each line in a `.jsonl` session file contains:
```json
{
  "sessionId": "4bb63347-fb0d-4478-85b2-c7d1a7f248fa",
  "project": "/home/coder/projects/portfolio-com",
  "cwd": "/home/coder/projects/portfolio-com",
  "gitBranch": "main",
  "timestamp": "2025-11-18T17:49:00.000Z",
  "message": { ... }
}
```

### How Resume Works
1. Claude CLI reads session file from `~/.claude/projects/`
2. Loads full conversation history
3. Restores context (working directory, git branch, etc.)
4. Continues from last message

### Rate Limit Detection
The `ccra` command searches for these patterns in session files:
- `rate.*limit`
- `usage.*limit`
- `exceeded`
- `quota`
- `overloaded`

---

## 💡 Usage Patterns

### Pattern 1: Long-Running Task with Auto-Resume
```bash
# Start task
claude "implement the entire authentication system"

# After ~4.5 hours, when approaching limit:
# 1. Note the session ID from output or use ccr-current
# 2. Resume manually:
ccr "$(ccr-current | grep -o '[0-9a-f-]\{36\}')"

# Or set up a cron job (see below)
```

### Pattern 2: Multiple Projects in Tmux
```bash
# Terminal 1: Project A
cd /home/coder/projects/project-a
cct

# Terminal 2: Project B (detached)
cd /home/coder/projects/project-b
cct
# Press Ctrl+b d to detach

# View all sessions
cct-list

# Attach to specific session
tmux attach -t claude-project-b
```

### Pattern 3: Mobile/Remote Development
```bash
# On mobile or different machine:
# 1. SSH/connect to Coder workspace
# 2. List sessions
ccr-list

# 3. Resume where you left off
ccr "abc123"
```

---

## ⏰ Automated Resume with Cron (Optional)

If you want automatic resume before hitting 5-hour limit:

```bash
# Edit crontab
crontab -e

# Add this line to resume every 4 hours
0 */4 * * * bash -c 'source ~/.bashrc && ccra >> ~/.claude/cron-resume.log 2>&1'
```

Or for a specific project:
```bash
# Resume main project session every 4 hours
0 */4 * * * cd /home/coder/projects/main && claude --continue >> ~/.claude/auto-resume.log 2>&1
```

---

## 🔍 Troubleshooting

### Problem: `ccr-list` shows "No history found"
**Solution:** Start at least one Claude session first. The history file is created on first use.

### Problem: Session resumes but loses context
**Solution:** This shouldn't happen as Claude preserves full context. Check:
```bash
# Verify session file exists
ls -la ~/.claude/projects/*/*.jsonl | grep <session-id>

# Check file size (should be > 0)
du -h ~/.claude/projects/*/<session-id>.jsonl
```

### Problem: OAuth token expired
**Solution:** Re-authenticate:
```bash
claude setup-token
# Follow the OAuth flow
```

### Problem: Tmux session not attaching
**Solution:**
```bash
# Kill stuck session
tmux kill-session -t claude-myproject

# Start fresh
cct
```

### Problem: `ccra` not finding rate-limited sessions
**Solution:** Check manually:
```bash
# Search for rate limit messages
grep -r "rate limit" ~/.claude/projects/

# If found, get session ID and resume manually
ccr "<session-id>"
```

---

## 📊 Session Statistics

Get insights into your Claude usage:

```bash
# Total sessions
find ~/.claude/projects -name "*.jsonl" | wc -l

# Sessions by project
find ~/.claude/projects -type d -mindepth 1 -maxdepth 1 | while read dir; do
    echo "$(basename $dir): $(ls $dir/*.jsonl 2>/dev/null | wc -l) sessions"
done

# Most recent sessions
ccr-list 10

# Disk usage
du -sh ~/.claude/projects/
```

---

## 🎛️ Integration with Coder Template

The helpers are automatically installed via `main.tf`:

```hcl
# In setup_script (lines 473-576)
cat > ~/scripts/claude-resume-helpers.sh << 'CLAUDE_HELPERS_EOF'
# ... all helper functions ...
CLAUDE_HELPERS_EOF

# Auto-sourced in .bashrc (lines 588-591)
if [ -f ~/scripts/claude-resume-helpers.sh ]; then
    source ~/scripts/claude-resume-helpers.sh
fi
```

**Deployment:** Functions are available immediately after workspace starts.

---

## 🆚 Comparison to Other Solutions

| Approach | Complexity | Reliability | Session-Aware | Our Solution |
|----------|------------|-------------|---------------|--------------|
| Systemd Timer | High | High | ❌ No | ❌ Not used |
| Session Manager + SQLite | Very High | High | ✅ Yes | ❌ Overkill |
| AgentAPI | Medium | Medium | ❌ No | ❌ Not session-aware |
| **Simple CCR/CCT** | **Low** | **High** | **✅ Yes** | **✅ Implemented** |

---

## 🔐 Security Notes

- OAuth tokens stored in `~/.claude/.credentials.json` (persistent)
- File permissions: `600` (owner read/write only)
- Session files contain full conversation history (keep confidential)
- Tmux sessions visible only to workspace owner
- No external services required

---

## 📝 Examples from Real Usage

### Example 1: Portfolio Website Development
```bash
$ ccr-list
 1 [2025-11-18 17:49] 4bb63347... - /home/coder/projects/portfolio-com - create fresh vanilla nextjs

$ ccr "4bb63347-fb0d-4478-85b2-c7d1a7f248fa"
🔄 Resuming Claude session: 4bb63347-fb0d-4478-85b2-c7d1a7f248fa
I'll continue with the Next.js portfolio site...
```

### Example 2: Multiple Project Management
```bash
$ cct-list
📺 Active Claude tmux sessions:
claude-portfolio-com: 3 windows
claude-api-backend: 3 windows
claude-mobile-app: 3 windows

$ tmux attach -t claude-api-backend
# Work on API
# Ctrl+b d to detach

$ tmux attach -t claude-mobile-app
# Work on mobile app
```

---

## 🚀 Next Steps

1. ✅ **Workspace is configured** - helpers auto-installed
2. ✅ **Sessions are persistent** - backed by Kubernetes PVC
3. ✅ **Commands available** - use `ccr`, `cct`, etc.

**Try it now:**
```bash
# Start a test session
claude "create a hello world app"

# After it completes, list sessions
ccr-list

# Resume it
ccr "$(ccr-current | grep -o '[0-9a-f-]\{36\}')"
```

---

## 📚 Related Documentation

- [Claude Code CLI Reference](https://docs.claude.com/en/docs/claude-code/cli-reference)
- [Coder Workspace Lifecycle](https://coder.com/docs/user-guides/workspace-lifecycle)
- [Tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [Kubernetes PVC](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

## 🆘 Support

If you encounter issues:

1. **Check logs:**
   ```bash
   tail -f ~/.claude/debug/*.txt
   tail -f ~/.claude/resume-logs/*.log
   ```

2. **Verify installation:**
   ```bash
   type ccr cct ccra
   ls -la ~/scripts/claude-resume-helpers.sh
   ```

3. **Re-source helpers:**
   ```bash
   source ~/scripts/claude-resume-helpers.sh
   ```

---

**Happy Coding!** 🚀

Your Claude Code sessions are now persistent, resumable, and protected against the 5-hour OAuth limit.
