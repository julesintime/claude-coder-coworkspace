# Dotfiles Setup for Unified DevOps Template

This guide explains how to set up your dotfiles repository to work with the Unified DevOps Coder template.

## Prerequisites

- A GitHub repository for dotfiles (e.g., `https://github.com/xoojulian/coder-dotfiles`)
- GitHub external authentication configured in Coder (or use a personal access token)

## What are Dotfiles?

Dotfiles are configuration files that customize your development environment. They're called "dotfiles" because they typically start with a dot (`.`) and are hidden by default in Unix-like systems.

## Recommended Dotfiles for This Template

### 1. `.tmux.conf` - Tmux Configuration

Create a file named `.tmux.conf` in your dotfiles repository with the following content:

```bash
# Enable mouse support for tmux
# Allows scrolling, selecting panes, and resizing with the mouse
set -g mouse on

# Increase scrollback buffer size
set -g history-limit 10000

# Enable 256 color support
set -g default-terminal "screen-256color"

# Set prefix to Ctrl+a (more ergonomic than default Ctrl+b)
# Uncomment the following lines if you prefer Ctrl+a
# unbind C-b
# set -g prefix C-a
# bind C-a send-prefix

# Start window numbering at 1 instead of 0
set -g base-index 1
set -g pane-base-index 1

# Automatically renumber windows when one is closed
set -g renumber-windows on

# Enable activity alerts
setw -g monitor-activity on
set -g visual-activity on

# Easier window splitting with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Easier pane navigation with vim keys
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Reload tmux config with prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
```

### 2. `.bashrc` Additions (Optional)

If you want to add custom bash aliases beyond what the template provides, create a `.bashrc` file:

```bash
# Custom aliases beyond template defaults

# Tmux shortcuts
alias ta='tmux attach'
alias tls='tmux ls'
alias tnew='tmux new -s'

# Git shortcuts
alias gst='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gpl='git pull'

# Docker shortcuts beyond template
alias dlogs='docker logs -f'
alias dexec='docker exec -it'

# Kubernetes shortcuts beyond template
alias kl='kubectl logs -f'
alias kx='kubectl exec -it'
alias kctx='kubectl config use-context'

# Add your custom aliases here
```

### 3. `.gitconfig` (Optional)

For git-specific configurations:

```ini
[core]
    editor = vim
    autocrlf = input

[pull]
    rebase = false

[init]
    defaultBranch = main

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all --decorate
```

## Setting Up Your Dotfiles Repository

### Option 1: Using coder ssh (After Workspace Bootstrap)

1. **Create the workspace** with the Unified DevOps template

2. **SSH into your workspace**:
   ```bash
   coder ssh <workspace-name>
   ```

3. **Clone your dotfiles repo**:
   ```bash
   cd ~
   git clone https://github.com/xoojulian/coder-dotfiles.git dotfiles-temp
   ```

4. **Create the tmux configuration**:
   ```bash
   cd dotfiles-temp
   cat > .tmux.conf << 'EOF'
# Enable mouse support
set -g mouse on

# Increase scrollback buffer
set -g history-limit 10000

# Enable 256 color support
set -g default-terminal "screen-256color"

# Start window numbering at 1
set -g base-index 1
set -g pane-base-index 1

# Automatically renumber windows
set -g renumber-windows on

# Easier window splitting
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Reload config with prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
EOF
   ```

5. **Commit and push**:
   ```bash
   git add .tmux.conf
   git commit -m "Add tmux configuration with mouse support"
   git push
   ```

### Option 2: Using GitHub Web Interface

1. Go to `https://github.com/xoojulian/coder-dotfiles`
2. Click "Add file" → "Create new file"
3. Name it `.tmux.conf`
4. Paste the configuration content from above
5. Commit the changes

### Option 3: Clone Locally and Push

```bash
# On your local machine
git clone https://github.com/xoojulian/coder-dotfiles.git
cd coder-dotfiles

# Create .tmux.conf
cat > .tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 10000
# ... rest of the config ...
EOF

# Commit and push
git add .tmux.conf
git commit -m "Add tmux configuration"
git push
```

## Configuring the Workspace to Use Dotfiles

When creating a new workspace with the Unified DevOps template:

1. Fill in the "Dotfiles Repository URL (Optional)" parameter:
   ```
   https://github.com/xoojulian/coder-dotfiles
   ```

2. If using GitHub external authentication (recommended):
   - No additional token needed
   - The template automatically uses your authenticated GitHub session

3. If NOT using external auth:
   - Provide a GitHub Personal Access Token in the "GitHub Personal Access Token" parameter
   - Or make your dotfiles repo public

## How Dotfiles Are Applied

The Unified DevOps template uses the official Coder dotfiles module:

1. During workspace startup, the module clones your dotfiles repository
2. It creates symlinks from `~/.dotfiles/` to `~/` for all dotfiles
3. If there's a `install.sh` script, it will be executed
4. Your configurations are applied before AI agents and tools start

## Testing Your Dotfiles

After your workspace starts with dotfiles configured:

1. **Verify tmux config**:
   ```bash
   # Start tmux
   tmux

   # Check if mouse mode is enabled
   tmux show-options -g | grep mouse
   # Should show: mouse on
   ```

2. **Test mouse functionality**:
   - Try scrolling with your mouse wheel
   - Click on different panes to switch between them
   - Try resizing panes by dragging borders

3. **Verify other dotfiles**:
   ```bash
   # Check symlinks
   ls -la ~ | grep "\->"

   # Verify .bashrc additions
   source ~/.bashrc
   ```

## Troubleshooting

### Dotfiles Not Applied

1. Check the workspace build logs for errors
2. Verify the repository URL is correct
3. Ensure GitHub authentication is working:
   ```bash
   gh auth status
   ```

### Tmux Mouse Not Working

1. Check tmux version:
   ```bash
   tmux -V
   # Should be 2.1 or higher
   ```

2. Reload tmux config manually:
   ```bash
   tmux source-file ~/.tmux.conf
   ```

3. Verify the config file exists:
   ```bash
   cat ~/.tmux.conf | grep mouse
   ```

## Advanced: Install Script

For more complex setup, create an `install.sh` in your dotfiles repo:

```bash
#!/bin/bash
# install.sh - Advanced dotfiles installation

set -e

echo "🔧 Running dotfiles installation script..."

# Create symlinks for all dotfiles
for file in .*; do
    if [ -f "$file" ] && [ "$file" != "." ] && [ "$file" != ".." ] && [ "$file" != ".git" ]; then
        ln -sf "$(pwd)/$file" "$HOME/$file"
        echo "✓ Linked $file"
    fi
done

# Source bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
    echo "✓ Sourced .bashrc"
fi

# Reload tmux config for all running sessions
if command -v tmux &> /dev/null; then
    tmux source-file ~/.tmux.conf 2>/dev/null || true
    echo "✓ Reloaded tmux config"
fi

echo "✅ Dotfiles installation complete!"
```

Make it executable:
```bash
chmod +x install.sh
git add install.sh
git commit -m "Add installation script"
git push
```

## References

- [Coder Dotfiles Module](https://registry.coder.com/modules/dotfiles)
- [GitHub Dotfiles Guide](https://dotfiles.github.io/)
- [Tmux Documentation](https://github.com/tmux/tmux/wiki)
- [Example Dotfiles Repos](https://github.com/webpro/awesome-dotfiles)

## Next Steps

Once your dotfiles are set up:

1. Create a new workspace with the dotfiles URL configured
2. Verify tmux mouse support works
3. Customize the configurations to your preferences
4. Add more dotfiles as needed (vim, git, etc.)

Happy coding! 🚀
