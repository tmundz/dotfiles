#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

if [ -t 1 ]; then
    bold="$(printf '\033[1m')"
    dim="$(printf '\033[2m')"
    red="$(printf '\033[31m')"
    green="$(printf '\033[32m')"
    yellow="$(printf '\033[33m')"
    blue="$(printf '\033[34m')"
    magenta="$(printf '\033[35m')"
    cyan="$(printf '\033[36m')"
    reset="$(printf '\033[0m')"
else
    bold=""
    dim=""
    red=""
    green=""
    yellow=""
    blue=""
    magenta=""
    cyan=""
    reset=""
fi

line() {
    printf '%s\n' "${dim}------------------------------------------------------------${reset}"
}

clear_screen() {
    if [ -t 1 ] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

banner() {
    clear_screen
    printf '%s\n' "${magenta}${bold}"
    printf '  caphe dotfiles installer\n'
    printf '%s\n' "${reset}${dim}  Hyprland + Wayland + terminal + editor + tools${reset}"
    line
}

section() {
    printf '\n%s%s%s\n' "$cyan" "$1" "$reset"
    line
}

info() {
    printf '%s[INFO]%s %s\n' "$blue" "$reset" "$*"
}

ok() {
    printf '%s[ OK ]%s %s\n' "$green" "$reset" "$*"
}

warn() {
    printf '%s[WARN]%s %s\n' "$yellow" "$reset" "$*" >&2
}

die() {
    printf '%s[FAIL]%s %s\n' "$red" "$reset" "$*" >&2
    exit 1
}

pause() {
    local _
    printf '\n'
    read -r -p "Press Enter to continue..." _
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    local suffix

    if [ "$default" = "y" ]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    read -r -p "$prompt $suffix " answer
    answer="${answer:-$default}"

    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

read_packages() {
    local file="$1"

    [ -f "$file" ] || return 0
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file"
}

package_list_contains() {
    local wanted="$1"
    shift
    local package

    for package in "$@"; do
        [ "$package" = "$wanted" ] && return 0
    done

    return 1
}

pacman_repo_enabled() {
    local repo="$1"

    command -v pacman-conf >/dev/null 2>&1 || return 1
    pacman-conf --repo-list 2>/dev/null | grep -Fxq "$repo"
}

enable_multilib_repo() {
    local tmp_conf

    pacman_repo_enabled "multilib" && {
        ok "pacman multilib repository is already enabled"
        return 0
    }

    [ -f /etc/pacman.conf ] || die "/etc/pacman.conf not found; cannot enable multilib for steam"

    section "Enabling pacman multilib repository"
    tmp_conf="$(mktemp)"
    awk '
        BEGIN {
            in_multilib = 0
            saw_multilib = 0
            saw_include = 0
        }
        /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ {
            print "[multilib]"
            in_multilib = 1
            saw_multilib = 1
            next
        }
        in_multilib && /^[[:space:]]*\[/ {
            if (!saw_include) {
                print "Include = /etc/pacman.d/mirrorlist"
                saw_include = 1
            }
            in_multilib = 0
        }
        in_multilib && /^[[:space:]]*#?[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist[[:space:]]*$/ {
            print "Include = /etc/pacman.d/mirrorlist"
            saw_include = 1
            next
        }
        { print }
        END {
            if (in_multilib && !saw_include) {
                print "Include = /etc/pacman.d/mirrorlist"
            }
            if (!saw_multilib) {
                print ""
                print "[multilib]"
                print "Include = /etc/pacman.d/mirrorlist"
            }
        }
    ' /etc/pacman.conf > "$tmp_conf"

    sudo install -m 644 "$tmp_conf" /etc/pacman.conf
    rm -f "$tmp_conf"
    sudo pacman -Sy
    ok "pacman multilib repository enabled"
}

print_package_count() {
    local file="$1"
    read_packages "$file" | wc -l | tr -d ' '
}

install_pacman_packages() {
    local package_file="$1"
    local label="$2"
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label pacman packages listed"
        return 0
    }

    if package_list_contains "steam" "${packages[@]}"; then
        enable_multilib_repo
    fi

    section "Installing $label pacman packages"
    sudo pacman -Syu --needed "${packages[@]}"
    ok "Installed $label pacman package set"
}

install_missing_pacman_packages() {
    local package_file="$1"
    local label="$2"
    local package
    local missing=()
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label pacman packages listed"
        return 0
    }

    for package in "${packages[@]}"; do
        pacman -Qq "$package" >/dev/null 2>&1 || missing+=("$package")
    done

    [ "${#missing[@]}" -gt 0 ] || {
        ok "No missing $label pacman packages"
        return 0
    }

    if package_list_contains "steam" "${missing[@]}"; then
        enable_multilib_repo
    fi

    section "Installing missing $label pacman packages"
    sudo pacman -Syu --needed "${missing[@]}"
    ok "Installed missing $label pacman packages"
}

