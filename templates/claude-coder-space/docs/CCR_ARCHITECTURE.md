# Claude Code Resume (CCR) - Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Coder Kubernetes Cluster                       │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Workspace Pod                               │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │  Coder Agent (main.tf deployed)                          │ │ │
│  │  │                                                           │ │ │
│  │  │  ┌────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  User Session (bash)                                │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  │  ~/.bashrc sources:                                 │  │ │ │
│  │  │  │  ~/scripts/claude-resume-helpers.sh                 │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  │  Available functions:                               │  │ │ │
│  │  │  │  ├─ ccr (resume)                                    │  │ │ │
│  │  │  │  ├─ ccr-list (list)                                 │  │ │ │
│  │  │  │  ├─ ccr-find (search)                               │  │ │ │
│  │  │  │  ├─ ccr-current (current)                           │  │ │ │
│  │  │  │  ├─ cct (tmux)                                      │  │ │ │
│  │  │  │  └─ ccra (auto-resume)                              │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  └─────────────────────────────────────────────────────┘  │ │ │
│  │  │                                                           │ │ │
│  │  │  ┌────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Claude Code CLI Process                           │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  │  Session Management:                                │  │ │ │
│  │  │  │  ├─ Reads: ~/.claude/projects/*/*.jsonl            │  │ │ │
│  │  │  │  ├─ Writes: ~/.claude/history.jsonl                │  │ │ │
│  │  │  │  └─ OAuth: ~/.claude/.credentials.json             │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  └─────────────────────────────────────────────────────┘  │ │ │
│  │  │                                                           │ │ │
│  │  │  ┌────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Tmux Sessions (optional)                          │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  │  claude-project-a:                                  │  │ │ │
│  │  │  │  ├─ Window 1: Claude CLI                           │  │ │ │
│  │  │  │  ├─ Window 2: Terminal                             │  │ │ │
│  │  │  │  └─ Window 3: Logs (watch)                         │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  │  claude-project-b:                                  │  │ │ │
│  │  │  │  └─ ... (same structure)                           │  │ │ │
│  │  │  │                                                     │  │ │ │
│  │  │  └─────────────────────────────────────────────────────┘  │ │ │
│  │  └───────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │         Persistent Volume Claim (Longhorn PVC - 20GB)         │ │
│  │                                                                │ │
│  │  /home/coder/                                                  │ │
│  │  ├─ .claude/                     ← Session data (persistent)  │ │
│  │  │  ├─ projects/                                              │ │
│  │  │  │  └─ -home-coder-projects-*/                            │ │
│  │  │  │     ├─ <session-id>.jsonl  ← Conversation history      │ │
│  │  │  │     └─ agent-*.jsonl       ← Agent sessions            │ │
│  │  │  ├─ history.jsonl             ← Global session index      │ │
│  │  │  ├─ .credentials.json         ← OAuth tokens              │ │
│  │  │  ├─ debug/                    ← Debug logs                │ │
│  │  │  └─ resume-logs/              ← Resume operation logs     │ │
│  │  │                                                            │ │
│  │  ├─ scripts/                                                  │ │
│  │  │  └─ claude-resume-helpers.sh  ← Helper functions          │ │
│  │  │                                                            │ │
│  │  └─ projects/                    ← User code repositories    │ │
│  │     └─ claude-coder-space/                                    │ │
│  │        ├─ main.tf                ← Template (source of truth) │ │
│  │        ├─ scripts/                                            │ │
│  │        │  └─ claude-resume-helpers.sh (dev copy)             │ │
│  │        └─ docs/                                               │ │
│  │           ├─ CLAUDE_SESSION_RESUME_GUIDE.md                   │ │
│  │           ├─ CLAUDE_SESSION_RESUME_IMPLEMENTATION.md          │ │
│  │           ├─ CCR_QUICK_REFERENCE.md                           │ │
│  │           └─ CCR_ARCHITECTURE.md (this file)                  │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Session Creation Flow

```
User runs: claude "task"
         │
         ├──→ Claude CLI starts
         │    │
         │    ├──→ Generates session ID (UUID)
         │    │
         │    ├──→ Creates ~/.claude/projects/<project>/<session-id>.jsonl
         │    │
         │    ├──→ Appends entry to ~/.claude/history.jsonl
         │    │    {
         │    │      "sessionId": "4bb63347...",
         │    │      "timestamp": 1762443128241,
         │    │      "project": "/home/coder/projects/myapp",
         │    │      "display": "task"
         │    │    }
         │    │
         │    └──→ Authenticates via ~/.claude/.credentials.json
         │         │
         │         └──→ Claude API (OAuth)
         │
         └──→ Session runs...
              │
              └──→ After ~5 hours → OAuth token expires
                   │
                   └──→ Session terminates (rate limit)
```

### Session Resume Flow

