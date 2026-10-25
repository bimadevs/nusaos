#!/usr/bin/env bash
# ==============================================================================
# NusaOS Comprehensive Profile Validation Script
# Verifies profiledef.sh, bootloaders, permissions, customrepo, and desktop configs.
# ==============================================================================
set -euo pipefail

PROFILE_DIR="${1:-profile}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================"
echo "🔍 Menjalankan Pre-flight Validation untuk NusaOS Profile: ${PROFILE_DIR}"
echo "================================================================"

ERRORS=0
WARNINGS=0

error() {
    echo "❌ ERROR: $1" >&2
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo "⚠️  WARNING: $1" >&2
    WARNINGS=$((WARNINGS + 1))
}

success() {
    echo "✅ SUCCESS: $1"
}

# 1. Periksa keberadaan direktori dan berkas wajib
REQUIRED_FILES=(
    "profiledef.sh"
    "pacman.conf"
    "packages.x86_64"
    "efiboot/loader/entries/01-archiso-linux.conf"
    "syslinux/archiso_sys-linux.cfg"
    "airootfs/etc/passwd"
    "airootfs/etc/shadow"
    "airootfs/etc/group"
    "airootfs/etc/sudoers.d/00_liveuser"
    "airootfs/etc/sddm.conf.d/autologin.conf"
    "airootfs/etc/calamares/settings.conf"
    "airootfs/etc/calamares/branding/nusaos/branding.desc"
    "airootfs/usr/local/bin/nusa-welcome"
    "airootfs/usr/local/bin/nusa-mirror"
    "airootfs/etc/skel/.config/hypr/hyprland.conf"
    "airootfs/etc/skel/.config/waybar/config.jsonc"
    "airootfs/etc/skel/.config/kitty/kitty.conf"
    "airootfs/etc/skel/.config/rofi/config.rasi"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "${PROFILE_DIR}/${file}" ]]; then
        error "Berkas wajib tidak ditemukan: ${PROFILE_DIR}/${file}"
    fi
done

# 2. Validasi profiledef.sh
PROFILEDEF="${PROFILE_DIR}/profiledef.sh"
if [[ -f "${PROFILEDEF}" ]]; then
    if ! bash -n "${PROFILEDEF}"; then
        error "Sintaks ${PROFILEDEF} tidak valid!"
    fi

    # Subshell untuk membaca variabel profiledef
    eval "$(
        iso_name=""
        install_dir=""
        bootmodes=()
        declare -A file_permissions=()
        source "${PROFILEDEF}"
        declare -p iso_name install_dir bootmodes file_permissions 2>/dev/null
    )"

    # Validasi install_dir
    if [[ ! "${install_dir}" =~ ^[a-z0-9]{1,30}$ ]]; then
        error "install_dir ('${install_dir}') tidak valid! Wajib hanya huruf kecil alfanumerik [a-z0-9] dan max 30 karakter."
    else
        success "install_dir valid: '${install_dir}'"
    fi

    # Validasi bootmodes
    has_uefi_sdboot=false
    has_uefi_grub=false
    for bm in "${bootmodes[@]}"; do
        if [[ "${bm}" == "uefi.systemd-boot" ]]; then
            has_uefi_sdboot=true
        elif [[ "${bm}" == "uefi.grub" ]]; then
            has_uefi_grub=true
        fi

        # Cek bootmodes usang (deprecated)
        if [[ "${bm}" =~ ^(bios\.syslinux\.(mbr|eltorito)|uefi-x64\.(systemd-boot|grub)\.(esp|eltorito))$ ]]; then
            error "Bootmode usang terdeteksi: '${bm}'! Gunakan 'bios.syslinux', 'uefi.systemd-boot', atau 'uefi.grub'."
        fi
    done

    if [[ "${has_uefi_sdboot}" == true && "${has_uefi_grub}" == true ]]; then
        error "bootmodes tidak boleh menggabungkan 'uefi.systemd-boot' dan 'uefi.grub' sekaligus!"
    elif [[ "${has_uefi_sdboot}" == true || "${has_uefi_grub}" == true ]]; then
        success "bootmodes valid: (${bootmodes[*]})"
    else
        warn "Tidak ada bootmode UEFI yang aktif di bootmodes!"
    fi

    # Validasi file_permissions wajib
    declare -A perms
    eval "$(declare -p file_permissions 2>/dev/null || echo "perms=()")"
    for k in "${!file_permissions[@]}"; do
        perms["$k"]="${file_permissions[$k]}"
    done

    REQUIRED_PERMS=(
        "/etc/shadow"
        "/etc/gshadow"
        "/etc/sudoers.d/00_liveuser"
        "/usr/local/bin/nusa-welcome"
        "/usr/local/bin/nusa-mirror"
    )
    for req_p in "${REQUIRED_PERMS[@]}"; do
        if [[ -z "${perms[$req_p]:-}" ]]; then
            error "file_permissions wajib menyertakan izin untuk '${req_p}'!"
        else
            success "Izin berkas terdaftar: ${req_p} -> ${perms[$req_p]}"
        fi
    done