bootstrap_paru() {
    if command -v paru >/dev/null 2>&1; then
        ok "paru is already installed"
        return 0
    fi

    section "Bootstrapping paru"
    info "Installing build dependencies"
    sudo pacman -S --needed git base-devel

    local build_dir
    build_dir="$(mktemp -d)"
    trap 'rm -rf "$build_dir"; trap - RETURN' RETURN

    info "Cloning paru from the AUR"
    git clone https://aur.archlinux.org/paru.git "$build_dir/paru"

    info "Building and installing paru"
    (
        cd "$build_dir/paru"
        makepkg -si
    )

    ok "paru installed"
}

install_aur_packages() {
    local package_file="$1"
    local label="$2"
    mapfile -t packages < <(read_packages "$package_file" | sed '/^paru$/d')

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label AUR packages listed"
        return 0
    }

    bootstrap_paru

    section "Installing $label AUR packages"
    for package in "${packages[@]}"; do
        printf '%s\n' "${dim}AUR: $package${reset}"
        paru -S --needed "$package" || warn "Failed to install AUR package: $package"
    done
    ok "Finished $label AUR package set"
}

install_missing_aur_packages() {
    local package_file="$1"
    local label="$2"
    local package
    local missing=()
    mapfile -t packages < <(read_packages "$package_file" | sed '/^paru$/d')

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label AUR packages listed"
        return 0
    }

    bootstrap_paru

    for package in "${packages[@]}"; do
        paru -Qq "$package" >/dev/null 2>&1 || missing+=("$package")
    done

    [ "${#missing[@]}" -gt 0 ] || {
        ok "No missing $label AUR packages"
        return 0
    }

    section "Installing missing $label AUR packages"
    for package in "${missing[@]}"; do
        printf '%s\n' "${dim}AUR: $package${reset}"
        paru -S --needed "$package" || warn "Failed to install AUR package: $package"
    done
    ok "Finished missing $label AUR packages"
}

install_pipx_packages() {
    local package_file="$1"
    local label="$2"
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label pipx packages listed"
        return 0
    }

    command -v pipx >/dev/null 2>&1 || die "pipx is not installed. Install normal pacman essentials first."

    section "Installing $label pipx tools"
    pipx ensurepath
    for package in "${packages[@]}"; do
        printf '%s\n' "${dim}pipx: $package${reset}"
        pipx install "$package" || pipx upgrade "$package" || warn "Failed to install pipx package: $package"
    done
    ok "Finished $label pipx tool set"
}

install_missing_pipx_packages() {
    local package_file="$1"
    local label="$2"
    local package
    local missing=()
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label pipx packages listed"
        return 0
    }

    command -v pipx >/dev/null 2>&1 || die "pipx is not installed. Install normal pacman essentials first."

    for package in "${packages[@]}"; do
        pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fxq "$package" || missing+=("$package")
    done

    [ "${#missing[@]}" -gt 0 ] || {
        ok "No missing $label pipx tools"
        return 0
    }

    section "Installing missing $label pipx tools"
    pipx ensurepath
    for package in "${missing[@]}"; do
        printf '%s\n' "${dim}pipx: $package${reset}"
        pipx install "$package" || warn "Failed to install pipx package: $package"
    done
    ok "Finished missing $label pipx tools"
}

install_npm_packages() {
    local package_file="$1"
    local label="$2"
    local package
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label npm packages listed"
        return 0
    }

    command -v npm >/dev/null 2>&1 || die "npm is not installed. Install normal pacman essentials first."

    section "Installing $label npm packages"
    for package in "${packages[@]}"; do
        printf '%s\n' "${dim}npm: $package${reset}"
        sudo npm install -g "$package" || warn "Failed to install npm package: $package"
    done
    ok "Finished $label npm package set"
}

