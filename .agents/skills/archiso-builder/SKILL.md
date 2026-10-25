---
name: archiso-builder
description: Build, customize, validate, and test custom Arch Linux live ISO images, installers, and distributions using the official archiso framework (mkarchiso and run_archiso). Use when the user asks to create a custom Arch Linux OS, build an Arch ISO, customize an archiso profile (releng or baseline), configure profiledef.sh, add custom packages or AUR repositories to an ISO, configure airootfs overlays, set up systemd services, display managers, desktop environments, live users, bootloaders (systemd-boot, GRUB, syslinux), or troubleshoot mkarchiso build errors.
---
# Archiso Builder

Build, customize, validate, and test production-grade custom Arch Linux live ISO images and operating systems using the official `archiso` toolset (`mkarchiso` and `run_archiso`).

## When to Use

- Creating a custom Arch Linux operating system, live USB/ISO, rescue medium, or automated installer from `releng` or `baseline` profiles
- Configuring `profiledef.sh`, `packages.x86_64`, `pacman.conf`, or bootloader templates (`efiboot`, `grub`, `syslinux`)
- Customizing the live root filesystem (`airootfs/`) with users, passwords, dotfiles, systemd services, desktop environments, or networking
- Integrating AUR packages or custom PKGBUILDs into an Arch ISO via a local repository
- Debugging `mkarchiso` validation errors, boot failures, CoW space exhaustion, or permission issues

## Prerequisites and Host Environment

Verify that the build host runs Arch Linux (or an Arch-based container/VM) with the required packages installed before building:

```bash
pacman -Qi archiso arch-install-scripts awk dosfstools e2fsprogs erofs-utils findutils grub gzip libarchive libisoburn mtools openssl pacman sed squashfs-tools
```

For testing images in QEMU (BIOS and UEFI), install:

```bash
sudo pacman -S --needed archiso qemu-desktop edk2-ovmf
```

## Core Workflow

### Step 1: Initialize the Profile

Never edit `/usr/share/archiso/configs/` directly, as package updates overwrite system files. Copy an official base profile to a writable workspace directory:

- Use `releng` for full-featured live environments, desktop distributions, or custom installers (includes wireless firmware, CLI utilities, accessibility tools, and `bios.syslinux` + `uefi.systemd-boot`).
- Use `baseline` for minimal rescue systems, headless appliances, or lightweight containers.

```bash
mkdir -p ~/custom-os
cp -r /usr/share/archiso/configs/releng ~/custom-os/profile
```

Inspect the profile structure before making changes:

```text
profile/
├── airootfs/                 # Overlay root filesystem (copied to / before pacstrap)
├── efiboot/                  # systemd-boot configuration (required for uefi.systemd-boot)
├── grub/                     # GRUB configuration (required for uefi.grub and loopback)
├── syslinux/                 # Syslinux configuration (required for bios.syslinux)
├── bootstrap_packages        # Packages for bootstrap tarball mode
├── packages.x86_64           # Packages installed into the live ISO environment
├── pacman.conf               # Pacman configuration used by mkarchiso during build
└── profiledef.sh             # Profile metadata, bootmodes, compression, and file_permissions
```

### Step 2: Configure `profiledef.sh`

Configure `profiledef.sh` to define branding, boot modes, filesystem image format, and custom file permissions. Follow modern `archiso` (v86-v91+) rules:

