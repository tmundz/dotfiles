# ============================================================================
# Clean .zshrc - Simplified and Fixed
# ============================================================================

# Zinit installation (plugin manager)
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d $ZINIT_HOME ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi 
source "${ZINIT_HOME}/zinit.zsh"

# ============================================================================
# Zinit Plugins
# ============================================================================
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light Aloxaf/fzf-tab

# Oh-My-Zsh snippets (lightweight, only what you need)
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::command-not-found
zinit snippet OMZP::colored-man-pages

# Load completions
autoload -U compinit && compinit
zinit cdreplay -q

# ============================================================================
# History Configuration
# ============================================================================
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
unsetopt beep

# ============================================================================
# Keybindings
# ============================================================================
bindkey -e
bindkey '^[j' history-search-forward   # Alt + j → next command
bindkey '^[k' history-search-backward  # Alt + k → previous command
bindkey '^[w' kill-region
bindkey "^[[3~" delete-char

# ============================================================================
# Completion Styling
# ============================================================================
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# ============================================================================
# Environment Variables
# ============================================================================
export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ============================================================================
# Aliases
# ============================================================================
alias ls='ls -CF --color=auto'
alias ll='ls -lah --color=auto'
alias free='free -mt'
alias mkdir='mkdir -pv'
alias wget='wget -c'
alias grep='grep --color=auto'
alias vim='nvim'
alias v='nvim'

# Quick reload
alias src='source ~/.zshrc && echo "zsh reloaded!"'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# ============================================================================
# Git VCS Info (for prompt)
# ============================================================================
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
zstyle ':vcs_info:git:*' formats '%F{blue}(%b)%f'
zstyle ':vcs_info:*' enable git
setopt prompt_subst

# ============================================================================
# Two-Line Prompt (shows last 2 dirs or ~)
# ============================================================================
PROMPT='%F{cyan}┌─[%f%F{magenta}%n@%m%f%F{cyan}]%f %F{blue}%(3~|.../%2~|%~) %f${vcs_info_msg_0_}
%F{cyan}└>%f '

# ============================================================================
# FZF Integration
# ============================================================================
if command -v fzf &> /dev/null; then
    eval "$(fzf --zsh)"
fi

# ============================================================================
# Cargo environment
# ============================================================================
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi
