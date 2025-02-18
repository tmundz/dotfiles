# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

# Lines configured by zsh-newuser-install
#
# Zinit installation
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d $ZINIT_HOME ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi 

source "${ZINIT_HOME}/zinit.zsh"

# Zinit plugins
source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

zinit ice depth=1; 
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light Aloxaf/fzf-tab


# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found


# Load completions
autoload -U compinit && compinit
zinit cdreplay -q


eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/config.json)"

## Keybindings
bindkey -e
bindkey '^[j' history-search-forward   # Alt + j → next command (down)
bindkey '^[k' history-search-backward  # Alt + k → previous command (up)
bindkey '^[w' kill-region


HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
unsetopt beep

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'



export EDITOR=nvim
export VISUAL=nvim

#custom alias
alias ls='ls -CF --color=auto'
alias ll='ls -lisa --color=auto'
alias free='free -mt'
alias mkdir='mkdir -pv'
alias wget='wget -c'
alias grep='grep --color=auto'
alias source-zsh='source ~/.zshrc'


vm_mount() {
    if ! mountpoint -q ~/vm; then
        sshfs user@sus-vm:/home/user ~/vm -o follow_symlinks,default_permissions
   fi
}
vm_unmount() {
  echo "Unmounting sshfs..."
  fusermount -u ~/vm
}


alias ssh-vm="vm_mount && waypipe ssh user@sus-vm; vm_unmount"

#GIT PROMPTS
autoload -Uz vcs_info  # Where do these come from? What else is there?
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
zstyle ':vcs_info:git:*' formats '%F{blue}(%b)%f'
zstyle ':vcs_info:*' enable git
setopt prompt_subst





#prompts
#prompts
#PROMPT='%F{magenta}%n%F{blue}@%F{magenta}%m:%F{cyan}%~%f$vcs_info_msg_0_%F{magenta}
#> %f'

#PROMPT='%F{magenta}%~%f$vcs_info_msg_0_%F{cyan}
#> %f'
bindkey "^[[3~" delete-char
#fastfetch
#export JAVA_HOME=$HOME/jdk15 example for dev 
# End of lines configured by zsh-newuser-install
source $HOME/.cargo/env

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
eval "$(fzf --zsh)"
