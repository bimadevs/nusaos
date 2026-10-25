#!/usr/bin/env bash
# Automated wrapper to validate, build, and optionally test an archiso profile.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${1:-}"
OUT_DIR="${2:-./out}"
WORK_DIR="${3:-/tmp/archiso-work}"

if [[ -z "${PROFILE_DIR}" ]]; then
  echo "Usage: $0 <profile-dir> [out-dir] [work-dir]" >&2
  exit 1
fi

PROFILE_DIR="$(realpath -- "${PROFILE_DIR}")"
OUT_DIR="$(realpath -m -- "${OUT_DIR}")"
WORK_DIR="$(realpath -m -- "${WORK_DIR}")"

echo "==> Step 1: Validating profile at ${PROFILE_DIR}..."
bash "${SCRIPT_DIR}/validate_profile.sh" "${PROFILE_DIR}"

echo "==> Step 2: Checking free disk space on work directory parent..."
mkdir -p "$(dirname -- "${WORK_DIR}")" "${OUT_DIR}"
df -h "$(dirname -- "${WORK_DIR}")"

echo "==> Step 3: Building ISO with mkarchiso..."
mkarchiso -v -r -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"

echo "==> Build complete! Output files in ${OUT_DIR}:"
ls -lh "${OUT_DIR}"/*.iso
