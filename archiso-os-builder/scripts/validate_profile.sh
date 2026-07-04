#!/usr/bin/env bash
# validate_profile.sh — run BEFORE mkarchiso to catch missing packages,
# duplicates, and broken scripts. Cheap (<5s) vs. a 20-min build that
# dies at 80% on a typo.
#
# Usage: ./validate_profile.sh [profile_dir]
# Default profile dir: ./archlive (relative to CWD)
#
set -euo pipefail

PROFILE_DIR="${1:-./archlive}"

if [ ! -d "$PROFILE_DIR" ]; then
  echo "ERROR: profile dir not found: $PROFILE_DIR" >&2
  exit 1
fi

cd "$PROFILE_DIR"

echo "=== Profile: $(pwd) ==="
echo

# 1. Required files
for f in profiledef.sh pacman.conf packages.x86_64 airootfs; do
  if [ ! -e "$f" ]; then
    echo "MISSING FILE: $f"
    exit 1
  fi
done
echo "[OK] all required files present"

# 2. Syntax check shell scripts
for s in profiledef.sh airootfs/root/customize_airootfs.sh; do
  if [ -f "$s" ]; then
    if bash -n "$s" 2>/dev/null; then
      echo "[OK] syntax: $s"
    else
      echo "SYNTAX ERROR in $s:"
      bash -n "$s"
      exit 1
    fi
  fi
done

# 3. Duplicate packages
DUPES=$(sort packages.x86_64 | uniq -d | grep -v '^$' || true)
if [ -n "$DUPES" ]; then
  echo "DUPLICATE PACKAGES:"
  echo "$DUPES"
  exit 1
fi
echo "[OK] no duplicate packages"

# 4. All packages exist in repos
TMP=$(mktemp)
pacman -Ssq > "$TMP" 2>/dev/null
PKGS=$(grep -v '^#' packages.x86_64 | grep -v '^$' || true)
MISSING=""
for p in $PKGS; do
  if ! grep -qx "$p" "$TMP"; then
    MISSING="$MISSING $p"
  fi
done
rm -f "$TMP"
if [ -n "$MISSING" ]; then
  echo "MISSING from repos:$MISSING"
  exit 1
fi
echo "[OK] all $(echo "$PKGS" | wc -w) packages exist in repos"

# 5. iso_label length (<=11) and char set
LABEL=$(grep '^iso_label=' profiledef.sh | head -1 | cut -d'"' -f2)
if [ -z "$LABEL" ]; then
  echo "WARN: iso_label not set (defaults to ARCH_YYYYMM)"