install_missing_npm_packages() {
    local package_file="$1"
    local label="$2"
    local package
    local missing=()
    mapfile -t packages < <(read_packages "$package_file")

    [ "${#packages[@]}" -gt 0 ] || {
        warn "No $label npm packages listed"
        return 0
    }

    command -v npm >/dev/null 2>&1 || die "npm is not installed. Install normal pacman essentials first."

    for package in "${packages[@]}"; do
        npm list -g "$package" --depth=0 >/dev/null 2>&1 || missing+=("$package")
    done

    [ "${#missing[@]}" -gt 0 ] || {
        ok "No missing $label npm packages"
        return 0
    }

    section "Installing missing $label npm packages"
    for package in "${missing[@]}"; do
        printf '%s\n' "${dim}npm: $package${reset}"
        sudo npm install -g "$package" || warn "Failed to install npm package: $package"
    done
    ok "Finished missing $label npm packages"
}

target_install_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER:-}" != "root" ]; then
        printf '%s\n' "$SUDO_USER"
    else
        id -un
    fi
}

ensure_zsh_login_shell() {
    local user shell current_shell

    user="$(target_install_user)"
    shell="$(command -v zsh || true)"

    [ -n "$shell" ] || {
        warn "zsh is not installed yet; cannot set login shell"
        return 0
    }

    if ! grep -Fxq "$shell" /etc/shells 2>/dev/null; then
        printf '%s\n' "$shell" | sudo tee -a /etc/shells >/dev/null
    fi

    current_shell="$(getent passwd "$user" | cut -d: -f7)"
    if [ "$(readlink -f "$current_shell" 2>/dev/null || printf '%s\n' "$current_shell")" = "$(readlink -f "$shell")" ]; then
        ok "$user login shell is already zsh"
        return 0
    fi

    sudo chsh -s "$shell" "$user"
    ok "Set $user login shell to $shell"
}

ensure_system_group() {
    local group="$1"

    getent group "$group" >/dev/null 2>&1 && return 0
    sudo groupadd --system "$group" || warn "Could not create $group group"
}

add_user_to_groups() {
    local user group
    local groups=(
        wheel
        docker
        wireshark
        video
        render
        input
        audio
        storage
        optical
        power
        network
        lp
        scanner
        uucp
        adbusers
        kvm
        libvirt
        realtime
    )

    user="$(target_install_user)"
    ensure_system_group "docker"
    ensure_system_group "wireshark"

    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            sudo usermod -aG "$group" "$user"
        fi
    done

    ok "Added $user to available desktop/dev/admin groups"
    warn "Group changes require logging out and back in before they fully apply"
}

enable_systemd_service() {
    local service="$1"

    command -v systemctl >/dev/null 2>&1 || return 0
    systemctl list-unit-files "$service" >/dev/null 2>&1 || return 0
    sudo systemctl enable --now "$service" || warn "Could not enable $service"
}

configure_wireshark_capture() {
    local dumpcap

    dumpcap="$(command -v dumpcap || true)"
    [ -n "$dumpcap" ] || return 0
    command -v setcap >/dev/null 2>&1 || {
        warn "setcap is not available; skipping dumpcap capture permissions"
        return 0
    }

    sudo setcap cap_net_raw,cap_net_admin=eip "$dumpcap" || warn "Could not set dumpcap capture permissions"
}

configure_system_access() {
    section "Configuring shell, permissions, and services"
    ensure_zsh_login_shell
    add_user_to_groups
    enable_systemd_service "NetworkManager.service"
    enable_systemd_service "docker.service"
    configure_wireshark_capture
    ok "System access setup complete"
}

fix_executable_bits() {
    local file

    section "Fixing executable permissions"
    while IFS= read -r -d '' file; do
        [ -e "$file" ] || continue
        chmod +x "$file"
    done < <(
        find "$repo_dir/.config/hypr/scripts" "$repo_dir/.config/waybar/scripts" -type f -print0 2>/dev/null
        find "$repo_dir/.config/rofi/launchers" -name '*.sh' -type f -print0 2>/dev/null
        printf '%s\0' "$repo_dir/install.sh" "$repo_dir/.config/wlogout/launch.sh"
    )
    ok "Executable bits fixed"
}

