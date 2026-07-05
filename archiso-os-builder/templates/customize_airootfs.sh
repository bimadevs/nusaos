#!/usr/bin/env bash
#
# customize_airootfs.sh — runs inside mkarchiso build chroot
# after all packages installed. Delete-on-success.
#
set -euo pipefail

# === Users ===
# Plain chpasswd — NO -e flag (which expects a precomputed hash)
useradd -m -G wheel,audio,video,storage,power -s /bin/zsh nusa
echo 'nusa:live' | chpasswd
echo 'root:live' | chpasswd

# === sudoers: NOPASSWD for live session ===
cat > /etc/sudoers.d/10-wheel-live <<'EOF'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/10-wheel-live

# === Locale ===
locale-gen

# === Display manager (greetd) ===
mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
user = "nusa"
command = "/usr/bin/Hyprland"

[initial_session]
user = "nusa"
command = "/usr/bin/Hyprland"
EOF

# === User dotfiles ===
mkdir -p /home/nusa/.config/gtk-3.0
cat > /home/nusa/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans, 10
EOF

chown -R nusa:nusa /home/nusa

# === Welcome message ===
cat > /etc/motd <<'EOF'

  ╔══════════════════════════════════════════╗
  ║         NusaOS 1.0 — Live ISO            ║
  ║     Arch Linux + Hyprland (Wayland)      ║
  ║     User: nusa / Password: live          ║
  ╚══════════════════════════════════════════╝

  Install NusaOS: sudo archinstall
  Update mirror:  sudo rate-mirrors --protocol https --country Indonesia
  Help:           https://github.com/bimadevs/nusaos

EOF
