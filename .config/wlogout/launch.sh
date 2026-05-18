#!/usr/bin/env bash
set -euo pipefail

if ! command -v wlogout >/dev/null 2>&1; then
    notify-send "wlogout is not installed" "Install it with: paru -S wlogout" 2>/dev/null || \
        printf '%s\n' "wlogout is not installed. Install it with: paru -S wlogout" >&2
    exit 1
fi

exec wlogout \
    --protocol layer-shell \
    --buttons-per-row 5 \
    --column-spacing 16 \
    --row-spacing 16 \
    --margin-top 300 \
    --margin-bottom 300 \
    --margin-left 180 \
    --margin-right 180
