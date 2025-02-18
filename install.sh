#/bin/bash

sudo pacman -Syu

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
sudo pacman -S brightnessctl zsh udiskie go delve gdb make cmake gcc man-db man-pages python gopls zig neovim

echo "Installing Hyprland"
paru -S pcmanfm docker mullvad-vpn grim slurp mako kitty hyprland rofi-wayland fastfetch mpv wlogout hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland hyprcursor wireplumber qt5-wayland qt6-wayland waybar copyq wl-clipboard hyprpaper swaybg kde-polkit-agent sshfs tmux

echo "Installing software"
paru -S nwg-look obsidian ntfs-3g keepassxc openssh rofi-power-menu feh rofi-wifi-menu candy-icons cava ranger gimp kdenlive krita zen-browser firefox uwufetch fzf qbittorrent ripgrep lazygit zathura obs-studio

echo "Installing Fonts"
paru -S nerd-fonts adobe-source-code-pro-fonts cantarell-fonts fontconfig fonts-cjk gnu-free-fonts libfontenc libxfont2 ttf-font-awesome ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common ttf-nerd-fonts-symbols-mono ttf-profont-nerd xorg-fonts-encodings xorg-mkfontscale ttf-hack

echo "Installing KVM"
sudo pacman -S qemu-full virt-manager virt-viewer dnsmasq bridge-utils libguestfs ebtables vde2 openbsd-netcat

echo "Installing the needed images"
cd ~
git clone --depth=1 https://github.com/adi1090x/rofi.git
cd rofi
chmod +x setup.sh
./setup.sh
cd ~

echo "Adding BB Tools"
paru -S caido hashcat scrcpy wireshark-qt gobuster ffuf binwalk ghidra radare2 android-tools android-studio burpsuite android-emulator android-apktool jadx
paru -S oh-my-posh

echo "Moving Configs"
cp ~/dotfiles/.zshrc ~/.zshrc
cp ~/dotfiles/.zprofile ~/.zprofile
cp -r ~/dotfiles/.config/hypr/  ~/.config/
cp -r ~/dotfiles/.config/nvim ~/.config/
cp -r ~/dotfiles/.config/rofi ~/.config/
cp -r ~/dotfiles/.config/fastfetch ~/.config/
cp -r ~/dotfiles/.config/waybar ~/.config/
cp -r ~/dotfiles/.config/mako ~/.config/
cp -r ~/dotfiles/.config/gtk-2.0 ~/.config/
cp -r ~/dotfiles/.config/gtk-3.0 ~/.config/
cp -r ~/dotfiles/.config/gtk-4.0 ~/.config/
cp -r ~/dotfiles/.config/kitty ~/.config/
cp -r ~/dotfiles/.config/cava ~/.config/
cp -r ~/dotfiles/.config/lazygit ~/.config/
cp -r ~/dotfiles/.config/ohmyposh/ ~/.config/
cp -r ~/dotfiles/.config/copyq ~/.config/
cp -r ~/dotfiles/.config/tmux ~/.config/
cp -r ~/dotfiles/.themes/ ~/
cp -r ~dotfiles/.zsh ~/

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

echo "Enabling services"
sudo systemctl enable sshd
sudo systemctl start sshd

sudo systemctl start docker                                        
sudo systemctl enable docker

sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

sudo usermod -aG video,ftp,log,uucp,tty,utmp,kvm,input,audio,storage $USER
sudo usermod -s /bin/zsh $USER

sudo virsh net-start default
sudo virsh net-autostart default

sudo usermod -aG docker $USER

echo "Git global UserName type Leave blank to skip"
read username
if [[ -n ${username} ]]; then
  git config --global user.name ${username}
  echo "Now the git global Email"
  read email
  git config --global user.email ${email}
fi

echo "Pulling docker mobsf"
sudo docker pull opensecurity/mobile-security-framework-mobsf:latest

echo "[+] to run mobfs"
echo "[+] docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest"

#bat --theme="Catppuccin Mocha" ~/.config/bat/themes/Catppuccin\ Mocha.tmTheme
echo "[+] GO TO /etc/libvirt/libvirtd.conf and uncomment "
echo '[+] unix_sock_group = "libvirt" unix_sock_rw_perms = "0777"'
echo "sudo usermod -aG libvirt $USER run this"
sudo usermod -aG libvirt $USER

# will eventually connect to my prox mox server but I do eventually want to re vamp this
# fix thjis up 
