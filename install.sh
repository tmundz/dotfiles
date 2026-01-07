#!/bin/bash

# =============================================================================
# Streamlined Arch Linux Install Script
# Hyprland + Essential Tools Only
# =============================================================================

set -e  # Exit on error

echo "Starting system update..."
sudo pacman -Syu --noconfirm

# =============================================================================
# Development Tools
# =============================================================================
echo "Installing Base dev & system tools..."
sudo pacman -S --noconfirm brightnessctl zsh git neovim make cmake gcc \
    man-db man-pages python go gopls zig tmux udiskie base-devel
    
# =============================================================================
# Install Rust/Cargo
# =============================================================================
if command -v cargo > /dev/null 2>&1; then 
    echo "cargo already installed"
else 
    echo "Installing rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source "$HOME/.cargo/env"
fi 

# =============================================================================
# Install Paru (AUR Helper)
# =============================================================================
if command -v paru > /dev/null 2>&1; then 
    echo "paru already installed"
else 
    echo "Installing paru..."
    cd ~
    if ! git clone https://aur.archlinux.org/paru.git 2>/dev/null; then
        echo "paru directory exists, removing and retrying..."
        rm -rf ~/paru
        git clone https://aur.archlinux.org/paru.git
    fi
    cd paru
    makepkg -si
    cd ~
fi

# =============================================================================
# Hyprland Core
# =============================================================================
echo "Installing Hyprland..."
paru -S --noconfirm hyprland waybar rofi-wayland mako wezterm foot \
    grim slurp swappy wl-clipboard cliphist \
    xdg-desktop-portal-hyprland hyprcursor hyprlock hypridle hyprpaper \
    qt5-wayland qt6-wayland wireplumber kde-polkit-agent fastfetch

# =============================================================================
# Essential Software
# =============================================================================
echo "Installing software..."
paru -S --noconfirm docker zen-browser brave-bin pcmanfm mpv openssh \
    keepassxc fzf ripgrep lazygit okular ntfs-3g obs-studio \
    candy-icons nwg-look

# =============================================================================
# Fonts
# =============================================================================
echo "Installing Fonts..."
paru -S --noconfirm ttf-jetbrains-mono-nerd \
    ttf-fira-code-nerd \
    adobe-source-code-pro-fonts \
    ttf-font-awesome \
    ttf-nerd-fonts-symbols-common \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-dejavu \
    fontconfig \
    libfontenc \
    libxfont2 \
    xorg-fonts-encodings \
    xorg-mkfontscale

# =============================================================================
# KVM/Virtualization
# =============================================================================
echo "Installing KVM..."
sudo pacman -S --noconfirm qemu-full virt-manager virt-viewer dnsmasq \
    bridge-utils libguestfs ebtables vde2 openbsd-netcat

# =============================================================================
# Optional: Rofi Themes (Comment out if you don't want 50+ themes)
# =============================================================================
# echo "Installing Rofi Themes..."
# cd ~
# git clone --depth=1 https://github.com/adi1090x/rofi.git
# cd rofi
# chmod +x setup.sh
# ./setup.sh
# cd ~

# =============================================================================
# BUG BOUNTY / HACKING TOOLS (Install manually when needed)
# =============================================================================
# echo "Installing Bug Hunting Tools..."
# paru -S --noconfirm caido hashcat wireshark-qt gobuster ffuf burpsuite

# Mobile Testing
# paru -S --noconfirm scrcpy android-tools android-studio android-emulator android-apktool jadx

# Reverse Engineering  
# paru -S --noconfirm binwalk ghidra radare2

# echo "Installing Go Tools..."
# go install -v github.com/tomnomnom/anew@latest
# go install -v github.com/s0md3v/smap/cmd/smap@latest
# go install -v github.com/tomnomnom/assetfinder@latest
# go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
# go install -v github.com/sensepost/gowitness@latest
# paru -S --noconfirm katana

# Docker Security Tools
# echo "Pulling docker MobSF..."
# sudo docker pull opensecurity/mobile-security-framework-mobsf:latest
# echo "[+] To run MobSF:"
# echo "[+] docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest"

# =============================================================================
# Install tmux plugin manager
# =============================================================================
echo "Installing tmux plugin manager..."
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# =============================================================================
# Moving Configs
# =============================================================================
echo "Moving essential configs..."
# Shell configs
# cp ~/dotfiles/.zshrc ~/.zshrc
cp ~/dotfiles/.zprofile ~/.zprofile
cp -r ~/dotfiles/.zsh ~/

# Hyprland only
mkdir -p ~/.config
cp -r ~/dotfiles/.config/hypr/ ~/.config/

echo "Configs copied. You'll need to manually configure wezterm, waybar, mako, etc."

# =============================================================================
# Password Policy - 7 attempts before lockout
# =============================================================================
echo "Configuring password policy (7 attempts before lockout)..."
echo "deny = 7" | sudo tee -a /etc/security/faillock.conf > /dev/null

# =============================================================================
# Enable Services
# =============================================================================
echo "Enabling services..."
sudo systemctl enable --now sshd
sudo systemctl enable --now docker
sudo systemctl enable --now libvirtd.service

# User groups
sudo usermod -aG docker,kvm,libvirt $USER
sudo usermod -s /bin/zsh $USER

# Libvirt network
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default

# Fix libvirt permissions automatically
sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf
sudo systemctl restart libvirtd.service

# =============================================================================
# Git Configuration
# =============================================================================
echo ""
read -p "Git global username (leave blank to skip): " username
if [[ -n ${username} ]]; then
  git config --global user.name "${username}"
  read -p "Git global email: " email
  git config --global user.email "${email}"
  echo "Git configured successfully!"
fi

# =============================================================================
# Cliphist Setup Reminder
# =============================================================================
echo ""
echo "=========================================================================="
echo "Installation Complete!"
echo "=========================================================================="
echo ""
echo "IMPORTANT - Add to your Hyprland config:"
echo ""
echo "# Start cliphist daemon"
echo "exec-once = wl-paste --type text --watch cliphist store"
echo "exec-once = wl-paste --type image --watch cliphist store"
echo ""
echo "# Clipboard history keybind"
echo "bind = SUPER, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
echo ""
echo "=========================================================================="
echo "You may need to log out and back in for group changes to take effect."
echo "=========================================================================="
