# ~/.bashrc: executed by bash(1) for non-login shells.
# See /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ========================================
# HISTORY CONFIGURATION
# ========================================

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# ========================================
# SHELL OPTIONS
# ========================================

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ========================================
# PROMPT CONFIGURATION (WITH COLORS)
# ========================================

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    # Colored prompt with user@host:path$ format
    # Green for regular user, red for root
    if [ "$USER" = "root" ]; then
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    else
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    fi
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# ========================================
# COLOR SUPPORT FOR LS AND GREP
# ========================================

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# ========================================
# DEFAULT ALIASES
# ========================================

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# ========================================
# BASH COMPLETION
# ========================================

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ========================================
# CUSTOM ALIASES FROM CODER TEMPLATE
# ========================================

# Claude Session Management helpers
if [ -f ~/scripts/claude-resume-helpers.sh ]; then
    source ~/scripts/claude-resume-helpers.sh
fi

# AI Tools
alias cc-c='claude'
alias cc='claude'
alias gemini-chat='gemini'
alias copilot='gh copilot'

# Docker shortcuts
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dclean='docker system prune -af'
alias dlogs='docker logs -f'
alias dexec='docker exec -it'

# Kubernetes shortcuts
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'
alias kl='kubectl logs -f'
alias kx='kubectl exec -it'
alias kctx='kubectl config use-context'

# Git shortcuts
alias gs='git status'
alias gst='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gpl='git pull'

# GitHub CLI
alias ghpr='gh pr'
alias ghissue='gh issue'

# AI UI Tools (PM2 managed)
alias claude-code-ui-logs='pm2 logs claude-code-ui'
alias vibe-logs='pm2 logs vibe-kanban'
alias ai-ui-restart='pm2 restart claude-code-ui vibe-kanban'
alias ai-ui-status='pm2 list'
alias update-ai-uis='npm update -g @siteboon/claude-code-ui vibe-kanban && pm2 restart claude-code-ui vibe-kanban'

# Tmux shortcuts
alias ta='tmux attach'
alias tls='tmux ls'
alias tnew='tmux new -s'

# Workspace info
alias workspace-info='echo "🚀 Unified DevOps Workspace"; echo "Docker: $(docker --version 2>/dev/null || echo Not available)"; echo "Kubectl: $(kubectl version --client --short 2>/dev/null || echo Not available)"; echo "Claude: $(claude --version 2>/dev/null || echo Not installed)"; echo "Gemini: $(gemini --version 2>/dev/null || echo Not installed)"'

# ========================================
# ADDITIONAL USER CUSTOMIZATIONS
# ========================================

# Source additional user-specific aliases if they exist
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Source local bashrc for machine-specific settings
if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi

# ========================================
# ENVIRONMENT VARIABLES
# ========================================

# Set default editor
export EDITOR=vim
export VISUAL=vim

# Improve Docker CLI output
export DOCKER_BUILDKIT=1

# Enable kubectl autocompletion if available
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
    complete -F __start_kubectl k  # Completion for 'k' alias
fi

# Enable gh (GitHub CLI) autocompletion if available
if command -v gh &> /dev/null; then
    eval "$(gh completion -s bash)"
fi