fi

# 3. Validasi Bootloader & Kecocokan Kernel
PACKAGES_FILE="${PROFILE_DIR}/packages.x86_64"
if [[ -f "${PACKAGES_FILE}" ]]; then
    KERNEL_NAME="linux"
    if grep -qE '^linux-zen$' "${PACKAGES_FILE}"; then
        KERNEL_NAME="linux-zen"
        success "Kernel terdeteksi di packages.x86_64: linux-zen"
    elif grep -qE '^linux$' "${PACKAGES_FILE}"; then
        KERNEL_NAME="linux"
        warn "Kernel default 'linux' terdeteksi, bukan 'linux-zen'."
    else
        error "Tidak ada paket kernel ('linux' atau 'linux-zen') di packages.x86_64!"
    fi

    # Cek entri efiboot
    EFIBOOT_ENTRY="${PROFILE_DIR}/efiboot/loader/entries/01-archiso-linux.conf"
    if [[ -f "${EFIBOOT_ENTRY}" ]]; then
        if ! grep -q "vmlinuz-${KERNEL_NAME}" "${EFIBOOT_ENTRY}"; then
            error "Entri efiboot (${EFIBOOT_ENTRY}) tidak merujuk ke vmlinuz-${KERNEL_NAME}!"
        else
            success "Entri efiboot merujuk ke vmlinuz-${KERNEL_NAME}"
        fi

        if ! grep -q "cow_spacesize=" "${EFIBOOT_ENTRY}"; then
            warn "Parameter 'cow_spacesize=' tidak ditemukan pada options di ${EFIBOOT_ENTRY}."
        else
            success "Parameter 'cow_spacesize' terpasang pada efiboot"
        fi
    fi

    # Cek entri syslinux
    SYSLINUX_ENTRY="${PROFILE_DIR}/syslinux/archiso_sys-linux.cfg"
    if [[ -f "${SYSLINUX_ENTRY}" ]]; then
        if ! grep -q "vmlinuz-${KERNEL_NAME}" "${SYSLINUX_ENTRY}"; then
            error "Entri syslinux (${SYSLINUX_ENTRY}) tidak merujuk ke vmlinuz-${KERNEL_NAME}!"
        else
            success "Entri syslinux merujuk ke vmlinuz-${KERNEL_NAME}"
        fi

        if ! grep -q "cow_spacesize=" "${SYSLINUX_ENTRY}"; then
            warn "Parameter 'cow_spacesize=' tidak ditemukan pada APPEND di ${SYSLINUX_ENTRY}."
        else
            success "Parameter 'cow_spacesize' terpasang pada syslinux"
        fi
    fi
fi

# 4. Validasi Customrepo
CUSTOMREPO_DB="${ROOT_DIR}/customrepo/x86_64/customrepo.db.tar.gz"
if [[ ! -f "${CUSTOMREPO_DB}" ]]; then
    error "Database repositori lokal '${CUSTOMREPO_DB}' tidak ditemukan! Jalankan 'scripts/setup_customrepo.sh'."
else
    success "Database customrepo ditemukan: ${CUSTOMREPO_DB}"
fi

# 5. Validasi User Live & Autologin
PASSWD_FILE="${PROFILE_DIR}/airootfs/etc/passwd"
if [[ -f "${PASSWD_FILE}" ]]; then
    if grep -qE '^nusa:' "${PASSWD_FILE}"; then
        success "Pengguna live 'nusa' terdaftar di /etc/passwd"
    else
        error "Pengguna live 'nusa' tidak ditemukan di ${PASSWD_FILE}!"
    fi
fi

echo "================================================================"
if [[ ${ERRORS} -gt 0 ]]; then
    echo "❌ Validasi GAGAL dengan ${ERRORS} error dan ${WARNINGS} warning!"
    exit 1
else
    echo "✅ Validasi LULUS SEMPURNA dengan 0 error dan ${WARNINGS} warning!"
    exit 0
fi
