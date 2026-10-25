# Archiso Profile Reference and Customization Recipes

## 1. Complete `profiledef.sh` Variable Reference

| Variable | Default | Description and Constraints |
| --- | --- | --- |
| `iso_name` | `mkarchiso` | First part of output filename: `<iso_name>-<iso_version>-<arch>.iso`. Also written to `IMAGE_ID` in `/etc/os-release`. |
| `iso_label` | `MKARCHISO` | ISO 9660 volume label (`%ARCHISO_LABEL%`). Uppercase alphanumeric and underscores recommended, max 32 chars. |
| `iso_publisher` | `mkarchiso` | Publisher metadata string embedded in the ISO header. |
| `iso_application` | `mkarchiso iso` | Application description embedded in the ISO header. |
| `iso_version` | `""` | Version string (`IMAGE_VERSION` in `/etc/os-release` and `/version`). |
| `install_dir` | `mkarchiso` | Directory on the ISO where live rootfs and kernel images reside (`%INSTALL_DIR%`). Must match `^[a-z0-9]+$` and be `<= 30` chars. |
| `arch` | `$(uname -m)` | Target architecture (`x86_64`, `aarch64`, `riscv64`, `loongarch64`). Cross-arch building is not supported. |
| `kernel_params_${arch}` | `""` | Architecture-specific kernel parameters (e.g., `kernel_params_x86_64="cow_spacesize=4G quiet splash"`), substituted for `%KERNEL_PARAMS%` in bootloader configs (added in archiso v91). |
| `bootmodes` | `()` | Array of supported boot modes: `bios.syslinux`, `uefi.systemd-boot`, or `uefi.grub`. Note: `uefi.systemd-boot` and `uefi.grub` are mutually exclusive. |
| `buildmodes` | `('iso')` | Optional array: `iso`, `bootstrap`, `netboot`. Usually omitted from `profiledef.sh` and passed via `mkarchiso -m`. |
| `pacman_conf` | `/etc/pacman.conf` | Path to `pacman.conf` used during build time. Note: `CacheDir`, `HookDir`, `RootDir`, `LogFile`, and `DBPath` are sanitized automatically by `mkarchiso`. |
| `packages` | `packages.${arch}` | Path to package list file for `iso` and `netboot` modes (falls back to `packages` if `packages.${arch}` does not exist). |
| `bootstrap_packages` | `bootstrap_packages.${arch}` | Path to package list file for `bootstrap` mode (falls back to `bootstrap_packages`). |
| `airootfs_image_type` | `squashfs` | Rootfs image type: `squashfs` (direct SquashFS), `ext4+squashfs` (32 GiB ext4 image inside SquashFS), or `erofs` (EROFS image). |
| `airootfs_image_tool_options` | `()` | Array of flags passed to `mksquashfs` or `mkfs.erofs`. |
| `bootstrap_tarball_compression` | `()` | Array of compressor command and flags for `bootstrap` tarball (e.g., `(zstd -c -T0 --long -19)` or `(xz -c -T0 -9e)`). |
| `file_permissions` | `()` | Associative array `["/path"]="UID:GID:MODE"`. Paths ending in `/` apply recursively. |

## 2. SquashFS and EROFS Compression Profiles

- **Fast Iteration / Development Build (zstd):**
  Builds rapidly while keeping a reasonable image size:

```bash
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')
```

- **Production Release Build (xz with BCJ filter):**
  Smallest ISO footprint (used by official `releng` profile):

```bash
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
```

- **EROFS Build (used by `baseline`):**
  Fast decompression and random access:

```bash
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlzma,109' -E 'ztailpacking')
```

## 3. Desktop Environment and Display Manager Recipes

### KDE Plasma + SDDM (Auto-login to Live User)

1. Add packages to `packages.x86_64`:
   `plasma-meta`, `konsole`, `dolphin`, `kate`, `sddm`, `networkmanager`, `pipewire`, `pipewire-pulse`, `wireplumber`, `mesa`, `vulkan-intel`, `vulkan-radeon`
