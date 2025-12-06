#!/bin/bash
set -e

echo "🚀 DevContainer Post-Create Setup..."
echo "=================================="

# ========================================
# ENVIRONMENT SETUP
# ========================================

# Create project directories
mkdir -p /home/node/projects
mkdir -p ~/.claude/resume-logs
mkdir -p ~/scripts

# ========================================
# INSTALL PM2 PROCESS MANAGER
# ========================================

if ! command -v pm2 >/dev/null 2>&1; then
  echo "📦 Installing PM2 process manager..."
  sudo npm install -g pm2 --force || {
    echo "⚠️ PM2 installation failed, retrying..."
    sleep 2
    sudo npm install -g pm2 --force
  }
  echo "✅ PM2 installed: $(pm2 --version)"
else
  echo "✅ PM2 already installed: $(pm2 --version)"
fi

# ========================================
# INSTALL UI TOOLS
# ========================================

# Claude Code UI
if ! command -v claude-code-ui >/dev/null 2>&1; then
  echo "📦 Installing Claude Code UI..."
  sudo npm install -g @siteboon/claude-code-ui --force || {
    echo "⚠️ Claude Code UI installation failed, retrying..."
    sleep 2
    sudo npm install -g @siteboon/claude-code-ui --force
  }
  echo "✅ Claude Code UI installed"
else
  echo "✅ Claude Code UI already installed"
fi

# Create Claude Code UI data directory
mkdir -p ~/.claude-code-ui

# Create Vibe Kanban data directory
mkdir -p ~/.vibe-kanban

# ========================================
# INSTALL ADDITIONAL TOOLS (OPTIONAL)
# ========================================

# Gitea CLI (tea) - if needed
if ! command -v tea >/dev/null 2>&1; then
  echo "📦 Installing Gitea CLI (tea)..."
  wget -qO /tmp/tea https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64
  sudo install -m 755 /tmp/tea /usr/local/bin/tea
  rm /tmp/tea
  echo "✅ Gitea CLI installed"
fi

# ========================================
# SETUP HELPER SCRIPTS
# ========================================

echo "⚙️ Installing Claude session management helpers..."

# Create claude-resume-helpers.sh
cat > ~/scripts/claude-resume-helpers.sh << 'CLAUDE_HELPERS_EOF'
#!/bin/bash
# Claude Code Resume Helpers

ccr() {
    local session_id=$1
    local prompt=${2:-"continue"}
    [ -z "$session_id" ] && echo "❌ Usage: ccr <session-id> [prompt]" && return 1
    echo "🔄 Resuming Claude session: $session_id"
    claude --dangerously-skip-permissions -r "$session_id" "$prompt"
}

ccr-list() {
    local limit=${1:-20}
    echo "📋 Recent Claude Code sessions:"
    [ ! -f ~/.claude/history.jsonl ] && echo "⚠️  No history found" && return 1
    tail -$limit ~/.claude/history.jsonl | jq -r 'if .timestamp then ((.timestamp / 1000) | strftime("%Y-%m-%d %H:%M")) as $time | "\($time) | \(.sessionId[0:8])... | \(.project // \"?\") | \(.display[0:60] // \"no prompt\")" else "? | ? | ? | ?" end' | tac | nl
}

ccr-find() {
    local keyword=$1
    [ -z "$keyword" ] && echo "❌ Usage: ccr-find <keyword>" && return 1
    echo "🔍 Searching for sessions containing: $keyword"
    [ ! -f ~/.claude/history.jsonl ] && echo "⚠️  No history found" && return 1
    grep -i "$keyword" ~/.claude/history.jsonl | jq -r '((.timestamp / 1000) | strftime("%Y-%m-%d %H:%M")) as $time | "\($time) | \(.sessionId[0:8])... | \(.display[0:80])"' | tac
}

cct() {
    local session_id=${1:-""}
    if [ -n "$session_id" ]; then
        tmux new-session -s claude "claude --dangerously-skip-permissions -r $session_id"
    else
        tmux new-session -s claude "claude --dangerously-skip-permissions"
    fi
}

ccra() {
    echo "🔄 Resuming all rate-limited Claude sessions..."
    if [ ! -f ~/.claude/history.jsonl ]; then
        echo "⚠️  No history found"
        return 1
    fi

    grep -i "rate limit" ~/.claude/history.jsonl | tail -10 | while read -r line; do
        session_id=$(echo "$line" | jq -r '.sessionId')
        echo "📝 Resuming session: $session_id"
        claude --dangerously-skip-permissions -r "$session_id" "continue from where we left off" || true
        sleep 2
    done
    echo "✅ All rate-limited sessions resumed!"
}

export -f ccr ccr-list ccr-find cct ccra
CLAUDE_HELPERS_EOF

chmod +x ~/scripts/claude-resume-helpers.sh

# ========================================
# INSTALL DOTFILES (if available)
# ========================================

if [ -d /mnt/dotfiles ] && [ "$(ls -A /mnt/dotfiles)" ]; then
  echo "📦 Installing dotfiles from /mnt/dotfiles..."
  cd /mnt/dotfiles

  if [ -f install.sh ] && [ -x install.sh ]; then
    echo "🔧 Running dotfiles install script..."
    bash install.sh
  else
    echo "🔗 Creating symlinks for dotfiles..."
    for file in .*; do
      if [ -f "$file" ] && [ "$(basename "$file")" != "." ] && [ "$(basename "$file")" != ".." ] && [ "$(basename "$file")" != ".git" ]; then
        ln -sf "/mnt/dotfiles/$file" ~/
        echo "✓ Linked $(basename "$file")"
      fi
    done
  fi

  echo "✅ Dotfiles installed!"
else
  echo "ℹ️  No dotfiles found at /mnt/dotfiles (this is normal)"
fi

# ========================================
# GIT CONFIGURATION
# ========================================

# Configure Git with GitHub authenticated user (if available)
if command -v gh >/dev/null 2>&1 && [ -n "$GITHUB_TOKEN" ]; then
  echo "⚙️ Configuring Git with GitHub authenticated user..."
  GH_USER=$(gh api user --jq '.name // .login' 2>/dev/null || echo "")
  GH_EMAIL=$(gh api user --jq '.email // ""' 2>/dev/null || echo "")

  if [ -n "$GH_USER" ]; then
    git config --global user.name "$GH_USER"
    echo "✓ Git user.name set to: $GH_USER (from GitHub)"
  fi

  if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
    git config --global user.email "$GH_EMAIL"
    echo "✓ Git user.email set to: $GH_EMAIL (from GitHub)"
  fi
fi

# ========================================
# SUMMARY
# ========================================

echo ""
echo "✅ DevContainer Post-Create Setup Complete!"
echo "=================================="
echo ""
echo "📊 Installed Tools:"
echo "  - PM2: $(pm2 --version 2>/dev/null || echo 'not installed')"
echo "  - Node.js: $(node --version)"
echo "  - npm: $(npm --version)"
echo "  - Docker: $(docker --version 2>/dev/null || echo 'not available yet (Envbox will provide)')"
echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || echo 'not installed')"
echo "  - GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not installed')"
echo ""
echo "🎯 Next: post-start.sh will launch PM2 services..."
echo ""

exit 0
