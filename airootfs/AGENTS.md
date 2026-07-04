# airootfs/ — Live System Overlay

## OVERVIEW

Root filesystem overlay untuk live environment NusaOS. File di sini di-copy ke `/` saat ISO boot, SEBELUM paket diinstall. Package files overwrite airootfs files.

## STRUCTURE

```
airootfs/
├── etc/
│   ├── hostname           → nusaos ✅
│   ├── locale.gen         → en_US.UTF-8 + id_ID.UTF-8 ✅
│   ├── locale.conf        → en_US.UTF-8 ✅
│   ├── localtime          → Asia/Jakarta symlink ✅
│   ├── vconsole.conf      → KEYMAP=us + font ter-116n ✅
│   ├── hosts              → localhost + nusaos.localdomain ✅
│   ├── os-release         → NusaOS identity ✅
│   ├── sudoers.d/10_wheel → wheel sudo access ✅
│   ├── pacman.d/
│   │   ├── mirrorlist     → Indonesia mirrors ✅
│   │   └── hooks/         → 2 hooks (mirror uncomment + cleanup)
│   ├── mkinitcpio.conf.d/archiso.conf → HOOKS archiso
│   ├── mkinitcpio.d/linux.preset      → kernel/initramfs paths
│   ├── NetworkManager/conf.d/
│   │   ├── wifi_backend.conf → iwd backend ✅
│   │   └── nusaos.conf      → dhcp=internal ✅
│   ├── lightdm/
│   │   ├── lightdm.conf           → autologin nusa, XFCE session ✅
│   │   └── lightdm-gtk-greeter.conf → Arc-Dark theme ✅
│   ├── systemd/
│   │   ├── multi-user.target.wants/ → NM, bluetooth, tlp, acpid, upower ✅
│   │   ├── display-manager.target.wants/lightdm.service → LightDM ✅
│   │   ├── getty@tty1.service.d/autologin.conf → root auto-login
│   │   ├── journald.conf.d/volatile.conf → volatile journal 50M ✅
│   │   └── sockets.target.wants/ → pcscd.socket
│   ├── skel/
│   │   ├── .bashrc         → bash aliases ✅
│   │   ├── .zshrc          → zsh with syntax highlighting ✅
│   │   └── .config/
│   │       ├── user-dirs.dirs     → XDG dirs ✅
│   │       └── user-dirs.locale   → id_ID ✅
│   └── modules-load.d/    → loop, squashfs, overlay
├── root/
│   ├── .automated_script.sh → auto-run script
│   └── .gnupg/              → gpg config
└── usr/local/bin/
    └── livecd-sound          → ALSA unmuter ✅
```

## ENABLED SERVICES

| Service | Target | Purpose |
|---------|--------|---------|
| NetworkManager.service | multi-user | Network management |
| bluetooth.service | multi-user | Bluetooth |
| lightdm.service | display-manager | Login manager |
| tlp.service | multi-user | Power management |
| acpid.service | multi-user | ACPI events |
| upower.service | multi-user | Power monitoring |
| iwd.service | multi-user | Wireless backend |
| ModemManager.service | multi-user | Mobile broadband |
| sshd.service | multi-user | SSH server (live only) |
| pacman-init.service | multi-user | Keyring init |

## CONVENTIONS

- File permissions default: 644 files, 755 dirs, root:root.
- airootfs copied BEFORE packages — package files overwrite conflicts.
- Symlinks: manual `ln -s` to `/usr/lib/systemd/system/`.

## ANTI-PATTERNS

- Jangan enable systemd-networkd + NetworkManager — conflict.
- Jangan pake `localectl`/`timedatectl` in chroot — use files directly.
- Jangan enable reflector.service — overwrites mirrorlist.

## NOTES

1. All releng cruft removed: cloud-init, HV/VMware/VBox, systemd-networkd, .network files.
2. LightDM > SDDM: GTK-based, shared deps with XFCE.
3. NM + iwd backend, not wpa_supplicant.
4. Journal volatile to reduce USB writes.