elif [ ${#LABEL} -gt 11 ]; then
  echo "iso_label too long (${#LABEL} > 11): $LABEL"
  exit 1
elif ! echo "$LABEL" | grep -qE '^[A-Z0-9_]+$'; then
  echo "iso_label must be [A-Z0-9_]: $LABEL"
  exit 1
fi
echo "[OK] iso_label: $LABEL"

# 6. install_dir length (<=8) and char set
IDIR=$(grep '^install_dir=' profiledef.sh | head -1 | cut -d'"' -f2)
if [ -z "$IDIR" ]; then
  echo "ERROR: install_dir not set"
  exit 1
fi
if [ ${#IDIR} -gt 8 ]; then
  echo "install_dir too long (${#IDIR} > 8): $IDIR"
  exit 1
fi
if ! echo "$IDIR" | grep -qE '^[a-z0-9]+$'; then
  echo "install_dir must be [a-z0-9]: $IDIR"
  exit 1
fi
echo "[OK] install_dir: $IDIR"

# 7. customize_airootfs.sh: executable bit declared
if [ -f airootfs/root/customize_airootfs.sh ]; then
  if grep -q 'customize_airootfs.sh.*0:0:755' profiledef.sh; then
    echo "[OK] customize_airootfs.sh marked executable in file_permissions"
  else
    echo "WARN: customize_airootfs.sh exists but no file_permissions entry — may not run"
  fi
fi

# 8. Kernel consistency: installed kernel package vs bootloader paths
# and mkinitcpio preset. Catches the "linux-lts install but vmlinuz-linux
# referenced everywhere" trap that produces an unbootable ISO.
KERNELS=$(grep -E '^linux$|^linux-lts$|^linux-zen$|^linux-hardened$' packages.x86_64 2>/dev/null | sort -u)
if [ -n "$KERNELS" ]; then
  BOOT_PATHS=$(grep -rhE 'vmlinuz-[a-z0-9._-]+|initramfs-[a-z0-9._-]+\.img' \
    grub/ efiboot/ syslinux/ airootfs/etc/mkinitcpio.d/ 2>/dev/null \
    | grep -oE 'vmlinuz-[a-z0-9._-]+|initramfs-[a-z0-9._-]+\.img' \
    | sort -u)
  MISMATCH=0
  for k in $KERNELS; do
    if ! echo "$BOOT_PATHS" | grep -q "vmlinuz-$k"; then
      echo "WARN: kernel '$k' installed but no 'vmlinuz-$k' reference in grub/efiboot/syslinux/preset"
      MISMATCH=1
    fi
    if ! echo "$BOOT_PATHS" | grep -q "initramfs-$k"; then
      echo "WARN: kernel '$k' installed but no 'initramfs-$k.img' reference in grub/efiboot/syslinux/preset"
      MISMATCH=1
    fi
  done
  if [ $MISMATCH -eq 0 ]; then
    echo "[OK] kernel/bootloader paths consistent"
  else
    echo "BLOCKER: kernel/bootloader path mismatch — ISO will not boot"
  fi
fi

# 9. Live user existence vs motd/hints
if [ -f airootfs/root/customize_airootfs.sh ]; then
  REFERENCED=$(grep -rhE 'login[: ]+[a-z][a-z0-9_-]+' \
    airootfs/etc/motd airootfs/etc/issue airootfs/root/customize_airootfs.sh 2>/dev/null \
    | grep -oE 'login[: ]+[a-z][a-z0-9_-]+' | awk '{print $2}' | sort -u || true)
  if [ -n "$REFERENCED" ]; then
    for u in $REFERENCED; do
      [ "$u" = "root" ] && continue
      if grep -q "^$u:" airootfs/etc/passwd 2>/dev/null; then
        echo "[OK] motd user '$u' exists in /etc/passwd"
      elif grep -qE "useradd[^|]*\\b$u\\b" airootfs/root/customize_airootfs.sh 2>/dev/null; then
        echo "[OK] motd user '$u' created in customize_airootfs.sh"
      else
        echo "WARN: motd references login '$u' but no entry in /etc/passwd or useradd in customize_airootfs.sh"
      fi
    done
  fi
fi

# 10. Service manager consistency: NM enabled + systemd-networkd files
if [ -f airootfs/root/customize_airootfs.sh ]; then
  NM_ENABLED=$(grep -c 'enable.*NetworkManager\.service' airootfs/root/customize_airootfs.sh 2>/dev/null || echo 0)
  NWD_FILES=$(find airootfs/etc/systemd/network -name '*.network' 2>/dev/null | wc -l)
  if [ "${NM_ENABLED:-0}" -gt 0 ] && [ "$NWD_FILES" -gt 0 ]; then
    echo "WARN: NetworkManager enabled but $NWD_FILES systemd-networkd .network files exist (dead config)"
    echo "      remove airootfs/etc/systemd/network/ OR don't enable NetworkManager"
  fi
fi

# 11. SDDM theme vs installed packages
if [ -f airootfs/etc/sddm.conf.d/theme.conf ]; then
  THEME=$(grep -oE '^ThemeCurrent=[^[:space:]#]+' airootfs/etc/sddm.conf.d/theme.conf | cut -d= -f2)
  if [ "$THEME" = "breeze" ] && ! grep -qx 'breeze' packages.x86_64; then
    echo "WARN: SDDM ThemeCurrent=breeze but 'breeze' package not in packages.x86_64 (fallback to default)"
  fi
fi

# 12. Reflector vs manual mirrorlist
if [ -f airootfs/root/customize_airootfs.sh ] \
   && grep -q 'enable.*reflector\.service' airootfs/root/customize_airootfs.sh \
   && [ -f airootfs/etc/pacman.d/mirrorlist ]; then
  echo "WARN: reflector.service enabled AND manual mirrorlist present — reflector will overwrite it at boot"
fi

# 13. Deprecated packages (Arch 2026)
for dep in wireless_tools p7zip gnome-icon-theme reiserfsprogs; do
  if grep -qx "$dep" packages.x86_64; then
    echo "WARN: deprecated package '$dep' in packages.x86_64 (removed/renamed in Arch 2026)"
  fi
done

echo
echo "=== Profile ready for build ==="
echo "Run: sudo mkarchiso -v -w /tmp/archiso-work -o ./out ."
