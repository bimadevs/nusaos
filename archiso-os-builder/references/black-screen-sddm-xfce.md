# Black Screen After SDDM Login (XFCE + archiso)

## Symptom

SDDM greeter tampil normal. Input password diterima (tidak looping).
Setelah login: layar hitam, mouse pointer visible, mouse bisa digerakkan.
Tidak ada panel, wallpaper, atau desktop muncul.

## Diagnosis Tree

### 1. SDDM Wayland default (most common)

SDDM 0.21+ di Arch auto-detects Wayland capability. Jika target GPU
mendukung, SDDM start session via Wayland. XFCE 4.18 only supports
X11 — Wayland session crashes silently before XFCE components init.

**Test:**
```bash
# cek session type yang digunakan
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type

# lihat error SDDM
journalctl -u sddm -b --no-pager | grep -i wayland
journalctl -u sddm -b --no-pager | grep -i "failed\|error\|crash"
```

**Fix:**
```
# airootfs/etc/sddm.conf.d/theme.conf
[General]
DisplayServer=x11
```

### 2. XFCE missing core components

Minimal `xfce4-panel` + `xfce4-session` tidak cukup. Paket minimal
yang diperlukan untuk session XFCE functional:

**Core session:**
- `xfce4-session` — session manager
- `xfce4-panel` — panel
- `xfce4-settings` — settings daemon
- `xfwm4` — window manager
- `xfdesktop` — desktop manager (wallpaper, icons)
- `xfconf` — config backend (dbus)

**Menu & launcher:**
- `garcon` — GApplication-based menu backend (WAJIB)
- `xfce4-appfinder` — app launcher (WAJIB)

**Tanpa garcon + xfce4-appfinder:**
Panel muncul tapi menu aplikasi tidak bisa dibuka — dimanifestasikan
sebagai empty click atau panel daemon error yang cascade ke session
crash.

**Notifications:**
- `xfce4-notifyd` — notification daemon (opsional, recommended)

**Thunar ecosystem:**
- `tumbler` — thumbnail generator
- `thunar`, `thunar-volman`, `thunar-archive-plugin`

**Archive:**
- `xarchiver` — "Extract here" context menu
- `file-roller` — archive manager

**Test session manual (via TTY):**
```bash
# switch to TTY2
# ctrl+alt+F2, login as root/bima
startxfce4
# error output langsung kelihatan di terminal
```

### 3. Other causes (less common)

| Cause | Test | Fix |
|-------|------|-----|
| NO compositor | `xfwm4 --replace &` | Add `xfwm4` to packages |
| Missing xfdesktop | `xfdesktop &` | Add `xfdesktop` |
| $DISPLAY not set | `echo $DISPLAY` | SDDM should set this automatically |
| dbus not running | `ps aux \| grep dbus` | dbus is part of base — should be running |

## Log locations (live ISO)

```bash
journalctl -u sddm -b --no-pager
journalctl -u sddm -b -p err
less ~/.xsession-errors   # jika ada
less /var/log/Xorg.0.log
```

## Prevention in SKILL.md

- Selalu tambahkan `[General] DisplayServer=x11` di SDDM config
  untuk XFCE target.
- Jangan pernah install hanya `xfce4-panel` + `xfce4-session` —
  minimal juga `garcon` + `xfce4-appfinder` + `xfwm4` + `xfdesktop` +
  `xfconf`.
- Validator check (L3) sebaiknya include: `startxfce4 --version`
  untuk pastikan XFCE session executable ada.
