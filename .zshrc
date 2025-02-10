# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=1000
unsetopt beep

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
    if ! mountpoint -q ~/vm_box; then
        sshfs user@vm-hostname:/ ~/athena
    fi
}

alias ssh-vm="vm_mount && ssh -Y user@vm-hostname"

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

PROMPT='%F{magenta}%~%f$vcs_info_msg_0_%F{cyan}
> %f'
bindkey "^[[3~" delete-char
fastfetch
#export JAVA_HOME=$HOME/jdk15 example for dev 
# End of lines configured by zsh-newuser-install
source $HOME/.cargo/env