- Set `install_dir` using only lowercase alphanumeric characters `[a-z0-9]` with a maximum length of 30 characters.
- Use modern combined boot mode identifiers: `bios.syslinux`, `uefi.systemd-boot`, or `uefi.grub`.
- Never combine `uefi.systemd-boot` and `uefi.grub` in `bootmodes=()`. `mkarchiso` rejects profiles that enable both UEFI bootloaders simultaneously.
- Do not use deprecated boot mode strings (`bios.syslinux.mbr`, `bios.syslinux.eltorito`, `uefi-x64.systemd-boot.esp`, `uefi-x64.systemd-boot.eltorito`, `uefi-x64.grub.esp`, `uefi-x64.grub.eltorito`).
- Omit `buildmodes` from `profiledef.sh` unless overriding the default (`iso`), and pass `-m` to `mkarchiso` when building `bootstrap` or `netboot` targets.
- Declare all non-default permissions and ownership in the `file_permissions` associative array. Every file in `airootfs/` defaults to `0644` (`0755` for directories) owned by `0:0` (`root:root`). Add a trailing slash (`/`) to apply permissions recursively to a directory.

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="myarchos"
iso_label="MYARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="MyArch OS <https://example.org>"
iso_application="MyArch OS Live/Installation Medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# Fast zstd compression for development/desktop ISOs; use ('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M') for smallest release size
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=(zstd -c -T0 --auto-threads=logical --long -19)
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/root"]="0:0:0750"
  ["/root/.automated_script.sh"]="0:0:0755"
  ["/root/.gnupg"]="0:0:0700"
  ["/usr/local/bin/choose-mirror"]="0:0:0755"
  ["/usr/local/bin/Installation_guide"]="0:0:0755"
  ["/usr/local/bin/livecd-sound"]="0:0:0755"
)
```

### Step 3: Manage Packages and Custom Repositories

Edit `packages.x86_64` (one package per line; comments with `#` and blank lines are ignored):

1. Keep mandatory packages in `packages.x86_64`:
   - `base`
   - A kernel package (`linux`, `linux-lts`, or `linux-zen`) and `linux-firmware`
   - `mkinitcpio` and `mkinitcpio-archiso` (mandatory for generating the live initramfs)
   - `syslinux` (mandatory when `bios.syslinux` is in `bootmodes`)
   - `edk2-shell` and `memtest86+-efi` / `memtest86+` (recommended for UEFI/BIOS diagnostics)

2. Include essential hardware and graphics drivers when building a graphical Desktop Environment or Window Manager to prevent live session freezes:
   - Graphics: `mesa`, `vulkan-intel`, `vulkan-radeon`, `vulkan-nouveau`, `xf86-video-amdgpu`, `xf86-video-ati`, `xf86-video-nouveau`
   - VM guest integration: `qemu-guest-agent`, `spice-vdagent`, `open-vm-tools`, `virtualbox-guest-utils`
   - Audio & networking: `pipewire`, `pipewire-pulse`, `wireplumber`, `networkmanager`

3. Include AUR packages or custom PKGBUILDs via a local repository (`pacstrap` cannot install AUR packages directly):
   - Build the `.pkg.tar.zst` packages in a clean chroot or with `makepkg -s`.
   - Create a local repository directory accessible during build (e.g., `/var/tmp/customrepo`):

```bash
mkdir -p /var/tmp/customrepo
cp /path/to/*.pkg.tar.zst /var/tmp/customrepo/
repo-add /var/tmp/customrepo/customrepo.db.tar.gz /var/tmp/customrepo/*.pkg.tar.zst
```

   - Register `customrepo` in `profile/pacman.conf` above `[core]` (and always keep `DownloadUser` commented out so rootless/unshare builds can access host paths):

```ini
[customrepo]
SigLevel = Optional TrustAll
Server = file:///var/tmp/customrepo
```

   - Add the custom package names to `packages.x86_64`.

### Step 4: Customize the Live Root Filesystem (`airootfs/`)

Files under `profile/airootfs/` are copied to `/` before packages are installed.

**Important:** Do not use `airootfs/root/customize_airootfs.sh`. It is deprecated in `archiso` and causes non-declarative builds. Use native `airootfs/` overlays and Pacman hooks instead:

#### 1. Users, Groups, and Passwords

Choose one of two declarative methods:

