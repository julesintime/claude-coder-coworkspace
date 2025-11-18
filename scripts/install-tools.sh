#!/bin/bash
# Additional Tools Installation Script
# Installs optional development tools not included in the base setup

set -e

echo "🔧 Installing additional development tools..."

# ========================================
# Homebrew (Linuxbrew) - Optional
# ========================================
install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "📦 Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    echo "✓ Homebrew installed"
  else
    echo "✓ Homebrew already installed"
  fi
}

# ========================================
# Zsh and Oh My Zsh - Optional
# ========================================
install_zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "📦 Installing Zsh..."
    sudo apt-get install -y zsh

    # Install Oh My Zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    echo "✓ Zsh and Oh My Zsh installed"
    echo "ℹ️ Run 'chsh -s $(which zsh)' to set Zsh as default shell"
  else
    echo "✓ Zsh already installed"
  fi
}

# ========================================
# Development Tools
# ========================================
install_dev_tools() {
  echo "📦 Installing development tools..."

  sudo apt-get update
  sudo apt-get install -y \
    htop \
    tree \
    jq \
    ripgrep \
    fd-find \
    bat \
    fzf \
    ncdu \
    httpie \
    2>/dev/null || true

  echo "✓ Development tools installed"
}

# ========================================
# Docker Compose Standalone
# ========================================
install_docker_compose() {
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo "📦 Installing Docker Compose..."

    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo "✓ Docker Compose installed"
  else
    echo "✓ Docker Compose already installed"
  fi
}

# ========================================
# Kubernetes Tools
# ========================================
install_k8s_tools() {
  echo "📦 Installing Kubernetes tools..."

  # Helm
  if ! command -v helm >/dev/null 2>&1; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✓ Helm installed"
  fi

  # k9s
  if ! command -v k9s >/dev/null 2>&1; then
    curl -sS https://webinstall.dev/k9s | bash
    echo "✓ k9s installed"
  fi

  # kubectx and kubens
  if ! command -v kubectx >/dev/null 2>&1; then
    sudo apt-get install -y kubectx 2>/dev/null || {
      wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /tmp/kubectx
      wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens -O /tmp/kubens
      sudo install -m 755 /tmp/kubectx /usr/local/bin/kubectx
      sudo install -m 755 /tmp/kubens /usr/local/bin/kubens
      rm /tmp/kubectx /tmp/kubens
    }
    echo "✓ kubectx and kubens installed"
  fi
}

# ========================================
# Programming Language Tools
# ========================================
install_language_tools() {
  echo "📦 Installing language-specific tools..."

  # Node Version Manager (nvm)
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    echo "✓ nvm installed"
  fi

  # Python Poetry
  if ! command -v poetry >/dev/null 2>&1; then
    curl -sSL https://install.python-poetry.org | python3 -
    echo "✓ Poetry installed"
  fi

  # Rust/Cargo
  if ! command -v cargo >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo "✓ Rust installed"
  fi
}

# ========================================
# Main Menu
# ========================================
echo ""
echo "Select tools to install:"
echo "1) All tools"
echo "2) Development tools (htop, tree, jq, etc.)"
echo "3) Kubernetes tools (helm, k9s, kubectx)"
echo "4) Docker Compose"
echo "5) Language tools (nvm, poetry, rust)"
echo "6) Zsh and Oh My Zsh"
echo "7) Homebrew"
echo "0) Exit"
echo ""

read -p "Enter choice (or press Enter to skip): " choice

case $choice in
  1)
    install_dev_tools
    install_k8s_tools
    install_docker_compose
    install_language_tools
    ;;
  2)
    install_dev_tools
    ;;
  3)
    install_k8s_tools
    ;;
  4)
    install_docker_compose
    ;;
  5)
    install_language_tools
    ;;
  6)
    install_zsh
    ;;
  7)
    install_homebrew
    ;;
  0|"")
    echo "Skipping additional tools installation"
    exit 0
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
echo "✅ Additional tools installation complete!"
echo "ℹ️ You may need to restart your shell for some changes to take effect"
