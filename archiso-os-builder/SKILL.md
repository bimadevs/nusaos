---
name: archiso-os-builder
version: 0.2.0
author: Hermes
description: Build custom Arch Linux live ISOs with archiso profiles.
metadata:
  hermes:
    tags: [Archiso, Arch, Linux, ISO, Live, OS]
platforms: [linux]
---

# Archiso OS Builder

Build custom Arch Linux live ISO, netboot artifacts, and bootstrap tarballs via `mkarchiso`. Covers full workflow from profile copy to QEMU smoke test. References official ArchWiki (rev 880026) + upstream `README.profile.rst` (master branch).

Does NOT cover: AUR package building, ISO signing, Secure Boot enrollment, multi-arch cross-builds. Stdlib-only on agent side; build itself is `pacman` + bash.

## When to Use

- User wants a custom Arch-derived distro ISO (desktop, rescue, installer).
- User wants reproducible live USB with fixed packages and config.
- User asks about `mkarchiso`, `profiledef.sh`, `airootfs`, bootmodes, or build failures.
- User wants netboot artifacts or bootstrap tarballs for container/VM seeding.

## Prerequisites

- **Host**: Arch Linux (or derivative). Non-Arch may work but unmaintained.
- **Packages** (`sudo pacman -S archiso`): `arch-install-scripts awk dosfstools e2fsprogs findutils grub gzip libarchive libisoburn mtools openssl pacman sed squashfs-tools`
- For `erofs` image type: `erofs-utils`
- QEMU test: `qemu-desktop` + `edk2-ovmf`
- **Root** required for `mkarchiso` (mount bind + chroot build).

Profile `releng` lives at `/usr/share/archiso/configs/releng/` — **read-only**, always copy first. Source code: <https://gitlab.archlinux.org/archlinux/archiso>.

## How to Run

All build steps through `terminal` tool (needs `sudo`). Profile editing through `read_file` / `patch` / `write_file`. Profile validation through the skill's `scripts/validate_profile.sh`. For long builds, use `terminal(background=true, notify_on_complete=true)`.

## Quick Reference

- Official docs: `/usr/share/doc/archiso/README.profile.rst`, <https://gitlab.archlinux.org/archlinux/archiso/-/blob/master/docs/README.profile.rst>
- Profile source: `/usr/share/archiso/configs/releng/` (full) and `baseline/` (minimal)
- Profile structure: `profiledef.sh`, `pacman.conf`, `packages.x86_64` (or `packages`), `airootfs/`, plus optional `efiboot/`, `grub/`, `syslinux/`
- Build ISO: `sudo mkarchiso -v -w /tmp/archiso-work -o ./out <profile_dir>`
- Build + cleanup: add `-r`
- QEMU BIOS: `run_archiso -i ./out/*.iso`
- QEMU UEFI: `run_archiso -u -i ./out/*.iso`
- Pre-build validation: `bash /home/bimadev/.hermes/skills/system-administration/archiso-os-builder/scripts/validate_profile.sh <profile_dir>`
- Template IDs in boot configs: `%ARCHISO_LABEL%`, `%INSTALL_DIR%`, `%ARCH%`, `%ARCHISO_UUID%`, `%ARCHISO_SEARCH_FILENAME%` (GRUB only)
- Mandatory pkgs: `mkinitcpio`, `mkinitcpio-archiso`

## Procedure

### 1. Setup workspace + copy profile

```
mkdir -p ~/archlive-work && cd ~/archlive-work
cp -r /usr/share/archiso/configs/releng/ archlive
ls archlive   # expect: profiledef.sh, pacman.conf, packages.x86_64, airootfs/, efiboot/, grub/, syslinux/
```

### 2. Edit `profiledef.sh`

All variables with defaults per README.profile.rst (master branch):

| Variable | Type | Default | Notes |
|----------|------|---------|-------|
| `iso_name` | string | `mkarchiso` | First part of ISO filename |
| `iso_label` | string | `MKARCHISO` | Volume label, max 11 chars, `[A-Z0-9_]` — keep **static**, timestamp goes in `iso_version` |
| `iso_publisher` | string | `mkarchiso` | Free-form publisher string |
| `iso_application` | string | `mkarchiso iso` | Free-form use-case string |
| `iso_version` | string | `""` | Date here: `$(date +%Y.%m.%d)` |
| `install_dir` | string | `mkarchiso` | Max 8 chars, `[a-z0-9]` |
| `buildmodes` | array | `('iso')` | Optional. `iso`, `bootstrap`, `netboot`. Omit = ISO only |
| `bootmodes` | array | — | One or more: `bios.syslinux`, `uefi.grub`, `uefi.systemd-boot` |
| `arch` | string | `uname -m` | Architecture, also selects `packages.${arch}` |
| `packages` | path | `packages.${arch}` | Package list file path |
| `bootstrap_packages` | path | `bootstrap_packages.${arch}` | Package list for bootstrap mode |
| `pacman_conf` | path | host's `/etc/pacman.conf` | Pacman config for build |
| `airootfs_image_type` | string | `squashfs` | `squashfs`, `ext4+squashfs`, `erofs` |
| `airootfs_image_tool_options` | array | — | Extra opts to `mksquashfs` / `mkfs.erofs` |
| `bootstrap_tarball_compression` | array | `cat` | e.g. `(zstd -c -T0 --long -19)` |
| `file_permissions` | assoc array | — | `["/path"]="uid:gid:mode"` — trailing `/` recurses |

