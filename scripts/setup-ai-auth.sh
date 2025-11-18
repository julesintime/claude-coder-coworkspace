#!/bin/bash
# AI Tools and Authentication Setup Script
# This script configures all AI CLI tools and authentication for the unified workspace

set -e

echo "🤖 Setting up AI tools and authentication..."

# ========================================
# GitHub CLI Authentication
# ========================================
if [ -n "$GITHUB_TOKEN" ] && command -v gh >/dev/null 2>&1; then
  echo "🔐 Configuring GitHub CLI authentication..."

  # Configure gh CLI with token
  echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || true

  # Verify authentication
  if gh auth status >/dev/null 2>&1; then
    echo "✓ GitHub CLI authenticated successfully"

    # Enable Copilot if available
    if gh copilot --version >/dev/null 2>&1; then
      echo "✓ GitHub Copilot CLI is available"
    else
      echo "ℹ️ GitHub Copilot CLI not available (may require subscription)"
    fi
  else
    echo "⚠️ GitHub CLI authentication failed"
  fi
else
  echo "ℹ️ Skipping GitHub CLI setup (token not provided or gh not installed)"
fi

# ========================================
# Gitea CLI Authentication
# ========================================
if [ -n "$GITEA_URL" ] && [ -n "$GITEA_TOKEN" ] && command -v tea >/dev/null 2>&1; then
  echo "🔐 Configuring Gitea CLI authentication..."

  # Create tea config directory
  mkdir -p ~/.config/tea

  # Add Gitea login
  tea login add \
    --name "default" \
    --url "$GITEA_URL" \
    --token "$GITEA_TOKEN" \
    2>/dev/null || true

  # Verify authentication
  if tea login list >/dev/null 2>&1; then
    echo "✓ Gitea CLI authenticated successfully"
  else
    echo "⚠️ Gitea CLI authentication failed"
  fi
else
  echo "ℹ️ Skipping Gitea CLI setup (credentials not provided or tea not installed)"
fi

# ========================================
# Claude Code CLI Authentication
# ========================================
if command -v claude >/dev/null 2>&1; then
  echo "🔐 Configuring Claude Code CLI..."

  # Claude uses environment variables (CLAUDE_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
  # These are set by the Coder template as coder_env resources

  if [ -n "$CLAUDE_API_KEY" ]; then
    echo "✓ Claude API key configured"
  elif [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    echo "✓ Claude OAuth token configured"
  else
    echo "⚠️ No Claude authentication found (set CLAUDE_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)"
  fi

  # Verify Claude CLI works
  if claude --version >/dev/null 2>&1; then
    echo "✓ Claude Code CLI is ready"
  else
    echo "⚠️ Claude Code CLI verification failed"
  fi
else
  echo "ℹ️ Claude Code CLI not installed"
fi

# ========================================
# Gemini CLI Authentication
# ========================================
if command -v gemini >/dev/null 2>&1; then
  echo "🔐 Configuring Gemini CLI..."

  if [ -n "$GOOGLE_AI_API_KEY" ]; then
    echo "✓ Gemini API key configured"

    # Verify Gemini CLI
    if gemini --version >/dev/null 2>&1; then
      echo "✓ Gemini CLI is ready"
    fi
  else
    echo "⚠️ No Gemini API key found (set GOOGLE_AI_API_KEY)"
  fi
else
  echo "ℹ️ Gemini CLI not installed"
fi

# ========================================
# Git Configuration
# ========================================
echo "⚙️ Configuring Git..."

# Git is already configured by Coder agent env vars
# But we can verify the configuration
if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
  echo "✓ Git user configured: $(git config user.name) <$(git config user.email)>"
else
  echo "⚠️ Git user not configured"
fi

# ========================================
# Kubectl Configuration
# ========================================
if command -v kubectl >/dev/null 2>&1; then
  echo "⚙️ Configuring kubectl..."

  # Check if kubeconfig exists or we're in a cluster
  if kubectl version --client >/dev/null 2>&1; then
    echo "✓ kubectl is ready"

    # If we're in a Kubernetes pod, we should have access to the cluster
    if kubectl cluster-info >/dev/null 2>&1; then
      echo "✓ Kubernetes cluster accessible"
    else
      echo "ℹ️ Kubernetes cluster not accessible (may need kubeconfig)"
    fi
  fi
else
  echo "ℹ️ kubectl not installed"
fi

# ========================================
# MCP Servers Configuration
# ========================================
echo "⚙️ Configuring MCP servers..."

# Create MCP config directory
mkdir -p ~/.config/coder/mcp

# Create default MCP configuration
cat > ~/.config/coder/mcp/config.json << 'EOF'
{
  "mcpServers": {
    "desktop-commander": {
      "command": "desktop-commander",
      "args": [],
      "enabled": true
    }
  }
}
EOF

echo "✓ MCP configuration created"

# ========================================
# Summary
# ========================================
echo ""
echo "✅ AI tools and authentication setup complete!"
echo ""
echo "📊 Status Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check each tool
command -v claude >/dev/null 2>&1 && echo "✓ Claude Code CLI: Installed" || echo "✗ Claude Code CLI: Not installed"
command -v gemini >/dev/null 2>&1 && echo "✓ Gemini CLI: Installed" || echo "✗ Gemini CLI: Not installed"
command -v gh >/dev/null 2>&1 && echo "✓ GitHub CLI: Installed" || echo "✗ GitHub CLI: Not installed"
command -v tea >/dev/null 2>&1 && echo "✓ Gitea CLI: Installed" || echo "✗ Gitea CLI: Not installed"
command -v kubectl >/dev/null 2>&1 && echo "✓ kubectl: Installed" || echo "✗ kubectl: Not installed"
command -v docker >/dev/null 2>&1 && echo "✓ Docker: Available" || echo "✗ Docker: Not available"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Quick Start:"
echo "  • Claude Code: Run 'cc-c' or 'claude'"
echo "  • Gemini: Run 'gemini' or 'gemini-chat'"
echo "  • GitHub: Run 'gh' for GitHub operations"
echo "  • Docker: Run 'docker ps' to verify"
echo "  • Kubernetes: Run 'kubectl get nodes'"
echo ""
