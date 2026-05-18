#!/bin/bash

## Set GTK Themes, Icons, Cursor and Fonts

THEME='Catppuccin-Mocha-Standard-Mauve-Dark'
ICONS='Colloid-grey-dark'
FONT='Satoshi Variable Regular 11'
CURSOR='Catppuccin-Mocha-Dark 24'

SCHEMA='gsettings set org.gnome.desktop.interface'

apply_themes() {
	${SCHEMA} gtk-theme "$THEME"
	${SCHEMA} color-scheme 'prefer-dark'
	${SCHEMA} icon-theme "$ICONS"
	${SCHEMA} cursor-theme "$CURSOR"
	#${SCHEMA} font-name "$FONT"
}

${SCHEMA} color-scheme 'prefer-dark'
# apply_themes
# hyprctl setcursor $CURSOR
if [ -f "$HOME/Music/sounds/startup.wav" ]; then
	paplay "$HOME/Music/sounds/startup.wav"
fi