link_file() {
    local src="$1"
    local dst="$HOME/${src#$repo_dir/}"

    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$(readlink -f "$dst" 2>/dev/null || true)" = "$src" ]; then
            return 0
        fi

        mkdir -p "$backup_dir/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$backup_dir/${dst#$HOME/}"
    fi

    ln -s "$src" "$dst"
}

link_dotfiles() {
    section "Linking dotfiles"

    while IFS= read -r -d '' file; do
        case "${file#$repo_dir/}" in
            .git/*|.gitignore|README.md|MANIFEST.md|install.sh|packages/*)
                continue
                ;;
        esac
        link_file "$file"
    done < <(find "$repo_dir" -type f -print0)

    ok "Dotfiles linked"
}

link_missing_dotfiles() {
    local file dst linked=0

    section "Linking missing dotfiles"

    while IFS= read -r -d '' file; do
        case "${file#$repo_dir/}" in
            .git/*|.gitignore|README.md|MANIFEST.md|install.sh|packages/*)
                continue
                ;;
        esac

        dst="$HOME/${file#$repo_dir/}"
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            continue
        fi

        mkdir -p "$(dirname "$dst")"
        ln -s "$file" "$dst"
        linked=$((linked + 1))
    done < <(find "$repo_dir" -type f -print0)

    ok "Linked $linked missing dotfiles"
}

write_hypr_single_monitor() {
    local output="${1:-eDP-1}"

    cat > "$repo_dir/.config/hypr/configs/monitors.conf" <<'EOF'
# Generated by install.sh.
# Single-monitor laptop/internal-display layout.
EOF
    printf 'monitor=%s,preferred,auto,1\n' "$output" >> "$repo_dir/.config/hypr/configs/monitors.conf"

    cat > "$repo_dir/.config/hypr/hyprpaper.conf" <<EOF
preload = ~/.config/hypr/images/backiee-325856-landscape.jpg

wallpaper {
    monitor = $output
    path = ~/.config/hypr/images/backiee-325856-landscape.jpg
}

splash = false
EOF
}

write_hypr_dual_monitor() {
    local left="${1:-HDMI-A-1}"
    local right="${2:-HDMI-A-2}"
    local mode="${3:-1920x1080@60}"
    local scale="${4:-1}"

    cat > "$repo_dir/.config/hypr/configs/monitors.conf" <<EOF
# Generated by install.sh.
# Two-monitor layout.
monitor=$left,$mode,0x0,$scale
monitor=$right,$mode,1920x0,$scale
EOF

    cat > "$repo_dir/.config/hypr/hyprpaper.conf" <<EOF
preload = ~/.config/hypr/images/backiee-325856-landscape.jpg

wallpaper {
    monitor = $left
    path = ~/.config/hypr/images/backiee-325856-landscape.jpg
}

wallpaper {
    monitor = $right
    path = ~/.config/hypr/images/backiee-325856-landscape.jpg
}

splash = false
EOF
}

show_detected_monitors() {
    if command -v hyprctl >/dev/null 2>&1; then
        info "Detected Hyprland outputs:"
        hyprctl monitors 2>/dev/null | awk '/^Monitor / {print "  - " $2}' || true
    else
        info "hyprctl is not available yet; using installer defaults"
    fi
}

get_detected_monitors() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    hyprctl monitors 2>/dev/null | awk '/^Monitor / {print $2}' || true
}

configure_hypr_monitors() {
    local choice left right mode scale
    local detected=()

    mapfile -t detected < <(get_detected_monitors)

    banner
    section "Hyprland monitor setup"
    show_detected_monitors
    printf '\n'
    printf '  %s1%s  Single monitor, eDP-1 laptop/internal display\n' "$bold" "$reset"
    printf '  %s2%s  Two monitors, HDMI-A-1 left and HDMI-A-2 right\n' "$bold" "$reset"
    printf '  %s3%s  Use detected monitor output names\n' "$bold" "$reset"
    printf '  %s4%s  Custom output names\n' "$bold" "$reset"
    printf '  %s5%s  Skip monitor changes\n' "$bold" "$reset"
    printf '\n'
    read -r -p "Choose monitor layout [1-5]: " choice

    case "$choice" in
        1)
            write_hypr_single_monitor "eDP-1"
            ok "Wrote single-monitor Hyprland config for eDP-1"
            ;;
        2)
            write_hypr_dual_monitor "HDMI-A-1" "HDMI-A-2" "1920x1080@60" "1"
            ok "Wrote two-monitor Hyprland config"
            ;;
        3)
            if [ "${#detected[@]}" -eq 1 ]; then
                write_hypr_single_monitor "${detected[0]}"
                ok "Wrote single-monitor Hyprland config for ${detected[0]}"
            elif [ "${#detected[@]}" -ge 2 ]; then
                write_hypr_dual_monitor "${detected[0]}" "${detected[1]}" "1920x1080@60" "1"
                ok "Wrote two-monitor Hyprland config for ${detected[0]} and ${detected[1]}"
            else
                warn "No live Hyprland outputs detected; leaving monitor config unchanged"
            fi
            ;;
        4)
            read -r -p "Left monitor output [HDMI-A-1]: " left
            read -r -p "Right monitor output [HDMI-A-2]: " right
            read -r -p "Resolution/refresh [1920x1080@60]: " mode
            read -r -p "Scale [1]: " scale
            write_hypr_dual_monitor "${left:-HDMI-A-1}" "${right:-HDMI-A-2}" "${mode:-1920x1080@60}" "${scale:-1}"
            ok "Wrote custom two-monitor Hyprland config"
            ;;
        *)
            info "Leaving Hyprland monitor config unchanged"
            ;;
    esac
}

activate_desktop_settings() {
    section "Applying desktop settings"

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
        gsettings set org.gnome.desktop.interface icon-theme candy-icons || true
        ok "Requested dark mode and candy-icons"
    else
        warn "gsettings not available; GTK files are still linked"
    fi
}

install_normal_packages() {
    install_pacman_packages "$repo_dir/packages/pacman-essential.txt" "normal"
    install_aur_packages "$repo_dir/packages/aur-essential.txt" "normal"
    install_pipx_packages "$repo_dir/packages/pipx.txt" "normal"
    install_npm_packages "$repo_dir/packages/npm.txt" "normal"
}

install_hacking_packages() {
    install_pacman_packages "$repo_dir/packages/pacman-hacking.txt" "hacking"
    install_aur_packages "$repo_dir/packages/aur-hacking.txt" "hacking"
    install_pipx_packages "$repo_dir/packages/pipx-hacking.txt" "hacking"
}

fix_missing_essentials() {
    install_missing_pacman_packages "$repo_dir/packages/pacman-essential.txt" "normal"
    install_missing_aur_packages "$repo_dir/packages/aur-essential.txt" "normal"
    install_missing_pipx_packages "$repo_dir/packages/pipx.txt" "normal"
    install_missing_npm_packages "$repo_dir/packages/npm.txt" "normal"
    configure_system_access
    fix_executable_bits
    link_missing_dotfiles
}

package_menu() {
    local choice

    while true; do
        banner
        section "Package menu"
        printf '  %s1%s  Install normal pacman packages (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/pacman-essential.txt")"
        printf '  %s2%s  Install normal AUR packages (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/aur-essential.txt")"
        printf '  %s3%s  Install normal pipx tools (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/pipx.txt")"
        printf '  %s4%s  Install normal npm packages (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/npm.txt")"
        printf '  %s5%s  Install hacking pacman packages (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/pacman-hacking.txt")"
        printf '  %s6%s  Install hacking AUR packages (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/aur-hacking.txt")"
        printf '  %s7%s  Install hacking pipx tools (%s)\n' "$bold" "$reset" "$(print_package_count "$repo_dir/packages/pipx-hacking.txt")"
        printf '  %s8%s  Configure zsh, permissions, and services\n' "$bold" "$reset"
        printf '  %s9%s  Fix missing essentials\n' "$bold" "$reset"
        printf '  %s10%s Back\n' "$bold" "$reset"
        printf '\n'
        read -r -p "Choose [1-10]: " choice

        case "$choice" in
            1) install_pacman_packages "$repo_dir/packages/pacman-essential.txt" "normal"; pause ;;
            2) install_aur_packages "$repo_dir/packages/aur-essential.txt" "normal"; pause ;;
            3) install_pipx_packages "$repo_dir/packages/pipx.txt" "normal"; pause ;;
            4) install_npm_packages "$repo_dir/packages/npm.txt" "normal"; pause ;;
            5) install_pacman_packages "$repo_dir/packages/pacman-hacking.txt" "hacking"; pause ;;
            6) install_aur_packages "$repo_dir/packages/aur-hacking.txt" "hacking"; pause ;;
            7) install_pipx_packages "$repo_dir/packages/pipx-hacking.txt" "hacking"; pause ;;
            8) configure_system_access; pause ;;
            9) fix_missing_essentials; pause ;;
            10) return 0 ;;
            *) warn "Invalid choice"; pause ;;
        esac
    done
}

recommended_desktop_setup() {
    install_normal_packages
    configure_system_access
    fix_executable_bits
    link_dotfiles
    configure_hypr_monitors
    activate_desktop_settings
}

full_setup() {
    install_normal_packages
    install_hacking_packages
    configure_system_access
    fix_executable_bits
    link_dotfiles
    configure_hypr_monitors
    activate_desktop_settings
}

check_passes=0
check_warnings=0
check_failures=0

check_ok() {
    check_passes=$((check_passes + 1))
    ok "$*"
}

check_warn() {
    check_warnings=$((check_warnings + 1))
    warn "$*"
}

check_fail() {
    check_failures=$((check_failures + 1))
    printf '%s[FAIL]%s %s\n' "$red" "$reset" "$*" >&2
}

check_file_exists() {
    local file="$1"

    if [ -e "$repo_dir/$file" ]; then
        check_ok "$file exists"
    else
        check_fail "$file is missing"
    fi
}

check_command_exists() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        check_ok "$command_name is available"
    else
        check_warn "$command_name is not installed yet"
    fi
}

check_package_file() {
    local file="$1"
    local label="$2"
    local count

    if [ ! -f "$repo_dir/$file" ]; then
        check_fail "$file is missing"
        return 0
    fi

    count="$(print_package_count "$repo_dir/$file")"
    check_ok "$label package file exists ($count packages)"
}

check_pacman_packages() {
    local file="$1"
    local label="$2"
    local package
    local missing=0
    local steam_needs_multilib=0

    if ! command -v pacman >/dev/null 2>&1; then
        check_warn "pacman is unavailable; skipping $label package validation"
        return 0
    fi

    while IFS= read -r package; do
        if [ "$package" = "steam" ] && ! pacman_repo_enabled "multilib"; then
            check_warn "multilib is disabled; installer will enable it before installing steam"
            steam_needs_multilib=1
            continue
        fi

        if ! pacman -Si "$package" >/dev/null 2>&1; then
            check_fail "$label pacman package not found: $package"
            missing=$((missing + 1))
        fi
    done < <(read_packages "$repo_dir/$file")

    if [ "$missing" -eq 0 ]; then
        if [ "$steam_needs_multilib" -eq 1 ]; then
            check_ok "$label pacman packages resolve, except steam pending multilib enablement"
        else
            check_ok "$label pacman packages resolve"
        fi
    fi
}

check_aur_packages() {
    local file="$1"
    local label="$2"
    local package
    local count=0

    while IFS= read -r package; do
        count=$((count + 1))
    done < <(read_packages "$repo_dir/$file")

    if [ "$count" -eq 0 ]; then
        check_warn "$label AUR package file has no packages"
        return 0
    fi

    if command -v paru >/dev/null 2>&1; then
        check_ok "paru is available for $label AUR packages ($count listed)"
    else
        check_warn "paru is not installed yet; installer will bootstrap it before $label AUR packages ($count listed)"
    fi
}

check_pipx_packages() {
    local file="$1"
    local label="$2"
    local count

    count="$(print_package_count "$repo_dir/$file")"
    if [ "$count" -eq 0 ]; then
        check_ok "$label pipx package file is empty"
    elif command -v pipx >/dev/null 2>&1; then
        check_ok "pipx is available for $label pipx tools ($count listed)"
    else
        check_warn "pipx is not installed yet; install normal pacman packages before $label pipx tools"
    fi
}

check_npm_packages() {
    local file="$1"
    local label="$2"
    local count

    count="$(print_package_count "$repo_dir/$file")"
    if [ "$count" -eq 0 ]; then
        check_ok "$label npm package file is empty"
    elif command -v npm >/dev/null 2>&1; then
        check_ok "npm is available for $label npm packages ($count listed)"
    else
        check_warn "npm is not installed yet; install normal pacman packages before $label npm packages"
    fi
}

check_executable_bits() {
    local file
    local missing=0

    while IFS= read -r -d '' file; do
        if [ ! -x "$file" ]; then
            check_fail "${file#$repo_dir/} is not executable"
            missing=$((missing + 1))
        fi
    done < <(
        find "$repo_dir/.config/hypr/scripts" "$repo_dir/.config/waybar/scripts" -type f -print0 2>/dev/null
        find "$repo_dir/.config/rofi/launchers" -name '*.sh' -type f -print0 2>/dev/null
        printf '%s\0' "$repo_dir/install.sh" "$repo_dir/.config/wlogout/launch.sh"
    )

    if [ "$missing" -eq 0 ]; then
        check_ok "installer and helper scripts are executable"
    fi
}

check_hypr_references() {
    local missing=0
    local file

    for file in \
        ".config/hypr/hyprland.conf" \
        ".config/hypr/configs/startup.conf" \
        ".config/hypr/configs/binds.conf" \
        ".config/hypr/configs/windowrule.conf" \
        ".config/hypr/configs/monitors.conf" \
        ".config/hypr/hyprpaper.conf"
    do
        if [ ! -f "$repo_dir/$file" ]; then
            check_fail "$file is missing"
            missing=$((missing + 1))
        fi
    done

    if rg -n 'source = configs/monitors.conf' "$repo_dir/.config/hypr/hyprland.conf" >/dev/null 2>&1; then
        check_ok "hyprland.conf sources configs/monitors.conf"
    else
        check_fail "hyprland.conf does not source configs/monitors.conf"
    fi

    if rg -n 'backiee-325856-landscape.jpg' "$repo_dir/.config/hypr/hyprpaper.conf" >/dev/null 2>&1 &&
        [ -f "$repo_dir/.config/hypr/images/backiee-325856-landscape.jpg" ]; then
        check_ok "hyprpaper wallpaper exists"
    else
        check_fail "hyprpaper wallpaper reference is missing"
    fi

    if [ "$missing" -eq 0 ]; then
        check_ok "Hyprland core config files exist"
    fi
}

check_no_obvious_secrets() {
    local output

    if ! command -v rg >/dev/null 2>&1; then
        check_warn "ripgrep is unavailable; skipping secret-looking string scan"
        return 0
    fi

    output="$(rg -n -i '(api[_-]?key|secret|token|password|passwd|authorization|bearer|private[_-]?key)' "$repo_dir" \
        --glob '!packages/*' \
        --glob '!README.md' \
        --glob '!MANIFEST.md' \
        --glob '!install.sh' \
        --glob '!.git/*' 2>/dev/null || true)"

    if [ -n "$output" ]; then
        check_warn "possible secret-looking strings found; review with:"
        printf '%s\n' "$output" | sed -n '1,12p'
    else
        check_ok "no obvious secret-looking strings found"
    fi
}

check_no_removed_terminals() {
    local output

    if ! command -v rg >/dev/null 2>&1; then
        check_warn "ripgrep is unavailable; skipping old terminal reference scan"
        return 0
    fi

    output="$(rg -n 'alacritty|wezterm|kitty' "$repo_dir/.config" "$repo_dir/.zshrc" "$repo_dir/.bashrc" 2>/dev/null || true)"
    if [ -n "$output" ]; then
        check_warn "old terminal references found:"
        printf '%s\n' "$output"
    else
        check_ok "no old terminal references found"
    fi
}

check_dotfiles() {
    banner
    section "Dry check"
    info "No packages will be installed and no files will be modified."

    section "Required files"
    check_file_exists "install.sh"
    check_file_exists "README.md"
    check_file_exists "MANIFEST.md"
    check_file_exists ".config/hypr/hyprland.conf"
    check_file_exists ".config/hypr/configs/monitors.conf"
    check_file_exists ".config/wlogout/layout"
    check_file_exists ".config/waybar/config.jsonc"
    check_file_exists ".config/rofi/config.rasi"
    check_file_exists ".config/ghostty/config"
    check_file_exists ".config/tmux/tmux.conf"
    check_file_exists ".config/btop/btop.conf"
    check_file_exists ".codex/config.toml"

    section "Package files"
    check_package_file "packages/pacman-essential.txt" "normal pacman"
    check_package_file "packages/aur-essential.txt" "normal AUR"
    check_package_file "packages/pipx.txt" "normal pipx"
    check_package_file "packages/npm.txt" "normal npm"
    check_package_file "packages/pacman-hacking.txt" "hacking pacman"
    check_package_file "packages/aur-hacking.txt" "hacking AUR"
    check_package_file "packages/pipx-hacking.txt" "hacking pipx"

    section "Host commands"
    check_command_exists "bash"
    check_command_exists "sudo"
    check_command_exists "git"
    check_command_exists "pacman"
    check_command_exists "makepkg"
    check_command_exists "rg"
    check_command_exists "pipx"
    check_command_exists "npm"
    check_command_exists "node"
    check_command_exists "zsh"
    check_command_exists "paru"

    section "Package availability"
    check_pacman_packages "packages/pacman-essential.txt" "normal"
    check_pacman_packages "packages/pacman-hacking.txt" "hacking"
    check_aur_packages "packages/aur-essential.txt" "normal"
    check_aur_packages "packages/aur-hacking.txt" "hacking"
    check_pipx_packages "packages/pipx.txt" "normal"
    check_pipx_packages "packages/pipx-hacking.txt" "hacking"
    check_npm_packages "packages/npm.txt" "normal"

    section "Config sanity"
    check_executable_bits
    check_hypr_references
    check_no_removed_terminals
    check_no_obvious_secrets

    section "Summary"
    printf '%sPasses:%s %s\n' "$green" "$reset" "$check_passes"
    printf '%sWarnings:%s %s\n' "$yellow" "$reset" "$check_warnings"
    printf '%sFailures:%s %s\n' "$red" "$reset" "$check_failures"

    if [ "$check_failures" -gt 0 ]; then
        return 1
    fi
}

finish_message() {
    printf '\n'
    line
    if [ -d "$backup_dir" ]; then
        printf '%sBackups:%s %s\n' "$yellow" "$reset" "$backup_dir"
    fi
    printf '%sRepo:%s %s\n' "$cyan" "$reset" "$repo_dir"
    printf '%sDone.%s\n' "$green" "$reset"
}

main_menu() {
    local choice

    while true; do
        banner
        printf '  %s1%s  Recommended desktop setup\n' "$bold" "$reset"
        printf '      normal packages, AUR apps, dotfiles, monitor setup\n'
        printf '  %s2%s  Full setup with hacking tools\n' "$bold" "$reset"
        printf '      normal setup plus security, Android, and firmware tools\n'
        printf '  %s3%s  Package menu\n' "$bold" "$reset"
        printf '      install normal/hacking pacman, AUR, pipx, or npm sets separately\n'
        printf '  %s4%s  Link dotfiles only\n' "$bold" "$reset"
        printf '  %s5%s  Configure Hyprland monitors only\n' "$bold" "$reset"
        printf '  %s6%s  Apply dark mode and icon theme only\n' "$bold" "$reset"
        printf '  %s7%s  Fix missing essentials\n' "$bold" "$reset"
        printf '      install absent normal packages/tools and repair shell, groups, services, permissions\n'
        printf '  %s8%s  Exit\n' "$bold" "$reset"
        printf '\n'
        read -r -p "Choose [1-8]: " choice

        case "$choice" in
            1) recommended_desktop_setup; finish_message; return 0 ;;
            2) full_setup; finish_message; return 0 ;;
            3) package_menu ;;
            4) link_dotfiles; finish_message; return 0 ;;
            5) configure_hypr_monitors; finish_message; return 0 ;;
            6) activate_desktop_settings; finish_message; return 0 ;;
            7) fix_missing_essentials; finish_message; return 0 ;;
            8) info "No changes made"; return 0 ;;
            *) warn "Invalid choice"; pause ;;
        esac
    done
}

main() {
    if [ ! -f /etc/arch-release ]; then
        warn "This installer targets Arch-based systems."
    fi

    if [ "${1:-}" = "--check" ]; then
        check_dotfiles
        return $?
    fi

    if [ "${1:-}" = "--full" ]; then
        full_setup
        finish_message
        return 0
    fi

    if [ "${1:-}" = "--desktop" ]; then
        recommended_desktop_setup
        finish_message
        return 0
    fi

    if [ "${1:-}" = "--fix-missing" ]; then
        fix_missing_essentials
        finish_message
        return 0
    fi

    main_menu
}

main "$@"
