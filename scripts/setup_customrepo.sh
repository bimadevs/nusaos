#!/usr/bin/env bash
# ==============================================================================
# NusaOS Custom Repository Setup Script
# Manages local PKGBUILDs, downloads binary packages, and generates pacman repo database.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CUSTOMREPO_DIR="${ROOT_DIR}/customrepo/x86_64"
PKGBUILDS_DIR="${ROOT_DIR}/customrepo/PKGBUILDs"

echo "================================================================"
echo "📦 Mempersiapkan Custom Repository NusaOS: ${CUSTOMREPO_DIR}"
echo "================================================================"

mkdir -p "${CUSTOMREPO_DIR}"

run_makepkg() {
    if [[ $EUID -eq 0 ]]; then
        # Inside Docker or root environment, makepkg requires a non-root user
        if ! id -u builder >/dev/null 2>&1; then
            useradd -m -s /bin/bash builder 2>/dev/null || true
            if [[ -d /etc/sudoers.d ]]; then
                echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-builder 2>/dev/null || true
            fi
        fi
        chown -R builder:builder . 2>/dev/null || true
        su -s /bin/bash builder -c "makepkg -f --nodeps" 2>/dev/null || runuser -u nobody -- makepkg -f --nodeps
    else
        makepkg -f --nodeps
    fi
}

# 1. Bangun meta-package lokal di PKGBUILDs
for pkg in nusa-artwork nusa-configs; do
    if [[ -d "${PKGBUILDS_DIR}/${pkg}" ]]; then
        echo "🔧 Memeriksa paket lokal: ${pkg}..."
        (
            cd "${PKGBUILDS_DIR}/${pkg}"
            if ! ls ./*.pkg.tar.zst 1>/dev/null 2>&1; then
                echo "🔨 Mengompilasi ${pkg} via makepkg..."
                run_makepkg
            fi
            echo "📋 Menyalin paket ${pkg} ke customrepo/x86_64/..."
            cp -f ./*.pkg.tar.zst "${CUSTOMREPO_DIR}/"
        )
    fi
done

# 2. Penyediaan paket Brave Browser
echo "🌐 Menyiapkan paket Brave Browser..."
LATEST_BRAVE=$(ls -t /var/cache/pacman/pkg/brave-bin-*.pkg.tar.zst 2>/dev/null | head -n 1 || true)
if [[ -n "${LATEST_BRAVE}" && -f "${LATEST_BRAVE}" ]]; then
    echo "  -> Menyalin ${LATEST_BRAVE} dari cache host..."
    cp -f "${LATEST_BRAVE}" "${CUSTOMREPO_DIR}/"
else
    echo "  -> Mengunduh paket brave-bin via URL resmi..."
    BRAVE_URL=$(pacman -Sp brave-bin 2>/dev/null | grep -E '^http' | head -n 1 || true)
    if [[ -z "${BRAVE_URL}" ]]; then
        BRAVE_URL="https://mirror.krfoss.org/cachyos/repo/x86_64/cachyos/brave-bin-1%3A1.97.59-1-x86_64.pkg.tar.zst"
    fi
    curl -fsSL -o "${CUSTOMREPO_DIR}/brave-bin-1:1.97.59-1-x86_64.pkg.tar.zst" "${BRAVE_URL}"
fi

# 3. Penyediaan paket Paru AUR Helper
echo "🦀 Menyiapkan paket Paru AUR Helper..."
PARU_URL=$(pacman -Sp paru 2>/dev/null | grep -E '^http' | head -n 1 || true)
if [[ -z "${PARU_URL}" ]]; then
    PARU_URL="https://mirror.krfoss.org/cachyos/repo/x86_64/cachyos/paru-2.1.0-3-x86_64.pkg.tar.zst"
fi
PARU_PKG="${CUSTOMREPO_DIR}/$(basename "${PARU_URL}")"
if [[ ! -f "${PARU_PKG}" ]]; then
    echo "  -> Mengunduh ${PARU_URL}..."
    curl -fsSL -o "${PARU_PKG}" "${PARU_URL}"
fi

# 4. Penyediaan paket Calamares Installer & dependensi tambahannya
echo "💿 Menyiapkan paket Calamares Installer Framework..."
CALAMARES_URL=$(pacman -Sp cachyos-calamares 2>/dev/null | grep -E '^http' | grep -E 'calamares' | head -n 1 || true)
if [[ -z "${CALAMARES_URL}" ]]; then
    CALAMARES_URL="https://mirror.krfoss.org/cachyos/repo/x86_64/cachyos/cachyos-calamares-3.4.2-4-x86_64.pkg.tar.zst"
fi
CALAMARES_PKG="${CUSTOMREPO_DIR}/$(basename "${CALAMARES_URL}")"
if [[ ! -f "${CALAMARES_PKG}" ]]; then
    echo "  -> Mengunduh ${CALAMARES_URL}..."
    curl -fsSL -o "${CALAMARES_PKG}" "${CALAMARES_URL}"
fi

# Dependensi Calamares non-official tambahan (ckbcomp & mkinitcpio-openswap)
for dep_url in \
    "https://mirror.krfoss.org/cachyos/repo/x86_64/cachyos/ckbcomp-1.249-1-any.pkg.tar.zst" \
    "https://mirror.krfoss.org/cachyos/repo/x86_64/cachyos/mkinitcpio-openswap-0.1.1-1-any.pkg.tar.zst"; do
    dep_file="${CUSTOMREPO_DIR}/$(basename "${dep_url}")"
    if [[ ! -f "${dep_file}" ]]; then
        echo "  -> Mengunduh dependensi: $(basename "${dep_url}")..."
        curl -fsSL -o "${dep_file}" "${dep_url}"
    fi
done

# 5. Inisialisasi basis data customrepo dengan repo-add
echo "📚 Memperbarui basis data repositori pacman (customrepo.db.tar.gz)..."
(
    cd "${CUSTOMREPO_DIR}"
    # Hapus basis data lama jika ada sebelum re-indexing
    rm -f customrepo.db* customrepo.files*
    repo-add -n -R customrepo.db.tar.gz ./*.pkg.tar.zst

    # Pastikan symlink standar pacman tersedia
    ln -sf customrepo.db.tar.gz customrepo.db
    ln -sf customrepo.files.tar.gz customrepo.files
)

# Sesuaikan path Server di profile/pacman.conf dengan direktori saat ini
PACMAN_CONF="${ROOT_DIR}/profile/pacman.conf"
if [[ -f "${PACMAN_CONF}" ]]; then
    echo "⚙️  Menyesuaikan path customrepo di ${PACMAN_CONF}..."
    sed -i -E "s|^Server = file://.*customrepo/x86_64$|Server = file://${CUSTOMREPO_DIR}|g" "${PACMAN_CONF}"
fi

echo "================================================================"
echo "✅ Custom Repository NusaOS berhasil diinisialisasi!"
ls -lh "${CUSTOMREPO_DIR}"
echo "================================================================"
