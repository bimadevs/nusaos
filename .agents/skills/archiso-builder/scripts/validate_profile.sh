#!/usr/bin/env bash
# Validate an archiso profile directory before running mkarchiso.
# Mirrors official mkarchiso validation rules plus checks for common customization pitfalls.

set -euo pipefail

if (( $# < 1 )); then
  echo "Usage: $0 <path-to-profile-dir>" >&2
  exit 1
fi

PROFILE_DIR="$(realpath -- "$1")"
ERRORS=0
WARNINGS=0

err() {
  printf '[ERROR] %s\n' "$1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  printf '[WARN]  %s\n' "$1" >&2
  WARNINGS=$((WARNINGS + 1))
}

info() {
  printf '[INFO]  %s\n' "$1"
}

info "Validating archiso profile at: ${PROFILE_DIR}"

if [[ ! -d "${PROFILE_DIR}" ]]; then
  err "Profile directory '${PROFILE_DIR}' does not exist (note: pass the profile directory, not profiledef.sh)."
  exit 1
fi

if [[ ! -f "${PROFILE_DIR}/profiledef.sh" ]]; then
  err "Missing '${PROFILE_DIR}/profiledef.sh'."
  exit 1
fi

# Check bash syntax of profiledef.sh
if ! bash -n "${PROFILE_DIR}/profiledef.sh"; then
  err "Syntax error in '${PROFILE_DIR}/profiledef.sh'."
  exit 1
fi

# Run shellcheck if available
if command -v shellcheck &>/dev/null; then
  if ! shellcheck -s bash "${PROFILE_DIR}/profiledef.sh"; then
    warn "shellcheck reported warnings in profiledef.sh."
  fi
fi

# Source profiledef.sh in a subshell-safe manner
iso_name="mkarchiso"
iso_label="MKARCHISO"
iso_publisher="mkarchiso"
iso_application="mkarchiso iso"
iso_version=""
install_dir="mkarchiso"
arch="$(uname -m)"
pacman_conf="/etc/pacman.conf"
packages=""
bootstrap_packages=""
airootfs_image_type="squashfs"
airootfs_image_tool_options=()
bootstrap_tarball_compression=()
buildmodes=()
bootmodes=()
declare -A file_permissions=()

pushd "${PROFILE_DIR}" >/dev/null
# shellcheck disable=SC1091
source "${PROFILE_DIR}/profiledef.sh"
popd >/dev/null

# 1. Validate install_dir
if [[ ! "${install_dir}" =~ ^[a-z0-9]+$ ]]; then
  err "Invalid install_dir '${install_dir}'. Must contain only lowercase [a-z0-9]."
fi
if (( ${#install_dir} > 30 )); then
  err "install_dir '${install_dir}' exceeds 30 characters (${#install_dir})."
fi

# 2. Validate pacman.conf
RESOLVED_PACMAN_CONF="${PROFILE_DIR}/${pacman_conf}"
if [[ "${pacman_conf}" == /* ]]; then
  RESOLVED_PACMAN_CONF="${pacman_conf}"
fi
if [[ ! -f "${RESOLVED_PACMAN_CONF}" ]]; then
  err "Pacman config '${RESOLVED_PACMAN_CONF}' does not exist."
else
  if grep -Eq '^[[:space:]]*DownloadUser[[:space:]]*=' "${RESOLVED_PACMAN_CONF}"; then
    warn "DownloadUser is active in '${RESOLVED_PACMAN_CONF}'. Comment it out to avoid permission errors on custom work directories or local repos."
  fi
fi

# 3. Validate packages file
if [[ -z "${packages}" ]]; then
  if [[ -f "${PROFILE_DIR}/packages.${arch}" ]]; then
    RESOLVED_PACKAGES="${PROFILE_DIR}/packages.${arch}"
  elif [[ -f "${PROFILE_DIR}/packages" ]]; then
    RESOLVED_PACKAGES="${PROFILE_DIR}/packages"
  else
    RESOLVED_PACKAGES="${PROFILE_DIR}/packages.${arch}"
  fi
else
  RESOLVED_PACKAGES="${PROFILE_DIR}/${packages}"
fi

PKG_LIST=()
if [[ ! -f "${RESOLVED_PACKAGES}" ]]; then
  err "Packages file '${RESOLVED_PACKAGES}' does not exist."
else
  mapfile -t PKG_LIST < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "${RESOLVED_PACKAGES}")
  if (( ${#PKG_LIST[@]} < 1 )); then
    err "No packages listed in '${RESOLVED_PACKAGES}'."
  fi
fi

has_pkg() {
  local needle="$1"
  local pkg
  for pkg in "${PKG_LIST[@]}"; do
    [[ "${pkg}" == "${needle}" ]] && return 0
  done
  return 1
}

# Mandatory packages check
for req_pkg in base mkinitcpio mkinitcpio-archiso; do
  if ! has_pkg "${req_pkg}"; then
    err "Mandatory package '${req_pkg}' is missing from '${RESOLVED_PACKAGES}'."
  fi
done

# Check that at least one kernel package is present
KERNEL_FOUND=0
for kpkg in linux linux-lts linux-zen linux-hardened; do
  if has_pkg "${kpkg}"; then
    KERNEL_FOUND=1
    break
  fi
done
if (( KERNEL_FOUND == 0 )); then
  warn "No standard kernel package (linux, linux-lts, linux-zen, linux-hardened) found in '${RESOLVED_PACKAGES}'. Ensure a custom kernel package is included."
fi

# 4. Validate airootfs_image_type
case "${airootfs_image_type}" in
  squashfs|ext4+squashfs|erofs) ;;
  *)
    err "Unsupported airootfs_image_type '${airootfs_image_type}'. Valid types: squashfs, ext4+squashfs, erofs."
    ;;
esac

# 5. Validate bootmodes
if (( ${#bootmodes[@]} < 1 )); then
  err "No bootmodes specified in profiledef.sh."
fi

HAS_SYSTEMD_BOOT=0
HAS_GRUB=0

for bm in "${bootmodes[@]}"; do
  case "${bm}" in
    bios.syslinux)
      if ! has_pkg "syslinux"; then
        err "Bootmode 'bios.syslinux' requires 'syslinux' in '${RESOLVED_PACKAGES}'."
      fi
      if [[ ! -d "${PROFILE_DIR}/syslinux" ]] || ! compgen -G "${PROFILE_DIR}/syslinux/*.cfg" >/dev/null; then
        err "Bootmode 'bios.syslinux' requires '${PROFILE_DIR}/syslinux/*.cfg' files."
      fi
      ;;
    uefi.systemd-boot)
      HAS_SYSTEMD_BOOT=1
      if [[ ! -f "${PROFILE_DIR}/efiboot/loader/loader.conf" ]]; then
        err "Bootmode 'uefi.systemd-boot' requires '${PROFILE_DIR}/efiboot/loader/loader.conf'."
      fi
      if [[ ! -d "${PROFILE_DIR}/efiboot/loader/entries" ]] || ! compgen -G "${PROFILE_DIR}/efiboot/loader/entries/*.conf" >/dev/null; then
        err "Bootmode 'uefi.systemd-boot' requires boot entries in '${PROFILE_DIR}/efiboot/loader/entries/*.conf'."
      fi
      ;;
    uefi.grub)
      HAS_GRUB=1
      if [[ ! -f "${PROFILE_DIR}/grub/grub.cfg" ]]; then
        err "Bootmode 'uefi.grub' requires '${PROFILE_DIR}/grub/grub.cfg'."
      fi
      ;;
    bios.syslinux.mbr|bios.syslinux.eltorito|uefi-x64.systemd-boot.esp|uefi-x64.systemd-boot.eltorito|uefi-ia32.systemd-boot.esp|uefi-ia32.systemd-boot.eltorito|uefi-x64.grub.esp|uefi-x64.grub.eltorito|uefi-ia32.grub.esp|uefi-ia32.grub.eltorito)
      warn "Bootmode '${bm}' is deprecated in modern archiso (v86+). Use 'bios.syslinux', 'uefi.systemd-boot', or 'uefi.grub' instead."
      ;;
    *)
      err "Invalid bootmode '${bm}' in profiledef.sh."
      ;;
  esac
done

if (( HAS_SYSTEMD_BOOT == 1 && HAS_GRUB == 1 )); then
  err "Bootmodes 'uefi.systemd-boot' and 'uefi.grub' cannot be used together in profiledef.sh."
fi

# 6. Validate airootfs and file_permissions
if [[ -f "${PROFILE_DIR}/airootfs/root/customize_airootfs.sh" ]]; then
  warn "'airootfs/root/customize_airootfs.sh' is deprecated by upstream archiso. Migrate to declarative files in airootfs/ and Pacman hooks in airootfs/etc/pacman.d/hooks/."
fi

for path in "${!file_permissions[@]}"; do
  perm_val="${file_permissions[$path]}"
  if [[ ! "${perm_val}" =~ ^[0-9]+:[0-9]+:[0-7]{3,4}$ ]]; then
    err "Invalid file_permissions format for '${path}': '${perm_val}' (expected 'UID:GID:MODE', e.g., '0:0:0755')."
  fi
  if [[ -d "${PROFILE_DIR}/airootfs" && ! -e "${PROFILE_DIR}/airootfs${path}" ]]; then
    warn "file_permissions entry '${path}' does not exist under '${PROFILE_DIR}/airootfs'."
  fi
done

if [[ -f "${PROFILE_DIR}/airootfs/etc/shadow" && -z "${file_permissions["/etc/shadow"]:-}" ]]; then
  err "'airootfs/etc/shadow' exists but ['/etc/shadow']='0:0:0400' is missing from file_permissions in profiledef.sh."
fi

if [[ -f "${PROFILE_DIR}/airootfs/etc/gshadow" && -z "${file_permissions["/etc/gshadow"]:-}" ]]; then
  err "'airootfs/etc/gshadow' exists but ['/etc/gshadow']='0:0:0400' is missing from file_permissions in profiledef.sh."
fi

if [[ -d "${PROFILE_DIR}/airootfs/etc/sudoers.d" ]]; then
  for sudofile in "${PROFILE_DIR}/airootfs/etc/sudoers.d/"*; do
    [[ -e "${sudofile}" ]] || continue
    rel_sudo="/etc/sudoers.d/${sudofile##*/}"
    if [[ -z "${file_permissions["${rel_sudo}"]:-}" && -z "${file_permissions["/etc/sudoers.d/"]:-}" ]]; then
      warn "'airootfs${rel_sudo}' exists without a '0:0:0440' entry in file_permissions."
    fi
  done
fi

info "Validation finished: ${ERRORS} error(s), ${WARNINGS} warning(s)."
if (( ERRORS > 0 )); then
  exit 1
fi
exit 0
