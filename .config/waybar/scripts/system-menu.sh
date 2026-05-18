#!/usr/bin/env bash

set -euo pipefail

choice=$(
    printf '%s\n' \
        "󰣇 Apps" \
        "󰍉 Windows" \
        "󰅌 Clipboard" \
        "󰉋 Files" \
        "󰤨 Network" \
        "󰌾 Lock" \
        "󰐥 Power" |
        rofi -dmenu \
            -p "System" \
            -theme "$HOME/.config/rofi/launchers/type-7/style-5.rasi"
)

case "$choice" in
    "󰣇 Apps")
        "$HOME/.config/rofi/launchers/type-7/launcher.sh"
        ;;
    "󰍉 Windows")
        rofi -show window -theme "$HOME/.config/rofi/launchers/type-7/style-5.rasi"
        ;;
    "󰅌 Clipboard")
        cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy
        ;;
    "󰉋 Files")
        pcmanfm
        ;;
    "󰤨 Network")
        ghostty -e nmtui
        ;;
    "󰌾 Lock")
        hyprlock
        ;;
    "󰐥 Power")
        "$HOME/.config/rofi/powermenu/type-5/powermenu.sh"
        ;;
esac
