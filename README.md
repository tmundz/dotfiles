# dotfile-2

Clean public dotfiles for a Hyprland Wayland desktop.

This repo intentionally contains only functional configuration: window manager,
bar, launcher, terminal, editor, shell, notifications, GTK dark-mode settings,
tmux, wlogout, and package manifests. It excludes personal files, browser/app
profiles, credentials, histories, caches, and agent state.

## Install

Review the files first, then run:

```sh
./install.sh
```

The installer creates timestamped backups for existing files before symlinking.
It opens an interactive menu for a recommended desktop setup, a full setup with
hacking tools, package-only installs, a missing-essentials repair path, dotfile
linking, and Hyprland monitor configuration. It can bootstrap `paru` from the
AUR, install Python CLI tools through `pipx`, install global npm tools, set zsh
as the login shell, enable Docker, add the user to available desktop/dev/admin
groups, and write a single-monitor or two-monitor Hyprland layout.
The single-monitor profile targets `eDP-1`; the two-monitor profile targets
`HDMI-A-1` and `HDMI-A-2`. The monitor menu can also use live `hyprctl`
detection or custom output names when the machine differs.

Non-interactive shortcuts:

```sh
./install.sh --check
./install.sh --fix-missing
./install.sh --desktop
./install.sh --full
```

## Package Manifests

- `packages/pacman-essential.txt` is the clean restore set used by `install.sh`.
- `packages/aur-essential.txt` is the clean AUR restore set used by `install.sh`.
- `packages/pipx.txt` is for Python CLI tools installed through `pipx`.
- `packages/npm.txt` is for global npm CLI tools installed through `npm`.
- `packages/pacman-hacking.txt` is the optional repo security/mobile/firmware tool set.
- `packages/aur-hacking.txt` is the optional AUR security/mobile/firmware tool set.
- `packages/pipx-hacking.txt` is the optional Python security/mobile tool set.
- `packages/pacman-explicit.txt` contains explicit packages from this machine.
- `packages/aur-explicit.txt` contains foreign/AUR packages from this machine.

The explicit manifests are references, not installer inputs.

## Codex

Only `.codex/config.toml` is included, and it is sanitized. Auth,
history, logs, sqlite state, shell snapshots, model caches, and trusted project
paths are intentionally excluded.

## Not Included

- `~/.ssh`, `~/.gnupg`, `~/.pki`
- browser and Electron app profiles
- `~/.claude`, full `~/.codex`, `~/.gemini`
- histories, caches, package build output
- personal documents, project directories, downloads
- personal documents, downloads, and project directories

The Hyprland config includes the copied `~/.config/hypr/images` wallpaper folder
so wallpaper and lockscreen references continue to work.