- **Method A: Overlay `/etc/passwd`, `/etc/shadow`, `/etc/group`, and `/etc/gshadow` (Recommended)**
  When `airootfs/etc/passwd` exists, `mkarchiso` automatically creates home directories for all users with UID `1000-59999`, copies `/etc/skel/.` into their home directories, sets mode `0750`, and recursively `chown`s the home directory to `UID:GID`.
  Generate a password hash with `openssl passwd -6 "password"` and add the user entries to `airootfs/etc/passwd`, `airootfs/etc/shadow`, `airootfs/etc/group`, and `airootfs/etc/gshadow`. Grant sudo access via `airootfs/etc/sudoers.d/00_liveuser` and register `["/etc/sudoers.d/00_liveuser"]="0:0:0440"` in `file_permissions`.

- **Method B: Build-Time One-Shot Pacman Hook**
  Create `airootfs/etc/pacman.d/hooks/20-liveuser.hook` containing `# remove from airootfs!` (the `releng` cleanup hook automatically strips hooks marked with that comment after package installation):

```ini
# remove from airootfs!
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = base

[Action]
Description = Creating live user...
When = PostTransaction
Depends = shadow
Exec = /usr/bin/useradd -u 1000 -G wheel,audio,video,storage,optical,network -p '' -s /usr/bin/zsh -m liveuser
```

#### 2. Enabling Systemd Services and Display Managers

Since `systemctl enable` cannot run directly outside a chroot, enable services by creating symbolic links in `airootfs/etc/systemd/system/`:

```bash
# Enable NetworkManager
mkdir -p profile/airootfs/etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager.service \
  profile/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service

# Enable a Display Manager (e.g., SDDM, GDM, LightDM) for graphical boot
ln -sf /usr/lib/systemd/system/sddm.service \
  profile/airootfs/etc/systemd/system/display-manager.service

# Set default target to graphical.target when booting into a desktop environment
ln -sf /usr/lib/systemd/system/graphical.target \
  profile/airootfs/etc/systemd/system/default.target
```

#### 3. Locales, Keymaps, and Distribution Branding

- **Locale**: Create `airootfs/etc/locale.gen` with desired UTF-8 locales (e.g., `en_US.UTF-8 UTF-8` and `id_ID.UTF-8 UTF-8`). `glibc` automatically runs `locale-gen` during package installation. Set `LANG=en_US.UTF-8` in `airootfs/etc/locale.conf`.
- **Console Keymap**: Set `KEYMAP=us` in `airootfs/etc/vconsole.conf`.
- **OS Branding**: Provide a custom `airootfs/etc/os-release` (`mkarchiso` automatically appends `IMAGE_ID` and `IMAGE_VERSION`).

### Step 5: Configure Bootloaders and CoW Space

When customizing bootloader configs (`efiboot/loader/entries/*.conf`, `grub/*.cfg`, `syslinux/*.cfg`), preserve the `mkarchiso` template placeholders:

- `%ARCHISO_LABEL%`: Replaced by `iso_label`
- `%INSTALL_DIR%`: Replaced by `install_dir`
- `%ARCH%`: Replaced by `arch` (e.g., `x86_64`)
- `%KERNEL_PARAMS%`: Replaced by `kernel_params_${arch}` (e.g., `kernel_params_x86_64` in `profiledef.sh`)
- `%ARCHISO_UUID%`: Replaced by the ISO modification timestamp UUID
- `%ARCHISO_SEARCH_FILENAME%`: Replaced by `/boot/${iso_uuid}.uuid` (used in `grub/*.cfg`)

**Adjusting Copy-on-Write (CoW) RAM Space:**
By default, `archiso` limits `/run/archiso/cowspace` to `256M`, which causes disk-full errors when starting heavy desktop environments or installing packages in the live session. Increase it by setting `kernel_params_x86_64="cow_spacesize=4G"` in `profiledef.sh` (if `%KERNEL_PARAMS%` is present in bootloader configs) or appending `cow_spacesize=4G` to the `options` / `linux` / `APPEND` lines in `efiboot/loader/entries/*.conf`, `grub/*.cfg`, and `syslinux/*.cfg`.

