#/bin/bash

# create a check somehow
if command cargo -v > /dev/null 2>&1; then 
	echo "cagro installed"
else 
	echo "installing rust"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi 

if command paru -h > /dev/null 2>&1; then 
	echo "paru installed"
else 
	echo "installing paru"
	cd ~
	git clone https://aur.archlinux.org/paru.git
	cd paru
	makepkg -si
fi

echo "Installing Dev tools"
sudo pacman -S go delve gdb make cmake gcc man-db man-pages python gopls zig neovim

echo "Installing Hyprland"
paru -S grim mako kitty hyprland rofi-wayland fastfetch mpv wlogout hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland hyprcursor wireplumber qt5-wayland qt6-wayland waybar copyq wl-clipboard hyprpaper swaybg kde-polkit-agent

echo "Installing software"
paru -S rofi-power-menu rofi-wifi-menu docker candy-icons cava ranger gimp kdenlive krita brave-bin firefox uwufetch fzf qbittorrent ripgrep lazygit thunar zathura obs-studio


echo "Installing Fonts"
paru -S adobe-source-code-pro-fonts cantarell-fonts fontconfig fonts-cjk gnu-free-fonts libfontenc libxfont2 ttf-font-awesome ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common ttf-nerd-fonts-symbols-mono ttf-profont-nerd xorg-fonts-encodings xorg-mkfontscale ttf-hack
