# Case Study: NusaOS — Desktop Arch ISO Build

Real session: 141-package XFCE desktop ISO built with archiso, validated
end-to-end before the 20-min build. Documents the gotchas that hit
during copy + edit of `releng` profile, and what fixed them.

## Final profile stats

| Item | Value |
|------|-------|
| `iso_name` | `nusaos` |
| `iso_label` | `NUSAOS` (static, 6 char) |
| `install_dir` | `nusaos` (6 char) |
| `arch` | `x86_64` |
| `bootmodes` | `bios.syslinux.mbr bios.syslinux.eltorito uefi.grub` |
| Packages | 141 (all in Arch official repos) |
| DE | XFCE (paket individual, no group names) |
| DM | SDDM |
| Audio | PipeWire + wireplumber |
| Network | NetworkManager + iwd fallback |
| Installer | `archinstall` (calamares fallback, see pitfall) |
| Kernel | `linux-lts` + `linux-firmware` |
| Timezone | Asia/Jakarta |
| Locales | en_US.UTF-8, id_ID.UTF-8 |

## Validator caught 4 issues before build

Running `scripts/validate_profile.sh` (linked file) saved a 20-min
build. Order of failures and fixes:

### 1. `xfce4` / `xfce4-goodies` are group names, not packages

**Symptom**: `MISSING from repos: xfce4 xfce4-goodies`.

**Why**: mkarchiso uses `pacstrap`, which doesn't expand group syntax.
Only individual package names work.

**Fix**: `pacman -Sg xfce4 xfce4-goodies` → list each package:
```
xfce4-panel xfce4-session xfce4-settings xfce4-terminal
xfce4-screenshooter xfce4-taskmanager xfce4-power-manager
xfwm4 xfdesktop xfconf thunar thunar-volman thunar-archive-plugin
thunar-media-tags-plugin ristretto mousepad
```

### 2. `breeze-cursor-theme` doesn't exist

**Symptom**: `MISSING from repos: breeze-cursor-theme`.

**Fix**: it's `breeze-cursors` (extra repo, plasma group).

### 3. `p7zip` was renamed to `7zip`

**Symptom**: `MISSING from repos: p7zip`.

**Fix**: use `7zip` (current name in `extra`).

### 4. `calamares` not in official Arch repos

**Symptom**: `MISSING from repos: calamares`.

**Why**: only CachyOS / EndeavourOS / Manjaro ship it in their
distro-specific repos. archiso default uses Arch official repos only.

**Fix for v1**: drop `calamares`, use `archinstall` (CLI, in `extra`).
For v1.1: add custom repo with `calamares` from
`https://github.com/endeavouros-team/calamares` build.

### 5. `lsusb` / `lspci` / `xdg-terminal-exec`

**Symptom**: `MISSING from repos: lsusb lspci xdg-terminal-exec`.

**Why**: `lsusb` is a binary from `usbutils`, `lspci` from `pciutils`.
`xdg-terminal-exec` simply doesn't exist as a package yet.

**Fix**: remove from list; the binaries come with their meta-packages
which are already listed.

## Duplicate cascade from copy-paste

Initial `packages.x86_64` had 7 duplicates (`bolt`, `f2fs-tools`,
`openssh`, `pciutils`, `unzip`, `usbutils`, `wget`) because of
copy-pasting releng's "live env essentials" section on top of
desktop sections. The dedup step is essential — don't skip it.

Final structure: 21 sections, 0 duplicates, all valid.

## `iso_label` literal-vs-expanded trap

The skill's own example showed `iso_label="MYOS_$(date +%Y%m)"`
which is 20 char **literal** string. `validate_profile.sh` parses
the raw bash value (no shell expansion), so it fails the 11-char
check.

**Fix**: keep `iso_label` short and static. `iso_version` already
encodes the date — use that for version tracking instead.

## airootfs gotchas

### `customize_airootfs.sh` requires `file_permissions` entry

Without `["/root/customize_airootfs.sh"]="0:0:755"` in
`profiledef.sh`, mkarchiso writes the script as non-executable
(644) and skips it silently. No error message. Validator warns
about this.

### `chpasswd` without `-e`

The skill templates include `echo 'user:pass' | chpasswd` without
`-e`. The `-e` flag expects a pre-computed hash. If you use `-e`
with plaintext, chpasswd silently treats plaintext as a hash and
the password won't work.

### Locale-gen requires a pacman hook OR explicit call

`/etc/locale.gen` lists locales but doesn't generate them. Either:
1. Run `locale-gen` in `customize_airootfs.sh` (chosen here), or
2. Create `airootfs/etc/pacman.d/hooks/zz-locale.hook` with
   `# remove from airootfs!` comment at the bottom so it's deleted
   post-build.

Both work. Hook + customize combo is the most robust.

## Files written (final)

```
~/nusaos-build/profile/
├── profiledef.sh
├── packages.x86_64         (141 packages, 21 sections)
├── pacman.conf             (core + extra + multilib)
└── airootfs/
    ├── etc/
    │   ├── hostname, hosts, locale.gen, locale.conf,
    │   │   vconsole.conf, os-release, issue
    │   ├── localtime → /usr/share/zoneinfo/Asia/Jakarta
    │   ├── mkinitcpio.conf (zstd, hooks include kms)
    │   ├── pacman.d/mirrorlist (4 Indonesia mirrors)
    │   ├── pacman.d/hooks/zz-locale.hook
    │   ├── NetworkManager/conf.d/dhcp-client-dispatcher.conf
    │   ├── sddm.conf.d/theme.conf (breeze)
    │   ├── sudoers.d/10_wheel
    │   ├── systemd/system/multi-user.target.wants/ →
    │   │   NetworkManager, bluetooth, tlp, acpid, upower
    │   ├── systemd/system/display-manager.target.wants/ → sddm
    │   ├── xdg/reflector/reflector.conf
    │   ├── modules-load.d/nusaos.conf (loop, squashfs, overlay)
    │   └── skel/.zshrc, .bashrc, .config/user-dirs.{dirs,locale}
    └── root/customize_airootfs.sh (locale-gen + motd)
```

## Build command (user runs manually — sudo required)

```bash
sudo mkarchiso -v -r \
  -w /tmp/archiso-work \
  -o ~/nusaos-build/out \
  ~/nusaos-build/profile
```

Estimated output: `~/nusaos-build/out/nusaos-YYYY.MM.DD-x86_64.iso`
(~800 MB squashfs-compressed).

## QEMU smoke test

```bash
run_archiso -u -i ~/nusaos-build/out/nusaos-*.iso   # UEFI
run_archiso -i ~/nusaos-build/out/nusaos-*.iso       # BIOS
```

## Lessons for next time

1. **Run `validate_profile.sh` first** — caught 4 classes of errors
   in <1s. Build takes 20min, validator is essentially free.
2. **Don't trust skill examples blindly** — the `iso_label` example
   itself was wrong. Test against the validator.
3. **Clean releng defaults before adding** — releng ships with
   ~128 rescue packages. Most duplicate common desktop needs.
4. **Use `archinstall` for v1** — calamares is distro-specific. Don't
   add CachyOS / EndeavourOS repos just for it on first build.
5. **Validator parses literal strings** — no shell expansion in
   config values unless the field is explicitly eval'd by mkarchiso.