Example:
```bash
iso_name="myos"
iso_label="MYOS"                  # static, <=11, [A-Z0-9_]
iso_publisher="BimaDev; https://example.org;"
iso_application="MyOS Live System"
iso_version="$(date +%Y.%m.%d)"
install_dir="myos"                # <=8, [a-z0-9]
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
packages="packages.x86_64"
airootfs_image_type="squashfs"
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/root"]="0:0:0750"
  ["/root/.ssh"]="0:0:0700"
)
```

Corresponding directories `grub/`, `syslinux/`, `efiboot/` must exist when their `bootmodes` are selected.

### 3. Edit `packages.x86_64`

One package per line, `#` comments allowed. **Group names don't work** — `xfce4` is a group, not a package. mkarchiso uses `pacstrap`, which doesn't expand groups. List individual packages. Check group contents: `pacman -Sg xfce4`.

Mandatory: `mkinitcpio` + `mkinitcpio-archiso` (see README.profile.rst §packages.arch).

### 4. Pre-build validation (WAJIB)

Build takes 15-30 min — validate first. The skill ships a 13-check validator (L1):

```bash
bash /home/bimadev/.hermes/skills/system-administration/archiso-os-builder/scripts/validate_profile.sh ~/archlive-work/archlive
```

Checks: required files, shell syntax, duplicate packages, missing packages from repos, iso_label constraints, install_dir constraints, customize_airootfs.sh executable bit, kernel/bootloader path consistency, motd user existence, NM+networkd conflict, SDDM theme, reflector+mirrorlist conflict, deprecated packages.

For manual spot-check:
```bash
# kernel consistency across grub/efiboot/syslinux preset paths
grep -r 'vmlinuz-' grub/ efiboot/ syslinux/ airootfs/etc/mkinitcpio.d/
```

### 5. Edit `pacman.conf`

For custom local repo, add at the **top** of the file:
```ini
[customrepo]
SigLevel = Optional TrustAll
Server = file:///path/to/customrepo
```

Note per README.profile.rst: `CacheDir` is only used if non-default AND differs from system's `CacheDir`. `HookDir` is always overridden to the work dir's airootfs. `RootDir`, `LogFile`, `DBPath` are always removed (mkarchiso uses `pacstrap -r`).

### 6. Customize `airootfs/`

Files in `airootfs/` overlay onto live `/`. Copied **before** packages install — package files overwrite conflicting airootfs files (unless package declares them as backup). Default permissions: 644 files, 755 dirs, root:root. Override via `file_permissions` in profiledef.sh. Trailing `/` on a directory key = recursive application.

```bash
cp /etc/nftables.conf archlive/airootfs/etc/
mkdir -p archlive/airootfs/root/.ssh
cat ~/.ssh/id_ed25519.pub >> archlive/airootfs/root/.ssh/authorized_keys
openssl passwd -6 >> archlive/airootfs/etc/shadow   # paste after root::
```

### 7. Users + passwords (airootfs method)

Edit `airootfs/etc/passwd`, `shadow`, `group`, `gshadow` directly. See ArchWiki §Users and passwords. If these files exist, they must contain root.

Alternatively, create users in `customize_airootfs.sh` (see template).

### 8. systemd units — symlink manually

```bash
mkdir -p archlive/airootfs/etc/systemd/system/multi-user.target.wants
ln -s /usr/lib/systemd/system/sshd.service \
    archlive/airootfs/etc/systemd/system/multi-user.target.wants/
```

**Login manager**: create `display-manager.service` symlink:
```bash
ln -s /usr/lib/systemd/system/sddm.service \
    archlive/airootfs/etc/systemd/system/display-manager.service
```

Auto-login getty: edit `airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`.

### 9. `customize_airootfs.sh`

Script at `airootfs/root/customize_airootfs.sh` is chroot-executed by mkarchiso after packages install, then **automatically deleted** from final ISO. Ideal for: `useradd`, `chpasswd`, `locale-gen`, `systemctl enable`, dotfile copy.

**REQUIRED**: `file_permissions` entry `["/root/customize_airootfs.sh"]="0:0:755"` — otherwise it's 644 non-executable and silently skipped (no error).

Template at: `templates/customize_airootfs.sh` in this skill directory.

Key patterns:
```bash
# Plain chpasswd (NO -e flag — -e expects hash, not plaintext)
echo 'live:mypass' | chpasswd
echo 'root:mypass' | chpasswd

# Locale-gen must be run explicitly unless using pacman hook
locale-gen

# Enable services
systemctl enable NetworkManager.service
```