```
User runs: ccr "4bb63347..."
         │
         ├──→ ccr function reads session ID
         │
         ├──→ Executes: claude -r "4bb63347..." "continue"
         │    │
         │    ├──→ Claude CLI looks up session
         │    │    │
         │    │    └──→ Reads: ~/.claude/projects/**/4bb63347*.jsonl
         │    │
         │    ├──→ Loads full conversation history
         │    │    │
         │    │    └──→ Restores context:
         │    │         ├─ Working directory
         │    │         ├─ Git branch
         │    │         ├─ Previous messages
         │    │         └─ Environment variables
         │    │
         │    ├──→ Refreshes OAuth token
         │    │    │
         │    │    └──→ Updates ~/.claude/.credentials.json
         │    │
         │    └──→ Continues conversation from last message
         │
         └──→ Session continues...
```

### Tmux Integration Flow

```
User runs: cct "4bb63347..."
         │
         ├──→ cct function checks for existing tmux session
         │    │
         │    ├──→ Not found → Create new session:
         │    │    │
         │    │    ├──→ tmux new-session "claude-<project>"
         │    │    │    │
         │    │    │    ├──→ Window 1: claude -r "4bb63347..."
         │    │    │    ├──→ Window 2: bash (empty)
         │    │    │    └──→ Window 3: watch tail ~/.claude/debug/*
         │    │    │
         │    │    └──→ tmux attach-session
         │    │
         │    └──→ Found → tmux attach-session (existing)
         │
         └──→ User works in tmux
              │
              ├──→ Ctrl+b d → Detach (session keeps running)
              │
              └──→ Later: tmux attach -t "claude-<project>"
```

### Auto-Resume (ccra) Flow

```
User runs: ccra
         │
         ├──→ Scan for rate-limited sessions:
         │    find ~/.claude/projects -name "*.jsonl" -exec grep -l "rate.*limit\|exceeded" {} \;
         │
         ├──→ For each rate-limited session:
         │    │
         │    ├──→ Extract session ID from filename
         │    │
         │    ├──→ Skip agent sessions (agent-*.jsonl)
         │    │
         │    └──→ Background resume:
         │         timeout 30s claude -r "<session-id>" "continue" \
         │         > ~/.claude/resume-logs/$(date)-<session-id>.log 2>&1 &
         │
         └──→ Wait 2 seconds between resumes (rate limiting)
```

## Component Interactions

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       │ Types commands (ccr, cct, ccra)
       │
       ▼
┌─────────────────────────────────┐
│   Bash Shell                    │
│   (~/.bashrc sourced helpers)   │
└────────┬────────────────────────┘
         │
         │ Calls function
         │
         ▼
┌─────────────────────────────────┐
│   Helper Functions              │
│   (claude-resume-helpers.sh)    │
│                                 │
│   ├─ ccr()                      │
│   ├─ ccr-list()                 │
│   ├─ cct()                      │
│   └─ ccra()                     │
└────────┬────────────────────────┘
         │
         │ Invokes Claude CLI or tmux
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐  ┌──────────────┐
│ Claude │  │    Tmux      │
│  CLI   │  │              │
└───┬────┘  └──────┬───────┘
    │              │
    │              │ Manages persistent sessions
    │              │
    ▼              ▼
