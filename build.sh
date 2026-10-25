#!/usr/bin/env bash
# ==============================================================================
# NusaOS Master Orchestrator Build Script
# Automates validation, custom repository setup, and rootless ISO compilation.
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${ROOT_DIR}/profile"
OUT_DIR="${ROOT_DIR}/out"
WORK_DIR="/tmp/archiso-work"

DO_CLEAN=false
DO_VALIDATE=true
DO_REBUILD_REPO=false
VERBOSE=false

usage() {
    cat << EOF
Penggunaan: $0 [OPSI]

Opsi:
  -c, --clean         Bersihkan direktori kerja (${WORK_DIR}) sebelum build
  -p, --validate      Jalankan validasi profil sebelum build (default: aktif)
  -r, --repo          Bangun ulang custom repository lokal (setup_customrepo.sh)
  -v, --verbose       Aktifkan output verbose mkarchiso
  -o, --out DIR       Tentukan direktori keluaran ISO (default: ${OUT_DIR})
  -w, --work DIR      Tentukan direktori kerja build (default: ${WORK_DIR})
  -h, --help          Tampilkan bantuan ini

Contoh:
  $0 -c -r            Bersihkan workdir, update customrepo, validasi, dan build ISO
EOF
    exit 0
}

# Parsing argument
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            DO_CLEAN=true
            shift
            ;;
        -p|--validate)
            DO_VALIDATE=true
            shift
            ;;
        --no-validate)
            DO_VALIDATE=false
            shift
            ;;
        -r|--repo)
            DO_REBUILD_REPO=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--out)
            OUT_DIR="$2"
            shift 2
            ;;
        -w|--work)
            WORK_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ Opsi tidak dikenal: $1" >&2
            usage
            ;;
    esac
done

echo "================================================================"
echo "🚀 NusaOS Build Orchestrator"
echo "================================================================"
echo "📁 Profile Directory : ${PROFILE_DIR}"
echo "📁 Output Directory  : ${OUT_DIR}"
echo "📁 Work Directory    : ${WORK_DIR}"
echo "================================================================"

# 1. Bersihkan workdir jika diminta
if [[ "${DO_CLEAN}" == true ]]; then
    echo "🧹 Membersihkan direktori kerja build (${WORK_DIR})..."
    if [[ -d "${WORK_DIR}" ]]; then
        if command -v findmnt >/dev/null 2>&1; then
            if findmnt -R "${WORK_DIR}" >/dev/null 2>&1; then
                echo "⚠️  Mountpoint aktif terdeteksi di dalam ${WORK_DIR}! Melepas kaitan dengan aman..."
                unshare --map-auto --map-root-user -- umount -R "${WORK_DIR}" 2>/dev/null || true
            fi
        fi
        unshare --map-auto --map-root-user -- rm -rf "${WORK_DIR}"
        echo "✅ Direktori kerja berhasil dibersihkan."
    fi
fi

mkdir -p "${OUT_DIR}"

# 2. Bangun ulang custom repository jika diminta atau jika belum ada
if [[ "${DO_REBUILD_REPO}" == true || ! -f "${ROOT_DIR}/customrepo/x86_64/customrepo.db.tar.gz" ]]; then
    echo "📦 Mempersiapkan Custom Repository..."
    bash "${ROOT_DIR}/scripts/setup_customrepo.sh"
fi

# 3. Jalankan Validasi Profil
if [[ "${DO_VALIDATE}" == true ]]; then
    echo "🔍 Menjalankan pre-flight profile validation..."
    bash "${ROOT_DIR}/scripts/validate_profile.sh" "${PROFILE_DIR}"
fi

# 4. Tentukan Mode Eksekusi (Rootless unshare vs Root langsung)
MKARCHISO_CMD=(mkarchiso)
if [[ "${VERBOSE}" == true ]]; then
    MKARCHISO_CMD+=(-v)
fi
MKARCHISO_CMD+=(-w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}")

echo "================================================================"
echo "🔨 Memulai kompilasi ISO NusaOS..."
echo "Perintah: ${MKARCHISO_CMD[*]}"
echo "================================================================"

if [[ $EUID -eq 0 ]]; then
    "${MKARCHISO_CMD[@]}"
else
    echo "ℹ️  Mengeksekusi dalam mode rootless user namespace via unshare..."
    unshare --map-auto --map-root-user -- "${MKARCHISO_CMD[@]}"
fi

echo "================================================================"
echo "🎉 Kompilasi ISO NusaOS SELESAI!"
echo "Berkas ISO yang dihasilkan:"
ls -lh "${OUT_DIR}"/nusaos-*.iso 2>/dev/null || echo "Tidak ada berkas ISO yang ditemukan di ${OUT_DIR}."
echo "================================================================"
