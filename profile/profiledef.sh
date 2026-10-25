#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="nusaos"
iso_label="NUSAOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="NusaOS Project <https://github.com/nusaos>"
iso_application="NusaOS Live/Installation Medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="nusaos"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/sudoers.d/00_liveuser"]="0:0:0440"
  ["/etc/sudoers.d/10_installer"]="0:0:0440"
  ["/root"]="0:0:0750"
  ["/root/.automated_script.sh"]="0:0:0755"
  ["/root/.gnupg"]="0:0:0700"
  ["/usr/local/bin/choose-mirror"]="0:0:0755"
  ["/usr/local/bin/Installation_guide"]="0:0:0755"
  ["/usr/local/bin/livecd-sound"]="0:0:0755"
  ["/usr/local/bin/nusa-welcome"]="0:0:0755"
  ["/usr/local/bin/nusa-mirror"]="0:0:0755"
)
