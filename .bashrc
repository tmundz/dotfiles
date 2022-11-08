#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
. "$HOME/.cargo/env"

neofetch

##-----------------------------------------------------
## synth-shell-prompt.sh
if [ -f /home/mundy/.config/synth-shell/synth-shell-prompt.sh ] && [ -n "$( echo $- | grep i )" ]; then
	source /home/mundy/.config/synth-shell/synth-shell-prompt.sh
fi
