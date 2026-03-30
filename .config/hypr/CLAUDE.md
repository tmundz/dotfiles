# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Hyprland configuration for Arch Linux. Hyprland is a dynamic tiling Wayland compositor.

## File Structure

- `hyprland.conf` - Main entry point, sources other configs, defines monitor setup, variables, and core settings
- `configs/startup.conf` - Exec-once commands (waybar, mako, cliphist, hypridle, swaybg)
- `configs/binds.conf` - All keybindings (SUPER as main modifier)
- `configs/windowrule.conf` - Window-specific rules
- `hyprlock.conf` - Lock screen appearance and behavior
- `hypridle.conf` - Idle timeouts (lock at 8min, suspend at ~11min)
- `hyprpaper.conf` - Wallpaper configuration
- `images/` - Wallpaper collection
- `scripts/` - Helper scripts for volume, brightness, GTK themes, etc.

## Architecture

**Config Sourcing**: `hyprland.conf` sources `configs/startup.conf` first, then `configs/binds.conf` and `configs/windowrule.conf` at the end.

**Layout**: Uses master layout (not dwindle). Vim-style navigation with HJKL.

**Theme**: Catppuccin Mocha colors - active border uses mauve (`#cba6f7`) to pink (`#f5c2e7`) gradient, inactive border is base (`#1e1e2e`).

**Wallpaper**: Currently uses swaybg (set in startup.conf), hyprpaper.conf available as alternative.

**Key Programs**:
- Terminal: wezterm
- File manager: pcmanfm
- Menu: rofi (custom launcher at `~/.config/rofi/launchers/type-7/launcher.sh`)
- Power menu: rofi (custom at `~/.config/rofi/powermenu/type-5/powermenu.sh`)

## Testing Changes

Reload Hyprland config without restarting:
```bash
hyprctl reload
```

For startup apps or exec-once changes, log out and back in.

## Key Bindings Reference

- `SUPER + SHIFT + Return` - Terminal
- `SUPER + P` - App launcher
- `SUPER + SHIFT + X` - Power menu
- `SUPER + SHIFT + C` - Kill window
- `SUPER + HJKL` - Focus navigation
- `SUPER + SHIFT + HJKL` - Resize window
- `ALT + L` - Lock screen
- `ALT + CTRL + P` - Screenshot (save)
- `ALT + SHIFT + P` - Screenshot selection (clipboard)

## Dependencies

- waybar, mako (notifications), cliphist (clipboard), hypridle, hyprlock
- pactl/amixer (audio), brightnessctl (backlight)
- grim + slurp (screenshots), wl-copy (clipboard)
- rofi, pcmanfm, wezterm
