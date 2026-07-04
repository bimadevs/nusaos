#!/usr/bin/env bash
#
# customize_airootfs.sh — runs inside mkarchiso build chroot
# after all packages installed. Delete-on-success.
# See references/ for grokf-of pattern.
#
set -euo pipefail

# === Users ===
# Plain chpasswd — NO -e flag (which expects a precomputed hash)
useradd -m -G wheel,audio,video,storage,power -s /bin/zsh USERNAME
echo 'USERNAME:CHANGE_ME' | chpasswd
echo 'root:CHANGE_ME' | chpasswd

# === sudoers: NOPASSWD for live session ===
cat > /etc/sudoers.d/10-wheel-live <<'EOF'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/10-wheel-live

# === Enable services ===
systemctl enable lightdm.service
systemctl enable NetworkManager.service

# === Locale (also needs pacman hook to trigger locale-gen first time) ===
locale-gen

# === Display manager autologin ===
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=USERNAME
autologin-user-timeout=0
greeter-session=lightdm-gtk-greeter
user-session=xfce
EOF

# === User dotfiles ===
mkdir -p /home/USERNAME/.config/gtk-3.0
cat > /home/USERNAME/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Papirus
EOF

# /etc/skel is the cleanest path for new-user defaults, but here
# the user is already created by useradd with default /etc/skel, so
# just chown after writing.
chown -R USERNAME:USERNAME /home/USERNAME

# === Welcome message ===
cat > /etc/motd <<'EOF'

  ==================================
       BimaXOS — Live ISO
  Arch Linux + XFCE x11
  Login: USERNAME / (see docs)
  ==================================

EOF
