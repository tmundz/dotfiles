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
export PATH="$PATH:$(pwd)/bin"

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
# Catppuccin Mocha — colour palette (mauve/pink focus)
# ============================================================================
# pink=#f5c2e7  mauve=#cba6f7  flamingo=#f2cdcd  lavender=#b4befe
# green=#a6e3a1  peach=#fab387  red=#f38ba8  overlay=#6c7086  surface=#585b70

# ============================================================================
# Git VCS Info (branch + staged/unstaged indicators)
# ============================================================================
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
zstyle ':vcs_info:*'     enable git
zstyle ':vcs_info:*'     check-for-changes true
zstyle ':vcs_info:git:*' stagedstr    '%F{#a6e3a1}●%f'          # green dot  = staged
zstyle ':vcs_info:git:*' unstagedstr  '%F{#fab387}●%f'          # peach dot  = unstaged
zstyle ':vcs_info:git:*' formats      '%F{#cba6f7}(%b)%f%c%u'  # (branch)●●
zstyle ':vcs_info:git:*' actionformats '%F{#f38ba8}(%b|%a)%f%c%u'  # (branch|MERGE)
setopt prompt_subst

# ============================================================================
# Prompt — Catppuccin Mocha · mauve/pink
# Line 1:  ┌─[user@host]─[path] (branch)●
# Line 2:  └─❯
# RPROMPT: ✓/✗ exit-code  HH:MM:SS
# ============================================================================
PROMPT='%F{#cba6f7}┌─[%f%F{#f5c2e7}%n%f%F{#6c7086}@%f%F{#f2cdcd}%m%f%F{#cba6f7}]─[%f%F{#b4befe}%(4~|…/%3~|%~)%f%F{#cba6f7}]%f ${vcs_info_msg_0_}
%F{#cba6f7}└─%f%F{#f5c2e7}❯%f '

RPROMPT='%(?.%F{#a6e3a1}✓%f.%F{#f38ba8}✗%? %f)  %F{#585b70}%*%f'

# ============================================================================
# Autosuggestions — muted surface colour so it doesn't clash
# ============================================================================
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#585b70'

# ============================================================================
# FZF — Catppuccin Mocha palette
# ============================================================================
export FZF_DEFAULT_OPTS="\
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5c2e7,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5c2e7 \
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#f5c2e7,hl+:#f38ba8 \
  --color=border:#cba6f7 \
  --border=rounded --prompt='❯ ' --pointer='▸' --marker='✓'"

if command -v fzf &> /dev/null; then
    eval "$(fzf --zsh)"
fi

# ============================================================================
# Cargo environment
# ============================================================================
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi
export PATH="$PATH:/home/caphe/iothackbot/bin"
