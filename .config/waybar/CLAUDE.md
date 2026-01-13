# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Waybar configuration for Hyprland on Arch Linux. Waybar is a customizable status bar.

## File Structure

- `config.jsonc` - Main configuration defining modules and their behavior
- `style.css` - Primary stylesheet importing the color theme
- `macchiato.css` / `mocha.css` - Catppuccin color palette definitions (currently using mocha)
- `scripts/cpu-gpu-toggle.sh` - Toggles between CPU and GPU stats display

## Architecture

**Theme System**: Uses Catppuccin color palettes via CSS `@define-color` variables. To switch themes, change the `@import` in `style.css` from `mocha.css` to `macchiato.css`.

**Module Layout**:
- Left: Arch launcher, CPU/GPU stats, memory, weather (Edmonton), window title
- Center: Hyprland workspaces (Japanese numerals)
- Right: Network, battery, backlight, audio, clock, VPN status, tray, power menu

**Custom Modules**:
- `custom/cpu-gpu`: Shows CPU and GPU usage/temperature side by side (reads from /sys live)
- `custom/weather`: Shows current temperature in Edmonton, AB via wttr.in (updates every 10 min)

## Testing Changes

Reload Waybar after editing:
```bash
killall waybar && waybar &
```

Or with Hyprland:
```bash
hyprctl dispatch exec "killall waybar; waybar"
```

## Key Dependencies

- Hack Nerd Font (for icons)
- brightnessctl (backlight control)
- pavucontrol (audio settings)
- nmtui/nmcli (network management)
- rofi (application launcher)