### 10. Locale/keymap

- `airootfs/etc/locale.gen` — list enabled locales (e.g. `en_US.UTF-8 UTF-8`)
- `airootfs/etc/locale.conf` — default locale (e.g. `LANG=en_US.UTF-8`)
- `airootfs/etc/vconsole.conf` — console keymap (e.g. `KEYMAP=us`)

Locale-gen can be triggered via pacman hook (see ArchWiki §Locales) or explicitly in `customize_airootfs.sh`. Hooks with `# remove from airootfs!` are auto-deleted post-build by releng's cleanup hook.

### 11. Build ISO

```bash
sudo mkarchiso -v -r -w /tmp/archiso-work -o ./out .
```

- `-w` work dir (tmpfs recommended for speed)
- `-r` delete work dir on success
- `-o` output dir (default `./out`)
- Last argument = **profile directory**, not the `profiledef.sh` file

### 12. Test in QEMU

```bash
run_archiso -i ./out/myos-*.iso           # BIOS
run_archiso -u -i ./out/myos-*.iso        # UEFI
```

Auto-forwards host:60022 → guest:22 for SSH test.

### 13. Cowspace size

If live session shows `error: partition / too full`, adjust on the fly:
```bash
mount -o remount,size=2G /run/archiso/cowspace
```
Or add `cow_spacesize=2G` to bootloader configs (`grub/*.cfg`, `efiboot/loader/entries/*.cfg`, `syslinux/*.cfg`).

## Pitfalls

- **Profile read-only** — always copy from `/usr/share/archiso/configs/` first.
- **Mount bind hang** — if `mkarchiso` is interrupted, run `findmnt` and unmount binds in `work/x86_64/airootfs/` before `rm -rf work`. Failure risks data loss on external devices.
- **Kernel mismatch (BLOCKER)** — if installing `linux-lts` instead of `linux`, update ALL of: (1) mkinitcpio preset name and `ALL_kver`/`archiso_image` paths, (2) bootloader configs (grub, efiboot, syslinux) — replace every `vmlinuz-linux` → `vmlinuz-linux-lts` and `initramfs-linux.img` → `initramfs-linux-lts.img`, (3) package list matches.
- **Group packages don't work** — mkarchiso uses `pacstrap`, not `pacman -S --needed`. List individual packages.
- **AUR/extra pkgs** — cannot list directly in `packages.x86_64`. Build `.pkg.tar.zst` first and serve via custom local repo in `pacman.conf`.
- **SDDM Wayland default + XFCE = black screen** — SDDM 0.21+ defaults to Wayland; XFCE 4.18 only supports X11. Add `[General] DisplayServer=x11` in `airootfs/etc/sddm.conf.d/theme.conf`. Full diagnosis: `references/black-screen-sddm-xfce.md`.
- **customize_airootfs.sh needs file_permissions 755** — silently skipped if not executable.
- **chpasswd WITHOUT -e** — `-e` expects a hash, not plaintext. Use bare `chpasswd` for plain passwords.
- **reflector overwrites manual mirrorlist** — don't enable `reflector.service` if you placed a custom `mirrorlist` in airootfs.
- **NetworkManager enabled + systemd-networkd .network files** — dead config. NM ignores `.network` files. Pick one.
- **SDDM theme `breeze` needs `breeze` package** — `breeze-icons` and `breeze-cursors` are not the SDDM theme. Install `breeze` or change `ThemeCurrent=`.
- **iso_label must be static** — `$(date)` is NOT expanded during validation. Label max 11 chars `[A-Z0-9_]`. Timestamp goes in `iso_version`.
- **install_dir max 8 chars `[a-z0-9]`** — hard constraint.
- **CacheDir behavior** — mkarchiso only uses custom `CacheDir` if it's non-default AND differs from host's cache.
- **HookDir always overridden** — to `/etc/pacman.d/hooks` in work dir's airootfs. Profile hooks work fine.
- **Deprecated packages (Arch 2026)** — `arc-gtk-theme`, `arc-icon-theme`, `gnome-icon-theme`, `reiserfsprogs` removed. `p7zip` → `7zip`. `wireless_tools` → `iwd`. `breeze-cursor-theme` → `breeze-cursors`.
- **CachyOS packages on first build** — `cachyos-hello` etc. need CachyOS keyring. Build with official Arch repos first, add CachyOS-specific repos after PoC.

## Verification

```bash
# ISO exists
ls -lh ./out/*.iso
# ISO 9660 valid
file ./out/myos-*.iso    # → "ISO 9660 CD-ROM" / "DOS/MBR boot sector"
# Boot files present
isoinfo -f -i ./out/myos-*.iso | grep -E 'vmlinuz|initramfs'
# QEMU smoke test
run_archiso -u -i ./out/myos-*.iso
```
