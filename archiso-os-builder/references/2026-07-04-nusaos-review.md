# Case Study: NusaOS Deep Review (2026-07-04)

Post-hoc code review of a real NusaOS archiso profile. Validator passed
but deeper analysis found 10 issues — from blocker to cosmetic. Full
session transcript: `session_search(query="nusaos review 2026")`.

## Key findings

| Severity | Issue | Fix |
|----------|-------|-----|
| Blocker | `linux.preset` referensi `vmlinuz-linux` tapi hanya `linux-lts` diinstall. Preset gagal menghasilkan initramfs. | Tambah `linux` ke packages, atau rename preset jadi `linux-lts.preset` + update path di preset itu sendiri. |
| Blocker | Semua bootloader config (`grub.cfg`, `loopback.cfg`, `efiboot/*.conf`) referensi `vmlinuz-linux` + `initramfs-linux.img`. ISO tidak boot. | Sinkronkan path dengan paket kernel terinstall. |
| Runtime | Motd bilang "Login: live (password: live)" tapi user `live` tidak dibuat dimanapun. | Tambah `useradd -m -G wheel live` + `chpasswd` di customize_airootfs.sh. |
| Cosmetic | SDDM theme `breeze` tapi paket `breeze` tidak di-install. Fallback ke default. | Tambah `breeze` ke packages atau ganti `ThemeCurrent=` ke `elarun` |
| Config conflict | `reflector.service` di-enable — akan overwrite mirrorlist Indonesia saat boot | Hapus `systemctl enable reflector.service` atau jangan pakai mirror manual. |
| Dead config | `systemd/network/*.network` ada tapi NM yang aktif, systemd-networkd tidak jalan | Hapus folder `systemd/network/` atau enable systemd-networkd — pilih satu. |
| Minor | `airootfs/etc/motd` (Arch default) lalu ditimpa oleh customize_airootfs.sh | Hapus file motd, biarkan script create. |
| Minor | `broadcom-wl.conf` cuma komentar tanpa directive — tidak melakukan apa-apa | Hapus file. |
| Minor | README bilang "Installer: calamares" tapi packages cuma archinstall | Sinkronkan docs dengan realitas. |
| Minor cleanup | `wireless_tools` deprecated di 2026 — fungsinya di-iwd | Hapus `wireless_tools` dari packages. |

## Lesson: validator v2 (13 checks) menutup hampir semua gap

v1 (7 checks) tidak cek: kernel consistency, live user, service
manager conflict, SDDM theme, reflector+mirrorlist, deprecated
packages. Semua silent.

v2 (13 checks, di-extend setelah session ini) menutup SEMUA gap
di atas. **Cara verifikasi v2 jalan:** output script harus
mengandung `[OK] kernel/bootloader paths consistent`. Kalau
tidak ada, validator masih v1 — re-deploy script
(`scripts/validate_profile.sh`) yang baru.

L2 (kernel+service manager), L3 (runtime expectations), L4
(docs/UX) tetap manual review. v2 = L1 lengkap.

## The four review levels

After two rounds of building + reviewing profiles (this session + earlier
case-study), the review hierarchy crystalizes:

| Level | What | Catches | Effort |
|-------|------|---------|--------|
| L1 — Scripted | `validate_profile.sh` | missing files, typos, duplicates, missing pkgs, bad syntax, label constraints | <5s |
| L2 — Structural | Cek boot configs vs kernel packages, service manager consistency | Kernel mismatch, dead configs | 2min |
| L3 — Functional | Cek runtime expectations (user exists, motd matches, services enable vs actual packages) | No login, broken autologin, SDDM wrong theme | 5min |
| L4 — UX | Cek branding, docs synchronisation, deprecated pkgs | README out of sync, dead files | 5min |

Gondol: **validate_profile.sh adalah L1 minimum**. Setiap build pertama
harus L2+L3 juga sebelum mkarchiso. L4 untuk release.

## Session outcome — full fix applied (2026-07-04)

Setelah review mendalam + v2 validator, semua issue di tabel
di-fix. Full transcript: session_search("nusaos review 2026").