**Custom Kernels:**
If replacing `linux` with `linux-lts` or `linux-zen` in `packages.x86_64`, update every `vmlinuz-linux` and `initramfs-linux.img` reference in `efiboot/loader/entries/*.conf`, `grub/*.cfg`, and `syslinux/*.cfg` to match the installed kernel (`vmlinuz-linux-lts` / `initramfs-linux-lts.img` or `vmlinuz-linux-zen` / `initramfs-linux-zen.img`).

### Step 6: Validate the Profile Before Building

Always run the bundled validation script (`scripts/validate_profile.sh`) against the profile directory before invoking `mkarchiso` to catch configuration errors early:

```bash
bash scripts/validate_profile.sh ~/custom-os/profile
```

Consult `references/profile-reference.md` for detailed recipes on desktop environments, display manager autologin, custom branding, and boot parameters.

### Step 7: Build and Test the ISO

1. **Grant Pacman Cache Access for Rootless Builds (Optional):**
   `mkarchiso` (v89+) supports running as a regular user via `unshare` (and warns if run via `sudo`). Grant write ACLs on `/var/cache/pacman/pkg` so rootless builds reuse the host package cache instead of downloading to `/tmp`:

```bash
sudo setfacl -m "u:${USER}:rwX" /var/cache/pacman/pkg
```

2. **Run `mkarchiso`:**
   Pass the **profile directory path** (never pass `profiledef.sh` as the path argument):

```bash
mkarchiso -v -r -w /tmp/archiso-work -o ~/custom-os/out ~/custom-os/profile
```

   - `-v`: Enable verbose output
   - `-r`: Automatically remove the working directory after a successful build
   - `-w`: Working directory (use a path with at least 15-25 GB of free space; avoid `/tmp` if RAM/tmpfs is small)
   - `-o`: Output directory for the generated `.iso`

3. **Clean Up Interrupted Builds Safely:**
   If a build fails or is interrupted, check `findmnt` to verify no bind mounts remain inside the work directory before deleting it:

```bash
findmnt -R /tmp/archiso-work
unshare --map-auto --map-root-user -- rm -rf /tmp/archiso-work
```

4. **Test with `run_archiso` (QEMU):**

```bash
# Test UEFI boot (default in modern run_archiso)
run_archiso -u -i ~/custom-os/out/myarchos-*.iso

# Test BIOS boot
run_archiso -i ~/custom-os/out/myarchos-*.iso
```

## Gotchas and Common Failure Modes

- **Passing `profiledef.sh` instead of the directory:** `mkarchiso ... /path/to/profile/profiledef.sh` fails with `Profile ... does not exist!`. Always pass the parent directory `/path/to/profile`.
- **Both `uefi.systemd-boot` and `uefi.grub` enabled:** `mkarchiso` aborts with a validation error if both UEFI bootmodes are listed in `bootmodes=()`. Pick `uefi.systemd-boot` (default in `releng`) or `uefi.grub` (default in `baseline`).
- **Missing `grub` on host when using `uefi.grub`:** Unlike `systemd-boot` (which uses binaries from `pacstrap_dir`), `uefi.grub` runs `grub-mkstandalone` on the **host** system and requires `grub` installed on the host.
- **Uncommented `DownloadUser = alpm` in `pacman.conf`:** Causes permission errors when `pacstrap` runs inside custom working directories or local repositories. Keep `DownloadUser` commented out in `profile/pacman.conf`.
- **Missing video drivers or small CoW space on GUI ISOs:** Always include `mesa` and Xorg/Wayland drivers plus `cow_spacesize=2G` (or `4G`) when booting a Desktop Environment.
- **Missing `file_permissions` entry for `/etc/shadow` or `/etc/sudoers.d/*`:** Since `mkarchiso` copies `airootfs/` with mode `0644`, `sudo` and `su`/`login` will fail unless `/etc/shadow` (`0:0:0400`) and `/etc/sudoers.d/*` (`0:0:0440`) are declared in `file_permissions`.