┌────────────────────────────────┐
│   Session Storage              │
│   (~/.claude/)                 │
│                                │
│   ├─ projects/*/*.jsonl        │
│   ├─ history.jsonl             │
│   ├─ .credentials.json         │
│   └─ resume-logs/              │
└────────────────────────────────┘
         │
         │ Persisted via
         │
         ▼
┌────────────────────────────────┐
│   Kubernetes PVC (Longhorn)    │
│   /home/coder → 20GB           │
└────────────────────────────────┘
```

## Deployment Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                        │
│                                                              │
│  ┌────────────────┐         ┌───────────────────────────┐   │
│  │  Terraform     │ apply   │  Coder Server             │   │
│  │  (main.tf)     │────────→│  (Kubernetes Deployment)  │   │
│  └────────────────┘         └──────────┬────────────────┘   │
│                                         │                    │
└─────────────────────────────────────────┼────────────────────┘
                                          │
                                          │ Creates workspace
                                          │
                        ┌─────────────────▼────────────────┐
                        │    Workspace Pod (Kubernetes)    │
                        │                                  │
                        │  ┌────────────────────────────┐  │
                        │  │  Init Container            │  │
                        │  │  (setup_script runs)       │  │
                        │  │                            │  │
                        │  │  1. Create directories     │  │
                        │  │  2. Install helpers        │  │
                        │  │  3. Configure .bashrc      │  │
                        │  │  4. Set permissions        │  │
                        │  └────────────────────────────┘  │
                        │                                  │
                        │  ┌────────────────────────────┐  │
                        │  │  Main Container            │  │
                        │  │  (Coder Agent)             │  │
                        │  │                            │  │
                        │  │  - User shell sessions     │  │
                        │  │  - Claude CLI available    │  │
                        │  │  - CCR functions ready     │  │
                        │  └────────────────────────────┘  │
                        │                                  │
                        └──────────────────────────────────┘
                                          │
                                          │ Mounts PVC
                                          │
                        ┌─────────────────▼────────────────┐
                        │    Longhorn PVC (20GB)           │
                        │    /home/coder                   │
                        │                                  │
                        │    ✅ Survives pod restarts      │
                        │    ✅ Survives workspace stop    │
                        │    ✅ Survives template updates  │
                        └──────────────────────────────────┘
```

## File Lifecycle

```
main.tf (lines 473-634)
         │
         │ Embedded during terraform apply
         │
         ▼
coder_script "setup_script"
         │
         │ Executes on workspace creation
         │
         ▼
~/scripts/claude-resume-helpers.sh (created)
         │
         │ chmod +x
         │
         ├──→ Exported functions available in shell
         │
         └──→ Appended to ~/.bashrc (source command)
                  │
                  │ Loaded on every shell startup
                  │
                  ▼
            User types: ccr, cct, ccra, etc.
                  │
                  │ Functions execute
                  │
                  ▼
            Interacts with ~/.claude/
                  │
                  └──→ Persistent across restarts (PVC)
```

## Security Model

```
┌─────────────────────────────────────────────────────────┐
│                   Security Layers                       │
│                                                         │
│  Kubernetes RBAC                                        │
│  ├─ User can only access their workspace pod           │
│  └─ No cross-workspace access                          │
│                                                         │
│  Pod Security                                           │
│  ├─ Non-privileged container (unless Docker needed)    │
│  ├─ User namespaces isolated                           │
│  └─ Network policies applied                           │
│                                                         │
│  PVC Security                                           │
│  ├─ Mounted only to owner's workspace                  │
│  ├─ Encryption at rest (Longhorn feature)              │
│  └─ Access control via Kubernetes                      │
│                                                         │
│  File Permissions                                       │
│  ├─ ~/.claude/.credentials.json (600)                  │
│  ├─ ~/scripts/claude-resume-helpers.sh (755)           │
│  └─ Session files (644)                                │
│                                                         │
│  OAuth Security                                         │
│  ├─ Tokens stored encrypted                            │
│  ├─ Auto-refresh on expiry                             │
│  └─ Scoped to Anthropic API only                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Failure Modes and Recovery

```
Scenario 1: OAuth Token Expires
    ├─ Detection: Claude CLI returns 401 error
    ├─ Recovery: Auto-refresh via .credentials.json
    └─ Fallback: User re-authenticates with `claude setup-token`

Scenario 2: Session File Corrupted
    ├─ Detection: jq parsing error or read failure
    ├─ Recovery: Skip that session in ccr-list
    └─ Fallback: User can manually inspect/fix .jsonl file

Scenario 3: Workspace Deleted
    ├─ Detection: N/A (user action)
    ├─ Recovery: Data lost (unless PVC retained)
    └─ Mitigation: Use ccr-export before deletion

Scenario 4: PVC Full (20GB limit)
    ├─ Detection: Disk space errors
    ├─ Recovery: Clean old sessions manually
    └─ Mitigation: Archive old sessions with ccr-export

Scenario 5: Tmux Session Crashes
    ├─ Detection: tmux list-sessions shows no session
    ├─ Recovery: Restart with cct (resumes from session file)
    └─ Fallback: Direct claude -r command

Scenario 6: Helper Functions Not Loaded
    ├─ Detection: "command not found: ccr"
    ├─ Recovery: source ~/scripts/claude-resume-helpers.sh
    └─ Mitigation: Verify .bashrc integration
```

## Performance Characteristics

```
Operation              Time        Disk I/O    Network
─────────────────────────────────────────────────────────
ccr (resume)           ~2-5s       Read 1-5MB  OAuth refresh
ccr-list               <1s         Read <100KB None
ccr-find               <2s         Scan files  None
cct (create)           <1s         None        None
cct (attach)           <500ms      None        None
ccra (10 sessions)     ~30s        Read 10-50MB Multiple OAuth
Session file write     ~100ms/msg  Append KB   None
```

## Scalability Considerations

```
Metric                  Current      Recommended Max    Notes
─────────────────────────────────────────────────────────────────
Sessions per project    Unlimited    100-500            Cleanup old sessions
Total sessions          Unlimited    1000-5000          20GB PVC limit
Tmux sessions           Unlimited    10-20              Memory constraints
Resume operations       Unlimited    10 concurrent      Rate limiting
Session file size       1-5MB avg    50MB max           Archive large sessions
```

## Integration Points

```
External System         Integration Type    Purpose
────────────────────────────────────────────────────────────
Coder Server            Terraform provider  Workspace lifecycle
Kubernetes API          PVC management      Persistent storage
Anthropic API           OAuth + REST        Claude AI service
Tmux                    Shell integration   Persistent terminals
Git                     File-based          Session context
Bash                    Function export     CLI interface
```

---

**Last Updated**: November 18, 2025
**Version**: 1.0
**Author**: Claude Code Implementation Team
