#!/bin/bash
set -e

echo "🚀 DevContainer Post-Start Setup..."
echo "=================================="

# ========================================
# VERIFY PM2 IS INSTALLED
# ========================================

if ! command -v pm2 >/dev/null 2>&1; then
  echo "❌ PM2 not found! This should not happen."
  echo "   post-create.sh should have installed PM2."
  echo "   Attempting emergency install..."
  sudo npm install -g pm2 --force
fi

# ========================================
# STOP ALL PM2 PROCESSES (Clean Slate)
# ========================================

echo "🛑 Stopping all PM2 processes..."
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true

# Give PM2 a moment to clean up
sleep 1

# ========================================
# START CLAUDE CODE UI
# ========================================

echo "🎨 Starting Claude Code UI on port 38401..."

PORT=38401 \
DATABASE_PATH=~/.claude-code-ui/database.json \
pm2 start claude-code-ui \
  --name claude-code-ui \
  --time \
  --no-autorestart \
  -- \
  || echo "⚠️ Claude Code UI failed to start"

# ========================================
# START VIBE KANBAN
# ========================================

echo "📋 Starting Vibe Kanban on port 38402..."

BACKEND_PORT=38402 \
HOST=0.0.0.0 \
pm2 start "npx vibe-kanban" \
  --name vibe-kanban \
  --time \
  --no-autorestart \
  || echo "⚠️ Vibe Kanban failed to start"

# ========================================
# SAVE PM2 PROCESS LIST
# ========================================

echo "💾 Saving PM2 process list..."
pm2 save --force

# ========================================
# DISPLAY PM2 STATUS
# ========================================

echo ""
echo "✅ DevContainer Post-Start Setup Complete!"
echo "=================================="
echo ""
echo "📊 PM2 Process Status:"
pm2 list

echo ""
echo "🔍 Service Details:"
echo "  - Claude Code UI: http://localhost:38401"
echo "  - Vibe Kanban:    http://localhost:38402"
echo ""
echo "💡 PM2 Commands:"
echo "  - pm2 list          # Show all processes"
echo "  - pm2 logs          # Show all logs"
echo "  - pm2 monit         # Real-time monitoring"
echo "  - pm2 restart all   # Restart all services"
echo "  - pm2 stop all      # Stop all services"
echo ""
echo "🚀 Workspace is ready!"
echo ""

exit 0
