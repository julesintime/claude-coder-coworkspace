# Claude Code Resume (CCR) - Quick Reference Card

## 🚀 Common Commands

### Resume Session
```bash
ccr <session-id> [prompt]         # Resume specific session
ccr "4bb63347..." "continue"      # Resume with custom prompt
```

### List & Search
```bash
ccr-list [limit]                  # List recent sessions (default 20)
ccr-list 50                       # List last 50 sessions
ccr-find "keyword"                # Search sessions by keyword
ccr-current                       # Show current/most recent session
```

### Tmux Integration
```bash
cct                               # Start Claude in new tmux session
cct "4bb63347..."                 # Resume session in tmux
cct "4bb63347..." /path/to/proj   # Resume in specific project path
cct-list                          # List active Claude tmux sessions
cct-kill <session-name>           # Kill specific tmux session
```

### Auto-Recovery
```bash
ccra                              # Resume all rate-limited sessions
ccr-export <session-id> [file]    # Export session to archive
```

## 📋 Tmux Keybindings

```bash
Ctrl+b n        # Next window
Ctrl+b p        # Previous window
Ctrl+b 0-9      # Switch to window number
Ctrl+b d        # Detach (keeps running)
Ctrl+b c        # Create new window
Ctrl+b ,        # Rename current window
Ctrl+b ?        # Show all keybindings
```

## 🔍 Quick Troubleshooting

### Functions not available
```bash
source ~/scripts/claude-resume-helpers.sh
```

### No history found
```bash
# Start at least one Claude session first
claude "test"
```

### Find session ID from running process
```bash
ccr-current
```

### View session files
```bash
ls -la ~/.claude/projects/*/*.jsonl
```

### Check logs
```bash
tail -f ~/.claude/debug/*.txt
tail -f ~/.claude/resume-logs/*.log
```

## 📊 Session Info

### Session Storage Location
```
~/.claude/projects/<project-path>/<session-id>.jsonl
```

### Global History
```
~/.claude/history.jsonl
```

### Resume Logs
```
~/.claude/resume-logs/
```

## 💡 Common Workflows

### Workflow 1: Resume After Rate Limit
```bash
# Note current session
ccr-current

# Wait a few minutes

# Resume
ccr "<session-id>"
```

### Workflow 2: Long Task in Tmux
```bash
# Start in tmux
cct

# Detach: Ctrl+b d

# Later, reattach
tmux attach -t claude-<project>
```

### Workflow 3: Find and Resume Old Session
```bash
# Search for project
ccr-find "portfolio"

# Copy session ID from results

# Resume
ccr "<full-session-id>" "add new feature"
```

### Workflow 4: Monitor Multiple Projects
```bash
# Terminal 1: Project A
cd ~/projects/project-a && cct

# Terminal 2: Project B (Ctrl+b d to detach)
cd ~/projects/project-b && cct

# List all sessions
cct-list

# Attach to specific session
tmux attach -t claude-project-b
```

## 🔧 Advanced Usage

### Auto-Resume Every 4 Hours (Optional)
```bash
# Edit crontab
crontab -e

# Add line:
0 */4 * * * bash -c 'source ~/.bashrc && ccra >> ~/.claude/cron-resume.log 2>&1'
```

### Export Session for Backup
```bash
ccr-export "4bb63347..." ~/backups/session-$(date +%Y%m%d).tar.gz
```

### Find Large Sessions
```bash
find ~/.claude/projects -name "*.jsonl" -type f -exec du -h {} \; | sort -rh | head -10
```

### Clean Old Sessions
```bash
# Find sessions older than 90 days
find ~/.claude/projects -name "*.jsonl" -type f -mtime +90
```

## 🎯 Tips & Tricks

1. **Use tab completion**: Type `ccr` and press Tab twice to see session IDs
2. **Pipe to grep**: `ccr-list 100 | grep "portfolio"`
3. **Check session age**: Sessions auto-expire after OAuth timeout (~5 hours)
4. **Keep tmux detached**: Long tasks can run in background
5. **Monitor with watch**: `watch -n 5 'ccr-list 5'`

## 📚 Documentation

- Full Guide: `/home/coder/projects/claude-coder-space/CLAUDE_SESSION_RESUME_GUIDE.md`
- Implementation Details: `/home/coder/projects/claude-coder-space/CLAUDE_SESSION_RESUME_IMPLEMENTATION.md`
- Helper Script: `/home/coder/scripts/claude-resume-helpers.sh`

## 🆘 Quick Help

```bash
# Show this reference (if sourced)
cat ~/projects/claude-coder-space/CCR_QUICK_REFERENCE.md

# Get function help
type ccr ccr-list cct ccra

# Verify installation
ls -la ~/scripts/claude-resume-helpers.sh
```

---

**Pro Tip**: Add `alias ccr-help='cat ~/projects/claude-coder-space/CCR_QUICK_REFERENCE.md'` to your `.bashrc` for instant access to this reference!