2. Enable SDDM and NetworkManager symlinks in `airootfs/`:

```bash
mkdir -p profile/airootfs/etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager.service \
  profile/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/sddm.service \
  profile/airootfs/etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
  profile/airootfs/etc/systemd/system/default.target
```

3. Configure SDDM auto-login in `profile/airootfs/etc/sddm.conf.d/autologin.conf`:

```ini
[Autologin]
User=liveuser
Session=plasma
```

### GNOME + GDM (Auto-login to Live User)

1. Add packages to `packages.x86_64`:
   `gnome`, `gnome-tweaks`, `gdm`, `networkmanager`, `pipewire`, `pipewire-pulse`, `wireplumber`, `mesa`
2. Enable `gdm.service` as `display-manager.service` and `graphical.target` as `default.target`.
3. Configure GDM auto-login in `profile/airootfs/etc/gdm/custom.conf`:

```ini
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=liveuser
```

### XFCE / Hyprland / Tiling WM + LightDM or Greer

1. For LightDM auto-login (`profile/airootfs/etc/lightdm/lightdm.conf.d/autologin.conf`):
   Ensure the `autologin` group exists in `airootfs/etc/group` and `liveuser` belongs to it.

```ini
[Seat:*]
autologin-user=liveuser
autologin-user-timeout=0
user-session=xfce
```

2. For TTY auto-login without a display manager (e.g., starting Hyprland or Sway from `.zprofile`):
   Edit `profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`:

```ini
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin liveuser - ${TERM}
```

## 4. Declarative User Creation (`passwd`, `shadow`, `group`, `gshadow`)

When creating `liveuser` (UID 1000) via `airootfs/etc/` files:

- `airootfs/etc/passwd`:

```text
root:x:0:0:root:/root:/usr/bin/zsh
liveuser:x:1000:1000:Live User:/home/liveuser:/usr/bin/zsh
```

- `airootfs/etc/shadow` (generate hash via `openssl passwd -6 "live"`):

```text
root::14871::::::
liveuser:$6$rounds=500000$...:14871::::::
```

- `airootfs/etc/group`:

```text
root:x:0:root
adm:x:4:liveuser
wheel:x:10:liveuser
uucp:x:14:liveuser
optical:x:990:liveuser
audio:x:995:liveuser
storage:x:997:liveuser
video:x:986:liveuser
network:x:90:liveuser
liveuser:x:1000:
```

- `airootfs/etc/gshadow`:

```text
root:::root
wheel:::liveuser
liveuser:!::
```

- `airootfs/etc/sudoers.d/00_liveuser`:

```text
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
```

- Required entries in `profiledef.sh` `file_permissions`:

```bash
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/sudoers.d/00_liveuser"]="0:0:0440"
)
```

Place default user dotfiles inside `profile/airootfs/etc/skel/`. During `_make_customize_airootfs`, `mkarchiso` copies `/etc/skel/.` into `/home/liveuser` and sets ownership to `1000:1000` with mode `0750`.

## 5. Useful `mkinitcpio-archiso` Kernel Boot Parameters

- `cow_spacesize=4G`: Sets the size of the tmpfs Copy-on-Write overlay (`/run/archiso/cowspace`). Default is `256M`.
- `copytoram=y` (or `copytoram=n`): Controls copying the SquashFS/EROFS rootfs image into RAM on boot (enabled automatically when sufficient free RAM is detected).
- `script=https://example.org/setup.sh`: Downloads and executes an automated setup script once `network-online.target` is reached (handled by `/root/.automated_script.sh` in `releng`).
- `checksum=y`: Verifies the SHA512 checksum (`airootfs.sha512`) of the rootfs image during boot.
- `verify=y`: Verifies the PGP signature (`airootfs.sfs.sig`) when built with `mkarchiso -g <gpg_key_id>`.
